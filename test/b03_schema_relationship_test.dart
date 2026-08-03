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
      expect(tables, hasLength(25));
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
          .into(db.nutritionHouseholdMeasures)
          .insert(
            NutritionHouseholdMeasuresCompanion.insert(
              id: 'mass-measure',
              key: 'mass-measure',
              displayName: 'Mass measure',
              dimension: 'mass',
              baseUnit: 'gram',
              nominalValue: 100,
              locale: 'und',
              version: 1,
            ),
          );
      await expectLater(
        db
            .into(db.nutritionVesselCalibrations)
            .insert(
              NutritionVesselCalibrationsCompanion.insert(
                id: 'invalid-vessel',
                userId: 'fixture-user',
                label: 'Invalid mass vessel',
                measureId: 'mass-measure',
                volumeMl: 100,
                method: 'fixture',
              ),
            ),
        throwsA(isA<Exception>()),
      );
    } finally {
      await db.close();
    }
  });

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
}
