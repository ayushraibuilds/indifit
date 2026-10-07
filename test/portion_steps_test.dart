import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:indifit/features/food_log/widgets/portion_steps.dart';

Quantity _pieces(String amount) =>
    Quantity.fromDecimal(amount: amount, unit: QuantityUnit.piece);

String? _up(Quantity q) => nextPortion(q, increase: true)?.amount.toString();
String? _down(Quantity q) => nextPortion(q, increase: false)?.amount.toString();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('portion steps are fixed, not a quarter of the amount (C-05)', () {
    test('servings move in halves, quarters at or below one', () {
      expect(_up(_pieces('1')), '1.5');
      expect(_up(_pieces('1.5')), '2');
      expect(_down(_pieces('1')), '0.75');
      expect(_down(_pieces('2')), '1.5');
      expect(_up(_pieces('0.5')), '0.75');
      expect(_down(_pieces('0.25')), isNull);
    });

    test('odd amounts snap to the grid', () {
      expect(_up(_pieces('1.3')), '1.5');
      expect(_down(_pieces('1.3')), '1');
      expect(_up(_pieces('3.0517578125')), '3.5');
    });

    test('grams and millilitres move in tens', () {
      final grams = Quantity.fromNum(amount: 150, unit: QuantityUnit.gram);
      expect(_up(grams), '160');
      expect(_down(grams), '140');
      final odd = Quantity.fromNum(amount: 155, unit: QuantityUnit.millilitre);
      expect(_up(odd), '160');
      expect(_down(odd), '150');
      expect(
        _down(Quantity.fromNum(amount: 10, unit: QuantityUnit.gram)),
        isNull,
      );
    });

    test('the unit and serving context are kept', () {
      final serving = Quantity.serving(
        amount: '1',
        definition: const ServingDefinitionReference(
          id: 'food-serving::x',
          revision: 'r',
          source: 'catalogue',
        ),
        source: 'catalogue',
      );
      final next = nextPortion(serving, increase: true)!;
      expect(next.unit, QuantityUnit.serving);
      expect(next.context, serving.context);
    });
  });

  testWidgets('+ from 1 katori shows 1.5 then 2; − shows 0.75', (tester) async {
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

    String amount() => tester
        .widget<TextField>(
          find.byKey(const ValueKey('food_log_dialog_portion_field')),
        )
        .controller!
        .text;

    await tester.tap(find.byTooltip('Increase amount'));
    await tester.pump();
    expect(amount(), '1.5');
    await tester.tap(find.byTooltip('Increase amount'));
    await tester.pump();
    expect(amount(), '2');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Decrease amount'));
      await tester.pump();
    }
    expect(amount(), '0.75');
  });
}
