import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/legacy_nutrient_adapter.dart';
import 'package:indifit/core/nutrients.dart';

void main() {
  test('nutrient contract exposes stable source and status identifiers', () {
    expect(NutrientFactStatus.knownZero.stableId, 'known_zero');
    expect(NutrientFactStatus.notApplicable.stableId, 'not_applicable');
    expect(NutrientSourceType.importedProvider.stableId, 'imported_provider');
    expect(NutrientSourceType.aiEstimate.stableId, 'ai_estimate');
    expect(NutrientBasisKind.per100Grams.stableId, 'per_100_grams');
  });

  test(
    'negative and non-finite legacy values are recoverable nutrient failures',
    () {
      final registry = NutrientRegistry.fromAssetFileSync(
        'assets/data/nutrient_registry.json',
      );
      final basis = NutrientBasis(NutrientBasisKind.absolute);

      expect(
        () => LegacyNutrientAdapter.adapt(
          registry: registry,
          nutrientId: 'protein',
          value: -1,
          unit: NutrientUnit.gram,
          basis: basis,
        ),
        throwsA(isA<NutrientValidationError>()),
      );
      expect(
        () => LegacyNutrientAdapter.adapt(
          registry: registry,
          nutrientId: 'protein',
          value: double.infinity,
          unit: NutrientUnit.gram,
          basis: basis,
        ),
        throwsA(isA<NutrientValidationError>()),
      );
      expect(registry.definitionFor('protein').id, 'protein');
    },
  );
}
