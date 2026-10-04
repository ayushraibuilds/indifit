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

/// Mimics the real catalogue: case-insensitive substring match, alphabetical
/// order.
MealItemResolver _resolverOver(List<NutritionFoodOption> catalog) =>
    MealItemResolver(
      search: (query) async =>
          catalog
              .where(
                (f) =>
                    f.displayName.toLowerCase().contains(query.toLowerCase()),
              )
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
      final match = await resolver.resolve('butter rotis');

      expect(match.state, CatalogMatchState.resolved);
      expect(match.option!.displayName, 'Butter Roti / Chapati');
    });

    test('plain "chapatis" means the everyday chapati, not a tie', () async {
      final match = await resolver.resolve('chapatis');

      expect(match.state, CatalogMatchState.resolved);
      expect(match.option!.displayName, 'Whole Wheat Roti / Chapati');
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

    // Mirrors the real catalogue, which has no plain "Roti" and generates
    // size/preparation variants for each bread.
    final breads = _resolverOver([
      _food('Rumali Roti', servingLabel: 'piece'),
      _food('Rumali Roti (Mini)', servingLabel: 'piece'),
      _food('Tandoori Roti (Wheat)', servingLabel: 'piece'),
      _food('Butter Roti / Chapati', servingLabel: 'piece'),
      _food('Whole Wheat Roti / Chapati', servingLabel: 'piece'),
      _food('Whole Wheat Roti / Chapati (Mini)', servingLabel: 'piece'),
    ]);

    test('a generic "roti" resolves to the everyday chapati', () async {
      for (final name in ['Roti', 'Rotis', 'Chapati']) {
        final match = await breads.resolve(name);

        expect(match.state, CatalogMatchState.resolved, reason: name);
        expect(match.option!.displayName, 'Whole Wheat Roti / Chapati');
      }
    });

    test('a named bread still beats its own size variants', () async {
      final match = await breads.resolve('Rumali Roti');

      expect(match.state, CatalogMatchState.resolved);
      expect(match.option!.displayName, 'Rumali Roti');
    });

    test('default keys are already normalised, or they never match', () {
      for (final key in MealItemResolver.genericDefaults.keys) {
        expect(MealItemResolver.normalize(key), key);
      }
    });

    test('nested-parenthesis variants still rank below their base', () async {
      final match = await _resolverOver([
        _food('Butter Chicken (Murgh Makhani)'),
        _food(
          'Butter Chicken (Murgh Makhani) (Diet prep (Low oil / breast only))',
        ),
        _food('Butter Chicken (Murgh Makhani) (Extra Chicken/Meat pieces)'),
      ]).resolve('Butter Chicken');

      expect(match.state, CatalogMatchState.resolved);
      expect(match.option!.displayName, 'Butter Chicken (Murgh Makhani)');
    });

    test('size variants rank below base dishes in the choice list', () {
      final ranked = MealItemResolver.rank('Tandoori Roti', [
        _food('Tandoori Roti (Wheat) (Mini)'),
        _food('Tandoori Roti (Wheat)'),
        _food('Tandoori Butter Roti'),
      ]);

      final order = ranked.map((s) => s.option.displayName).toList();
      expect(
        order.indexOf('Tandoori Roti (Wheat)'),
        lessThan(order.indexOf('Tandoori Roti (Wheat) (Mini)')),
      );
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

    test('pieces become servings of a food whose serving holds several', () {
      final eggs = _food('Boiled Eggs (2 pieces)');
      final four = PortionMapping.map(amount: 4, unit: 'eggs', option: eggs);
      expect(four.needsReview, isFalse);
      expect(four.quantity.unit, QuantityUnit.serving);
      expect(four.quantity.amount.asDouble, 2);

      final three = PortionMapping.map(amount: 3, unit: 'egg', option: eggs);
      expect(three.quantity.amount.asDouble, 1.5);

      final puri = _food('Pani Puri / Golgappa (6 pieces)');
      expect(
        PortionMapping.map(
          amount: 12,
          unit: 'pieces',
          option: puri,
        ).quantity.amount.asDouble,
        2,
      );

      final tikka = _food('Paneer Tikka (5 pcs)', servingLabel: 'katori');
      expect(
        PortionMapping.map(
          amount: 10,
          unit: 'pcs',
          option: tikka,
        ).quantity.amount.asDouble,
        2,
      );
    });

    test('a one-piece serving and a serving unit are unchanged', () {
      final samosa = _food('Samosa (1 piece)', servingLabel: 'piece');
      expect(
        PortionMapping.map(
          amount: 2,
          unit: 'piece',
          option: samosa,
        ).quantity.amount.asDouble,
        2,
      );
      final eggs = _food('Boiled Eggs (2 pieces)');
      expect(
        PortionMapping.map(
          amount: 2,
          unit: 'serving',
          option: eggs,
        ).quantity.amount.asDouble,
        2,
      );
    });

    test('piecesPerServing reads the catalogue name', () {
      expect(piecesPerServing(_food('Boiled Eggs (2 pieces)')), 2);
      expect(piecesPerServing(_food('Chicken Tikka (6 pcs) (Mini)')), 6);
      expect(piecesPerServing(_food('Samosa (1 piece)')), 1);
      expect(piecesPerServing(_food('Dal Makhani')), isNull);
    });
  });

  group('spelling', () {
    test('sabzi, subzi and sabji normalise alike', () {
      expect(MealItemResolver.normalize('Bhindi Sabzi'), 'bhindi sabji');
      expect(MealItemResolver.normalize('mix veg subzis'), 'mix veg sabji');
      expect(MealItemResolver.normalize('Torai ki Subji'), 'torai ki sabji');
    });

    test('a sabzi query resolves through the sabji default', () async {
      final bhindi = _food('Bhindi Masala (Okra)');
      final resolver = _resolverOver([bhindi, _food('Bhindi Fry')]);
      final match = await resolver.resolve('bhindi sabzi');
      expect(match.state, CatalogMatchState.resolved);
      expect(match.option, bhindi);
    });
  });
}
