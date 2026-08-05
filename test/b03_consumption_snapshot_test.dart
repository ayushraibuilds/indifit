import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
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
            'measure': {'calibration_id': 'cal-1', 'calibration_version': 1},
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

  test(
    'normalizes omitted requested nutrient facts into immutable calculation lineage',
    () async {
      await _insertFood(db, 'food-1', 'Food');
      final repository = NutritionConsumptionRepository(
        db: db,
        registry: registry,
      );
      await repository.finalizeConsumption(
        _request(
          calculation: _calculation(
            registry,
            facts: {'protein': _known('protein', '10')},
            requested: const ['protein', 'fibre'],
          ),
          consumptionId: 'normalized-calculation',
          commandId: 'normalized-calculation-command',
        ),
      );

      final row =
          (await db.select(db.nutritionConsumptionSnapshots).get()).single;
      final lineage = jsonDecode(row.lineage!) as Map<String, dynamic>;
      final evidence = Map<String, dynamic>.from(lineage['evidence'] as Map);
      final items = Map<String, dynamic>.from(evidence['items'] as Map);
      final item = Map<String, dynamic>.from(items['item-1'] as Map);
      final calculation = Map<String, dynamic>.from(item['calculation'] as Map);
      expect(calculation['facts'], contains('fibre'));
      expect(
        (await repository.getSnapshot(
          userId: 'user-1',
          consumptionId: 'normalized-calculation',
        )),
        isNotNull,
      );
    },
  );

  test(
    'historical reads reject calculation-fact and estimate-status drift',
    () async {
      await _insertFood(db, 'food-1', 'Food');
      final repository = NutritionConsumptionRepository(
        db: db,
        registry: registry,
      );
      await repository.finalizeConsumption(
        _request(
          calculation: _calculation(
            registry,
            facts: {
              'protein': NutrientFact.estimated(
                nutrientId: 'protein',
                point: NutrientAmount(
                  value: QuantityAmount.fromString('10'),
                  unit: NutrientUnit.gram,
                ),
                basis: NutrientBasis(NutrientBasisKind.absolute),
                source: NutrientSourceType.aiEstimate,
                factVersion: 'estimate-v1',
              ),
            },
            requested: const ['protein'],
          ),
          consumptionId: 'drifted-calculation',
          commandId: 'drifted-calculation-command',
        ),
      );

      final row =
          (await db.select(db.nutritionConsumptionSnapshots).get()).single;
      final originalLineage = row.lineage!;
      final lineage = jsonDecode(row.lineage!) as Map<String, dynamic>;
      final evidence = Map<String, dynamic>.from(lineage['evidence'] as Map);
      final items = Map<String, dynamic>.from(evidence['items'] as Map);
      final item = Map<String, dynamic>.from(items['item-1'] as Map);
      final calculation = Map<String, dynamic>.from(item['calculation'] as Map)
        ..['facts'] = <String, dynamic>{};
      item['calculation'] = calculation;
      items['item-1'] = item;
      evidence['items'] = items;
      lineage['evidence'] = evidence;
      await (db.update(
        db.nutritionConsumptionSnapshots,
      )..where((table) => table.id.equals('drifted-calculation'))).write(
        NutritionConsumptionSnapshotsCompanion(
          lineage: Value(jsonEncode(lineage)),
        ),
      );
      await expectLater(
        repository.getSnapshot(
          userId: 'user-1',
          consumptionId: 'drifted-calculation',
        ),
        throwsA(
          isA<NutritionConsumptionPersistenceError>().having(
            (error) => error.code,
            'code',
            'calculation_lineage_mismatch',
          ),
        ),
      );

      await (db.update(
        db.nutritionConsumptionSnapshots,
      )..where((table) => table.id.equals('drifted-calculation'))).write(
        NutritionConsumptionSnapshotsCompanion(lineage: Value(originalLineage)),
      );
      await (db.update(
        db.nutritionConsumptionSnapshots,
      )..where((table) => table.id.equals('drifted-calculation'))).write(
        const NutritionConsumptionSnapshotsCompanion(
          estimateStatus: Value('none'),
        ),
      );
      await expectLater(
        repository.getSnapshot(
          userId: 'user-1',
          consumptionId: 'drifted-calculation',
        ),
        throwsA(
          isA<NutritionConsumptionPersistenceError>().having(
            (error) => error.code,
            'code',
            'snapshot_result_mismatch',
          ),
        ),
      );

      final graph = await NutritionBackupGraph.capture(db);
      expect(
        () => NutritionBackupGraph.fromJson(graph.toJson()),
        throwsA(
          isA<BackupV8ValidationException>().having(
            (error) => error.code,
            'code',
            'snapshot_result_mismatch',
          ),
        ),
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
      commandId: 'command-1',
    );
    final first = await repository.finalizeConsumption(request);
    final retry = await repository.finalizeConsumption(request);
    expect(retry.id, first.id);
    expect(first.id, startsWith('consumption-'));
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
    'idempotent retry does not re-resolve mutable evidence after commit',
    () async {
      await _insertFood(db, 'food-1', 'Food');
      await db
          .into(db.nutritionHouseholdMeasures)
          .insert(
            NutritionHouseholdMeasuresCompanion.insert(
              id: 'measure-1',
              key: 'test_cup',
              displayName: 'Test cup',
              dimension: 'volume',
              baseUnit: 'millilitre',
              nominalValue: 240,
              locale: 'en-IN',
              version: 1,
            ),
          );
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
        consumptionId: 'mutable-evidence-consumption',
        commandId: 'mutable-evidence-command',
        evidence: {
          'measure': {'measure_id': 'measure-1', 'definition_version': 1},
        },
      );
      final first = await repository.finalizeConsumption(request);
      await (db.delete(db.nutritionHouseholdMeasures)).go();

      final retry = await repository.finalizeConsumption(request);
      expect(retry.id, first.id);
      expect(
        await db.select(db.nutritionConsumptionSnapshots).get(),
        hasLength(1),
      );
    },
  );

  test('rejects an item identity that schema-v17 cannot persist', () async {
    final repository = NutritionConsumptionRepository(
      db: db,
      registry: registry,
    );
    await expectLater(
      repository.finalizeConsumption(
        NutritionConsumptionFinalizeRequest(
          userId: 'user-1',
          consumptionId: 'source-only-consumption',
          loggedAtUtc: DateTime.utc(2026, 8, 4, 10),
          mealCategory: 'lunch',
          sourceType: 'estimate',
          localDate: '2026-08-04',
          timezoneId: 'Asia/Kolkata',
          calculatorVersion: 'snapshot-test-v1',
          items: [
            NutritionConsumptionItemInput(
              id: 'source-only-item',
              position: 0,
              sourceType: 'estimate',
              sourceReference: 'estimate-1',
              quantity: Quantity.fromDecimal(
                amount: '1',
                unit: QuantityUnit.serving,
                context: const QuantityContext(
                  servingDefinition: ServingDefinitionReference(
                    id: 'estimate-serving',
                    revision: '1',
                  ),
                ),
              ),
              calculation: _calculation(
                registry,
                facts: {'protein': _known('protein', '5')},
                requested: const ['protein'],
              ),
            ),
          ],
        ),
      ),
      throwsA(
        isA<NutritionConsumptionValidationError>().having(
          (error) => error.code,
          'code',
          'invalid_consumed_item_identity',
        ),
      ),
    );
    expect(await db.select(db.nutritionConsumptionSnapshots).get(), isEmpty);
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

  test('rejects a mutable draft recipe version', () async {
    await db
        .into(db.nutritionRecipes)
        .insert(
          NutritionRecipesCompanion.insert(
            id: 'draft-recipe',
            userId: 'user-1',
            name: 'Draft recipe',
            lifecycle: 'active',
          ),
        );
    await db
        .into(db.nutritionRecipeVersions)
        .insert(
          NutritionRecipeVersionsCompanion.insert(
            id: 'draft-recipe-version',
            recipeId: 'draft-recipe',
            versionNumber: 1,
            status: 'draft',
            calcRuleVersion: 'snapshot-test-v1',
            source: '{}',
          ),
        );
    final repository = NutritionConsumptionRepository(
      db: db,
      registry: registry,
    );
    await expectLater(
      repository.finalizeConsumption(
        NutritionConsumptionFinalizeRequest(
          userId: 'user-1',
          consumptionId: 'draft-consumption',
          loggedAtUtc: DateTime.utc(2026, 8, 4, 10),
          mealCategory: 'lunch',
          sourceType: 'recipe_version',
          recipeVersionId: 'draft-recipe-version',
          localDate: '2026-08-04',
          timezoneId: 'Asia/Kolkata',
          calculatorVersion: 'snapshot-test-v1',
          items: [
            NutritionConsumptionItemInput(
              id: 'draft-item',
              position: 0,
              sourceType: 'recipe_version',
              recipeVersionId: 'draft-recipe-version',
              quantity: Quantity.fromDecimal(
                amount: '1',
                unit: QuantityUnit.serving,
                context: const QuantityContext(
                  servingDefinition: ServingDefinitionReference(
                    id: 'draft-serving',
                    revision: '1',
                  ),
                ),
              ),
              calculation: _calculation(
                registry,
                facts: {'protein': _known('protein', '5')},
                requested: const ['protein'],
              ),
            ),
          ],
        ),
      ),
      throwsA(
        isA<NutritionConsumptionValidationError>().having(
          (error) => error.code,
          'code',
          'mutable_recipe_version',
        ),
      ),
    );
    expect(await db.select(db.nutritionConsumptionSnapshots).get(), isEmpty);
  });

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

  test(
    'corrections remain exclusive when the successor is on another local date',
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
          consumptionId: 'original-cross-date',
          commandId: 'original-cross-date-command',
          itemId: 'cross-date-item-1',
        ),
      );
      await repository.finalizeConsumption(
        _request(
          calculation: _calculation(
            registry,
            facts: {'protein': _known('protein', '12')},
            requested: const ['protein'],
          ),
          consumptionId: 'successor-cross-date',
          commandId: 'successor-cross-date-command',
          itemId: 'cross-date-item-2',
          loggedAtUtc: DateTime.utc(2026, 8, 4, 19),
          localDate: '2026-08-05',
          supersedesSnapshotId: original.id,
          correctionId: 'cross-date-correction',
          correctionReason: 'Corrected on the following day',
        ),
      );

      final originalDay = await repository.dailyTotals(
        userId: 'user-1',
        localDate: '2026-08-04',
      );
      final successorDay = await repository.dailyTotals(
        userId: 'user-1',
        localDate: '2026-08-05',
      );
      expect(originalDay.snapshotIds, isEmpty);
      expect(successorDay.snapshotIds, ['successor-cross-date']);
      expect(
        successorDay.totals.facts['protein']!.point!.value.toString(),
        '12',
      );
    },
  );

  test('a finalized event cannot have two correction successors', () async {
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
        consumptionId: 'branch-original',
        commandId: 'branch-original-command',
        itemId: 'branch-item-1',
      ),
    );
    await repository.finalizeConsumption(
      _request(
        calculation: _calculation(
          registry,
          facts: {'protein': _known('protein', '11')},
          requested: const ['protein'],
        ),
        consumptionId: 'branch-successor-1',
        commandId: 'branch-successor-command-1',
        itemId: 'branch-item-2',
        supersedesSnapshotId: original.id,
        correctionId: 'branch-correction-1',
        correctionReason: 'First correction',
      ),
    );
    await expectLater(
      repository.finalizeConsumption(
        _request(
          calculation: _calculation(
            registry,
            facts: {'protein': _known('protein', '12')},
            requested: const ['protein'],
          ),
          consumptionId: 'branch-successor-2',
          commandId: 'branch-successor-command-2',
          itemId: 'branch-item-3',
          supersedesSnapshotId: original.id,
          correctionId: 'branch-correction-2',
          correctionReason: 'Second correction',
        ),
      ),
      throwsA(
        isA<NutritionConsumptionValidationError>().having(
          (error) => error.code,
          'code',
          'correction_predecessor_already_superseded',
        ),
      ),
    );
  });

  test(
    'backup validation rejects a nutrient attached across snapshots',
    () async {
      await _insertFood(db, 'food-1', 'Food');
      final repository = NutritionConsumptionRepository(
        db: db,
        registry: registry,
      );
      await repository.finalizeConsumption(
        _request(
          calculation: _calculation(
            registry,
            facts: {'protein': _known('protein', '10')},
            requested: const ['protein'],
          ),
          consumptionId: 'backup-snapshot-1',
          commandId: 'backup-command-1',
        ),
      );
      await repository.finalizeConsumption(
        _request(
          calculation: _calculation(
            registry,
            facts: {'protein': _known('protein', '11')},
            requested: const ['protein'],
          ),
          consumptionId: 'backup-snapshot-2',
          commandId: 'backup-command-2',
          itemId: 'backup-item-2',
        ),
      );
      final graph = await NutritionBackupGraph.capture(db);
      final tables = <String, List<Map<String, dynamic>>>{
        for (final entry in graph.tables.entries)
          entry.key: [
            for (final row in entry.value) Map<String, dynamic>.from(row),
          ],
      };
      final nutrientRows = tables['nutrition_snapshot_nutrients']!;
      final snapshotRows = tables['nutrition_consumption_snapshots']!;
      nutrientRows.first['snapshot_id'] = snapshotRows.last['id'];
      expect(
        () => NutritionBackupGraph.fromJson(
          NutritionBackupGraph(
            graphVersion: graph.graphVersion,
            manifestVersion: graph.manifestVersion,
            nutrientRegistryVersion: graph.nutrientRegistryVersion,
            tables: tables,
          ).toJson(),
        ),
        throwsA(
          isA<BackupV8ValidationException>().having(
            (error) => error.code,
            'code',
            'cross_snapshot_nutrient_owner',
          ),
        ),
      );
    },
  );

  test(
    'historical reads and Backup-v8 reject drifted nutrient projections',
    () async {
      await _insertFood(db, 'food-1', 'Food');
      final repository = NutritionConsumptionRepository(
        db: db,
        registry: registry,
      );
      await repository.finalizeConsumption(
        _request(
          calculation: _calculation(
            registry,
            facts: {'protein': _known('protein', '10')},
            requested: const ['protein'],
          ),
          consumptionId: 'projection-integrity',
          commandId: 'projection-integrity-command',
        ),
      );
      await (db.update(
        db.nutritionSnapshotNutrients,
      )).write(const NutritionSnapshotNutrientsCompanion(amount: Value(999)));
      await expectLater(
        repository.getSnapshot(
          userId: 'user-1',
          consumptionId: 'projection-integrity',
        ),
        throwsA(
          isA<NutritionConsumptionPersistenceError>().having(
            (error) => error.code,
            'code',
            'nutrient_row_mismatch',
          ),
        ),
      );
      final graph = await NutritionBackupGraph.capture(db);
      expect(
        () => NutritionBackupGraph.fromJson(graph.toJson()),
        throwsA(
          isA<BackupV8ValidationException>().having(
            (error) => error.code,
            'code',
            'nutrient_projection_mismatch',
          ),
        ),
      );
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
  String? consumptionId,
  String? commandId,
  Map<String, dynamic> evidence = const {},
  String? supersedesSnapshotId,
  String? correctionId,
  String? correctionReason,
  String itemId = 'item-1',
  DateTime? loggedAtUtc,
  String localDate = '2026-08-04',
  String timezoneId = 'Asia/Kolkata',
}) => NutritionConsumptionFinalizeRequest(
  userId: 'user-1',
  consumptionId: consumptionId,
  commandId: commandId,
  loggedAtUtc: loggedAtUtc ?? DateTime.utc(2026, 8, 4, 10),
  mealCategory: 'lunch',
  sourceType: 'direct_food',
  localDate: localDate,
  timezoneId: timezoneId,
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
