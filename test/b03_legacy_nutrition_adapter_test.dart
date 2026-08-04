import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_v8.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_consumption_snapshots.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_legacy_adapter.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NutrientRegistry registry;
  late NutritionLegacyAdapter adapter;

  setUp(() {
    db = AppDatabase.memory();
    registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    adapter = NutritionLegacyAdapter(db: db, registry: registry);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'legacy food logs adapt without mutation and preserve copied facts',
    () async {
      await _seedMappedFood(db);
      await _insertLog(
        db,
        id: 11,
        foodItemId: 101,
        uuid: 'portable-log-11',
        amount: 100,
        unit: 'g',
        calories: 250,
        proteinG: 12.5,
        carbsG: 30,
        fatG: 8,
      );
      final beforeLogs = await db.select(db.foodLogs).get();
      final beforeSnapshots = await db
          .select(db.nutritionConsumptionSnapshots)
          .get();

      final record = (await adapter.readFoodLogs()).single;

      expect(record.stableId, 'legacy-food-log:uuid:portable-log-11');
      expect(record.foodIdentity.isResolved, isTrue);
      expect(record.foodIdentity.canonicalFoodId, 'food-101');
      expect(record.quantity.quantity!.unit, QuantityUnit.gram);
      expect(record.quantity.quantity!.amount.toString(), '100');
      expect(record.totals.facts['energy']!.point!.value.toString(), '250');
      expect(record.totals.facts['protein']!.point!.value.toString(), '12.5');
      expect(record.totals.facts['fibre']!.status, NutrientFactStatus.missing);
      expect(record.completeness.state, NutrientCompletenessState.partial);
      expect(record.completeness.missingNutrientIds, contains('fibre'));
      expect(await db.select(db.foodLogs).get(), beforeLogs);
      expect(
        await db.select(db.nutritionConsumptionSnapshots).get(),
        beforeSnapshots,
      );

      await (db.update(db.nutritionFoods)
            ..where((table) => table.id.equals('food-101')))
          .write(const NutritionFoodsCompanion(displayName: Value('Changed')));
      final afterCatalogueEdit = (await adapter.readFoodLogs()).single;
      expect(
        afterCatalogueEdit.totals.facts['protein']!.point!.value.toString(),
        '12.5',
      );
    },
  );

  test(
    'stable identity is deterministic and separate rows do not collapse',
    () async {
      await _insertLog(
        db,
        id: 2,
        amount: 1,
        unit: 'serving',
        uuid: 'same-uuid',
      );
      await _insertLog(
        db,
        id: 1,
        amount: 2,
        unit: 'serving',
        uuid: 'same-uuid',
      );
      await _insertLog(db, id: 3, amount: 1, unit: 'g');

      final first = await adapter.readFoodLogs();
      final second = await adapter.readFoodLogs();

      expect(first.map((row) => row.stableId).toList(), [
        'legacy-food-log:local-id:1',
        'legacy-food-log:local-id:2',
        'legacy-food-log:local-id:3',
      ]);
      expect(
        second.map((row) => row.stableId),
        first.map((row) => row.stableId),
      );
      expect(
        first[0].issues.map((issue) => issue.code),
        contains(NutritionCompatibilityIssueCode.duplicateLegacyIdentity),
      );
      expect(
        first[2].issues.map((issue) => issue.code),
        contains(NutritionCompatibilityIssueCode.localIdOnlyIdentity),
      );
    },
  );

  test('stored legacy zero remains known zero rather than unknown', () async {
    await _insertLog(
      db,
      id: 1,
      calories: 0,
      proteinG: 0,
      carbsG: 0,
      fatG: 0,
      amount: 1,
      unit: 'piece',
    );

    final record = (await adapter.readFoodLogs()).single;
    expect(record.totals.facts['energy']!.status, NutrientFactStatus.knownZero);
    expect(
      record.totals.facts['protein']!.status,
      NutrientFactStatus.knownZero,
    );
    expect(
      record.totals.facts['carbohydrate']!.status,
      NutrientFactStatus.knownZero,
    );
    expect(record.totals.facts['fat']!.status, NutrientFactStatus.knownZero);
    expect(record.totals.facts['fibre']!.status, NutrientFactStatus.missing);
  });

  test(
    'quantity adaptation keeps dimensions and contextual ambiguity explicit',
    () async {
      await _insertLog(db, id: 1, amount: 100, unit: 'ml');
      await _insertLog(db, id: 2, amount: 2, unit: 'pieces');
      await _insertLog(db, id: 3, amount: 1, unit: 'serving');
      await _insertLog(db, id: 4, amount: 1, unit: 'katori');
      await _insertLog(db, id: 5, amount: 1, unit: 'unknown portion');
      await _insertLog(db, id: 6, amount: 0, unit: 'g');
      await _insertLog(db, id: 7, amount: -1, unit: 'g');

      final records = await adapter.readFoodLogs();
      expect(records[0].quantity.quantity!.unit, QuantityUnit.millilitre);
      expect(records[1].quantity.quantity!.unit, QuantityUnit.piece);
      expect(
        records[2].quantity.state,
        NutritionHistoricalQuantityState.contextual,
      );
      expect(records[2].quantity.quantity!.unit, QuantityUnit.serving);
      expect(
        records[3].quantity.state,
        NutritionHistoricalQuantityState.unresolved,
      );
      expect(
        records[3].quantity.quantity!.unit,
        QuantityUnit.householdReference,
      );
      expect(
        records[4].quantity.state,
        NutritionHistoricalQuantityState.unresolved,
      );
      expect(
        records[5].quantity.state,
        NutritionHistoricalQuantityState.invalid,
      );
      expect(
        records[6].quantity.state,
        NutritionHistoricalQuantityState.invalid,
      );
      expect(
        records[3].issues.map((issue) => issue.code),
        contains(NutritionCompatibilityIssueCode.unsupportedQuantity),
      );
    },
  );

  test(
    'explicit mapping resolves identity while ambiguous or missing mappings stay unresolved',
    () async {
      await _seedMappedFood(db);
      await db
          .into(db.nutritionLegacyFoodMappings)
          .insert(
            NutritionLegacyFoodMappingsCompanion.insert(
              legacyFoodItemId: const Value(102),
              mappingStatus: 'ambiguous',
              evidence: 'two reviewed candidates',
            ),
          );
      await _insertLog(db, id: 1, foodItemId: 101, amount: 1, unit: 'g');
      await _insertLog(db, id: 2, foodItemId: 102, amount: 1, unit: 'g');
      await _insertLog(db, id: 3, foodItemId: 103, amount: 1, unit: 'g');

      final records = await adapter.readFoodLogs();
      expect(
        records[0].foodIdentity.resolution,
        NutritionLegacyIdentityResolution.resolved,
      );
      expect(
        records[1].foodIdentity.resolution,
        NutritionLegacyIdentityResolution.ambiguous,
      );
      expect(
        records[2].foodIdentity.resolution,
        NutritionLegacyIdentityResolution.unresolved,
      );
      expect(records[1].foodIdentity.canonicalFoodId, isNull);
      expect(
        records[2].issues.map((issue) => issue.code),
        contains(NutritionCompatibilityIssueCode.missingLegacyFoodMapping),
      );
    },
  );

  test(
    'legacy templates preserve order and never create recipes or snapshots',
    () async {
      final templateId = await db
          .into(db.mealTemplates)
          .insert(
            MealTemplatesCompanion.insert(
              name: 'Saved legacy meal',
              defaultMealType: const Value('lunch'),
            ),
          );
      await db
          .into(db.mealTemplateItems)
          .insert(
            MealTemplateItemsCompanion.insert(
              id: const Value(20),
              templateId: templateId,
              name: 'Second item',
              calories: 200,
              proteinG: 8,
              carbsG: 20,
              fatG: 4,
              servingLogged: 1,
              servingUnit: 'piece',
            ),
          );
      await db
          .into(db.mealTemplateItems)
          .insert(
            MealTemplateItemsCompanion.insert(
              id: const Value(10),
              templateId: templateId,
              name: 'First item',
              calories: 100,
              proteinG: 4,
              carbsG: 10,
              fatG: 2,
              servingLogged: 1,
              servingUnit: 'piece',
            ),
          );

      final template = (await adapter.readTemplates()).single;
      expect(template.stableId, 'legacy-meal-template:local-id:$templateId');
      expect(template.items.map((item) => item.displayLabel).toList(), [
        'First item',
        'Second item',
      ]);
      expect(template.items.map((item) => item.position), [0, 1]);
      expect(
        template.items.every((item) => item.foodIdentity.isResolved),
        isFalse,
      );
      expect(await db.select(db.nutritionRecipes).get(), isEmpty);
      expect(await db.select(db.nutritionConsumptionSnapshots).get(), isEmpty);
    },
  );

  test(
    'unified history combines canonical and legacy records without duplicate daily counting',
    () async {
      await _insertLog(
        db,
        id: 1,
        uuid: 'legacy-daily-1',
        amount: 1,
        unit: 'serving',
        calories: 100,
        proteinG: 5,
        carbsG: 10,
        fatG: 2,
        loggedAt: DateTime.utc(2026, 8, 4, 8),
      );
      await _seedCanonicalSnapshot(db, registry);

      final repository = NutritionReadModelRepository(
        db: db,
        registry: registry,
      );
      final records = await repository.listForLocalDate(
        userId: 'user-1',
        localDate: '2026-08-04',
      );
      expect(
        records.map((record) => record.sourceType),
        containsAll([
          NutritionHistoricalSourceType.legacyFoodLog.stableId,
          NutritionHistoricalSourceType.canonicalSnapshot.stableId,
        ]),
      );
      expect(records.map((record) => record.stableId).toSet(), hasLength(2));

      final daily = await repository.dailyTotals(
        userId: 'user-1',
        localDate: '2026-08-04',
      );
      expect(daily.records, hasLength(2));
      expect(daily.sourceCounts['legacy_food_log'], 1);
      expect(daily.sourceCounts['canonical_snapshot'], 1);
      expect(daily.totals.facts['protein']!.point!.value.toString(), '15');
      expect(
        daily.totals.completeness.state,
        NutrientCompletenessState.partial,
      );
    },
  );

  test('v5, v6, and v7 imports remain legacy-only and readable', () async {
    final current = await BackupV8Data.createFromDatabase(db);
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

    final fixture =
        jsonDecode(
              File(
                'test/fixtures/data/b03_backup_v7_legacy_baseline.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final restored = AppDatabase.memory();
    addTearDown(restored.close);
    await BackupV8Data.fromJson(fixture).restoreToDatabase(restored);
    final restoredAdapter = NutritionLegacyAdapter(
      db: restored,
      registry: registry,
    );
    expect(await restoredAdapter.readFoodLogs(), hasLength(3));
  });
}

Future<void> _seedMappedFood(AppDatabase db) async {
  await db
      .into(db.nutritionFoods)
      .insert(
        NutritionFoodsCompanion.insert(
          id: 'food-101',
          kind: 'userCreated',
          displayName: 'Mapped Food',
          locale: 'en-IN',
          sourceType: 'user',
          lifecycle: 'active',
        ),
      );
  await db
      .into(db.nutritionLegacyFoodMappings)
      .insert(
        NutritionLegacyFoodMappingsCompanion.insert(
          legacyFoodItemId: const Value(101),
          foodId: const Value('food-101'),
          mappingStatus: 'reviewed',
          evidence: 'test-reviewed-mapping',
        ),
      );
}

Future<void> _insertLog(
  AppDatabase db, {
  required int id,
  int? foodItemId,
  String? uuid,
  double amount = 1,
  String unit = 'g',
  int calories = 100,
  double proteinG = 5,
  double carbsG = 10,
  double fatG = 2,
  DateTime? loggedAt,
}) async {
  await db
      .into(db.foodLogs)
      .insert(
        FoodLogsCompanion.insert(
          id: Value(id),
          foodItemId: Value<int?>(foodItemId),
          name: 'Legacy display $id',
          calories: calories,
          proteinG: proteinG,
          carbsG: carbsG,
          fatG: fatG,
          servingLogged: amount,
          servingUnit: unit,
          mealType: 'lunch',
          loggedAt: Value(loggedAt ?? DateTime.utc(2026, 8, 4, 9)),
          uuid: Value<String?>(uuid),
        ),
      );
}

Future<void> _seedCanonicalSnapshot(
  AppDatabase db,
  NutrientRegistry registry,
) async {
  await db
      .into(db.nutritionFoods)
      .insert(
        NutritionFoodsCompanion.insert(
          id: 'food-canonical',
          kind: 'userCreated',
          displayName: 'Canonical food',
          locale: 'en-IN',
          sourceType: 'user',
          lifecycle: 'active',
        ),
      );
  final repository = NutritionConsumptionRepository(db: db, registry: registry);
  final calculation = NutritionConsumptionCalculationSnapshot.fromFacts(
    facts: {
      'protein': NutrientFact.known(
        nutrientId: 'protein',
        point: NutrientAmount(
          value: QuantityAmount.fromString('10'),
          unit: NutrientUnit.gram,
        ),
        basis: NutrientBasis(NutrientBasisKind.absolute),
        source: NutrientSourceType.reviewedCatalogue,
        factVersion: 'test',
      ),
    },
    registry: registry,
    requestedNutrientIds: const ['protein'],
    calculatorVersion: 'adapter-test-v1',
    calculationFingerprint: 'adapter-canonical-fingerprint',
  );
  await repository.finalizeConsumption(
    NutritionConsumptionFinalizeRequest(
      userId: 'user-1',
      consumptionId: 'canonical-consumption-1',
      commandId: 'canonical-command-1',
      loggedAtUtc: DateTime.utc(2026, 8, 4, 10),
      mealCategory: 'lunch',
      sourceType: 'direct_food',
      localDate: '2026-08-04',
      timezoneId: 'Asia/Kolkata',
      calculatorVersion: 'adapter-test-v1',
      items: [
        NutritionConsumptionItemInput(
          id: 'canonical-item-1',
          position: 0,
          sourceType: 'direct_food',
          foodId: 'food-canonical',
          displayLabel: 'Canonical food',
          quantity: Quantity.fromDecimal(
            amount: '100',
            unit: QuantityUnit.gram,
          ),
          calculation: calculation,
        ),
      ],
    ),
  );
}
