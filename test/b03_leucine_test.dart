import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/nutrition_protein_distribution.dart';
import 'package:indifit/core/typed_quantities.dart';

void main() {
  late NutrientRegistry registry;
  const service = NutritionProteinDistributionService();

  setUp(() {
    registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
  });

  test('explicit reviewed leucine is shown as measured or reviewed', () {
    final result = service.build(
      registry: registry,
      userId: 'user-1',
      localDate: '2026-08-04',
      records: [
        _record(
          id: 'reviewed-leucine',
          items: [
            _item(
              id: 'reviewed-item',
              facts: {
                'protein': _known('protein', '20'),
                'leucine': _known('leucine', '1.5'),
              },
            ),
          ],
        ),
      ],
    );

    expect(
      result.leucineAvailability,
      NutritionLeucineAvailability.measuredOrReviewed,
    );
    expect(result.totalLeucine.pointText, '1.50');
    expect(
      result.totalLeucine.sources,
      contains(NutrientSourceType.reviewedCatalogue),
    );
  });

  test('estimated leucine stays estimated and preserves its range', () {
    final result = service.build(
      registry: registry,
      userId: 'user-1',
      localDate: '2026-08-04',
      records: [
        _record(
          id: 'estimated-leucine',
          items: [
            _item(
              id: 'estimated-item',
              facts: {
                'protein': _known('protein', '20'),
                'leucine': _estimated('leucine', '1', '0.8', '1.2'),
              },
            ),
          ],
        ),
      ],
    );

    expect(result.leucineAvailability, NutritionLeucineAvailability.estimated);
    expect(result.totalLeucine.pointText, '1.00');
    expect(result.totalLeucine.lowerText, '0.80');
    expect(result.totalLeucine.upperText, '1.20');
  });

  test(
    'missing leucine is unknown and is never inferred from protein or names',
    () {
      final result = service.build(
        registry: registry,
        userId: 'user-1',
        localDate: '2026-08-04',
        records: [
          _record(
            id: 'protein-only',
            items: [
              _item(
                id: 'named-protein-item',
                label: 'High leucine protein food',
                facts: {'protein': _known('protein', '30')},
              ),
            ],
          ),
        ],
      );

      expect(result.leucineAvailability, NutritionLeucineAvailability.unknown);
      expect(result.totalLeucine.pointText, isNull);
      expect(
        result.totalLeucine.completeness.state,
        NutrientCompletenessState.unknown,
      );
    },
  );
}

NutrientFact _known(String nutrientId, String value) => NutrientFact.known(
  nutrientId: nutrientId,
  point: NutrientAmount(
    value: QuantityAmount.fromString(value),
    unit: NutrientUnit.gram,
  ),
  basis: NutrientBasis(NutrientBasisKind.absolute),
  source: NutrientSourceType.reviewedCatalogue,
  factVersion: 'leucine-test-v1',
);

NutrientFact _estimated(
  String nutrientId,
  String point,
  String lower,
  String upper,
) => NutrientFact.estimated(
  nutrientId: nutrientId,
  point: NutrientAmount(
    value: QuantityAmount.fromString(point),
    unit: NutrientUnit.gram,
  ),
  lower: NutrientAmount(
    value: QuantityAmount.fromString(lower),
    unit: NutrientUnit.gram,
  ),
  upper: NutrientAmount(
    value: QuantityAmount.fromString(upper),
    unit: NutrientUnit.gram,
  ),
  basis: NutrientBasis(NutrientBasisKind.absolute),
  source: NutrientSourceType.aiEstimate,
  factVersion: 'leucine-estimate-v1',
);

NutritionHistoricalReadItem _item({
  required String id,
  required Map<String, NutrientFact> facts,
  String? label,
}) {
  final quantity = Quantity.fromDecimal(amount: '1', unit: QuantityUnit.gram);
  return NutritionHistoricalReadItem(
    stableId: id,
    position: 0,
    sourceType: NutritionHistoricalSourceType.canonicalSnapshot.stableId,
    originSourceType: 'direct_food',
    displayLabel: label ?? id,
    foodId: id,
    recipeVersionId: null,
    quantity: NutritionHistoricalQuantity(
      storedAmount: 1,
      storedUnit: quantity.definition.stableId,
      quantity: quantity,
      state: NutritionHistoricalQuantityState.typed,
      issues: const [],
    ),
    facts: facts,
    issues: const [],
  );
}

_TestRecord _record({
  required String id,
  required List<NutritionHistoricalReadItem> items,
}) => _TestRecord(stableId: id, items: items);

class _TestRecord implements NutritionHistoricalReadRecord {
  @override
  final String stableId;
  @override
  final List<NutritionHistoricalReadItem> items;

  _TestRecord({required this.stableId, required this.items});

  @override
  String get userId => 'user-1';

  @override
  String get sourceType =>
      NutritionHistoricalSourceType.canonicalSnapshot.stableId;

  @override
  DateTime get loggedAtUtc => DateTime.utc(2026, 8, 4, 12);

  @override
  String get localDate => '2026-08-04';

  @override
  String get mealCategory => 'lunch';

  @override
  String? get mealGroupId => null;

  @override
  String get displayLabel => stableId;

  @override
  NutrientCompleteness get completeness => NutrientCompleteness(
    state: NutrientCompletenessState.partial,
    requestedNutrientIds: const ['protein', 'leucine'],
    availableNutrientIds: const [],
    missingNutrientIds: const ['protein', 'leucine'],
    estimatedNutrientIds: const [],
    notApplicableNutrientIds: const [],
    partiallyKnownNutrientIds: const [],
  );

  @override
  NutrientAggregationResult get totals => NutrientAggregationService.aggregate(
    registry: NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    ),
    contributions: items.expand(
      (item) =>
          item.facts.values.map((fact) => NutrientContribution(fact: fact)),
    ),
  );

  @override
  List<NutritionCompatibilityIssue> get issues => const [];

  @override
  bool get isLegacy => false;
}
