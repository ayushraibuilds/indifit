import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/typed_quantities.dart';

NutrientRegistry factsRegistry() =>
    NutrientRegistry.fromAssetFileSync('assets/data/nutrient_registry.json');

NutrientBasis absoluteBasis() => NutrientBasis(NutrientBasisKind.absolute);

NutrientAmount amount(String value, NutrientUnit unit) =>
    NutrientAmount(value: QuantityAmount.fromString(value), unit: unit);

void main() {
  test('known zero, missing and estimated are distinct fact states', () {
    final zero = NutrientFact.knownZero(
      nutrientId: 'protein',
      unit: NutrientUnit.gram,
      basis: absoluteBasis(),
      source: NutrientSourceType.reviewedCatalogue,
    );
    final missing = NutrientFact.missing(
      nutrientId: 'protein',
      unit: NutrientUnit.gram,
      basis: absoluteBasis(),
      source: NutrientSourceType.legacy,
    );
    final estimated = NutrientFact.estimated(
      nutrientId: 'protein',
      point: amount('8', NutrientUnit.gram),
      basis: absoluteBasis(),
      source: NutrientSourceType.aiEstimate,
    );

    expect(zero.status, NutrientFactStatus.knownZero);
    expect(zero.point!.value.isZero, isTrue);
    expect(missing.point, isNull);
    expect(estimated.status, NutrientFactStatus.estimated);
    expect(estimated.source, NutrientSourceType.aiEstimate);
  });

  test('invalid ranges and units fail validation', () {
    expect(
      () => NutrientFact(
        nutrientId: 'protein',
        unit: NutrientUnit.gram,
        status: NutrientFactStatus.known,
        point: amount('5', NutrientUnit.gram),
        lower: amount('6', NutrientUnit.gram),
        basis: absoluteBasis(),
        source: NutrientSourceType.reviewedCatalogue,
        factVersion: '1',
      ),
      throwsA(isA<NutrientValidationError>()),
    );
    expect(
      () => NutrientFact(
        nutrientId: 'protein',
        unit: NutrientUnit.gram,
        status: NutrientFactStatus.known,
        point: amount('5', NutrientUnit.gram),
        upper: amount('6', NutrientUnit.milligram),
        basis: absoluteBasis(),
        source: NutrientSourceType.reviewedCatalogue,
        factVersion: '1',
      ),
      throwsA(isA<NutrientUnitMismatchError>()),
    );
  });

  test('registry canonical units are enforced', () {
    final fact = NutrientFact.known(
      nutrientId: 'sodium',
      point: amount('4', NutrientUnit.gram),
      basis: absoluteBasis(),
      source: NutrientSourceType.reviewedCatalogue,
    );
    expect(
      () => fact.validateAgainst(factsRegistry()),
      throwsA(isA<NutrientUnitMismatchError>()),
    );
  });

  test('per-100-gram and per-100-millilitre bases remain distinct', () {
    final protein = NutrientFact.known(
      nutrientId: 'protein',
      point: amount('20', NutrientUnit.gram),
      basis: NutrientBasis(NutrientBasisKind.per100Grams),
      source: NutrientSourceType.reviewedCatalogue,
    );
    final energy = NutrientFact.known(
      nutrientId: 'energy',
      point: amount('50', NutrientUnit.kilocalorie),
      basis: NutrientBasis(NutrientBasisKind.per100Millilitres),
      source: NutrientSourceType.reviewedCatalogue,
    );
    final grams = Quantity.fromDecimal(amount: '250', unit: QuantityUnit.gram);
    final millilitres = Quantity.fromDecimal(
      amount: '200',
      unit: QuantityUnit.millilitre,
    );

    expect(protein.scaleBy(grams).point!.value.toString(), '50');
    expect(energy.scaleBy(millilitres).point!.value.toString(), '100');
    expect(
      () => protein.scaleBy(millilitres),
      throwsA(isA<NutrientBasisMismatchError>()),
    );
  });

  test('per-serving facts require matching serving context', () {
    final definition = ServingDefinitionReference(
      id: 'food-serving',
      revision: '1',
    );
    final fact = NutrientFact.known(
      nutrientId: 'protein',
      point: amount('12', NutrientUnit.gram),
      basis: NutrientBasis(
        NutrientBasisKind.perServing,
        servingDefinition: definition,
      ),
      source: NutrientSourceType.reviewedCatalogue,
    );
    final matching = Quantity.serving(amount: '2', definition: definition);
    final other = Quantity.serving(
      amount: '2',
      definition: ServingDefinitionReference(id: 'other', revision: '1'),
    );

    expect(fact.scaleBy(matching).point!.value.toString(), '24');
    expect(
      () => fact.scaleBy(other),
      throwsA(isA<NutrientBasisMismatchError>()),
    );
  });

  test('serialization round-trips deterministically', () {
    final registry = factsRegistry();
    final fact = NutrientFact.estimated(
      nutrientId: 'protein',
      point: amount('8.25', NutrientUnit.gram),
      lower: amount('7', NutrientUnit.gram),
      upper: amount('9', NutrientUnit.gram),
      basis: absoluteBasis(),
      source: NutrientSourceType.aiEstimate,
      confidence: NutrientConfidence.medium,
      sourceReference: 'synthetic-estimate-1',
    );
    final restored = NutrientFact.fromJson(
      jsonDecode(fact.toJsonString()),
      registry,
    );

    expect(restored.toJsonString(), fact.toJsonString());
    expect(restored.displayPoint(registry), '8.3');
  });
}
