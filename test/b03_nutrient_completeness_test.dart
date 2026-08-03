import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/typed_quantities.dart';

void main() {
  test('requested nutrient completeness reports missing IDs and estimates', () {
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    final facts = <String, NutrientFact>{
      'protein': NutrientFact.known(
        nutrientId: 'protein',
        point: NutrientAmount(
          value: QuantityAmount.fromString('20'),
          unit: NutrientUnit.gram,
        ),
        basis: NutrientBasis(NutrientBasisKind.absolute),
        source: NutrientSourceType.reviewedCatalogue,
      ),
      'fat': NutrientFact.estimated(
        nutrientId: 'fat',
        point: NutrientAmount(
          value: QuantityAmount.fromString('8'),
          unit: NutrientUnit.gram,
        ),
        basis: NutrientBasis(NutrientBasisKind.absolute),
        source: NutrientSourceType.aiEstimate,
      ),
    };
    final completeness = NutrientCompletenessEvaluator.evaluate(
      registry: registry,
      facts: facts,
      requestedNutrientIds: {'protein', 'fat', 'fibre'},
    );

    expect(completeness.state, NutrientCompletenessState.partial);
    expect(completeness.estimatedNutrientIds, contains('fat'));
    expect(completeness.missingNutrientIds, contains('fibre'));
  });

  test('invalid completeness states cannot be deserialized', () {
    final invalid = <String, dynamic>{
      'state': 'complete-ish',
      'requested': <String>[],
      'available': <String>[],
      'missing': <String>[],
      'estimated': <String>[],
      'not_applicable': <String>[],
      'partially_known': <String>[],
    };
    expect(
      () => NutrientCompleteness.fromJson(invalid),
      throwsA(isA<NutrientValidationError>()),
    );
  });
}
