import '../database/app_database.dart';
import '../repositories/food_api_service.dart';
import '../repositories/nutrition_food_catalog_repository.dart';

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
  };

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
    final expanded = <String>{normalized};
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
  });

  factory NutritionFoodSearchCandidate.legacy(FoodItem food) {
    return NutritionFoodSearchCandidate._(
      source: NutritionFoodSearchSource.legacy,
      id: 'legacy-food-item::${food.id}',
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
    );
  }

  factory NutritionFoodSearchCandidate.canonical(NutritionFoodOption option) {
    return NutritionFoodSearchCandidate._(
      source: NutritionFoodSearchSource.canonical,
      id: option.id,
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
    );
  }

  factory NutritionFoodSearchCandidate.remote(FoodApiResult remote) {
    final stableId = NutritionFoodProviderIdentity.stableProductId(remote);
    return NutritionFoodSearchCandidate._(
      source: NutritionFoodSearchSource.remote,
      id: stableId ?? '',
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
  final String displayName;
  final String? brand;
  final String? category;
  final String? regionPack;
  final bool isCustom;
  final bool hasNumericFacts;
  final String? providerId;
  final String? packageQuantity;
  final FoodItem? food;
  final NutritionFoodOption? option;
  final FoodApiResult? remote;

  /// Only canonical IDs and stable provider IDs are trusted for dedupe.
  String? get trustedIdentityKey {
    if (source == NutritionFoodSearchSource.remote) {
      final provider = providerId;
      return provider == null ? null : 'provider::$provider';
    }
    return id.isEmpty ? null : 'canonical::$id';
  }

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
/// dominant, then bounded locality, generic-name, and facts-availability
/// tie-breaks apply. Usage history and popularity are intentionally excluded.
/// The UI consumes the ordered candidates and never exposes the score.
class NutritionFoodSearchRanking {
  const NutritionFoodSearchRanking._();

  static const int _exact = 1000;
  static const int _aliasExact = 950;
  static const int _prefix = 820;
  static const int _token = 680;
  static const int _substring = 220;
  static const int _remoteWeakToken = 175;
  static const int _fuzzy = 300;
  static const int _localityBoost = 35;
  static const int _customBoost = 30;
  static const int _genericBoost = 22;
  static const int _factsAvailabilityBoost = 12;
  static const int _remoteMinimum = 260;

  static List<NutritionFoodSearchResult> rank({
    required String query,
    required Iterable<NutritionFoodSearchCandidate> candidates,
    NutritionFoodSearchHistory history =
        const NutritionFoodSearchHistory.empty(),
    int limit = 40,
  }) {
    final normalizedQuery = NutritionFoodSearchVocabulary.normalize(query);
    if (normalizedQuery.isEmpty) return const [];
    final queryVariants = NutritionFoodSearchVocabulary.expand(normalizedQuery);
    final scored = <NutritionFoodSearchResult>[];
    final seen = <String, NutritionFoodSearchResult>{};

    for (final candidate in candidates) {
      final evaluation = _evaluate(candidate, normalizedQuery, queryVariants);
      if (evaluation.match == NutritionFoodSearchMatch.none) continue;
      final score = _score(candidate, evaluation, normalizedQuery);
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
    if (scored.length <= limit) return List.unmodifiable(scored);
    return List.unmodifiable(scored.take(limit));
  }

  static _Evaluation _evaluate(
    NutritionFoodSearchCandidate candidate,
    String normalizedQuery,
    List<String> queryVariants,
  ) {
    final name = candidate.searchableText;
    if (name.isEmpty) return const _Evaluation.none();
    final nameTokens = _tokens(name);
    final originalTokens = _tokens(normalizedQuery);
    var best = const _Evaluation.none();
    for (final variant in queryVariants) {
      final variantTokens = _tokens(variant);
      final alias = variant != normalizedQuery;
      final evaluation = _evaluateVariant(
        candidate,
        name,
        nameTokens,
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
    return best;
  }

  static _Evaluation _evaluateVariant(
    NutritionFoodSearchCandidate candidate,
    String name,
    List<String> nameTokens,
    String variant,
    List<String> variantTokens,
    List<String> originalTokens,
    bool alias,
  ) {
    // Display name is the primary identity-bearing field. Search metadata is
    // useful for discovery, but must not turn an exact food-name query into a
    // weaker token match merely because a brand/category is also present.
    final displayName = NutritionFoodSearchVocabulary.normalize(
      candidate.displayName,
    );
    if (displayName == variant) {
      return _Evaluation(
        match: alias
            ? NutritionFoodSearchMatch.aliasExact
            : NutritionFoodSearchMatch.exact,
        lexicalScore: alias ? _aliasExact : _exact,
      );
    }
    if (displayName.startsWith('$variant ')) {
      return _Evaluation(
        match: alias
            ? NutritionFoodSearchMatch.aliasExact
            : NutritionFoodSearchMatch.prefix,
        lexicalScore: alias ? _aliasExact - 30 : _prefix,
      );
    }
    if (name == variant) {
      return _Evaluation(
        match: alias
            ? NutritionFoodSearchMatch.aliasExact
            : NutritionFoodSearchMatch.exact,
        lexicalScore: alias ? _aliasExact : _exact,
      );
    }
    if (name.startsWith('$variant ')) {
      return _Evaluation(
        match: alias
            ? NutritionFoodSearchMatch.aliasExact
            : NutritionFoodSearchMatch.prefix,
        lexicalScore: alias ? _aliasExact - 30 : _prefix,
      );
    }

    final allTokensMatch =
        variantTokens.isNotEmpty &&
        variantTokens.every(
          (queryToken) => nameTokens.any(
            (nameToken) =>
                nameToken == queryToken ||
                _safeSingular(nameToken) == _safeSingular(queryToken),
          ),
        );
    if (allTokensMatch) {
      final firstTokenMatches = variantTokens.every(
        (queryToken) => nameTokens.first == queryToken,
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
        nameTokens.any((token) => token.startsWith(variant))) {
      return _Evaluation(
        match: NutritionFoodSearchMatch.prefix,
        lexicalScore: alias ? _prefix - 30 : _prefix,
      );
    }
    if (name.contains(variant)) {
      return const _Evaluation(
        match: NutritionFoodSearchMatch.substring,
        lexicalScore: _substring,
      );
    }

    if (variant.length >= 4 && originalTokens.length <= 3) {
      final fuzzy = _fuzzyMatch(variantTokens, nameTokens);
      if (fuzzy >= _fuzzyThreshold(variant.length)) {
        return const _Evaluation(
          match: NutritionFoodSearchMatch.fuzzy,
          lexicalScore: _fuzzy,
        );
      }
    }
    return const _Evaluation.none();
  }

  static int _score(
    NutritionFoodSearchCandidate candidate,
    _Evaluation evaluation,
    String normalizedQuery,
  ) {
    var score = evaluation.lexicalScore;
    if (candidate.source != NutritionFoodSearchSource.remote) {
      score += _localityBoost;
    }
    if (candidate.isCustom &&
        (evaluation.match == NutritionFoodSearchMatch.exact ||
            evaluation.match == NutritionFoodSearchMatch.aliasExact)) {
      score += _customBoost;
    }
    final brandIntent = _queryNamesBrand(candidate.brand, normalizedQuery);
    if (candidate.brand == null && !brandIntent) score += _genericBoost;

    if (candidate.hasNumericFacts) score += _factsAvailabilityBoost;
    return score;
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
    return _tokens(cleanBrand).every(queryTokens.contains);
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
