import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_api_service.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/services/nutrition_food_search_ranking.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reviewed B03 presentation authority is read-only and explicit',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final repository = FoodRepository(db);
      await repository.logFoodEntry(
        name: 'Historical Roti',
        calories: 120,
        proteinG: 4,
        carbsG: 20,
        fatG: 2,
        servingLogged: 1,
        servingUnit: 'piece',
        mealType: 'lunch',
        foodItemId: 1,
      );
      final before = (await db.select(db.foodLogs).get()).single;

      final authority = await repository.readSearchPresentationAuthority([
        1,
        117,
        118,
      ]);

      expect(authority[1]?.canonicalFoodId, 'food-seed-0564');
      expect(authority[1]?.kind, 'canonical');
      expect(authority[117]?.kind, 'servingPresentationVariant');
      expect(authority[117]?.variantOfFoodId, 'food-seed-0564');
      expect(authority[118]?.kind, 'preparationVariant');
      final after = (await db.select(db.foodLogs).get()).single;
      expect(after.uuid, before.uuid);
      expect(after.name, before.name);
      expect(after.foodItemId, before.foodItemId);
    },
  );

  test('shipped catalogue satisfies the common food concept matrix', () {
    final candidates = _catalogueCandidates();
    final matrix = {
      for (final query in const [
        'roti',
        'chapati',
        'dal',
        'rice',
        'poha',
        'dosa',
        'paneer',
        'chana',
        'chole',
      ])
        query: _rank(query, candidates).take(5).toList(growable: false),
    };
    expect(
      matrix['roti']!.first.candidate.displayName,
      'Whole Wheat Roti / Chapati',
    );
    expect(
      matrix['chapati']!.first.candidate.displayName,
      'Whole Wheat Roti / Chapati',
    );
    expect(
      matrix['roti']!.take(5),
      everyElement(
        predicate<NutritionFoodSearchResult>(
          (result) => !result.candidate.isExplicitPresentationVariant,
        ),
      ),
    );

    final dalTop = matrix['dal']!;
    expect(
      dalTop,
      everyElement(
        predicate<NutritionFoodSearchResult>((result) {
          final tokens = NutritionFoodSearchVocabulary.normalize(
            result.candidate.displayName,
          ).split(' ');
          return tokens.contains('dal');
        }),
      ),
    );
    expect(
      dalTop.map((result) => result.candidate.displayName),
      isNot(contains(startsWith('Chana Masala'))),
    );
    expect(
      dalTop.map((result) => result.candidate.displayName),
      isNot(contains(startsWith('Chole Masala'))),
    );
    expect(
      dalTop,
      everyElement(
        predicate<NutritionFoodSearchResult>(
          (result) => !result.candidate.isExplicitPresentationVariant,
        ),
      ),
    );

    expect(matrix['rice']!.first.candidate.displayName, contains('Rice'));
    expect(matrix['poha']!.first.candidate.displayName, startsWith('Poha'));
    expect(matrix['dosa']!.first.candidate.displayName, contains('Dosa'));
    expect(matrix['paneer']!.first.candidate.displayName, contains('Paneer'));
    expect(matrix['chana']!.first.candidate.displayName, startsWith('Chana'));
    expect(matrix['chole']!.first.candidate.displayName, startsWith('Chole'));
    expect(
      matrix['chole']!.map((result) => result.candidate.displayName),
      everyElement(startsWith('Chole')),
    );

    for (final entry in matrix.entries) {
      final identities = entry.value
          .map((result) => result.candidate.trustedIdentityKey)
          .toSet();
      expect(identities, hasLength(entry.value.length), reason: entry.key);
    }
  });

  test('only explicit B03 variants receive presentation de-prioritization', () {
    final base = _foodCandidate(
      'Chana Masala',
      1,
      canonicalId: 'food-chana-base',
      kind: 'canonical',
    );
    final reviewedVariant = _foodCandidate(
      'Chana Masala (Double serving)',
      2,
      canonicalId: 'food-chana-double',
      kind: 'servingPresentationVariant',
      parentId: 'food-chana-base',
    );
    final unresolvedLookalike = _foodCandidate(
      'Chana Masala (Family recipe)',
      3,
    );

    final results = _rank('chana', [
      reviewedVariant,
      unresolvedLookalike,
      base,
    ]);

    expect(results.first.candidate, same(base));
    expect(
      results.indexWhere((result) => result.candidate == reviewedVariant),
      greaterThan(
        results.indexWhere((result) => result.candidate == unresolvedLookalike),
      ),
    );
    expect(base.trustedIdentityKey, isNot(reviewedVariant.trustedIdentityKey));
  });

  test('provider identity dedupe preserves distinct package records', () {
    final pack555 = _providerRoti('8992907953270', '555 g');
    final pack370 = _providerRoti('8992907110017', '370 g');
    final results = _rank('roti', [pack555, pack370, pack555]);

    expect(results, hasLength(2));
    expect(results.map((result) => result.candidate.providerId).toSet(), {
      '8992907953270',
      '8992907110017',
    });
    expect(results.map((result) => result.candidate.packageQuantity).toSet(), {
      '555 g',
      '370 g',
    });
  });

  test('full local catalogue ranking remains bounded', () {
    final candidates = _catalogueCandidates();
    final stopwatch = Stopwatch()..start();
    for (final query in const [
      'roti',
      'chapati',
      'dal',
      'rice',
      'poha',
      'dosa',
      'paneer',
      'chana',
      'chole',
    ]) {
      expect(_rank(query, candidates), isNotEmpty);
    }
    stopwatch.stop();

    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
  });
}

List<NutritionFoodSearchCandidate> _catalogueCandidates() {
  final foods =
      jsonDecode(File('assets/data/indian_foods.json').readAsStringSync())
          as List<dynamic>;
  final manifest = Map<String, dynamic>.from(
    jsonDecode(
          File(
            'assets/data/nutrition_food_identity_manifest.json',
          ).readAsStringSync(),
        )
        as Map,
  );
  final mappings = <int, String>{
    for (final raw in manifest['legacy_mappings'] as List<dynamic>)
      if ((raw as Map)['legacy_local_id'] != null && raw['target_id'] != null)
        raw['legacy_local_id'] as int: raw['target_id'] as String,
  };
  final entries = <String, Map<dynamic, dynamic>>{
    for (final raw in manifest['entries'] as List<dynamic>)
      (raw as Map)['id'] as String: raw,
  };

  return [
    for (var index = 0; index < foods.length; index++)
      (() {
        final legacyId = index + 1;
        final canonicalId = mappings[legacyId];
        final entry = canonicalId == null ? null : entries[canonicalId];
        return NutritionFoodSearchCandidate.legacy(
          _food(foods[index] as Map, legacyId),
          canonicalIdentityId: canonicalId,
          presentationKind: entry?['kind'] as String?,
          variantOfFoodId: entry?['parent_id'] as String?,
        );
      })(),
  ];
}

List<NutritionFoodSearchResult> _rank(
  String query,
  Iterable<NutritionFoodSearchCandidate> candidates,
) => NutritionFoodSearchRanking.rank(query: query, candidates: candidates);

NutritionFoodSearchCandidate _foodCandidate(
  String name,
  int id, {
  String? canonicalId,
  String? kind,
  String? parentId,
}) => NutritionFoodSearchCandidate.legacy(
  FoodItem(
    id: id,
    name: name,
    calories: 180,
    proteinG: 8,
    carbsG: 24,
    fatG: 6,
    servingSize: 1,
    servingUnit: 'katori',
    category: 'Dals & Legumes',
    isCustom: false,
  ),
  canonicalIdentityId: canonicalId,
  presentationKind: kind,
  variantOfFoodId: parentId,
);

NutritionFoodSearchCandidate _providerRoti(String id, String package) =>
    NutritionFoodSearchCandidate.remote(
      FoodApiResult(
        name: 'Roti Tawar',
        calories: 270,
        protein: 8.11,
        carbs: 47.3,
        fat: 4.05,
        servingSize: 100,
        servingUnit: 'g',
        barcode: id,
        providerId: id,
        brand: 'Sari Roti',
        packageQuantity: package,
      ),
    );

FoodItem _food(Map<dynamic, dynamic> raw, int id) => FoodItem(
  id: id,
  name: raw['name'] as String,
  nameHindi: raw['name_hindi'] as String?,
  calories: raw['calories'] as int,
  proteinG: (raw['protein_g'] as num).toDouble(),
  carbsG: (raw['carbs_g'] as num).toDouble(),
  fatG: (raw['fat_g'] as num).toDouble(),
  fiberG: (raw['fiber_g'] as num?)?.toDouble() ?? 0,
  servingSize: (raw['serving_size'] as num).toDouble(),
  servingUnit: raw['serving_unit'] as String,
  category: raw['category'] as String,
  isCustom: false,
);
