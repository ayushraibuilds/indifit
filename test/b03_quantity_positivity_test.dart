import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/typed_quantities.dart';

void main() {
  const servingDefinition = ServingDefinitionReference(
    id: 'serving:fixture:one',
    revision: 'v1',
    source: 'fixture',
  );

  const householdReference = HouseholdMeasureReference(measureType: 'katori');

  final contexts = NutritionQuantityInputContext.values;

  group('B03-04 positive nutrition quantity boundary', () {
    test('core quantities permit zero for internal arithmetic', () {
      final zero = Quantity.fromDecimal(amount: '0', unit: QuantityUnit.gram);
      final grams = Quantity.fromDecimal(amount: '4', unit: QuantityUnit.gram);

      expect(zero.isZero, isTrue);
      expect(zero + zero, equals(zero));
      expect(grams - grams, equals(zero));
    });

    test('internal aggregation can begin at a zero accumulator', () {
      var total = QuantityAmount.zero;
      for (final amount in <QuantityAmount>[]) {
        total = total + amount;
      }

      expect(total, equals(QuantityAmount.zero));
    });

    test('zero is rejected with the selected user-input context', () {
      final quantities = <NutritionQuantityInputContext, Quantity>{
        NutritionQuantityInputContext.foodLogConsumed: Quantity.fromDecimal(
          amount: '0',
          unit: QuantityUnit.gram,
        ),
        NutritionQuantityInputContext.recipeIngredient: Quantity.fromDecimal(
          amount: '0',
          unit: QuantityUnit.millilitre,
        ),
        NutritionQuantityInputContext.servingCount: Quantity.serving(
          amount: '0',
          definition: servingDefinition,
        ),
        NutritionQuantityInputContext.userEnteredPortion:
            Quantity.householdReference(
              count: '0',
              reference: householdReference,
            ),
      };
      final validators =
          <NutritionQuantityInputContext, Quantity Function(Quantity)>{
            NutritionQuantityInputContext.foodLogConsumed:
                NutritionQuantityService
                    .validatePositiveConsumedFoodLogQuantity,
            NutritionQuantityInputContext.recipeIngredient:
                NutritionQuantityService
                    .validatePositiveRecipeIngredientQuantity,
            NutritionQuantityInputContext.servingCount:
                NutritionQuantityService.validatePositiveServingCount,
            NutritionQuantityInputContext.userEnteredPortion:
                NutritionQuantityService.validatePositiveUserEnteredPortion,
          };

      for (final entry in quantities.entries) {
        expect(
          () => validators[entry.key]!(entry.value),
          throwsA(
            isA<NonPositiveQuantityError>().having(
              (error) => error.context,
              'context',
              entry.key,
            ),
          ),
        );
      }
    });

    test('positive values pass without changing typed identity', () {
      final quantities = <Quantity>[
        Quantity.fromDecimal(amount: '1', unit: QuantityUnit.gram),
        Quantity.fromDecimal(amount: '1', unit: QuantityUnit.millilitre),
        Quantity.fromDecimal(amount: '1', unit: QuantityUnit.piece),
        Quantity.serving(amount: '1', definition: servingDefinition),
        Quantity.householdReference(count: '1', reference: householdReference),
      ];

      for (final quantity in quantities) {
        for (final context in contexts) {
          expect(
            NutritionQuantityService.validatePositive(
              quantity,
              context: context,
            ),
            same(quantity),
          );
        }
      }
    });

    test('negative values remain rejected by the core quantity boundary', () {
      expect(
        () => Quantity.fromDecimal(amount: '-1', unit: QuantityUnit.gram),
        throwsA(isA<InvalidQuantityAmountError>()),
      );
      expect(
        () => QuantityAmount.fromNum(-0.1),
        throwsA(isA<InvalidQuantityAmountError>()),
      );
    });

    test('specific domain entry points apply the shared policy', () {
      final positive = Quantity.fromDecimal(
        amount: '2',
        unit: QuantityUnit.gram,
      );

      expect(
        NutritionQuantityService.validatePositiveConsumedQuantity(positive),
        same(positive),
      );
      expect(
        NutritionQuantityService.validatePositiveRecipeIngredient(positive),
        same(positive),
      );
      expect(
        NutritionQuantityService.validatePositiveServingCount(positive),
        same(positive),
      );
      expect(
        NutritionQuantityService.validatePositiveUserEnteredPortion(positive),
        same(positive),
      );
    });

    test(
      'input contexts have stable IDs independent of presentation labels',
      () {
        expect(
          NutritionQuantityInputContext.foodLogConsumed.stableId,
          'food_log_consumed',
        );
        expect(
          NutritionQuantityInputContext.recipeIngredient.displayLabel,
          'recipe ingredient',
        );
        expect(
          NutritionQuantityInputContext.foodLogConsumed.stableId,
          isNot(NutritionQuantityInputContext.recipeIngredient.stableId),
        );
      },
    );
  });
}
