import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrition_constraints.dart';

void main() {
  final instant = DateTime.utc(2026, 8, 4, 10);

  test('taxonomy IDs are stable across cosmetic labels and registry order', () {
    final ids = NutritionConstraintTaxonomy.definitions
        .map((definition) => definition.id)
        .toSet();
    expect(ids, hasLength(8));
    expect(
      NutritionConstraintTaxonomy.definitions.reversed
          .map((definition) => definition.id)
          .toSet(),
      ids,
    );

    final allergy = NutritionConstraintTaxonomy.definitionForType(
      NutritionConstraintType.allergy,
    );
    final renamed = NutritionConstraintDefinition(
      id: allergy.id,
      key: allergy.key,
      type: allergy.type,
      displayName: 'Allergie',
      targetTypes: allergy.targetTypes,
      severitySupported: allergy.severitySupported,
      crossContactSupported: allergy.crossContactSupported,
      version: allergy.version,
    );
    expect(
      () => NutritionConstraintTaxonomy.validateDefinition(renamed),
      returnsNormally,
    );
  });

  test('taxonomy rejects duplicate IDs and unsupported versions', () {
    final allergy = NutritionConstraintTaxonomy.definitionForType(
      NutritionConstraintType.allergy,
    );
    expect(
      () => NutritionConstraintTaxonomy.validateRegistry([
        allergy,
        allergy,
        ...NutritionConstraintTaxonomy.definitions.skip(1),
      ]),
      throwsA(isA<NutritionConstraintValidationError>()),
    );
    expect(
      () => NutritionConstraintDefinition(
        id: allergy.id,
        key: allergy.key,
        type: allergy.type,
        displayName: allergy.displayName,
        targetTypes: allergy.targetTypes,
        severitySupported: allergy.severitySupported,
        crossContactSupported: allergy.crossContactSupported,
        version: 2,
      ),
      throwsA(isA<NutritionConstraintValidationError>()),
    );
    expect(
      () => NutritionConstraintTaxonomy.validateDefinition(
        NutritionConstraintDefinition(
          id: allergy.id,
          key: allergy.key,
          type: allergy.type,
          displayName: allergy.displayName,
          targetTypes: const {NutritionConstraintTargetType.food},
          severitySupported: allergy.severitySupported,
          crossContactSupported: allergy.crossContactSupported,
        ),
      ),
      throwsA(isA<NutritionConstraintValidationError>()),
    );
  });

  test('constraint categories and target identities remain distinct', () {
    final allergy = _constraint(
      id: 'constraint-allergy',
      type: NutritionConstraintType.allergy,
      target: _target(NutritionConstraintTargetType.allergen, 'milk'),
    );
    final intolerance = _constraint(
      id: 'constraint-intolerance',
      type: NutritionConstraintType.intolerance,
      target: _target(NutritionConstraintTargetType.allergen, 'milk'),
    );
    expect(allergy.type, isNot(intolerance.type));
    expect(allergy.target.stableKey, intolerance.target.stableKey);
    expect(allergy.id, isNot(intolerance.id));
    expect(
      () => NutritionConstraintTarget(
        type: NutritionConstraintTargetType.food,
        id: '42',
      ),
      throwsA(isA<NutritionConstraintValidationError>()),
    );
  });

  test(
    'confirmed, possible, unknown, and no-known-conflict are deterministic',
    () {
      final allergy = _constraint(
        id: 'constraint-peanut',
        type: NutritionConstraintType.allergy,
        target: _target(NutritionConstraintTargetType.allergen, 'peanut'),
      );
      final evaluator = const NutritionConstraintEvaluator();

      final confirmed = evaluator.evaluate(
        subject: _foodInput(
          evidence: [
            _evidence(
              id: 'evidence-confirmed',
              target: _target(NutritionConstraintTargetType.allergen, 'peanut'),
              status: NutritionConstraintEvidenceStatus.confirmed,
              source:
                  NutritionConstraintEvidenceSource.reviewedAllergenDeclaration,
            ),
          ],
          at: instant,
        ),
        constraints: [allergy],
      );
      expect(confirmed.outcome, NutritionConstraintOutcome.confirmedConflict);
      expect(
        confirmed.evaluations.single.reasonCodes,
        contains('confirmed_presence'),
      );

      final possible = evaluator.evaluate(
        subject: _foodInput(
          evidence: [
            _evidence(
              id: 'evidence-possible',
              target: _target(NutritionConstraintTargetType.allergen, 'peanut'),
              status: NutritionConstraintEvidenceStatus.possible,
              source: NutritionConstraintEvidenceSource.aiEstimate,
            ),
          ],
          at: instant,
        ),
        constraints: [allergy],
      );
      expect(possible.outcome, NutritionConstraintOutcome.possibleConflict);

      final unknown = evaluator.evaluate(
        subject: _foodInput(
          evidence: [
            _evidence(
              id: 'evidence-unknown',
              target: _target(NutritionConstraintTargetType.allergen, 'peanut'),
              status: NutritionConstraintEvidenceStatus.unknown,
              source: NutritionConstraintEvidenceSource.unknown,
            ),
          ],
          at: instant,
        ),
        constraints: [allergy],
      );
      expect(
        unknown.outcome,
        NutritionConstraintOutcome.insufficientInformation,
      );

      final noKnownConflict = evaluator.evaluate(
        subject: _foodInput(
          evidence: [
            _evidence(
              id: 'evidence-absent',
              target: _target(NutritionConstraintTargetType.allergen, 'peanut'),
              status: NutritionConstraintEvidenceStatus.notIndicated,
              source:
                  NutritionConstraintEvidenceSource.reviewedAllergenDeclaration,
            ),
          ],
          at: instant,
        ),
        constraints: [allergy],
      );
      expect(
        noKnownConflict.outcome,
        NutritionConstraintOutcome.noKnownConflict,
      );
      expect(noKnownConflict.outcome.stableId, isNot('safe'));
    },
  );

  test('missing food evidence and display names never imply safety', () {
    final constraint = _constraint(
      id: 'constraint-nut',
      type: NutritionConstraintType.allergy,
      target: _target(NutritionConstraintTargetType.allergen, 'tree_nut'),
    );
    final result = const NutritionConstraintEvaluator().evaluate(
      subject: _foodInput(at: instant, subjectId: 'food-called-nut-free'),
      constraints: [constraint],
    );
    expect(result.outcome, NutritionConstraintOutcome.insufficientInformation);
    expect(result.missingEvidence, isNotEmpty);
  });

  test('unknown composition evidence blocks a safety-looking result', () {
    final constraint = _constraint(
      id: 'constraint-unknown-composition',
      type: NutritionConstraintType.allergy,
      target: _target(NutritionConstraintTargetType.allergen, 'milk'),
    );
    final result = const NutritionConstraintEvaluator().evaluate(
      subject: _foodInput(
        at: instant,
        evidence: [
          _evidence(
            id: 'composition-unknown',
            target: _target(
              NutritionConstraintTargetType.unknownOrUnsupported,
              'composition',
            ),
            status: NutritionConstraintEvidenceStatus.unknown,
            source: NutritionConstraintEvidenceSource.unknown,
          ),
        ],
      ),
      constraints: [constraint],
    );
    expect(result.outcome, NutritionConstraintOutcome.insufficientInformation);
    expect(
      result.evaluations.single.evidence.single.targetKey,
      'unknown:composition',
    );
  });

  test('estimated and imported evidence cannot claim confirmed presence', () {
    expect(
      () => _evidence(
        id: 'ai-confirmed',
        target: _target(NutritionConstraintTargetType.allergen, 'milk'),
        status: NutritionConstraintEvidenceStatus.confirmed,
        source: NutritionConstraintEvidenceSource.aiEstimate,
      ),
      throwsA(isA<NutritionConstraintValidationError>()),
    );
  });

  test('dietary pattern conflict uses typed animal-product evidence only', () {
    final vegan = _constraint(
      id: 'constraint-vegan',
      type: NutritionConstraintType.dietaryPattern,
      target: _target(NutritionConstraintTargetType.foodFamily, 'vegan'),
    );
    final result = const NutritionConstraintEvaluator().evaluate(
      subject: _foodInput(
        at: instant,
        evidence: [
          _evidence(
            id: 'milk-line',
            target: _target(
              NutritionConstraintTargetType.animalProduct,
              'milk',
            ),
            status: NutritionConstraintEvidenceStatus.confirmed,
            source: NutritionConstraintEvidenceSource.explicitIngredientList,
          ),
        ],
      ),
      constraints: [vegan],
    );
    expect(result.outcome, NutritionConstraintOutcome.confirmedConflict);
    expect(result.evaluations.single.affectedComponentIds, ['food-1']);
  });

  test('recipe line ordering does not change the evaluation fingerprint', () {
    final constraint = _constraint(
      id: 'constraint-egg',
      type: NutritionConstraintType.dietaryPattern,
      target: _target(NutritionConstraintTargetType.foodFamily, 'vegan'),
    );
    final lineA = NutritionConstraintSubjectLine(
      id: 'line-a',
      foodId: 'food-a',
      evidence: [
        _evidence(
          id: 'evidence-a',
          subjectId: 'food-a',
          target: _target(NutritionConstraintTargetType.animalProduct, 'egg'),
          status: NutritionConstraintEvidenceStatus.confirmed,
          source: NutritionConstraintEvidenceSource.recipeIngredientGraph,
          ingredientLineage: 'line-a',
        ),
      ],
    );
    final lineB = NutritionConstraintSubjectLine(
      id: 'line-b',
      foodId: 'food-b',
      evidence: [
        _evidence(
          id: 'evidence-b',
          subjectId: 'food-b',
          target: _target(NutritionConstraintTargetType.ingredient, 'salt'),
          status: NutritionConstraintEvidenceStatus.notIndicated,
          source: NutritionConstraintEvidenceSource.recipeIngredientGraph,
          ingredientLineage: 'line-b',
        ),
      ],
    );
    final first = const NutritionConstraintEvaluator().evaluate(
      subject: NutritionConstraintEvaluationInput(
        userId: 'user-1',
        subjectId: 'recipe-v1',
        recipeVersionId: 'recipe-v1',
        lines: [lineA, lineB],
        evaluatedAtUtc: instant,
      ),
      constraints: [constraint],
    );
    final second = const NutritionConstraintEvaluator().evaluate(
      subject: NutritionConstraintEvaluationInput(
        userId: 'user-1',
        subjectId: 'recipe-v1',
        recipeVersionId: 'recipe-v1',
        lines: [lineB, lineA],
        evaluatedAtUtc: instant,
      ),
      constraints: [constraint],
    );
    expect(first.fingerprint, second.fingerprint);
    expect(first.evaluations.single.affectedComponentIds, ['line-a']);
  });

  test('effective dates and acknowledgement do not mutate evidence', () {
    final constraint = _constraint(
      id: 'constraint-effective',
      type: NutritionConstraintType.allergy,
      target: _target(NutritionConstraintTargetType.allergen, 'soy'),
      effectiveFrom: instant.add(const Duration(days: 1)),
    );
    final result = const NutritionConstraintEvaluator().evaluate(
      subject: _foodInput(
        at: instant.add(const Duration(days: 2)),
        evidence: [
          _evidence(
            id: 'soy-evidence',
            target: _target(NutritionConstraintTargetType.allergen, 'soy'),
            status: NutritionConstraintEvidenceStatus.confirmed,
            source: NutritionConstraintEvidenceSource.userEntered,
          ),
        ],
      ),
      constraints: [constraint],
      acknowledgedConstraintIds: const ['constraint-effective'],
    );
    expect(result.evaluations.single.acknowledged, isTrue);
    expect(
      result.evaluations.single.evidence.single.status,
      NutritionConstraintEvidenceStatus.confirmed,
    );
  });
}

NutritionUserConstraint _constraint({
  required String id,
  required NutritionConstraintType type,
  required NutritionConstraintTarget target,
  DateTime? effectiveFrom,
}) {
  final definition = NutritionConstraintTaxonomy.definitionForType(type);
  final timestamp = effectiveFrom ?? DateTime.utc(2026, 8, 1);
  return NutritionUserConstraint(
    id: id,
    userId: 'user-1',
    definitionId: definition.id,
    type: type,
    target: target,
    strictness: NutritionConstraintStrictness.avoid,
    effectiveFrom: timestamp,
    source: NutritionConstraintSource.userEntered,
    createdAtUtc: timestamp,
    updatedAtUtc: timestamp,
  );
}

NutritionConstraintTarget _target(
  NutritionConstraintTargetType type,
  String id,
) => NutritionConstraintTarget(type: type, id: id);

NutritionConstraintEvidence _evidence({
  required String id,
  String subjectId = 'food-1',
  required NutritionConstraintTarget target,
  required NutritionConstraintEvidenceStatus status,
  required NutritionConstraintEvidenceSource source,
  String? ingredientLineage,
}) => NutritionConstraintEvidence(
  id: id,
  subjectId: subjectId,
  target: target,
  status: status,
  source: source,
  ingredientLineage: ingredientLineage,
);

NutritionConstraintEvaluationInput _foodInput({
  String subjectId = 'food-1',
  required DateTime at,
  Iterable<NutritionConstraintEvidence> evidence = const [],
}) => NutritionConstraintEvaluationInput(
  userId: 'user-1',
  subjectId: subjectId,
  foodId: subjectId,
  evidence: evidence,
  evaluatedAtUtc: at,
);
