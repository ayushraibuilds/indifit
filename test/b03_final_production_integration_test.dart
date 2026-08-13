import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/raw_cooked_transformations.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart'
    hide NutritionConsumptionSnapshot;
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_logging_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/data/repositories/nutrition_recipe_log_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_recipe_repository.dart';
import 'package:indifit/data/repositories/nutrition_transformation_repository.dart';
import 'package:indifit/features/food_log/nutrition_recipe_editor_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('B03 final production integration', () {
    test(
      'provider missingness and known zero survive canonical logging',
      () async {
        final harness = await _Harness.create();
        addTearDown(harness.close);

        final missing = await harness.catalog.ensureProviderFood(
          displayName: 'Provider partial',
          sourceReference: 'provider:partial:v1',
          servingSize: 1,
          servingUnit: 'serving',
          energyKcal: 120,
          proteinG: null,
          carbohydrateG: 12,
          fatG: 0,
        );
        final preview = await harness.foodLogger.preview(
          option: missing,
          quantity: missing.baseQuantity,
        );
        expect(preview.facts['protein']!.status, NutrientFactStatus.missing);
        expect(preview.facts['protein']!.point, isNull);
        expect(preview.facts['fat']!.status, NutrientFactStatus.knownZero);

        final saved = await harness.foodLogger.finalize(
          userId: harness.userId,
          preview: preview,
          mealCategory: 'lunch',
          loggedAt: DateTime.utc(2026, 8, 5, 12),
          localDate: '2026-08-05',
          timezoneId: 'Asia/Kolkata',
          consumptionId: 'direct-consumption-v1',
          commandId: 'direct-command-v1',
        );
        expect(saved.localDate, '2026-08-05');
        final historical = await harness.consumption.getSnapshot(
          userId: harness.userId,
          consumptionId: saved.id,
        );
        expect(
          historical!.items.single.facts['protein']!.status,
          NutrientFactStatus.missing,
        );

        final daily = await harness.readModels.dailyTotals(
          userId: harness.userId,
          localDate: '2026-08-05',
        );
        expect(
          daily.totals.facts['protein']!.status,
          NutrientFactStatus.missing,
        );
        expect(daily.totals.facts['fat']!.status, NutrientFactStatus.knownZero);
      },
    );

    test(
      'recipe editor persists, reopens, publishes, duplicates, and successor-edits',
      () async {
        final harness = await _Harness.create();
        addTearDown(harness.close);
        final food = await harness.catalog.ensureProviderFood(
          displayName: 'Editor food',
          sourceReference: 'provider:editor:v1',
          servingSize: 1,
          servingUnit: 'serving',
          energyKcal: 200,
          proteinG: 10,
          carbohydrateG: 20,
          fatG: 5,
        );

        final editor = harness.editor();
        await editor.load();
        editor.setName('Offline bowl');
        editor.setServingCount('2');
        editor.addIngredient(food: food, quantity: food.baseQuantity);
        await editor.saveDraft();
        final draft = editor.currentState.draft!;
        expect(draft.version.status, NutritionRecipeVersionStatus.draft);
        expect(draft.version.servingDefinition?.count.toString(), '2');

        final reopened = harness.editor(
          recipeId: draft.recipe.id,
          draftVersionId: draft.version.id,
        );
        await reopened.load();
        expect(reopened.currentState.ingredients.single.foodId, food.id);
        expect(reopened.currentState.servingCountText, '2');
        await reopened.publish();
        final publishedRecipe = reopened.currentState.recipe!;
        final publishedVersion = publishedRecipe.currentVersionId!;

        final duplicate = harness.editor(recipeId: publishedRecipe.id);
        await duplicate.load();
        await duplicate.duplicateCurrent();
        expect(duplicate.currentState.draft, isNotNull);
        expect(duplicate.currentState.recipe!.id, isNot(publishedRecipe.id));

        final successor = harness.editor(recipeId: publishedRecipe.id);
        await successor.load();
        successor.setName('Offline bowl edited');
        successor.updateIngredientQuantity(
          0,
          Quantity.fromDecimal(
            amount: '2',
            unit: food.baseQuantity.unit,
            context: food.baseQuantity.context,
          ),
        );
        await successor.saveDraft();
        expect(
          successor.currentState.draft,
          isNotNull,
          reason:
              '${successor.currentState.errorCode}: ${successor.currentState.errorMessage}',
        );
        await successor.publish();
        final versions = await harness.recipes.listPublishedVersions(
          publishedRecipe.id,
        );
        expect(
          versions.map((version) => version.id),
          contains(publishedVersion),
        );
        expect(versions.length, 2);

        final recipeLog = NutritionRecipeLogCoordinator(
          db: harness.db,
          recipes: harness.recipes,
          calculator: const NutritionCalculationService(),
          consumption: harness.consumption,
          registry: harness.registry,
        );
        final logPreview = await recipeLog.preview(
          userId: harness.userId,
          recipeId: publishedRecipe.id,
          recipeVersionId: publishedVersion,
          amount: NutritionRecipeLogAmount.wholeRecipe(),
        );
        final snapshot = await recipeLog.finalize(
          userId: harness.userId,
          preview: logPreview,
          mealCategory: 'dinner',
          loggedAt: DateTime.utc(2026, 8, 6, 12),
          localDate: '2026-08-06',
          timezoneId: 'Asia/Kolkata',
          commandId: 'recipe-command-v1',
          consumptionId: 'recipe-consumption-v1',
          allowPartial: true,
        );
        expect(snapshot.recipeVersionId, publishedVersion);
        expect(snapshot.items.single.recipeVersionId, publishedVersion);
      },
    );

    test(
      'food logging applies a range transformation and preserves lineage',
      () async {
        final harness = await _Harness.create();
        addTearDown(harness.close);
        await harness.insertMassFood('raw-rice', energy: 100);
        await harness.insertMassFood('cooked-rice', energy: 50);
        await harness.insertPreparation('raw-rice-prep', 'raw-rice', 'raw');
        await harness.insertPreparation(
          'cooked-rice-prep',
          'cooked-rice',
          'cooked',
        );
        final transformation = NutritionTransformation(
          id: 'rice-range-v1',
          sourceFoodId: 'raw-rice',
          sourcePreparationId: 'raw-rice-prep',
          sourceState: NutritionPreparationState.raw,
          targetFoodId: 'cooked-rice',
          targetPreparationId: 'cooked-rice-prep',
          targetState: NutritionPreparationState.cooked,
          sourceUnit: QuantityUnit.gram,
          targetUnit: QuantityUnit.gram,
          yieldRange: TransformationRange(
            lower: QuantityAmount.fromString('2.1'),
            upper: QuantityAmount.fromString('2.9'),
          ),
          method: NutritionPreparationMethod.boiled,
          source: NutritionTransformationSource.reviewedCatalogue,
          reviewState: NutritionTransformationReviewState.reviewed,
          evidence: 'reviewed fixture',
          ruleVersion: 'rice-rule-v1',
        );
        await harness.transformations.saveReviewed(transformation);
        final raw = (await harness.catalog.getOption('raw-rice'))!;
        final conversion = (await harness.foodLogger.transformationsFor(
          raw,
        )).single;
        final preview = await harness.foodLogger.preview(
          option: raw,
          quantity: Quantity.fromDecimal(
            amount: '100',
            unit: QuantityUnit.gram,
          ),
          transformation: conversion,
        );

        final energy = preview.facts['energy']!;
        expect(energy.status, NutrientFactStatus.estimated);
        expect(energy.lower!.value.toString(), '105');
        expect(energy.upper!.value.toString(), '145');
        expect(
          preview.calculationSnapshot.lineage['transformation'],
          isNotNull,
        );
        expect(preview.transformation!.lineage.ruleVersion, 'rice-rule-v1');
        final saved = await harness.foodLogger.finalize(
          userId: harness.userId,
          preview: preview,
          mealCategory: 'lunch',
          loggedAt: DateTime.utc(2026, 8, 7, 12),
          localDate: '2026-08-07',
          timezoneId: 'Asia/Kolkata',
          consumptionId: 'range-consumption-v1',
          commandId: 'range-command-v1',
        );
        expect(
          saved.items.single.facts['energy']!.lower!.value.toString(),
          '105',
        );
        expect(
          saved.items.single.facts['energy']!.upper!.value.toString(),
          '145',
        );
        final requestEvidence =
            saved.lineage.evidence['request_evidence'] as Map<dynamic, dynamic>;
        expect(requestEvidence['transformation'], isNotNull);
      },
    );
  });
}

class _Harness {
  final AppDatabase db;
  final NutrientRegistry registry;
  final NutritionFoodCatalogRepository catalog;
  final NutritionFoodLoggingCoordinator foodLogger;
  final NutritionConsumptionRepository consumption;
  final NutritionRecipeRepository recipes;
  final NutritionTransformationRepository transformations;
  final NutritionReadModelRepository readModels;
  final String userId = 'b03-production-user';

  _Harness._(
    this.db,
    this.registry,
    this.catalog,
    this.foodLogger,
    this.consumption,
    this.recipes,
    this.transformations,
    this.readModels,
  );

  static Future<_Harness> create() async {
    final db = AppDatabase.memory();
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    final catalog = NutritionFoodCatalogRepository(db: db, registry: registry);
    final consumption = NutritionConsumptionRepository(
      db: db,
      registry: registry,
    );
    final transformations = NutritionTransformationRepository(db: db);
    final recipes = NutritionRecipeRepository(db: db);
    return _Harness._(
      db,
      registry,
      catalog,
      NutritionFoodLoggingCoordinator(
        db: db,
        registry: registry,
        catalog: catalog,
        calculator: const NutritionCalculationService(),
        consumption: consumption,
        transformations: transformations,
      ),
      consumption,
      recipes,
      transformations,
      NutritionReadModelRepository(
        db: db,
        registry: registry,
        canonicalRepository: consumption,
      ),
    );
  }

  NutritionRecipeEditorController editor({
    String? recipeId,
    String? draftVersionId,
  }) => NutritionRecipeEditorController(
    recipes: recipes,
    foods: Future.value(catalog),
    transformations: transformations,
    userId: userId,
    recipeId: recipeId,
    draftVersionId: draftVersionId,
  );

  Future<void> insertMassFood(String id, {required double energy}) async {
    await db
        .into(db.nutritionFoods)
        .insert(
          NutritionFoodsCompanion.insert(
            id: id,
            kind: 'canonical',
            displayName: id,
            locale: 'en-IN',
            sourceType: 'fixture',
            lifecycle: 'active',
          ),
        );
    for (final definition in registry.definitions) {
      final value = switch (definition.id) {
        'energy' => energy,
        'protein' => 3.0,
        'carbohydrate' => 20.0,
        'fat' => 1.0,
        'fibre' => 2.0,
        _ => null,
      };
      await db
          .into(db.nutritionFoodNutrientFacts)
          .insert(
            NutritionFoodNutrientFactsCompanion.insert(
              id: '$id::${definition.id}',
              foodId: id,
              nutrientId: definition.id,
              amount: Value(value),
              status: value == null ? 'missing' : 'known',
              source: 'reviewed_catalogue',
              factVersion: 1,
              basis: 'per_100_grams',
              basisQuantity: const Value(100),
              basisUnit: const Value('gram'),
              isCurrent: const Value(true),
            ),
          );
    }
  }

  Future<void> insertPreparation(String id, String foodId, String state) => db
      .into(db.nutritionFoodPreparations)
      .insert(
        NutritionFoodPreparationsCompanion.insert(
          id: id,
          foodId: foodId,
          state: state,
          source: 'fixture',
          version: 'v1',
        ),
      );

  Future<void> close() => db.close();
}
