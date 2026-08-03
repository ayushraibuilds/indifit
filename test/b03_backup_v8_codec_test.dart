import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_file_adapter.dart';
import 'package:indifit/core/backup/backup_v8.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('v8 export is deterministic and excludes catalogue seed rows', () async {
    final source = AppDatabase.memory();
    addTearDown(source.close);
    await _populateNutritionGraph(source);

    final backup = await BackupV8Data.createFromDatabase(source);
    final first = jsonEncode(backup.nutrition.toJson());
    final second = jsonEncode(backup.nutrition.toJson());

    expect(backup.version, 8);
    expect(backup.schemaVersion, 17);
    expect(first, second);
    expect(
      backup.nutrition.tables['nutrition_foods']!.map((row) => row['id']),
      contains('v8-user-food'),
    );
    expect(
      backup.nutrition.tables['nutrition_foods']!.map((row) => row['kind']),
      isNot(contains('canonical')),
    );
  });

  test(
    'v8 envelope export and inspection preserve the typed payload',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await _populateNutritionGraph(db);
      final backup = await BackupV8Data.createFromDatabase(db);
      final envelope = BackupFileAdapter.exportV8ToEnvelopeJson(data: backup);
      final inspection = await BackupFileAdapter.inspectBackupContent(envelope);

      expect(inspection.envelope.version, 8);
      expect(inspection.backupV8Data, isNotNull);
      expect(
        inspection.backupV8Data!.nutrition.tables['nutrition_foods'],
        isNotEmpty,
      );
    },
  );

  test(
    'v8 round-trip preserves portable nutrition graph and preferences',
    () async {
      final source = AppDatabase.memory();
      final target = AppDatabase.memory();
      addTearDown(source.close);
      addTearDown(target.close);
      await _populateNutritionGraph(source);
      SharedPreferences.setMockInitialValues({'water_logged': 7});
      final sourcePrefs = await SharedPreferences.getInstance();
      final backup = await BackupV8Data.createFromDatabase(source, sourcePrefs);
      final decoded = BackupV8Data.fromJson(
        jsonDecode(jsonEncode(backup.toJson())) as Map<String, dynamic>,
      );

      SharedPreferences.setMockInitialValues({'water_logged': 2});
      final targetPrefs = await SharedPreferences.getInstance();
      await decoded.restoreToDatabase(target, targetPrefs);

      expect(targetPrefs.getInt('water_logged'), 7);
      expect(
        (await target.select(target.nutritionFoods).get()).where(
          (row) => row.id == 'v8-user-food',
        ),
        hasLength(1),
      );
      expect(await target.select(target.nutritionRecipes).get(), hasLength(1));
      expect(
        (await target.select(target.nutritionRecipes).get())
            .single
            .currentVersionId,
        'v8-recipe-v1',
      );
      expect(
        await target.select(target.nutritionRecipeIngredients).get(),
        hasLength(1),
      );
      expect(
        (await target.select(target.nutritionFoods).get()).where(
          (row) => row.id == 'a-v8-child',
        ),
        hasLength(1),
      );
      expect(
        (await target.select(target.nutritionEstimates).get()).where(
          (row) => row.supersedesId == 'z-v8-estimate-parent',
        ),
        hasLength(1),
      );
      expect(
        await target.select(target.nutritionConsumptionSnapshots).get(),
        hasLength(1),
      );
      expect(
        await target.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test(
    'v8 prevalidation rejects newer versions and missing references atomically',
    () async {
      final source = AppDatabase.memory();
      final target = AppDatabase.memory();
      addTearDown(source.close);
      addTearDown(target.close);
      await _populateNutritionGraph(source);
      final valid = await BackupV8Data.createFromDatabase(source);
      final missing =
          jsonDecode(jsonEncode(valid.toJson())) as Map<String, dynamic>;
      final tables =
          (missing['nutrition_graph'] as Map<String, dynamic>)['tables']
              as Map<String, dynamic>;
      final ingredients = tables['nutrition_recipe_ingredients'] as List;
      (ingredients.single as Map<String, dynamic>)['food_id'] = 'missing-food';
      final invalid = BackupV8Data.fromJson(missing);
      expect(
        () => invalid.restoreToDatabase(target),
        throwsA(isA<BackupV8ValidationException>()),
      );
      expect(
        () => BackupV8Data.fromJson({'version': 9}),
        throwsA(
          isA<BackupV8ValidationException>().having(
            (error) => error.code,
            'code',
            'unsupported_newer_version',
          ),
        ),
      );
      final registryRows =
          jsonDecode(jsonEncode(valid.toJson())) as Map<String, dynamic>;
      final registryTables =
          (registryRows['nutrition_graph'] as Map<String, dynamic>)['tables']
              as Map<String, dynamic>;
      registryTables['nutrition_nutrient_definitions'] = <dynamic>[];
      expect(
        () => BackupV8Data.fromJson(registryRows),
        throwsA(
          isA<BackupV8ValidationException>().having(
            (error) => error.code,
            'code',
            'registry_rows_not_exportable',
          ),
        ),
      );
      final duplicate =
          jsonDecode(jsonEncode(valid.toJson())) as Map<String, dynamic>;
      final duplicateTables =
          (duplicate['nutrition_graph'] as Map<String, dynamic>)['tables']
              as Map<String, dynamic>;
      duplicateTables['nutrition_food_aliases'] = [
        {
          'id': 'v8-alias-1',
          'food_id': 'v8-user-food',
          'alias': 'same',
          'normalized_alias': 'same',
          'locale': 'en-IN',
          'source': 'user',
          'confidence': null,
          'is_active': 1,
          'created_at': 0,
          'updated_at': 0,
        },
        {
          'id': 'v8-alias-2',
          'food_id': 'v8-user-food',
          'alias': 'same 2',
          'normalized_alias': 'same',
          'locale': 'en-IN',
          'source': 'user',
          'confidence': null,
          'is_active': 1,
          'created_at': 0,
          'updated_at': 0,
        },
      ];
      expect(
        () => BackupV8Data.fromJson(duplicate),
        throwsA(
          isA<BackupV8ValidationException>().having(
            (error) => error.code,
            'code',
            'duplicate_unique_relationship',
          ),
        ),
      );
      await target
          .into(target.workoutRoutines)
          .insert(WorkoutRoutinesCompanion.insert(name: 'sentinel', goal: 'x'));
      expect(
        (await target.select(target.workoutRoutines).get()).single.name,
        'sentinel',
      );
    },
  );

  test('v5, v6 and v7 imports remain legacy-only', () async {
    final source = AppDatabase.memory();
    addTearDown(source.close);
    final current = await BackupV8Data.createFromDatabase(source);
    final base =
        jsonDecode(jsonEncode(current.toJson())) as Map<String, dynamic>;
    base.remove('nutrition_graph');
    for (final version in [5, 6, 7]) {
      final payload = Map<String, dynamic>.from(base)..['version'] = version;
      if (version < 7) {
        for (final key in const [
          'exercise_groups',
          'exercise_group_members',
          'strength_set_prescriptions',
          'cardio_session_details',
          'cardio_intervals',
          'mobility_session_details',
          'performed_exercise_groups',
          'performed_exercises',
          'exercise_target_recommendations',
          'performed_sets',
          'performed_set_segments',
          'performed_rest_periods',
          'muscles',
          'exercise_muscle_mappings',
        ]) {
          payload.remove(key);
        }
      }
      final imported = BackupV8Data.fromJson(payload);
      expect(imported.version, version);
      expect(imported.nutrition.tables, isEmpty);
    }
  });

  test(
    'v8 restore rolls back nutrition rows and preferences, then retries',
    () async {
      final source = AppDatabase.memory();
      final target = AppDatabase.memory();
      addTearDown(source.close);
      addTearDown(target.close);
      await _populateNutritionGraph(source);
      final backup = await BackupV8Data.createFromDatabase(source);
      await target
          .into(target.nutritionFoods)
          .insert(
            NutritionFoodsCompanion.insert(
              id: 'v8-sentinel-food',
              kind: 'userCreated',
              displayName: 'Sentinel',
              locale: 'en-IN',
              sourceType: 'user',
              lifecycle: 'active',
            ),
          );
      await target.customStatement('''
      CREATE TRIGGER fail_v8_nutrition_restore
      BEFORE INSERT ON nutrition_foods
      WHEN NEW.id = 'v8-user-food'
      BEGIN
        SELECT RAISE(ABORT, 'simulated v8 restore failure');
      END;
    ''');
      SharedPreferences.setMockInitialValues({'water_logged': 3});
      final prefs = await SharedPreferences.getInstance();
      final payload =
          jsonDecode(jsonEncode(backup.toJson())) as Map<String, dynamic>;
      final decoded = BackupV8Data.fromJson(payload);
      decoded.legacy.userPreferences['water_logged'] = 9;

      await expectLater(
        decoded.restoreToDatabase(target, prefs),
        throwsA(isA<Exception>()),
      );
      expect(prefs.getInt('water_logged'), 3);
      expect(
        (await target.select(target.nutritionFoods).get()).map((row) => row.id),
        contains('v8-sentinel-food'),
      );

      await target.customStatement('DROP TRIGGER fail_v8_nutrition_restore');
      await decoded.restoreToDatabase(target, prefs);
      expect(prefs.getInt('water_logged'), 9);
      expect(
        (await target.select(target.nutritionFoods).get()).map((row) => row.id),
        contains('v8-user-food'),
      );
    },
  );
}

Future<void> _populateNutritionGraph(AppDatabase db) async {
  await db
      .into(db.nutritionFoods)
      .insert(
        NutritionFoodsCompanion.insert(
          id: 'v8-user-food',
          kind: 'userCreated',
          displayName: 'V8 User Food',
          locale: 'en-IN',
          sourceType: 'user',
          lifecycle: 'active',
        ),
      );
  await db
      .into(db.nutritionFoods)
      .insert(
        NutritionFoodsCompanion.insert(
          id: 'z-v8-parent',
          kind: 'userCreated',
          displayName: 'V8 Parent',
          locale: 'en-IN',
          sourceType: 'user',
          lifecycle: 'active',
        ),
      );
  await db
      .into(db.nutritionFoods)
      .insert(
        NutritionFoodsCompanion.insert(
          id: 'a-v8-child',
          kind: 'preparationVariant',
          displayName: 'V8 Child',
          locale: 'en-IN',
          sourceType: 'user',
          lifecycle: 'active',
          variantOfFoodId: const Value('z-v8-parent'),
        ),
      );
  await db
      .into(db.nutritionFoodPreparations)
      .insert(
        NutritionFoodPreparationsCompanion.insert(
          id: 'v8-preparation',
          foodId: 'v8-user-food',
          state: 'cooked',
          source: 'user_entered',
          version: 'v1',
        ),
      );
  await db
      .into(db.nutritionHouseholdMeasures)
      .insert(
        NutritionHouseholdMeasuresCompanion.insert(
          id: 'v8-measure',
          key: 'v8_cup',
          displayName: 'V8 cup',
          dimension: 'volume',
          baseUnit: 'millilitre',
          nominalValue: 240,
          locale: 'en-IN',
          version: 1,
        ),
      );
  final nutrient =
      (await db.select(db.nutritionNutrientDefinitions).get()).first;
  await db
      .into(db.nutritionFoodNutrientFacts)
      .insert(
        NutritionFoodNutrientFactsCompanion.insert(
          id: 'v8-fact',
          foodId: 'v8-user-food',
          nutrientId: nutrient.id,
          amount: const Value(0),
          status: 'known_zero',
          source: 'user_entered',
          factVersion: 1,
          basis: 'absolute',
          isCurrent: const Value(true),
        ),
      );
  await db
      .into(db.nutritionRecipes)
      .insert(
        NutritionRecipesCompanion.insert(
          id: 'v8-recipe',
          userId: 'v8-user',
          name: 'V8 recipe',
          lifecycle: 'active',
        ),
      );
  await db
      .into(db.nutritionRecipeVersions)
      .insert(
        NutritionRecipeVersionsCompanion.insert(
          id: 'v8-recipe-v1',
          recipeId: 'v8-recipe',
          versionNumber: 1,
          status: 'published',
          calcRuleVersion: 'v1',
          source: 'user_entered',
        ),
      );
  await (db.update(
    db.nutritionRecipes,
  )..where((row) => row.id.equals('v8-recipe'))).write(
    const NutritionRecipesCompanion(currentVersionId: Value('v8-recipe-v1')),
  );
  await db
      .into(db.nutritionEstimates)
      .insert(
        NutritionEstimatesCompanion.insert(
          id: 'z-v8-estimate-parent',
          userId: 'v8-user',
          source: 'ai_estimate',
          status: 'estimated',
        ),
      );
  await db
      .into(db.nutritionEstimates)
      .insert(
        NutritionEstimatesCompanion.insert(
          id: 'a-v8-estimate-child',
          userId: 'v8-user',
          source: 'ai_estimate',
          status: 'superseded',
          supersedesId: const Value('z-v8-estimate-parent'),
        ),
      );
  await db
      .into(db.nutritionRecipeIngredients)
      .insert(
        NutritionRecipeIngredientsCompanion.insert(
          id: 'v8-ingredient',
          recipeVersionId: 'v8-recipe-v1',
          position: 0,
          foodId: 'v8-user-food',
          quantityValue: 100,
          quantityDimension: 'mass',
          quantityUnit: 'gram',
        ),
      );
  await db
      .into(db.nutritionConsumptionSnapshots)
      .insert(
        NutritionConsumptionSnapshotsCompanion.insert(
          id: 'v8-snapshot',
          userId: 'v8-user',
          loggedAt: DateTime.utc(2026, 8, 3),
          mealCategory: 'lunch',
          sourceType: 'manual',
          calculatorVersion: 'v1',
          completeness: 'partial',
          estimateStatus: 'none',
        ),
      );
  await db
      .into(db.nutritionSnapshotItems)
      .insert(
        NutritionSnapshotItemsCompanion.insert(
          id: 'v8-snapshot-item',
          snapshotId: 'v8-snapshot',
          position: 0,
          foodId: const Value('v8-user-food'),
          preparationId: const Value('v8-preparation'),
          quantityValue: 1,
          quantityDimension: 'serving',
          quantityUnit: 'serving',
        ),
      );
}
