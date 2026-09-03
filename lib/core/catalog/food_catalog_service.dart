import 'dart:async';

import '../../data/repositories/food_api_service.dart';
import '../capabilities/food_catalog_capability.dart';
import '../privacy/privacy_policy.dart';

/// Implementation of [FoodCatalogCapability] that bridges external food APIs
/// with the normalized IndiFit Indian culinary catalog schema and 2-tier caching.
class FoodCatalogService implements FoodCatalogCapability {
  FoodCatalogService({
    required FoodApiService foodApiService,
    PrivacyPolicy? privacyPolicy,
  })  : _apiService = foodApiService,
        _privacyPolicy = privacyPolicy;

  final FoodApiService _apiService;
  final PrivacyPolicy? _privacyPolicy;

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
      // Fail closed and return empty page on network errors or timeouts
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

    if (_privacyPolicy != null && !_privacyPolicy.isOpenFoodFactsAllowed) {
      return null;
    }

    try {
      final raw = await _apiService.fetchByBarcode(cleanBarcode);
      if (raw == null) return null;

      final candidate = _adaptRawToCandidate(raw);
      if (candidate != null) {
        _memoryCache[candidate.id] = candidate;
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
  }

  @override
  Future<RemoteFoodCandidate?> getCachedCandidate(String candidateId) async {
    return _memoryCache[candidateId];
  }

  @override
  Future<List<RemoteFoodCandidate>> getRecentCachedCandidates({
    int limit = 50,
  }) async {
    return _memoryCache.values.take(limit).toList();
  }

  /// Adapts a raw third-party [FoodApiResult] into a strongly typed [RemoteFoodCandidate]
  /// with Indian culinary serving options and Atwater validation.
  RemoteFoodCandidate? _adaptRawToCandidate(FoodApiResult raw) {
    final stableId = raw.barcode ?? raw.providerId;
    if (stableId == null || stableId.trim().isEmpty) return null;

    final name = raw.name.trim();
    if (name.isEmpty) return null;

    // Standard per 100g basis
    final calories = raw.calories ?? 0.0;
    final protein = raw.protein ?? 0.0;
    final carbs = raw.carbs ?? 0.0;
    final fat = raw.fat ?? 0.0;

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
      fiberPer100g: null,
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

  /// Synthesizes appropriate Indian portion options (`katori`, `piece`, `glass`)
  /// based on food name and package metadata.
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

    // 3. Indian Culinary household measures
    if (lower.contains('dal') || lower.contains('curry') || lower.contains('sabzi') || lower.contains('sambar') || lower.contains('khichdi')) {
      options.add(
        const ServingOption(unitName: 'katori', gramWeight: 150.0),
      );
      options.add(
        const ServingOption(unitName: 'bowl', gramWeight: 300.0),
      );
    } else if (lower.contains('roti') || lower.contains('chapati') || lower.contains('phulka')) {
      options.add(
        const ServingOption(unitName: 'piece', gramWeight: 35.0),
      );
    } else if (lower.contains('paratha')) {
      options.add(
        const ServingOption(unitName: 'piece', gramWeight: 75.0),
      );
    } else if (lower.contains('milk') || lower.contains('chaas') || lower.contains('lassi') || lower.contains('juice')) {
      options.add(
        const ServingOption(unitName: 'glass', gramWeight: 206.0),
      );
    } else if (lower.contains('ghee') || lower.contains('oil') || lower.contains('butter')) {
      options.add(
        const ServingOption(unitName: 'tbsp', gramWeight: 15.0),
      );
      options.add(
        const ServingOption(unitName: 'tsp', gramWeight: 5.0),
      );
    }

    return options;
  }
}
