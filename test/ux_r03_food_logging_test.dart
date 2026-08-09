import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/core/raw_cooked_transformations.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_api_service.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_logging_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_transformation_repository.dart';
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
      expect(find.bySemanticsLabel('Search foods'), findsOneWidget);
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
        ),
      );
      container = ProviderScope.containerOf(
        tester.element(find.byType(FoodSearchScreen)),
      );
      await _pumpFood(tester);

      expect(find.text('Roti'), findsOneWidget);
      expect(find.text('Recent'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Add'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Log to LUNCH'), findsOneWidget);
      expect(find.text('1 servings'), findsOneWidget);
      expect(find.text('Add Meal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(FoodSearchScreen)),
    );
    await _pumpFood(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Add'));
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
  double textScale = 1,
  required String mealType,
  required DateTime selectedDate,
}) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(database),
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
    canonicalRecentFoodsProvider.overrideWith((ref) async => const []),
    foodLogsForDayProvider.overrideWith((ref, date) async => []),
    canonicalFoodRecordsForDayProvider.overrideWith((ref, date) async => []),
  ],
  child: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: MaterialApp(
      theme: theme ?? AppTheme.darkTheme,
      builder: (context, child) => RepaintBoundary(
        key: const ValueKey('food_golden_root'),
        child: child ?? const SizedBox.shrink(),
      ),
      home: FoodSearchScreen(mealType: mealType, selectedDate: selectedDate),
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
  await tester.pump(const Duration(milliseconds: 500));
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
  Future<List<FoodApiResult>> searchOnline(String query) async => const [];
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
  _TestFoodCatalog(AppDatabase database, this.registry)
    : super(db: database, registry: registry);

  final NutrientRegistry registry;

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
      facts[definition.id] = value == null
          ? NutrientFact.missing(
              nutrientId: definition.id,
              unit: definition.unit,
              basis: NutrientBasis(
                NutrientBasisKind.perServing,
                servingDefinition: serving,
              ),
              source: NutrientSourceType.legacy,
              sourceReference: 'ux-r03-test:${item.name}',
            )
          : NutrientFact.known(
              nutrientId: definition.id,
              point: NutrientAmount(
                value: QuantityAmount.fromNum(value),
                unit: definition.unit,
              ),
              basis: NutrientBasis(
                NutrientBasisKind.perServing,
                servingDefinition: serving,
              ),
              source: NutrientSourceType.legacy,
              sourceReference: 'ux-r03-test:${item.name}',
            );
    }
    return NutritionFoodOption(
      id: 'ux-r03:${item.name.toLowerCase()}',
      displayName: item.name,
      baseQuantity: Quantity.serving(amount: '1', definition: serving),
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

  @override
  Future<List<NutritionTransformation>> transformationsFor(
    NutritionFoodOption option,
  ) async => const [];
}
