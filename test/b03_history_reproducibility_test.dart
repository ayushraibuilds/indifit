import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_v8.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_consumption_snapshots.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_protein_distribution_repository.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NutrientRegistry registry;

  setUp(() {
    db = AppDatabase.memory();
    registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
  });

  tearDown(() => db.close());

  test(
    'repository reads immutable history, excludes superseded events, and keeps legacy source explicit',
    () async {
      await _insertFood(db, 'food-1', 'Original food label');
      final consumption = NutritionConsumptionRepository(
        db: db,
        registry: registry,
        nowUtc: () => DateTime.utc(2026, 8, 4, 20),
      );

      final original = _request(
        registry: registry,
        id: 'original-event',
        commandId: 'original-command',
        itemId: 'original-item',
        loggedAtUtc: DateTime.utc(2026, 8, 3, 20),
        localDate: '2026-08-03',
        protein: '99',
      );
      await consumption.finalizeConsumption(original);
      await consumption.finalizeConsumption(
        _request(
          registry: registry,
          id: 'breakfast-one',
          commandId: 'breakfast-command-one',
          itemId: 'breakfast-item-one',
          mealCategory: 'breakfast',
          mealGroupId: 'breakfast-group',
          loggedAtUtc: DateTime.utc(2026, 8, 4, 7),
          protein: '10',
        ),
      );
      await consumption.finalizeConsumption(
        _request(
          registry: registry,
          id: 'breakfast-two',
          commandId: 'breakfast-command-two',
          itemId: 'breakfast-item-two',
          mealCategory: 'breakfast',
          mealGroupId: 'breakfast-group',
          loggedAtUtc: DateTime.utc(2026, 8, 4, 7, 30),
          protein: '5',
        ),
      );
      await consumption.finalizeConsumption(
        _request(
          registry: registry,
          id: 'lunch-event',
          commandId: 'lunch-command',
          itemId: 'lunch-item',
          mealCategory: 'lunch',
          loggedAtUtc: DateTime.utc(2026, 8, 4, 13),
          protein: '20',
        ),
      );
      await consumption.finalizeConsumption(
        _request(
          registry: registry,
          id: 'corrected-event',
          commandId: 'corrected-command',
          itemId: 'corrected-item',
          mealCategory: 'dinner',
          loggedAtUtc: DateTime.utc(2026, 8, 4, 19),
          protein: '12',
          supersedesSnapshotId: original.consumptionId,
          correctionId: 'correction-1',
          correctionReason: 'Corrected logged quantity.',
        ),
      );

      await db
          .into(db.foodLogs)
          .insert(
            FoodLogsCompanion.insert(
              name: 'Legacy dinner',
              calories: 50,
              proteinG: 3,
              carbsG: 2,
              fatG: 1,
              servingLogged: 1,
              servingUnit: 'serving',
              mealType: 'snack',
              // Keep the compatibility row away from a UTC/local date
              // boundary; the legacy adapter deliberately preserves the
              // stored wall-clock date rather than deriving a new snapshot.
              loggedAt: Value(DateTime(2026, 8, 4, 12)),
              uuid: const Value('legacy-protein-1'),
            ),
          );

      final history = NutritionReadModelRepository(
        db: db,
        registry: registry,
        canonicalRepository: consumption,
        legacyUserId: 'user-1',
      );
      final repository = NutritionProteinDistributionRepository(
        registry: registry,
        history: history,
      );
      final distribution = await repository.forLocalDate(
        userId: 'user-1',
        localDate: '2026-08-04',
      );

      expect(distribution.totalProtein.pointText, '50.0');
      expect(distribution.recordIds, isNot(contains('original-event')));
      expect(distribution.recordIds, contains('corrected-event'));
      expect(distribution.meals, hasLength(4));
      expect(
        distribution.meals
            .singleWhere((meal) => meal.sourceTypes.contains('legacy_food_log'))
            .mealCategory,
        'snack',
      );
      expect(
        distribution.meals
            .singleWhere((meal) => meal.mealGroupId == 'breakfast-group')
            .protein
            .pointText,
        '15.0',
      );
      expect(
        distribution.totalProtein.fact!.source,
        NutrientSourceType.unknown,
      );

      final before = distribution.fingerprint;
      await (db.update(
        db.nutritionFoods,
      )..where((table) => table.id.equals('food-1'))).write(
        const NutritionFoodsCompanion(
          displayName: Value('Changed current catalogue label'),
        ),
      );
      final after = await repository.forLocalDate(
        userId: 'user-1',
        localDate: '2026-08-04',
      );
      expect(after.fingerprint, before);
      expect(after.totalProtein.pointText, distribution.totalProtein.pointText);
    },
  );

  test(
    'repeated finalization does not duplicate the read-model total',
    () async {
      await _insertFood(db, 'food-1', 'Food');
      final consumption = NutritionConsumptionRepository(
        db: db,
        registry: registry,
      );
      final request = _request(
        registry: registry,
        id: 'idempotent-event',
        commandId: 'idempotent-command',
        itemId: 'idempotent-item',
        protein: '14',
      );
      final first = await consumption.finalizeConsumption(request);
      final second = await consumption.finalizeConsumption(request);

      expect(second.id, first.id);
      expect(
        await db.select(db.nutritionConsumptionSnapshots).get(),
        hasLength(1),
      );

      final history = NutritionReadModelRepository(
        db: db,
        registry: registry,
        canonicalRepository: consumption,
      );
      final repository = NutritionProteinDistributionRepository(
        registry: registry,
        history: history,
      );
      final distribution = await repository.forLocalDate(
        userId: 'user-1',
        localDate: '2026-08-04',
      );
      expect(distribution.totalProtein.pointText, '14.0');
    },
  );

  test(
    'Backup-v8 round trip preserves descriptive distribution fingerprint',
    () async {
      await _insertFood(db, 'food-1', 'Food');
      final consumption = NutritionConsumptionRepository(
        db: db,
        registry: registry,
      );
      await consumption.finalizeConsumption(
        _request(
          registry: registry,
          id: 'backup-event',
          commandId: 'backup-command',
          itemId: 'backup-item',
          protein: '18',
        ),
      );

      final history = NutritionReadModelRepository(
        db: db,
        registry: registry,
        canonicalRepository: consumption,
      );
      final repository = NutritionProteinDistributionRepository(
        registry: registry,
        history: history,
      );
      final before = await repository.forLocalDate(
        userId: 'user-1',
        localDate: '2026-08-04',
      );
      final graph = await NutritionBackupGraph.capture(db);
      final restored = AppDatabase.memory();
      addTearDown(restored.close);
      await NutritionBackupGraph.fromJson(graph.toJson()).restoreInto(restored);

      final restoredConsumption = NutritionConsumptionRepository(
        db: restored,
        registry: registry,
      );
      final restoredHistory = NutritionReadModelRepository(
        db: restored,
        registry: registry,
        canonicalRepository: restoredConsumption,
      );
      final restoredRepository = NutritionProteinDistributionRepository(
        registry: registry,
        history: restoredHistory,
      );
      final after = await restoredRepository.forLocalDate(
        userId: 'user-1',
        localDate: '2026-08-04',
      );

      expect(after.fingerprint, before.fingerprint);
    },
  );
}

NutritionConsumptionFinalizeRequest _request({
  required NutrientRegistry registry,
  required String id,
  required String commandId,
  required String itemId,
  required String protein,
  DateTime? loggedAtUtc,
  String localDate = '2026-08-04',
  String mealCategory = 'lunch',
  String? mealGroupId,
  String? supersedesSnapshotId,
  String? correctionId,
  String? correctionReason,
}) {
  final calculation = NutritionConsumptionCalculationSnapshot.fromFacts(
    facts: {
      'protein': NutrientFact.known(
        nutrientId: 'protein',
        point: NutrientAmount(
          value: QuantityAmount.fromString(protein),
          unit: NutrientUnit.gram,
        ),
        basis: NutrientBasis(NutrientBasisKind.absolute),
        source: NutrientSourceType.reviewedCatalogue,
        factVersion: 'protein-v1',
      ),
      'leucine': NutrientFact.known(
        nutrientId: 'leucine',
        point: NutrientAmount(
          value: QuantityAmount.fromString('1'),
          unit: NutrientUnit.gram,
        ),
        basis: NutrientBasis(NutrientBasisKind.absolute),
        source: NutrientSourceType.reviewedCatalogue,
        factVersion: 'leucine-v1',
      ),
    },
    registry: registry,
    requestedNutrientIds: const ['protein', 'leucine'],
    calculatorVersion: 'history-test-v1',
    calculationFingerprint: 'history-calculation-$id',
  );
  return NutritionConsumptionFinalizeRequest(
    userId: 'user-1',
    consumptionId: id,
    commandId: commandId,
    loggedAtUtc: loggedAtUtc ?? DateTime.utc(2026, 8, 4, 12),
    mealCategory: mealCategory,
    mealGroupId: mealGroupId,
    sourceType: 'direct_food',
    localDate: localDate,
    timezoneId: 'Asia/Kolkata',
    calculatorVersion: 'history-test-v1',
    supersedesSnapshotId: supersedesSnapshotId,
    correctionId: correctionId,
    correctionReason: correctionReason,
    items: [
      NutritionConsumptionItemInput(
        id: itemId,
        position: 0,
        sourceType: 'direct_food',
        foodId: 'food-1',
        displayLabel: 'Frozen food label',
        quantity: Quantity.fromDecimal(amount: '100', unit: QuantityUnit.gram),
        calculation: calculation,
      ),
    ],
  );
}

Future<void> _insertFood(AppDatabase db, String id, String label) async {
  await db
      .into(db.nutritionFoods)
      .insert(
        NutritionFoodsCompanion.insert(
          id: id,
          kind: 'userCreated',
          displayName: label,
          locale: 'en-IN',
          sourceType: 'user',
          lifecycle: 'active',
        ),
      );
}
