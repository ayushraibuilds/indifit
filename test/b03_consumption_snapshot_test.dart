import 'package:drift/drift.dart' hide isNull;
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

  setUp(() {
    db = AppDatabase.memory();
    registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'finalizes a direct-food immutable snapshot with exact evidence',
    () async {
      await _insertFood(db, 'food-1', 'Original label');
      await db
          .into(db.nutritionPersonalVessels)
          .insert(
            NutritionPersonalVesselsCompanion.insert(
              id: 'vessel-1',
              userId: 'user-1',
              displayName: 'Lunch bowl',
            ),
          );
      await db
          .into(db.nutritionVesselCalibrations)
          .insert(
            NutritionVesselCalibrationsCompanion.insert(
              id: 'cal-1',
              vesselId: 'vessel-1',
              volumeAmount: 180,
              volumeUnit: 'millilitre',
              method: 'water_fill',
              version: 1,
            ),
          );
      final repository = NutritionConsumptionRepository(
        db: db,
        registry: registry,
        nowUtc: () => DateTime.utc(2026, 8, 4, 10),
      );
      final calculation = _calculation(
        registry,
        facts: {
          'protein': _known('protein', '12.345678'),
          'energy': _known('energy', '123.456'),
          'fat': _knownZero('fat'),
          'carbohydrate': _missing('carbohydrate'),
        },
        requested: const ['protein', 'energy', 'fat', 'carbohydrate'],
      );

      final saved = await repository.finalizeConsumption(
        _request(
          calculation: calculation,
          consumptionId: 'consumption-1',
          commandId: 'command-1',
          evidence: {
            'measure': {'id': 'katori-v1', 'calibration_id': 'cal-1'},
            'transformation': {'id': 'none', 'version': 'not_applied'},
          },
        ),
      );

      expect(saved.id, 'consumption-1');
      expect(saved.items.single.displayLabel, 'Original label');
      expect(
        saved.items.single.facts['fat']!.status,
        NutrientFactStatus.knownZero,
      );
      expect(
        saved.items.single.facts['carbohydrate']!.status,
        NutrientFactStatus.missing,
      );
      expect(
        saved.totals.facts['protein']!.point!.value.toString(),
        '12.345678',
      );
      expect(saved.completeness.state, NutrientCompletenessState.partial);
      expect(saved.lineage.commandId, 'command-1');
      expect(saved.lineage.contentFingerprint, isNotEmpty);

      await (db.update(
        db.nutritionFoods,
      )..where((table) => table.id.equals('food-1'))).write(
        const NutritionFoodsCompanion(displayName: Value('Changed label')),
      );
      final historical = await repository.getSnapshot(
        userId: 'user-1',
        consumptionId: 'consumption-1',
      );
      expect(historical!.items.single.displayLabel, 'Original label');
      expect(
        historical.items.single.facts['protein']!.point!.value.toString(),
        '12.345678',
      );
    },
  );

  test('retries are idempotent and conflicting payloads fail', () async {
    await _insertFood(db, 'food-1', 'Food');
    final repository = NutritionConsumptionRepository(
      db: db,
      registry: registry,
    );
    final request = _request(
      calculation: _calculation(
        registry,
        facts: {'protein': _known('protein', '10')},
        requested: const ['protein'],
      ),
      consumptionId: 'consumption-1',
      commandId: 'command-1',
    );
    final first = await repository.finalizeConsumption(request);
    final retry = await repository.finalizeConsumption(request);
    expect(retry.id, first.id);
    expect(
      await db.select(db.nutritionConsumptionSnapshots).get(),
      hasLength(1),
    );

    final conflicting = _request(
      calculation: _calculation(
        registry,
        facts: {'protein': _known('protein', '11')},
        requested: const ['protein'],
      ),
      consumptionId: 'different-id',
      commandId: 'command-1',
    );
    await expectLater(
      repository.finalizeConsumption(conflicting),
      throwsA(
        isA<NutritionConsumptionConflictError>().having(
          (error) => error.code,
          'code',
          'idempotency_conflict',
        ),
      ),
    );
  });

  test(
    'finalizes a recipe-version snapshot without resolving current recipe data',
    () async {
      await db
          .into(db.nutritionRecipes)
          .insert(
            NutritionRecipesCompanion.insert(
              id: 'recipe-1',
              userId: 'user-1',
              name: 'Frozen recipe name',
              lifecycle: 'active',
            ),
          );
      await db
          .into(db.nutritionRecipeVersions)
          .insert(
            NutritionRecipeVersionsCompanion.insert(
              id: 'recipe-version-1',
              recipeId: 'recipe-1',
              versionNumber: 1,
              status: 'published',
              calcRuleVersion: 'snapshot-test-v1',
              source: '{}',
            ),
          );
      final repository = NutritionConsumptionRepository(
        db: db,
        registry: registry,
      );
      final calculation = _calculation(
        registry,
        facts: {'protein': _known('protein', '25')},
        requested: const ['protein'],
      );
      final snapshot = await repository.finalizeConsumption(
        NutritionConsumptionFinalizeRequest(
          userId: 'user-1',
          consumptionId: 'recipe-consumption-1',
          commandId: 'recipe-command-1',
          loggedAtUtc: DateTime.utc(2026, 8, 4, 10),
          mealCategory: 'dinner',
          sourceType: 'recipe_version',
          recipeVersionId: 'recipe-version-1',
          localDate: '2026-08-04',
          timezoneId: 'Asia/Kolkata',
          calculatorVersion: 'snapshot-test-v1',
          items: [
            NutritionConsumptionItemInput(
              id: 'recipe-item-1',
              position: 0,
              sourceType: 'recipe_version',
              recipeVersionId: 'recipe-version-1',
              displayLabel: 'Frozen recipe label',
              quantity: Quantity.fromDecimal(
                amount: '1',
                unit: QuantityUnit.serving,
                context: const QuantityContext(
                  servingDefinition: ServingDefinitionReference(
                    id: 'recipe-serving-1',
                    revision: '1',
                  ),
                ),
              ),
              calculation: calculation,
            ),
          ],
        ),
      );
      expect(snapshot.recipeVersionId, 'recipe-version-1');
      expect(snapshot.items.single.recipeVersionId, 'recipe-version-1');
      expect(snapshot.totals.facts['protein']!.point!.value.toString(), '25');
    },
  );

  test('failed finalization rolls back the complete graph', () async {
    await _insertFood(db, 'food-1', 'Food');
    final repository = NutritionConsumptionRepository(
      db: db,
      registry: registry,
      failureInjector: (stage) {
        if (stage == 'after_items') {
          throw const NutritionConsumptionPersistenceError(
            'injected_failure',
            'test failure',
          );
        }
      },
    );
    await expectLater(
      repository.finalizeConsumption(
        _request(
          calculation: _calculation(
            registry,
            facts: {'protein': _known('protein', '10')},
            requested: const ['protein'],
          ),
          consumptionId: 'consumption-1',
        ),
      ),
      throwsA(isA<NutritionConsumptionPersistenceError>()),
    );
    expect(await db.select(db.nutritionConsumptionSnapshots).get(), isEmpty);
    expect(await db.select(db.nutritionSnapshotItems).get(), isEmpty);
    expect(await db.select(db.nutritionSnapshotNutrients).get(), isEmpty);
  });

  test(
    'corrections preserve originals and daily totals use the successor',
    () async {
      await _insertFood(db, 'food-1', 'Food');
      final repository = NutritionConsumptionRepository(
        db: db,
        registry: registry,
      );
      final original = await repository.finalizeConsumption(
        _request(
          calculation: _calculation(
            registry,
            facts: {'protein': _known('protein', '10')},
            requested: const ['protein'],
          ),
          consumptionId: 'original',
          commandId: 'original-command',
        ),
      );
      final successor = await repository.finalizeConsumption(
        _request(
          calculation: _calculation(
            registry,
            facts: {'protein': _known('protein', '12')},
            requested: const ['protein'],
          ),
          consumptionId: 'successor',
          commandId: 'successor-command',
          itemId: 'item-2',
          supersedesSnapshotId: original.id,
          correctionId: 'correction-1',
          correctionReason: 'User correction',
        ),
      );
      expect(successor.lineage.supersedesSnapshotId, original.id);
      expect(
        (await repository.getSnapshot(
          userId: 'user-1',
          consumptionId: original.id,
        ))!.totals.facts['protein']!.point!.value.toString(),
        '10',
      );
      final daily = await repository.dailyTotals(
        userId: 'user-1',
        localDate: '2026-08-04',
      );
      expect(daily.snapshotIds, ['successor']);
      expect(daily.totals.facts['protein']!.point!.value.toString(), '12');
    },
  );

  test('Backup-v8 captures and restores the snapshot graph', () async {
    await _insertFood(db, 'food-1', 'Food');
    final repository = NutritionConsumptionRepository(
      db: db,
      registry: registry,
    );
    await repository.finalizeConsumption(
      _request(
        calculation: _calculation(
          registry,
          facts: {'protein': _known('protein', '12.345678')},
          requested: const ['protein'],
        ),
        consumptionId: 'consumption-1',
        commandId: 'command-1',
      ),
    );
    final graph = await NutritionBackupGraph.capture(db);
    final roundTrip = NutritionBackupGraph.fromJson(graph.toJson());
    expect(roundTrip.tables['nutrition_consumption_snapshots'], hasLength(1));
    expect(roundTrip.tables['nutrition_snapshot_items'], hasLength(1));
    final roundTripNutrients = roundTrip.tables['nutrition_snapshot_nutrients'];
    expect(roundTripNutrients, hasLength(1));
    expect(roundTripNutrients!.single['lineage'], contains('fact'));

    final restored = AppDatabase.memory();
    addTearDown(restored.close);
    await roundTrip.restoreInto(restored);
    final restoredRepo = NutritionConsumptionRepository(
      db: restored,
      registry: registry,
    );
    final snapshot = await restoredRepo.getSnapshot(
      userId: 'user-1',
      consumptionId: 'consumption-1',
    );
    expect(
      snapshot!.items.single.facts['protein']!.point!.value.toString(),
      '12.345678',
    );
  });
}

NutritionConsumptionFinalizeRequest _request({
  required NutritionConsumptionCalculationSnapshot calculation,
  required String consumptionId,
  String? commandId,
  Map<String, dynamic> evidence = const {},
  String? supersedesSnapshotId,
  String? correctionId,
  String? correctionReason,
  String itemId = 'item-1',
}) => NutritionConsumptionFinalizeRequest(
  userId: 'user-1',
  consumptionId: consumptionId,
  commandId: commandId,
  loggedAtUtc: DateTime.utc(2026, 8, 4, 10),
  mealCategory: 'lunch',
  sourceType: 'direct_food',
  localDate: '2026-08-04',
  timezoneId: 'Asia/Kolkata',
  calculatorVersion: 'snapshot-test-v1',
  evidence: evidence,
  supersedesSnapshotId: supersedesSnapshotId,
  correctionId: correctionId,
  correctionReason: correctionReason,
  items: [
    NutritionConsumptionItemInput(
      id: itemId,
      position: 0,
      sourceType: 'direct_food',
      foodId: 'food-1',
      displayLabel: 'Original label',
      quantity: Quantity.fromDecimal(amount: '100', unit: QuantityUnit.gram),
      calculation: calculation,
    ),
  ],
);

NutritionConsumptionCalculationSnapshot _calculation(
  NutrientRegistry registry, {
  required Map<String, NutrientFact> facts,
  required Iterable<String> requested,
}) => NutritionConsumptionCalculationSnapshot.fromFacts(
  facts: facts,
  registry: registry,
  requestedNutrientIds: requested,
  calculatorVersion: 'snapshot-test-v1',
  calculationFingerprint: 'calculation-${facts.keys.join('-')}',
);

NutrientFact _known(String nutrientId, String value) => NutrientFact.known(
  nutrientId: nutrientId,
  point: NutrientAmount(
    value: QuantityAmount.fromString(value),
    unit: _unitFor(nutrientId),
  ),
  basis: NutrientBasis(NutrientBasisKind.absolute),
  source: NutrientSourceType.reviewedCatalogue,
  factVersion: '7',
);

NutrientFact _knownZero(String nutrientId) => NutrientFact.knownZero(
  nutrientId: nutrientId,
  unit: _unitFor(nutrientId),
  basis: NutrientBasis(NutrientBasisKind.absolute),
  source: NutrientSourceType.reviewedCatalogue,
  factVersion: '7',
);

NutrientFact _missing(String nutrientId) => NutrientFact.missing(
  nutrientId: nutrientId,
  unit: _unitFor(nutrientId),
  basis: NutrientBasis(NutrientBasisKind.absolute),
  source: NutrientSourceType.unknown,
  factVersion: '7',
);

NutrientUnit _unitFor(String nutrientId) => switch (nutrientId) {
  'energy' => NutrientUnit.kilocalorie,
  'protein' ||
  'carbohydrate' ||
  'fat' ||
  'fibre' ||
  'added_sugar' ||
  'saturated_fat' ||
  'leucine' => NutrientUnit.gram,
  'vitamin_b12' || 'vitamin_d' || 'folate' => NutrientUnit.microgram,
  _ => NutrientUnit.milligram,
};

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
