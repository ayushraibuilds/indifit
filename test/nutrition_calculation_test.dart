import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/typed_quantities.dart';

void main() {
  test(
    'authoritative nutrient aggregation preserves lineage deterministically',
    () {
      final registry = NutrientRegistry.fromAssetFileSync(
        'assets/data/nutrient_registry.json',
      );
      NutrientFact fact(String value, NutrientSourceType source) =>
          NutrientFact.known(
            nutrientId: 'protein',
            point: NutrientAmount(
              value: QuantityAmount.fromString(value),
              unit: NutrientUnit.gram,
            ),
            basis: NutrientBasis(NutrientBasisKind.absolute),
            source: source,
            factVersion: '1',
          );

      final result = NutrientAggregationService.aggregate(
        registry: registry,
        contributions: [
          NutrientContribution(fact: fact('2', NutrientSourceType.userEntered)),
          NutrientContribution(
            fact: fact('3', NutrientSourceType.reviewedCatalogue),
          ),
        ],
        requestedNutrientIds: {'protein'},
      );

      expect(result.facts['protein']!.point!.value.toString(), '5');
      expect(
        result.sourceLineage['protein']!.map((source) => source.stableId),
        ['reviewed_catalogue', 'user_entered'],
      );
      expect(result.facts['protein']!.source, NutrientSourceType.unknown);
    },
  );
}
