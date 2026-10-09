import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
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
import 'package:indifit/features/food_log/food_search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/widget_test_database.dart';

/// Regression for the 8 Oct simulator report: the "…" action sheet on a
/// logged food in the meal detail screen (and its delete dialog) appeared
/// over a "Log lunch" search screen. The detail screen used to push a fresh
/// FoodSearchScreen just to host the sheet; it now runs the actions in place.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('logged-food actions sheet and delete dialog sit over the '
      'meal detail screen', (tester) async {
    // iPhone 17 logical size, where the report came from.
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final database = AppDatabase.memory();
    addTearDown(() => closeWidgetTestDatabase(tester, database));
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
    );
    final readModels = NutritionReadModelRepository(
      db: database,
      registry: registry,
      canonicalRepository: consumption,
      legacyUserId: kLocalNutritionUserScopeId,
    );
    final coordinator = NutritionFoodLoggingCoordinator(
      db: database,
      registry: registry,
      catalog: catalog,
      calculator: const NutritionCalculationService(),
      consumption: consumption,
      transformations: NutritionTransformationRepository(db: database),
    );
    final day = DateTime(2026, 10, 8);

    await tester.runAsync(() async {
      final rice = await catalog.createUserFood(
        displayName: 'Jeera rice',
        servingSize: 1,
        servingUnit: 'serving',
        energyKcal: 210,
        proteinG: 4,
        carbohydrateG: 40,
        fatG: 4,
      );
      await coordinator.finalize(
        userId: kLocalNutritionUserScopeId,
        preview: await coordinator.preview(
          option: rice,
          quantity: rice.baseQuantity,
        ),
        mealCategory: 'lunch',
        loggedAt: DateTime.utc(2026, 10, 8, 7),
        localDate: '2026-10-08',
        timezoneId: 'Asia/Kolkata',
        commandId: 'detail-actions-command',
        consumptionId: 'detail-actions-consumption',
      );
    });

    final observer = _PushObserver();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          localTimezoneServiceProvider.overrideWithValue(
            LocalTimezoneService(read: () async => 'Asia/Kolkata'),
          ),
          nutritionRegistryProvider.overrideWith((ref) async => registry),
          nutritionFoodCatalogRepositoryProvider.overrideWith(
            (ref) async => catalog,
          ),
          nutritionConsumptionRepositoryProvider.overrideWith(
            (ref) async => consumption,
          ),
          nutritionReadModelRepositoryProvider.overrideWith(
            (ref) async => readModels,
          ),
          nutritionFoodLoggingCoordinatorProvider.overrideWith(
            (ref) async => coordinator,
          ),
          foodRepositoryProvider.overrideWithValue(_EmptyFoodRepo(database)),
          canonicalRecentFoodsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<bool>(
                        builder: (_) => FoodSearchScreen(
                          mealType: 'lunch',
                          selectedDate: day,
                        ),
                      ),
                    ),
                    child: const Text('Open lunch search'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FoodMealDetailScreen(
                          mealType: 'lunch',
                          selectedDate: day,
                        ),
                      ),
                    ),
                    child: const Text('Open lunch detail'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    // Visit "Log lunch" and back out, as in the simulator repro.
    await tester.tap(find.text('Open lunch search'));
    await settle();
    expect(find.text('Log lunch'), findsOneWidget);
    await tester.pageBack();
    await settle();
    expect(find.byType(FoodSearchScreen, skipOffstage: false), findsNothing);

    await tester.tap(find.text('Open lunch detail'));
    await settle();
    expect(find.byType(FoodMealDetailScreen), findsOneWidget);
    expect(find.text('Jeera rice'), findsOneWidget);
    final detailRoute = ModalRoute.of(
      tester.element(find.byType(FoodMealDetailScreen)),
    )!;

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await settle();

    // The sheet is pushed directly on top of the detail route, on the same
    // navigator, with no search screen anywhere in the stack.
    expect(find.text('Edit amount'), findsOneWidget);
    expect(find.byType(FoodSearchScreen, skipOffstage: false), findsNothing);
    final sheetRoute = ModalRoute.of(tester.element(find.text('Edit amount')))!;
    expect(sheetRoute, isA<ModalBottomSheetRoute<CanonicalFoodAction>>());
    expect(sheetRoute.isCurrent, isTrue);
    expect(observer.previousOf[sheetRoute], same(detailRoute));
    expect(sheetRoute.navigator, same(detailRoute.navigator));

    // On a phone the sheet is full width and its actions span it, instead of
    // wrapping at intrinsic width (B05ActionGroup's layout above 360pt).
    final sheetWidth = tester.getSize(find.byType(BottomSheet)).width;
    expect(sheetWidth, 402);
    for (final label in ['Edit amount', 'Copy food', 'Delete food']) {
      final button = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(tester.getSize(button.first).width, sheetWidth - 32);
    }

    // Tapping the barrier above the sheet lands back on the detail screen.
    await tester.tapAt(const Offset(20, 20));
    await settle();
    expect(find.text('Edit amount'), findsNothing);
    expect(detailRoute.isCurrent, isTrue);

    // Delete: the confirmation dialog also sits over the detail screen, and
    // confirming keeps the user there with the food removed.
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await settle();
    await tester.tap(find.text('Delete food'));
    await settle();
    expect(find.text('Delete this food?'), findsOneWidget);
    expect(find.byType(FoodSearchScreen, skipOffstage: false), findsNothing);
    final dialogRoute = ModalRoute.of(
      tester.element(find.text('Delete this food?')),
    )!;
    expect(dialogRoute, isA<DialogRoute<bool>>());
    expect(dialogRoute.navigator, same(detailRoute.navigator));

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle();
    expect(detailRoute.isCurrent, isTrue);
    expect(find.byType(FoodMealDetailScreen), findsOneWidget);
    expect(find.text('Jeera rice'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _PushObserver extends NavigatorObserver {
  final previousOf = <Route<dynamic>, Route<dynamic>?>{};

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    previousOf[route] = previousRoute;
  }
}

class _EmptyFoodRepo extends FoodRepository {
  _EmptyFoodRepo(super.database);

  @override
  Future<List<FoodItem>> getRecentFoods(int limit) async => const [];

  @override
  Future<List<FoodLog>> getLastLoggedMeal(String mealType) async => const [];
}
