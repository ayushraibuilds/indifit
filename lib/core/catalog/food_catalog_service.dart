import 'dart:async';

import '../../data/repositories/food_api_service.dart';
import '../capabilities/food_catalog_capability.dart';
import '../privacy/privacy_policy.dart';
import 'remote_food_cache_store.dart';

/// Implementation of [FoodCatalogCapability] that bridges external food APIs
/// with the normalized IndiFit Indian culinary catalog schema and 2-tier caching.
///
/// Tier-1 is the in-memory map below; when [persistentCache] is provided
/// (SQLite `cached_remote_foods`, 14-day TTL), reads fall through to it and
/// writes go through to it, so confirmed candidates survive process death and
/// work offline. Memory-only operation (tests) is unchanged when it is null.
class FoodCatalogService implements FoodCatalogCapability {
  FoodCatalogService({
    required FoodApiService foodApiService,
    PrivacyPolicy? privacyPolicy,
    DriftRemoteFoodCacheStore? persistentCache,
  })  : _apiService = foodApiService,
        _privacyPolicy = privacyPolicy,
        _persistentCache = persistentCache;

  final FoodApiService _apiService;
  final PrivacyPolicy? _privacyPolicy;
  final DriftRemoteFoodCacheStore? _persistentCache;

  /// Tier-1 in-memory cache of previously resolved remote candidates keyed by ID.
  final Map<String, RemoteFoodCandidate> _memoryCache = {};

  @override
  Future<FoodSearchPage> searchRemoteFoods(
    String query, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return FoodSearchPage(
        items: const [],
        totalCount: 0,
        page: page,
        hasMore: false,
        query: query,
      );
    }

    if (_privacyPolicy != null && !_privacyPolicy.isOpenFoodFactsAllowed) {
      return FoodSearchPage(
        items: const [],
        totalCount: 0,
        page: page,
        hasMore: false,
        query: query,
      );
    }

    try {
      final rawResults = await _apiService.searchOnline(trimmed);
      final candidates = <RemoteFoodCandidate>[];

      for (final raw in rawResults) {
        final candidate = _adaptRawToCandidate(raw);
        if (candidate != null) {
          candidates.add(candidate);
          _memoryCache[candidate.id] = candidate;
        }
      }

      // Slice for pagination
      final startIndex = (page - 1) * pageSize;
      final slice = startIndex < candidates.length
          ? candidates.skip(startIndex).take(pageSize).toList()
          : <RemoteFoodCandidate>[];

      return FoodSearchPage(
        items: slice,
        totalCount: candidates.length,
        page: page,
        hasMore: startIndex + pageSize < candidates.length,
        query: query,
      );
    } catch (_) {
      // Fail closed and return empty page on network errors, timeouts, or
      // HTTP 429 rate limits (spec §7.3). No retry/backoff here: search is
      // user-initiated and re-issued per keystroke; the provider User-Agent
      // header (food_api_service) + empty-state copy are the rate-limit
      // contract. Never cache the empty failure page as a Tier-1 result.
      return FoodSearchPage(
        items: const [],
        totalCount: 0,
        page: page,
        hasMore: false,
        query: query,
      );
    }
  }

  @override
  Future<RemoteFoodCandidate?> lookupByBarcode(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return null;

    final cached = _memoryCache[cleanBarcode] ??
        _memoryCache.values.where((c) => c.barcode == cleanBarcode).firstOrNull;
    if (cached != null) return cached;

    // Persistent Tier-1 before any network (offline reuse across restarts).
    if (_persistentCache != null) {
      final stored = await _persistentCache.getByBarcode(cleanBarcode);
      if (stored != null) {
        _memoryCache[stored.id] = stored;
        return stored;
      }
    }

    if (_privacyPolicy != null && !_privacyPolicy.isOpenFoodFactsAllowed) {
      return null;
    }

    try {
      final raw = await _apiService.fetchByBarcode(cleanBarcode);
      if (raw == null) return null;

      final candidate = _adaptRawToCandidate(raw);
      if (candidate != null) {
        _memoryCache[candidate.id] = candidate;
        await _persistentCache?.putCandidate(candidate);
      }
      return candidate;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> cacheRemoteCandidate(RemoteFoodCandidate candidate) async {
    _memoryCache[candidate.id] = candidate;
    if (candidate.barcode != null && candidate.barcode!.isNotEmpty) {
      _memoryCache[candidate.barcode!] = candidate;
    }
    await _persistentCache?.putCandidate(candidate);
  }

  @override
  Future<RemoteFoodCandidate?> getCachedCandidate(String candidateId) async {
    final memory = _memoryCache[candidateId];
    if (memory != null) return memory;
    final stored = await _persistentCache?.getCandidate(candidateId);
    if (stored != null) _memoryCache[stored.id] = stored;
    return stored;
  }

  @override
  Future<List<RemoteFoodCandidate>> getRecentCachedCandidates({
    int limit = 50,
  }) async {
    final seen = <String>{};
    final deduped = <RemoteFoodCandidate>[];
    for (final candidate in _memoryCache.values) {
      if (!seen.add(candidate.id)) continue;
      deduped.add(candidate);
      if (deduped.length >= limit) break;
    }
    // Union with persistent Tier-1 (fresh only; store enforces TTL).
    if (deduped.length < limit && _persistentCache != null) {
      for (final stored
          in await _persistentCache.recentCandidates(limit: limit)) {
        if (!seen.add(stored.id)) continue;
        _memoryCache[stored.id] = stored;
        deduped.add(stored);
        if (deduped.length >= limit) break;
      }
    }
    return deduped;
  }

  /// Adapts a raw third-party [FoodApiResult] into a strongly typed [RemoteFoodCandidate]
  /// with Indian culinary serving options and Atwater validation.
  ///
  /// Returns null when energy/macros are incomplete: absent nutrients stay
  /// missing and must go through explicit custom entry, never silent 0.0.
  RemoteFoodCandidate? _adaptRawToCandidate(FoodApiResult raw) {
    final stableId = raw.barcode ?? raw.providerId;
    if (stableId == null || stableId.trim().isEmpty) return null;

    final name = raw.name.trim();
    if (name.isEmpty) return null;
    if (!raw.hasCompleteMacros) return null;

    // Standard per 100g basis (all non-null after the completeness gate).
    final calories = raw.calories!;
    final protein = raw.protein!;
    final carbs = raw.carbs!;
    final fat = raw.fat!;

    final servingOptions = _synthesizeIndianServingOptions(
      name: name,
      servingSize: raw.servingSize,
      servingUnit: raw.servingUnit,
    );

    final provenance = FoodProvenance(
      provider: FoodCatalogProvider.openFoodFacts,
      attributionText: 'Source: Open Food Facts (ODbL)',
      license: 'ODbL',
      sourceUrl: raw.barcode != null
          ? 'https://world.openfoodfacts.org/product/${raw.barcode}'
          : null,
      fetchedAtUtc: DateTime.now().toUtc(),
    );

    return RemoteFoodCandidate(
      id: 'off_$stableId',
      provider: FoodCatalogProvider.openFoodFacts,
      providerId: stableId,
      name: name,
      brand: raw.brand,
      barcode: raw.barcode,
      category: _inferCategory(name),
      caloriesPer100g: calories,
      proteinPer100g: protein,
      carbsPer100g: carbs,
      fatPer100g: fat,
      fiberPer100g: raw.fiber,
      servingOptions: servingOptions,
      provenance: provenance,
      verificationLevel: FoodVerificationLevel.communityReported,
    );
  }

  /// Infers standard culinary categories based on common Indian culinary keywords.
  String _inferCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('roti') || lower.contains('chapati') || lower.contains('bread') || lower.contains('naan')) {
      return 'roti';
    }
    if (lower.contains('dal') || lower.contains('lentil') || lower.contains('sambar')) {
      return 'dal';
    }
    if (lower.contains('rice') || lower.contains('pulao') || lower.contains('biryani') || lower.contains('khichdi')) {
      return 'rice';
    }
    if (lower.contains('milk') || lower.contains('paneer') || lower.contains('curd') || lower.contains('dahi') || lower.contains('cheese')) {
      return 'dairy';
    }
    if (lower.contains('sabzi') || lower.contains('curry') || lower.contains('bhaji')) {
      return 'sabzi';
    }
    if (lower.contains('biscuit') || lower.contains('cookie') || lower.contains('namkeen') || lower.contains('chips')) {
      return 'snack';
    }
    return 'general';
  }

  /// Synthesizes appropriate Indian portion options per
  /// `CATALOG01A_FOOD_CATALOG_SPECIFICATION.md` §5 (exact unit names/weights).
  ///
  /// Density note: `glass` is 200 ml per spec; gram conversion uses 1.03 g/ml
  /// (milk-like density) only when the provider serving unit is `ml`. This is
  /// wrong for juice/oil, so the sheet always shows the original unit label
  /// and users confirm the portion before logging.
  List<ServingOption> _synthesizeIndianServingOptions({
    required String name,
    required double servingSize,
    required String servingUnit,
  }) {
    final options = <ServingOption>[];
    final lower = name.toLowerCase();

    // 1. Exact packaging serving size
    if (servingSize > 0 && servingSize.isFinite) {
      options.add(
        ServingOption(
          unitName: servingUnit.isNotEmpty ? servingUnit : 'serving',
          gramWeight: servingUnit.toLowerCase() == 'ml' ? servingSize * 1.03 : servingSize,
          isDefault: true,
        ),
      );
    }

    // 2. Standard 100g basis
    if (servingSize != 100.0) {
      options.add(
        const ServingOption(
          unitName: '100g',
          gramWeight: 100.0,
          isDefault: false,
        ),
      );
    }

    // 3. Indian culinary household measures (spec §5 exact names/weights)
    final isStuffedParatha = isStuffedParathaName(name);
    if (lower.contains('dal') ||
        lower.contains('curry') ||
        lower.contains('sabzi') ||
        lower.contains('sambar') ||
        lower.contains('khichdi') ||
        lower.contains('kadhi') ||
        lower.contains('raita')) {
      options.add(
        const ServingOption(unitName: 'katori', gramWeight: 150.0),
      );
      options.add(
        const ServingOption(unitName: 'serving_bowl', gramWeight: 300.0),
      );
    }
    if (lower.contains('biryani') ||
        lower.contains('pulao') ||
        lower.contains('rice')) {
      options.add(
        const ServingOption(unitName: 'medium_katori', gramWeight: 200.0),
      );
      options.add(
        const ServingOption(unitName: 'serving_bowl', gramWeight: 300.0),
      );
    }
    if (lower.contains('roti') ||
        lower.contains('chapati') ||
        lower.contains('phulka')) {
      options.add(
        const ServingOption(unitName: 'roti_piece', gramWeight: 35.0),
      );
    }
    if (lower.contains('paratha')) {
      options.add(
        ServingOption(
          unitName: isStuffedParatha ? 'stuffed_paratha' : 'paratha_piece',
          gramWeight: isStuffedParatha ? 110.0 : 60.0,
        ),
      );
    }
    if (lower.contains('idli')) {
      options.add(
        const ServingOption(unitName: 'idli_piece', gramWeight: 40.0),
      );
    }
    if (lower.contains('dosa')) {
      options.add(
        const ServingOption(unitName: 'dosa_piece', gramWeight: 90.0),
      );
    }
    if (lower.contains('milk') ||
        lower.contains('chaas') ||
        lower.contains('lassi') ||
        lower.contains('juice')) {
      options.add(
        const ServingOption(unitName: 'glass', gramWeight: 206.0),
      );
    }
    if (lower.contains('ghee') ||
        lower.contains('oil') ||
        lower.contains('butter') ||
        lower.contains('chutney') ||
        lower.contains('sugar') ||
        lower.contains('honey') ||
        lower.contains('seeds')) {
      options.add(
        const ServingOption(unitName: 'tablespoon', gramWeight: 15.0),
      );
      options.add(
        const ServingOption(unitName: 'teaspoon', gramWeight: 5.0),
      );
    }

    return options;
  }
}
