import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart'
    hide NutritionConsumptionSnapshot;
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/data/repositories/nutrition_recipe_log_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_recipe_repository.dart';
import 'package:indifit/features/food_log/saved_recipe_log_controller.dart';
import 'package:indifit/features/food_log/saved_recipe_log_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('B03-12 saved recipe logging integration', () {
    test(
      'active recipes are discoverable and duplicate names keep identity',
      () async {
        final harness = await _Harness.create();
        addTearDown(harness.close);
        await harness.published('recipe-a', 'Same name');
        await harness.published('recipe-b', 'Same name');
        await harness.published('recipe-archived', 'Same name');
        await harness.recipes.archiveRecipe('recipe-archived');

        final recipes = await harness.coordinator.listSavedRecipes(
          userId: harness.userId,
          query: 'same',
        );

        expect(recipes.map((recipe) => recipe.id), ['recipe-a', 'recipe-b']);
        expect(recipes.map((recipe) => recipe.name).toSet(), {'Same name'});
        expect(
          recipes.every((recipe) => recipe.id != 'recipe-archived'),
          isTrue,
        );
      },
    );

    test(
      'draft versions cannot be logged and current published version resolves',
      () async {
        final harness = await _Harness.create();
        addTearDown(harness.close);
        await harness.draft('draft-only', 'Draft only');
        final published = await harness.published('published', 'Published');

        expect(
          await harness.coordinator.listLoggableVersions(
            recipeId: 'draft-only',
            userId: harness.userId,
          ),
          isEmpty,
        );
        expect(
          () => harness.coordinator.preview(
            userId: harness.userId,
            recipeId: 'draft-only',
            amount: NutritionRecipeLogAmount.wholeRecipe(),
          ),
          throwsA(
            isA<NutritionRecipeLogError>().having(
              (error) => error.code,
              'code',
              'unpublished_recipe',
            ),
          ),
        );

        final preview = await harness.coordinator.preview(
          userId: harness.userId,
          recipeId: published.recipe.id,
          amount: NutritionRecipeLogAmount.wholeRecipe(),
        );
        expect(preview.version.id, published.version.id);
        expect(preview.calculation.recipeVersionId, published.version.id);
        expect(preview.evidence['recipe_id'], 'published');
      },
    );

    test(
      'positive fractions preview through B03-08 without persistence',
      () async {
        final harness = await _Harness.create();
        addTearDown(harness.close);
        final published = await harness.published(
          'fraction-recipe',
          'Fraction',
        );

        final preview = await harness.coordinator.preview(
          userId: harness.userId,
          recipeId: published.recipe.id,
          recipeVersionId: published.version.id,
          amount: NutritionRecipeLogAmount.fraction('0.5'),
        );

        expect(preview.amount.kind, NutritionRecipeLogAmountKind.fraction);
        expect(
          preview.calculation.facts['energy']?.point?.value.toString(),
          '50',
        );
        expect(
          await harness.consumption.listAllForUser(userId: harness.userId),
          isEmpty,
        );
        expect(
          () => harness.coordinator.preview(
            userId: harness.userId,
            recipeId: published.recipe.id,
            recipeVersionId: published.version.id,
            amount: NutritionRecipeLogAmount.fraction('0'),
          ),
          throwsA(
            isA<NutritionRecipeLogError>().having(
              (error) => error.code,
              'code',
              NutritionCalculationErrorCode.invalidScale,
            ),
          ),
        );
        expect(
          () => harness.coordinator.preview(
            userId: harness.userId,
            recipeId: published.recipe.id,
            recipeVersionId: published.version.id,
            amount: NutritionRecipeLogAmount.fraction('-0.5'),
          ),
          throwsA(isA<NutritionRecipeLogError>()),
        );
      },
    );

    test('declared serving requires explicit serving context', () async {
      final harness = await _Harness.create();
      addTearDown(harness.close);
      final published = await harness.published(
        'no-serving',
        'No serving',
        withServing: false,
      );

      expect(
        () => harness.coordinator.preview(
          userId: harness.userId,
          recipeId: published.recipe.id,
          amount: NutritionRecipeLogAmount.declaredServing(),
        ),
        throwsA(
          isA<NutritionRecipeLogError>().having(
            (error) => error.code,
            'code',
            NutritionCalculationErrorCode.missingServingDefinition,
          ),
        ),
      );
    });

    test(
      'unknown nutrients, partial completeness, and estimate ranges survive preview',
      () async {
        final harness = await _Harness.create(
          includeFibre: false,
          estimatedEnergy: true,
        );
        addTearDown(harness.close);
        final published = await harness.published('partial', 'Partial');
        final preview = await harness.coordinator.preview(
          userId: harness.userId,
          recipeId: published.recipe.id,
          amount: NutritionRecipeLogAmount.wholeRecipe(),
        );

        expect(preview.isPartial, isTrue);
        expect(preview.calculation.missingNutrientIds, contains('fibre'));
        final energy = preview.calculation.facts['energy']!;
        expect(energy.status, NutrientFactStatus.estimated);
        expect(energy.lower?.value.toString(), '90');
        expect(energy.upper?.value.toString(), '110');
        expect(energy.source, NutrientSourceType.reviewedCatalogue);
      },
    );

    test(
      'finalization uses one B03-11A command and preserves ancestry',
      () async {
        final harness = await _Harness.create();
        addTearDown(harness.close);
        final published = await harness.published('finalize', 'Frozen recipe');
        final preview = await harness.coordinator.preview(
          userId: harness.userId,
          recipeId: published.recipe.id,
          amount: NutritionRecipeLogAmount.wholeRecipe(),
        );
        final saved = await harness.coordinator.finalize(
          userId: harness.userId,
          preview: preview,
          mealCategory: 'lunch',
          loggedAt: DateTime.utc(2026, 8, 4, 12),
          localDate: '2026-08-04',
          timezoneId: 'Asia/Kolkata',
          consumptionId: 'consumption-finalize',
          commandId: 'command-finalize',
          allowPartial: true,
        );

        expect(saved.sourceType, 'recipe');
        expect(saved.recipeVersionId, published.version.id);
        expect(saved.items.single.recipeVersionId, published.version.id);
        expect(saved.items.single.sourceReference, published.recipe.id);
        expect(saved.items.single.displayLabel, 'Frozen recipe');
        expect(saved.items.single.quantity.dimension, QuantityDimension.mass);
        expect(saved.lineage.commandId, 'command-finalize');
        final requestEvidence =
            saved.lineage.evidence['request_evidence'] as Map<String, dynamic>;
        expect(requestEvidence['recipe_version_id'], published.version.id);
        expect(requestEvidence['calculation_fingerprint'], isNotEmpty);
      },
    );

    test(
      'repeated finalization is idempotent and retry leaves no partial graph',
      () async {
        final harness = await _Harness.create();
        addTearDown(harness.close);
        final published = await harness.published('retry', 'Retry recipe');
        final preview = await harness.coordinator.preview(
          userId: harness.userId,
          recipeId: published.recipe.id,
          amount: NutritionRecipeLogAmount.wholeRecipe(),
        );
        var injected = true;
        final failingConsumption = NutritionConsumptionRepository(
          db: harness.db,
          registry: harness.registry,
          failureInjector: (stage) {
            if (stage == 'after_items' && injected) {
              injected = false;
              throw StateError('injected finalization failure');
            }
          },
        );
        final failingCoordinator = NutritionRecipeLogCoordinator(
          db: harness.db,
          recipes: harness.recipes,
          calculator: const NutritionCalculationService(),
          consumption: failingConsumption,
          registry: harness.registry,
        );
        final arguments = <String, Object?>{
          'userId': harness.userId,
          'preview': preview,
          'mealCategory': 'dinner',
          'loggedAt': DateTime.utc(2026, 8, 4, 18),
          'localDate': '2026-08-04',
          'timezoneId': 'Asia/Kolkata',
          'consumptionId': 'consumption-retry',
          'commandId': 'command-retry',
          'allowPartial': true,
        };

        expect(
          () => failingCoordinator.finalize(
            userId: arguments['userId']! as String,
            preview: arguments['preview']! as NutritionRecipeLogPreview,
            mealCategory: arguments['mealCategory']! as String,
            loggedAt: arguments['loggedAt']! as DateTime,
            localDate: arguments['localDate']! as String,
            timezoneId: arguments['timezoneId']! as String,
            consumptionId: arguments['consumptionId']! as String,
            commandId: arguments['commandId']! as String,
            allowPartial: true,
          ),
          throwsA(isA<NutritionRecipeLogError>()),
        );
        expect(
          await harness.db
              .select(harness.db.nutritionConsumptionSnapshots)
              .get(),
          isEmpty,
        );
        expect(
          await harness.db.select(harness.db.nutritionSnapshotItems).get(),
          isEmpty,
        );

        final retried = await harness.coordinator.finalize(
          userId: harness.userId,
          preview: preview,
          mealCategory: 'dinner',
          loggedAt: DateTime.utc(2026, 8, 4, 18),
          localDate: '2026-08-04',
          timezoneId: 'Asia/Kolkata',
          consumptionId: 'consumption-retry',
          commandId: 'command-retry',
          allowPartial: true,
        );
        final repeated = await harness.coordinator.finalize(
          userId: harness.userId,
          preview: preview,
          mealCategory: 'dinner',
          loggedAt: DateTime.utc(2026, 8, 4, 18),
          localDate: '2026-08-04',
          timezoneId: 'Asia/Kolkata',
          consumptionId: 'consumption-retry',
          commandId: 'command-retry',
          allowPartial: true,
        );

        expect(retried.id, 'consumption-retry');
        expect(repeated.id, retried.id);
        expect(
          await harness.consumption.listAllForUser(userId: harness.userId),
          hasLength(1),
        );
      },
    );

    test('idempotent acknowledgement retry survives recipe archival', () async {
      final harness = await _Harness.create();
      addTearDown(harness.close);
      final published = await harness.published(
        'archived-after-log',
        'Archived after log',
      );
      final preview = await harness.coordinator.preview(
        userId: harness.userId,
        recipeId: published.recipe.id,
        amount: NutritionRecipeLogAmount.wholeRecipe(),
      );

      final first = await harness.coordinator.finalize(
        userId: harness.userId,
        preview: preview,
        mealCategory: 'lunch',
        loggedAt: DateTime.utc(2026, 8, 4, 12),
        localDate: '2026-08-04',
        timezoneId: 'Asia/Kolkata',
        commandId: 'archived-after-log-command',
        allowPartial: true,
      );
      await harness.recipes.archiveRecipe(published.recipe.id);

      final acknowledgementRetry = await harness.coordinator.finalize(
        userId: harness.userId,
        preview: preview,
        mealCategory: 'lunch',
        loggedAt: DateTime.utc(2026, 8, 4, 12),
        localDate: '2026-08-04',
        timezoneId: 'Asia/Kolkata',
        commandId: 'archived-after-log-command',
        allowPartial: false,
      );

      expect(acknowledgementRetry.id, first.id);
      expect(
        await harness.consumption.listAllForUser(userId: harness.userId),
        hasLength(1),
      );
    });

    test(
      'changing the recipe head after preview produces a stale-version error',
      () async {
        final harness = await _Harness.create();
        addTearDown(harness.close);
        final first = await harness.published('stale', 'Stale recipe');
        final preview = await harness.coordinator.preview(
          userId: harness.userId,
          recipeId: first.recipe.id,
          amount: NutritionRecipeLogAmount.wholeRecipe(),
        );
        final successor = await harness.recipes.createSuccessorDraft(
          recipeId: first.recipe.id,
          versionId: 'stale-v2',
        );
        await harness.recipes.publishDraft(
          recipeId: first.recipe.id,
          draftVersionId: successor.version.id,
        );

        expect(
          () => harness.coordinator.finalize(
            userId: harness.userId,
            preview: preview,
            mealCategory: 'breakfast',
            loggedAt: DateTime.utc(2026, 8, 4, 8),
            localDate: '2026-08-04',
            commandId: 'stale-command',
            allowPartial: true,
          ),
          throwsA(
            isA<NutritionRecipeLogError>().having(
              (error) => error.code,
              'code',
              'stale_recipe_version',
            ),
          ),
        );
      },
    );

    test(
      'an explicitly selected published predecessor stays exact through finalization',
      () async {
        final harness = await _Harness.create();
        addTearDown(harness.close);
        final first = await harness.published(
          'selected-version',
          'Versioned recipe',
        );
        final successor = await harness.recipes.createSuccessorDraft(
          recipeId: first.recipe.id,
          versionId: 'selected-version-v2',
        );
        await harness.recipes.publishDraft(
          recipeId: first.recipe.id,
          draftVersionId: successor.version.id,
        );

        final preview = await harness.coordinator.preview(
          userId: harness.userId,
          recipeId: first.recipe.id,
          recipeVersionId: first.version.id,
          amount: NutritionRecipeLogAmount.wholeRecipe(),
        );
        final saved = await harness.coordinator.finalize(
          userId: harness.userId,
          preview: preview,
          mealCategory: 'lunch',
          loggedAt: DateTime.utc(2026, 8, 4, 12),
          localDate: '2026-08-04',
          timezoneId: 'Asia/Kolkata',
          commandId: 'selected-version-command',
          allowPartial: true,
        );

        expect(preview.version.id, first.version.id);
        expect(saved.recipeVersionId, first.version.id);
        expect(saved.items.single.recipeVersionId, first.version.id);
      },
    );

    test(
      'history remains readable from frozen snapshot after recipe changes',
      () async {
        final harness = await _Harness.create();
        addTearDown(harness.close);
        final published = await harness.published(
          'history',
          'Historical label',
        );
        final preview = await harness.coordinator.preview(
          userId: harness.userId,
          recipeId: published.recipe.id,
          amount: NutritionRecipeLogAmount.fraction('0.5'),
        );
        final saved = await harness.coordinator.finalize(
          userId: harness.userId,
          preview: preview,
          mealCategory: 'snack',
          loggedAt: DateTime.utc(2026, 8, 4, 16),
          localDate: '2026-08-04',
          timezoneId: 'Asia/Kolkata',
          commandId: 'history-command',
          consumptionId: 'history-consumption',
          allowPartial: true,
        );
        await harness.recipes.renameRecipe(
          recipeId: published.recipe.id,
          name: 'Current mutable label',
        );
        await harness.recipes.archiveRecipe(published.recipe.id);

        final readModels = NutritionReadModelRepository(
          db: harness.db,
          registry: harness.registry,
          canonicalRepository: harness.consumption,
        );
        final history = await readModels.listForLocalDate(
          userId: harness.userId,
          localDate: '2026-08-04',
        );
        final recipeRecord =
            history.single as NutritionCanonicalSnapshotReadModel;

        expect(recipeRecord.displayLabel, 'Historical label');
        expect(recipeRecord.items.single.recipeVersionId, published.version.id);
        expect(recipeRecord.items.single.quantity.quantity, isNotNull);
        expect(
          recipeRecord.items.single.facts['energy']?.point?.value.toString(),
          saved.items.single.facts['energy']?.point?.value.toString(),
        );
        expect(recipeRecord.isLegacy, isFalse);
        expect(recipeRecord.sourceType, 'canonical_snapshot');
      },
    );

    test(
      'unified daily totals include recipe and legacy sources once',
      () async {
        final harness = await _Harness.create();
        addTearDown(harness.close);
        final published = await harness.published('daily', 'Daily recipe');
        final preview = await harness.coordinator.preview(
          userId: harness.userId,
          recipeId: published.recipe.id,
          amount: NutritionRecipeLogAmount.wholeRecipe(),
        );
        await harness.coordinator.finalize(
          userId: harness.userId,
          preview: preview,
          mealCategory: 'lunch',
          loggedAt: DateTime.utc(2026, 8, 4, 12),
          localDate: '2026-08-04',
          timezoneId: 'Asia/Kolkata',
          commandId: 'daily-command',
          consumptionId: 'daily-consumption',
          allowPartial: true,
        );

        final readModels = NutritionReadModelRepository(
          db: harness.db,
          registry: harness.registry,
          canonicalRepository: harness.consumption,
        );
        final day = await readModels.dailyTotals(
          userId: harness.userId,
          localDate: '2026-08-04',
        );

        expect(day.records, hasLength(1));
        expect(day.sourceCounts['canonical_snapshot'], 1);
        expect(day.totals.facts['energy']?.point?.value.toString(), '100');
        expect(day.recordIds, ['daily-consumption']);
      },
    );

    test(
      'controller exposes loading, partial confirmation, failure, retry, success',
      () async {
        final harness = await _Harness.create();
        addTearDown(harness.close);
        await harness.published('controller', 'Controller recipe');
        final controller = SavedRecipeLogController(
          coordinator: Future.value(harness.coordinator),
          userId: harness.userId,
        );
        addTearDown(controller.dispose);

        await controller.loadRecipes();
        expect(controller.state.status, SavedRecipeLogStatus.ready);
        expect(controller.state.recipes.single.id, 'controller');
        await controller.selectRecipe(controller.state.recipes.single);
        controller.setAmountKind(NutritionRecipeLogAmountKind.fraction);
        controller.setAmountText('0.5');
        await controller.preview();
        expect(controller.state.status, SavedRecipeLogStatus.previewReady);

        await controller.finalize(
          mealCategory: 'lunch',
          loggedAt: DateTime.utc(2026, 8, 4, 11, 59),
          localDate: '2026-08-04',
          timezoneId: 'Asia/Kolkata',
        );
        expect(controller.state.status, SavedRecipeLogStatus.failure);
        expect(controller.state.errorCode, 'partial_confirmation_required');

        controller.acknowledgePartial(true);
        await controller.retryFinalize(
          mealCategory: 'lunch',
          loggedAt: DateTime.utc(2026, 8, 4, 12),
          localDate: '2026-08-04',
          timezoneId: 'Asia/Kolkata',
        );
        expect(controller.state.status, SavedRecipeLogStatus.success);
        expect(
          controller.state.savedSnapshot?.recipeVersionId,
          'controller-v1',
        );
        expect(
          controller.state.savedSnapshot?.loggedAtUtc,
          DateTime.utc(2026, 8, 4, 11, 59),
        );
      },
    );

    testWidgets(
      'saved-recipe selection surface survives compact and large text',
      (tester) async {
        final controller = SavedRecipeLogController(
          coordinator: Completer<NutritionRecipeLogCoordinator>().future,
          userId: 'recipe-user',
        );
        controller.state = controller.state.copyWith(
          status: SavedRecipeLogStatus.ready,
          recipes: const [
            NutritionRecipeModel(
              id: 'screen',
              userId: 'recipe-user',
              name: 'Screen recipe',
              description: null,
              lifecycle: NutritionRecipeLifecycle.active,
              currentVersionId: 'screen-v1',
            ),
          ],
        );

        Widget app({required double textScale}) => ProviderScope(
          overrides: [
            savedRecipeLogControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 568),
                textScaler: TextScaler.linear(textScale),
              ),
              child: const SavedRecipeLogScreen(mealType: 'lunch'),
            ),
          ),
        );

        await tester.pumpWidget(app(textScale: 1));
        await tester.pump();
        expect(find.text('Screen recipe'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(app(textScale: 2));
        await tester.pump();
        expect(find.text('Screen recipe'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _Harness {
  final AppDatabase db;
  final NutrientRegistry registry;
  final NutritionRecipeRepository recipes;
  final NutritionConsumptionRepository consumption;
  final NutritionRecipeLogCoordinator coordinator;
  final String userId;

  _Harness._(
    this.db,
    this.registry,
    this.recipes,
    this.consumption,
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
    await _insertFood(
      db,
      registry,
      foodId: 'food-rice',
      includeFibre: includeFibre,
      estimatedEnergy: estimatedEnergy,
    );
    final recipes = NutritionRecipeRepository(db: db);
    final consumption = NutritionConsumptionRepository(
      db: db,
      registry: registry,
    );
    return _Harness._(
      db,
      registry,
      recipes,
      consumption,
      NutritionRecipeLogCoordinator(
        db: db,
        recipes: recipes,
        calculator: const NutritionCalculationService(),
        consumption: consumption,
        registry: registry,
      ),
      'recipe-user',
    );
  }

  Future<NutritionRecipeDraftModel> draft(String id, String name) =>
      recipes.createRecipe(
        userId: userId,
        recipeId: id,
        versionId: '$id-v1',
        name: name,
        ingredients: [_ingredient('$id-line', 'food-rice')],
        yieldQuantity: _grams('400'),
      );

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
      ingredients: [_ingredient('$id-line', 'food-rice')],
      yieldQuantity: _grams('400'),
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

NutritionRecipeIngredientInput _ingredient(String id, String foodId) =>
    NutritionRecipeIngredientInput.directFood(
      id: id,
      foodId: foodId,
      quantity: _grams('100'),
      position: 0,
    );

Quantity _grams(String value) =>
    Quantity.fromDecimal(amount: value, unit: QuantityUnit.gram);

Future<void> _insertFood(
  AppDatabase db,
  NutrientRegistry registry, {
  required String foodId,
  required bool includeFibre,
  required bool estimatedEnergy,
}) async {
  await db
      .into(db.nutritionFoods)
      .insert(
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
    await db
        .into(db.nutritionFoodNutrientFacts)
        .insert(
          NutritionFoodNutrientFactsCompanion.insert(
            id: '$foodId-${entry.key}-v1',
            foodId: foodId,
            nutrientId: entry.key,
            status: value.status,
            source: 'reviewed_catalogue',
            factVersion: 1,
            basis: 'per_100_grams',
            basisQuantity: const Value(100),
            basisUnit: const Value('gram'),
            amount: Value(value.amount),
            lower: Value(value.lower),
            upper: Value(value.upper),
            isCurrent: const Value(true),
          ),
        );
  }
}
