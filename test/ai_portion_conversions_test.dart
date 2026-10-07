import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/features/nutrition_ai/meal_item_resolver.dart';
import 'package:indifit/features/nutrition_ai/natural_language_meal_service.dart';

import 'support/real_catalogue.dart';

/// Audit C-06 / CAT-12 (PR-F): the AI meal tools convert household units
/// with the installed catalogue's own measures. Each case was a probe in the
/// final launch audit (§ 3.4) and failed there; they run on the real
/// bundled catalogue, not synthetic foods.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RealCatalogue catalogue;
  late MealItemResolver resolver;

  setUp(() async {
    catalogue = await RealCatalogue.open();
    // The same search the meal service gives the resolver.
    resolver = MealItemResolver(
      search: (query) async => [
        for (final option in await catalogue.catalog.search(query: query))
          if (option.facts['energy']?.point != null) option,
      ],
    );
  });
  tearDown(() => catalogue.close());

  Future<NutritionFoodOption> food(String name) async =>
      (await catalogue.catalog.getOption(await catalogue.foodId(name)))!;

  Future<PortionMapping> map(double amount, String unit, String name) async =>
      PortionMapping.map(amount: amount, unit: unit, option: await food(name));

  void expectServings(PortionMapping portion, double servings) {
    expect(portion.needsReview, isFalse, reason: portion.reviewReason);
    expect(portion.quantity.unit, QuantityUnit.serving);
    expect(portion.quantity.amount.asDouble, servings);
  }

  test('"1 katori dal" logs Toor Dal Tadka without asking', () async {
    final match = await resolver.resolve('dal');

    expect(match.state, CatalogMatchState.resolved);
    expect(match.option!.displayName, 'Toor Dal / Yellow Dal Tadka');
    expectServings(
      PortionMapping.map(amount: 1, unit: 'katori', option: match.option!),
      1,
    );
  });

  test('a bowl is two katori', () async {
    expectServings(await map(1, 'bowl', 'Toor Dal / Yellow Dal Tadka'), 2);
    expectServings(await map(1, 'bowl', 'Rajma Masala (Red Kidney Beans)'), 2);
  });

  test('a plate of poha or biryani is two katori, not one', () async {
    expectServings(await map(1, 'plate', 'Poha (Flattened Rice)'), 2);
    expectServings(await map(1, 'plate', 'Chicken Biryani (Hyderabadi)'), 2);
  });

  test('grams become katori through the serving\'s gram weight', () async {
    expectServings(await map(150, 'g', 'Basmati White Rice (Cooked)'), 1);
    expectServings(await map(225, 'g', 'Basmati White Rice (Cooked)'), 1.5);
  });

  test('a katori of curd is 150 g, not 100 g', () async {
    final portion = await map(1, 'katori', 'Plain Curd / Dahi (Cow Milk)');

    expect(portion.needsReview, isFalse, reason: portion.reviewReason);
    expect(portion.quantity.unit, QuantityUnit.gram);
    expect(portion.quantity.amount.asDouble, 150);
  });

  test('a half-katori serving counts in its own servings', () async {
    // "Small side bowl" is half a katori per serving.
    expectServings(await map(1, 'katori', 'Suji Upma (Small side bowl)'), 2);
  });

  test(
    'a per-100 g variant asks rather than guessing a katori weight',
    () async {
      // Mini rice rows are 60 g; a katori of a cooked dish is 150 g, but a
      // per-100 g variant could be a dry snack, so the user sets it.
      final portion = await map(
        1,
        'katori',
        'Basmati White Rice (Cooked) (Mini)',
      );

      expect(portion.needsReview, isTrue);
    },
  );

  test('the review card shows what a bowl of dal logs', () async {
    final dal = await food('Toor Dal / Yellow Dal Tadka');
    final katoriKcal = dal.facts['energy']!.point!.value.asDouble;
    final item = bindToCatalog(
      const DecomposedFoodItem(
        rawSegment: '1 bowl dal tadka',
        foodName: 'dal tadka',
        quantityAmount: 1,
        quantityUnit: 'bowl',
        estimatedCalories: 0,
        estimatedProtein: 0,
        estimatedCarbs: 0,
        estimatedFat: 0,
        confidence: 'high',
      ),
      dal,
    );

    expect(item.quantityAmount, 2);
    expect(item.quantityUnit, 'katori');
    expect(item.portionNote, isNull);
    expect(item.estimatedCalories, (2 * katoriKcal).round());
  });

  test(
    'size variants don\'t crowd the choices when their dish is there',
    () async {
      final match = await resolver.resolve('upma');

      expect(match.state, CatalogMatchState.needsChoice);
      expect(
        match.choices.map((option) => option.displayName),
        unorderedEquals(['Oats Upma', 'Suji Upma']),
      );
    },
  );
}
