import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('v17 graph exposes all physical tables and required indexes', () async {
    final db = AppDatabase.memory();
    try {
      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'nutrition_%'",
          )
          .get();
      expect(tables, hasLength(26));
      final indexes = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'nutrition_%'",
          )
          .get();
      final names = indexes.map((row) => row.data['name'] as String).toSet();
      expect(names, contains('nutrition_foods_kind_lifecycle_idx'));
      expect(
        names,
        contains('nutrition_snapshot_constraint_evidence_result_idx'),
      );
      expect(names, contains('nutrition_user_constraints_user_idx'));
    } finally {
      await db.close();
    }
  });

  test('ambiguous aliases remain targetless and orphan facts fail', () async {
    final db = AppDatabase.memory();
    try {
      await db
          .into(db.nutritionFoodAliases)
          .insert(
            NutritionFoodAliasesCompanion.insert(
              id: 'ambiguous-alias',
              alias: 'generic curry',
              normalizedAlias: 'generic curry',
              locale: 'und',
              source: 'fixture:ambiguous',
            ),
          );
      expect(
        (await (db.select(
              db.nutritionFoodAliases,
            )..where((row) => row.id.equals('ambiguous-alias'))).getSingle())
            .foodId,
        isNull,
      );
      await expectLater(
        db
            .into(db.nutritionFoodNutrientFacts)
            .insert(
              NutritionFoodNutrientFactsCompanion.insert(
                id: 'orphan-fact',
                foodId: 'missing-food',
                nutrientId: 'protein',
                status: 'known',
                source: 'legacy',
                factVersion: 1,
                basis: 'per_100_grams',
                basisQuantity: const Value(100),
                basisUnit: const Value('gram'),
                amount: const Value(1),
              ),
            ),
        throwsA(isA<Exception>()),
      );
    } finally {
      await db.close();
    }
  });

  test('vessel calibration is volume-only', () async {
    final db = AppDatabase.memory();
    try {
      await db
          .into(db.nutritionPersonalVessels)
          .insert(
            NutritionPersonalVesselsCompanion.insert(
              id: 'vessel-volume',
              userId: 'fixture-user',
              displayName: 'Fixture vessel',
            ),
          );
      await expectLater(
        db
            .into(db.nutritionVesselCalibrations)
            .insert(
              NutritionVesselCalibrationsCompanion.insert(
                id: 'invalid-vessel',
                vesselId: 'vessel-volume',
                volumeAmount: 100,
                volumeUnit: 'gram',
                method: 'fixture',
                version: 1,
              ),
            ),
        throwsA(isA<Exception>()),
      );
    } finally {
      await db.close();
    }
  });

  test(
    'portable vessels allow duplicate names and immutable calibration history',
    () async {
      final db = AppDatabase.memory();
      try {
        await db
            .into(db.nutritionPersonalVessels)
            .insert(
              NutritionPersonalVesselsCompanion.insert(
                id: 'vessel-a',
                userId: 'fixture-user',
                displayName: 'Kitchen cup',
              ),
            );
        await db
            .into(db.nutritionPersonalVessels)
            .insert(
              NutritionPersonalVesselsCompanion.insert(
                id: 'vessel-b',
                userId: 'fixture-user',
                displayName: 'Kitchen cup',
              ),
            );
        await (db.update(
          db.nutritionPersonalVessels,
        )..where((row) => row.id.equals('vessel-a'))).write(
          const NutritionPersonalVesselsCompanion(
            displayName: Value('Renamed cup'),
          ),
        );

        await db
            .into(db.nutritionVesselCalibrations)
            .insert(
              NutritionVesselCalibrationsCompanion.insert(
                id: 'calibration-a-1',
                vesselId: 'vessel-a',
                volumeAmount: 180,
                volumeUnit: 'millilitre',
                method: 'water_fill',
                version: 1,
              ),
            );
        await db
            .into(db.nutritionVesselCalibrations)
            .insert(
              NutritionVesselCalibrationsCompanion.insert(
                id: 'calibration-a-2',
                vesselId: 'vessel-a',
                volumeAmount: 200,
                volumeUnit: 'millilitre',
                method: 'water_fill',
                supersedesCalibrationId: const Value('calibration-a-1'),
                version: 2,
              ),
            );

        final vessel = await (db.select(
          db.nutritionPersonalVessels,
        )..where((row) => row.id.equals('vessel-a'))).getSingle();
        expect(vessel.displayName, 'Renamed cup');
        expect(
          await (db.select(db.nutritionVesselCalibrations)
                ..where((row) => row.id.equals('calibration-a-1')))
              .getSingle()
              .then((row) => row.volumeAmount),
          180,
        );

        await expectLater(
          db
              .into(db.nutritionVesselCalibrations)
              .insert(
                NutritionVesselCalibrationsCompanion.insert(
                  id: 'calibration-a-branch',
                  vesselId: 'vessel-a',
                  volumeAmount: 210,
                  volumeUnit: 'millilitre',
                  method: 'water_fill',
                  supersedesCalibrationId: const Value('calibration-a-1'),
                  version: 2,
                ),
              ),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          db
              .into(db.nutritionVesselCalibrations)
              .insert(
                NutritionVesselCalibrationsCompanion.insert(
                  id: 'calibration-b-2',
                  vesselId: 'vessel-b',
                  volumeAmount: 220,
                  volumeUnit: 'millilitre',
                  method: 'water_fill',
                  supersedesCalibrationId: const Value('calibration-a-2'),
                  version: 2,
                ),
              ),
          throwsA(isA<Exception>()),
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'thali items require exactly one direct-food or recipe reference',
    () async {
      final db = AppDatabase.memory();
      try {
        await db
            .into(db.nutritionThalis)
            .insert(
              NutritionThalisCompanion.insert(
                id: 'fixture-thali',
                userId: 'fixture-user',
                name: 'Fixture thali',
                lifecycle: 'active',
                currentVersion: 1,
              ),
            );
        await expectLater(
          db
              .into(db.nutritionThaliItems)
              .insert(
                NutritionThaliItemsCompanion.insert(
                  id: 'invalid-thali-item',
                  thaliId: 'fixture-thali',
                  position: 0,
                  quantityValue: 1,
                  quantityDimension: 'serving',
                  quantityUnit: 'serving',
                ),
              ),
          throwsA(isA<Exception>()),
        );
      } finally {
        await db.close();
      }
    },
  );

  test('constraint results use the accepted cautious taxonomy', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    await db
        .into(db.nutritionConsumptionSnapshots)
        .insert(
          NutritionConsumptionSnapshotsCompanion.insert(
            id: 'snapshot-constraint-taxonomy',
            userId: 'fixture-user',
            loggedAt: DateTime.utc(2026, 1, 1),
            mealCategory: 'lunch',
            sourceType: 'manual',
            calculatorVersion: 'fixture-v1',
            completeness: 'unknown',
            estimateStatus: 'none',
          ),
        );
    await db
        .into(db.nutritionFoods)
        .insert(
          NutritionFoodsCompanion.insert(
            id: 'snapshot-taxonomy-food',
            kind: 'canonical',
            displayName: 'Snapshot taxonomy food',
            locale: 'en-IN',
            sourceType: 'fixture',
            lifecycle: 'active',
          ),
        );
    await db
        .into(db.nutritionRecipes)
        .insert(
          NutritionRecipesCompanion.insert(
            id: 'snapshot-taxonomy-recipe',
            userId: 'fixture-user',
            name: 'Snapshot taxonomy recipe',
            lifecycle: 'active',
          ),
        );
    await db
        .into(db.nutritionRecipeVersions)
        .insert(
          NutritionRecipeVersionsCompanion.insert(
            id: 'snapshot-taxonomy-recipe-v1',
            recipeId: 'snapshot-taxonomy-recipe',
            versionNumber: 1,
            status: 'draft',
            calcRuleVersion: 'fixture-v1',
            source: 'fixture',
          ),
        );
    await expectLater(
      db
          .into(db.nutritionSnapshotItems)
          .insert(
            NutritionSnapshotItemsCompanion.insert(
              id: 'snapshot-item-both-references',
              snapshotId: 'snapshot-constraint-taxonomy',
              position: 0,
              foodId: const Value('snapshot-taxonomy-food'),
              recipeVersionId: const Value('snapshot-taxonomy-recipe-v1'),
              quantityValue: 1,
              quantityDimension: 'serving',
              quantityUnit: 'serving',
            ),
          ),
      throwsA(isA<Exception>()),
    );
    for (final result in const [
      'confirmed_conflict',
      'possible_conflict',
      'no_known_conflict',
      'insufficient_information',
    ]) {
      await db
          .into(db.nutritionConstraintDefinitions)
          .insert(
            NutritionConstraintDefinitionsCompanion.insert(
              id: 'constraint-$result',
              key: 'fixture_constraint_$result',
              type: 'allergy',
              displayName: 'Fixture constraint $result',
              version: 1,
            ),
          );
      await db
          .into(db.nutritionUserConstraints)
          .insert(
            NutritionUserConstraintsCompanion.insert(
              id: 'user-constraint-$result',
              userId: 'fixture-user',
              definitionId: 'constraint-$result',
              value: 'avoid',
              strictness: 'avoid',
              effectiveFrom: DateTime.utc(2026, 1, 1),
              source: 'fixture',
            ),
          );
      await db
          .into(db.nutritionSnapshotConstraintResults)
          .insert(
            NutritionSnapshotConstraintResultsCompanion.insert(
              id: 'result-$result',
              snapshotId: 'snapshot-constraint-taxonomy',
              constraintId: 'user-constraint-$result',
              result: result,
              ruleVersion: 'fixture-v1',
              evaluatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
    }

    await expectLater(
      db
          .into(db.nutritionSnapshotConstraintResults)
          .insert(
            NutritionSnapshotConstraintResultsCompanion.insert(
              id: 'result-unsafe-shortcut',
              snapshotId: 'snapshot-constraint-taxonomy',
              constraintId: 'user-constraint-confirmed_conflict',
              result: 'safe',
              ruleVersion: 'fixture-v1',
              evaluatedAt: DateTime.utc(2026, 1, 1),
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });
}
