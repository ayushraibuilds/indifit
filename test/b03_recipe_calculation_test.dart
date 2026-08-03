import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/typed_quantities.dart';

NutrientRegistry calculationRegistry() =>
    NutrientRegistry.fromAssetFileSync('assets/data/nutrient_registry.json');

Quantity grams(String value) =>
    Quantity.fromDecimal(amount: value, unit: QuantityUnit.gram);

Quantity millilitres(String value) =>
    Quantity.fromDecimal(amount: value, unit: QuantityUnit.millilitre);

Quantity pieces(String value) =>
    Quantity.fromDecimal(amount: value, unit: QuantityUnit.piece);

NutrientAmount amount(String value, NutrientUnit unit) =>
    NutrientAmount(value: QuantityAmount.fromString(value), unit: unit);

NutrientFact per100GramsFact(
  String nutrientId,
  String value, {
  NutrientUnit? unit,
  NutrientFactStatus status = NutrientFactStatus.known,
  NutrientSourceType source = NutrientSourceType.reviewedCatalogue,
  String factVersion = 'food-v1',
  String? lower,
  String? upper,
}) {
  final registry = calculationRegistry();
  final resolvedUnit = unit ?? registry.definitionFor(nutrientId).unit;
  final basis = NutrientBasis(NutrientBasisKind.per100Grams);
  if (status == NutrientFactStatus.knownZero) {
    return NutrientFact.knownZero(
      nutrientId: nutrientId,
      unit: resolvedUnit,
      basis: basis,
      source: source,
      factVersion: factVersion,
    );
  }
  if (status == NutrientFactStatus.missing) {
    return NutrientFact.missing(
      nutrientId: nutrientId,
      unit: resolvedUnit,
      basis: basis,
      source: source,
      factVersion: factVersion,
    );
  }
  if (status == NutrientFactStatus.estimated) {
    return NutrientFact.estimated(
      nutrientId: nutrientId,
      point: amount(value, resolvedUnit),
      lower: lower == null ? null : amount(lower, resolvedUnit),
      upper: upper == null ? null : amount(upper, resolvedUnit),
      basis: basis,
      source: source,
      factVersion: factVersion,
    );
  }
  return NutrientFact.known(
    nutrientId: nutrientId,
    point: amount(value, resolvedUnit),
    lower: lower == null ? null : amount(lower, resolvedUnit),
    upper: upper == null ? null : amount(upper, resolvedUnit),
    basis: basis,
    source: source,
    factVersion: factVersion,
  );
}

NutritionCalculationIngredient calculationIngredient({
  required String id,
  required String foodId,
  required Quantity quantity,
  required Map<String, NutrientFact> facts,
  int? position,
}) => NutritionCalculationIngredient.directFood(
  id: id,
  foodId: foodId,
  quantity: quantity,
  nutrientFacts: facts,
  position: position,
);

NutritionCalculationRequest calculationRequest({
  required Iterable<NutritionCalculationIngredient> ingredients,
  Set<String>? requestedNutrientIds,
  Quantity? declaredYield,
  NutritionCalculationServingDefinition? servingDefinition,
  NutritionScaleRequest scale = const NutritionScaleRequest.wholeRecipe(),
}) {
  final registry = calculationRegistry();
  return NutritionCalculationRequest(
    recipeId: 'recipe-1',
    recipeVersionId: 'recipe-1-v1',
    ingredients: ingredients,
    registry: registry,
    nutrientRegistryVersion: registry.version,
    calculationRuleVersion: 'b03-08-v1',
    requestedNutrientIds: requestedNutrientIds,
    declaredYield: declaredYield,
    servingDefinition: servingDefinition,
    scale: scale,
  );
}

NutritionCalculationResult calculate(
  Iterable<NutritionCalculationIngredient> ingredients, {
  Set<String>? requestedNutrientIds,
  Quantity? declaredYield,
  NutritionCalculationServingDefinition? servingDefinition,
  NutritionScaleRequest scale = const NutritionScaleRequest.wholeRecipe(),
}) => const NutritionCalculationService().calculate(
  calculationRequest(
    ingredients: ingredients,
    requestedNutrientIds: requestedNutrientIds,
    declaredYield: declaredYield,
    servingDefinition: servingDefinition,
    scale: scale,
  ),
);

void main() {
  group('B03-08 direct-food recipe calculation', () {
    test('a valid recipe calculates and multiple ingredients aggregate', () {
      final result = calculate(
        [
          calculationIngredient(
            id: 'line-1',
            foodId: 'food-rice',
            quantity: grams('100'),
            facts: {'protein': per100GramsFact('protein', '7')},
            position: 0,
          ),
          calculationIngredient(
            id: 'line-2',
            foodId: 'food-dal',
            quantity: grams('200'),
            facts: {'protein': per100GramsFact('protein', '9')},
            position: 1,
          ),
        ],
        requestedNutrientIds: {'protein'},
      );

      expect(result.facts['protein']!.point!.value.toString(), '25');
      expect(result.ingredientCount, 2);
      expect(result.completeness.state, NutrientCompletenessState.complete);
    });

    test('ingredient order does not change totals', () {
      final first = calculationIngredient(
        id: 'line-a',
        foodId: 'food-a',
        quantity: grams('100'),
        facts: {'protein': per100GramsFact('protein', '3')},
        position: 0,
      );
      final second = calculationIngredient(
        id: 'line-b',
        foodId: 'food-b',
        quantity: grams('100'),
        facts: {'protein': per100GramsFact('protein', '4')},
        position: 1,
      );
      final ordered = calculate(
        [first, second],
        requestedNutrientIds: {'protein'},
      );
      final reversed = calculate(
        [second, first],
        requestedNutrientIds: {'protein'},
      );

      expect(reversed.facts['protein']!.point!.value.toString(), '7');
      expect(
        reversed.facts['protein']!.toJson(),
        ordered.facts['protein']!.toJson(),
      );
    });

    test('ingredient identity remains in deterministic lineage', () {
      final result = calculate(
        [
          calculationIngredient(
            id: 'line-1',
            foodId: 'stable-food-identity',
            quantity: grams('100'),
            facts: {'protein': per100GramsFact('protein', '5')},
          ),
        ],
        requestedNutrientIds: {'protein'},
      );

      final lineage = result.lineage.toJson();
      expect(
        (lineage['ingredients'] as List).single['food_id'],
        'stable-food-identity',
      );
      expect(result.lineage.fingerprint, isNotEmpty);
    });

    test('known zero remains known', () {
      final result = calculate(
        [
          calculationIngredient(
            id: 'line-1',
            foodId: 'food-zero',
            quantity: grams('100'),
            facts: {
              'protein': per100GramsFact(
                'protein',
                '0',
                status: NutrientFactStatus.knownZero,
              ),
            },
          ),
        ],
        requestedNutrientIds: {'protein'},
      );

      expect(result.facts['protein']!.status, NutrientFactStatus.knownZero);
      expect(result.completeness.state, NutrientCompletenessState.complete);
    });

    test('unknown facts and missing coverage remain distinct from zero', () {
      final result = calculate(
        [
          calculationIngredient(
            id: 'line-known',
            foodId: 'food-known',
            quantity: grams('100'),
            facts: {'protein': per100GramsFact('protein', '5')},
            position: 0,
          ),
          calculationIngredient(
            id: 'line-unknown',
            foodId: 'food-unknown',
            quantity: grams('100'),
            facts: const {},
            position: 1,
          ),
        ],
        requestedNutrientIds: {'protein'},
      );

      expect(result.facts['protein']!.point!.value.toString(), '5');
      expect(result.facts['protein']!.status, NutrientFactStatus.known);
      expect(result.facts['protein']!.coverageIncomplete, isTrue);
      expect(result.completeness.state, NutrientCompletenessState.partial);
      expect(result.completeness.missingNutrientIds, contains('protein'));
      expect(result.unresolvedInputs, contains('line-unknown:protein'));
    });

    test('unknown facts do not fail on an incompatible source basis', () {
      final result = calculate(
        [
          calculationIngredient(
            id: 'line-unknown',
            foodId: 'food-liquid',
            quantity: millilitres('100'),
            facts: {
              'protein': NutrientFact.missing(
                nutrientId: 'protein',
                unit: NutrientUnit.gram,
                basis: NutrientBasis(NutrientBasisKind.per100Grams),
                source: NutrientSourceType.importedProvider,
                factVersion: 'provider-v1',
              ),
            },
          ),
        ],
        requestedNutrientIds: {'protein'},
      );

      expect(result.facts['protein']!.status, NutrientFactStatus.missing);
      expect(result.completeness.state, NutrientCompletenessState.unknown);
      expect(
        result.lineage.ingredients.single.nutrientFacts['protein']!.basis.kind,
        NutrientBasisKind.per100Grams,
      );
    });

    test('missing nutrient IDs are returned for the requested set', () {
      final result = calculate(
        [
          calculationIngredient(
            id: 'line-1',
            foodId: 'food-protein-only',
            quantity: grams('100'),
            facts: {'protein': per100GramsFact('protein', '10')},
          ),
        ],
        requestedNutrientIds: {'fat', 'protein'},
      );

      expect(result.facts['fat']!.status, NutrientFactStatus.missing);
      expect(result.missingNutrientIds, contains('fat'));
      expect(result.completeness.state, NutrientCompletenessState.partial);
    });

    test('estimated facts retain estimate state and source lineage', () {
      final result = calculate(
        [
          calculationIngredient(
            id: 'line-estimated',
            foodId: 'food-estimated',
            quantity: grams('100'),
            facts: {
              'protein': per100GramsFact(
                'protein',
                '8',
                status: NutrientFactStatus.estimated,
                source: NutrientSourceType.importedProvider,
              ),
            },
          ),
        ],
        requestedNutrientIds: {'protein'},
      );

      expect(result.facts['protein']!.status, NutrientFactStatus.estimated);
      expect(result.estimatedNutrientIds, contains('protein'));
      expect(result.sourceTypes, contains(NutrientSourceType.importedProvider));
    });

    test('nutrient lower, point, and upper ranges aggregate exactly', () {
      final result = calculate(
        [
          calculationIngredient(
            id: 'line-1',
            foodId: 'food-1',
            quantity: grams('100'),
            facts: {
              'protein': per100GramsFact(
                'protein',
                '4',
                lower: '3',
                upper: '5',
              ),
            },
            position: 0,
          ),
          calculationIngredient(
            id: 'line-2',
            foodId: 'food-2',
            quantity: grams('100'),
            facts: {
              'protein': per100GramsFact(
                'protein',
                '6',
                lower: '5',
                upper: '7',
              ),
            },
            position: 1,
          ),
        ],
        requestedNutrientIds: {'protein'},
      );

      final fact = result.facts['protein']!;
      expect(fact.lower!.value.toString(), '8');
      expect(fact.point!.value.toString(), '10');
      expect(fact.upper!.value.toString(), '12');
    });

    test('per-100-gram facts scale by mass without display rounding', () {
      final result = calculate(
        [
          calculationIngredient(
            id: 'line-1',
            foodId: 'food-precise',
            quantity: grams('100'),
            facts: {'protein': per100GramsFact('protein', '1.2344')},
            position: 0,
          ),
          calculationIngredient(
            id: 'line-2',
            foodId: 'food-precise-2',
            quantity: grams('100'),
            facts: {'protein': per100GramsFact('protein', '2.3455')},
            position: 1,
          ),
        ],
        requestedNutrientIds: {'protein'},
      );

      final fact = result.facts['protein']!;
      expect(fact.point!.value.toString(), '3.5799');
      expect(fact.displayPoint(calculationRegistry()), '3.6');
    });

    test('per-100-millilitre facts scale by volume', () {
      final registry = calculationRegistry();
      final fact = NutrientFact.known(
        nutrientId: 'energy',
        point: amount('2', NutrientUnit.kilocalorie),
        basis: NutrientBasis(NutrientBasisKind.per100Millilitres),
        source: NutrientSourceType.reviewedCatalogue,
      );
      final result = calculate(
        [
          calculationIngredient(
            id: 'line-volume',
            foodId: 'food-liquid',
            quantity: millilitres('250'),
            facts: {'energy': fact},
          ),
        ],
        requestedNutrientIds: {'energy'},
      );

      expect(result.facts['energy']!.point!.value.toString(), '5');
      expect(result.nutrientRegistryVersion, registry.version);
    });

    test('serving facts require and honor matching serving context', () {
      const servingReference = ServingDefinitionReference(
        id: 'food-serving',
        revision: 'v1',
      );
      final fact = NutrientFact.known(
        nutrientId: 'protein',
        point: amount('4', NutrientUnit.gram),
        basis: NutrientBasis(
          NutrientBasisKind.perServing,
          servingDefinition: servingReference,
        ),
        source: NutrientSourceType.reviewedCatalogue,
      );
      final result = calculate(
        [
          calculationIngredient(
            id: 'line-serving',
            foodId: 'food-serving',
            quantity: Quantity.serving(
              amount: '2',
              definition: servingReference,
            ),
            facts: {'protein': fact},
          ),
        ],
        requestedNutrientIds: {'protein'},
      );

      expect(result.facts['protein']!.point!.value.toString(), '8');
    });

    test(
      'mass-volume, piece-mass, and mismatched serving conversions fail',
      () {
        const servingReference = ServingDefinitionReference(
          id: 'food-serving',
          revision: 'v1',
        );
        final perMass = per100GramsFact('protein', '10');
        final perServing = NutrientFact.known(
          nutrientId: 'protein',
          point: amount('4', NutrientUnit.gram),
          basis: NutrientBasis(
            NutrientBasisKind.perServing,
            servingDefinition: servingReference,
          ),
          source: NutrientSourceType.reviewedCatalogue,
        );

        expect(
          () => calculate(
            [
              calculationIngredient(
                id: 'line-volume',
                foodId: 'food',
                quantity: millilitres('100'),
                facts: {'protein': perMass},
              ),
            ],
            requestedNutrientIds: {'protein'},
          ),
          throwsA(
            isA<NutritionCalculationError>().having(
              (error) => error.code,
              'code',
              NutritionCalculationErrorCode.incompatibleUnitOrBasis,
            ),
          ),
        );
        expect(
          () => calculate(
            [
              calculationIngredient(
                id: 'line-piece',
                foodId: 'food',
                quantity: pieces('1'),
                facts: {'protein': perMass},
              ),
            ],
            requestedNutrientIds: {'protein'},
          ),
          throwsA(isA<NutritionCalculationError>()),
        );
        expect(
          () => calculate(
            [
              calculationIngredient(
                id: 'line-serving-mismatch',
                foodId: 'food',
                quantity: Quantity.serving(
                  amount: '1',
                  definition: const ServingDefinitionReference(
                    id: 'other-serving',
                    revision: 'v1',
                  ),
                ),
                facts: {'protein': perServing},
              ),
            ],
            requestedNutrientIds: {'protein'},
          ),
          throwsA(isA<NutritionCalculationError>()),
        );
      },
    );

    test('raw/cooked context is not transformed by this calculator', () {
      final quantity = Quantity(
        amount: QuantityAmount.fromString('100'),
        unit: QuantityUnit.gram,
        context: const QuantityContext(
          conversion: QuantityConversionContext(
            foodIdentityId: 'food-raw',
            yieldTransformationId: 'raw-cooked-rule-v1',
            preparationState: QuantityPreparationState.raw,
          ),
        ),
      );
      final result = calculate(
        [
          calculationIngredient(
            id: 'line-raw',
            foodId: 'food-raw',
            quantity: quantity,
            facts: {'protein': per100GramsFact('protein', '10')},
          ),
        ],
        requestedNutrientIds: {'protein'},
      );

      expect(result.facts['protein']!.point!.value.toString(), '10');
      expect(result.lineage.toJson()['ingredients'], isNotEmpty);
    });

    test('nested recipes are rejected as an explicit out-of-scope failure', () {
      final request = calculationRequest(
        ingredients: [
          NutritionCalculationIngredient.nestedRecipe(
            id: 'nested-line',
            recipeVersionId: 'nested-v1',
            quantity: grams('100'),
          ),
        ],
        requestedNutrientIds: {'protein'},
      );

      expect(
        () => const NutritionCalculationService().calculate(request),
        throwsA(
          isA<NutritionCalculationError>().having(
            (error) => error.code,
            'code',
            NutritionCalculationErrorCode.unsupportedNestedRecipe,
          ),
        ),
      );
    });

    test(
      'invalid graph and missing recipe version fail before calculation',
      () {
        final validIngredient = calculationIngredient(
          id: 'line-1',
          foodId: 'food',
          quantity: grams('100'),
          facts: {'protein': per100GramsFact('protein', '1')},
        );
        final registry = calculationRegistry();
        final missingVersion = NutritionCalculationRequest(
          recipeId: 'recipe-1',
          recipeVersionId: '',
          ingredients: [validIngredient],
          registry: registry,
          nutrientRegistryVersion: registry.version,
          calculationRuleVersion: 'v1',
          requestedNutrientIds: {'protein'},
        );
        final duplicateLines = calculationRequest(
          ingredients: [validIngredient, validIngredient],
          requestedNutrientIds: {'protein'},
        );

        expect(
          () => const NutritionCalculationService().calculate(missingVersion),
          throwsA(
            isA<NutritionCalculationError>().having(
              (error) => error.code,
              'code',
              NutritionCalculationErrorCode.missingRecipeVersion,
            ),
          ),
        );
        expect(
          () => const NutritionCalculationService().calculate(duplicateLines),
          throwsA(isA<NutritionCalculationError>()),
        );
      },
    );
  });

  group('B03-08 scaling and lineage', () {
    test('positive scalar scaling works and preserves provenance', () {
      final whole = calculate(
        [
          calculationIngredient(
            id: 'line-1',
            foodId: 'food',
            quantity: grams('100'),
            facts: {
              'protein': per100GramsFact(
                'protein',
                '10',
                source: NutrientSourceType.userEntered,
              ),
            },
          ),
        ],
        requestedNutrientIds: {'protein'},
      );
      final scaled = calculate(
        [
          calculationIngredient(
            id: 'line-1',
            foodId: 'food',
            quantity: grams('100'),
            facts: {
              'protein': per100GramsFact(
                'protein',
                '10',
                source: NutrientSourceType.userEntered,
              ),
            },
          ),
        ],
        requestedNutrientIds: {'protein'},
        scale: NutritionScaleRequest.scalar('2'),
      );

      expect(scaled.facts['protein']!.point!.value.toString(), '20');
      expect(scaled.facts['protein']!.source, whole.facts['protein']!.source);
      expect(
        scaled.facts['protein']!.factVersion,
        whole.facts['protein']!.factVersion,
      );
      expect(scaled.completeness.state, whole.completeness.state);
      expect(scaled.scalingBasis, NutritionScaleKind.scalar);
    });

    test('zero and negative scales fail with typed invalid-scale errors', () {
      final ingredient = calculationIngredient(
        id: 'line-1',
        foodId: 'food',
        quantity: grams('100'),
        facts: {'protein': per100GramsFact('protein', '10')},
      );
      expect(
        () => calculate(
          [ingredient],
          requestedNutrientIds: {'protein'},
          scale: NutritionScaleRequest.scalar(QuantityAmount.zero),
        ),
        throwsA(
          isA<NutritionCalculationError>().having(
            (error) => error.code,
            'code',
            NutritionCalculationErrorCode.invalidScale,
          ),
        ),
      );
      expect(
        () => NutritionScaleRequest.scalar('-1'),
        throwsA(
          isA<NutritionCalculationError>().having(
            (error) => error.code,
            'code',
            NutritionCalculationErrorCode.invalidScale,
          ),
        ),
      );
    });

    test(
      'per-serving division requires and uses an explicit serving count',
      () {
        final ingredient = calculationIngredient(
          id: 'line-1',
          foodId: 'food',
          quantity: grams('100'),
          facts: {'protein': per100GramsFact('protein', '20')},
        );
        final serving = NutritionCalculationServingDefinition(
          id: 'recipe-serving',
          revision: 'v1',
          count: QuantityAmount.fromString('4'),
        );
        final result = calculate(
          [ingredient],
          requestedNutrientIds: {'protein'},
          servingDefinition: serving,
          scale: const NutritionScaleRequest.perDeclaredServing(),
        );

        expect(result.facts['protein']!.point!.value.toString(), '5');
        expect(result.scalingBasis, NutritionScaleKind.perDeclaredServing);
        expect(result.lineage.toJson()['serving_definition'], isNotNull);
        expect(
          () => calculate(
            [ingredient],
            requestedNutrientIds: {'protein'},
            scale: const NutritionScaleRequest.perDeclaredServing(),
          ),
          throwsA(
            isA<NutritionCalculationError>().having(
              (error) => error.code,
              'code',
              NutritionCalculationErrorCode.missingServingDefinition,
            ),
          ),
        );
      },
    );

    test(
      'requested fraction and requested yield scale only with explicit context',
      () {
        final ingredient = calculationIngredient(
          id: 'line-1',
          foodId: 'food',
          quantity: grams('100'),
          facts: {'protein': per100GramsFact('protein', '20')},
        );
        final fraction = calculate(
          [ingredient],
          requestedNutrientIds: {'protein'},
          scale: NutritionScaleRequest.fraction('0.25'),
        );
        final yield = calculate(
          [ingredient],
          requestedNutrientIds: {'protein'},
          declaredYield: grams('100'),
          scale: NutritionScaleRequest.requestedYield(grams('250')),
        );

        expect(fraction.facts['protein']!.point!.value.toString(), '5');
        expect(yield.facts['protein']!.point!.value.toString(), '50');
        expect(yield.scalingBasis, NutritionScaleKind.requestedYield);
        expect(
          () => calculate(
            [ingredient],
            requestedNutrientIds: {'protein'},
            scale: NutritionScaleRequest.requestedYield(grams('250')),
          ),
          throwsA(
            isA<NutritionCalculationError>().having(
              (error) => error.code,
              'code',
              NutritionCalculationErrorCode.missingRecipeYield,
            ),
          ),
        );
      },
    );

    test('yield scaling rejects mass-volume conversion without density', () {
      final ingredient = calculationIngredient(
        id: 'line-1',
        foodId: 'food',
        quantity: grams('100'),
        facts: {'protein': per100GramsFact('protein', '20')},
      );

      expect(
        () => calculate(
          [ingredient],
          requestedNutrientIds: {'protein'},
          declaredYield: grams('100'),
          scale: NutritionScaleRequest.requestedYield(millilitres('250')),
        ),
        throwsA(
          isA<NutritionCalculationError>()
              .having(
                (error) => error.code,
                'code',
                NutritionCalculationErrorCode.missingDensity,
              )
              .having((error) => error.missingContext, 'context', 'density'),
        ),
      );
    });

    test(
      'scaling preserves unknown completeness and does not mutate inputs',
      () {
        final quantity = grams('100');
        final ingredient = calculationIngredient(
          id: 'line-1',
          foodId: 'food',
          quantity: quantity,
          facts: const {},
        );
        final request = calculationRequest(
          ingredients: [ingredient],
          requestedNutrientIds: {'protein'},
          scale: NutritionScaleRequest.scalar('3'),
        );
        final result = const NutritionCalculationService().calculate(request);

        expect(result.completeness.state, NutrientCompletenessState.unknown);
        expect(result.facts['protein']!.status, NutrientFactStatus.missing);
        expect(result.facts['protein']!.source, NutrientSourceType.unknown);
        expect(quantity.amount.toString(), '100');
        expect(request.ingredients.single.quantity.amount.toString(), '100');
      },
    );

    test('lineage fingerprint is stable for identical immutable inputs', () {
      final ingredient = calculationIngredient(
        id: 'line-1',
        foodId: 'food',
        quantity: grams('100'),
        facts: {
          'protein': per100GramsFact(
            'protein',
            '1.2344',
            factVersion: 'catalogue-v7',
          ),
        },
      );
      final first = calculate([ingredient], requestedNutrientIds: {'protein'});
      final second = calculate([ingredient], requestedNutrientIds: {'protein'});

      expect(first.lineage.fingerprint, second.lineage.fingerprint);
      expect(first.toJson(), second.toJson());
    });

    test('no database mutation is possible at the pure service boundary', () {
      final result = calculate(
        [
          calculationIngredient(
            id: 'line-1',
            foodId: 'food',
            quantity: grams('100'),
            facts: {'protein': per100GramsFact('protein', '10')},
          ),
        ],
        requestedNutrientIds: {'protein'},
      );

      expect(result, isA<NutritionCalculationResult>());
      expect(result.lineage.toJson()['recipe_version_id'], 'recipe-1-v1');
    });
  });
}
