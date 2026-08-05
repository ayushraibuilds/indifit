import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/typed_quantities.dart';

NutrientRegistry scalingRegistry() =>
    NutrientRegistry.fromAssetFileSync('assets/data/nutrient_registry.json');

NutritionCalculationRequest scalingRequest({
  required NutritionScaleRequest scale,
  Quantity? declaredYield,
  NutritionCalculationServingDefinition? servingDefinition,
}) {
  final registry = scalingRegistry();
  final ingredient = NutritionCalculationIngredient.directFood(
    id: 'line-1',
    foodId: 'food-1',
    quantity: Quantity.fromDecimal(amount: '100', unit: QuantityUnit.gram),
    nutrientFacts: {
      'protein': NutrientFact.known(
        nutrientId: 'protein',
        point: NutrientAmount(
          value: QuantityAmount.fromString('10'),
          unit: NutrientUnit.gram,
        ),
        basis: NutrientBasis(NutrientBasisKind.per100Grams),
        source: NutrientSourceType.reviewedCatalogue,
        factVersion: 'scaling-v1',
      ),
    },
  );
  return NutritionCalculationRequest(
    recipeId: 'recipe-1',
    recipeVersionId: 'recipe-1-v1',
    ingredients: [ingredient],
    registry: registry,
    nutrientRegistryVersion: registry.version,
    calculationRuleVersion: 'b03-08-v1',
    requestedNutrientIds: {'protein'},
    declaredYield: declaredYield,
    servingDefinition: servingDefinition,
    scale: scale,
  );
}

void main() {
  final service = const NutritionCalculationService();

  test('scalar scaling is exact and does not use display-rounded totals', () {
    final result = service.calculate(
      scalingRequest(scale: NutritionScaleRequest.scalar('1.5')),
    );

    expect(result.facts['protein']!.point!.value.toString(), '15');
    expect(result.scalingFactor.toString(), '1.5');
  });

  test('per-serving scaling divides only by an explicit serving count', () {
    final result = service.calculate(
      scalingRequest(
        scale: const NutritionScaleRequest.perDeclaredServing(),
        servingDefinition: NutritionCalculationServingDefinition(
          id: 'serving-1',
          revision: 'v1',
          count: QuantityAmount.fromString('4'),
        ),
      ),
    );

    expect(result.facts['protein']!.point!.value.toString(), '2.5');
    expect(result.scalingFactor.toString(), '0.25');
  });

  test('requested yield uses a compatible declared mass yield', () {
    final result = service.calculate(
      scalingRequest(
        declaredYield: Quantity.fromDecimal(
          amount: '200',
          unit: QuantityUnit.gram,
        ),
        scale: NutritionScaleRequest.requestedYield(
          Quantity.fromDecimal(amount: '50', unit: QuantityUnit.gram),
        ),
      ),
    );

    expect(result.facts['protein']!.point!.value.toString(), '2.5');
    expect(result.scalingFactor.toString(), '0.25');
  });

  test('unsupported scale precision fails explicitly', () {
    expect(
      () => NutritionScaleRequest.scalar('0.1234567890123'),
      throwsA(
        isA<NutritionCalculationError>().having(
          (error) => error.code,
          'code',
          NutritionCalculationErrorCode.precisionOverflow,
        ),
      ),
    );
  });

  test('scaling up and back down stays within exact decimal contract', () {
    final up = service.calculate(
      scalingRequest(scale: NutritionScaleRequest.scalar('3')),
    );
    final down = service.calculate(
      scalingRequest(scale: NutritionScaleRequest.scalar('0.333333333333')),
    );

    expect(up.facts['protein']!.point!.value.toString(), '30');
    expect(down.facts['protein']!.point!.value.toString(), '3.33333333333');
  });
}
