import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/nutrition_constraints.dart';
import 'package:indifit/core/nutrition_consumption_snapshots.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart'
    hide NutritionConsumptionSnapshot;
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_logging_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/data/repositories/nutrition_transformation_repository.dart';
import 'package:indifit/features/food_log/food_log_surface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R08D.4 canonical direct-food correction', () {
    test(
      'updates one exact item in an atomic batch and preserves the other item',
      () async {
        final harness = await _EditHarness.create();
        addTearDown(harness.close);
        final first = await harness.food(
          'First correction food',
          energy: 200,
          protein: 10,
        );
        final second = await harness.food(
          'Second unchanged food',
          energy: 120,
          protein: 6,
        );
        final original = await harness.batch([first, second]);
        final replacement = await harness.logger.preview(
          option: first,
          quantity: _serving(first, '2'),
        );

        final corrected = await harness.logger.correctDirectFoodItem(
          userId: harness.userId,
          snapshotId: original.id,
          itemId: original.items.first.id,
          expectedMealCategory: 'breakfast',
          mealCategory: 'lunch',
          localDate: '2026-08-24',
          timezoneId: 'Asia/Kolkata',
          loggedAtUtc: original.loggedAtUtc,
          commandId: 'r08d4-update-item-1',
          correctionReason: 'User edited logged food.',
          replacement: replacement,
        );

        expect(corrected.lineage.supersedesSnapshotId, original.id);
        expect(corrected.mealCategory, 'lunch');
        expect(corrected.localDate, '2026-08-24');
        expect(corrected.timezoneId, 'Asia/Kolkata');
        expect(corrected.items, hasLength(2));
        expect(corrected.items[0].foodId, first.id);
        expect(corrected.items[0].quantity.amount.toString(), '2');
        expect(corrected.items[1].foodId, second.id);
        expect(corrected.items[1].quantity.amount.toString(), '1');
        expect(corrected.items[0].facts['energy']!.point!.value.asDouble, 400);
        expect(
          (await harness.consumption.getSnapshot(
            userId: harness.userId,
            consumptionId: original.id,
          ))!.items.first.quantity.amount.toString(),
          '1',
        );

        final history = await harness.history.listForLocalDate(
          userId: harness.userId,
          localDate: '2026-08-24',
        );
        expect(history, hasLength(1));
        expect(history.single.stableId, corrected.id);
        expect(history.single.items, hasLength(2));
        expect(
          history.single.totals.facts['energy']!.point!.value.asDouble,
          520,
        );
      },
    );

    test(
      'supports a same-dimension unit update without inventing conversion',
      () async {
        final harness = await _EditHarness.create();
        addTearDown(harness.close);
        final food = await harness.massFood('Mass correction food');
        final original = await harness.single(
          food,
          quantity: food.baseQuantity,
          meal: 'dinner',
        );
        final replacement = await harness.logger.preview(
          option: food,
          quantity: Quantity.fromNum(amount: 1, unit: QuantityUnit.kilogram),
        );

        final corrected = await harness.logger.correctDirectFoodItem(
          userId: harness.userId,
          snapshotId: original.id,
          itemId: original.items.single.id,
          expectedMealCategory: 'dinner',
          mealCategory: 'dinner',
          localDate: '2026-08-24',
          timezoneId: 'Asia/Kolkata',
          loggedAtUtc: original.loggedAtUtc,
          commandId: 'r08d4-unit-update-1',
          correctionReason: 'User edited logged food.',
          replacement: replacement,
        );

        expect(corrected.items.single.quantity.unit, QuantityUnit.kilogram);
        expect(corrected.items.single.quantity.amount.toString(), '1');
        expect(
          corrected.items.single.facts['energy']!.point!.value.asDouble,
          2000,
        );
      },
    );

    test(
      'unsupported conversion fails before persistence and keeps the old entry',
      () async {
        final harness = await _EditHarness.create();
        addTearDown(harness.close);
        final food = await harness.food('Serving-only food', energy: 200);
        final original = await harness.single(food);

        expect(
          () => food.baseQuantity.convertTo(QuantityUnit.gram),
          throwsA(isA<QuantityError>()),
        );
        expect(
          await harness.consumption.listAllForUser(userId: harness.userId),
          hasLength(1),
        );
        expect(original.items.single.quantity.unit, QuantityUnit.serving);
      },
    );

    test(
      'deletes one exact item from a batch and leaves identical intentional entries distinct',
      () async {
        final harness = await _EditHarness.create();
        addTearDown(harness.close);
        final food = await harness.food(
          'Two intentional servings',
          energy: 150,
        );
        final original = await harness.batch([food, food]);
        expect(original.items, hasLength(2));
        expect(original.items[0].foodId, original.items[1].foodId);

        final corrected = await harness.logger.correctDirectFoodItem(
          userId: harness.userId,
          snapshotId: original.id,
          itemId: original.items[1].id,
          expectedMealCategory: 'breakfast',
          mealCategory: 'breakfast',
          localDate: '2026-08-24',
          timezoneId: 'Asia/Kolkata',
          loggedAtUtc: original.loggedAtUtc,
          commandId: 'r08d4-delete-second-1',
          correctionReason: 'User deleted logged food.',
        );

        expect(corrected.items, hasLength(1));
        expect(corrected.items.single.foodId, food.id);
        expect(
          (await harness.history.listForLocalDate(
            userId: harness.userId,
            localDate: '2026-08-24',
          )).single.items,
          hasLength(1),
        );
      },
    );

    test(
      'deleting the first batch item keeps the remaining position valid',
      () async {
        final harness = await _EditHarness.create();
        addTearDown(harness.close);
        final first = await harness.food('First item to delete');
        final second = await harness.food('Remaining second item');
        final original = await harness.batch([first, second]);

        final corrected = await harness.logger.correctDirectFoodItem(
          userId: harness.userId,
          snapshotId: original.id,
          itemId: original.items.first.id,
          expectedMealCategory: 'breakfast',
          mealCategory: 'breakfast',
          localDate: '2026-08-24',
          timezoneId: 'Asia/Kolkata',
          loggedAtUtc: original.loggedAtUtc,
          commandId: 'r08d4-delete-first-1',
          correctionReason: 'User deleted logged food.',
        );

        expect(corrected.items.single.foodId, second.id);
        expect(corrected.items.single.position, 0);
      },
    );

    test(
      'failed correction rolls back and retrying the same command is idempotent',
      () async {
        var shouldFail = false;
        final harness = await _EditHarness.create(
          failureInjector: (stage) {
            if (shouldFail && stage == 'after_items') {
              throw StateError('injected D.4 failure');
            }
          },
        );
        addTearDown(harness.close);
        final food = await harness.food(
          'Retryable correction food',
          energy: 100,
        );
        final original = await harness.single(food);
        final replacement = await harness.logger.preview(
          option: food,
          quantity: _serving(food, '3'),
        );
        shouldFail = true;

        Future<NutritionConsumptionSnapshot> correct() =>
            harness.logger.correctDirectFoodItem(
              userId: harness.userId,
              snapshotId: original.id,
              itemId: original.items.single.id,
              expectedMealCategory: 'breakfast',
              mealCategory: 'breakfast',
              localDate: '2026-08-24',
              timezoneId: 'Asia/Kolkata',
              loggedAtUtc: original.loggedAtUtc,
              commandId: 'r08d4-retry-command',
              correctionReason: 'User edited logged food.',
              replacement: replacement,
            );

        await expectLater(correct(), throwsA(isA<NutritionFoodLoggingError>()));
        expect(
          await harness.consumption.listAllForUser(userId: harness.userId),
          hasLength(1),
        );
        shouldFail = false;
        final firstSuccess = await correct();
        final retry = await correct();
        expect(retry.id, firstSuccess.id);
        expect(
          await harness.consumption.listAllForUser(userId: harness.userId),
          hasLength(2),
        );
      },
    );

    test(
      'successor remains the only current record and stale predecessor cannot be edited',
      () async {
        final harness = await _EditHarness.create();
        addTearDown(harness.close);
        final food = await harness.food('Successor lineage food', energy: 100);
        final original = await harness.single(food);
        final twice = await harness.logger.preview(
          option: food,
          quantity: _serving(food, '2'),
        );
        final firstSuccessor = await harness.logger.correctDirectFoodItem(
          userId: harness.userId,
          snapshotId: original.id,
          itemId: original.items.single.id,
          expectedMealCategory: 'breakfast',
          mealCategory: 'lunch',
          localDate: '2026-08-24',
          timezoneId: 'Asia/Kolkata',
          loggedAtUtc: original.loggedAtUtc,
          commandId: 'r08d4-lineage-first',
          correctionReason: 'User edited logged food.',
          replacement: twice,
        );
        final thrice = await harness.logger.preview(
          option: food,
          quantity: _serving(food, '3'),
        );
        final current = await harness.logger.correctDirectFoodItem(
          userId: harness.userId,
          snapshotId: firstSuccessor.id,
          itemId: firstSuccessor.items.single.id,
          expectedMealCategory: 'lunch',
          mealCategory: 'lunch',
          localDate: '2026-08-24',
          timezoneId: 'Asia/Kolkata',
          loggedAtUtc: firstSuccessor.loggedAtUtc,
          commandId: 'r08d4-lineage-second',
          correctionReason: 'User edited logged food.',
          replacement: thrice,
        );

        expect(current.lineage.supersedesSnapshotId, firstSuccessor.id);
        expect(current.items.single.quantity.amount.toString(), '3');
        final history = await harness.history.listForLocalDate(
          userId: harness.userId,
          localDate: '2026-08-24',
        );
        expect(history, hasLength(1));
        expect(history.single.stableId, current.id);

        await expectLater(
          harness.logger.correctDirectFoodItem(
            userId: harness.userId,
            snapshotId: original.id,
            itemId: original.items.single.id,
            expectedMealCategory: 'breakfast',
            mealCategory: 'breakfast',
            localDate: '2026-08-24',
            timezoneId: 'Asia/Kolkata',
            loggedAtUtc: original.loggedAtUtc,
            commandId: 'r08d4-stale-predecessor',
            correctionReason: 'User edited logged food.',
            replacement: twice,
          ),
          throwsA(
            isA<NutritionFoodLoggingError>().having(
              (error) => error.code,
              'code',
              'correction_predecessor_already_superseded',
            ),
          ),
        );

        await harness.logger.correctDirectFoodItem(
          userId: harness.userId,
          snapshotId: current.id,
          itemId: current.items.single.id,
          expectedMealCategory: 'lunch',
          mealCategory: 'lunch',
          localDate: '2026-08-24',
          timezoneId: 'Asia/Kolkata',
          loggedAtUtc: current.loggedAtUtc,
          commandId: 'r08d4-delete-current-successor',
          correctionReason: 'User deleted logged food.',
        );
        expect(
          await harness.history.listForLocalDate(
            userId: harness.userId,
            localDate: '2026-08-24',
          ),
          isEmpty,
        );
      },
    );

    test(
      'constraint-bearing snapshot and unsupported meal fail closed',
      () async {
        final harness = await _EditHarness.create();
        addTearDown(harness.close);
        final food = await harness.food('Constraint-bearing food');
        final constrained = await harness.constrainedSingle(food);
        final replacement = await harness.logger.preview(
          option: food,
          quantity: _serving(food, '2'),
        );

        await expectLater(
          harness.logger.correctDirectFoodItem(
            userId: harness.userId,
            snapshotId: constrained.id,
            itemId: constrained.items.single.id,
            expectedMealCategory: 'breakfast',
            mealCategory: 'breakfast',
            localDate: '2026-08-24',
            timezoneId: 'Asia/Kolkata',
            loggedAtUtc: constrained.loggedAtUtc,
            commandId: 'r08d4-constrained-edit',
            correctionReason: 'User edited logged food.',
            replacement: replacement,
          ),
          throwsA(
            isA<NutritionFoodLoggingError>().having(
              (error) => error.code,
              'code',
              'unsupported_food_correction_constraints',
            ),
          ),
        );
        await expectLater(
          harness.logger.correctDirectFoodItem(
            userId: harness.userId,
            snapshotId: constrained.id,
            itemId: constrained.items.single.id,
            expectedMealCategory: 'breakfast',
            mealCategory: 'brunch',
            localDate: '2026-08-24',
            timezoneId: 'Asia/Kolkata',
            loggedAtUtc: constrained.loggedAtUtc,
            commandId: 'r08d4-unsupported-meal',
            correctionReason: 'User edited logged food.',
            replacement: replacement,
          ),
          throwsA(
            isA<NutritionFoodLoggingError>().having(
              (error) => error.code,
              'code',
              'unsupported_food_correction_meal',
            ),
          ),
        );
        expect(
          await harness.history.listForLocalDate(
            userId: harness.userId,
            localDate: '2026-08-24',
          ),
          hasLength(1),
        );
      },
    );
  });

  testWidgets(
    'direct batch items render as independently actionable rows at 320pt and 2x text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final record = _widgetCanonicalRecord();
      String? tappedItem;
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foodLogsForDayProvider.overrideWith((ref, date) async => const []),
            canonicalFoodRecordsForDayProvider.overrideWith(
              (ref, date) async => [record],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: FoodLogEntriesPanel(
                  date: DateTime(2026, 8, 24),
                  onCanonicalItemTap: (entry, item) =>
                      tappedItem = item.stableId,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('First visible item'), findsOneWidget);
      expect(find.text('Second visible item'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Actions for First visible item'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Actions for Second visible item'),
        findsOneWidget,
      );
      await tester.tap(
        find.bySemanticsLabel('Actions for Second visible item'),
      );
      await tester.pump();
      expect(tappedItem, record.items[1].stableId);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}

Quantity _serving(NutritionFoodOption option, String amount) =>
    Quantity.serving(
      amount: amount,
      definition: option.baseQuantity.context.servingDefinition!,
      source: 'r08d4-test',
    );

NutritionHistoricalReadRecord _widgetCanonicalRecord() {
  final serving = Quantity.serving(
    amount: '1',
    definition: const ServingDefinitionReference(
      id: 'r08d4-widget-serving',
      revision: 'v1',
      source: 'test',
    ),
    source: 'r08d4-test',
  );
  final first = _widgetItem(
    id: 'r08d4-widget-item-1',
    label: 'First visible item',
    quantity: serving,
    energy: 100,
    protein: 10,
  );
  final second = _widgetItem(
    id: 'r08d4-widget-item-2',
    label: 'Second visible item',
    quantity: serving,
    energy: 80,
    protein: 8,
  );
  final completeness = NutrientCompleteness(
    state: NutrientCompletenessState.complete,
    requestedNutrientIds: const ['energy', 'protein'],
    availableNutrientIds: const ['energy', 'protein'],
    missingNutrientIds: const [],
    estimatedNutrientIds: const [],
    notApplicableNutrientIds: const [],
    partiallyKnownNutrientIds: const [],
  );
  final totals = NutrientAggregationResult(
    facts: {
      'energy': _widgetFact('energy', 180, NutrientUnit.kilocalorie),
      'protein': _widgetFact('protein', 18, NutrientUnit.gram),
    },
    completeness: completeness,
    sourceLineage: const {
      'energy': [NutrientSourceType.userEntered],
      'protein': [NutrientSourceType.userEntered],
    },
    factVersionLineage: const {
      'energy': ['r08d4-widget-v1'],
      'protein': ['r08d4-widget-v1'],
    },
  );
  return _WidgetCanonicalRecord(
    items: [first, second],
    completeness: completeness,
    totals: totals,
  );
}

NutritionHistoricalReadItem _widgetItem({
  required String id,
  required String label,
  required Quantity quantity,
  required double energy,
  required double protein,
}) {
  final facts = {
    'energy': _widgetFact('energy', energy, NutrientUnit.kilocalorie),
    'protein': _widgetFact('protein', protein, NutrientUnit.gram),
  };
  return NutritionHistoricalReadItem(
    stableId: id,
    position: id.endsWith('1') ? 0 : 1,
    sourceType: 'canonical_snapshot',
    originSourceType: 'direct_food',
    sourceReference: 'r08d4-widget-source::$id',
    displayLabel: label,
    foodId: 'r08d4-widget-food::$id',
    recipeVersionId: null,
    quantity: NutritionHistoricalQuantity(
      storedAmount: quantity.amount.asDouble,
      storedUnit: quantity.definition.stableId,
      quantity: quantity,
      state: NutritionHistoricalQuantityState.typed,
      issues: const [],
    ),
    facts: facts,
    issues: const [],
  );
}

NutrientFact _widgetFact(String id, double value, NutrientUnit unit) {
  return NutrientFact.known(
    nutrientId: id,
    point: NutrientAmount(value: QuantityAmount.fromNum(value), unit: unit),
    basis: NutrientBasis(NutrientBasisKind.absolute),
    source: NutrientSourceType.userEntered,
    factVersion: 'r08d4-widget-v1',
  );
}

class _WidgetCanonicalRecord implements NutritionHistoricalReadRecord {
  _WidgetCanonicalRecord({
    required this.items,
    required this.completeness,
    required this.totals,
  });

  @override
  final List<NutritionHistoricalReadItem> items;

  @override
  final NutrientCompleteness completeness;

  @override
  final NutrientAggregationResult totals;

  @override
  String get stableId => 'r08d4-widget-snapshot';

  @override
  String get userId => 'r08d4-test-user';

  @override
  String get sourceType => 'canonical_snapshot';

  @override
  DateTime get loggedAtUtc => DateTime.utc(2026, 8, 24, 5);

  @override
  String get localDate => '2026-08-24';

  @override
  String get mealCategory => 'breakfast';

  @override
  String? get mealGroupId => 'r08d4-widget-meal';

  @override
  String get displayLabel => 'Canonical nutrition snapshot';

  @override
  List<NutritionCompatibilityIssue> get issues => const [];

  @override
  bool get isLegacy => false;
}

class _EditHarness {
  _EditHarness({
    required this.database,
    required this.registry,
    required this.catalog,
    required this.consumption,
    required this.logger,
    required this.history,
  });

  static const _userId = 'r08d4-test-user';

  final AppDatabase database;
  final NutrientRegistry registry;
  final NutritionFoodCatalogRepository catalog;
  final NutritionConsumptionRepository consumption;
  final NutritionFoodLoggingCoordinator logger;
  final NutritionReadModelRepository history;

  String get userId => _userId;

  static Future<_EditHarness> create({
    NutritionConsumptionFailureInjector? failureInjector,
  }) async {
    final database = AppDatabase.memory();
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    final catalog = NutritionFoodCatalogRepository(
      db: database,
      registry: registry,
    );
    final consumption = NutritionConsumptionRepository(
      db: database,
      registry: registry,
      failureInjector: failureInjector,
    );
    final logger = NutritionFoodLoggingCoordinator(
      db: database,
      registry: registry,
      catalog: catalog,
      calculator: const NutritionCalculationService(),
      consumption: consumption,
      transformations: NutritionTransformationRepository(db: database),
    );
    final history = NutritionReadModelRepository(
      db: database,
      registry: registry,
      canonicalRepository: consumption,
    );
    return _EditHarness(
      database: database,
      registry: registry,
      catalog: catalog,
      consumption: consumption,
      logger: logger,
      history: history,
    );
  }

  Future<NutritionFoodOption> food(
    String name, {
    double energy = 200,
    double protein = 10,
  }) => catalog.createUserFood(
    displayName: name,
    servingSize: 1,
    servingUnit: 'serving',
    energyKcal: energy,
    proteinG: protein,
    carbohydrateG: 20,
    fatG: 8,
  );

  Future<NutritionFoodOption> massFood(String name) =>
      catalog.ensureProviderFood(
        displayName: name,
        sourceReference: 'r08d4-provider::$name',
        servingSize: 100,
        servingUnit: 'g',
        energyKcal: 200,
        proteinG: 10,
        carbohydrateG: 20,
        fatG: 8,
      );

  Future<NutritionConsumptionSnapshot> single(
    NutritionFoodOption option, {
    Quantity? quantity,
    String meal = 'breakfast',
  }) async {
    final preview = await logger.preview(
      option: option,
      quantity: quantity ?? option.baseQuantity,
    );
    return logger.finalize(
      userId: userId,
      preview: preview,
      mealCategory: meal,
      loggedAt: DateTime.utc(2026, 8, 24, 5),
      localDate: '2026-08-24',
      timezoneId: 'Asia/Kolkata',
      commandId: 'r08d4-single-${option.id}',
      consumptionId: 'r08d4-single-consumption-${option.id}',
    );
  }

  Future<NutritionConsumptionSnapshot> batch(
    List<NutritionFoodOption> options,
  ) async {
    final previews = await Future.wait(
      options.map(
        (option) =>
            logger.preview(option: option, quantity: option.baseQuantity),
      ),
    );
    final result = await logger.finalizeBatch(
      userId: userId,
      previews: previews,
      mealCategory: 'breakfast',
      mealGroupId: 'r08d4-meal-group',
      loggedAt: DateTime.utc(2026, 8, 24, 5),
      localDate: '2026-08-24',
      timezoneId: 'Asia/Kolkata',
      commandId: 'r08d4-batch-${options.map((option) => option.id).join('|')}',
      consumptionId:
          'r08d4-batch-consumption-${options.length}-${options.first.id}',
    );
    return result;
  }

  Future<NutritionConsumptionSnapshot> constrainedSingle(
    NutritionFoodOption option,
  ) async {
    final preview = await logger.preview(
      option: option,
      quantity: option.baseQuantity,
    );
    return consumption.finalizeConsumption(
      NutritionConsumptionFinalizeRequest(
        userId: userId,
        consumptionId: 'r08d4-constrained-${option.id}',
        commandId: 'r08d4-constrained-command-${option.id}',
        loggedAtUtc: DateTime.utc(2026, 8, 24, 5),
        mealCategory: 'breakfast',
        sourceType: 'direct_food',
        localDate: '2026-08-24',
        timezoneId: 'Asia/Kolkata',
        calculatorVersion: preview.calculation.calculationRuleVersion,
        items: [
          NutritionConsumptionItemInput(
            id: 'r08d4-constrained-item-${option.id}',
            position: 0,
            sourceType: 'direct_food',
            foodId: option.id,
            sourceReference: option.sourceReference,
            displayLabel: option.displayName,
            quantity: preview.quantity,
            calculation: preview.calculationSnapshot,
          ),
        ],
        constraintEvaluation: NutritionConstraintEvaluationResult(
          userId: userId,
          subjectId: option.id,
          foodId: option.id,
          recipeVersionId: null,
          outcome: NutritionConstraintOutcome.noKnownConflict,
          evaluations: const [],
          missingEvidence: const [],
          provenanceSummary: const ['r08d4-test'],
          evaluatedAtUtc: DateTime.utc(2026, 8, 24, 5),
        ),
      ),
    );
  }

  Future<void> close() => database.close();
}
