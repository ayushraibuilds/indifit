import 'dart:convert';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/nutrition_consumption_snapshots.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/nutrition_thali.dart';
import 'package:indifit/core/services/achievement_service.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart'
    hide
        NutritionConsumptionSnapshot,
        NutritionThaliItem,
        NutritionUserConstraint;
import 'package:indifit/data/repositories/nutrition_constraint_repository.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_household_measure_repository.dart';
import 'package:indifit/data/repositories/nutrition_recipe_log_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_recipe_repository.dart';
import 'package:indifit/data/repositories/nutrition_thali_repository.dart';
import 'package:indifit/data/repositories/progress_statistics_repository.dart';
import 'package:indifit/features/food_log/nutrition_thali_controller.dart';
import 'package:indifit/features/food_log/saved_meals_controller.dart';
import 'package:indifit/features/food_log/thali/thali_builder_screen.dart';
import 'package:indifit/features/food_log/thali/thali_presets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PV1-NUT-02 Thali Builder & Modular Indian Meal Composition', () {
    test(
      '1. logThali mints mealGroupId and increments lifetime thaliLoggedCount for Thali Connoisseur',
      () async {
        final harness = await _ThaliTestHarness.create();
        addTearDown(harness.close);

        final controller = NutritionThaliController(
          repository: Future.value(harness.repository),
          userId: harness.userId,
          mealCategory: 'lunch',
        );
        addTearDown(controller.dispose);
        await controller.initialize();

        controller.addFood(
          const NutritionThaliFoodOption(
            id: 'food-roti',
            displayName: 'Roti (Whole Wheat)',
            kind: 'canonical',
            sourceType: 'fixture',
            region: 'IN',
          ),
          quantity: Quantity.fromNum(amount: 60, unit: QuantityUnit.gram),
        );
        controller.addFood(
          const NutritionThaliFoodOption(
            id: 'food-dal',
            displayName: 'Dal Tadka',
            kind: 'canonical',
            sourceType: 'fixture',
            region: 'IN',
          ),
          quantity: Quantity.fromNum(amount: 150, unit: QuantityUnit.gram),
        );

        final snapshot = await controller.logThali(
          loggedAt: DateTime.utc(2026, 8, 4, 13),
          localDate: '2026-08-04',
          timezoneId: 'Asia/Kolkata',
        );

        expect(snapshot, isNotNull);
        expect(snapshot!.mealGroupId, isNotNull);
        expect(snapshot.mealGroupId, startsWith('meal-group:'));
        expect(snapshot.sourceType, 'thali');
        expect(snapshot.items.length, 2);

        // Verify achievement stats bridge reads canonical snapshot
        final progressRepo = ProgressStatisticsRepository(harness.db);
        final stats = await progressRepo.getLifetimeStats();
        expect(stats.thaliLoggedCount, greaterThanOrEqualTo(1));

        // Verify Thali Connoisseur badge unlocks
        final achievements = AchievementService.evaluateFromLifetimeStats(
          stats: stats,
          currentStreakDays: 1,
        );
        final thaliBadge = achievements.firstWhere((a) => a.id == 'first_thali');
        expect(thaliBadge.isUnlocked, isTrue);
        expect(thaliBadge.currentProgress, 1.0);
      },
    );

    test(
      '2. loadPreset gracefully skips missing items with informative userNotice without crashing',
      () async {
        final harness = await _ThaliTestHarness.create();
        addTearDown(harness.close);

        final controller = NutritionThaliController(
          repository: Future.value(harness.repository),
          userId: harness.userId,
          mealCategory: 'lunch',
        );
        addTearDown(controller.dispose);
        await controller.initialize();

        // Database only has 'Roti' and 'Dal', but northIndianClassic has Roti, Dal, Sabzi, Rice, Curd
        await controller.loadPreset(
          presetName: ThaliPresets.northIndianClassic.name,
          items: ThaliPresets.northIndianClassic.items,
        );

        expect(controller.state.draft, isNotNull);
        expect(controller.state.draft!.name, 'North Indian Classic');
        // 4 items found: Roti, Dal, Rice, Curd; Mixed Veg Sabzi is missing
        expect(controller.state.draft!.items.length, 4);
        expect(controller.state.userNotice, isNotNull);
        expect(
          controller.state.userNotice,
          contains('Missing from food library'),
        );
        expect(controller.state.userNotice, contains('Mixed Veg Sabzi'));

        // Preview should have computed for the present items
        expect(controller.state.preview, isNotNull);

        // clearNotice clears it
        controller.clearNotice();
        expect(controller.state.userNotice, isNull);
      },
    );

    test(
      '3. Steppers increment and decrement portion amounts cleanly',
      () async {
        final harness = await _ThaliTestHarness.create();
        addTearDown(harness.close);

        final controller = NutritionThaliController(
          repository: Future.value(harness.repository),
          userId: harness.userId,
          mealCategory: 'lunch',
        );
        addTearDown(controller.dispose);
        await controller.initialize();

        controller.addFood(
          const NutritionThaliFoodOption(
            id: 'food-roti',
            displayName: 'Roti (Whole Wheat)',
            kind: 'canonical',
            sourceType: 'fixture',
            region: 'IN',
          ),
          quantity: Quantity.fromNum(amount: 2, unit: QuantityUnit.piece),
        );

        final itemId = controller.state.draft!.items.first.id;

        // Increment by 1
        controller.incrementQuantity(itemId, step: 1.0);
        expect(
          controller.state.draft!.items.first.quantity.amount.asDouble,
          3.0,
        );

        // Decrement by 1
        controller.decrementQuantity(itemId, step: 1.0);
        expect(
          controller.state.draft!.items.first.quantity.amount.asDouble,
          2.0,
        );

        // Decrement below min clamps
        controller.decrementQuantity(itemId, step: 5.0, min: 1.0);
        expect(
          controller.state.draft!.items.first.quantity.amount.asDouble,
          1.0,
        );
      },
    );

    test(
      '4. Slot validation accepts all 10 supported slots and rejects unknown slot',
      () async {
        final harness = await _ThaliTestHarness.create();
        addTearDown(harness.close);

        // Valid slots: breakfast, morning_snack, lunch, afternoon_snack, evening_snack,
        // dinner, pre_workout, post_workout, snack, late_snack
        for (final slot in [
          'breakfast',
          'morning_snack',
          'lunch',
          'afternoon_snack',
          'evening_snack',
          'dinner',
          'pre_workout',
          'post_workout',
          'snack',
          'late_snack',
        ]) {
          final controller = NutritionThaliController(
            repository: Future.value(harness.repository),
            userId: harness.userId,
            mealCategory: slot,
          );
          await controller.initialize();
          controller.addFood(
            const NutritionThaliFoodOption(
              id: 'food-roti',
              displayName: 'Roti (Whole Wheat)',
              kind: 'canonical',
              sourceType: 'fixture',
              region: 'IN',
            ),
          );
          await controller.preview();
          final snapshot = await controller.finalize(
            loggedAt: DateTime.utc(2026, 8, 4, 12),
            localDate: '2026-08-04',
            timezoneId: 'Asia/Kolkata',
          );
          expect(snapshot, isNotNull);
          expect(snapshot!.mealCategory, slot);
          controller.dispose();
        }

        // Unknown slot
        final invalidController = NutritionThaliController(
          repository: Future.value(harness.repository),
          userId: harness.userId,
          mealCategory: 'invalid_midnight_buffet',
        );
        await invalidController.initialize();
        invalidController.addFood(
          const NutritionThaliFoodOption(
            id: 'food-roti',
            displayName: 'Roti (Whole Wheat)',
            kind: 'canonical',
            sourceType: 'fixture',
            region: 'IN',
          ),
        );
        await invalidController.preview();
        final invalidSnapshot = await invalidController.finalize(
          loggedAt: DateTime.utc(2026, 8, 4, 12),
          localDate: '2026-08-04',
          timezoneId: 'Asia/Kolkata',
        );
        expect(invalidSnapshot, isNull);
        expect(invalidController.state.status, NutritionThaliStatus.failure);
        expect(invalidController.state.errorCode, 'invalid_meal_category');
        invalidController.dispose();
      },
    );

    test(
      '5. saveAsTemplate / saveDraft converges directly with SavedMealsController',
      () async {
        final harness = await _ThaliTestHarness.create();
        addTearDown(harness.close);

        final controller = NutritionThaliController(
          repository: Future.value(harness.repository),
          userId: harness.userId,
          mealCategory: 'lunch',
        );
        addTearDown(controller.dispose);
        await controller.initialize();
        controller.setName('Special Festive Thali');
        controller.addFood(
          const NutritionThaliFoodOption(
            id: 'food-roti',
            displayName: 'Roti (Whole Wheat)',
            kind: 'canonical',
            sourceType: 'fixture',
            region: 'IN',
          ),
        );

        // Save as template via logThali
        await controller.logThali(
          loggedAt: DateTime.utc(2026, 8, 4, 13),
          localDate: '2026-08-04',
          timezoneId: 'Asia/Kolkata',
          saveAsTemplate: true,
        );

        // Saved meals controller should see this saved meal draft
        final savedMealsController = SavedMealsController(
          thaliRepoFuture: Future.value(harness.repository),
          userId: harness.userId,
        );
        addTearDown(savedMealsController.dispose);
        await savedMealsController.loadSavedMeals();

        expect(savedMealsController.state.meals, hasLength(1));
        expect(
          savedMealsController.state.meals.first.draft.name,
          'Special Festive Thali',
        );
      },
    );

    test(
      '6. Mid-failure triggers transaction rollback without leaving orphan consumption records',
      () async {
        final harness = await _ThaliTestHarness.create();
        addTearDown(harness.close);

        var failNow = true;
        final failingConsumption = NutritionConsumptionRepository(
          db: harness.db,
          registry: harness.registry,
          failureInjector: (stage) {
            if (stage == 'after_items' && failNow) {
              throw StateError('Simulated network/disk write error mid-transaction');
            }
          },
        );

        final failingRepo = harness.withConsumption(failingConsumption);
        final controller = NutritionThaliController(
          repository: Future.value(failingRepo),
          userId: harness.userId,
          mealCategory: 'lunch',
        );
        addTearDown(controller.dispose);
        await controller.initialize();
        controller.addFood(
          const NutritionThaliFoodOption(
            id: 'food-roti',
            displayName: 'Roti (Whole Wheat)',
            kind: 'canonical',
            sourceType: 'fixture',
            region: 'IN',
          ),
        );

        await controller.preview();
        final failedSnapshot = await controller.finalize(
          loggedAt: DateTime.utc(2026, 8, 4, 13),
          localDate: '2026-08-04',
          timezoneId: 'Asia/Kolkata',
        );

        expect(failedSnapshot, isNull);
        expect(controller.state.status, NutritionThaliStatus.failure);

        // Assert 0 rows in consumption snapshots table
        final allSnapshots = await harness.db.select(harness.db.nutritionConsumptionSnapshots).get();
        expect(allSnapshots, isEmpty);

        // Assert 0 rows in snapshot items table
        final allItems = await harness.db.select(harness.db.nutritionSnapshotItems).get();
        expect(allItems, isEmpty);
      },
    );

    test(
      '7. Idempotent finalization with duplicate commandId returns existing snapshot',
      () async {
        final harness = await _ThaliTestHarness.create();
        addTearDown(harness.close);

        final draft = harness.repository.newDraft(
          userId: harness.userId,
          name: 'Idempotent Thali',
          items: [
            NutritionThaliItem(
              id: 'thali-item-1',
              position: 0,
              source: NutritionThaliItemSource.food,
              foodId: 'food-roti',
              recipeVersionId: null,
              quantity: Quantity.fromNum(amount: 100, unit: QuantityUnit.gram),
              displayLabel: 'Roti',
            ),
          ],
        );
        final savedDraft = await harness.repository.saveDraft(draft);
        final preview = await harness.repository.preview(draft: savedDraft);

        const commandId = 'thali-idempotency-command-123';
        final first = await harness.repository.finalize(
          preview: preview,
          mealCategory: 'lunch',
          loggedAt: DateTime.utc(2026, 8, 4, 12),
          commandId: commandId,
          localDate: '2026-08-04',
          timezoneId: 'Asia/Kolkata',
          allowPartial: true,
        );

        final second = await harness.repository.finalize(
          preview: preview,
          mealCategory: 'lunch',
          loggedAt: DateTime.utc(2026, 8, 4, 12),
          commandId: commandId,
          localDate: '2026-08-04',
          timezoneId: 'Asia/Kolkata',
          allowPartial: true,
        );

        expect(first.id, second.id);
        final allSnapshots = await harness.db.select(harness.db.nutritionConsumptionSnapshots).get();
        expect(allSnapshots, hasLength(1));
      },
    );

    testWidgets(
      '8. ThaliBuilderScreen renders empty state, loads presets, and logs meal',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final harness = await _ThaliTestHarness.create(tester: tester);
        addTearDown(() async {
          await tester.runAsync(harness.close);
        });

        final controller = NutritionThaliController(
          repository: Future.value(harness.repository),
          userId: harness.userId,
          mealCategory: 'lunch',
        );
        await tester.runAsync(controller.initialize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(harness.db),
              localTimezoneServiceProvider.overrideWithValue(
                LocalTimezoneService(read: () async => 'Asia/Kolkata'),
              ),
              nutritionThaliRepositoryProvider.overrideWith(
                (ref) async => harness.repository,
              ),
              nutritionThaliControllerProvider('lunch').overrideWith(
                (ref) => controller,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const ThaliBuilderScreen(mealCategory: 'lunch'),
            ),
          ),
        );

        // Initial pump
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 300));

        // Header
        expect(find.text('Lunch Thali'), findsOneWidget);
        // Empty plate state
        expect(find.text('Your Thali Plate is Empty'), findsOneWidget);
        // Archetype presets
        expect(find.byKey(const Key('thali_preset_north_indian_classic')), findsOneWidget);

        // Tap preset chip
        await tester.tap(find.byKey(const Key('thali_preset_north_indian_classic')));
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump(const Duration(milliseconds: 300));

        // Should now have items in list
        expect(find.byKey(const Key('thali_items_list')), findsOneWidget);
        expect(find.textContaining('Roti'), findsAtLeast(1));
        expect(find.textContaining('Dal'), findsAtLeast(1));

        // Summary bar should display live calories
        expect(find.byKey(const Key('thali_summary_calories')), findsOneWidget);
        expect(find.byKey(const Key('thali_log_meal_button')), findsOneWidget);

        // Tap Log Thali button
        await tester.tap(find.byKey(const Key('thali_log_meal_button')));
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pump(const Duration(milliseconds: 300));

        // Snapshot is saved in db
        final allSnapshots = await tester.runAsync(
          () => harness.db.select(harness.db.nutritionConsumptionSnapshots).get(),
        );
        expect(allSnapshots, isNotNull);
        expect(allSnapshots!, hasLength(1));
        expect(allSnapshots.first.sourceType, 'thali');
        expect(allSnapshots.first.mealGroupId, isNotNull);
      },
    );

    test(
      '9. Deleting / retracting a meal does not inflate totalMealsLogged or thaliLoggedCount',
      () async {
        final harness = await _ThaliTestHarness.create();
        addTearDown(harness.close);
        final progressRepo = ProgressStatisticsRepository(harness.db);

        // 1. Initial empty state: 0 meals, 0 thalis
        var stats = await progressRepo.getLifetimeStats();
        expect(stats.totalMealsLogged, 0);
        expect(stats.thaliLoggedCount, 0);

        // 2. Log a genuine thali meal carrying mealGroupId
        final controller = NutritionThaliController(
          repository: Future.value(harness.repository),
          userId: harness.userId,
          mealCategory: 'lunch',
        );
        addTearDown(controller.dispose);
        await controller.initialize();

        controller.addFood(
          const NutritionThaliFoodOption(
            id: 'food-roti',
            displayName: 'Roti (Whole Wheat)',
            kind: 'canonical',
            sourceType: 'fixture',
            region: 'IN',
          ),
          quantity: Quantity.fromNum(amount: 60, unit: QuantityUnit.gram),
        );

        final snapshot = await controller.logThali(
          loggedAt: DateTime.utc(2026, 8, 4, 13),
          localDate: '2026-08-04',
          timezoneId: 'Asia/Kolkata',
        );
        expect(snapshot, isNotNull);

        stats = await progressRepo.getLifetimeStats();
        expect(stats.totalMealsLogged, 1);
        expect(stats.thaliLoggedCount, 1);

        // 3. Retract / delete the thali meal
        // Deleting a thali writes an append-only retraction snapshot carrying the same mealGroupId,
        // superseding the original snapshot.
        await harness.db.into(harness.db.nutritionConsumptionSnapshots).insert(
          NutritionConsumptionSnapshotsCompanion.insert(
            id: 'thali-retraction-${snapshot!.id}',
            userId: harness.userId,
            loggedAt: snapshot.loggedAtUtc,
            mealCategory: snapshot.mealCategory,
            sourceType: 'thali',
            calculatorVersion: snapshot.calculatorVersion,
            completeness: 'complete',
            estimateStatus: 'none',
            mealGroupId: Value(snapshot.mealGroupId),
            lineage: Value(
              jsonEncode({
                'contract_version': kNutritionConsumptionSnapshotContractVersion,
                'content_fingerprint': 'fp-retraction',
                'supersedes_snapshot_id': snapshot.id,
                'correction_id': 'corr-retract',
                'correction_reason': 'User deleted thali',
                'evidence': {
                  'retraction': {
                    'contract_version': kNutritionConsumptionRetractionContractVersion,
                    'predecessor_snapshot_id': snapshot.id,
                    'reason': 'User deleted thali',
                  },
                },
              }),
            ),
          ),
        );

        // Assert that the database now contains 2 rows (original + retraction),
        // both carrying mealGroupId.
        final allDbSnapshots = await harness.db
            .select(harness.db.nutritionConsumptionSnapshots)
            .get();
        expect(allDbSnapshots.length, 2);

        // Stats bridge must filter out both:
        // - Original is superseded -> excluded
        // - Retraction is a retraction marker -> excluded
        stats = await progressRepo.getLifetimeStats();
        expect(stats.totalMealsLogged, 0, reason: 'Delete must not leave inflated meal count');
        expect(stats.thaliLoggedCount, 0, reason: 'Delete must not leave inflated thali count');
      },
    );

    test(
      '10. Prospective estimate and recommendation snapshots do not count as logged meals',
      () async {
        final harness = await _ThaliTestHarness.create();
        addTearDown(harness.close);
        final progressRepo = ProgressStatisticsRepository(harness.db);

        // 1. Insert an estimate snapshot (sourceType: 'estimate')
        await harness.db.into(harness.db.nutritionConsumptionSnapshots).insert(
          NutritionConsumptionSnapshotsCompanion.insert(
            id: 'estimate-snap-1',
            userId: harness.userId,
            loggedAt: DateTime.utc(2026, 8, 4, 14, 0),
            mealCategory: 'lunch',
            sourceType: 'estimate',
            calculatorVersion: 'v1',
            completeness: 'complete',
            estimateStatus: 'estimated',
            mealGroupId: const Value('meal-group:estimate-1'),
          ),
        );

        // 2. Insert a recommendation event (sourceType: 'b04_production_orchestration')
        await harness.db.into(harness.db.nutritionConsumptionSnapshots).insert(
          NutritionConsumptionSnapshotsCompanion.insert(
            id: 'orchestration-snap-1',
            userId: harness.userId,
            loggedAt: DateTime.utc(2026, 8, 4, 14, 30),
            mealCategory: 'lunch',
            sourceType: 'b04_production_orchestration',
            calculatorVersion: 'v1',
            completeness: 'complete',
            estimateStatus: 'none',
          ),
        );

        // Verify neither estimate nor orchestration count towards stats
        var stats = await progressRepo.getLifetimeStats();
        expect(stats.totalMealsLogged, 0);
        expect(stats.thaliLoggedCount, 0);

        // 3. Insert a legitimate direct_food meal
        await harness.db.into(harness.db.nutritionConsumptionSnapshots).insert(
          NutritionConsumptionSnapshotsCompanion.insert(
            id: 'genuine-meal-1',
            userId: harness.userId,
            loggedAt: DateTime.utc(2026, 8, 4, 15, 0),
            mealCategory: 'lunch',
            sourceType: 'direct_food',
            calculatorVersion: 'v1',
            completeness: 'complete',
            estimateStatus: 'none',
          ),
        );

        stats = await progressRepo.getLifetimeStats();
        expect(stats.totalMealsLogged, 1, reason: 'Only genuine meal counts');
        expect(stats.thaliLoggedCount, 0);
      },
    );
  });
}

class _ThaliTestHarness {
  final AppDatabase db;
  final NutrientRegistry registry;
  final NutritionRecipeRepository recipes;
  final NutritionConsumptionRepository consumption;
  final NutritionThaliRepository repository;
  final String userId;

  _ThaliTestHarness._(
    this.db,
    this.registry,
    this.recipes,
    this.consumption,
    this.repository,
    this.userId,
  );

  static Future<_ThaliTestHarness> create({WidgetTester? tester}) async {
    final db = AppDatabase.memory();
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    Future<void> doInserts() async {
      await _insertFoodItem(db, 'food-roti', 120, 'Roti (Whole Wheat)', 'roti');
      await _insertFoodItem(db, 'food-dal', 150, 'Dal Tadka', 'dal');
      await _insertFoodItem(db, 'food-rice', 130, 'Steamed Rice', 'rice');
    }
    if (tester != null) {
      await tester.runAsync(doInserts);
    } else {
      await doInserts();
    }

    final recipes = NutritionRecipeRepository(db: db);
    final consumption = NutritionConsumptionRepository(
      db: db,
      registry: registry,
    );
    final repo = _createRepository(
      db: db,
      registry: registry,
      recipes: recipes,
      consumption: consumption,
    );
    return _ThaliTestHarness._(
      db,
      registry,
      recipes,
      consumption,
      repo,
      kLocalNutritionUserScopeId,
    );
  }

  NutritionThaliRepository withConsumption(
    NutritionConsumptionRepository customConsumption,
  ) => _createRepository(
    db: db,
    registry: registry,
    recipes: recipes,
    consumption: customConsumption,
  );

  Future<void> close() => db.close();

  static NutritionThaliRepository _createRepository({
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

Future<void> _insertFoodItem(
  AppDatabase db,
  String id,
  double energy,
  String displayName,
  String alias,
) async {
  await db.into(db.nutritionFoods).insert(
        NutritionFoodsCompanion.insert(
          id: id,
          kind: 'canonical',
          displayName: displayName,
          locale: 'en-IN',
          sourceType: 'fixture',
          lifecycle: 'active',
        ),
      );
  await db.into(db.nutritionFoodAliases).insert(
        NutritionFoodAliasesCompanion.insert(
          id: '$id-alias',
          foodId: Value(id),
          alias: alias,
          normalizedAlias: alias.toLowerCase(),
          locale: 'en-IN',
          source: 'canonical',
          isActive: const Value(true),
        ),
      );
  await db.into(db.nutritionFoodNutrientFacts).insert(
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
  await db.into(db.nutritionFoodNutrientFacts).insert(
        NutritionFoodNutrientFactsCompanion.insert(
          id: '$id-protein-v1',
          foodId: id,
          nutrientId: 'protein',
          status: 'known',
          source: 'reviewed_catalogue',
          factVersion: 1,
          basis: 'per_100_grams',
          basisQuantity: const Value(100),
          basisUnit: const Value('gram'),
          amount: const Value(6.0),
          isCurrent: const Value(true),
        ),
      );
  await db.into(db.nutritionFoodNutrientFacts).insert(
        NutritionFoodNutrientFactsCompanion.insert(
          id: '$id-carb-v1',
          foodId: id,
          nutrientId: 'carbohydrate',
          status: 'known',
          source: 'reviewed_catalogue',
          factVersion: 1,
          basis: 'per_100_grams',
          basisQuantity: const Value(100),
          basisUnit: const Value('gram'),
          amount: const Value(25.0),
          isCurrent: const Value(true),
        ),
      );
  await db.into(db.nutritionFoodNutrientFacts).insert(
        NutritionFoodNutrientFactsCompanion.insert(
          id: '$id-fat-v1',
          foodId: id,
          nutrientId: 'fat',
          status: 'known',
          source: 'reviewed_catalogue',
          factVersion: 1,
          basis: 'per_100_grams',
          basisQuantity: const Value(100),
          basisUnit: const Value('gram'),
          amount: const Value(2.0),
          isCurrent: const Value(true),
        ),
      );
}
