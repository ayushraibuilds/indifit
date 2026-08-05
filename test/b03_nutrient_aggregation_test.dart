import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/legacy_nutrient_adapter.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/typed_quantities.dart';

NutrientRegistry aggregationRegistry() =>
    NutrientRegistry.fromAssetFileSync('assets/data/nutrient_registry.json');

NutrientBasis aggregateBasis() => NutrientBasis(NutrientBasisKind.absolute);

NutrientAmount nutrientAmount(String value, NutrientUnit unit) =>
    NutrientAmount(value: QuantityAmount.fromString(value), unit: unit);

NutrientFact knownProtein(String value) => NutrientFact.known(
  nutrientId: 'protein',
  point: nutrientAmount(value, NutrientUnit.gram),
  basis: aggregateBasis(),
  source: NutrientSourceType.reviewedCatalogue,
);

void main() {
  test('known facts aggregate without intermediate rounding', () {
    final registry = aggregationRegistry();
    final result = NutrientAggregationService.aggregate(
      registry: registry,
      contributions: [
        NutrientContribution(fact: knownProtein('1.2344')),
        NutrientContribution(fact: knownProtein('2.3455')),
      ],
      requestedNutrientIds: {'protein'},
    );

    expect(result.facts['protein']!.point!.value.toString(), '3.5799');
    expect(result.displayValue('protein', registry), '3.6');
    expect(result.completeness.state, NutrientCompletenessState.complete);
  });

  test('known zero remains known and empty aggregation is unknown', () {
    final registry = aggregationRegistry();
    final zero = NutrientFact.knownZero(
      nutrientId: 'protein',
      unit: NutrientUnit.gram,
      basis: aggregateBasis(),
      source: NutrientSourceType.reviewedCatalogue,
    );
    final result = NutrientAggregationService.aggregate(
      registry: registry,
      contributions: [NutrientContribution(fact: zero)],
      requestedNutrientIds: {'protein'},
    );
    final empty = NutrientAggregationService.aggregate(
      registry: registry,
      contributions: const [],
      requestedNutrientIds: {'protein'},
    );

    expect(result.facts['protein']!.status, NutrientFactStatus.knownZero);
    expect(result.completeness.state, NutrientCompletenessState.complete);
    expect(empty.completeness.state, NutrientCompletenessState.unknown);
    expect(empty.completeness.missingNutrientIds, contains('protein'));
  });

  test('unknown coverage stays visible while known values aggregate', () {
    final registry = aggregationRegistry();
    final missing = NutrientFact.missing(
      nutrientId: 'protein',
      unit: NutrientUnit.gram,
      basis: aggregateBasis(),
      source: NutrientSourceType.legacy,
    );
    final result = NutrientAggregationService.aggregate(
      registry: registry,
      contributions: [
        NutrientContribution(fact: knownProtein('5')),
        NutrientContribution(fact: missing),
      ],
      requestedNutrientIds: {'protein'},
    );

    expect(result.facts['protein']!.point!.value.toString(), '5');
    expect(result.facts['protein']!.coverageIncomplete, isTrue);
    expect(result.completeness.state, NutrientCompletenessState.partial);
    expect(result.completeness.missingNutrientIds, contains('protein'));
  });

  test('mixed estimates retain estimated status and ranges aggregate', () {
    final registry = aggregationRegistry();
    final first = NutrientFact.estimated(
      nutrientId: 'protein',
      point: nutrientAmount('4', NutrientUnit.gram),
      lower: nutrientAmount('3', NutrientUnit.gram),
      upper: nutrientAmount('5', NutrientUnit.gram),
      basis: aggregateBasis(),
      source: NutrientSourceType.aiEstimate,
    );
    final second = NutrientFact.estimated(
      nutrientId: 'protein',
      point: nutrientAmount('6', NutrientUnit.gram),
      lower: nutrientAmount('5', NutrientUnit.gram),
      upper: nutrientAmount('7', NutrientUnit.gram),
      basis: aggregateBasis(),
      source: NutrientSourceType.aiEstimate,
    );
    final result = NutrientAggregationService.aggregate(
      registry: registry,
      contributions: [
        NutrientContribution(fact: first),
        NutrientContribution(fact: second),
      ],
      requestedNutrientIds: {'protein'},
    );

    final fact = result.facts['protein']!;
    expect(fact.status, NutrientFactStatus.estimated);
    expect(fact.point!.value.toString(), '10');
    expect(fact.lower!.value.toString(), '8');
    expect(fact.upper!.value.toString(), '12');
    expect(result.completeness.estimatedNutrientIds, contains('protein'));
  });

  test('basis and unit mismatches fail with typed errors', () {
    final registry = aggregationRegistry();
    final per100 = NutrientFact.known(
      nutrientId: 'protein',
      point: nutrientAmount('10', NutrientUnit.gram),
      basis: NutrientBasis(NutrientBasisKind.per100Grams),
      source: NutrientSourceType.reviewedCatalogue,
    );
    expect(
      () => NutrientAggregationService.aggregate(
        registry: registry,
        contributions: [NutrientContribution(fact: per100)],
        requestedNutrientIds: {'protein'},
      ),
      throwsA(isA<NutrientBasisMismatchError>()),
    );

    final wrongUnit = NutrientFact(
      nutrientId: 'sodium',
      unit: NutrientUnit.gram,
      status: NutrientFactStatus.known,
      point: nutrientAmount('1', NutrientUnit.gram),
      basis: aggregateBasis(),
      source: NutrientSourceType.reviewedCatalogue,
      factVersion: '1',
    );
    expect(
      () => NutrientAggregationService.aggregate(
        registry: registry,
        contributions: [NutrientContribution(fact: wrongUnit)],
      ),
      throwsA(isA<NutrientUnitMismatchError>()),
    );
  });

  test('legacy adapter preserves null, zero and values without mutation', () {
    final registry = aggregationRegistry();
    final original = <String, num?>{
      'calories': 100,
      'protein': 12.5,
      'fibre': null,
    };
    final adapted = LegacyNutrientAdapter.adaptMacros(
      registry: registry,
      calories: original['calories'],
      proteinG: original['protein'],
      carbohydrateG: 0,
      fatG: 4,
      fibreG: original['fibre'],
      basis: aggregateBasis(),
    );

    expect(adapted['energy']!.source, NutrientSourceType.legacy);
    expect(adapted['protein']!.point!.value.toString(), '12.5');
    expect(adapted['carbohydrate']!.status, NutrientFactStatus.knownZero);
    expect(adapted['fibre']!.status, NutrientFactStatus.missing);
    expect(original, {'calories': 100, 'protein': 12.5, 'fibre': null});
  });
}
