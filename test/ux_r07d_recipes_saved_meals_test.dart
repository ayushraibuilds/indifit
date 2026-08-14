import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/nutrition_thali.dart' as thali;
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/repositories/nutrition_constraint_repository.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/data/repositories/nutrition_household_measure_repository.dart';
import 'package:indifit/data/repositories/nutrition_recipe_log_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_recipe_repository.dart';
import 'package:indifit/data/repositories/nutrition_thali_repository.dart';
import 'package:indifit/features/food_log/saved_meals_controller.dart';
import 'package:indifit/features/food_log/saved_meals_screen.dart';
import 'package:indifit/features/food_log/widgets/saved_meal_edit_before_log_sheet.dart';

Quantity _grams(String amount) => Quantity(
  amount: QuantityAmount.fromString(amount),
  unit: QuantityUnit.gram,
);

NutritionRecipeIngredientInput _ingredient(String id, String foodId) =>
    NutritionRecipeIngredientInput.directFood(
      id: id,
      position: 0,
      foodId: foodId,
      quantity: _grams('100'),
    );

Future<void> _insertFood(
  AppDatabase db,
  NutrientRegistry registry, {
  required String foodId,
  required String displayName,
  required double energy,
  required double protein,
  required double carbs,
  required double fat,
}) async {
  await db
      .into(db.nutritionFoods)
      .insert(
        NutritionFoodsCompanion.insert(
          id: foodId,
          kind: 'canonical',
          displayName: displayName,
          locale: 'en-IN',
          sourceType: 'reviewed_catalogue',
          lifecycle: 'active',
        ),
      );
  final facts = <String, double>{
    'energy': energy,
    'protein': protein,
    'carbohydrate': carbs,
    'fat': fat,
  };
  for (final entry in facts.entries) {
    await db
        .into(db.nutritionFoodNutrientFacts)
        .insert(
          NutritionFoodNutrientFactsCompanion.insert(
            id: '$foodId-${entry.key}-v1',
            foodId: foodId,
            nutrientId: entry.key,
            status: 'known',
            source: 'reviewed_catalogue',
            factVersion: 1,
            basis: 'per_100_grams',
            basisQuantity: const drift.Value(100),
            basisUnit: const drift.Value('gram'),
            amount: drift.Value(entry.value),
            isCurrent: const drift.Value(true),
          ),
        );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NutrientRegistry registry;
  late NutritionCalculationService calculator;
  late NutritionRecipeRepository recipeRepo;
  late NutritionConsumptionRepository consumptionRepo;
  late NutritionFoodCatalogRepository catalogRepo;
  late NutritionHouseholdMeasureRepository measureRepo;
  late NutritionRecipeLogCoordinator recipeCoordinator;
  late NutritionThaliRepository thaliRepo;
  late FoodRepository legacyFoodRepo;

  setUp(() async {
    db = AppDatabase.memory();
    registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    calculator = const NutritionCalculationService();
    recipeRepo = NutritionRecipeRepository(db: db);
    consumptionRepo = NutritionConsumptionRepository(
      db: db,
      registry: registry,
    );
    catalogRepo = NutritionFoodCatalogRepository(db: db, registry: registry);
    measureRepo = NutritionHouseholdMeasureRepository(db: db);
    recipeCoordinator = NutritionRecipeLogCoordinator(
      db: db,
      recipes: recipeRepo,
      calculator: calculator,
      consumption: consumptionRepo,
      registry: registry,
    );
    thaliRepo = NutritionThaliRepository(
      db: db,
      registry: registry,
      recipes: recipeRepo,
      recipeLogging: recipeCoordinator,
      measures: measureRepo,
      constraints: NutritionConstraintRepository(database: db),
      consumption: consumptionRepo,
    );
    legacyFoodRepo = FoodRepository(db);

    // Seed test food items in catalog
    await _insertFood(
      db,
      registry,
      foodId: 'food::rice',
      displayName: 'Steamed Basmati Rice',
      energy: 130.0,
      protein: 2.7,
      carbs: 28.0,
      fat: 0.3,
    );

    await _insertFood(
      db,
      registry,
      foodId: 'food::dal',
      displayName: 'Yellow Moong Dal',
      energy: 105.0,
      protein: 7.0,
      carbs: 18.0,
      fat: 1.0,
    );

    await _insertFood(
      db,
      registry,
      foodId: 'food::paneer',
      displayName: 'Paneer Cubes',
      energy: 265.0,
      protein: 18.0,
      carbs: 3.5,
      fat: 20.0,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('R07D-3 Recipe Lifecycle and Immutability', () {
    test('Create recipe, calculate nutrition, and publish version 1', () async {
      final draft = await recipeRepo.createRecipe(
        userId: kLocalNutritionUserScopeId,
        recipeId: 'recipe-paneer-bhurji',
        versionId: 'rpb-v1',
        name: 'Paneer Bhurji',
        description: 'Home-style spiced paneer scramble',
        ingredients: [_ingredient('pb-ing-1', 'food::paneer')],
        yieldQuantity: _grams('200'),
        servingDefinition: NutritionRecipeServingDefinition(
          id: 'pb-serving-1',
          revision: 'v1',
          count: QuantityAmount.fromString('2'),
        ),
      );

      expect(draft.recipe.name, 'Paneer Bhurji');
      expect(draft.version.versionNumber, 1);

      // Publish version 1
      final published = await recipeRepo.publishDraft(
        recipeId: draft.recipe.id,
        draftVersionId: draft.version.id,
      );
      expect(published.status, NutritionRecipeVersionStatus.published);

      // Verify list of saved recipes includes Paneer Bhurji
      final recipes = await recipeCoordinator.listSavedRecipes(
        userId: kLocalNutritionUserScopeId,
      );
      expect(recipes.length, 1);
      expect(recipes.first.name, 'Paneer Bhurji');
    });

    test(
      'Editing published recipe creates immutable version 2, leaving version 1 untouched',
      () async {
        // 1. Create and publish version 1
        final draft1 = await recipeRepo.createRecipe(
          userId: kLocalNutritionUserScopeId,
          recipeId: 'recipe-dal-tadka',
          versionId: 'rdt-v1',
          name: 'Dal Tadka',
          ingredients: [_ingredient('dt-ing-1', 'food::dal')],
          yieldQuantity: _grams('300'),
        );
        final published1 = await recipeRepo.publishDraft(
          recipeId: draft1.recipe.id,
          draftVersionId: draft1.version.id,
        );
        expect(published1.versionNumber, 1);

        // Log 1 serving of version 1
        final preview1 = await recipeCoordinator.preview(
          userId: kLocalNutritionUserScopeId,
          recipeId: draft1.recipe.id,
          recipeVersionId: published1.id,
          amount: NutritionRecipeLogAmount.wholeRecipe(),
        );
        final snapshot1 = await recipeCoordinator.finalize(
          userId: kLocalNutritionUserScopeId,
          preview: preview1,
          mealCategory: 'lunch',
          loggedAt: DateTime.now().toUtc(),
          localDate: '2026-08-14',
          timezoneId: 'UTC',
          consumptionId: 'snap-001',
          commandId: 'cmd-001',
          allowPartial: true,
        );
        expect(snapshot1.recipeVersionId, published1.id);

        // 2. Create draft version 2 for editing
        final draft2 = await recipeRepo.createSuccessorDraft(
          recipeId: draft1.recipe.id,
          versionId: 'rdt-v2',
        );
        expect(draft2.version.versionNumber, 2);

        final published2 = await recipeRepo.publishDraft(
          recipeId: draft1.recipe.id,
          draftVersionId: draft2.version.id,
        );
        expect(published2.versionNumber, 2);

        // 3. Verify historical consumption snapshot still references version 1
        final historySnapshot = await consumptionRepo.getSnapshot(
          userId: kLocalNutritionUserScopeId,
          consumptionId: snapshot1.id,
        );
        expect(historySnapshot?.recipeVersionId, published1.id);
        expect(historySnapshot?.recipeVersionId, isNot(published2.id));
      },
    );

    test(
      'Deleting/archiving recipe preserves historical consumption snapshots',
      () async {
        final draft = await recipeRepo.createRecipe(
          userId: kLocalNutritionUserScopeId,
          recipeId: 'recipe-curd-rice',
          versionId: 'rcr-v1',
          name: 'Curd Rice',
          ingredients: [_ingredient('cr-ing-1', 'food::rice')],
          yieldQuantity: _grams('250'),
        );
        final published = await recipeRepo.publishDraft(
          recipeId: draft.recipe.id,
          draftVersionId: draft.version.id,
        );

        // Log recipe to diary
        final preview = await recipeCoordinator.preview(
          userId: kLocalNutritionUserScopeId,
          recipeId: draft.recipe.id,
          recipeVersionId: published.id,
          amount: NutritionRecipeLogAmount.wholeRecipe(),
        );
        final snapshot = await recipeCoordinator.finalize(
          userId: kLocalNutritionUserScopeId,
          preview: preview,
          mealCategory: 'dinner',
          loggedAt: DateTime.now().toUtc(),
          localDate: '2026-08-14',
          timezoneId: 'UTC',
          consumptionId: 'snap-curd-rice',
          commandId: 'cmd-curd-rice',
          allowPartial: true,
        );

        // Archive / delete recipe
        await recipeCoordinator.archiveRecipe(draft.recipe.id);

        // Recipe is no longer discoverable for new logging
        final activeRecipes = await recipeCoordinator.listSavedRecipes(
          userId: kLocalNutritionUserScopeId,
        );
        expect(activeRecipes.any((r) => r.id == draft.recipe.id), isFalse);

        // Historical consumption snapshot remains fully intact
        final storedSnapshot = await consumptionRepo.getSnapshot(
          userId: kLocalNutritionUserScopeId,
          consumptionId: snapshot.id,
        );
        expect(storedSnapshot, isNotNull);
        expect(storedSnapshot!.id, snapshot.id);
        expect(storedSnapshot.mealCategory, 'dinner');
      },
    );
  });

  group('R07D-3 Saved Meal Lifecycle, Fast Re-log, and Edit-Before-Log', () {
    test(
      'Create saved meal with multiple foods, 1-tap fast re-log, and verify snapshot',
      () async {
        final draft = thali.NutritionThaliDraft(
          id: 'thali::my-usual-lunch',
          userId: kLocalNutritionUserScopeId,
          name: 'My Usual Lunch',
          description: 'Rice, Dal, and Paneer',
          lifecycle: 'active',
          currentVersion: 1,
          createdAtUtc: DateTime.now().toUtc(),
          updatedAtUtc: DateTime.now().toUtc(),
          items: [
            thali.NutritionThaliItem(
              id: 'item-1',
              position: 0,
              source: thali.NutritionThaliItemSource.food,
              foodId: 'food::rice',
              recipeVersionId: null,
              quantity: Quantity(
                amount: QuantityAmount.fromNum(150),
                unit: QuantityUnit.gram,
              ),
              measureId: null,
              optional: false,
              notes: null,
              displayLabel: 'Steamed Basmati Rice',
            ),
            thali.NutritionThaliItem(
              id: 'item-2',
              position: 1,
              source: thali.NutritionThaliItemSource.food,
              foodId: 'food::dal',
              recipeVersionId: null,
              quantity: Quantity(
                amount: QuantityAmount.fromNum(150),
                unit: QuantityUnit.gram,
              ),
              measureId: null,
              optional: false,
              notes: null,
              displayLabel: 'Yellow Moong Dal',
            ),
            thali.NutritionThaliItem(
              id: 'item-3',
              position: 2,
              source: thali.NutritionThaliItemSource.food,
              foodId: 'food::paneer',
              recipeVersionId: null,
              quantity: Quantity(
                amount: QuantityAmount.fromNum(100),
                unit: QuantityUnit.gram,
              ),
              measureId: null,
              optional: false,
              notes: null,
              displayLabel: 'Paneer Cubes',
            ),
          ],
        );

        final saved = await thaliRepo.saveDraft(draft);
        expect(saved.name, 'My Usual Lunch');
        expect(saved.items.length, 3);

        // Fast re-log to Lunch
        final preview = await thaliRepo.preview(draft: saved);
        final snapshot = await thaliRepo.finalize(
          preview: preview,
          mealCategory: 'lunch',
          loggedAt: DateTime.now().toUtc(),
          localDate: '2026-08-14',
          timezoneId: 'UTC',
          commandId: 'cmd-fast-relog',
          consumptionId: 'snap-fast-relog',
          allowPartial: true,
        );

        expect(snapshot.mealCategory, 'lunch');
        expect(snapshot.sourceType, 'thali');
        expect(snapshot.thaliId, 'thali::my-usual-lunch');
        expect(snapshot.items.length, 3);
      },
    );

    test(
      'Edit-before-log temporary variation does NOT mutate saved meal template',
      () async {
        // 1. Save original meal template with 100g Paneer
        final originalDraft = thali.NutritionThaliDraft(
          id: 'thali::post-workout',
          userId: kLocalNutritionUserScopeId,
          name: 'Post-Workout Meal',
          description: 'Rice and Paneer',
          lifecycle: 'active',
          currentVersion: 1,
          createdAtUtc: DateTime.now().toUtc(),
          updatedAtUtc: DateTime.now().toUtc(),
          items: [
            thali.NutritionThaliItem(
              id: 'item-pw-1',
              position: 0,
              source: thali.NutritionThaliItemSource.food,
              foodId: 'food::paneer',
              recipeVersionId: null,
              quantity: Quantity(
                amount: QuantityAmount.fromNum(100),
                unit: QuantityUnit.gram,
              ),
              measureId: null,
              optional: false,
              notes: null,
              displayLabel: 'Paneer Cubes',
            ),
          ],
        );
        await thaliRepo.saveDraft(originalDraft);

        // 2. User modifies portion for today only: 200g (2.0x)
        final tempModifiedDraft = thali.NutritionThaliDraft(
          id: 'thali::temp-variation',
          userId: kLocalNutritionUserScopeId,
          name: originalDraft.name,
          description: originalDraft.description,
          lifecycle: 'active',
          currentVersion: 1,
          createdAtUtc: DateTime.now().toUtc(),
          updatedAtUtc: DateTime.now().toUtc(),
          items: [
            thali.NutritionThaliItem(
              id: 'item-temp-1',
              position: 0,
              source: thali.NutritionThaliItemSource.food,
              foodId: 'food::paneer',
              recipeVersionId: null,
              quantity: Quantity(
                amount: QuantityAmount.fromNum(200),
                unit: QuantityUnit.gram,
              ),
              measureId: null,
              optional: false,
              notes: null,
              displayLabel: 'Paneer Cubes',
            ),
          ],
        );

        await thaliRepo.saveDraft(tempModifiedDraft);
        final tempPreview = await thaliRepo.preview(draft: tempModifiedDraft);
        final loggedSnapshot = await thaliRepo.finalize(
          preview: tempPreview,
          mealCategory: 'dinner',
          loggedAt: DateTime.now().toUtc(),
          localDate: '2026-08-14',
          timezoneId: 'UTC',
          commandId: 'cmd-temp-log',
          consumptionId: 'snap-temp-log',
          allowPartial: true,
        );

        // Verify today's logged snapshot has the doubled quantity (200g)
        expect(loggedSnapshot.items.first.quantity.amount.asDouble, 200.0);

        // 3. Verify the original template remains strictly at 100g
        final template = await thaliRepo.getDraft(
          userId: kLocalNutritionUserScopeId,
          thaliId: 'thali::post-workout',
        );
        expect(template, isNotNull);
        expect(template!.items.first.quantity.amount.asDouble, 100.0);
      },
    );

    test(
      'Deleting saved meal template marks lifecycle deleted and preserves diary history',
      () async {
        final draft = thali.NutritionThaliDraft(
          id: 'thali::to-delete',
          userId: kLocalNutritionUserScopeId,
          name: 'Snack Plate',
          description: null,
          lifecycle: 'active',
          currentVersion: 1,
          createdAtUtc: DateTime.now().toUtc(),
          updatedAtUtc: DateTime.now().toUtc(),
          items: [
            thali.NutritionThaliItem(
              id: 'item-del-1',
              position: 0,
              source: thali.NutritionThaliItemSource.food,
              foodId: 'food::paneer',
              recipeVersionId: null,
              quantity: Quantity(
                amount: QuantityAmount.fromNum(50),
                unit: QuantityUnit.gram,
              ),
              measureId: null,
              optional: false,
              notes: null,
              displayLabel: 'Paneer Cubes',
            ),
          ],
        );
        await thaliRepo.saveDraft(draft);

        // Log it
        final preview = await thaliRepo.preview(draft: draft);
        final snapshot = await thaliRepo.finalize(
          preview: preview,
          mealCategory: 'snack',
          loggedAt: DateTime.now().toUtc(),
          localDate: '2026-08-14',
          timezoneId: 'UTC',
          commandId: 'cmd-snack',
          consumptionId: 'snap-snack',
          allowPartial: true,
        );

        // Delete the template
        await thaliRepo.deleteThali(
          userId: kLocalNutritionUserScopeId,
          thaliId: 'thali::to-delete',
        );

        // Verify template is not in active list
        final activeList = await thaliRepo.listDrafts(
          userId: kLocalNutritionUserScopeId,
          includeArchived: false,
        );
        expect(activeList.any((t) => t.id == 'thali::to-delete'), isFalse);

        // Diary snapshot is preserved
        final savedSnapshot = await consumptionRepo.getSnapshot(
          userId: kLocalNutritionUserScopeId,
          consumptionId: snapshot.id,
        );
        expect(savedSnapshot, isNotNull);
      },
    );
  });

  group('R07D-3 Controller and UI Tests', () {
    test(
      'SavedMealsController loads meals, calculates preview, logs, and deletes',
      () async {
        // Seed a saved meal
        final draft = thali.NutritionThaliDraft(
          id: 'thali::controller-test-meal',
          userId: kLocalNutritionUserScopeId,
          name: 'High Protein Lunch',
          description: 'Paneer and Rice',
          lifecycle: 'active',
          currentVersion: 1,
          createdAtUtc: DateTime.now().toUtc(),
          updatedAtUtc: DateTime.now().toUtc(),
          items: [
            thali.NutritionThaliItem(
              id: 'item-ui-1',
              position: 0,
              source: thali.NutritionThaliItemSource.food,
              foodId: 'food::paneer',
              recipeVersionId: null,
              quantity: Quantity(
                amount: QuantityAmount.fromNum(100),
                unit: QuantityUnit.gram,
              ),
              measureId: null,
              optional: false,
              notes: null,
              displayLabel: 'Paneer Cubes',
            ),
          ],
        );
        await thaliRepo.saveDraft(draft);

        final controller = SavedMealsController(
          thaliRepoFuture: Future.value(thaliRepo),
          userId: kLocalNutritionUserScopeId,
        );
        addTearDown(controller.dispose);

        await controller.loadSavedMeals();
        expect(controller.state.status, SavedMealsStatus.ready);
        expect(controller.state.meals.length, 1);
        expect(controller.state.meals.first.draft.name, 'High Protein Lunch');

        // Log meal
        final snapshot = await controller.logSavedMeal(
          draft: draft,
          mealCategory: 'lunch',
        );
        expect(snapshot, isNotNull);
        expect(controller.state.status, SavedMealsStatus.success);

        // Delete meal
        await controller.deleteSavedMeal(draft.id);
        expect(controller.state.meals.isEmpty, isTrue);
      },
    );

    testWidgets(
      'SavedMealsScreen renders cards, macro chips, and survives large text',
      (tester) async {
        final controller = SavedMealsController(
          thaliRepoFuture: Completer<NutritionThaliRepository>().future,
          userId: kLocalNutritionUserScopeId,
        );

        final draft = thali.NutritionThaliDraft(
          id: 'thali::screen-meal',
          userId: kLocalNutritionUserScopeId,
          name: 'Screen Meal',
          description: 'Tasty meal',
          lifecycle: 'active',
          currentVersion: 1,
          createdAtUtc: DateTime.now().toUtc(),
          updatedAtUtc: DateTime.now().toUtc(),
          items: const [],
        );

        controller.state = controller.state.copyWith(
          status: SavedMealsStatus.ready,
          meals: [
            SavedMealDisplayItem(
              draft: draft,
              itemCount: 1,
              estimatedCalories: 450,
              estimatedProteinG: 35,
              summary: 'Tasty meal',
            ),
          ],
        );

        Widget buildApp({required double textScale}) => ProviderScope(
          overrides: [
            savedMealsControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 568),
                textScaler: TextScaler.linear(textScale),
              ),
              child: const SavedMealsScreen(mealType: 'lunch'),
            ),
          ),
        );

        await tester.pumpWidget(buildApp(textScale: 1.0));
        await tester.pump();
        expect(find.text('Saved Meals'), findsOneWidget);
        expect(find.text('Screen Meal'), findsOneWidget);
        expect(find.text('LOG TO LUNCH'), findsOneWidget);
        expect(find.text('REVIEW PORTIONS'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(buildApp(textScale: 2.0));
        await tester.pump();
        expect(find.text('Screen Meal'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'SavedMealEditBeforeLogSheet renders steppers and controls properly',
      (tester) async {
        final draft = thali.NutritionThaliDraft(
          id: 'thali::edit-sheet-test',
          userId: kLocalNutritionUserScopeId,
          name: 'Dinner Combo',
          description: null,
          lifecycle: 'active',
          currentVersion: 1,
          createdAtUtc: DateTime.now().toUtc(),
          updatedAtUtc: DateTime.now().toUtc(),
          items: [
            thali.NutritionThaliItem(
              id: 'item-es-1',
              position: 0,
              source: thali.NutritionThaliItemSource.food,
              foodId: 'food::rice',
              recipeVersionId: null,
              quantity: Quantity(
                amount: QuantityAmount.fromNum(100),
                unit: QuantityUnit.gram,
              ),
              measureId: null,
              optional: false,
              notes: null,
              displayLabel: 'Steamed Basmati Rice',
            ),
          ],
        );

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            nutritionThaliRepositoryProvider.overrideWith(
              (ref) => Future.value(thaliRepo),
            ),
            nutritionRecipeRepositoryProvider.overrideWithValue(recipeRepo),
            nutritionRecipeLogCoordinatorProvider.overrideWith(
              (ref) => Future.value(recipeCoordinator),
            ),
            nutritionFoodCatalogRepositoryProvider.overrideWith(
              (ref) => Future.value(catalogRepo),
            ),
            foodRepositoryProvider.overrideWithValue(legacyFoodRepo),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SavedMealEditBeforeLogSheet(
                  draft: draft,
                  mealType: 'dinner',
                  selectedDate: DateTime(2026, 8, 14),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Dinner Combo'), findsOneWidget);
        expect(find.text('Steamed Basmati Rice'), findsOneWidget);
        expect(find.text('1.0x'), findsOneWidget);

        // Increment multiplier
        await tester.tap(find.byIcon(Icons.add_circle_outline));
        await tester.pump();
        expect(find.text('1.25x'), findsOneWidget);

        expect(tester.takeException(), isNull);
      },
    );
  });
}
