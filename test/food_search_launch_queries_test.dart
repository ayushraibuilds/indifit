import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/services/nutrition_food_search_ranking.dart';

import 'support/indifit_test_harness.dart';

/// Everyday queries against the shipped on-device catalogue, run the way the
/// food screen runs them (vocabulary expansion, name search, the catalogue
/// index, a prefix pass, then ranking). From the 12 Oct launch check; the
/// full 144-query list is in docs/audit/food-search-2026-10-12/.
Future<List<String>> _search(FoodRepository repository, String query) async {
  final byId = <int, FoodItem>{};
  var matched = <int, List<String>>{};
  for (final variant in NutritionFoodSearchVocabulary.expand(query)) {
    for (final item in await repository.searchFoodLocal(variant)) {
      byId[item.id] = item;
    }
  }
  final indexed = await repository.searchCatalogueIndex(query);
  for (final item in indexed.items) {
    byId[item.id] = item;
  }
  matched = indexed.matchedTerms;
  final normalized = NutritionFoodSearchVocabulary.normalize(query);
  if (normalized.length >= 4) {
    final first = normalized.split(' ').first;
    if (first.length >= 3) {
      for (final item in await repository.searchFoodLocal(
        first.substring(0, 3),
      )) {
        byId[item.id] = item;
      }
    }
  }
  final authority = await repository.readSearchPresentationAuthority(
    byId.keys,
  );
  return [
    for (final result in NutritionFoodSearchRanking.rank(
      query: query,
      candidates: [
        for (final food in byId.values)
          NutritionFoodSearchCandidate.legacy(
            food,
            canonicalIdentityId: authority[food.id]?.canonicalFoodId,
            presentationKind: authority[food.id]?.kind,
            variantOfFoodId: authority[food.id]?.variantOfFoodId,
            matchedTerms: matched[food.id] ?? const [],
          ),
      ],
    ))
      result.candidate.displayName,
  ];
}

void main() {
  initializeIndiFitTestHarness();

  late FoodRepository repository;

  setUpAll(() {
    repository = FoodRepository(registerTestDatabaseScope().create());
  });

  // Query → text the first result must contain.
  const firstResult = {
    'roti': 'Whole Wheat Roti',
    'chapati': 'Whole Wheat Roti',
    'chappati': 'Whole Wheat Roti',
    'रोटी': 'Whole Wheat Roti',
    'दाल': 'Dal',
    'पनीर': 'Paneer',
    'dal': 'Dal',
    'rice': 'Rice',
    'curd': 'Curd',
    'dahi': 'Curd',
    'paneer': 'Paneer',
    'panir': 'Paneer',
    'egg': 'Egg',
    'poha': 'Poha',
    'idli': 'Idli',
    'masala dosa': 'Masala Dosa',
    'rajma': 'Rajma',
    'chole': 'Chole',
    'palak paneer': 'Palak Paneer',
    'butter chicken': 'Butter Chicken',
    'chicken biryani': 'Biryani',
    'samosa': 'Samosa',
    'vada pav': 'Vada Pav',
    'pav bhaji': 'Pav Bhaji',
    'lassi': 'Lassi',
    'milk': 'Milk',
  };

  for (final MapEntry(key: query, value: expected) in firstResult.entries) {
    test('"$query" leads with $expected', () async {
      final results = await _search(repository, query);
      expect(results, isNotEmpty);
      expect(results.first, contains(expected));
    });
  }

  // Wrong foods that used to come first: a different first letter, or a
  // word that only starts a longer one, is not a match.
  const neverFirst = {
    'laddu': 'Kaddu',
    'kachori': 'Achari',
    'panir': 'Nimbu Pani',
    'egg': 'eggplant',
    'curd': 'Papdi Chaat',
  };

  for (final MapEntry(key: query, value: wrong) in neverFirst.entries) {
    test('"$query" never leads with $wrong', () async {
      final results = await _search(repository, query);
      if (results.isEmpty) return;
      expect(results.first, isNot(contains(wrong)));
    });
  }
}
