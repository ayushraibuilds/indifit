import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/nutrition_constraints.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/nutrition_thali.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart'
    hide
        NutritionConsumptionSnapshot,
        NutritionThaliItem,
        NutritionUserConstraint;
import 'package:indifit/data/repositories/nutrition_constraint_repository.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_household_measure_repository.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/data/repositories/nutrition_recipe_log_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_recipe_repository.dart';
import 'package:indifit/data/repositories/nutrition_thali_repository.dart';
import 'package:indifit/features/food_log/nutrition_thali_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('B03-13 thali composition', () {
    test(
      'empty drafts cannot preview, and duplicate items retain identity',
      () async {
        final harness = await _ThaliHarness.create();
        addTearDown(harness.close);
        final empty = harness.repository.newDraft(userId: harness.userId);

        expect(
          () => harness.repository.preview(draft: empty),
          throwsA(
            isA<NutritionThaliValidationError>().having(
              (error) => error.code,
              'code',
              'empty_thali',
            ),
          ),
        );

        final first = harness.foodItem('food-a', 0);
        final second = harness.foodItem('food-a', 1);
        final draft = empty.copyWith(items: [first, second]);
        expect(draft.items.map((item) => item.id), ['item-a', 'item-b']);
        expect(draft.items.map((item) => item.foodId), ['food-a', 'food-a']);
      },
    );

    test(
      'direct food and immutable recipe versions coexist and aggregate through B03-08',
      () async {
        final harness = await _ThaliHarness.create();
        addTearDown(harness.close);
        final recipe = await harness.createPublishedRecipe();
        final draft = harness.repository.newDraft(
          userId: harness.userId,
          name: 'Mixed meal',
          items: [
            harness.foodItem('food-a', 0),
            NutritionThaliItem(
              id: 'item-recipe',
              position: 1,
              source: NutritionThaliItemSource.recipe,
              foodId: null,
              recipeVersionId: recipe.id,
              quantity: Quantity(
                amount: QuantityAmount.one,
                unit: QuantityUnit.serving,
                context: QuantityContext(
                  servingDefinition: ServingDefinitionReference(
                    id: 'recipe-complete:${recipe.id}',
                    revision: 'recipe-version',
                    source: 'recipe_version',
                  ),
                ),
              ),
              displayLabel: 'Saved recipe',
            ),
          ],
        );

        final preview = await harness.repository.preview(draft: draft);
        expect(preview.items, hasLength(2));
        expect(preview.items[1].item.recipeVersionId, recipe.id);
        expect(
          preview.aggregate.facts['energy']?.point?.value.toString(),
          '200',
        );
        expect(preview.constraintEvaluation?.thaliId, draft.id);

        final savedDraft = await harness.repository.saveDraft(draft);
        final restored = await harness.repository.getDraft(
          userId: harness.userId,
          thaliId: draft.id,
        );
        expect(savedDraft.currentVersion, 1);
        expect(restored!.items.map((item) => item.id), [
          'item-a',
          'item-recipe',
        ]);
        expect(
          restored.items
              .singleWhere((item) => item.id == 'item-recipe')
              .recipeVersionId,
          recipe.id,
        );
      },
    );

    test(
      'reordering is identity-stable and quantities reject zero and negative values',
      () async {
        final harness = await _ThaliHarness.create();
        addTearDown(harness.close);
        final controller = NutritionThaliController(
          repository: Future.value(harness.repository),
          userId: harness.userId,
          mealCategory: 'lunch',
        );
        addTearDown(controller.dispose);
        await controller.initialize();
        const option = NutritionThaliFoodOption(
          id: 'food-a',
          displayName: 'Rice',
          kind: 'canonical',
          sourceType: 'fixture',
          region: 'IN',
        );
        controller.addFood(option);
        controller.addFood(option);
        final ids = controller.state.draft!.items
            .map((item) => item.id)
            .toList();
        controller.reorderItem(0, 2);
        expect(controller.state.draft!.items.map((item) => item.id), [
          ids[1],
          ids[0],
        ]);

        controller.setQuantity(
          ids[0],
          Quantity.fromDecimal(amount: '0', unit: QuantityUnit.gram),
        );
        expect(controller.state.status, NutritionThaliStatus.failure);
        expect(controller.state.errorCode, 'invalid_quantity');
        expect(
          controller.state.draft!.items
              .firstWhere((item) => item.id == ids[0])
              .quantity
              .amount
              .toString(),
          '100',
        );

        expect(
          () => Quantity.fromDecimal(amount: '-1', unit: QuantityUnit.gram),
          throwsA(isA<QuantityError>()),
        );
      },
    );

    test(
      'one immutable thali finalizes transactionally, retries, and is idempotent',
      () async {
        final harness = await _ThaliHarness.create();
        addTearDown(harness.close);
        final draft = harness.repository.newDraft(
          userId: harness.userId,
          items: [harness.foodItem('food-a', 0)],
        );
        final preview = await harness.repository.preview(
          draft: await harness.repository.saveDraft(draft),
        );

        var inject = true;
        final failing = harness.withConsumption(
          NutritionConsumptionRepository(
            db: harness.db,
            registry: harness.registry,
            failureInjector: (stage) {
              if (stage == 'after_items' && inject) {
                inject = false;
                throw StateError('injected failure');
              }
            },
          ),
        );
        expect(
          () => failing.finalize(
            preview: preview,
            mealCategory: 'lunch',
            loggedAt: DateTime.utc(2026, 8, 4, 12),
            commandId: 'thali-retry-command',
            consumptionId: 'thali-retry-consumption',
            allowPartial: true,
          ),
          throwsA(isA<NutritionThaliError>()),
        );
        expect(
          await harness.consumption.listAllForUser(userId: harness.userId),
          isEmpty,
        );

        final saved = await harness.repository.finalize(
          preview: preview,
          mealCategory: 'lunch',
          loggedAt: DateTime.utc(2026, 8, 4, 12),
          commandId: 'thali-retry-command',
          consumptionId: 'thali-retry-consumption',
          allowPartial: true,
        );
        final repeated = await harness.repository.finalize(
          preview: preview,
          mealCategory: 'lunch',
          loggedAt: DateTime.utc(2026, 8, 4, 12),
          commandId: 'thali-retry-command',
          consumptionId: 'thali-retry-consumption',
          allowPartial: true,
        );
        expect(saved.id, 'thali-retry-consumption');
        expect(repeated.id, saved.id);
        expect(saved.sourceType, 'thali');
        expect(saved.thaliId, draft.id);
        expect(saved.items.single.foodId, 'food-a');
        expect(saved.items.single.position, 0);
        expect(saved.lineage.commandId, 'thali-retry-command');
        expect(
          await harness.consumption.listAllForUser(userId: harness.userId),
          hasLength(1),
        );
        final daily = await NutritionReadModelRepository(
          db: harness.db,
          registry: harness.registry,
          canonicalRepository: harness.consumption,
        ).dailyTotals(userId: harness.userId, localDate: '2026-08-04');
        expect(daily.records, hasLength(1));
        expect(daily.totals.facts['energy']?.point?.value.toString(), '100');
        expect(daily.records.single.items.single.originSourceType, 'food');
      },
    );

    test(
      'household measure input keeps explicit context and unresolved measures do not become grams',
      () async {
        final harness = await _ThaliHarness.create();
        addTearDown(harness.close);
        final measure = NutritionHouseholdMeasureRepository(db: harness.db);
        final cup = (await measure.listStandardMeasures()).firstWhere(
          (item) => item.key == 'cup',
        );
        final quantity = Quantity(
          amount: QuantityAmount.one,
          unit: QuantityUnit.householdReference,
          context: QuantityContext(
            householdMeasure: HouseholdMeasureReference(measureType: cup.id),
          ),
        );
        expect(quantity.dimension, QuantityDimension.householdReference);
        final resolved = await measure.convertToVolume(
          userId: harness.userId,
          selection: NutritionStandardMeasureSelection(cup.id),
          count: Quantity.fromNum(amount: 1, unit: QuantityUnit.piece),
        );
        expect(resolved, isA<NutritionMeasureConversionResolved>());
        final volume = (resolved as NutritionMeasureConversionResolved).volume;
        expect(volume.point?.toString(), '240');
        expect(volume.unit, QuantityUnit.millilitre);
        expect(quantity.unit, isNot(QuantityUnit.gram));
      },
    );

    test(
      'bounded vessel quantities retain dimensional and calibration lineage in history',
      () async {
        final harness = await _ThaliHarness.create();
        addTearDown(harness.close);
        await _insertVolumeFood(harness.db, 'food-milk', 50, 'Milk');
        final measures = NutritionHouseholdMeasureRepository(db: harness.db);
        final vessel = await measures.createVessel(
          userId: harness.userId,
          displayName: 'Measured cup',
          portableId: 'vessel-a',
        );
        final calibration = await measures.addCalibration(
          userId: harness.userId,
          vesselId: vessel.id,
          volume: Quantity.fromNum(amount: 200, unit: QuantityUnit.millilitre),
          lower: QuantityAmount.fromNum(180),
          upper: QuantityAmount.fromNum(220),
          method: 'water fill',
          portableId: 'calibration-a',
        );
        final draft = await harness.repository.saveDraft(
          harness.repository.newDraft(
            userId: harness.userId,
            items: [
              NutritionThaliItem(
                id: 'item-milk',
                position: 0,
                source: NutritionThaliItemSource.food,
                foodId: 'food-milk',
                recipeVersionId: null,
                quantity: Quantity.householdReference(
                  count: '1',
                  reference: HouseholdMeasureReference(measureType: vessel.id),
                ),
                measureId: vessel.id,
                displayLabel: 'Milk',
              ),
            ],
          ),
        );

        final preview = await harness.repository.preview(draft: draft);
        final resolved = preview.items.single.resolvedQuantity;
        expect(resolved.calculationQuantity.unit, QuantityUnit.millilitre);
        expect(
          resolved.calculationQuantity.amount,
          QuantityAmount.fromNum(200),
        );
        expect(resolved.original.unit, QuantityUnit.householdReference);
        expect(
          resolved.original.context.householdMeasure!.calibrationId,
          calibration.id,
        );
        expect(
          resolved.original.context.householdMeasure!.resolutionState,
          HouseholdResolutionState.volumeResolved,
        );
        expect(resolved.original.context.approximate, isTrue);
        final volume = resolved.evidence['volume'] as Map;
        expect(volume['lower'], '180');
        expect(volume['point'], '200');
        expect(volume['upper'], '220');

        final snapshot = await harness.repository.finalize(
          preview: preview,
          mealCategory: 'breakfast',
          loggedAt: DateTime.utc(2026, 8, 4, 8),
          commandId: 'thali-volume-command',
          consumptionId: 'thali-volume-consumption',
          allowPartial: true,
        );
        final historicalQuantity = snapshot.items.single.quantity;
        expect(historicalQuantity.unit, QuantityUnit.householdReference);
        expect(historicalQuantity.amount, QuantityAmount.one);
        expect(
          historicalQuantity.context.householdMeasure!.calibrationId,
          calibration.id,
        );
        expect(historicalQuantity.context.approximate, isTrue);
        final itemLineage =
            snapshot.lineage.evidence['items'] as Map<String, dynamic>;
        final itemEvidence =
            (itemLineage['item-milk'] as Map<String, dynamic>)['evidence']
                as Map<String, dynamic>;
        expect(itemEvidence['quantity_evidence'], isNotNull);
        expect(
          (itemEvidence['measure'] as Map<String, dynamic>)['calibration_id'],
          calibration.id,
        );
        expect(
          (itemEvidence['measure']
              as Map<String, dynamic>)['calibration_version'],
          calibration.version,
        );
      },
    );

    test(
      'dietary evaluation stays component-scoped and acknowledgement is explicit',
      () async {
        final harness = await _ThaliHarness.create();
        addTearDown(harness.close);
        final constraints = NutritionConstraintRepository(database: harness.db);
        final target = NutritionConstraintTarget(
          type: NutritionConstraintTargetType.allergen,
          id: 'milk',
        );
        final timestamp = DateTime.utc(2026, 8, 4);
        await constraints.createConstraint(
          NutritionUserConstraint(
            id: 'constraint-milk',
            userId: harness.userId,
            definitionId: NutritionConstraintTaxonomy.definitionForType(
              NutritionConstraintType.allergy,
            ).id,
            type: NutritionConstraintType.allergy,
            target: target,
            strictness: NutritionConstraintStrictness.avoid,
            effectiveFrom: timestamp,
            source: NutritionConstraintSource.userEntered,
            createdAtUtc: timestamp,
            updatedAtUtc: timestamp,
          ),
        );
        await constraints.recordFoodEvidence(
          foodId: 'food-a',
          evidence: NutritionConstraintEvidence(
            id: 'food-a-milk-evidence',
            subjectId: 'food-a',
            target: target,
            status: NutritionConstraintEvidenceStatus.confirmed,
            source:
                NutritionConstraintEvidenceSource.reviewedAllergenDeclaration,
          ),
        );
        final draft = await harness.repository.saveDraft(
          harness.repository.newDraft(
            userId: harness.userId,
            items: [harness.foodItem('food-a', 0)],
          ),
        );
        final preview = await harness.repository.preview(draft: draft);
        expect(
          preview.constraintEvaluation?.outcome,
          NutritionConstraintOutcome.confirmedConflict,
        );
        final acknowledged = await harness.repository.preview(
          draft: draft,
          acknowledgedConstraintIds: const ['constraint-milk'],
        );
        expect(
          acknowledged.constraintEvaluation!.evaluations.single.acknowledged,
          isTrue,
        );
        final commandId = 'thali-constraint-command';
        final saved = await harness.repository.finalize(
          preview: acknowledged,
          mealCategory: 'lunch',
          loggedAt: timestamp,
          commandId: commandId,
          acknowledgement: NutritionConstraintAcknowledgement(
            commandId: commandId,
            userId: harness.userId,
            evaluationFingerprint:
                acknowledged.constraintEvaluation!.fingerprint,
            constraintId: 'constraint-milk',
            reason: 'User acknowledged the dietary warning.',
            acknowledgedAtUtc: timestamp,
          ),
          allowPartial: true,
        );
        expect(
          saved.constraintEvaluation!.evaluations.single.acknowledged,
          isTrue,
        );
      },
    );

    test(
      'duplicate thali components receive distinct constraint evidence identities',
      () async {
        final harness = await _ThaliHarness.create();
        addTearDown(harness.close);
        final constraints = NutritionConstraintRepository(database: harness.db);
        final target = NutritionConstraintTarget(
          type: NutritionConstraintTargetType.allergen,
          id: 'milk',
        );
        final timestamp = DateTime.utc(2026, 8, 4);
        await constraints.createConstraint(
          NutritionUserConstraint(
            id: 'constraint-duplicate-milk',
            userId: harness.userId,
            definitionId: NutritionConstraintTaxonomy.definitionForType(
              NutritionConstraintType.allergy,
            ).id,
            type: NutritionConstraintType.allergy,
            target: target,
            strictness: NutritionConstraintStrictness.avoid,
            effectiveFrom: timestamp,
            source: NutritionConstraintSource.userEntered,
            createdAtUtc: timestamp,
            updatedAtUtc: timestamp,
          ),
        );
        await constraints.recordFoodEvidence(
          foodId: 'food-a',
          evidence: NutritionConstraintEvidence(
            id: 'food-a-milk-evidence',
            subjectId: 'food-a',
            target: target,
            status: NutritionConstraintEvidenceStatus.confirmed,
            source:
                NutritionConstraintEvidenceSource.reviewedAllergenDeclaration,
          ),
        );

        final draft = await harness.repository.saveDraft(
          harness.repository.newDraft(
            userId: harness.userId,
            items: [
              harness.foodItem('food-a', 0),
              harness.foodItem('food-a', 1),
            ],
          ),
        );
        final preview = await harness.repository.preview(draft: draft);
        final result = preview.constraintEvaluation!.evaluations.single;
        expect(result.outcome, NutritionConstraintOutcome.confirmedConflict);
        expect(result.evidence, hasLength(2));
        expect(
          result.evidence.map((item) => item.evidenceId).toSet(),
          hasLength(2),
        );
        expect(result.evidence.map((item) => item.ingredientLineage).toSet(), {
          'item-a',
          'item-b',
        });
      },
    );
  });
}

class _ThaliHarness {
  final AppDatabase db;
  final NutrientRegistry registry;
  final NutritionRecipeRepository recipes;
  final NutritionConsumptionRepository consumption;
  final NutritionThaliRepository repository;
  final String userId;

  _ThaliHarness._(
    this.db,
    this.registry,
    this.recipes,
    this.consumption,
    this.repository,
    this.userId,
  );

  static Future<_ThaliHarness> create() async {
    final db = AppDatabase.memory();
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    await _insertFood(db, 'food-a', 100, 'Rice');
    final recipes = NutritionRecipeRepository(db: db);
    final consumption = NutritionConsumptionRepository(
      db: db,
      registry: registry,
    );
    return _ThaliHarness._(
      db,
      registry,
      recipes,
      consumption,
      _repository(
        db: db,
        registry: registry,
        recipes: recipes,
        consumption: consumption,
      ),
      'thali-user',
    );
  }

  NutritionThaliRepository withConsumption(
    NutritionConsumptionRepository value,
  ) => _repository(
    db: db,
    registry: registry,
    recipes: recipes,
    consumption: value,
  );

  NutritionThaliItem foodItem(String id, int position) => NutritionThaliItem(
    id: position == 0 ? 'item-a' : 'item-b',
    position: position,
    source: NutritionThaliItemSource.food,
    foodId: id,
    recipeVersionId: null,
    quantity: Quantity.fromNum(amount: 100, unit: QuantityUnit.gram),
    displayLabel: 'Rice',
  );

  Future<NutritionRecipeVersionModel> createPublishedRecipe() async {
    final draft = await recipes.createRecipe(
      userId: userId,
      recipeId: 'recipe-a',
      versionId: 'recipe-a-v1',
      name: 'Dal recipe',
      ingredients: [
        NutritionRecipeIngredientInput.directFood(
          id: 'recipe-line-a',
          foodId: 'food-a',
          quantity: Quantity.fromNum(amount: 100, unit: QuantityUnit.gram),
          position: 0,
        ),
      ],
      yieldQuantity: Quantity.fromNum(amount: 400, unit: QuantityUnit.gram),
    );
    return recipes.publishDraft(
      recipeId: 'recipe-a',
      draftVersionId: draft.version.id,
    );
  }

  Future<void> close() => db.close();

  static NutritionThaliRepository _repository({
    required AppDatabase db,
    required NutrientRegistry registry,
    required NutritionRecipeRepository recipes,
    required NutritionConsumptionRepository consumption,
  }) {
    return NutritionThaliRepository(
      db: db,
      registry: registry,
      recipes: recipes,
      recipeLogging: NutritionRecipeLogCoordinator(
        db: db,
        recipes: recipes,
        calculator: const NutritionCalculationService(),
        consumption: consumption,
        registry: registry,
      ),
      measures: NutritionHouseholdMeasureRepository(db: db),
      constraints: NutritionConstraintRepository(database: db),
      consumption: consumption,
    );
  }
}

Future<void> _insertFood(
  AppDatabase db,
  String id,
  double energy,
  String displayName,
) async {
  await db
      .into(db.nutritionFoods)
      .insert(
        NutritionFoodsCompanion.insert(
          id: id,
          kind: 'canonical',
          displayName: displayName,
          locale: 'en-IN',
          sourceType: 'fixture',
          lifecycle: 'active',
        ),
      );
  await db
      .into(db.nutritionFoodNutrientFacts)
      .insert(
        NutritionFoodNutrientFactsCompanion.insert(
          id: '$id-energy-v1',
          foodId: id,
          nutrientId: 'energy',
          status: 'known',
          source: 'reviewed_catalogue',
          factVersion: 1,
          basis: 'per_100_grams',
          basisQuantity: const Value(100),
          basisUnit: const Value('gram'),
          amount: Value(energy),
          isCurrent: const Value(true),
        ),
      );
}

Future<void> _insertVolumeFood(
  AppDatabase db,
  String id,
  double energy,
  String displayName,
) async {
  await db
      .into(db.nutritionFoods)
      .insert(
        NutritionFoodsCompanion.insert(
          id: id,
          kind: 'canonical',
          displayName: displayName,
          locale: 'en-IN',
          sourceType: 'fixture',
          lifecycle: 'active',
        ),
      );
  await db
      .into(db.nutritionFoodNutrientFacts)
      .insert(
        NutritionFoodNutrientFactsCompanion.insert(
          id: '$id-energy-v1',
          foodId: id,
          nutrientId: 'energy',
          status: 'known',
          source: 'reviewed_catalogue',
          factVersion: 1,
          basis: 'per_100_millilitres',
          basisQuantity: const Value(100),
          basisUnit: const Value('millilitre'),
          amount: Value(energy),
          isCurrent: const Value(true),
        ),
      );
}
