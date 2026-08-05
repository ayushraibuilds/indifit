import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_v8.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_consumption_snapshots.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NutrientRegistry registry;

  setUp(() async {
    db = AppDatabase.memory();
    registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    await db
        .into(db.nutritionFoods)
        .insert(
          NutritionFoodsCompanion.insert(
            id: 'time-food',
            kind: 'userCreated',
            displayName: 'Time context food',
            locale: 'en-IN',
            sourceType: 'user',
            lifecycle: 'active',
          ),
        );
  });

  tearDown(() => db.close());

  test(
    'canonical finalization requires and validates typed time context',
    () async {
      final repository = NutritionConsumptionRepository(
        db: db,
        registry: registry,
      );

      await expectLater(
        repository.finalizeConsumption(
          _request(registry, localDate: null, timezoneId: null),
        ),
        throwsA(
          isA<NutritionConsumptionValidationError>().having(
            (error) => error.code,
            'code',
            'missing_local_time_context',
          ),
        ),
      );
      await expectLater(
        repository.finalizeConsumption(
          _request(registry, localDate: '2026-08-04', timezoneId: 'not-a-zone'),
        ),
        throwsA(
          isA<NutritionConsumptionValidationError>().having(
            (error) => error.code,
            'code',
            'invalid_local_time_context',
          ),
        ),
      );
      await expectLater(
        repository.finalizeConsumption(
          _request(
            registry,
            localDate: '2026-08-05',
            timezoneId: 'Asia/Kolkata',
          ),
        ),
        throwsA(
          isA<NutritionConsumptionValidationError>().having(
            (error) => error.code,
            'code',
            'local_time_context_mismatch',
          ),
        ),
      );
      expect(await db.select(db.nutritionConsumptionSnapshots).get(), isEmpty);
    },
  );

  test(
    'DST and cross-midnight dates are persisted from the stored timezone',
    () async {
      final repository = NutritionConsumptionRepository(
        db: db,
        registry: registry,
      );
      final dst = await repository.finalizeConsumption(
        _request(
          registry,
          id: 'dst-event',
          commandId: 'dst-command',
          loggedAtUtc: DateTime.utc(2026, 3, 8, 7, 30),
          localDate: '2026-03-08',
          timezoneId: 'America/New_York',
        ),
      );
      final midnight = await repository.finalizeConsumption(
        _request(
          registry,
          id: 'midnight-event',
          commandId: 'midnight-command',
          loggedAtUtc: DateTime.utc(2026, 8, 4, 18, 45),
          localDate: '2026-08-05',
          timezoneId: 'Asia/Kolkata',
        ),
      );

      expect(dst.localDate, '2026-03-08');
      expect(dst.timezoneId, 'America/New_York');
      expect(midnight.localDate, '2026-08-05');
      expect(midnight.timezoneId, 'Asia/Kolkata');

      final graph = await NutritionBackupGraph.capture(db);
      final restored = AppDatabase.memory();
      addTearDown(restored.close);
      await NutritionBackupGraph.fromJson(
        jsonDecode(jsonEncode(graph.toJson())),
      ).restoreInto(restored);
      final restoredRepository = NutritionConsumptionRepository(
        db: restored,
        registry: registry,
      );
      final restoredMidnight = await restoredRepository.getSnapshot(
        userId: 'time-user',
        consumptionId: 'midnight-event',
      );
      expect(restoredMidnight!.localDate, '2026-08-05');
      expect(restoredMidnight.timezoneId, 'Asia/Kolkata');
    },
  );
}

NutritionConsumptionFinalizeRequest _request(
  NutrientRegistry registry, {
  String id = 'time-event',
  String commandId = 'time-command',
  DateTime? loggedAtUtc,
  String? localDate,
  String? timezoneId,
}) {
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
        factVersion: 'time-test-v1',
      ),
    },
    registry: registry,
    requestedNutrientIds: const ['protein'],
    calculatorVersion: 'time-test-v1',
    calculationFingerprint: 'time-calculation-$id',
  );
  return NutritionConsumptionFinalizeRequest(
    userId: 'time-user',
    consumptionId: id,
    commandId: commandId,
    loggedAtUtc: loggedAtUtc ?? DateTime.utc(2026, 8, 4, 10),
    mealCategory: 'lunch',
    sourceType: 'direct_food',
    localDate: localDate,
    timezoneId: timezoneId,
    calculatorVersion: 'time-test-v1',
    items: [
      NutritionConsumptionItemInput(
        id: '$id-item',
        position: 0,
        sourceType: 'direct_food',
        foodId: 'time-food',
        displayLabel: 'Time context food',
        quantity: Quantity.fromDecimal(amount: '100', unit: QuantityUnit.gram),
        calculation: calculation,
      ),
    ],
  );
}
