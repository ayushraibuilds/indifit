import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_api_service.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/data/services/nutrition_food_search_ranking.dart';

void main() {
  group('R07D-2 food search vocabulary and normalization', () {
    test(
      'normalization preserves numeric/package intent and aliases are bounded',
      () {
        expect(
          NutritionFoodSearchVocabulary.normalize('  Amul 200g,  Paneer  '),
          'amul 200g paneer',
        );
        expect(
          NutritionFoodSearchVocabulary.expand('dahi'),
          containsAll(<String>['dahi', 'curd']),
        );
        expect(
          NutritionFoodSearchVocabulary.expand('poha'),
          containsAll(<String>['poha', 'flattened rice', 'beaten rice']),
        );
        expect(
          NutritionFoodSearchVocabulary.expand('curry'),
          equals(const ['curry']),
        );
      },
    );
  });

  group('R07D-2 deterministic relevance matrix', () {
    test('exact poha outranks weaker lexical matches', () {
      final results = _rank(
        'poha',
        candidates: [
          _food('Poha (Flattened Rice)', 1),
          _food('Poha side bowl', 2),
          _remote('Bon Appé brownie cookies', providerId: 'appe-1'),
        ],
      );

      expect(results.first.candidate.displayName, 'Poha (Flattened Rice)');
    });

    test('pane prefix ranks Paneer above unrelated remote products', () {
      final results = _rank(
        'pane',
        candidates: [
          _remote('Protein snack product', providerId: 'remote-1'),
          _food('Paneer', 1),
          _food('Paneer bhurji', 2),
        ],
      );

      expect(results.take(2).map((item) => item.candidate.displayName), [
        'Paneer',
        'Paneer bhurji',
      ]);
    });

    test('generic milk wins generic intent while brand intent admits Amul', () {
      final generic = _food('Milk', 1);
      final branded = _remote(
        'Amul Taaza Milk',
        providerId: 'amul-1',
        brand: 'Amul',
      );

      expect(
        _rank('milk', candidates: [branded, generic]).first.candidate,
        same(generic),
      );
      expect(
        _rank('amul milk', candidates: [generic, branded]).first.candidate,
        same(branded),
      );
    });

    test(
      'safe dahi and chapati retrieval vocabulary does not merge identity',
      () {
        final curd = _food('Curd', 1);
        final chapati = _food('Whole Wheat Chapati', 2);

        expect(_rank('dahi', candidates: [curd]).single.candidate, same(curd));
        expect(
          _rank('roti', candidates: [chapati]).single.candidate,
          same(chapati),
        );
        expect(curd.id, isNot(chapati.id));
      },
    );

    test(
      'bounded typo tolerance finds paner and bananna without fuzzy flooding',
      () {
        final results = _rank(
          'paner',
          candidates: [
            _food('Paneer', 1),
            _food('Banana', 2),
            _remote('Random pantry product', providerId: 'random-1'),
          ],
        );
        expect(results.first.candidate.displayName, 'Paneer');

        final banana = _rank('bananna', candidates: [_food('Banana', 2)]);
        expect(banana.single.candidate.displayName, 'Banana');
      },
    );

    test('appe-style weak provider brand token is suppressed', () {
      final results = _rank(
        'appe',
        candidates: [
          _remote(
            'Bon Appe, mini brownie cookies',
            providerId: 'bon-appe-1',
            brand: 'Bon Appe',
          ),
          _food('Apple', 1),
        ],
      );

      expect(results.first.candidate.displayName, 'Apple');
      expect(
        results.any(
          (result) =>
              result.candidate.displayName == 'Bon Appe, mini brownie cookies',
        ),
        isFalse,
      );
    });

    test('history boosts only an already relevant food and stays bounded', () {
      final milk = _food('Milk', 1);
      final rice = _food('Rice', 2);
      final history = NutritionFoodSearchHistory(
        frequencyByIdentity: {'canonical::legacy-food-item::2': 99},
        recentIdentities: const {'canonical::legacy-food-item::2'},
      );

      final milkResults = _rank(
        'milk',
        candidates: [milk, rice],
        history: history,
      );
      expect(milkResults.single.candidate.displayName, 'Milk');

      final exact = _food('Milk', 3);
      final weak = _food('Milk chocolate drink', 4);
      final bounded = _rank(
        'milk',
        candidates: [exact, weak],
        history: NutritionFoodSearchHistory(
          frequencyByIdentity: {'canonical::legacy-food-item::4': 99},
          recentIdentities: const {'canonical::legacy-food-item::4'},
        ),
      );
      expect(bounded.first.candidate.displayName, 'Milk');
    });

    test('custom exact match is strong without merging provider identity', () {
      final custom = _canonical(
        'My Family Poha',
        'custom-poha',
        isCustom: true,
      );
      final provider = _remote('My Family Poha', providerId: 'provider-poha');
      final results = _rank('my family poha', candidates: [custom, provider]);

      expect(results.first.candidate, same(custom));
      expect(results, hasLength(2));
    });

    test('raw/cooked variants remain distinct and cooked intent wins', () {
      final raw = _food('Raw Rice', 1);
      final cooked = _food('Cooked Rice', 2);

      final cookedResults = _rank('cooked rice', candidates: [raw, cooked]);
      expect(cookedResults.first.candidate, same(cooked));

      final riceResults = _rank('rice', candidates: [raw, cooked]);
      expect(
        riceResults.map((item) => item.candidate.displayName),
        containsAll(<String>['Raw Rice', 'Cooked Rice']),
      );
    });

    test('one canonical identity and one provider identity dedupe safely', () {
      final legacy = _food('Paneer', 1);
      final canonical = _canonical('Paneer', 'legacy-food-item::1');
      final remoteOne = _remote('Paneer product', providerId: 'provider-1');
      final remoteDuplicate = _remote(
        'Paneer product renamed',
        providerId: 'provider-1',
      );
      final sameNameDifferentIdentity = _food('Paneer', 2);

      final results = _rank(
        'paneer',
        candidates: [
          remoteDuplicate,
          canonical,
          sameNameDifferentIdentity,
          remoteOne,
          legacy,
        ],
      );

      expect(
        results.where((item) => item.candidate.id == 'legacy-food-item::1'),
        hasLength(1),
      );
      expect(
        results.where((item) => item.candidate.providerId == 'provider-1'),
        hasLength(1),
      );
      expect(
        results.where((item) => item.candidate.displayName == 'Paneer'),
        hasLength(2),
      );
    });

    test('short queries do not activate fuzzy provider noise', () {
      final results = _rank(
        'ap',
        candidates: [
          _remote('Xaple snack', providerId: 'fuzzy-1'),
          _remote('Apple', providerId: 'prefix-1'),
        ],
      );

      expect(results.map((item) => item.candidate.displayName), ['Apple']);
    });

    test('ordering is independent of provider response order', () {
      final candidates = [
        _remote('Remote Paneer', providerId: 'r-paneer'),
        _food('Paneer', 1),
        _food('Paneer bhurji', 2),
      ];
      final forward = _rank(
        'pane',
        candidates: candidates,
      ).map((item) => item.candidate.deterministicKey).toList();
      final reverse = _rank(
        'pane',
        candidates: candidates.reversed,
      ).map((item) => item.candidate.deterministicKey).toList();
      expect(reverse, forward);
    });
  });
}

List<NutritionFoodSearchResult> _rank(
  String query, {
  required Iterable<NutritionFoodSearchCandidate> candidates,
  NutritionFoodSearchHistory history = const NutritionFoodSearchHistory.empty(),
}) => NutritionFoodSearchRanking.rank(
  query: query,
  candidates: candidates,
  history: history,
);

NutritionFoodSearchCandidate _food(
  String name,
  int id, {
  String? brand,
  bool isCustom = false,
}) => NutritionFoodSearchCandidate.legacy(
  FoodItem(
    id: id,
    name: name,
    calories: 120,
    proteinG: 5,
    carbsG: 20,
    fatG: 3,
    fiberG: 2,
    servingSize: 1,
    servingUnit: 'serving',
    category: 'Indian',
    isCustom: isCustom,
    brand: brand,
  ),
);

NutritionFoodSearchCandidate _remote(
  String name, {
  required String providerId,
  String? brand,
}) => NutritionFoodSearchCandidate.remote(
  FoodApiResult(
    name: name,
    calories: 120,
    protein: 5,
    carbs: 20,
    fat: 3,
    servingSize: 100,
    servingUnit: 'g',
    providerId: providerId,
    barcode: providerId,
    brand: brand,
  ),
);

NutritionFoodSearchCandidate _canonical(
  String name,
  String id, {
  bool isCustom = false,
}) => NutritionFoodSearchCandidate.canonical(
  NutritionFoodOption(
    id: id,
    displayName: name,
    baseQuantity: Quantity.fromDecimal(amount: '1', unit: QuantityUnit.gram),
    facts: const {},
    sourceType: isCustom ? 'user' : 'reviewed_catalogue',
    sourceReference: 'test:$id',
    preparationId: null,
  ),
);
