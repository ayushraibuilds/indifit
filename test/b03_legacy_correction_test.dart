import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_v8.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_legacy_corrections.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/repositories/nutrition_legacy_adapter.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NutrientRegistry registry;

  setUp(() async {
    db = AppDatabase.memory();
    registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    await _insertLog(db);
  });

  tearDown(() => db.close());

  test(
    'legacy correction appends, reads effectively, and is idempotent',
    () async {
      final repository = FoodRepository(db);
      final before = (await db.select(db.foodLogs).get()).single;

      expect(
        await repository.updateFoodLog(
          id: 1,
          name: 'Corrected dal',
          calories: 240,
          proteinG: 14,
          carbsG: 28,
          fatG: 7,
          servingLogged: 1.5,
        ),
        isTrue,
      );
      expect((await db.select(db.foodLogs).get()).single, before);
      expect(await db.select(db.nutritionUserCorrections).get(), hasLength(1));

      final adapter = NutritionLegacyAdapter(db: db, registry: registry);
      final corrected = (await adapter.readFoodLogs()).single;
      expect(corrected.displayLabel, 'Corrected dal');
      expect(corrected.totals.facts['protein']!.point!.value.toString(), '14');
      expect(corrected.quantity.storedAmount, 1.5);
      expect(
        corrected.issues.any(
          (issue) => issue.code.name == 'legacyCorrectionApplied',
        ),
        isTrue,
      );

      await repository.updateFoodLog(
        id: 1,
        name: 'Corrected dal',
        calories: 240,
        proteinG: 14,
        carbsG: 28,
        fatG: 7,
        servingLogged: 1.5,
      );
      expect(await db.select(db.nutritionUserCorrections).get(), hasLength(1));

      await repository.updateFoodLog(
        id: 1,
        name: 'Corrected dal v2',
        calories: 250,
        proteinG: 15,
        carbsG: 29,
        fatG: 8,
        servingLogged: 1.5,
      );
      final corrections = await db.select(db.nutritionUserCorrections).get();
      expect(corrections, hasLength(2));
      final second = corrections.singleWhere(
        (row) => row.id != corrections.first.id,
      );
      final ancestry = NutritionLegacyFoodLogCorrectionCodec.decode(
        second.newValue,
      );
      expect(ancestry.supersedesId, isNotNull);
    },
  );

  test(
    'unified history counts one effective legacy row and backup preserves ancestry',
    () async {
      final repository = FoodRepository(db);
      await repository.updateFoodLog(
        id: 1,
        name: 'Corrected dal',
        calories: 240,
        proteinG: 14,
        carbsG: 28,
        fatG: 7,
        servingLogged: 1,
      );
      final history = NutritionReadModelRepository(db: db, registry: registry);
      final daily = await history.dailyTotals(
        userId: NutritionLegacyAdapter.defaultLegacyUserId,
        localDate: '2026-08-04',
      );
      expect(daily.records, hasLength(1));
      expect(daily.records.single.displayLabel, 'Corrected dal');
      expect(daily.totals.facts['protein']!.point!.value.toString(), '14');

      final backup = BackupV8Data.fromJson(
        jsonDecode(
              jsonEncode((await BackupV8Data.createFromDatabase(db)).toJson()),
            )
            as Map<String, dynamic>,
      );
      final restored = AppDatabase.memory();
      addTearDown(restored.close);
      await backup.restoreToDatabase(restored);
      final restoredRows = await restored.select(restored.foodLogs).get();
      expect(restoredRows.single.name, 'Original dal');
      expect(
        await restored.select(restored.nutritionUserCorrections).get(),
        hasLength(1),
      );
      final restoredHistory = NutritionReadModelRepository(
        db: restored,
        registry: registry,
      );
      final restoredDaily = await restoredHistory.dailyTotals(
        userId: NutritionLegacyAdapter.defaultLegacyUserId,
        localDate: '2026-08-04',
      );
      expect(restoredDaily.records, hasLength(1));
      expect(restoredDaily.records.single.displayLabel, 'Corrected dal');
    },
  );
}

Future<void> _insertLog(AppDatabase db) async {
  await db
      .into(db.foodLogs)
      .insert(
        FoodLogsCompanion.insert(
          id: const Value(1),
          name: 'Original dal',
          calories: 200,
          proteinG: 10,
          carbsG: 25,
          fatG: 5,
          servingLogged: 1,
          servingUnit: 'serving',
          mealType: 'lunch',
          loggedAt: Value(DateTime.utc(2026, 8, 4, 12)),
          uuid: const Value('legacy-correction-log'),
        ),
      );
}
