import '../catalog/catalog_search_index.dart';
import '../database/app_database.dart';
import '../repositories/food_repository.dart';
import '../repositories/nutrition_food_catalog_repository.dart';
import 'food_query_amount.dart';
import 'nutrition_food_search_ranking.dart';

/// What a typed search resolved to: the words searched and any amount.
class ResolvedFoodSearch {
  const ResolvedFoodSearch({
    required this.typed,
    required this.query,
    this.amount,
    this.relaxed = false,
  });

  /// As typed.
  final String typed;

  /// The words searched: without the amount, and with one word dropped
  /// when the whole search matched nothing ([relaxed]).
  final String query;
  final FoodQueryAmount? amount;
  final bool relaxed;
}

/// The on-device food search, in one place for the food screen and the
/// search tests (UR-01, UR-03; part of UR-52): name search over every
/// vocabulary variant, the catalogue index, a prefix pass, catalogue-only
/// foods, then ranking.
class FoodSearchPipeline {
  FoodSearchPipeline(this._repository, {required this.optionFor});

  final FoodRepository _repository;

  /// The catalogue option for a food the index found without a legacy row.
  final Future<NutritionFoodOption?> Function(String foodId) optionFor;

  /// Legacy `food_items` rows for [query], with the index's matched terms.
  Future<({List<FoodItem> items, Map<int, List<String>> matchedTerms})>
  legacyHits(String query) async {
    final byId = <int, FoodItem>{};
    final matched = <int, List<String>>{};
    final normalized = NutritionFoodSearchVocabulary.normalize(query);
    final variants = NutritionFoodSearchVocabulary.expand(query);
    for (final variant in variants) {
      try {
        for (final item in await _repository.searchFoodLocal(variant)) {
          byId[item.id] = item;
        }
      } catch (_) {
        // Safe: one vocabulary variant must not block the others.
      }
    }
    // The index needs every word, so it too gets each variant: "veg
    // pulao" reaches "Vegetable Pulao" only as "vegetable pulao".
    for (final variant in variants) {
      try {
        final indexed = await _repository.searchCatalogueIndex(variant);
        for (final item in indexed.items) {
          byId[item.id] = item;
        }
        for (final entry in indexed.matchedTerms.entries) {
          matched.putIfAbsent(entry.key, () => entry.value);
        }
      } catch (_) {
        // Safe: the name search above still answers without the index.
      }
    }
    if (normalized.length >= 4) {
      final firstToken = normalized.split(' ').first;
      if (firstToken.length >= 3) {
        try {
          for (final item in await _repository.searchFoodLocal(
            firstToken.substring(0, 3),
          )) {
            byId[item.id] = item;
          }
        } catch (_) {
          // Safe: the other passes still answer.
        }
      }
    }
    return (items: byId.values.toList(growable: false), matchedTerms: matched);
  }

  /// Catalogue foods without a legacy row, for every vocabulary variant.
  Future<List<(NutritionFoodOption, CatalogSearchHit)>> catalogueOnly(
    String query,
  ) async {
    final found = <String, (NutritionFoodOption, CatalogSearchHit)>{};
    for (final variant in NutritionFoodSearchVocabulary.expand(query)) {
      for (final hit in await _repository.searchCatalogueOnlyFoods(variant)) {
        if (found.containsKey(hit.foodId)) continue;
        final option = await optionFor(hit.foodId);
        if (option != null) found[hit.foodId] = (option, hit);
      }
    }
    return found.values.toList(growable: false);
  }

  /// Every on-device candidate for [query].
  Future<List<NutritionFoodSearchCandidate>> candidates(String query) async {
    final legacy = await legacyHits(query);
    Map<int, FoodSearchPresentationAuthority> authority = const {};
    try {
      authority = await _repository.readSearchPresentationAuthority(
        legacy.items.map((food) => food.id),
      );
    } catch (_) {
      // Safe: presentation metadata fails open.
    }
    return [
      for (final (option, hit) in await catalogueOnly(query))
        NutritionFoodSearchCandidate.canonical(
          option,
          matchedTerms: hit.matchedTerms,
          alternateNames: [
            ...hit.aliasNames,
            if (hit.aliases.isNotEmpty) hit.aliasText,
          ],
        ),
      for (final food in legacy.items)
        NutritionFoodSearchCandidate.legacy(
          food,
          canonicalIdentityId: authority[food.id]?.canonicalFoodId,
          presentationKind: authority[food.id]?.kind,
          variantOfFoodId: authority[food.id]?.variantOfFoodId,
          matchedTerms: legacy.matchedTerms[food.id] ?? const [],
        ),
    ];
  }

  Future<List<NutritionFoodSearchResult>> rank(String query) async =>
      NutritionFoodSearchRanking.rank(
        query: query,
        candidates: await candidates(query),
        oneRowPerDish: true,
      );

  /// Splits the amount off [typed] and picks the words to search.
  ///
  /// A bare number counts as an amount only when the rest still finds a
  /// food and no food is named with the number ("7 Up"). When the whole
  /// search finds nothing, one word is dropped: the drop whose best match
  /// is the closest kind of match, then scores highest, then is the rarer
  /// word; the last word (usually the dish) is kept on a full tie.
  Future<ResolvedFoodSearch> resolve(String typed) async {
    final parsed = FoodQueryParser.parse(typed);
    var query = parsed.food;
    var amount = parsed.amount;
    var ranked = <NutritionFoodSearchResult>[];
    if (parsed.bareNumber) {
      final whole = await rank(parsed.original);
      final wholeName = NutritionFoodSearchVocabulary.normalize(
        parsed.original,
      );
      final named =
          whole.isNotEmpty &&
          NutritionFoodSearchVocabulary.normalize(
            whole.first.candidate.displayName,
          ).startsWith(wholeName);
      ranked = named ? const [] : await rank(parsed.food);
      // "up" only starts "Upma": "7 up" stays a name.
      if (named || ranked.isEmpty || !_namesFood(ranked.first, parsed.food)) {
        query = parsed.original;
        amount = null;
        ranked = whole;
      }
    } else {
      ranked = await rank(query);
    }
    if (ranked.isNotEmpty) {
      return ResolvedFoodSearch(typed: typed, query: query, amount: amount);
    }
    // "7 up" is a product name: online search may know it, a guess won't.
    final relaxed = parsed.bareNumber && amount == null
        ? null
        : await dropOneWord(query);
    return ResolvedFoodSearch(
      typed: typed,
      query: relaxed ?? query,
      amount: amount,
      relaxed: relaxed != null,
    );
  }

  static const int _relaxedMinimumScore = 600;

  /// Whether [result]'s name has every word of [query] (or of one of its
  /// vocabulary variants) as a whole word, singular or plural.
  static bool _namesFood(NutritionFoodSearchResult result, String query) {
    String singular(String token) => token.length > 3 && token.endsWith('s')
        ? token.substring(0, token.length - 1)
        : token;
    final names = [
      result.candidate.displayName,
      ...result.candidate.alternateNames,
    ];
    final words = {
      for (final name in names)
        for (final token in NutritionFoodSearchVocabulary.expand(
          name,
        ).first.split(' '))
          singular(token),
    };
    return NutritionFoodSearchVocabulary.expand(query).any(
      (variant) => variant
          .split(' ')
          .where((token) => token.isNotEmpty)
          .every((token) => words.contains(singular(token))),
    );
  }

  /// Words dropped first: fillers, and describing words that rarely name
  /// the dish ("green chutney" is a chutney, not green tea).
  static const Set<String> _fillerWords = {
    'ki',
    'ka',
    'ke',
    'with',
    'and',
    'of',
    'the',
    'green',
    'red',
    'fried',
    'grilled',
    'plain',
    'homemade',
    'home',
    'spicy',
    'hot',
    'healthy',
  };

  /// [query] with one word dropped, when that finds a food by name; null
  /// when no drop does.
  Future<String?> dropOneWord(String query) async {
    final tokens = NutritionFoodSearchVocabulary.normalize(
      query,
    ).split(' ').where((token) => token.isNotEmpty).toList();
    if (tokens.length < 2) return null;
    String? best;
    NutritionFoodSearchResult? bestTop;
    var bestCount = 0;
    var bestKeepsLast = false;
    // Filler words go first; then each word, last word kept longest.
    final order = [
      for (var i = 0; i < tokens.length; i++)
        if (_fillerWords.contains(tokens[i])) i,
      for (var i = 0; i < tokens.length; i++)
        if (!_fillerWords.contains(tokens[i])) i,
    ];
    for (final index in order) {
      final candidate = [
        for (var i = 0; i < tokens.length; i++)
          if (i != index) tokens[i],
      ].join(' ');
      if (!RegExp(r'[^\d\s]').hasMatch(candidate)) continue;
      final ranked = await rank(candidate);
      // Only a match on the food's own name counts, by whole words: not
      // its metadata ("bar" in a category), nor "up" starting "Upma".
      if (ranked.isEmpty ||
          ranked.first.match.index < NutritionFoodSearchMatch.token.index ||
          ranked.first.score < _relaxedMinimumScore ||
          !_namesFood(ranked.first, candidate)) {
        continue;
      }
      if (_fillerWords.contains(tokens[index])) return candidate;
      // A food named by the words left ("Plain Dosa" for "dosa") beats one
      // that only starts with them ("Cheese Slice" for "cheese"). When both
      // name a food, the last word is the dish ("cheese dosa" is a dosa).
      // Then the rarer word wins: "prawn" over "curry".
      final top = ranked.first;
      final keepsLast = index != tokens.length - 1;
      final better =
          bestTop == null ||
          top.match.index > bestTop.match.index ||
          (top.match == bestTop.match &&
              (keepsLast != bestKeepsLast
                  ? keepsLast
                  : top.score > bestTop.score ||
                        (top.score == bestTop.score &&
                            ranked.length < bestCount)));
      if (better) {
        bestTop = top;
        bestCount = ranked.length;
        bestKeepsLast = keepsLast;
        best = candidate;
      }
    }
    return best;
  }

  /// Resolves [typed] and ranks what it finds.
  Future<(ResolvedFoodSearch, List<NutritionFoodSearchResult>)> search(
    String typed,
  ) async {
    final resolved = await resolve(typed);
    return (resolved, await rank(resolved.query));
  }
}
