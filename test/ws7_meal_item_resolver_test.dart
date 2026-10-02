import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/features/nutrition_ai/meal_item_resolver.dart';

NutritionFoodOption _food(
  String name, {
  QuantityUnit unit = QuantityUnit.serving,
  String? servingLabel,
}) => NutritionFoodOption(
  id: 'food:${name.toLowerCase()}',
  displayName: name,
  baseQuantity: unit == QuantityUnit.serving
      ? Quantity.serving(
          amount: '1',
          definition: ServingDefinitionReference(
            id: 'serving:${name.toLowerCase()}',
            revision: '1',
          ),
        )
      : Quantity.fromNum(amount: 100, unit: unit),
  facts: const {},
  sourceType: 'test',
  sourceReference: null,
  preparationId: null,
  servingUnitLabel: servingLabel,
);

/// Mimics the real catalogue: substring match, alphabetical order.
MealItemResolver _resolverOver(List<NutritionFoodOption> catalog) =>
    MealItemResolver(
      search: (query) async =>
          catalog
              .where((f) => f.displayName.toLowerCase().contains(query))
              .toList()
            ..sort((a, b) => a.displayName.compareTo(b.displayName)),
    );

void main() {
  group('MealItemResolver', () {
    final catalog = [
      _food('Chana Dal Palak (Spinach & Gram dal)'),
      _food('Dal Makhani'),
      _food('Yellow Dal Tadka', servingLabel: 'katori'),
      _food('Whole Wheat Roti / Chapati', servingLabel: 'piece'),
      _food('Butter Roti / Chapati', servingLabel: 'piece'),
      _food('Steamed Rice', unit: QuantityUnit.gram),
    ];
    final resolver = _resolverOver(catalog);

    test('never takes the alphabetical first hit for a vague name', () async {
      final match = await resolver.resolve('Dal');

      expect(match.state, CatalogMatchState.needsChoice);
      expect(match.option, isNull);
      expect(match.choices, isNotEmpty);
      expect(match.choices.length, lessThanOrEqualTo(3));
    });

    test('resolves an exact name', () async {
      final match = await resolver.resolve('Steamed Rice');

      expect(match.state, CatalogMatchState.resolved);
      expect(match.option!.displayName, 'Steamed Rice');
    });

    test('resolves via a slash alternative and folds plurals', () async {
      final match = await resolver.resolve('chapatis');

      // Both roti foods list "Chapati" as an alternative, so this is a
      // genuine tie and the user picks.
      expect(match.state, CatalogMatchState.needsChoice);
      expect(
        match.choices.map((f) => f.displayName),
        containsAll(['Whole Wheat Roti / Chapati', 'Butter Roti / Chapati']),
      );
    });

    test('falls back to distinctive words when the phrase misses', () async {
      final match = await resolver.resolve('dal tadka with jeera');

      expect(match.state, isNot(CatalogMatchState.unmatched));
      final best = match.option ?? match.choices.first;
      expect(best.displayName, 'Yellow Dal Tadka');
    });

    test('reports unmatched instead of guessing', () async {
      final match = await resolver.resolve('Quinoa salad');

      expect(match.state, CatalogMatchState.unmatched);
    });

    test('a clear winner is auto-selected', () {
      final ranked = MealItemResolver.rank('Dal Makhani', catalog);

      expect(MealItemResolver.decide(ranked).state, CatalogMatchState.resolved);
      expect(ranked.first.option.displayName, 'Dal Makhani');
    });
  });

  group('PortionMapping', () {
    test('keeps a per-piece serving count for pieces', () {
      final roti = _food('Whole Wheat Roti / Chapati', servingLabel: 'piece');
      final mapping = PortionMapping.map(amount: 2, unit: 'roti', option: roti);

      expect(mapping.needsReview, isFalse);
      expect(mapping.quantity.unit, QuantityUnit.serving);
      expect(mapping.quantity.amount.asDouble, 2);
    });

    test('keeps katori for a katori-served food', () {
      final dal = _food('Yellow Dal Tadka', servingLabel: 'katori');
      final mapping = PortionMapping.map(
        amount: 1.5,
        unit: 'katoris',
        option: dal,
      );

      expect(mapping.needsReview, isFalse);
      expect(mapping.quantity.amount.asDouble, 1.5);
    });

    test('grams map onto a per-100 g food', () {
      final rice = _food('Steamed Rice', unit: QuantityUnit.gram);
      final mapping = PortionMapping.map(amount: 150, unit: 'g', option: rice);

      expect(mapping.needsReview, isFalse);
      expect(mapping.quantity.unit, QuantityUnit.gram);
      expect(mapping.quantity.amount.asDouble, 150);
    });

    test(
      'pieces against a per-100 g food are flagged, not logged as grams',
      () {
        final rice = _food('Steamed Rice', unit: QuantityUnit.gram);
        final mapping = PortionMapping.map(
          amount: 2,
          unit: 'piece',
          option: rice,
        );

        expect(mapping.needsReview, isTrue);
        expect(mapping.quantity.amount.asDouble, 100);
        expect(mapping.reviewReason, contains('2 piece'));
      },
    );

    test('grams against a katori serving are flagged, not 150 katori', () {
      final dal = _food('Yellow Dal Tadka', servingLabel: 'katori');
      final mapping = PortionMapping.map(amount: 150, unit: 'g', option: dal);

      expect(mapping.needsReview, isTrue);
      expect(mapping.quantity.amount.asDouble, 1);
      expect(mapping.reviewReason, contains('katori'));
    });

    test('a different household measure is flagged', () {
      final dal = _food('Yellow Dal Tadka', servingLabel: 'katori');
      final mapping = PortionMapping.map(amount: 1, unit: 'bowl', option: dal);

      expect(mapping.needsReview, isTrue);
    });

    test('zero or missing amounts are flagged', () {
      final dal = _food('Yellow Dal Tadka', servingLabel: 'katori');

      expect(
        PortionMapping.map(amount: 0, unit: 'katori', option: dal).needsReview,
        isTrue,
      );
    });
  });
}
