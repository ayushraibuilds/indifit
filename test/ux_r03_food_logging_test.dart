import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/core/raw_cooked_transformations.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart'
    hide NutritionConsumptionSnapshot;
import 'package:indifit/data/repositories/food_api_service.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_logging_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_transformation_repository.dart';
import 'package:indifit/features/dashboard/main_navigation_scaffold.dart';
import 'package:indifit/features/food_log/ai_meal_logger_screen.dart';
import 'package:indifit/features/food_log/food_log_surface.dart';
import 'package:indifit/features/food_log/food_search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'food entry starts with search and keeps secondary tools secondary',
    (tester) async {
      _setViewport(tester, const Size(320, 568));
      final database = AppDatabase.memory();
      final repository = _TestFoodRepository(database);
      late ProviderContainer container;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        container.dispose();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await database.close();
      });

      await tester.pumpWidget(
        _foodApp(
          database: database,
          repository: repository,
          theme: AppTheme.darkTheme,
          textScale: 2,
          mealType: 'breakfast',
          selectedDate: DateTime(2026, 8, 9),
        ),
      );
      container = ProviderScope.containerOf(
        tester.element(find.byType(FoodSearchScreen)),
      );
      await _pumpFood(tester);

      expect(find.text('Add breakfast'), findsOneWidget);
      expect(find.text('Search foods'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(FoodSearchScreen),
        matchesGoldenFile('goldens/ux_r03_food_landing_320_2x.png'),
      );
    },
  );

  testWidgets(
    'recent food keeps the selected meal context for quantity entry',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      final database = AppDatabase.memory();
      final repository = _TestFoodRepository(
        database,
        recent: const [
          FoodItem(
            id: -1,
            name: 'Roti',
            calories: 120,
            proteinG: 4,
            carbsG: 20,
            fatG: 2,
            servingSize: 1,
            servingUnit: 'piece',
            category: 'Recent',
            isCustom: false,
          ),
        ],
      );
      final registry = NutrientRegistry.fromAssetFileSync(
        'assets/data/nutrient_registry.json',
      );
      final catalog = _TestFoodCatalog(database, registry);
      final coordinator = _TestCoordinator(
        database: database,
        registry: registry,
        catalog: catalog,
      );
      late ProviderContainer container;
      final selectedDate = DateTime(2026, 8, 7);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        container.dispose();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await database.close();
      });

      await tester.pumpWidget(
        _foodApp(
          database: database,
          repository: repository,
          catalog: catalog,
          coordinator: coordinator,
          theme: AppTheme.lightTheme,
          mealType: 'lunch',
          selectedDate: selectedDate,
          mediaSize: const Size(390, 844),
        ),
      );
      container = ProviderScope.containerOf(
        tester.element(find.byType(FoodSearchScreen)),
      );
      await _pumpFood(tester);

      expect(find.text('Roti'), findsOneWidget);
      expect(find.text('Recent'), findsOneWidget);
      await tester.tap(find.text('Roti'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Log to LUNCH'), findsOneWidget);
      expect(find.text('servings'), findsOneWidget);
      expect(find.text('Add Meal'), findsOneWidget);
      final amountField = find.widgetWithText(TextField, 'Amount');
      await tester.enterText(amountField, '');
      await tester.pump();
      expect(
        find.text('Enter an amount to preview nutrition.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Add Meal'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.enterText(amountField, '0.5');
      await tester.pump();
      expect(coordinator.lastPreviewQuantity?.amount.toString(), '0.5');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('top-level Food opens neutral with keyboard closed', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    final database = AppDatabase.memory();
    final repository = _TestFoodRepository(database);
    late ProviderContainer container;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await database.close();
    });

    await tester.pumpWidget(
      _foodApp(
        database: database,
        repository: repository,
        mealType: null,
        selectedDate: DateTime(2026, 8, 9),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(FoodSearchScreen)),
    );
    await _pumpFood(tester);

    expect(find.text('Log breakfast'), findsNothing);
    expect(find.text('Add breakfast'), findsNothing);
    expect(find.text('Search foods'), findsNothing);
    expect(find.text('Add food'), findsWidgets);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Food Home pushes Add Lunch and Back restores the stable root', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    final database = AppDatabase.memory();
    late ProviderContainer container;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
      tester.view.reset();
      await database.close();
    });

    await tester.pumpWidget(
      _foodApp(
        database: database,
        repository: _TestFoodRepository(database),
        mealType: null,
        selectedDate: DateTime(2026, 8, 9),
        home: const MainNavigationScaffold(initialIndex: 2),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(MainNavigationScaffold)),
    );
    await _pumpFood(tester);

    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Add lunch'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Add Lunch'));
    await tester.pumpAndSettle();

    expect(find.text('Add lunch'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Add lunch'), findsNothing);
    expect(find.text('Add food'), findsWidgets);
    expect(find.text('Search foods'), findsNothing);
  });

  testWidgets('Food Home save returns from Add Lunch to the refreshed root', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    final database = AppDatabase.memory();
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    final catalog = _TestFoodCatalog(database, registry);
    final coordinator = _TestCoordinator(
      database: database,
      registry: registry,
      catalog: catalog,
    );
    late ProviderContainer container;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
      tester.view.reset();
      await database.close();
    });

    await tester.pumpWidget(
      _foodApp(
        database: database,
        repository: _TestFoodRepository(
          database,
          searchResults: const [
            FoodItem(
              id: 41,
              name: 'Lunch roti',
              calories: 120,
              proteinG: 4,
              carbsG: 20,
              fatG: 2,
              servingSize: 1,
              servingUnit: 'piece',
              category: 'Bread',
              isCustom: false,
            ),
          ],
        ),
        catalog: catalog,
        coordinator: coordinator,
        apiService: _TestFoodApiService(),
        mealType: null,
        selectedDate: DateTime(2026, 8, 9),
        home: const MainNavigationScaffold(initialIndex: 2),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(MainNavigationScaffold)),
    );
    await _pumpFood(tester);
    await tester.tap(find.bySemanticsLabel('Add Lunch'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'roti');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    await tester.tap(find.text('Lunch roti'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 250));
    Navigator.of(
      tester.element(
        find.byKey(const ValueKey('food_quantity_review_surface')),
      ),
    ).pop(true);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Add lunch'), findsNothing);
    expect(find.text('Add food'), findsWidgets);
    expect(find.text('Search foods'), findsNothing);
    expect(coordinator.lastPreviewQuantity, isNotNull);
  });

  testWidgets('mass-authority foods expose canonical mass units', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    final database = AppDatabase.memory();
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    final catalog = _TestFoodCatalog(database, registry, massAuthority: true);
    final coordinator = _TestCoordinator(
      database: database,
      registry: registry,
      catalog: catalog,
    );
    late ProviderContainer container;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await database.close();
    });

    await tester.pumpWidget(
      _foodApp(
        database: database,
        repository: _TestFoodRepository(
          database,
          recent: const [
            FoodItem(
              id: -3,
              name: 'Mass authority food',
              calories: 120,
              proteinG: 4,
              carbsG: 20,
              fatG: 2,
              servingSize: 100,
              servingUnit: 'g',
              category: 'Recent',
              isCustom: false,
            ),
          ],
        ),
        catalog: catalog,
        coordinator: coordinator,
        mealType: 'breakfast',
        selectedDate: DateTime(2026, 8, 9),
        mediaSize: const Size(390, 844),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(FoodSearchScreen)),
    );
    await _pumpFood(tester);

    await tester.tap(find.text('Mass authority food'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    final unitDropdown = find.byType(DropdownButton<QuantityUnit>);
    expect(unitDropdown, findsOneWidget);
    await tester.dragUntilVisible(
      unitDropdown,
      find.byType(SingleChildScrollView).last,
      const Offset(0, -120),
    );
    await tester.tap(unitDropdown);
    await tester.pump();
    expect(find.text('kg'), findsOneWidget);
    expect(find.text('servings'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('canonical recent history displaces legacy fallback', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    final database = AppDatabase.memory();
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    final catalog = _TestFoodCatalog(database, registry);
    final option = await catalog.ensureLegacyFood(
      const FoodItem(
        id: -1,
        name: 'Canonical dal',
        calories: 210,
        proteinG: 12,
        carbsG: 30,
        fatG: 5,
        servingSize: 1,
        servingUnit: 'katori',
        category: 'Recent',
        isCustom: false,
      ),
    );
    final repository = _TestFoodRepository(
      database,
      recent: const [
        FoodItem(
          id: -2,
          name: 'Legacy fallback only',
          calories: 100,
          proteinG: 2,
          carbsG: 10,
          fatG: 1,
          servingSize: 1,
          servingUnit: 'piece',
          category: 'Recent',
          isCustom: false,
        ),
      ],
    );
    late ProviderContainer container;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await database.close();
    });
    await tester.pumpWidget(
      _foodApp(
        database: database,
        repository: repository,
        canonicalRecent: [
          CanonicalRecentFood(
            option: option,
            quantityLabel: '1 katori',
            loggedAtUtc: DateTime(2026, 8, 9).toUtc(),
          ),
        ],
        mealType: 'dinner',
        selectedDate: DateTime(2026, 8, 9),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(FoodSearchScreen)),
    );
    await _pumpFood(tester);
    expect(find.text('Canonical dal'), findsOneWidget);
    expect(find.text('Legacy fallback only'), findsNothing);
  });

  testWidgets('local search results appear before online search completes', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    final database = AppDatabase.memory();
    final online = _DelayedFoodApiService();
    late ProviderContainer container;
    addTearDown(() async {
      if (!online.completer.isCompleted) online.completer.complete(const []);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await database.close();
    });
    await tester.pumpWidget(
      _foodApp(
        database: database,
        repository: _TestFoodRepository(
          database,
          searchResults: const [
            FoodItem(
              id: 1,
              name: 'Offline roti',
              calories: 120,
              proteinG: 4,
              carbsG: 20,
              fatG: 2,
              servingSize: 1,
              servingUnit: 'piece',
              category: 'Local',
              isCustom: false,
            ),
          ],
        ),
        apiService: online,
        mealType: 'breakfast',
        selectedDate: DateTime(2026, 8, 9),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(FoodSearchScreen)),
    );
    await _pumpFood(tester);
    await tester.enterText(find.byType(TextField).first, 'roti');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(find.text('Offline roti'), findsOneWidget);
    expect(find.text('Searching more foods'), findsOneWidget);
    online.completer.complete(const []);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Offline roti'), findsOneWidget);
  });

  testWidgets('changed query cancels transport and stale results cannot win', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    final database = AppDatabase.memory();
    final online = _MultiQueryFoodApiService();
    late ProviderContainer container;
    addTearDown(() async {
      online.completeOutstanding();
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      tester.view.reset();
      await database.close();
    });
    await tester.pumpWidget(
      _foodApp(
        database: database,
        repository: _TestFoodRepository(database),
        apiService: online,
        mealType: 'breakfast',
        selectedDate: DateTime(2026, 8, 9),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(FoodSearchScreen)),
    );
    await _pumpFood(tester);

    await tester.enterText(find.byType(TextField).first, 'first');
    await tester.pump(const Duration(milliseconds: 800));
    expect(online.completers, contains('first'));
    await tester.enterText(find.byType(TextField).first, 'second');
    expect(online.tokens['first']!.isCancelled, isTrue);
    await tester.pump(const Duration(milliseconds: 800));
    online.completers['second']!.complete([
      FoodApiResult(
        name: 'Second result',
        calories: 100,
        protein: 10,
        carbs: 5,
        fat: 2,
        servingSize: 100,
        servingUnit: 'g',
      ),
    ]);
    await tester.pump();
    online.completers['first']!.complete([
      FoodApiResult(
        name: 'Stale first result',
        calories: 100,
        protein: 10,
        carbs: 5,
        fat: 2,
        servingSize: 100,
        servingUnit: 'g',
      ),
    ]);
    await tester.pump();

    expect(find.text('Second result'), findsOneWidget);
    expect(find.text('Stale first result'), findsNothing);
  });

  testWidgets('remote provider results remain distinct from local foods', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    final database = AppDatabase.memory();
    late ProviderContainer container;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      tester.view.reset();
      await database.close();
    });
    await tester.pumpWidget(
      _foodApp(
        database: database,
        repository: _TestFoodRepository(database),
        apiService: _SuccessfulFoodApiService(),
        mealType: 'breakfast',
        selectedDate: DateTime(2026, 8, 12),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(FoodSearchScreen)),
    );
    await _pumpFood(tester);

    await tester.enterText(find.byType(TextField).first, 'protein shake');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();

    expect(find.text('Provider protein shake'), findsOneWidget);
    expect(find.text('More results'), findsOneWidget);
    expect(find.text('Foods on this device'), findsNothing);
  });

  testWidgets('HTTP failure keeps local food usable with quiet fallback', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    final database = AppDatabase.memory();
    late ProviderContainer container;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      tester.view.reset();
      await database.close();
    });
    await tester.pumpWidget(
      _foodApp(
        database: database,
        repository: _TestFoodRepository(
          database,
          searchResults: const [
            FoodItem(
              id: 9,
              name: 'Local protein smoothie',
              calories: 180,
              proteinG: 18,
              carbsG: 20,
              fatG: 3,
              servingSize: 1,
              servingUnit: 'glass',
              category: 'Local',
              isCustom: false,
            ),
          ],
        ),
        apiService: _HttpFailureFoodApiService(),
        mealType: 'breakfast',
        selectedDate: DateTime(2026, 8, 12),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(FoodSearchScreen)),
    );
    await _pumpFood(tester);

    await tester.enterText(find.byType(TextField).first, 'protein');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();

    expect(find.text('Local protein smoothie'), findsOneWidget);
    expect(find.text('Showing available results'), findsOneWidget);
    expect(find.text('Online search unavailable'), findsNothing);
  });

  testWidgets('AI completion unwinds the food entry route to its caller', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 2000));
    final database = AppDatabase.memory();
    late ProviderContainer container;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await database.close();
    });
    await tester.pumpWidget(
      _foodApp(
        database: database,
        repository: _TestFoodRepository(database),
        mealType: 'breakfast',
        selectedDate: DateTime(2026, 8, 9),
        home: const _FoodRouteHarness(),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(_FoodRouteHarness)),
    );
    unawaited(
      tester
          .state<_FoodRouteHarnessState>(find.byType(_FoodRouteHarness))
          .openFoodFlow(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(FoodSearchScreen), findsOneWidget);
    tester.testTextInput.hide();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Describe with AI'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Describe with AI'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.byType(AiMealLoggerScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(AiMealLoggerScreen))).pop(true);
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Saved result'), findsOneWidget);
    expect(find.byType(FoodSearchScreen), findsNothing);
  });

  testWidgets('recent and saved landing state golden', (tester) async {
    _setViewport(tester, const Size(390, 844));
    final database = AppDatabase.memory();
    final repository = _TestFoodRepository(
      database,
      recent: const [
        FoodItem(
          id: -1,
          name: 'Roti',
          calories: 120,
          proteinG: 4,
          carbsG: 20,
          fatG: 2,
          servingSize: 1,
          servingUnit: 'piece',
          category: 'Recent',
          isCustom: false,
        ),
      ],
    );
    late ProviderContainer container;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await database.close();
    });

    await tester.pumpWidget(
      _foodApp(
        database: database,
        repository: repository,
        theme: AppTheme.darkTheme,
        mealType: 'lunch',
        selectedDate: DateTime(2026, 8, 9),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(FoodSearchScreen)),
    );
    await _pumpFood(tester);
    expect(find.text('Saved recipes'), findsOneWidget);
    expect(find.text('Roti'), findsOneWidget);
    await expectLater(
      find.byType(FoodSearchScreen),
      matchesGoldenFile('goldens/ux_r03_food_recent_saved_dark.png'),
    );
  });

  testWidgets('search results dark golden', (tester) async {
    await _pumpSearchGolden(tester, theme: AppTheme.darkTheme);
    await expectLater(
      find.byType(FoodSearchScreen),
      matchesGoldenFile('goldens/ux_r03_food_search_dark.png'),
    );
  });

  testWidgets('search results light golden', (tester) async {
    await _pumpSearchGolden(tester, theme: AppTheme.lightTheme);
    await expectLater(
      find.byType(FoodSearchScreen),
      matchesGoldenFile('goldens/ux_r03_food_search_light.png'),
    );
  });

  testWidgets('AI description state golden', (tester) async {
    await _pumpAiGolden(tester, theme: AppTheme.darkTheme);
    expect(find.text('Describe your meal'), findsOneWidget);
    await expectLater(
      find.byType(AiMealLoggerScreen),
      matchesGoldenFile('goldens/ux_r03_food_ai_description_dark.png'),
    );
  });

  testWidgets('AI failure keeps fallback golden', (tester) async {
    SharedPreferences.setMockInitialValues({'offline_only': false});
    final prefs = await SharedPreferences.getInstance();
    final dio = Dio()..httpClientAdapter = _FailingDioAdapter();
    _setViewport(tester, const Size(390, 844));
    final database = AppDatabase.memory();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await database.close();
      dio.close(force: true);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          foodLogsForDayProvider.overrideWith((ref, date) async => []),
          privacyPolicyProvider.overrideWith(
            (ref) => PrivacyPolicyNotifier(prefs),
          ),
          dioProvider.overrideWithValue(dio),
        ],
        child: MediaQuery(
          data: const MediaQueryData(),
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: AiMealLoggerScreen(
              mealType: 'dinner',
              selectedDate: DateTime(2026, 8, 9),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '2 rotis with paneer');
    await tester.pump();
    await tester.ensureVisible(find.text('Estimate nutrition'));
    await tester.tap(find.text('Estimate nutrition'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.textContaining('AI estimate isn’t available right now'),
      findsOneWidget,
    );
    expect(find.text('Search foods instead'), findsOneWidget);
    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await expectLater(
      find.byType(AiMealLoggerScreen),
      matchesGoldenFile('goldens/ux_r03_food_ai_failure_dark.png'),
    );
  });

  testWidgets('quantity and review state golden', (tester) async {
    _setViewport(tester, const Size(390, 844));
    final database = AppDatabase.memory();
    final repository = _TestFoodRepository(
      database,
      recent: const [
        FoodItem(
          id: -1,
          name: 'Roti',
          calories: 120,
          proteinG: 4,
          carbsG: 20,
          fatG: 2,
          servingSize: 1,
          servingUnit: 'piece',
          category: 'Recent',
          isCustom: false,
        ),
      ],
    );
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    final catalog = _TestFoodCatalog(database, registry);
    final coordinator = _TestCoordinator(
      database: database,
      registry: registry,
      catalog: catalog,
    );
    late ProviderContainer container;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await database.close();
    });

    await tester.pumpWidget(
      _foodApp(
        database: database,
        repository: repository,
        catalog: catalog,
        coordinator: coordinator,
        theme: AppTheme.darkTheme,
        mealType: 'breakfast',
        selectedDate: DateTime(2026, 8, 9),
        mediaSize: const Size(390, 844),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(FoodSearchScreen)),
    );
    await _pumpFood(tester);
    await tester.tap(find.text('Roti'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Log to BREAKFAST'), findsOneWidget);
    await expectLater(
      find.byKey(const ValueKey('food_quantity_review_surface')),
      matchesGoldenFile('goldens/ux_r03_food_quantity_review_dark.png'),
    );
  });

  testWidgets('food landing dark golden', (tester) async {
    _setViewport(tester, const Size(390, 844));
    final database = AppDatabase.memory();
    final repository = _TestFoodRepository(database);
    late ProviderContainer container;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await database.close();
    });
    await tester.pumpWidget(
      _foodApp(
        database: database,
        repository: repository,
        theme: AppTheme.darkTheme,
        mealType: 'breakfast',
        selectedDate: DateTime(2026, 8, 9),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(FoodSearchScreen)),
    );
    await _pumpFood(tester);
    await expectLater(
      find.byType(FoodSearchScreen),
      matchesGoldenFile('goldens/ux_r03_food_landing_dark.png'),
    );
  });

  testWidgets('food landing light golden', (tester) async {
    _setViewport(tester, const Size(390, 844));
    final database = AppDatabase.memory();
    final repository = _TestFoodRepository(database);
    late ProviderContainer container;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await database.close();
    });
    await tester.pumpWidget(
      _foodApp(
        database: database,
        repository: repository,
        theme: AppTheme.lightTheme,
        mealType: 'breakfast',
        selectedDate: DateTime(2026, 8, 9),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(FoodSearchScreen)),
    );
    await _pumpFood(tester);
    await expectLater(
      find.byType(FoodSearchScreen),
      matchesGoldenFile('goldens/ux_r03_food_landing_light.png'),
    );
  });
}

Widget _foodApp({
  required AppDatabase database,
  ThemeData? theme,
  FoodRepository? repository,
  NutritionFoodCatalogRepository? catalog,
  NutritionFoodLoggingCoordinator? coordinator,
  FoodApiService? apiService,
  List<CanonicalRecentFood> canonicalRecent = const [],
  double textScale = 1,
  Size? mediaSize,
  required String? mealType,
  required DateTime selectedDate,
  Widget? home,
}) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(database),
    localTimezoneServiceProvider.overrideWithValue(
      LocalTimezoneService(read: () async => 'Asia/Kolkata'),
    ),
    nutritionRegistryProvider.overrideWith(
      (ref) async => NutrientRegistry.fromAssetFileSync(
        'assets/data/nutrient_registry.json',
      ),
    ),
    if (catalog != null)
      nutritionFoodCatalogRepositoryProvider.overrideWith(
        (ref) async => catalog,
      ),
    if (coordinator != null)
      nutritionFoodLoggingCoordinatorProvider.overrideWith(
        (ref) async => coordinator,
      ),
    foodRepositoryProvider.overrideWithValue(
      repository ?? FoodRepository(database),
    ),
    if (apiService != null)
      foodApiServiceProvider.overrideWithValue(apiService),
    canonicalRecentFoodsProvider.overrideWith((ref) async => canonicalRecent),
    foodLogsForDayProvider.overrideWith((ref, date) async => []),
    canonicalFoodRecordsForDayProvider.overrideWith((ref, date) async => []),
    foodDiaryReadModelProvider.overrideWith((ref, date) async {
      final registry = await ref.watch(nutritionRegistryProvider.future);
      final totals = NutrientAggregationService.aggregate(
        registry: registry,
        contributions: const <NutrientContribution>[],
        requestedNutrientIds: registry.definitions
            .map((definition) => definition.id)
            .toSet(),
      );
      final localDate =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      return FoodDiaryReadModel(
        daily: NutritionDailyReadModel(
          userId: kLocalNutritionUserScopeId,
          localDate: localDate,
          records: const [],
          recordIds: const [],
          totals: totals,
          sourceCounts: const {},
          issues: const [],
        ),
      );
    }),
  ],
  child: MediaQuery(
    data: MediaQueryData(
      size: mediaSize ?? Size.zero,
      textScaler: TextScaler.linear(textScale),
    ),
    child: MaterialApp(
      theme: theme ?? AppTheme.darkTheme,
      builder: (context, child) => RepaintBoundary(
        key: const ValueKey('food_golden_root'),
        child: child ?? const SizedBox.shrink(),
      ),
      home:
          home ??
          FoodSearchScreen(mealType: mealType, selectedDate: selectedDate),
    ),
  ),
);

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
}

Future<void> _pumpSearchGolden(
  WidgetTester tester, {
  required ThemeData theme,
}) async {
  _setViewport(tester, const Size(390, 844));
  final database = AppDatabase.memory();
  final repository = _TestFoodRepository(
    database,
    searchResults: const [
      FoodItem(
        id: 1,
        name: 'Paneer bhurji with capsicum',
        calories: 285,
        proteinG: 18,
        carbsG: 9,
        fatG: 19,
        servingSize: 1,
        servingUnit: 'katori',
        category: 'Indian',
        isCustom: false,
      ),
      FoodItem(
        id: 2,
        name: 'Roti',
        calories: 120,
        proteinG: 4,
        carbsG: 20,
        fatG: 2,
        servingSize: 1,
        servingUnit: 'piece',
        category: 'Indian',
        isCustom: false,
      ),
    ],
  );
  late ProviderContainer container;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await database.close();
  });
  await tester.pumpWidget(
    _foodApp(
      database: database,
      repository: repository,
      apiService: _TestFoodApiService(),
      theme: theme,
      mealType: 'breakfast',
      selectedDate: DateTime(2026, 8, 9),
    ),
  );
  container = ProviderScope.containerOf(
    tester.element(find.byType(FoodSearchScreen)),
  );
  await _pumpFood(tester);
  await tester.enterText(find.byType(TextField), 'paneer');
  await tester.pump(const Duration(milliseconds: 800));
  expect(find.text('Paneer bhurji with capsicum'), findsOneWidget);
  expect(tester.takeException(), isNull);
}

Future<void> _pumpAiGolden(
  WidgetTester tester, {
  required ThemeData theme,
}) async {
  _setViewport(tester, const Size(390, 844));
  final database = AppDatabase.memory();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await database.close();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        foodLogsForDayProvider.overrideWith((ref, date) async => []),
      ],
      child: MediaQuery(
        data: const MediaQueryData(),
        child: MaterialApp(
          theme: theme,
          home: AiMealLoggerScreen(
            mealType: 'breakfast',
            selectedDate: DateTime(2026, 8, 9),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _pumpFood(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

class _TestFoodRepository extends FoodRepository {
  // ignore: use_super_parameters
  _TestFoodRepository(
    AppDatabase database, {
    this.recent = const [],
    this.searchResults = const [],
  }) : super(database);

  final List<FoodItem> recent;
  final List<FoodItem> searchResults;

  @override
  Future<List<FoodItem>> getRecentFoods(int limit) async => recent;

  @override
  Future<List<FoodItem>> searchFoodLocal(String query) async => searchResults;
}

class _TestFoodApiService extends FoodApiService {
  _TestFoodApiService();

  @override
  Future<List<FoodApiResult>> searchOnline(
    String query, {
    CancelToken? cancelToken,
  }) async => const [];
}

class _SuccessfulFoodApiService extends FoodApiService {
  @override
  Future<List<FoodApiResult>> searchOnline(
    String query, {
    CancelToken? cancelToken,
  }) async => [
    FoodApiResult(
      name: 'Provider protein shake',
      calories: 120,
      protein: 20,
      carbs: 6,
      fat: 2,
      servingSize: 330,
      servingUnit: 'g',
      barcode: 'provider-123',
    ),
  ];
}

class _HttpFailureFoodApiService extends FoodApiService {
  @override
  Future<List<FoodApiResult>> searchOnline(
    String query, {
    CancelToken? cancelToken,
  }) {
    final request = RequestOptions(path: kOpenFoodFactsSearchUrl);
    throw DioException(
      requestOptions: request,
      response: Response<void>(requestOptions: request, statusCode: 503),
      type: DioExceptionType.badResponse,
    );
  }
}

class _DelayedFoodApiService extends FoodApiService {
  final Completer<List<FoodApiResult>> completer = Completer();

  @override
  Future<List<FoodApiResult>> searchOnline(
    String query, {
    CancelToken? cancelToken,
  }) => completer.future;
}

class _MultiQueryFoodApiService extends FoodApiService {
  final Map<String, Completer<List<FoodApiResult>>> completers = {};
  final Map<String, CancelToken> tokens = {};

  @override
  Future<List<FoodApiResult>> searchOnline(
    String query, {
    CancelToken? cancelToken,
  }) {
    tokens[query] = cancelToken!;
    return (completers[query] ??= Completer<List<FoodApiResult>>()).future;
  }

  void completeOutstanding() {
    for (final completer in completers.values) {
      if (!completer.isCompleted) completer.complete(const []);
    }
  }
}

class _FoodRouteHarness extends StatefulWidget {
  const _FoodRouteHarness();

  @override
  State<_FoodRouteHarness> createState() => _FoodRouteHarnessState();
}

class _FoodRouteHarnessState extends State<_FoodRouteHarness> {
  var saved = false;

  Future<void> openFoodFlow() async {
    final result = await Navigator.of(context).push<bool?>(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          mealType: 'breakfast',
          selectedDate: DateTime(2026, 8, 9),
        ),
      ),
    );
    if (mounted && result == true) setState(() => saved = true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: saved
          ? const Text('Saved result')
          : FilledButton(
              onPressed: openFoodFlow,
              child: const Text('Open food flow'),
            ),
    ),
  );
}

class _FailingDioAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'UX-R3 test failure',
    );
  }

  @override
  void close({bool force = false}) {}
}

class _TestFoodCatalog extends NutritionFoodCatalogRepository {
  // ignore: use_super_parameters
  _TestFoodCatalog(
    AppDatabase database,
    this.registry, {
    this.massAuthority = false,
  }) : super(db: database, registry: registry);

  final NutrientRegistry registry;
  final bool massAuthority;

  @override
  Future<NutritionFoodOption> ensureLegacyFood(FoodItem item) async {
    final serving = const ServingDefinitionReference(
      id: 'test-serving',
      revision: '1',
      source: 'ux-r03-test',
    );
    final values = <String, double>{
      'energy': item.calories.toDouble(),
      'protein': item.proteinG,
      'carbohydrate': item.carbsG,
      'fat': item.fatG,
    };
    final facts = <String, NutrientFact>{};
    for (final definition in registry.definitions) {
      final value = values[definition.id];
      final basis = massAuthority
          ? NutrientBasis(NutrientBasisKind.per100Grams)
          : NutrientBasis(
              NutrientBasisKind.perServing,
              servingDefinition: serving,
            );
      facts[definition.id] = value == null
          ? NutrientFact.missing(
              nutrientId: definition.id,
              unit: definition.unit,
              basis: basis,
              source: NutrientSourceType.legacy,
              sourceReference: 'ux-r03-test:${item.name}',
            )
          : NutrientFact.known(
              nutrientId: definition.id,
              point: NutrientAmount(
                value: QuantityAmount.fromNum(value),
                unit: definition.unit,
              ),
              basis: basis,
              source: NutrientSourceType.legacy,
              sourceReference: 'ux-r03-test:${item.name}',
            );
    }
    return NutritionFoodOption(
      id: 'ux-r03:${item.name.toLowerCase()}',
      displayName: item.name,
      baseQuantity: massAuthority
          ? Quantity.fromDecimal(amount: '100', unit: QuantityUnit.gram)
          : Quantity.serving(amount: '1', definition: serving),
      facts: facts,
      sourceType: 'legacy',
      sourceReference: 'ux-r03-test:${item.name}',
      preparationId: null,
    );
  }
}

class _TestCoordinator extends NutritionFoodLoggingCoordinator {
  // ignore: use_super_parameters
  _TestCoordinator({
    required AppDatabase database,
    required NutrientRegistry registry,
    required NutritionFoodCatalogRepository catalog,
  }) : super(
         db: database,
         registry: registry,
         catalog: catalog,
         calculator: const NutritionCalculationService(),
         consumption: NutritionConsumptionRepository(
           db: database,
           registry: registry,
         ),
         transformations: NutritionTransformationRepository(db: database),
       );

  Quantity? lastPreviewQuantity;

  @override
  Future<NutritionFoodLogPreview> preview({
    required NutritionFoodOption option,
    required Quantity quantity,
    NutritionTransformation? transformation,
  }) {
    lastPreviewQuantity = quantity;
    return super.preview(
      option: option,
      quantity: quantity,
      transformation: transformation,
    );
  }

  @override
  Future<List<NutritionTransformation>> transformationsFor(
    NutritionFoodOption option,
  ) async => const [];
}
