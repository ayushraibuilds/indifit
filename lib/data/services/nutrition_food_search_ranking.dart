import '../database/app_database.dart';
import '../repositories/food_api_service.dart';
import '../repositories/nutrition_food_catalog_repository.dart';
import 'food_dish_groups.dart';
import 'food_name_spelling.dart';
import 'food_query_amount.dart';

/// Retrieval vocabulary used by food search. These terms are intentionally
/// separate from B03 identity aliases: they help a query find a candidate but
/// never change the candidate's canonical identity, facts, or provenance.
class NutritionFoodSearchVocabulary {
  NutritionFoodSearchVocabulary._();

  static const Map<String, List<String>> _aliasGroups = {
    'dahi': ['curd'],
    'curd': ['dahi'],
    'roti': ['chapati'],
    'chapati': ['roti'],
    'poha': ['flattened rice', 'beaten rice'],
    'flattened rice': ['poha'],
    'beaten rice': ['poha'],
    // The catalogue's "Aloo Gobbi (Dry Sabji)" carries a typo in its
    // identity key, so searches for the usual spelling must reach it.
    'gobi': ['gobbi'],
    // Short forms, regional names and both spellings the catalogue uses
    // (UR-03). Retrieval only: each finds the other's foods.
    'veg': ['vegetable'],
    'vegetable': ['veg'],
    'rava': ['suji'],
    'suji': ['rava'],
    'semolina': ['suji'],
    'puri': ['poori'],
    'poori': ['puri'],
    'bhatura': ['bhature'],
    'bhature': ['bhatura'],
    'bhakri': ['roti'],
    'phulka': ['roti'],
    'mudde': ['roti'],
    'prawn': ['shrimp'],
    'shrimp': ['prawn'],
    'jhinga': ['prawn'],
    'momo': ['momos'],
    'momos': ['momo'],
    'chilla': ['chilka', 'cheela'],
    'cheela': ['chilka', 'chilla'],
    'chilka': ['chilla', 'cheela'],
    'fry': ['do pyaza'],
    'chawal': ['rice'],
    'rice': ['chawal'],
    'anda': ['egg'],
    'aloo': ['potato'],
    'potato': ['aloo'],
    'matar': ['mattar', 'peas'],
    'mattar': ['matar'],
    'bhindi': ['okra'],
    'okra': ['bhindi'],
    'baingan': ['brinjal', 'eggplant'],
    'brinjal': ['baingan'],
    'lauki': ['bottle gourd'],
    'karela': ['bitter gourd'],
    'yogurt': ['curd'],
    'yoghurt': ['curd'],
    'dosai': ['dosa'],
    'idly': ['idli'],
  };

  /// Plain base foods and the head noun they are (UR-04): "Toned Milk" is
  /// what someone typing "milk" means. Names are matched without their
  /// bracketed detail, so variants inherit the alias (and their penalty).
  static const Map<String, List<String>> _plainBaseNames = {
    'toned milk': ['milk'],
    'double toned milk': ['milk'],
    'full cream milk': ['milk'],
    'skimmed milk': ['milk'],
    'cow milk': ['milk'],
    'buffalo milk': ['milk'],
    'whole milk': ['milk'],
    'basmati white rice': ['rice', 'chawal'],
    'white rice': ['rice', 'chawal'],
    'steamed rice': ['rice', 'chawal'],
    'plain rice': ['rice', 'chawal'],
    'plain curd dahi': ['curd', 'dahi'],
    'plain dosa with chutney': ['dosa'],
    'amul fresh paneer': ['paneer'],
  };

  /// Head-noun aliases of [displayName] when it is a plain base food.
  static List<String> baseAliasesFor(String displayName) =>
      _plainBaseNames[normalize(_withoutBrackets(displayName))] ?? const [];

  static String _withoutBrackets(String name) {
    var text = name;
    for (var i = 0; i < 3 && text.contains('('); i++) {
      text = text.replaceAll(RegExp(r'\([^()]*\)'), ' ');
    }
    return text;
  }

  static const Set<String> _fillerWords = {'ki', 'ka', 'ke', 'with', 'and'};

  /// A name's words without its bracketed detail and filler words: "Lauki
  /// Ki Sabji (Bottle Gourd)" -> "lauki sabji".
  static String coreName(String displayName) =>
      _core(foldFoodSpellings(normalize(_withoutBrackets(displayName))));

  static String coreQuery(String normalizedQuery) =>
      _core(foldFoodSpellings(normalizedQuery));

  static String _core(String text) => text
      .split(' ')
      .where((token) => token.isNotEmpty && !_fillerWords.contains(token))
      .join(' ');

  static const Set<String> _dessertWords = {
    'barfi',
    'burfi',
    'chocolate',
    'halwa',
    'kheer',
    'ladoo',
    'jamun',
    'rasgulla',
    'rasmalai',
    'peda',
    'cake',
    'pastry',
    'kulfi',
    'payasam',
    'mithai',
    'katli',
    'jalebi',
    'shrikhand',
    'sandesh',
    'brownie',
    'cookie',
    'cookies',
    'candy',
    'dessert',
    'custard',
    'pudding',
    'icecream',
    'sweets',
  };

  static bool _hasDessertWord(String normalized) {
    final tokens = foldFoodSpellings(normalized).split(' ');
    if (tokens.any(_dessertWords.contains)) return true;
    return normalized.contains('ice cream');
  }

  /// A sweet or dessert, by name or category: pushed below plain foods
  /// when the search names no sweet (UR-04: "milk" isn't Milk Barfi).
  static bool isDessert({required String displayName, String? category}) =>
      _hasDessertWord(normalize(displayName)) ||
      _hasDessertWord(normalize(category ?? ''));

  static bool queryWantsDessert(String query) =>
      _hasDessertWord(normalize(query));

  /// Reviewed search-only defaults for generic consumer concepts.
  ///
  /// These stable B03 IDs are ranking hints, not aliases in the identity
  /// resolver. They never make `roti` or `chapati` identity-equal to the
  /// canonical food; they only put the ordinary base option first in search.
  static const Map<String, Set<String>> _primaryConceptCanonicalIds = {
    'roti': {'food-seed-0564'},
    'chapati': {'food-seed-0564'},
    'dal': {
      'food-seed-0532', // Toor Dal / Yellow Dal Tadka
      'food-seed-0156', // Dal Fry (Chana & Toor)
      'food-seed-0160', // Dal Makhani
      'food-seed-0345', // Moong Dal Chilka (Cooked)
      'food-seed-0310', // Masoor Dal / Red Lentil Soup
      'food-seed-0543', // Urad Dal Plain
      'food-seed-0570', // Yellow Dal Tadka
    },
    'curd': {
      'food-seed-0416', // Plain Curd / Dahi (Cow Milk)
      'food-seed-0288', // Low Fat Curd / Dahi
    },
    'dahi': {'food-seed-0416', 'food-seed-0288'},
    // Pack 3 (USDA staples): the plain food before dishes that contain it.
    'bread': {'food-usda-0050'}, // White Bread
    'cheese': {'food-usda-0097'}, // Cheese Slice
    'egg': {
      'food-seed-0089', // Boiled Eggs (2 pieces)
      'food-usda-0084', // Whole Egg (Boiled)
    },
    'chai': {
      'food-seed-0300', // Masala Chai (with milk & sugar)
      'food-usda-0100', // Tea with Milk and Sugar
    },
    'tea': {'food-usda-0100', 'food-seed-0300'},
  };

  /// Hindi words for the primary concepts above.
  static const Map<String, String> _hindiConcepts = {
    'रोटी': 'roti',
    'चपाती': 'chapati',
    'दाल': 'dal',
    'दही': 'dahi',
  };

  /// "1 bowl dal" -> "dal", "chawal 1 plate" -> "chawal", "100g paneer" ->
  /// "paneer": drops an amount and unit typed with the food. Left alone when
  /// nothing would remain. A bare number ("3 roti", "7 up") is kept here;
  /// the search decides whether it is an amount ([FoodQueryParser]).
  static String stripLeadingMeasure(String query) {
    final parsed = FoodQueryParser.parse(query);
    return parsed.bareNumber ? parsed.original : parsed.food;
  }

  static String normalize(String value) {
    // Preserve letters and digits, including non-Latin food names and
    // meaningful package numbers, while making punctuation a token boundary.
    return value
        .toLowerCase()
        .replaceAll(
          RegExp(r'[\u00a0\u1680\u2000-\u200a\u202f\u205f\u3000]'),
          ' ',
        )
        .replaceAll(RegExp(r'''[!"#\$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~]'''), ' ')
        .replaceAll(RegExp(r'[\u2010-\u2015\u2212\u2022]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAllMapped(
          RegExp(r'\b(\d+(?:\.\d+)?)\s+(kg|g|ml|l)\b'),
          (match) => '${match.group(1)}${match.group(2)}',
        )
        .trim();
  }

  static List<String> expand(String value) {
    final normalized = normalize(value);
    if (normalized.isEmpty) return const [];
    final expanded = <String>{normalized, foldFoodSpellings(normalized)};
    final direct = _aliasGroups[normalized];
    if (direct != null) expanded.addAll(direct.map(normalize));

    final tokens = normalized.split(' ');
    for (var index = 0; index < tokens.length; index++) {
      final aliases = _aliasGroups[tokens[index]];
      if (aliases == null) continue;
      for (final alias in aliases) {
        final replacement = normalize(alias).split(' ');
        expanded.add(
          [
            ...tokens.take(index),
            ...replacement,
            ...tokens.skip(index + 1),
          ].join(' '),
        );
      }
    }
    return expanded.toList(growable: false);
  }

  static bool isPrimaryConcept({
    required String query,
    required String? canonicalFoodId,
  }) {
    if (canonicalFoodId == null) return false;
    final key = foldFoodSpellings(normalize(query));
    return (_primaryConceptCanonicalIds[key] ??
                _primaryConceptCanonicalIds[_hindiConcepts[key]])
            ?.contains(canonicalFoodId) ??
        false;
  }

  static bool hasPrimaryConceptCategory({
    required String query,
    required String? category,
  }) {
    final normalizedCategory = normalize(category ?? '');
    return switch (normalize(query)) {
      'roti' || 'chapati' => normalizedCategory == 'grains breads',
      _ => false,
    };
  }
}

/// Exact Open Food Facts identity validation shared by discovery and logging.
/// Display text and other metadata never participate in this decision.
class NutritionFoodProviderIdentity {
  const NutritionFoodProviderIdentity._();

  static String? stableProductId(FoodApiResult result) {
    final barcode = _clean(result.barcode);
    final providerId = _clean(result.providerId);
    if (barcode != null && providerId != null && barcode != providerId) {
      return null;
    }
    return barcode ?? providerId;
  }

  static String? sourceReference(FoodApiResult result) {
    final stableId = stableProductId(result);
    if (stableId == null) return null;
    return _clean(result.barcode) != null
        ? 'open-food-facts:barcode:$stableId'
        : 'open-food-facts:product:$stableId';
  }

  static String? _clean(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}

enum NutritionFoodSearchSource { legacy, canonical, remote }

enum NutritionFoodSearchMatch {
  none,
  fuzzy,
  substring,
  token,
  prefix,
  aliasExact,
  exact,
}

class NutritionFoodSearchCandidate {
  const NutritionFoodSearchCandidate._({
    required this.source,
    required this.id,
    required this.canonicalIdentityId,
    required this.presentationKind,
    required this.variantOfFoodId,
    required this.displayName,
    required this.brand,
    required this.category,
    required this.regionPack,
    required this.isCustom,
    required this.hasNumericFacts,
    required this.providerId,
    required this.packageQuantity,
    required this.food,
    required this.option,
    required this.remote,
    this.matchedTerms = const [],
    this.alternateNames = const [],
  });

  factory NutritionFoodSearchCandidate.legacy(
    FoodItem food, {
    String? canonicalIdentityId,
    String? presentationKind,
    String? variantOfFoodId,
    List<String> matchedTerms = const [],
  }) {
    return NutritionFoodSearchCandidate._(
      source: NutritionFoodSearchSource.legacy,
      id: 'legacy-food-item::${food.id}',
      canonicalIdentityId: canonicalIdentityId,
      presentationKind: presentationKind,
      variantOfFoodId: variantOfFoodId,
      displayName: food.name,
      brand: _clean(food.brand),
      category: _clean(food.category),
      regionPack: _clean(food.regionPack),
      isCustom: food.isCustom,
      hasNumericFacts: true,
      providerId: null,
      packageQuantity: null,
      food: food,
      option: null,
      remote: null,
      matchedTerms: matchedTerms,
      alternateNames: [
        if (food.nameHindi?.trim().isNotEmpty ?? false) food.nameHindi!.trim(),
        ...NutritionFoodSearchVocabulary.baseAliasesFor(food.name),
      ],
    );
  }

  factory NutritionFoodSearchCandidate.canonical(
    NutritionFoodOption option, {
    List<String> matchedTerms = const [],
    List<String> alternateNames = const [],
  }) {
    return NutritionFoodSearchCandidate._(
      source: NutritionFoodSearchSource.canonical,
      id: option.id,
      canonicalIdentityId: option.id,
      presentationKind: null,
      variantOfFoodId: option.variantOfFoodId,
      displayName: option.displayName,
      brand: _clean(option.brand),
      category: null,
      regionPack: null,
      isCustom:
          option.sourceType == 'user' || option.sourceType == 'user_entered',
      hasNumericFacts: option.hasNumericFacts,
      providerId: null,
      packageQuantity: null,
      food: null,
      option: option,
      remote: null,
      matchedTerms: matchedTerms,
      alternateNames: [
        ...alternateNames,
        ...NutritionFoodSearchVocabulary.baseAliasesFor(option.displayName),
      ],
    );
  }

  factory NutritionFoodSearchCandidate.remote(FoodApiResult remote) {
    final stableId = NutritionFoodProviderIdentity.stableProductId(remote);
    return NutritionFoodSearchCandidate._(
      source: NutritionFoodSearchSource.remote,
      id: stableId ?? '',
      canonicalIdentityId: null,
      presentationKind: null,
      variantOfFoodId: null,
      displayName: remote.name,
      brand: _clean(remote.brand),
      category: null,
      regionPack: null,
      isCustom: false,
      hasNumericFacts:
          remote.calories != null ||
          remote.protein != null ||
          remote.carbs != null ||
          remote.fat != null,
      providerId: stableId,
      packageQuantity: _clean(remote.packageQuantity),
      food: null,
      option: null,
      remote: remote,
    );
  }

  final NutritionFoodSearchSource source;
  final String id;
  final String? canonicalIdentityId;
  final String? presentationKind;
  final String? variantOfFoodId;
  final String displayName;
  final String? brand;
  final String? category;
  final String? regionPack;
  final bool isCustom;
  final bool hasNumericFacts;
  final String? providerId;
  final String? packageQuantity;

  /// Other names that count as the food's name, not just metadata: the
  /// Hindi name, so "रोटी" finds "गेहूं की रोटी".
  final List<String> alternateNames;
  final FoodItem? food;
  final NutritionFoodOption? option;
  final FoodApiResult? remote;

  /// Words the on-device index matched besides the name: pack aliases and
  /// corrected spellings (CAT-9). Searchable, never displayed.
  final List<String> matchedTerms;

  /// Only canonical IDs and stable provider IDs are trusted for dedupe.
  String? get trustedIdentityKey {
    if (source == NutritionFoodSearchSource.remote) {
      final provider = providerId;
      return provider == null ? null : 'provider::$provider';
    }
    final canonicalId = canonicalIdentityId ?? id;
    return canonicalId.isEmpty ? null : 'canonical::$canonicalId';
  }

  /// Bounded presentation-only marker. The record remains independently
  /// selectable and keeps its canonical identity; this only prevents obvious
  /// convenience variants from filling the first viewport.
  bool get isExplicitPresentationVariant =>
      presentationKind == 'servingPresentationVariant' ||
      _minorVariantSuffixes.any(displayName.trim().toLowerCase().endsWith);

  static const List<String> _minorVariantSuffixes = [
    '(mini)',
    '(double)',
    '(premium ghee / extra oil)',
    '(jumbo / large)',
    '(half plate)',
    '(double serving)',
    '(extra butter / ghee)',
    '(double paneer)',
    '(low oil / diet version)',
    '(mini size)',
    '(with extra cheese / butter)',
    '(small side bowl)',
    '(double healthy bowl)',
    '(low oil cooking)',
    '(dhaba style (high oil))',
  ];

  /// Brand and declared pack quantity can be searched as product metadata,
  /// without altering the candidate's B03 identity, facts, or provenance.
  String get searchableText {
    final name = NutritionFoodSearchVocabulary.normalize(displayName);
    final brandText = NutritionFoodSearchVocabulary.normalize(brand ?? '');
    final packageText = NutritionFoodSearchVocabulary.normalize(
      packageQuantity ?? '',
    );
    final categoryText = NutritionFoodSearchVocabulary.normalize(
      category ?? '',
    );
    final regionText = NutritionFoodSearchVocabulary.normalize(
      regionPack ?? '',
    );
    return [
      name,
      if (brandText.isNotEmpty && !name.contains(brandText)) brandText,
      if (packageText.isNotEmpty && !name.contains(packageText)) packageText,
      if (categoryText.isNotEmpty && !name.contains(categoryText)) categoryText,
      if (regionText.isNotEmpty && !name.contains(regionText)) regionText,
      for (final term in matchedTerms)
        NutritionFoodSearchVocabulary.normalize(term),
    ].where((part) => part.isNotEmpty).join(' ');
  }

  String get deterministicKey {
    final sourceKey = switch (source) {
      NutritionFoodSearchSource.legacy => 'legacy',
      NutritionFoodSearchSource.canonical => 'canonical',
      NutritionFoodSearchSource.remote => 'remote',
    };
    return [
      NutritionFoodSearchVocabulary.normalize(displayName),
      NutritionFoodSearchVocabulary.normalize(brand ?? ''),
      sourceKey,
      id,
      canonicalIdentityId ?? '',
      presentationKind ?? '',
      variantOfFoodId ?? '',
      remote?.servingSize.toString() ?? '',
      remote?.servingUnit ?? '',
      remote?.calories?.toString() ?? '',
      remote?.protein?.toString() ?? '',
      remote?.carbs?.toString() ?? '',
      remote?.fat?.toString() ?? '',
      NutritionFoodSearchVocabulary.normalize(packageQuantity ?? ''),
      NutritionFoodSearchVocabulary.normalize(category ?? ''),
      NutritionFoodSearchVocabulary.normalize(regionPack ?? ''),
    ].join('|');
  }

  static String? _clean(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}

class NutritionFoodSearchHistory {
  const NutritionFoodSearchHistory({
    this.frequencyByIdentity = const {},
    this.recentIdentities = const {},
  });

  const NutritionFoodSearchHistory.empty()
    : frequencyByIdentity = const {},
      recentIdentities = const {};

  final Map<String, int> frequencyByIdentity;
  final Set<String> recentIdentities;

  int frequencyFor(NutritionFoodSearchCandidate candidate) {
    final key = candidate.trustedIdentityKey;
    if (key == null) return 0;
    return frequencyByIdentity[key] ?? 0;
  }

  bool isRecent(NutritionFoodSearchCandidate candidate) {
    final key = candidate.trustedIdentityKey;
    return key != null && recentIdentities.contains(key);
  }
}

class NutritionFoodSearchResult {
  const NutritionFoodSearchResult({
    required this.candidate,
    required this.match,
    required this.score,
  });

  final NutritionFoodSearchCandidate candidate;
  final NutritionFoodSearchMatch match;
  final int score;
}

/// Pure deterministic ranking for local, canonical, and provider candidates.
///
/// The score is deliberately an explainable composition: lexical match is
/// dominant, then bounded local-authority, facts-availability, and relevant
/// history tie-breaks apply. Usage history can only help a candidate that is
/// already a meaningful lexical match; it never creates a result or makes a
/// provider product outrank a useful local match.
/// The UI consumes the ordered candidates and never exposes the score.
class NutritionFoodSearchRanking {
  const NutritionFoodSearchRanking._();

  static const int _exact = 1000;
  static const int _aliasExact = 950;
  static const int _prefix = 820;
  // The query starts a later word ("egg" in "Roasted eggplant"): weaker
  // than a whole-word match ("Boiled Eggs").
  static const int _innerPrefix = 640;
  static const int _token = 680;
  static const int _substring = 220;
  static const int _metadataToken = 120;
  static const int _metadataSubstring = 70;
  static const int _remoteWeakToken = 175;
  static const int _fuzzy = 300;
  static const int _localityBoost = 80;
  static const int _customBoost = 30;
  static const int _genericBoost = 22;
  static const int _factsAvailabilityBoost = 40;
  static const int _historyRecentBoost = 8;
  static const int _historyFrequencyStep = 2;
  static const int _primaryConceptBoost = 220;
  static const int _primaryConceptCategoryBoost = 80;
  static const int _servingVariantPenalty = 180;
  static const int _unaskedDessertPenalty = 200;
  // A generic provider exact match must not displace a reviewed/local food
  // whose name contains the requested common food (for example the bundled
  // "Whole Wheat Roti / Chapati" entry for a `roti` query). Explicit brand or
  // numeric product intent bypasses this penalty below.
  static const int _remotePenalty = 260;
  static const int _remoteMinimum = 260;

  static List<NutritionFoodSearchResult> rank({
    required String query,
    required Iterable<NutritionFoodSearchCandidate> candidates,
    NutritionFoodSearchHistory history =
        const NutritionFoodSearchHistory.empty(),
    int limit = 40,
    bool oneRowPerDish = false,
  }) {
    final normalizedQuery = NutritionFoodSearchVocabulary.normalize(query);
    if (normalizedQuery.isEmpty) return const [];
    final queryVariants = NutritionFoodSearchVocabulary.expand(normalizedQuery);
    final scored = <NutritionFoodSearchResult>[];
    final seen = <String, NutritionFoodSearchResult>{};

    for (final candidate in candidates) {
      final evaluation = _evaluate(candidate, normalizedQuery, queryVariants);
      if (evaluation.match == NutritionFoodSearchMatch.none) continue;
      final score = _score(candidate, evaluation, normalizedQuery, history);
      final result = NutritionFoodSearchResult(
        candidate: candidate,
        match: evaluation.match,
        score: score,
      );
      final identity = candidate.trustedIdentityKey;
      if (identity == null) {
        scored.add(result);
        continue;
      }
      final previous = seen[identity];
      if (previous == null || _preferCandidate(result, previous)) {
        seen[identity] = result;
      }
    }
    scored.addAll(seen.values);
    scored.removeWhere(
      (result) =>
          result.candidate.source == NutritionFoodSearchSource.remote &&
          !_remotePassesThreshold(result, normalizedQuery),
    );
    scored.sort(_compare);
    // UR-05: size and oil variants become chips in the portion sheet.
    final rows = oneRowPerDish
        ? FoodDishGroups.collapse(normalizedQuery, scored)
        : scored;
    if (rows.length <= limit) return List.unmodifiable(rows);
    return List.unmodifiable(rows.take(limit));
  }

  static _Evaluation _evaluate(
    NutritionFoodSearchCandidate candidate,
    String normalizedQuery,
    List<String> queryVariants,
  ) {
    final searchableText = candidate.searchableText;
    if (searchableText.isEmpty) return const _Evaluation.none();
    final searchableTokens = _tokens(searchableText);
    final originalTokens = _tokens(normalizedQuery);
    var best = const _Evaluation.none();
    for (final name in [candidate.displayName, ...candidate.alternateNames]) {
      final displayName = NutritionFoodSearchVocabulary.normalize(name);
      if (displayName.isEmpty) continue;
      final displayTokens = _tokens(displayName);
      for (final variant in queryVariants) {
        final variantTokens = _tokens(variant);
        final alias = variant != normalizedQuery;
        final evaluation = _evaluateVariant(
          candidate,
          displayName,
          displayTokens,
          searchableText,
          searchableTokens,
          normalizedQuery,
          variant,
          variantTokens,
          originalTokens,
          alias,
        );
        if (evaluation.rank > best.rank ||
            evaluation.lexicalScore > best.lexicalScore) {
          best = evaluation;
        }
      }
    }
    // The name is the query apart from filler words and bracketed detail
    // ("Lauki Ki Sabji (Bottle Gourd)" for "lauki sabji"): nearly exact.
    if (best.rank < NutritionFoodSearchMatch.aliasExact.index) {
      final core = NutritionFoodSearchVocabulary.coreName(
        candidate.displayName,
      );
      if (core.isNotEmpty &&
          queryVariants.any(
            (variant) =>
                NutritionFoodSearchVocabulary.coreQuery(variant) == core,
          )) {
        best = const _Evaluation(
          match: NutritionFoodSearchMatch.aliasExact,
          lexicalScore: _aliasExact,
        );
      }
    }
    return best;
  }

  static _Evaluation _evaluateVariant(
    NutritionFoodSearchCandidate candidate,
    String displayName,
    List<String> displayTokens,
    String searchableText,
    List<String> searchableTokens,
    String normalizedQuery,
    String variant,
    List<String> variantTokens,
    List<String> originalTokens,
    bool alias,
  ) {
    // Display name is the primary identity-bearing field. Search metadata is
    // useful for discovery, but must not turn an exact food-name query into a
    // weaker token match merely because a brand/category is also present.
    if (displayName == variant) {
      return _Evaluation(
        match: alias
            ? NutritionFoodSearchMatch.aliasExact
            : NutritionFoodSearchMatch.exact,
        lexicalScore: alias ? _aliasExact : _exact,
      );
    }
    if (displayName.startsWith('$variant ')) {
      // A name that only starts with an alias ("Dahi Papdi Chaat" for
      // "curd") is a prefix match, not an exact one.
      return _Evaluation(
        match: NutritionFoodSearchMatch.prefix,
        lexicalScore: alias ? _prefix - 30 : _prefix,
      );
    }
    final allDisplayTokensMatch =
        variantTokens.isNotEmpty &&
        variantTokens.every(
          (queryToken) => displayTokens.any(
            (nameToken) =>
                nameToken == queryToken ||
                _safeSingular(nameToken) == _safeSingular(queryToken),
          ),
        );
    if (allDisplayTokensMatch) {
      final firstTokenMatches = variantTokens.every(
        (queryToken) => displayTokens.first == queryToken,
      );
      // A short provider token hidden in a product name is often a brand or
      // marketing fragment (for example "Bon appe"), not a useful food hit.
      if (candidate.source == NutritionFoodSearchSource.remote &&
          variantTokens.length == 1 &&
          variant.length <= 4 &&
          _brandContainsQuery(candidate.brand, variant) &&
          !_brandStartsWithQuery(candidate.brand, variant) &&
          !_displayNameStartsWithQuery(candidate.displayName, variant)) {
        return const _Evaluation(
          match: NutritionFoodSearchMatch.substring,
          lexicalScore: _remoteWeakToken,
        );
      }
      return _Evaluation(
        match: NutritionFoodSearchMatch.token,
        lexicalScore: alias
            ? _token - 20
            : firstTokenMatches
            ? _token + 12
            : _token,
      );
    }

    if (variantTokens.length == 1 &&
        displayTokens.any((token) => token.startsWith(variant))) {
      final startsName = displayTokens.first.startsWith(variant);
      return _Evaluation(
        match: NutritionFoodSearchMatch.prefix,
        lexicalScore: !startsName
            ? _innerPrefix
            : alias
            ? _prefix - 30
            : _prefix,
      );
    }
    if (displayName.contains(variant)) {
      return const _Evaluation(
        match: NutritionFoodSearchMatch.substring,
        lexicalScore: _substring,
      );
    }

    if (variant.length >= 4 && originalTokens.length <= 3) {
      final fuzzy = _fuzzyMatch(variantTokens, displayTokens);
      if (fuzzy >= _fuzzyThreshold(variant.length)) {
        return const _Evaluation(
          match: NutritionFoodSearchMatch.fuzzy,
          lexicalScore: _fuzzy,
        );
      }
    }

    final allSearchableTokensMatch =
        variantTokens.isNotEmpty &&
        variantTokens.every(
          (queryToken) => searchableTokens.any(
            (searchToken) =>
                searchToken == queryToken ||
                _safeSingular(searchToken) == _safeSingular(queryToken),
          ),
        );
    if (allSearchableTokensMatch) {
      final explicitProductIntent = _hasExplicitProductIntent(
        candidate,
        normalizedQuery,
      );
      return _Evaluation(
        match: NutritionFoodSearchMatch.token,
        lexicalScore: explicitProductIntent ? _token : _metadataToken,
      );
    }
    if (searchableText.contains(variant)) {
      return const _Evaluation(
        match: NutritionFoodSearchMatch.substring,
        lexicalScore: _metadataSubstring,
      );
    }
    return const _Evaluation.none();
  }

  static int _score(
    NutritionFoodSearchCandidate candidate,
    _Evaluation evaluation,
    String normalizedQuery,
    NutritionFoodSearchHistory history,
  ) {
    var score = evaluation.lexicalScore;
    if (candidate.source != NutritionFoodSearchSource.remote) {
      score += _localityBoost;
    } else if (!_hasExplicitProductIntent(candidate, normalizedQuery)) {
      // Provider results are useful fallback discovery, but they should not
      // displace a reviewed/local result solely because provider metadata is
      // verbose or happens to contain the query token.
      score -= _remotePenalty;
    }
    if (candidate.isCustom &&
        (evaluation.match == NutritionFoodSearchMatch.exact ||
            evaluation.match == NutritionFoodSearchMatch.aliasExact)) {
      score += _customBoost;
    }
    final brandIntent = _queryNamesBrand(candidate.brand, normalizedQuery);
    if (candidate.brand == null && !brandIntent) score += _genericBoost;

    if (candidate.hasNumericFacts) score += _factsAvailabilityBoost;
    if (NutritionFoodSearchVocabulary.isPrimaryConcept(
      query: normalizedQuery,
      canonicalFoodId: candidate.canonicalIdentityId,
    )) {
      score += _primaryConceptBoost;
    }
    if (NutritionFoodSearchVocabulary.hasPrimaryConceptCategory(
      query: normalizedQuery,
      category: candidate.category,
    )) {
      score += _primaryConceptCategoryBoost;
    }
    if (candidate.isExplicitPresentationVariant) {
      score -= _servingVariantPenalty;
    }
    if (evaluation.match != NutritionFoodSearchMatch.exact &&
        evaluation.match != NutritionFoodSearchMatch.aliasExact &&
        !NutritionFoodSearchVocabulary.queryWantsDessert(normalizedQuery) &&
        NutritionFoodSearchVocabulary.isDessert(
          displayName: candidate.displayName,
          category: candidate.category,
        )) {
      score -= _unaskedDessertPenalty;
    }
    if (candidate.source != NutritionFoodSearchSource.remote &&
        evaluation.match.index >= NutritionFoodSearchMatch.token.index) {
      final frequency = history.frequencyFor(candidate).clamp(0, 5).toInt();
      if (frequency > 0) {
        score += frequency * _historyFrequencyStep;
      }
      if (history.isRecent(candidate)) score += _historyRecentBoost;
    }
    return score;
  }

  static bool _hasExplicitProductIntent(
    NutritionFoodSearchCandidate candidate,
    String normalizedQuery,
  ) {
    if (_queryNamesBrand(candidate.brand, normalizedQuery)) return true;
    return RegExp(r'\d').hasMatch(normalizedQuery);
  }

  static bool _remotePassesThreshold(
    NutritionFoodSearchResult result,
    String normalizedQuery,
  ) {
    if (normalizedQuery.length < 3) {
      return result.match == NutritionFoodSearchMatch.exact ||
          result.match == NutritionFoodSearchMatch.aliasExact ||
          result.match == NutritionFoodSearchMatch.prefix;
    }
    if (result.match == NutritionFoodSearchMatch.fuzzy &&
        normalizedQuery.length < 5) {
      return false;
    }
    return result.score >= _remoteMinimum;
  }

  static bool _preferCandidate(
    NutritionFoodSearchResult current,
    NutritionFoodSearchResult previous,
  ) {
    if (current.score != previous.score) return current.score > previous.score;
    final currentFacts = current.candidate.hasNumericFacts ? 1 : 0;
    final previousFacts = previous.candidate.hasNumericFacts ? 1 : 0;
    if (currentFacts != previousFacts) return currentFacts > previousFacts;
    final currentSource = _sourceRank(current.candidate.source);
    final previousSource = _sourceRank(previous.candidate.source);
    if (currentSource != previousSource) return currentSource > previousSource;
    return current.candidate.deterministicKey.compareTo(
          previous.candidate.deterministicKey,
        ) <
        0;
  }

  static int _compare(
    NutritionFoodSearchResult left,
    NutritionFoodSearchResult right,
  ) {
    final score = right.score.compareTo(left.score);
    if (score != 0) return score;
    final match = right.match.index.compareTo(left.match.index);
    if (match != 0) return match;
    final name =
        NutritionFoodSearchVocabulary.normalize(
          left.candidate.displayName,
        ).compareTo(
          NutritionFoodSearchVocabulary.normalize(right.candidate.displayName),
        );
    if (name != 0) return name;
    final brand =
        NutritionFoodSearchVocabulary.normalize(
          left.candidate.brand ?? '',
        ).compareTo(
          NutritionFoodSearchVocabulary.normalize(right.candidate.brand ?? ''),
        );
    if (brand != 0) return brand;
    return left.candidate.deterministicKey.compareTo(
      right.candidate.deterministicKey,
    );
  }

  static int _sourceRank(NutritionFoodSearchSource source) => switch (source) {
    NutritionFoodSearchSource.canonical => 3,
    NutritionFoodSearchSource.legacy => 2,
    NutritionFoodSearchSource.remote => 1,
  };

  static List<String> _tokens(String value) => value.isEmpty
      ? const []
      : value.split(' ').where((token) => token.isNotEmpty).toList();

  static String _safeSingular(String token) {
    if (token.length <= 4) return token;
    if (token.endsWith('ies') && token.length > 5) {
      return '${token.substring(0, token.length - 3)}y';
    }
    if (token.endsWith('s') && !token.endsWith('ss')) {
      return token.substring(0, token.length - 1);
    }
    return token;
  }

  static double _fuzzyMatch(List<String> queryTokens, List<String> nameTokens) {
    if (queryTokens.isEmpty || nameTokens.isEmpty) return 0;
    var total = 0.0;
    for (final queryToken in queryTokens) {
      var best = 0.0;
      for (final nameToken in nameTokens) {
        // A one-edit substitution at the first letter commonly crosses food
        // concepts (`chole` -> `whole`) rather than correcting a typo.
        if (queryToken.codeUnitAt(0) != nameToken.codeUnitAt(0)) continue;
        final maxLength = queryToken.length > nameToken.length
            ? queryToken.length
            : nameToken.length;
        if (maxLength == 0) continue;
        final distance = _levenshtein(queryToken, nameToken);
        final similarity = 1 - distance / maxLength;
        if (similarity > best) best = similarity;
      }
      total += best;
    }
    return total / queryTokens.length;
  }

  static double _fuzzyThreshold(int length) => length <= 4 ? 0.78 : 0.72;

  static int _levenshtein(String left, String right) {
    if (left == right) return 0;
    if (left.isEmpty) return right.length;
    if (right.isEmpty) return left.length;
    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var row = 1; row <= left.length; row++) {
      final current = List<int>.filled(right.length + 1, 0)..[0] = row;
      for (var column = 1; column <= right.length; column++) {
        final cost = left.codeUnitAt(row - 1) == right.codeUnitAt(column - 1)
            ? 0
            : 1;
        current[column] = [
          current[column - 1] + 1,
          previous[column] + 1,
          previous[column - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
      previous = current;
    }
    return previous.last;
  }

  static bool _queryNamesBrand(String? brand, String query) {
    final cleanBrand = brand == null
        ? ''
        : NutritionFoodSearchVocabulary.normalize(brand);
    if (cleanBrand.isEmpty) return false;
    final queryTokens = _tokens(query).toSet();
    return _tokens(cleanBrand).any(queryTokens.contains);
  }

  static bool _brandContainsQuery(String? brand, String query) {
    final cleanBrand = brand == null
        ? ''
        : NutritionFoodSearchVocabulary.normalize(brand);
    return cleanBrand.isNotEmpty &&
        _tokens(cleanBrand).any((token) => token == query);
  }

  static bool _brandStartsWithQuery(String? brand, String query) {
    final cleanBrand = brand == null
        ? ''
        : NutritionFoodSearchVocabulary.normalize(brand);
    final tokens = _tokens(cleanBrand);
    return tokens.isNotEmpty && tokens.first == query;
  }

  static bool _displayNameStartsWithQuery(String displayName, String query) {
    final tokens = _tokens(
      NutritionFoodSearchVocabulary.normalize(displayName),
    );
    return tokens.isNotEmpty && tokens.first.startsWith(query);
  }
}

class _Evaluation {
  const _Evaluation({required this.match, required this.lexicalScore});

  const _Evaluation.none()
    : match = NutritionFoodSearchMatch.none,
      lexicalScore = 0;

  final NutritionFoodSearchMatch match;
  final int lexicalScore;

  int get rank => match.index;
}
