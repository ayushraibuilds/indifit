import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/nutrition_consumption_snapshots.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart'
    hide NutritionConsumptionSnapshot;
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_logging_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/data/repositories/nutrition_transformation_repository.dart';
import 'package:indifit/features/dashboard/widgets/dashboard_meal_section.dart';
import 'package:indifit/features/food_log/food_log_surface.dart';
import 'package:indifit/features/food_log/food_search_screen.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

NutritionConsumptionSnapshot _testConsumptionSnapshot({
  required String id,
  required String userId,
  required DateTime loggedAt,
  required String mealCategory,
  required String localDate,
  required String timezoneId,
}) {
  final completeness = NutrientCompleteness(
    state: NutrientCompletenessState.unknown,
    requestedNutrientIds: const ['energy'],
    availableNutrientIds: const [],
    missingNutrientIds: const ['energy'],
    estimatedNutrientIds: const [],
    notApplicableNutrientIds: const [],
    partiallyKnownNutrientIds: const [],
  );
  return NutritionConsumptionSnapshot(
    id: id,
    userId: userId,
    loggedAtUtc: loggedAt,
    mealCategory: mealCategory,
    mealGroupId: null,
    sourceType: 'direct_food',
    recipeVersionId: null,
    thaliId: null,
    calculatorVersion: 'test',
    completeness: completeness,
    totals: NutrientAggregationResult(
      facts: const {},
      completeness: completeness,
      sourceLineage: const {},
      factVersionLineage: const {},
    ),
    localDate: localDate,
    timezoneId: timezoneId,
    createdAtUtc: loggedAt,
    lineage: NutritionConsumptionLineage(contentFingerprint: 'test-$id'),
    items: const [],
  );
}

class _EmptyFoodRepository extends FoodRepository {
  _EmptyFoodRepository(super.db);

  @override
  Future<List<FoodItem>> getRecentFoods(int limit) async => const [];

  @override
  Future<List<FoodItem>> searchFoodLocal(String query) async => const [];
}

class _Harness {
  _Harness._(
    this.db,
    this.registry,
    this.catalog,
    this.consumption,
    this.coordinator,
    this.readModels,
  );

  final AppDatabase db;
  final NutrientRegistry registry;
  final NutritionFoodCatalogRepository catalog;
  final NutritionConsumptionRepository consumption;
  final NutritionFoodLoggingCoordinator coordinator;
  final NutritionReadModelRepository readModels;

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
    final readModels = NutritionReadModelRepository(
      db: db,
      registry: registry,
      canonicalRepository: consumption,
    );
    final coordinator = NutritionFoodLoggingCoordinator(
      db: db,
      registry: registry,
      catalog: catalog,
      calculator: const NutritionCalculationService(),
      consumption: consumption,
      transformations: transformations,
    );
    return _Harness._(
      db,
      registry,
      catalog,
      consumption,
      coordinator,
      readModels,
    );
  }

  Future<void> close() async {
    await db.close();
  }
}

class _TrackingBatchCoordinator extends NutritionFoodLoggingCoordinator {
  _TrackingBatchCoordinator({
    required super.db,
    required super.registry,
    required super.catalog,
    required super.consumption,
  }) : super(
         calculator: const NutritionCalculationService(),
         transformations: NutritionTransformationRepository(db: db),
       );

  int batchCalls = 0;
  List<NutritionFoodLogPreview> lastPreviews = [];
  String? lastMealCategory;
  String? lastLocalDate;
  String? lastTimezoneId;

  @override
  Future<NutritionConsumptionSnapshot> finalizeBatch({
    required String userId,
    required Iterable<NutritionFoodLogPreview> previews,
    required String mealCategory,
    required DateTime loggedAt,
    required String localDate,
    required String timezoneId,
    String? mealGroupId,
    String? consumptionId,
    String? commandId,
  }) {
    batchCalls++;
    lastPreviews = previews.toList();
    lastMealCategory = mealCategory;
    lastLocalDate = localDate;
    lastTimezoneId = timezoneId;
    return Future.value(
      _testConsumptionSnapshot(
        userId: userId,
        loggedAt: loggedAt,
        mealCategory: mealCategory,
        localDate: localDate,
        timezoneId: timezoneId,
        id: 'test-batch-snapshot-123',
      ),
    );
  }
}

class _FailingBatchCoordinator extends NutritionFoodLoggingCoordinator {
  _FailingBatchCoordinator({
    required super.db,
    required super.registry,
    required super.catalog,
    required super.consumption,
  }) : super(
         calculator: const NutritionCalculationService(),
         transformations: NutritionTransformationRepository(db: db),
       );

  int batchCallCount = 0;

  @override
  Future<NutritionConsumptionSnapshot> finalizeBatch({
    required String userId,
    required Iterable<NutritionFoodLogPreview> previews,
    required String mealCategory,
    required DateTime loggedAt,
    required String localDate,
    required String timezoneId,
    String? mealGroupId,
    String? consumptionId,
    String? commandId,
  }) {
    batchCallCount++;
    return Future.error(
      const NutritionFoodLoggingError('network_fail', 'Network failure'),
    );
  }
}

Future<void> _pumpFoodSearch({
  required WidgetTester tester,
  required _Harness harness,
  required List<CanonicalRecentFood> recent,
  required String mealType,
  DateTime? selectedDate,
  bool initialMultiSelect = false,
  NutritionFoodLoggingCoordinator? coordinatorOverride,
  ThemeData? themeOverride,
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(harness.db),
        localTimezoneServiceProvider.overrideWithValue(
          LocalTimezoneService(read: () async => 'Asia/Kolkata'),
        ),
        nutritionRegistryProvider.overrideWith(
          (ref) async => harness.registry,
        ),
        nutritionFoodCatalogRepositoryProvider.overrideWith(
          (ref) async => harness.catalog,
        ),
        nutritionConsumptionRepositoryProvider.overrideWith(
          (ref) async => harness.consumption,
        ),
        nutritionReadModelRepositoryProvider.overrideWith(
          (ref) async => harness.readModels,
        ),
        nutritionFoodLoggingCoordinatorProvider.overrideWith(
          (ref) async => coordinatorOverride ?? harness.coordinator,
        ),
        foodRepositoryProvider.overrideWithValue(
          _EmptyFoodRepository(harness.db),
        ),
        canonicalRecentFoodsProvider.overrideWith((ref) async => recent),
        foodLogsForDayProvider.overrideWith((ref, date) async => []),
        canonicalFoodRecordsForDayProvider.overrideWith(
          (ref, date) async => [],
        ),
      ],
      child: MaterialApp(
        theme: themeOverride ?? AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: FoodSearchScreen(
          mealType: mealType,
          selectedDate: selectedDate,
          initialMultiSelect: initialMultiSelect,
        ),
      ),
    ),
  );
  await _settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R08D.5: Canonical Coordinator Batch Persistence', () {
    test('finalizeBatch creates atomic snapshot with distinct food quantities and meal context', () async {
      final harness = await _Harness.create();
      addTearDown(harness.close);

      final rice = await harness.catalog.createUserFood(
        displayName: 'Basmati Rice',
        servingSize: 100,
        servingUnit: 'g',
        energyKcal: 130,
        proteinG: 3,
        carbohydrateG: 28,
        fatG: 0.5,
      );
      final dal = await harness.catalog.createUserFood(
        displayName: 'Moong Dal',
        servingSize: 150,
        servingUnit: 'g',
        energyKcal: 160,
        proteinG: 9,
        carbohydrateG: 22,
        fatG: 3,
      );

      final p1 = await harness.coordinator.preview(
        option: rice,
        quantity: rice.baseQuantity,
      );
      final p2 = await harness.coordinator.preview(
        option: dal,
        quantity: dal.baseQuantity,
      );

      const userScope = 'local-user';
      final snapshot = await harness.coordinator.finalizeBatch(
        userId: userScope,
        previews: [p1, p2],
        mealCategory: 'lunch',
        loggedAt: DateTime.utc(2026, 8, 24, 13, 0),
        localDate: '2026-08-24',
        timezoneId: 'Asia/Kolkata',
      );

      expect(snapshot.mealCategory, 'lunch');
      expect(snapshot.localDate, '2026-08-24');
      expect(snapshot.timezoneId, 'Asia/Kolkata');
      expect(snapshot.items, hasLength(2));

      final history = await harness.readModels.listHistory(
        userId: userScope,
      );
      expect(history.where((r) => !r.isLegacy), hasLength(1));
      final record = history.firstWhere((r) => !r.isLegacy);
      expect(record.mealCategory, 'lunch');
      expect(record.items, hasLength(2));
      expect(record.items.map((i) => i.foodId), containsAll([rice.id, dal.id]));
    });
  });

  group('R08D.5: Normal Mode vs Explicit Multi-Select Mode', () {
    testWidgets('Normal mode defaults to single-select with no checkboxes and fast add', (tester) async {
      final harness = await _Harness.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        unawaited(harness.close());
      });

      final options = (await tester.runAsync(() async {
        final r = await harness.catalog.createUserFood(
          displayName: 'Rice',
          servingSize: 100,
          servingUnit: 'g',
          energyKcal: 130,
          proteinG: 3,
          carbohydrateG: 28,
          fatG: 0.5,
        );
        final d = await harness.catalog.createUserFood(
          displayName: 'Dal',
          servingSize: 150,
          servingUnit: 'g',
          energyKcal: 150,
          proteinG: 8,
          carbohydrateG: 20,
          fatG: 3,
        );
        return [r, d];
      }))!;

      final recent = [
        CanonicalRecentFood(
          option: options[0],
          quantityLabel: '100 g',
          loggedAtUtc: DateTime.utc(2026, 8, 24, 12, 0),
        ),
        CanonicalRecentFood(
          option: options[1],
          quantityLabel: '150 g',
          loggedAtUtc: DateTime.utc(2026, 8, 24, 12, 5),
        ),
      ];

      await _pumpFoodSearch(
        tester: tester,
        harness: harness,
        recent: recent,
        mealType: 'lunch',
      );

      // In normal mode, no checkboxes exist
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byKey(const ValueKey('toggle_multiselect_mode')), findsOneWidget);
      expect(find.text('Log lunch'), findsOneWidget);
    });

    testWidgets('Enter and exit multi-select mode via explicit action', (tester) async {
      final harness = await _Harness.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        unawaited(harness.close());
      });

      final option = (await tester.runAsync(() async {
        return harness.catalog.createUserFood(
          displayName: 'Paneer',
          servingSize: 100,
          servingUnit: 'g',
          energyKcal: 260,
          proteinG: 18,
          carbohydrateG: 4,
          fatG: 20,
        );
      }))!;

      final recent = [
        CanonicalRecentFood(
          option: option,
          quantityLabel: '100 g',
          loggedAtUtc: DateTime.utc(2026, 8, 24, 12, 0),
        ),
      ];

      await _pumpFoodSearch(
        tester: tester,
        harness: harness,
        recent: recent,
        mealType: 'dinner',
      );

      // Normal mode: 0 checkboxes
      expect(find.byType(Checkbox), findsNothing);

      // Enter multi-select mode
      await tester.tap(find.byKey(const ValueKey('toggle_multiselect_mode')));
      await _settle(tester);

      // Checkboxes appear
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.text('Select dinner foods'), findsOneWidget);

      // Select item
      await tester.tap(find.byType(Checkbox));
      await _settle(tester);
      expect(find.textContaining('1 food selected'), findsOneWidget);

      // Exit multi-select mode
      await tester.tap(find.byKey(const ValueKey('toggle_multiselect_mode')));
      await _settle(tester);

      // Back to normal mode, checkboxes gone and selection cleared
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Log dinner'), findsOneWidget);
      expect(find.textContaining('selected'), findsNothing);
    });
  });

  group('R08D.5: Selection, Per-Item Quantity, and Batch Logging', () {
    testWidgets('Select multiple foods with distinct units and log atomically', (tester) async {
      final harness = await _Harness.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        unawaited(harness.close());
      });

      final trackingCoordinator = _TrackingBatchCoordinator(
        db: harness.db,
        registry: harness.registry,
        catalog: harness.catalog,
        consumption: harness.consumption,
      );

      final options = (await tester.runAsync(() async {
        final r = await harness.catalog.createUserFood(
          displayName: 'Brown Rice',
          servingSize: 100,
          servingUnit: 'g',
          energyKcal: 110,
          proteinG: 3,
          carbohydrateG: 23,
          fatG: 1,
        );
        final c = await harness.catalog.createUserFood(
          displayName: 'Curd',
          servingSize: 1,
          servingUnit: 'cup',
          energyKcal: 120,
          proteinG: 6,
          carbohydrateG: 8,
          fatG: 4,
        );
        return [r, c];
      }))!;

      final recent = [
        CanonicalRecentFood(
          option: options[0],
          quantityLabel: '100 g',
          loggedAtUtc: DateTime.utc(2026, 8, 24, 12, 0),
        ),
        CanonicalRecentFood(
          option: options[1],
          quantityLabel: '1 cup',
          loggedAtUtc: DateTime.utc(2026, 8, 24, 12, 5),
        ),
      ];

      await _pumpFoodSearch(
        tester: tester,
        harness: harness,
        recent: recent,
        mealType: 'lunch',
        selectedDate: DateTime(2026, 8, 24),
        initialMultiSelect: true,
        coordinatorOverride: trackingCoordinator,
      );

      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(2));

      // Select both
      await tester.tap(checkboxes.at(0));
      await _settle(tester);
      await tester.tap(checkboxes.at(1));
      await _settle(tester);

      expect(find.text('2 foods selected · 230 kcal'), findsOneWidget);
      expect(find.text('Add 2 foods to lunch'), findsOneWidget);

      // Verify each chip has its unit
      expect(find.textContaining('Brown Rice (100 g)'), findsOneWidget);
      expect(find.textContaining('Curd (1 cup)'), findsOneWidget);

      // Commit batch
      await tester.tap(find.text('Add 2 foods to lunch'));
      await _settle(tester);

      // Verify coordinator received call with accurate data
      expect(trackingCoordinator.batchCalls, 1);
      expect(trackingCoordinator.lastMealCategory, 'lunch');
      expect(trackingCoordinator.lastLocalDate, '2026-08-24');
      expect(trackingCoordinator.lastPreviews, hasLength(2));
      expect(
        trackingCoordinator.lastPreviews.map((p) => p.effectiveFood.id),
        containsAll([options[0].id, options[1].id]),
      );
    });

    testWidgets('Deselect via chip deletion and clear button', (tester) async {
      final harness = await _Harness.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        unawaited(harness.close());
      });

      final options = (await tester.runAsync(() async {
        final f1 = await harness.catalog.createUserFood(
          displayName: 'Apple',
          servingSize: 1,
          servingUnit: 'medium',
          energyKcal: 95,
          proteinG: 0.5,
          carbohydrateG: 25,
          fatG: 0.3,
        );
        final f2 = await harness.catalog.createUserFood(
          displayName: 'Banana',
          servingSize: 1,
          servingUnit: 'medium',
          energyKcal: 105,
          proteinG: 1.3,
          carbohydrateG: 27,
          fatG: 0.3,
        );
        return [f1, f2];
      }))!;

      final recent = [
        CanonicalRecentFood(
          option: options[0],
          quantityLabel: '1 medium',
          loggedAtUtc: DateTime.utc(2026, 8, 24, 12, 0),
        ),
        CanonicalRecentFood(
          option: options[1],
          quantityLabel: '1 medium',
          loggedAtUtc: DateTime.utc(2026, 8, 24, 12, 5),
        ),
      ];

      await _pumpFoodSearch(
        tester: tester,
        harness: harness,
        recent: recent,
        mealType: 'snack',
        initialMultiSelect: true,
      );

      final checkboxes = find.byType(Checkbox);
      await tester.tap(checkboxes.at(0));
      await _settle(tester);
      await tester.tap(checkboxes.at(1));
      await _settle(tester);

      expect(find.text('2 foods selected · 200 kcal'), findsOneWidget);

      // Deselect via chip delete icon
      final deleteButtons = find.byIcon(Icons.cancel);
      if (deleteButtons.evaluate().isNotEmpty) {
        await tester.tap(deleteButtons.first);
        await _settle(tester);
        expect(find.text('1 food selected · 105 kcal'), findsOneWidget);
      }

      // Clear all
      await tester.tap(find.text('Clear'));
      await _settle(tester);
      expect(find.text('0 selected · Today'), findsOneWidget);
      expect(find.textContaining('ADD'), findsNothing);
    });

    testWidgets('Failure during batch commit preserves selection for retry', (tester) async {
      final harness = await _Harness.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        unawaited(harness.close());
      });

      final option = (await tester.runAsync(() async {
        return harness.catalog.createUserFood(
          displayName: 'Oatmeal',
          servingSize: 50,
          servingUnit: 'g',
          energyKcal: 190,
          proteinG: 6,
          carbohydrateG: 34,
          fatG: 3,
        );
      }))!;

      final recent = [
        CanonicalRecentFood(
          option: option,
          quantityLabel: '50 g',
          loggedAtUtc: DateTime.utc(2026, 8, 24, 8, 0),
        ),
      ];

      final failingCoordinator = _FailingBatchCoordinator(
        db: harness.db,
        registry: harness.registry,
        catalog: harness.catalog,
        consumption: harness.consumption,
      );

      await _pumpFoodSearch(
        tester: tester,
        harness: harness,
        recent: recent,
        mealType: 'breakfast',
        initialMultiSelect: true,
        coordinatorOverride: failingCoordinator,
      );

      await tester.tap(find.byType(Checkbox));
      await _settle(tester);

      expect(find.text('Add 1 food to breakfast'), findsOneWidget);

      // Attempt commit -> fails
      await tester.tap(find.text('Add 1 food to breakfast'));
      await _settle(tester);

      expect(failingCoordinator.batchCallCount, 1);
      expect(
        find.text('Foods could not be added together. Your selection is still here.'),
        findsOneWidget,
      );
      // Selection is preserved!
      expect(find.text('Add 1 food to breakfast'), findsOneWidget);
    });
  });

  group('R08D.5: Meal Section Visual Identity & Accessibility', () {
    testWidgets('DashboardMealSection renders distinctive icons and labels without color-only semantics', (tester) async {
      final harness = await _Harness.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        unawaited(harness.close());
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(harness.db),
            foodLogsForDayProvider.overrideWith((ref, date) async => []),
            canonicalFoodRecordsForDayProvider.overrideWith(
              (ref, date) async => [],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: DashboardMealSection(
                  logs: [],
                  selectedDate: null,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Meal titles present
      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Dinner'), findsOneWidget);
      expect(find.text('Snacks'), findsOneWidget);

      // Distinct icons present
      expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget); // Breakfast
      expect(find.byIcon(Icons.wb_twilight_rounded), findsOneWidget); // Lunch
      expect(find.byIcon(Icons.nightlight_round), findsOneWidget); // Dinner
      expect(find.byIcon(Icons.cookie_outlined), findsOneWidget); // Snacks
    });

    testWidgets('FoodSearchScreen multi-select renders cleanly at 320pt and 2x text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      final harness = await _Harness.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        unawaited(harness.close());
      });

      final option = (await tester.runAsync(() async {
        return harness.catalog.createUserFood(
          displayName: 'Poha with Peanuts and Coriander Garnish',
          servingSize: 1,
          servingUnit: 'plate',
          energyKcal: 260,
          proteinG: 5,
          carbohydrateG: 45,
          fatG: 7,
        );
      }))!;

      final recent = [
        CanonicalRecentFood(
          option: option,
          quantityLabel: '1 plate',
          loggedAtUtc: DateTime.utc(2026, 8, 24, 8, 0),
        ),
      ];

      await _pumpFoodSearch(
        tester: tester,
        harness: harness,
        recent: recent,
        mealType: 'breakfast',
        initialMultiSelect: true,
        themeOverride: AppTheme.darkTheme,
        textScale: 2.0,
      );

      expect(find.byType(Checkbox), findsOneWidget);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.text('Add 1 food to breakfast'), findsOneWidget);
    });
  });
}
