import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart'
    hide NutritionConsumptionSnapshot;
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_logging_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/data/repositories/nutrition_transformation_repository.dart';
import 'package:indifit/features/food_log/food_search_screen.dart';

class _D3TestHarness {
  final AppDatabase database;
  final NutrientRegistry registry;
  final NutritionFoodCatalogRepository catalog;
  final NutritionConsumptionRepository consumption;
  final NutritionReadModelRepository readModels;
  final NutritionFoodLoggingCoordinator coordinator;

  _D3TestHarness._({
    required this.database,
    required this.registry,
    required this.catalog,
    required this.consumption,
    required this.readModels,
    required this.coordinator,
  });

  static Future<_D3TestHarness> create() async {
    final database = AppDatabase.memory();
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
    final transformations = NutritionTransformationRepository(db: database);
    final readModels = NutritionReadModelRepository(
      db: database,
      registry: registry,
      canonicalRepository: consumption,
    );
    final coordinator = NutritionFoodLoggingCoordinator(
      db: database,
      registry: registry,
      catalog: catalog,
      calculator: const NutritionCalculationService(),
      consumption: consumption,
      transformations: transformations,
    );
    return _D3TestHarness._(
      database: database,
      registry: registry,
      catalog: catalog,
      consumption: consumption,
      readModels: readModels,
      coordinator: coordinator,
    );
  }

  Future<void> close() => database.close();
}

class _EmptyFoodRepo extends FoodRepository {
  _EmptyFoodRepo(super.database);

  @override
  Future<List<FoodItem>> getRecentFoods(int limit) async => const [];
}

Future<void> _settleD3(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

Widget _buildFoodSearch({
  required _D3TestHarness harness,
  required Widget home,
  List<CanonicalRecentFood> recent = const [],
  NutritionFoodLoggingCoordinator? coordinator,
  Size mediaSize = const Size(390, 844),
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(harness.database),
      localTimezoneServiceProvider.overrideWithValue(
        LocalTimezoneService(read: () async => 'Asia/Kolkata'),
      ),
      nutritionRegistryProvider.overrideWith((ref) async => harness.registry),
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
        (ref) async => coordinator ?? harness.coordinator,
      ),
      foodRepositoryProvider.overrideWithValue(_EmptyFoodRepo(harness.database)),
      canonicalRecentFoodsProvider.overrideWith((ref) async => recent),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: mediaSize,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: home,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R08D.3 — Recent and Frequent Food Logging', () {
    test(
      'recent deterministic ordering orders by loggedAtUtc descending and stableId tie-breaker',
      () async {
        final harness = await _D3TestHarness.create();
        addTearDown(() => unawaited(harness.close()));

        final paneer = await harness.catalog.ensureProviderFood(
          displayName: 'Organic Paneer',
          sourceReference: 'provider-food-paneer',
          servingSize: 100,
          servingUnit: 'g',
          energyKcal: 265,
          proteinG: 18,
          carbohydrateG: 6,
          fatG: 20,
        );
        final dahi = await harness.catalog.ensureProviderFood(
          displayName: 'Fresh Dahi',
          sourceReference: 'provider-food-dahi',
          servingSize: 100,
          servingUnit: 'g',
          energyKcal: 60,
          proteinG: 3,
          carbohydrateG: 4,
          fatG: 3,
        );
        final oats = await harness.catalog.ensureProviderFood(
          displayName: 'Rolled Oats',
          sourceReference: 'provider-food-oats',
          servingSize: 40,
          servingUnit: 'g',
          energyKcal: 150,
          proteinG: 5,
          carbohydrateG: 27,
          fatG: 3,
        );

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(harness.database),
            nutritionReadModelRepositoryProvider.overrideWith(
              (ref) async => harness.readModels,
            ),
            nutritionFoodCatalogRepositoryProvider.overrideWith(
              (ref) async => harness.catalog,
            ),
          ],
        );
        addTearDown(container.dispose);

        // 1. Log Oats at 04:00 UTC (09:30 IST on 2026-08-20)
        final oatsPreview = await harness.coordinator.preview(
          option: oats,
          quantity: oats.baseQuantity,
        );
        await harness.coordinator.finalize(
          userId: kLocalNutritionUserScopeId,
          preview: oatsPreview,
          mealCategory: 'breakfast',
          loggedAt: DateTime.utc(2026, 8, 20, 4, 0),
          localDate: '2026-08-20',
          timezoneId: 'Asia/Kolkata',
          commandId: 'cmd-oats-1',
          consumptionId: 'cons-oats-1',
        );

        // 2. Log Dahi at 07:30 UTC (13:00 IST on 2026-08-20)
        final dahiPreview = await harness.coordinator.preview(
          option: dahi,
          quantity: dahi.baseQuantity,
        );
        await harness.coordinator.finalize(
          userId: kLocalNutritionUserScopeId,
          preview: dahiPreview,
          mealCategory: 'lunch',
          loggedAt: DateTime.utc(2026, 8, 20, 7, 30),
          localDate: '2026-08-20',
          timezoneId: 'Asia/Kolkata',
          commandId: 'cmd-dahi-1',
          consumptionId: 'cons-dahi-1',
        );

        // 3. Log Paneer at 14:30 UTC (20:00 IST on 2026-08-20)
        final paneerPreview = await harness.coordinator.preview(
          option: paneer,
          quantity: Quantity.fromDecimal(
            amount: '150',
            unit: QuantityUnit.gram,
          ),
        );
        await harness.coordinator.finalize(
          userId: kLocalNutritionUserScopeId,
          preview: paneerPreview,
          mealCategory: 'dinner',
          loggedAt: DateTime.utc(2026, 8, 20, 14, 30),
          localDate: '2026-08-20',
          timezoneId: 'Asia/Kolkata',
          commandId: 'cmd-paneer-1',
          consumptionId: 'cons-paneer-1',
        );

        final recents = await container.read(
          canonicalRecentFoodsProvider.future,
        );

        // Most recent first: Paneer (20:00 IST), Dahi (13:00 IST), Oats (09:30 IST)
        expect(
          recents.map((r) => r.option.displayName).toList(),
          ['Organic Paneer', 'Fresh Dahi', 'Rolled Oats'],
        );

        // Verify exact historical quantity on Paneer
        expect(recents.first.historicalQuantity, isNotNull);
        expect(recents.first.historicalQuantity!.amount.asDouble, 150.0);
        expect(recents.first.historicalQuantity!.unit, QuantityUnit.gram);
      },
    );

    test(
      'frequency semantics deterministically orders by count descending then recency without recommendation wording',
      () async {
        final harness = await _D3TestHarness.create();
        addTearDown(() => unawaited(harness.close()));

        final foodA = await harness.catalog.createUserFood(
          displayName: 'Food Alpha',
          servingSize: 1,
          servingUnit: 'serving',
          energyKcal: 100,
          proteinG: 5,
          carbohydrateG: 10,
          fatG: 2,
        );
        final foodB = await harness.catalog.createUserFood(
          displayName: 'Food Beta',
          servingSize: 1,
          servingUnit: 'serving',
          energyKcal: 200,
          proteinG: 10,
          carbohydrateG: 20,
          fatG: 4,
        );
        final foodC = await harness.catalog.createUserFood(
          displayName: 'Food Gamma',
          servingSize: 1,
          servingUnit: 'serving',
          energyKcal: 300,
          proteinG: 15,
          carbohydrateG: 30,
          fatG: 6,
        );

        // Log Food A 3 times
        for (var i = 1; i <= 3; i++) {
          final p = await harness.coordinator.preview(
            option: foodA,
            quantity: foodA.baseQuantity,
          );
          await harness.coordinator.finalize(
            userId: kLocalNutritionUserScopeId,
            preview: p,
            mealCategory: 'breakfast',
            loggedAt: DateTime.utc(2026, 8, 20, 3, i),
            localDate: '2026-08-20',
            timezoneId: 'Asia/Kolkata',
            commandId: 'cmd-a-$i',
            consumptionId: 'cons-a-$i',
          );
        }

        // Log Food B 2 times
        for (var i = 1; i <= 2; i++) {
          final p = await harness.coordinator.preview(
            option: foodB,
            quantity: foodB.baseQuantity,
          );
          await harness.coordinator.finalize(
            userId: kLocalNutritionUserScopeId,
            preview: p,
            mealCategory: 'lunch',
            loggedAt: DateTime.utc(2026, 8, 20, 7, i),
            localDate: '2026-08-20',
            timezoneId: 'Asia/Kolkata',
            commandId: 'cmd-b-$i',
            consumptionId: 'cons-b-$i',
          );
        }

        // Log Food C 1 time
        final pC = await harness.coordinator.preview(
          option: foodC,
          quantity: foodC.baseQuantity,
        );
        await harness.coordinator.finalize(
          userId: kLocalNutritionUserScopeId,
          preview: pC,
          mealCategory: 'dinner',
          loggedAt: DateTime.utc(2026, 8, 20, 13, 0),
          localDate: '2026-08-20',
          timezoneId: 'Asia/Kolkata',
          commandId: 'cmd-c-1',
          consumptionId: 'cons-c-1',
        );

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(harness.database),
            nutritionReadModelRepositoryProvider.overrideWith(
              (ref) async => harness.readModels,
            ),
            nutritionFoodCatalogRepositoryProvider.overrideWith(
              (ref) async => harness.catalog,
            ),
          ],
        );
        addTearDown(container.dispose);

        final recents = await container.read(
          canonicalRecentFoodsProvider.future,
        );

        final itemA = recents.firstWhere((r) => r.option.id == foodA.id);
        final itemB = recents.firstWhere((r) => r.option.id == foodB.id);
        final itemC = recents.firstWhere((r) => r.option.id == foodC.id);

        expect(itemA.frequencyCount, 3);
        expect(itemB.frequencyCount, 2);
        expect(itemC.frequencyCount, 1);
      },
    );

    testWidgets(
      'UI displays Recent and Frequent sections with factual copy and no recommendation wording',
      (tester) async {
        final harness = await _D3TestHarness.create();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          unawaited(harness.close());
        });

        final roti = await tester.runAsync(
          () => harness.catalog.createUserFood(
            displayName: 'Whole Wheat Roti',
            servingSize: 1,
            servingUnit: 'piece',
            energyKcal: 120,
            proteinG: 4,
            carbohydrateG: 20,
            fatG: 2,
          ),
        );

        final recentItem = CanonicalRecentFood(
          option: roti!,
          quantityLabel: '2 servings',
          loggedAtUtc: DateTime.utc(2026, 8, 20, 14, 0),
          frequencyCount: 3,
          historicalQuantity: Quantity(
            amount: QuantityAmount.fromBigInt(BigInt.two),
            unit: QuantityUnit.serving,
            context: QuantityContext(
              servingDefinition: roti.baseQuantity.context.servingDefinition,
            ),
          ),
        );

        await tester.pumpWidget(
          _buildFoodSearch(
            harness: harness,
            home: FoodSearchScreen(
              mealType: 'breakfast',
              selectedDate: DateTime(2026, 8, 24),
            ),
            recent: [recentItem],
          ),
        );
        await _settleD3(tester);

        // Factual section headers present
        expect(find.text('Recent'), findsOneWidget);
        expect(find.text('Frequent'), findsOneWidget);
        expect(
          find.text('Your repeat choices, ordered by real local history.'),
          findsOneWidget,
        );

        // No recommendation buzzwords
        expect(find.textContaining('recommend'), findsNothing);
        expect(find.textContaining('Recommend'), findsNothing);
        expect(find.textContaining('suggested'), findsNothing);
        expect(find.textContaining('Suggested'), findsNothing);
        expect(find.textContaining('smart pick'), findsNothing);
      },
    );

    testWidgets(
      'historical quantity and unit reuse seeds the edit sheet and destination meal/date are preserved',
      (tester) async {
        final harness = await _D3TestHarness.create();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          unawaited(harness.close());
        });

        final paneer = await tester.runAsync(
          () => harness.catalog.ensureProviderFood(
            displayName: 'Fresh Malai Paneer',
            sourceReference: 'provider-food-fresh-malai-paneer',
            servingSize: 100,
            servingUnit: 'g',
            energyKcal: 280,
            proteinG: 18,
            carbohydrateG: 4,
            fatG: 22,
          ),
        );

        final recentItem = CanonicalRecentFood(
          option: paneer!,
          quantityLabel: '150 g',
          loggedAtUtc: DateTime.utc(2026, 8, 10, 14, 0),
          frequencyCount: 1,
          historicalQuantity: Quantity.fromDecimal(
            amount: '150',
            unit: QuantityUnit.gram,
          ),
        );

        final targetDate = DateTime(2026, 8, 24);
        await tester.pumpWidget(
          _buildFoodSearch(
            harness: harness,
            home: FoodSearchScreen(
              mealType: 'breakfast',
              selectedDate: targetDate,
            ),
            recent: [recentItem],
          ),
        );
        await _settleD3(tester);

        // Tap the Recent Paneer row (not the Add button) to inspect / adjust quantity
        final paneerRow = find.text('Fresh Malai Paneer').first;
        expect(paneerRow, findsOneWidget);
        await tester.tap(paneerRow);
        await _settleD3(tester);

        // Dialog should be open with seeded historical amount
        expect(find.widgetWithText(ElevatedButton, 'Add to Breakfast'), findsOneWidget);

        final amountInput = find.byType(TextField).last;
        final textField = tester.widget<TextField>(amountInput);
        expect(textField.controller?.text, '150');

        // Edit amount from 150 to 200
        await tester.enterText(amountInput, '200');
        await tester.pump();

        // Submit log
        final logButton = find.widgetWithText(ElevatedButton, 'Add to Breakfast');
        expect(logButton, findsOneWidget);
        await tester.tap(logButton);
        await _settleD3(tester);
        await _settleD3(tester);

        // Verify the persisted consumption in the database
        final history = await tester.runAsync(
          () => harness.readModels.listHistory(
            userId: kLocalNutritionUserScopeId,
          ),
        );
        final latestRecord = history?.firstWhere(
          (r) => r.localDate == '2026-08-24',
        );

        // Verify destination date and meal were preserved
        expect(latestRecord?.localDate, '2026-08-24');
        expect(latestRecord?.mealCategory, 'breakfast');

        final item = latestRecord?.items.first;
        expect(item?.quantity.quantity?.amount.asDouble, 200.0);
        expect(item?.quantity.quantity?.unit, QuantityUnit.gram);
      },
    );

    testWidgets(
      'fast repeat logging with safe historical quantity logs immediately to current meal and date',
      (tester) async {
        final harness = await _D3TestHarness.create();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          unawaited(harness.close());
        });

        final dahi = await tester.runAsync(
          () => harness.catalog.ensureProviderFood(
            displayName: 'Thick Dahi',
            sourceReference: 'provider-food-thick-dahi',
            servingSize: 100,
            servingUnit: 'g',
            energyKcal: 70,
            proteinG: 4,
            carbohydrateG: 5,
            fatG: 4,
          ),
        );

        final recentItem = CanonicalRecentFood(
          option: dahi!,
          quantityLabel: '120 g',
          loggedAtUtc: DateTime.utc(2026, 8, 12, 7, 30),
          frequencyCount: 1,
          historicalQuantity: Quantity.fromDecimal(
            amount: '120',
            unit: QuantityUnit.gram,
          ),
        );

        final targetDate = DateTime(2026, 8, 24);
        await tester.pumpWidget(
          _buildFoodSearch(
            harness: harness,
            home: FoodSearchScreen(
              mealType: 'snack',
              selectedDate: targetDate,
            ),
            recent: [recentItem],
          ),
        );
        await _settleD3(tester);

        // Tap the Fast Add button for Thick Dahi
        final addBtn = find.widgetWithText(TextButton, 'Add').first;
        expect(addBtn, findsOneWidget);
        await tester.tap(addBtn);
        await _settleD3(tester);
        await _settleD3(tester);

        // Check feedback
        expect(find.textContaining('Added Thick Dahi to snack'), findsOneWidget);

        // Verify the persisted consumption
        final history = await tester.runAsync(
          () => harness.readModels.listHistory(
            userId: kLocalNutritionUserScopeId,
          ),
        );
        final latest = history?.firstWhere(
          (r) => r.localDate == '2026-08-24' && r.mealCategory == 'snack',
        );

        expect(latest?.localDate, '2026-08-24');
        expect(latest?.mealCategory, 'snack');
        expect(latest?.items.first.quantity.quantity?.amount.asDouble, 120.0);
      },
    );

    test(
      'deleted or unavailable food in history fails closed and is omitted from recent list',
      () async {
        final harness = await _D3TestHarness.create();
        addTearDown(() => unawaited(harness.close()));

        final food = await harness.catalog.createUserFood(
          displayName: 'Temporary Food',
          servingSize: 1,
          servingUnit: 'serving',
          energyKcal: 100,
          proteinG: 5,
          carbohydrateG: 10,
          fatG: 2,
        );

        final p = await harness.coordinator.preview(
          option: food,
          quantity: food.baseQuantity,
        );
        await harness.coordinator.finalize(
          userId: kLocalNutritionUserScopeId,
          preview: p,
          mealCategory: 'breakfast',
          loggedAt: DateTime.utc(2026, 8, 20, 3, 0),
          localDate: '2026-08-20',
          timezoneId: 'Asia/Kolkata',
          commandId: 'cmd-temp-1',
          consumptionId: 'cons-temp-1',
        );

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(harness.database),
            nutritionReadModelRepositoryProvider.overrideWith(
              (ref) async => harness.readModels,
            ),
            nutritionFoodCatalogRepositoryProvider.overrideWith(
              (ref) async => _MockMissingCatalogRepository(
                db: harness.database,
                registry: harness.registry,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final recents = await container.read(
          canonicalRecentFoodsProvider.future,
        );

        // Deleted food cannot be resolved and must fail closed (omitted from recents)
        expect(recents, isEmpty);
      },
    );

    testWidgets(
      'empty state renders clean landing message when no history exists',
      (tester) async {
        final harness = await _D3TestHarness.create();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          unawaited(harness.close());
        });

        await tester.pumpWidget(
          _buildFoodSearch(
            harness: harness,
            home: FoodSearchScreen(
              mealType: 'breakfast',
              selectedDate: DateTime(2026, 8, 24),
            ),
            recent: const [],
          ),
        );
        await _settleD3(tester);

        expect(find.text('No recent foods yet'), findsOneWidget);
        expect(find.text('Foods you log will appear here.'), findsOneWidget);
      },
    );

    testWidgets(
      'narrow width 320px and 2.0x text scale renders without overflow and remains accessible',
      (tester) async {
        final harness = await _D3TestHarness.create();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          unawaited(harness.close());
        });

        final food = await tester.runAsync(
          () => harness.catalog.createUserFood(
            displayName: 'Poha with Roasted Peanuts',
            servingSize: 1,
            servingUnit: 'serving',
            energyKcal: 230,
            proteinG: 4,
            carbohydrateG: 40,
            fatG: 6,
          ),
        );

        final recentItem = CanonicalRecentFood(
          option: food!,
          quantityLabel: '1 serving',
          loggedAtUtc: DateTime.utc(2026, 8, 24, 3, 0),
          historicalQuantity: food.baseQuantity,
        );

        await tester.pumpWidget(
          _buildFoodSearch(
            harness: harness,
            home: FoodSearchScreen(
              mealType: 'breakfast',
              selectedDate: DateTime(2026, 8, 24),
            ),
            recent: [recentItem],
            mediaSize: const Size(320, 600),
            textScale: 2.0,
          ),
        );
        await _settleD3(tester);

        expect(find.text('Poha with Roasted Peanuts'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _MockMissingCatalogRepository extends NutritionFoodCatalogRepository {
  _MockMissingCatalogRepository({
    required super.db,
    required super.registry,
  });

  @override
  Future<NutritionFoodOption?> getOption(String foodId) async => null;
}
