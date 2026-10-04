import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/catalog/food_catalog_models.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_logging_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_transformation_repository.dart';
import 'package:indifit/features/food_log/widgets/food_portion_bottom_sheet.dart';
import 'package:indifit/features/food_log/widgets/household_portion_visual.dart';

const _chips = [
  ServingOption(unitName: 'small_katori', gramWeight: 80),
  ServingOption(unitName: 'katori', gramWeight: 150),
  ServingOption(unitName: 'serving_bowl', gramWeight: 300),
  ServingOption(unitName: 'glass', gramWeight: 206),
  ServingOption(unitName: '100g', gramWeight: 100),
];

Quantity _grams(num value) =>
    Quantity.fromNum(amount: value, unit: QuantityUnit.gram);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('which vessel a selection amounts to', () {
    test('a household quantity names its measure', () {
      final spec = portionVisualSpecFor(
        quantity: Quantity.householdReference(
          count: '1.5',
          reference: const HouseholdMeasureReference(measureType: 'katori'),
        ),
      );
      expect(spec?.vessel, PortionVessel.katori);
      expect(spec?.count, 1.5);
      expect(spec?.caption, '1½ katori');
    });

    test('a serving labelled as a household measure', () {
      final quantity = Quantity.serving(
        amount: '2',
        definition: const ServingDefinitionReference(
          id: 'serving:poha',
          revision: '1',
        ),
      );
      final katori = portionVisualSpecFor(
        quantity: quantity,
        servingUnitLabel: '1 katori',
      );
      expect(katori?.vessel, PortionVessel.katori);
      expect(katori?.count, 2);
      expect(katori?.caption, '2 katori');

      final glass = portionVisualSpecFor(
        quantity: quantity,
        servingUnitLabel: 'glass',
      );
      expect(glass?.vessel, PortionVessel.glass);
      expect(glass?.caption, '2 glasses');

      expect(
        portionVisualSpecFor(quantity: quantity, servingUnitLabel: 'piece'),
        isNull,
      );
    });

    test('grams equal to a household chip show that vessel', () {
      final katori = portionVisualSpecFor(
        quantity: _grams(150),
        servingOptions: _chips,
      );
      expect(katori?.vessel, PortionVessel.katori);
      expect(katori?.metricLabel, '≈ 150 g');
      expect(katori?.semanticsLabel, '1 katori, about 150 grams');

      expect(
        portionVisualSpecFor(
          quantity: _grams(80),
          servingOptions: _chips,
        )?.vessel,
        PortionVessel.smallKatori,
      );
      expect(
        portionVisualSpecFor(
          quantity: _grams(300),
          servingOptions: _chips,
        )?.vessel,
        PortionVessel.bowl,
      );
    });

    test('plain metric amounts have no household picture', () {
      expect(
        portionVisualSpecFor(quantity: _grams(100), servingOptions: _chips),
        isNull,
      );
      expect(
        portionVisualSpecFor(quantity: _grams(175), servingOptions: _chips),
        isNull,
      );
      expect(portionVisualSpecFor(quantity: _grams(150)), isNull);
    });
  });

  group('drawing', () {
    test('one vessel per whole unit, a part-filled one for a fraction', () {
      expect(HouseholdPortionVisual.fills(1), [1.0]);
      expect(HouseholdPortionVisual.fills(1.5), [1.0, 0.5]);
      expect(HouseholdPortionVisual.fills(3), [1.0, 1.0, 1.0]);
      expect(HouseholdPortionVisual.fills(0.25), [0.25]);
      // More than four collapses to one vessel and a count.
      expect(HouseholdPortionVisual.fills(6), [1.0]);
    });

    test('counts read naturally', () {
      expect(formatPortionCount(1), '1');
      expect(formatPortionCount(1.5), '1½');
      expect(formatPortionCount(0.25), '¼');
      expect(formatPortionCount(2.75), '2¾');
      expect(formatPortionCount(1.3), '1.3');
    });

    testWidgets('renders vessels, caption and a screen-reader label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: HouseholdPortionVisual(
              spec: PortionVisualSpec(
                vessel: PortionVessel.katori,
                count: 6,
                unitLabel: 'katori',
              ),
            ),
          ),
        ),
      );
      expect(find.byType(PortionVesselIcon), findsOneWidget);
      expect(find.text('×6'), findsOneWidget);
      expect(find.text('6 katori'), findsOneWidget);
      expect(find.bySemanticsLabel('Portion: 6 katori'), findsOneWidget);
      semantics.dispose();
    });
  });

  testWidgets('the portion sheet shows the katori for a katori-served food', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase.memory();
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    final catalog = NutritionFoodCatalogRepository(db: db, registry: registry);
    final coordinator = NutritionFoodLoggingCoordinator(
      db: db,
      registry: registry,
      catalog: catalog,
      calculator: const NutritionCalculationService(),
      consumption: NutritionConsumptionRepository(db: db, registry: registry),
      transformations: NutritionTransformationRepository(db: db),
    );
    final setup = (await tester.runAsync(() async {
      final option = await catalog.createUserFood(
        displayName: 'Test poha',
        servingSize: 1,
        servingUnit: 'katori',
        energyKcal: 230,
        proteinG: 5,
        carbohydrateG: 42,
        fatG: 4,
      );
      final preview = await coordinator.preview(
        option: option,
        quantity: option.baseQuantity,
      );
      return (option, preview);
    }))!;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(db.close);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: FoodPortionBottomSheet(
              option: setup.$1,
              initialMealType: 'lunch',
              coordinator: coordinator,
              transformations: const [],
              initialPreview: setup.$2,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('household_portion_visual')),
      findsOneWidget,
    );
    expect(find.text('1 katori'), findsWidgets);
  });
}
