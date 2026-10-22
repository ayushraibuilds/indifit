import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart' show AppDatabase;
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_logging_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/data/repositories/nutrition_transformation_repository.dart';
import 'package:indifit/features/food_log/food_search_view_models.dart';
import 'package:indifit/features/food_log/widgets/logged_food_row.dart';
import 'package:indifit/features/nutrition_ai/ai_result_report.dart';
import 'package:indifit/features/nutrition_ai/natural_language_meal_service.dart';
import 'package:indifit/features/nutrition_ai/nutrition_ai_controllers.dart';

/// C-08, U-4, N14-09: unmatched AI items are one-off estimates, review rows
/// say where numbers come from, and the report mail carries names only.
const _unmatched = DecomposedFoodItem(
  rawSegment: 'ek katori ghar wali sabzi with extra ghee',
  foodName: 'Ghar ki sabzi',
  quantityAmount: 1,
  quantityUnit: 'katori',
  estimatedCalories: 120,
  estimatedProtein: 3,
  estimatedCarbs: 12,
  estimatedFat: 6,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NutritionFoodCatalogRepository catalog;
  late NutritionConsumptionRepository consumption;
  late NutritionFoodLoggingCoordinator coordinator;
  late NutritionReadModelRepository readModels;

  setUp(() {
    db = AppDatabase.memory();
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    catalog = NutritionFoodCatalogRepository(db: db, registry: registry);
    consumption = NutritionConsumptionRepository(db: db, registry: registry);
    coordinator = NutritionFoodLoggingCoordinator(
      db: db,
      registry: registry,
      catalog: catalog,
      calculator: const NutritionCalculationService(),
      consumption: consumption,
      transformations: NutritionTransformationRepository(db: db),
    );
    readModels = NutritionReadModelRepository(
      db: db,
      registry: registry,
      canonicalRepository: consumption,
    );
  });

  tearDown(() => db.close());

  Future<void> logUnmatched() => AiMealLogSession('ai-describe').logAll(
    items: const [_unmatched],
    catalog: catalog,
    coordinator: coordinator,
    userId: kLocalNutritionUserScopeId,
    mealType: 'lunch',
    date: DateTime.utc(2026, 10, 20, 7),
    timezoneId: 'Asia/Kolkata',
  );

  test(
    'an unmatched item creates no user food, only a tagged estimate',
    () async {
      await logUnmatched();

      final userFoods = await db
          .customSelect(
            "SELECT COUNT(*) AS c FROM nutrition_foods WHERE source_type = 'user'",
          )
          .getSingle();
      expect(userFoods.read<int>('c'), 0);

      final estimate = await db
          .customSelect(
            'SELECT id, kind, source_type FROM nutrition_foods '
            "WHERE display_name = 'Ghar ki sabzi'",
          )
          .getSingle();
      expect(estimate.read<String>('kind'), 'aiEstimate');
      expect(estimate.read<String>('source_type'), 'ai');

      final factSources = await db
          .customSelect(
            'SELECT DISTINCT source FROM nutrition_food_nutrient_facts '
            'WHERE food_id = ?',
            variables: [Variable.withString(estimate.read<String>('id'))],
          )
          .get();
      expect(factSources.map((row) => row.read<String>('source')), [
        'ai_estimate',
      ]);

      final history = await readModels.listHistory(
        userId: kLocalNutritionUserScopeId,
      );
      final item = history.single.items.single;
      expect(item.facts['energy']?.source, NutrientSourceType.aiEstimate);
      expect(isAiEstimateItem(item), isTrue);
    },
  );

  test('estimates stay out of search, My Foods and recents', () async {
    await logUnmatched();

    expect(
      (await catalog.search(query: 'ghar ki')).map((o) => o.displayName),
      isNot(contains('Ghar ki sabzi')),
    );
    expect(await catalog.searchCustomFoods(queries: ['ghar ki']), isEmpty);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        nutritionReadModelRepositoryProvider.overrideWith(
          (ref) async => readModels,
        ),
        nutritionFoodCatalogRepositoryProvider.overrideWith(
          (ref) async => catalog,
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(canonicalRecentFoodsProvider.future), isEmpty);
  });

  test('a user food is still found after the change', () async {
    await catalog.createUserFood(
      displayName: 'Ghar ki roti',
      servingSize: 1,
      servingUnit: 'roti',
      energyKcal: 80,
      proteinG: 2.5,
      carbohydrateG: 15,
      fatG: 0.8,
    );
    expect(
      (await catalog.search(query: 'ghar ki')).map((o) => o.displayName),
      contains('Ghar ki roti'),
    );
  });

  testWidgets('a logged estimate shows a small "Estimate" label', (
    tester,
  ) async {
    late List<NutritionHistoricalReadRecord> history;
    await tester.runAsync(() async {
      await logUnmatched();
      history = await readModels.listHistory(
        userId: kLocalNutritionUserScopeId,
      );
    });
    final record = history.single;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nutritionFoodCatalogRepositoryProvider.overrideWith(
            (ref) async => catalog,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: LoggedFoodRow(record: record, item: record.items.single),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Estimate'), findsOneWidget);
  });

  group('review source labels', () {
    test('an unmatched item is "Estimated by AI"', () {
      expect(aiItemSourceLabel(_unmatched), 'Estimated by AI');
    });

    test('a matched item names its catalogue food', () async {
      final dal = await catalog.createUserFood(
        displayName: 'Toor Dal Tadka',
        servingSize: 1,
        servingUnit: 'katori',
        energyKcal: 150,
        proteinG: 7,
        carbohydrateG: 20,
        fatG: 4,
      );
      final matched = _unmatched.copyWith(matchedCatalogOption: dal);
      expect(aiItemSourceLabel(matched), 'Matched: Toor Dal Tadka');
    });
  });

  test('the report mail holds only the allowed fields', () {
    final uri = aiResultReportEmail(
      feature: 'Describe a meal',
      items: const [
        (name: 'Toor dal', matchedName: 'Toor Dal Tadka'),
        (name: 'Ghar ki sabzi', matchedName: null),
      ],
      modelId: 'gemini-test-model',
      appVersion: '1.0.0 (12)',
    );
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'support@indifit.app');
    final body = Uri.decodeComponent(
      RegExp(r'body=([^&]*)').firstMatch(uri.query)!.group(1)!,
    );
    expect(body, contains('- Toor dal → Toor Dal Tadka'));
    expect(body, contains('- Ghar ki sabzi → no catalogue match'));
    expect(body, contains('Model: gemini-test-model'));
    expect(body, contains('App version: 1.0.0 (12)'));
    // Nothing else: no typed text, no images, no targets.
    final lines = body
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    expect(lines, [
      'Something was wrong with this AI result:',
      'Feature: Describe a meal',
      'Items:',
      '- Toor dal → Toor Dal Tadka',
      '- Ghar ki sabzi → no catalogue match',
      'Model: gemini-test-model',
      'App version: 1.0.0 (12)',
    ]);
    expect(body, isNot(contains(_unmatched.rawSegment)));
    expect(uri.toString(), isNot(contains('+')));
  });
}
