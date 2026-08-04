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

  test('known protein aggregates by explicit meal group deterministically', () {
    final breakfastOne = _record(
      registry,
      id: 'snapshot-b',
      loggedAtUtc: DateTime.utc(2026, 8, 4, 7, 30),
      mealCategory: 'breakfast',
      mealGroupId: 'group-breakfast',
      items: [_item('item-b', protein: _known('12'))],
    );
    final breakfastTwo = _record(
      registry,
      id: 'snapshot-a',
      loggedAtUtc: DateTime.utc(2026, 8, 4, 7),
      mealCategory: 'breakfast',
      mealGroupId: 'group-breakfast',
      items: [_item('item-a', protein: _known('8'))],
    );
    final lunch = _record(
      registry,
      id: 'snapshot-lunch',
      loggedAtUtc: DateTime.utc(2026, 8, 4, 13),
      mealCategory: 'lunch',
      items: [_item('item-lunch', protein: _known('20'))],
    );

    final first = service.build(
      registry: registry,
      userId: 'user-1',
      localDate: '2026-08-04',
      records: [breakfastOne, lunch, breakfastTwo],
    );
    final reordered = service.build(
      registry: registry,
      userId: 'user-1',
      localDate: '2026-08-04',
      records: [breakfastTwo, breakfastOne, lunch],
    );

    expect(first.meals, hasLength(2));
    expect(first.meals.first.mealGroupId, 'group-breakfast');
    expect(first.meals.first.protein.pointText, '20.0');
    expect(first.meals.last.mealCategory, 'lunch');
    expect(first.knownProtein.pointText, '40.0');
    expect(first.meals.first.distributionPercentageText, '50.0');
    expect(first.meals.last.distributionPercentageText, '50.0');
    expect(first.toJson(), reordered.toJson());
    expect(first.fingerprint, reordered.fingerprint);
  });

  test('known zero remains known and zero total has no percentage', () {
    final distribution = service.build(
      registry: registry,
      userId: 'user-1',
      localDate: '2026-08-04',
      records: [
        _record(
          registry,
          id: 'zero',
          loggedAtUtc: DateTime.utc(2026, 8, 4, 8),
          mealCategory: 'breakfast',
          items: [_item('zero-item', protein: _knownZero())],
        ),
      ],
    );

    expect(
      distribution.totalProtein.fact!.status,
      NutrientFactStatus.knownZero,
    );
    expect(distribution.totalProtein.pointText, '0.0');
    expect(
      distribution.totalProtein.completeness.state,
      NutrientCompletenessState.complete,
    );
    expect(distribution.percentagesAvailable, isFalse);
    expect(distribution.percentageUnavailableReason, 'zero_known_total');
    expect(distribution.meals.single.distributionPercentage, isNull);
  });

  test(
    'distribution percentages use known values and the display rounding policy',
    () {
      final distribution = service.build(
        registry: registry,
        userId: 'user-1',
        localDate: '2026-08-04',
        records: [
          _record(
            registry,
            id: 'one',
            loggedAtUtc: DateTime.utc(2026, 8, 4, 8),
            mealCategory: 'breakfast',
            items: [_item('one-item', protein: _known('1'))],
          ),
          _record(
            registry,
            id: 'two',
            loggedAtUtc: DateTime.utc(2026, 8, 4, 12),
            mealCategory: 'lunch',
            items: [_item('two-item', protein: _known('2'))],
          ),
        ],
      );

      expect(distribution.percentagesAvailable, isTrue);
      expect(distribution.meals[0].distributionPercentageText, '33.3');
      expect(distribution.meals[1].distributionPercentageText, '66.7');
      expect(
        distribution.meals
            .map((meal) => meal.distributionPercentage!)
            .reduce((left, right) => left + right)
            .format(decimalPlaces: 1),
        '100.0',
      );
    },
  );

  test('pure service ignores records owned by another user', () {
    final distribution = service.build(
      registry: registry,
      userId: 'user-1',
      localDate: '2026-08-04',
      records: [
        _record(
          registry,
          id: 'owned',
          loggedAtUtc: DateTime.utc(2026, 8, 4, 8),
          mealCategory: 'breakfast',
          items: [_item('owned-item', protein: _known('4'))],
        ),
        _record(
          registry,
          id: 'other-user',
          loggedAtUtc: DateTime.utc(2026, 8, 4, 9),
          mealCategory: 'lunch',
          items: [_item('other-item', protein: _known('99'))],
          userId: 'user-2',
        ),
      ],
    );

    expect(distribution.totalProtein.pointText, '4.0');
    expect(distribution.recordIds, ['owned']);
  });

  test('duplicate history records do not double-count a meal', () {
    final record = _record(
      registry,
      id: 'duplicate',
      loggedAtUtc: DateTime.utc(2026, 8, 4, 8),
      mealCategory: 'breakfast',
      items: [_item('duplicate-item', protein: _known('9'))],
    );
    final distribution = service.build(
      registry: registry,
      userId: 'user-1',
      localDate: '2026-08-04',
      records: [record, record],
    );

    expect(distribution.totalProtein.pointText, '9.0');
    expect(distribution.recordIds, ['duplicate']);
  });

  test(
    'known plus unknown remains partial without converting unknown to zero',
    () {
      final distribution = service.build(
        registry: registry,
        userId: 'user-1',
        localDate: '2026-08-04',
        records: [
          _record(
            registry,
            id: 'known',
            loggedAtUtc: DateTime.utc(2026, 8, 4, 8),
            mealCategory: 'breakfast',
            items: [_item('known-item', protein: _known('20'))],
          ),
          _record(
            registry,
            id: 'unknown',
            loggedAtUtc: DateTime.utc(2026, 8, 4, 12),
            mealCategory: 'lunch',
            items: [_item('unknown-item')],
          ),
        ],
      );

      expect(distribution.totalProtein.pointText, '20.0');
      expect(
        distribution.totalProtein.completeness.state,
        NutrientCompletenessState.partial,
      );
      expect(distribution.unknownProteinItemCount, 1);
      expect(distribution.hasUnknownProtein, isTrue);
      expect(distribution.knownProtein.pointText, '20.0');
      expect(distribution.percentagesAvailable, isTrue);
      expect(distribution.meals.first.distributionPercentageText, '100.0');
      expect(distribution.meals.last.distributionPercentage, isNull);
    },
  );

  test('estimated protein ranges aggregate and remain estimated', () {
    final distribution = service.build(
      registry: registry,
      userId: 'user-1',
      localDate: '2026-08-04',
      records: [
        _record(
          registry,
          id: 'estimate-a',
          loggedAtUtc: DateTime.utc(2026, 8, 4, 9),
          mealCategory: 'breakfast',
          items: [_item('estimate-a-item', protein: _estimated('7', '5', '9'))],
        ),
        _record(
          registry,
          id: 'estimate-b',
          loggedAtUtc: DateTime.utc(2026, 8, 4, 13),
          mealCategory: 'lunch',
          items: [_item('estimate-b-item', protein: _estimated('3', '2', '4'))],
        ),
      ],
    );

    expect(
      distribution.totalProtein.fact!.status,
      NutrientFactStatus.estimated,
    );
    expect(distribution.totalProtein.pointText, '10.0');
    expect(distribution.totalProtein.lowerText, '7.0');
    expect(distribution.totalProtein.upperText, '13.0');
    expect(distribution.estimatedProteinItemCount, 2);
    expect(distribution.percentagesAvailable, isFalse);
  });

  test('explicit leucine remains separate from estimated and unknown data', () {
    final distribution = service.build(
      registry: registry,
      userId: 'user-1',
      localDate: '2026-08-04',
      records: [
        _record(
          registry,
          id: 'measured',
          loggedAtUtc: DateTime.utc(2026, 8, 4, 9),
          mealCategory: 'breakfast',
          items: [
            _item(
              'measured-item',
              protein: _known('10'),
              leucine: _known('1.2', nutrientId: nutritionLeucineNutrientId),
            ),
          ],
        ),
        _record(
          registry,
          id: 'estimated',
          loggedAtUtc: DateTime.utc(2026, 8, 4, 13),
          mealCategory: 'lunch',
          items: [
            _item(
              'estimated-item',
              protein: _known('10'),
              leucine: _estimated(
                '0.8',
                '0.6',
                '1',
                nutrientId: nutritionLeucineNutrientId,
              ),
            ),
          ],
        ),
        _record(
          registry,
          id: 'unknown-leucine',
          loggedAtUtc: DateTime.utc(2026, 8, 4, 19),
          mealCategory: 'dinner',
          items: [_item('unknown-leucine-item', protein: _known('10'))],
        ),
      ],
    );

    expect(
      distribution.leucineAvailability,
      NutritionLeucineAvailability.mixed,
    );
    expect(distribution.totalLeucine.pointText, '2.00');
    expect(
      distribution.totalLeucine.completeness.state,
      NutrientCompletenessState.partial,
    );
    expect(
      distribution.totalLeucine.sources,
      contains(NutrientSourceType.reviewedCatalogue),
    );
    expect(
      distribution.totalLeucine.sources,
      contains(NutrientSourceType.aiEstimate),
    );
    expect(distribution.meals.last.unknownLeucineItemCount, 1);
  });

  test(
    'leucine is explicitly unavailable when the registry does not support it',
    () {
      final withoutLeucine = NutrientRegistry(
        version: registry.version,
        definitions: registry.definitions.where(
          (definition) => definition.id != nutritionLeucineNutrientId,
        ),
      );
      final distribution = service.build(
        registry: withoutLeucine,
        userId: 'user-1',
        localDate: '2026-08-04',
        records: [
          _record(
            withoutLeucine,
            id: 'protein-only',
            loggedAtUtc: DateTime.utc(2026, 8, 4, 9),
            mealCategory: 'breakfast',
            items: [_item('protein-only-item', protein: _known('10'))],
          ),
        ],
      );

      expect(
        distribution.leucineAvailability,
        NutritionLeucineAvailability.unavailable,
      );
      expect(distribution.totalLeucine.unitSymbol, isNull);
    },
  );

  test('empty day is explicit and does not fabricate a zero total', () {
    final distribution = service.build(
      registry: registry,
      userId: 'user-1',
      localDate: '2026-08-04',
      records: const [],
    );

    expect(distribution.isEmpty, isTrue);
    expect(distribution.meals, isEmpty);
    expect(distribution.totalProtein.pointText, isNull);
    expect(
      distribution.totalProtein.completeness.state,
      NutrientCompletenessState.unknown,
    );
    expect(distribution.percentageUnavailableReason, 'empty_day');
  });
}

NutrientFact _known(
  String value, {
  NutrientSourceType source = NutrientSourceType.reviewedCatalogue,
  String nutrientId = nutritionProteinNutrientId,
}) => NutrientFact.known(
  nutrientId: nutrientId,
  point: NutrientAmount(
    value: QuantityAmount.fromString(value),
    unit: NutrientUnit.gram,
  ),
  basis: NutrientBasis(NutrientBasisKind.absolute),
  source: source,
  factVersion: 'fact-v1',
);

NutrientFact _knownZero() => NutrientFact.knownZero(
  nutrientId: nutritionProteinNutrientId,
  unit: NutrientUnit.gram,
  basis: NutrientBasis(NutrientBasisKind.absolute),
  source: NutrientSourceType.reviewedCatalogue,
  factVersion: 'fact-v1',
);

NutrientFact _estimated(
  String point,
  String lower,
  String upper, {
  String nutrientId = nutritionProteinNutrientId,
}) => NutrientFact.estimated(
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
  factVersion: 'estimate-v1',
);

NutritionHistoricalReadItem _item(
  String id, {
  NutrientFact? protein,
  NutrientFact? leucine,
}) {
  final quantity = Quantity.fromDecimal(amount: '1', unit: QuantityUnit.gram);
  final itemFacts = <String, NutrientFact>{};
  if (protein != null) itemFacts[nutritionProteinNutrientId] = protein;
  if (leucine != null) itemFacts[nutritionLeucineNutrientId] = leucine;
  return NutritionHistoricalReadItem(
    stableId: id,
    position: 0,
    sourceType: NutritionHistoricalSourceType.canonicalSnapshot.stableId,
    originSourceType: 'direct_food',
    displayLabel: id,
    foodId: id,
    recipeVersionId: null,
    quantity: NutritionHistoricalQuantity(
      storedAmount: 1,
      storedUnit: quantity.definition.stableId,
      quantity: quantity,
      state: NutritionHistoricalQuantityState.typed,
      issues: const [],
    ),
    facts: itemFacts,
    issues: const [],
  );
}

_TestHistoricalRecord _record(
  NutrientRegistry registry, {
  required String id,
  required DateTime loggedAtUtc,
  required String mealCategory,
  String? mealGroupId,
  required List<NutritionHistoricalReadItem> items,
  String userId = 'user-1',
}) => _TestHistoricalRecord(
  stableId: id,
  userId: userId,
  loggedAtUtc: loggedAtUtc,
  localDate: '2026-08-04',
  mealCategory: mealCategory,
  mealGroupId: mealGroupId,
  items: items,
  registry: registry,
);

class _TestHistoricalRecord implements NutritionHistoricalReadRecord {
  @override
  final String stableId;
  @override
  final String userId;
  @override
  final DateTime loggedAtUtc;
  @override
  final String localDate;
  @override
  final String mealCategory;
  @override
  final String? mealGroupId;
  @override
  final List<NutritionHistoricalReadItem> items;
  @override
  final NutrientCompleteness completeness;
  @override
  final NutrientAggregationResult totals;

  _TestHistoricalRecord({
    required this.stableId,
    required this.userId,
    required this.loggedAtUtc,
    required this.localDate,
    required this.mealCategory,
    required this.mealGroupId,
    required this.items,
    required NutrientRegistry registry,
  }) : completeness = NutrientCompleteness(
         state: NutrientCompletenessState.partial,
         requestedNutrientIds: const [nutritionProteinNutrientId],
         availableNutrientIds: const [],
         missingNutrientIds: const [nutritionProteinNutrientId],
         estimatedNutrientIds: const [],
         notApplicableNutrientIds: const [],
         partiallyKnownNutrientIds: const [],
       ),
       totals = NutrientAggregationService.aggregate(
         registry: registry,
         contributions: items.expand(
           (item) => item.facts.values.map(
             (fact) => NutrientContribution(fact: fact),
           ),
         ),
       );

  @override
  String get displayLabel => mealCategory;

  @override
  List<NutritionCompatibilityIssue> get issues => const [];

  @override
  String get sourceType =>
      NutritionHistoricalSourceType.canonicalSnapshot.stableId;

  @override
  bool get isLegacy => false;
}
