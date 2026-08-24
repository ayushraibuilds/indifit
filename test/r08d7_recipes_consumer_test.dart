import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/nutrition_consumption_snapshots.dart' as snapshots;
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/core/widgets/consumer_task_primitives.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/data/repositories/nutrition_recipe_log_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_recipe_repository.dart';
import 'package:indifit/data/repositories/nutrition_transformation_repository.dart';
import 'package:indifit/features/food_log/nutrition_recipe_editor_controller.dart';
import 'package:indifit/features/food_log/nutrition_recipe_editor_screen.dart';
import 'package:indifit/features/food_log/saved_recipe_log_controller.dart';
import 'package:indifit/features/food_log/saved_recipe_log_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Harness harness;

  setUp(() async {
    harness = await _Harness.create();
  });

  tearDown(() async {
    await harness.close();
  });

  group('R08D.7: Recipe List & Discovery', () {
    testWidgets('Displays published recipes and drafts with clear status and yield', (tester) async {
      final controller = SavedRecipeLogController(
        coordinator: Future.value(harness.coordinator),
        userId: harness.userId,
      );
      controller.state = controller.state.copyWith(
        status: SavedRecipeLogStatus.ready,
        recipes: const [
          NutritionRecipeModel(
            id: 'rec-1',
            userId: kLocalNutritionUserScopeId,
            name: 'Palak Paneer',
            description: 'Spinach curry with cottage cheese',
            lifecycle: NutritionRecipeLifecycle.active,
            currentVersionId: 'rec-1-v1',
          ),
        ],
        drafts: [
          NutritionRecipeDraftModel(
            recipe: const NutritionRecipeModel(
              id: 'rec-draft-1',
              userId: kLocalNutritionUserScopeId,
              name: 'Oatmeal Bowl',
              description: null,
              lifecycle: NutritionRecipeLifecycle.active,
              currentVersionId: null,
            ),
            version: NutritionRecipeVersionModel(
              id: 'rec-draft-1-v1',
              recipeId: 'rec-draft-1',
              versionNumber: 1,
              status: NutritionRecipeVersionStatus.draft,
              yieldQuantity: null,
              servingDefinition: null,
              calculationRuleVersion: 'b03',
              source: const NutritionRecipeSource(),
              parentVersionId: null,
              createdAt: DateTime.now().toUtc(),
              updatedAt: DateTime.now().toUtc(),
              ingredients: const [],
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedRecipeLogControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(
            home: SavedRecipeLogScreen(mealType: 'lunch'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Recipes'), findsOneWidget);
      expect(find.text('Palak Paneer'), findsOneWidget);
      expect(find.text('Spinach curry with cottage cheese'), findsOneWidget);
      expect(find.text('RECIPES IN PROGRESS'), findsOneWidget);
      expect(find.text('Oatmeal Bowl'), findsOneWidget);
      expect(find.textContaining('Finish this recipe before logging it'), findsOneWidget);
    });

    testWidgets('Empty search shows ProductEmptyState and clear button', (tester) async {
      final controller = SavedRecipeLogController(
        coordinator: Future.value(harness.coordinator),
        userId: harness.userId,
      );
      controller.state = controller.state.copyWith(
        status: SavedRecipeLogStatus.ready,
        query: 'Nonexistent',
        recipes: const [],
        drafts: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedRecipeLogControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(
            home: SavedRecipeLogScreen(mealType: 'lunch'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ProductEmptyState), findsOneWidget);
      expect(find.text('No saved recipes match “Nonexistent”'), findsOneWidget);
      expect(find.text('Clear search'), findsOneWidget);
    });

    testWidgets('Error state displays error message with retry button', (tester) async {
      final controller = SavedRecipeLogController(
        coordinator: Future.value(harness.coordinator),
        userId: harness.userId,
      );
      controller.state = controller.state.copyWith(
        status: SavedRecipeLogStatus.failure,
        errorMessage: 'Unable to load recipes.',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedRecipeLogControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(
            home: SavedRecipeLogScreen(mealType: 'lunch'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Unable to load recipes.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('R08D.7: Recipe Detail & Ingredient Presentation', () {
    testWidgets('Selecting a recipe displays description, yield, ingredients list, and portion choices', (tester) async {
      final controller = SavedRecipeLogController(
        coordinator: Future.value(harness.coordinator),
        userId: harness.userId,
      );
      const recipe = NutritionRecipeModel(
        id: 'rec-dal',
        userId: kLocalNutritionUserScopeId,
        name: 'High Protein Moong Dal',
        description: 'Comforting yellow lentil soup',
        lifecycle: NutritionRecipeLifecycle.active,
        currentVersionId: 'rec-dal-v1',
      );
      final version = NutritionRecipeVersionModel(
        id: 'rec-dal-v1',
        recipeId: 'rec-dal',
        versionNumber: 1,
        status: NutritionRecipeVersionStatus.published,
        yieldQuantity: null,
        servingDefinition: NutritionRecipeServingDefinition(
          id: 'serving-dal',
          revision: 'v1',
          count: QuantityAmount.fromString('4'),
        ),
        calculationRuleVersion: 'b03',
        source: const NutritionRecipeSource(),
        parentVersionId: null,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
        ingredients: [
          NutritionRecipeIngredientModel(
            id: 'ing-1',
            recipeVersionId: 'rec-dal-v1',
            position: 0,
            foodId: 'food::moong_dal',
            preparationId: null,
            quantity: Quantity.fromDecimal(
              amount: '200',
              unit: QuantityUnit.gram,
            ),
            measureId: null,
            lower: null,
            upper: null,
            notes: null,
            substitutedFromFoodId: null,
          ),
          NutritionRecipeIngredientModel(
            id: 'ing-2',
            recipeVersionId: 'rec-dal-v1',
            position: 1,
            foodId: 'food::ghee',
            preparationId: null,
            quantity: Quantity.fromDecimal(
              amount: '15',
              unit: QuantityUnit.gram,
            ),
            measureId: null,
            lower: null,
            upper: null,
            notes: null,
            substitutedFromFoodId: null,
          ),
        ],
      );

      controller.state = controller.state.copyWith(
        status: SavedRecipeLogStatus.ready,
        selectedRecipe: recipe,
        selectedVersion: version,
        versions: [version],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedRecipeLogControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(
            home: SavedRecipeLogScreen(mealType: 'lunch'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Add recipe'), findsOneWidget);
      expect(find.text('High Protein Moong Dal'), findsOneWidget);
      expect(find.text('Comforting yellow lentil soup'), findsOneWidget);
      expect(find.text('Makes 4 servings'), findsOneWidget);
      expect(find.text('INGREDIENTS'), findsOneWidget);
      expect(find.text('(2)'), findsOneWidget);
      expect(find.text('Moong Dal'), findsOneWidget);
      expect(find.text('200 grams'), findsOneWidget);
      expect(find.text('Ghee'), findsOneWidget);
      expect(find.text('15 grams'), findsOneWidget);

      // Portion choices
      expect(find.text('Whole recipe'), findsOneWidget);
      expect(find.text('1 serving'), findsOneWidget);
      expect(find.text('Fraction'), findsOneWidget);
      expect(find.text('Scale'), findsOneWidget);
      expect(find.text('Choose another recipe'), findsOneWidget);
      expect(find.text('Review nutrition'), findsOneWidget);
      expect(find.text('Edit recipe'), findsOneWidget);
    });

    testWidgets('Tapping choose another recipe clears selection', (tester) async {
      final controller = SavedRecipeLogController(
        coordinator: Future.value(harness.coordinator),
        userId: harness.userId,
      );
      const recipe = NutritionRecipeModel(
        id: 'rec-1',
        userId: kLocalNutritionUserScopeId,
        name: 'Quick Oats',
        description: null,
        lifecycle: NutritionRecipeLifecycle.active,
        currentVersionId: 'rec-1-v1',
      );
      final version = NutritionRecipeVersionModel(
        id: 'rec-1-v1',
        recipeId: 'rec-1',
        versionNumber: 1,
        status: NutritionRecipeVersionStatus.published,
        yieldQuantity: null,
        servingDefinition: null,
        calculationRuleVersion: 'b03',
        source: const NutritionRecipeSource(),
        parentVersionId: null,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
        ingredients: const [],
      );

      controller.state = controller.state.copyWith(
        status: SavedRecipeLogStatus.ready,
        selectedRecipe: recipe,
        selectedVersion: version,
        versions: [version],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedRecipeLogControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(
            home: SavedRecipeLogScreen(mealType: 'breakfast'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Add recipe'), findsOneWidget);

      await tester.tap(find.text('Choose another recipe'));
      await tester.pump();

      expect(controller.state.selectedRecipe, isNull);
      expect(controller.state.selectedVersion, isNull);
    });
    testWidgets('unresolved ingredient identity never leaks a durable ID', (
      tester,
    ) async {
      final controller = SavedRecipeLogController(
        coordinator: Future.value(harness.coordinator),
        userId: harness.userId,
      );
      const rawFoodId = 'food-seed-private-identity-9f87';
      const recipe = NutritionRecipeModel(
        id: 'rec-unresolved',
        userId: kLocalNutritionUserScopeId,
        name: 'Unresolved ingredient recipe',
        description: null,
        lifecycle: NutritionRecipeLifecycle.active,
        currentVersionId: 'rec-unresolved-v1',
      );
      final version = NutritionRecipeVersionModel(
        id: 'rec-unresolved-v1',
        recipeId: recipe.id,
        versionNumber: 1,
        status: NutritionRecipeVersionStatus.published,
        yieldQuantity: null,
        servingDefinition: null,
        calculationRuleVersion: 'b03',
        source: const NutritionRecipeSource(),
        parentVersionId: null,
        createdAt: DateTime.utc(2026, 8, 24),
        updatedAt: DateTime.utc(2026, 8, 24),
        ingredients: [
          NutritionRecipeIngredientModel(
            id: 'ingredient-unresolved',
            recipeVersionId: 'rec-unresolved-v1',
            position: 0,
            foodId: rawFoodId,
            preparationId: null,
            quantity: Quantity.fromDecimal(
              amount: '100',
              unit: QuantityUnit.gram,
            ),
            measureId: null,
            lower: null,
            upper: null,
            notes: null,
            substitutedFromFoodId: null,
          ),
        ],
      );
      controller.state = controller.state.copyWith(
        status: SavedRecipeLogStatus.ready,
        selectedRecipe: recipe,
        selectedVersion: version,
        versions: [version],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedRecipeLogControllerProvider.overrideWith((ref) => controller),
            nutritionFoodCatalogRepositoryProvider.overrideWith(
              (ref) async => _MissingFoodCatalogRepository(
                db: harness.db,
                registry: harness.registry,
              ),
            ),
          ],
          child: const MaterialApp(
            home: SavedRecipeLogScreen(mealType: 'lunch'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(rawFoodId), findsNothing);
      expect(find.text('Ingredient unavailable'), findsOneWidget);
    });
  });

  group('R08D.7: Portion Selection & Nutrition Logging', () {
    testWidgets('Preview displays calculated nutrition facts and confirm button', (tester) async {
      late NutritionRecipeModel recipe;
      late NutritionRecipeVersionModel version;
      late NutritionRecipeLogPreview preview;

      await tester.runAsync(() async {
        final published = await harness.published('paneer-bhurji', 'Paneer Bhurji', withServing: true);
        recipe = published.recipe;
        version = published.version;
        preview = await harness.coordinator.preview(
          userId: harness.userId,
          recipeId: published.recipe.id,
          amount: NutritionRecipeLogAmount.declaredServing(),
        );
      });

      final controller = SavedRecipeLogController(
        coordinator: Future.value(harness.coordinator),
        userId: harness.userId,
      );
      controller.state = controller.state.copyWith(
        status: SavedRecipeLogStatus.previewReady,
        selectedRecipe: recipe,
        selectedVersion: version,
        versions: [version],
        amountKind: NutritionRecipeLogAmountKind.declaredServing,
        preview: preview,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedRecipeLogControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(
            home: SavedRecipeLogScreen(mealType: 'lunch'),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Nutrition for'), findsOneWidget);
      expect(find.text('Energy: 100 kcal'), findsOneWidget);
      expect(find.text('Protein: 7.0 g'), findsOneWidget);
      expect(find.text('Confirm & log'), findsOneWidget);
    });

    testWidgets('Missing nutrition warning displays acknowledgement checkbox', (tester) async {
      late NutritionRecipeModel recipe;
      late NutritionRecipeVersionModel version;
      late NutritionRecipeLogPreview preview;

      await tester.runAsync(() async {
        await harness.insertFood(foodId: 'food-partial', includeFibre: false, estimatedEnergy: false);
        final draft = await harness.recipes.createRecipe(
          userId: harness.userId,
          recipeId: 'rec-partial',
          versionId: 'rec-partial-v1',
          name: 'Partial Recipe',
          ingredients: [
            NutritionRecipeIngredientInput.directFood(
              id: 'partial-ing',
              foodId: 'food-partial',
              quantity: Quantity.fromDecimal(amount: '100', unit: QuantityUnit.gram),
            ),
          ],
          yieldQuantity: Quantity.fromDecimal(amount: '100', unit: QuantityUnit.gram),
        );
        version = await harness.recipes.publishDraft(
          recipeId: 'rec-partial',
          draftVersionId: draft.version.id,
        );
        recipe = (await harness.recipes.getRecipe('rec-partial'))!;
        preview = await harness.coordinator.preview(
          userId: harness.userId,
          recipeId: recipe.id,
          amount: NutritionRecipeLogAmount.wholeRecipe(),
        );
      });

      final controller = SavedRecipeLogController(
        coordinator: Future.value(harness.coordinator),
        userId: harness.userId,
      );
      controller.state = controller.state.copyWith(
        status: SavedRecipeLogStatus.previewReady,
        selectedRecipe: recipe,
        selectedVersion: version,
        versions: [version],
        preview: preview,
        partialAcknowledged: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedRecipeLogControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(
            home: SavedRecipeLogScreen(mealType: 'snack'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Some nutrition information is missing'), findsOneWidget);
      expect(find.text('Add with missing nutrition'), findsOneWidget);
      expect(find.text('Missing nutrition stays missing rather than becoming zero.'), findsOneWidget);
    });
    testWidgets('successful persistence stays visible until Done', (
      tester,
    ) async {
      late NutritionRecipeModel recipe;
      late NutritionRecipeVersionModel version;
      late NutritionRecipeLogPreview preview;
      late NutritionFoodOption food;
      late snapshots.NutritionConsumptionSnapshot saved;
      late SavedRecipeLogController controller;
      await tester.runAsync(() async {
        final published = await harness.published(
          'visible-success',
          'Visible Success Recipe',
        );
        recipe = published.recipe;
        version = published.version;
        preview = await harness.coordinator.preview(
          userId: harness.userId,
          recipeId: recipe.id,
          amount: NutritionRecipeLogAmount.wholeRecipe(),
        );
        food = (await harness.catalogRepo.getOption('food-rice'))!;
        saved = await harness.coordinator.finalize(
          userId: harness.userId,
          preview: preview,
          mealCategory: 'dinner',
          loggedAt: DateTime.utc(2026, 8, 24, 12),
          localDate: '2026-08-24',
          timezoneId: 'UTC',
          commandId: 'recipe-visible-success-fixture',
          allowPartial: true,
        );
        controller = SavedRecipeLogController(
          coordinator: Future.value(
            _ImmediateRecipeLogCoordinator(
              harness: harness,
              savedSnapshot: saved,
            ),
          ),
          userId: harness.userId,
        );
      });
      controller.state = controller.state.copyWith(
        status: SavedRecipeLogStatus.previewReady,
        selectedRecipe: recipe,
        selectedVersion: version,
        versions: [version],
        preview: preview,
        partialAcknowledged: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedRecipeLogControllerProvider.overrideWith((ref) => controller),
            nutritionFoodCatalogRepositoryProvider.overrideWith(
              (ref) async => _ImmediateFoodCatalogRepository(
                db: harness.db,
                registry: harness.registry,
                option: food,
              ),
            ),
            localTimezoneServiceProvider.overrideWithValue(
              LocalTimezoneService(read: () async => 'UTC'),
            ),
            localScheduleDateServiceProvider.overrideWithValue(
              LocalScheduleDateService(
                nowUtc: () => DateTime.utc(2026, 8, 24, 12),
              ),
            ),
          ],
          child: MaterialApp(
            home: SavedRecipeLogScreen(
              mealType: 'dinner',
              selectedDate: DateTime(2026, 8, 24),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Confirm & log'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final confirm = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Confirm & log'),
      );
      await tester.runAsync(() async {
        confirm.onPressed!();
        for (var attempt = 0; attempt < 100; attempt++) {
          if (controller.state.status == SavedRecipeLogStatus.success) return;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pump();

      expect(controller.state.status, SavedRecipeLogStatus.success);
      expect(find.text('Recipe added'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.byType(SavedRecipeLogScreen), findsOneWidget);
    });
  });

  group('R08D.7: Recipe Editor Flow', () {
    testWidgets('Create recipe screen renders cooking language and input fields', (tester) async {
      final editorController = NutritionRecipeEditorController(
        recipes: harness.recipes,
        foods: Future.value(harness.catalogRepo),
        transformations: harness.transformationRepo,
        userId: harness.userId,
      );
      editorController.state = editorController.state.copyWith(
        status: NutritionRecipeEditorStatus.ready,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(harness.db),
            nutritionRecipeRepositoryProvider.overrideWithValue(harness.recipes),
            nutritionFoodCatalogRepositoryProvider.overrideWith((ref) async => harness.catalogRepo),
            nutritionTransformationRepositoryProvider.overrideWithValue(harness.transformationRepo),
            nutritionRecipeEditorControllerProvider(const NutritionRecipeEditorArgs()).overrideWith((ref) => editorController),
          ],
          child: const MaterialApp(
            home: NutritionRecipeEditorScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Create Recipe'), findsOneWidget);
      expect(find.text('Recipe name'), findsOneWidget);
      expect(find.text('Cooking notes & instructions (optional)'), findsOneWidget);
      expect(find.text('Declared servings (Yield)'), findsOneWidget);
      expect(find.text('Ingredients'), findsOneWidget);
      expect(find.text('Save draft'), findsOneWidget);
      expect(find.text('Publish recipe'), findsOneWidget);
    });
  });

  group('R08D.7: Accessibility & Responsiveness', () {
    testWidgets('SavedRecipeLogScreen renders cleanly at 320pt with 2x text in dark theme', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = SavedRecipeLogController(
        coordinator: Future.value(harness.coordinator),
        userId: harness.userId,
      );
      controller.state = controller.state.copyWith(
        status: SavedRecipeLogStatus.ready,
        recipes: const [
          NutritionRecipeModel(
            id: 'rec-responsive',
            userId: kLocalNutritionUserScopeId,
            name: 'Responsive Recipe',
            description: 'Long description to test narrow text scaling behavior without flex overflow',
            lifecycle: NutritionRecipeLifecycle.active,
            currentVersionId: 'rec-responsive-v1',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedRecipeLogControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(2.0),
              ),
              child: const SavedRecipeLogScreen(mealType: 'lunch'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Responsive Recipe'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('NutritionRecipeEditorScreen renders cleanly at 320pt with 2x text in light theme', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final editorController = NutritionRecipeEditorController(
        recipes: harness.recipes,
        foods: Future.value(harness.catalogRepo),
        transformations: harness.transformationRepo,
        userId: harness.userId,
      );
      editorController.state = editorController.state.copyWith(
        status: NutritionRecipeEditorStatus.ready,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(harness.db),
            nutritionRecipeRepositoryProvider.overrideWithValue(harness.recipes),
            nutritionFoodCatalogRepositoryProvider.overrideWith((ref) async => harness.catalogRepo),
            nutritionTransformationRepositoryProvider.overrideWithValue(harness.transformationRepo),
            nutritionRecipeEditorControllerProvider(const NutritionRecipeEditorArgs()).overrideWith((ref) => editorController),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(2.0),
              ),
              child: const NutritionRecipeEditorScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Create Recipe'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _Harness {
  final AppDatabase db;
  final NutrientRegistry registry;
  final NutritionRecipeRepository recipes;
  final NutritionConsumptionRepository consumption;
  final NutritionFoodCatalogRepository catalogRepo;
  final NutritionTransformationRepository transformationRepo;
  final NutritionRecipeLogCoordinator coordinator;
  final String userId;

  _Harness._(
    this.db,
    this.registry,
    this.recipes,
    this.consumption,
    this.catalogRepo,
    this.transformationRepo,
    this.coordinator,
    this.userId,
  );

  static Future<_Harness> create({
    bool includeFibre = true,
    bool estimatedEnergy = false,
  }) async {
    final db = AppDatabase.memory();
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    final recipes = NutritionRecipeRepository(db: db);
    final consumption = NutritionConsumptionRepository(
      db: db,
      registry: registry,
    );
    final catalogRepo = NutritionFoodCatalogRepository(
      db: db,
      registry: registry,
    );
    final transformationRepo = NutritionTransformationRepository(db: db);
    final coordinator = NutritionRecipeLogCoordinator(
      db: db,
      recipes: recipes,
      calculator: const NutritionCalculationService(),
      consumption: consumption,
      registry: registry,
    );
    final harness = _Harness._(
      db,
      registry,
      recipes,
      consumption,
      catalogRepo,
      transformationRepo,
      coordinator,
      kLocalNutritionUserScopeId,
    );

    await harness.insertFood(
      foodId: 'food-rice',
      includeFibre: includeFibre,
      estimatedEnergy: estimatedEnergy,
    );

    return harness;
  }

  Future<void> insertFood({
    required String foodId,
    required bool includeFibre,
    required bool estimatedEnergy,
  }) async {
    await db.into(db.nutritionFoods).insert(
      NutritionFoodsCompanion.insert(
        id: foodId,
        kind: 'canonical',
        displayName: 'Rice fixture',
        locale: 'en-IN',
        sourceType: 'fixture',
        lifecycle: 'active',
      ),
    );
    final facts =
        <String, ({double amount, double? lower, double? upper, String status})>{
          'energy': (
            amount: 100,
            lower: estimatedEnergy ? 90 : null,
            upper: estimatedEnergy ? 110 : null,
            status: estimatedEnergy ? 'estimated' : 'known',
          ),
          'protein': (amount: 7, lower: null, upper: null, status: 'known'),
          'carbohydrate': (amount: 20, lower: null, upper: null, status: 'known'),
          'fat': (amount: 1, lower: null, upper: null, status: 'known'),
        };
    if (includeFibre) {
      facts['fibre'] = (amount: 2, lower: null, upper: null, status: 'known');
    }
    for (final entry in facts.entries) {
      final value = entry.value;
      await db.into(db.nutritionFoodNutrientFacts).insert(
        NutritionFoodNutrientFactsCompanion.insert(
          id: '$foodId-${entry.key}-v1',
          foodId: foodId,
          nutrientId: entry.key,
          status: value.status,
          source: 'reviewed_catalogue',
          factVersion: 1,
          basis: 'per_100_grams',
          basisQuantity: const drift.Value(100),
          basisUnit: const drift.Value('gram'),
          amount: drift.Value(value.amount),
          lower: drift.Value(value.lower),
          upper: drift.Value(value.upper),
          isCurrent: const drift.Value(true),
        ),
      );
    }
  }

  Future<NutritionRecipeDraftModel> published(
    String id,
    String name, {
    bool withServing = true,
  }) async {
    final draft = await recipes.createRecipe(
      userId: userId,
      recipeId: id,
      versionId: '$id-v1',
      name: name,
      ingredients: [
        NutritionRecipeIngredientInput.directFood(
          id: '$id-line',
          foodId: 'food-rice',
          quantity: Quantity.fromDecimal(amount: '100', unit: QuantityUnit.gram),
          position: 0,
        ),
      ],
      yieldQuantity: Quantity.fromDecimal(amount: '400', unit: QuantityUnit.gram),
      servingDefinition: withServing
          ? NutritionRecipeServingDefinition(
              id: 'declared-serving',
              revision: 'v1',
              count: QuantityAmount.fromString('1'),
            )
          : null,
    );
    final version = await recipes.publishDraft(
      recipeId: id,
      draftVersionId: draft.version.id,
    );
    return NutritionRecipeDraftModel(
      recipe: (await recipes.getRecipe(id))!,
      version: version,
    );
  }

  Future<void> close() => db.close();
}
class _MissingFoodCatalogRepository extends NutritionFoodCatalogRepository {
  _MissingFoodCatalogRepository({required super.db, required super.registry});

  @override
  Future<NutritionFoodOption?> getOption(String foodId) async => null;
}

class _ImmediateFoodCatalogRepository extends NutritionFoodCatalogRepository {
  _ImmediateFoodCatalogRepository({
    required super.db,
    required super.registry,
    required this.option,
  });

  final NutritionFoodOption option;

  @override
  Future<NutritionFoodOption?> getOption(String foodId) async =>
      foodId == option.id ? option : null;
}

class _ImmediateRecipeLogCoordinator extends NutritionRecipeLogCoordinator {
  _ImmediateRecipeLogCoordinator({
    required _Harness harness,
    required this.savedSnapshot,
  }) : super(
         db: harness.db,
         recipes: harness.recipes,
         calculator: const NutritionCalculationService(),
         consumption: harness.consumption,
         registry: harness.registry,
       );

  final snapshots.NutritionConsumptionSnapshot savedSnapshot;

  @override
  Future<snapshots.NutritionConsumptionSnapshot> finalize({
    required String userId,
    required NutritionRecipeLogPreview preview,
    required String mealCategory,
    required DateTime loggedAt,
    String? mealGroupId,
    String? localDate,
    String? timezoneId,
    String? consumptionId,
    required String commandId,
    bool allowPartial = false,
    String? supersedesSnapshotId,
    String? correctionId,
    String? correctionReason,
  }) async => savedSnapshot;
}
