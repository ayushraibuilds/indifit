import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b04_policy_gate_fixture.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_constraints.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/models/b04_nutrition_safety_models.dart';
import 'package:indifit/data/services/b04_nutrition_safety_filter.dart';

void main() {
  const filter = B04NutritionSafetyFilter();
  test('confirmed strict dietary conflicts are hard blocks', () {
    final cases = [
      (
        type: NutritionConstraintType.allergy,
        target: _target(NutritionConstraintTargetType.allergen, 'peanut'),
        evidenceTarget: _target(
          NutritionConstraintTargetType.allergen,
          'peanut',
        ),
      ),
      (
        type: NutritionConstraintType.intolerance,
        target: _target(NutritionConstraintTargetType.allergen, 'milk'),
        evidenceTarget: _target(NutritionConstraintTargetType.allergen, 'milk'),
      ),
      (
        type: NutritionConstraintType.religiousRestriction,
        target: _target(NutritionConstraintTargetType.foodFamily, 'jain'),
        evidenceTarget: _target(
          NutritionConstraintTargetType.ingredient,
          'onion',
        ),
      ),
      (
        type: NutritionConstraintType.ethicalPreference,
        target: _target(NutritionConstraintTargetType.animalProduct, 'beef'),
        evidenceTarget: _target(
          NutritionConstraintTargetType.animalProduct,
          'beef',
        ),
      ),
    ];

    for (final item in cases) {
      final result = filter.mapEvaluation(
        evaluation: _evaluate(
          type: item.type,
          constraintTarget: item.target,
          evidence: [
            _evidence(
              id: 'confirmed-${item.type.stableId}',
              target: item.evidenceTarget,
              status: NutritionConstraintEvidenceStatus.confirmed,
            ),
          ],
        ),
        output: B04NutritionSafetyOutput.eatNow,
      );

      expect(result.disposition, B04NutritionSafetyDisposition.hardBlock);
      expect(result.isHardBlock, isTrue);
      expect(result.recommendationAllowed, isFalse);
      expect(result.hardBlockConstraintIds, hasLength(1));
    }
  });

  test('evaluate delegates conflict semantics to the B03 evaluator', () {
    final constraint = _constraint(
      id: 'constraint-delegated',
      type: NutritionConstraintType.allergy,
      target: _target(NutritionConstraintTargetType.allergen, 'peanut'),
    );
    final result = filter.evaluate(
      subject: NutritionConstraintEvaluationInput(
        userId: 'user-1',
        subjectId: 'food-1',
        foodId: 'food-1',
        evidence: [
          NutritionConstraintEvidence(
            id: 'delegated-confirmed',
            subjectId: 'food-1',
            target: NutritionConstraintTarget(
              type: NutritionConstraintTargetType.allergen,
              id: 'peanut',
            ),
            status: NutritionConstraintEvidenceStatus.confirmed,
            source: NutritionConstraintEvidenceSource.reviewedCatalogue,
          ),
        ],
        evaluatedAtUtc: DateTime.utc(2026, 8, 4, 10),
      ),
      constraints: [constraint],
      output: B04NutritionSafetyOutput.adaptiveTarget,
    );

    expect(result.disposition, B04NutritionSafetyDisposition.hardBlock);
    expect(result.constraintEvaluation, isNotNull);
    expect(
      result.constraintContexts.single.constraintId,
      'constraint-delegated',
    );
  });

  test(
    'possible, unknown, insufficient, missing and cross-contact evidence is unavailable for every safety output',
    () {
      final possible = _evaluate(
        type: NutritionConstraintType.allergy,
        constraintTarget: _target(
          NutritionConstraintTargetType.allergen,
          'peanut',
        ),
        evidence: [
          _evidence(
            id: 'possible-peanut',
            target: _target(NutritionConstraintTargetType.allergen, 'peanut'),
            status: NutritionConstraintEvidenceStatus.possible,
            source: NutritionConstraintEvidenceSource.aiEstimate,
          ),
        ],
      );
      final unknown = _evaluate(
        type: NutritionConstraintType.allergy,
        constraintTarget: _target(
          NutritionConstraintTargetType.allergen,
          'peanut',
        ),
        evidence: [
          _evidence(
            id: 'unknown-peanut',
            target: _target(NutritionConstraintTargetType.allergen, 'peanut'),
            status: NutritionConstraintEvidenceStatus.unknown,
            source: NutritionConstraintEvidenceSource.unknown,
          ),
        ],
      );
      final insufficient = _evaluate(
        type: NutritionConstraintType.intolerance,
        constraintTarget: _target(
          NutritionConstraintTargetType.allergen,
          'milk',
        ),
      );
      final missingIngredient = const NutritionConstraintEvaluator().evaluate(
        subject: NutritionConstraintEvaluationInput(
          userId: 'user-1',
          subjectId: 'recipe-1',
          recipeVersionId: 'recipe-1',
          lines: [
            NutritionConstraintSubjectLine(
              id: 'line-missing',
              foodId: 'food-missing',
              evidence: const [],
            ),
          ],
          evaluatedAtUtc: DateTime.utc(2026, 8, 4, 10),
        ),
        constraints: [
          _constraint(
            id: 'constraint-peanut-recipe',
            type: NutritionConstraintType.allergy,
            target: _target(NutritionConstraintTargetType.allergen, 'peanut'),
          ),
        ],
      );
      final crossContact = _evaluate(
        type: NutritionConstraintType.allergy,
        constraintTarget: _target(
          NutritionConstraintTargetType.allergen,
          'peanut',
        ),
        crossContact: true,
        evidence: [
          _evidence(
            id: 'possible-cross-contact',
            target: _target(NutritionConstraintTargetType.allergen, 'peanut'),
            status: NutritionConstraintEvidenceStatus.possible,
            source:
                NutritionConstraintEvidenceSource.reviewedAllergenDeclaration,
          ),
        ],
      );

      for (final evaluation in [
        possible,
        unknown,
        insufficient,
        missingIngredient,
        crossContact,
      ]) {
        for (final output in B04NutritionSafetyOutput.values.where(
          (item) => item.isSafetySensitive,
        )) {
          final result = filter.mapEvaluation(
            evaluation: evaluation,
            output: output,
          );
          expect(result.disposition, B04NutritionSafetyDisposition.unavailable);
          expect(result.recommendationAllowed, isFalse);
          expect(result.isUnavailable, isTrue);
        }
      }
      final crossContactResult = filter.mapEvaluation(
        evaluation: crossContact,
        output: B04NutritionSafetyOutput.eatNow,
      );
      expect(
        crossContactResult.reasonCodes,
        contains('possible_cross_contact'),
      );
      final missingResult = filter.mapEvaluation(
        evaluation: missingIngredient,
        output: B04NutritionSafetyOutput.rankedMealCandidates,
      );
      expect(
        missingResult.reasonCodes,
        contains('missing_ingredient_evidence'),
      );
    },
  );

  test(
    'no-known-conflict is cautious exact wording, not a safety guarantee',
    () {
      final result = filter.mapEvaluation(
        evaluation: _evaluate(
          type: NutritionConstraintType.allergy,
          constraintTarget: _target(
            NutritionConstraintTargetType.allergen,
            'peanut',
          ),
          evidence: [
            _evidence(
              id: 'reviewed-absence',
              target: _target(NutritionConstraintTargetType.allergen, 'peanut'),
              status: NutritionConstraintEvidenceStatus.notIndicated,
            ),
          ],
        ),
        output: B04NutritionSafetyOutput.eatNow,
      );

      expect(result.disposition, B04NutritionSafetyDisposition.noKnownConflict);
      final approvedWording = B04PolicyGateFixturePacket.current.safetyWording
          .singleWhere((item) => item.semanticState == 'no_known_conflict')
          .text;
      expect(result.wording, approvedWording);
      expect(result.wording.toLowerCase(), isNot(contains('safe')));
      expect(result.wording.toLowerCase(), isNot(contains('guarantee')));
      expect(result.recommendationAllowed, isTrue);
    },
  );

  test(
    'confirmed soft preferences remain filters rather than safety hard blocks',
    () {
      final result = filter.mapEvaluation(
        evaluation: _evaluate(
          type: NutritionConstraintType.tasteDislike,
          constraintTarget: _target(
            NutritionConstraintTargetType.food,
            'food-1',
          ),
          evidence: [
            _evidence(
              id: 'disliked-food',
              target: _target(NutritionConstraintTargetType.food, 'food-1'),
              status: NutritionConstraintEvidenceStatus.confirmed,
            ),
          ],
        ),
        output: B04NutritionSafetyOutput.rankedMealCandidates,
      );

      expect(result.disposition, B04NutritionSafetyDisposition.softFilter);
      expect(result.isHardBlock, isFalse);
      expect(result.recommendationAllowed, isTrue);
      expect(result.softFilterConstraintIds, ['constraint-1']);
    },
  );

  test(
    'strictness is preserved and non-avoid constraints do not become hard blocks',
    () {
      final constraint = _constraint(
        id: 'constraint-warn-allergy',
        type: NutritionConstraintType.allergy,
        target: _target(NutritionConstraintTargetType.allergen, 'peanut'),
        strictness: NutritionConstraintStrictness.warn,
      );
      final evaluation = const NutritionConstraintEvaluator().evaluate(
        subject: NutritionConstraintEvaluationInput(
          userId: 'user-1',
          subjectId: 'food-1',
          foodId: 'food-1',
          evidence: [
            _evidence(
              id: 'confirmed-peanut',
              target: _target(NutritionConstraintTargetType.allergen, 'peanut'),
              status: NutritionConstraintEvidenceStatus.confirmed,
            ),
          ],
          evaluatedAtUtc: DateTime.utc(2026, 8, 4, 10),
        ),
        constraints: [constraint],
      );
      final result = filter.mapEvaluation(
        evaluation: evaluation,
        constraints: [constraint],
        output: B04NutritionSafetyOutput.eatNow,
      );

      expect(result.disposition, B04NutritionSafetyDisposition.softFilter);
      expect(
        result.constraintContexts.single.strictness,
        NutritionConstraintStrictness.warn,
      );
      expect(result.constraintContexts.single.crossContact, isFalse);
    },
  );

  test(
    'unknown nutrients remain visible and unavailable without exactification',
    () {
      final nutrient = _nutrientEvidence(
        fact: NutrientFact.missing(
          nutrientId: 'energy',
          unit: NutrientUnit.kilocalorie,
          basis: NutrientBasis(NutrientBasisKind.absolute),
          source: NutrientSourceType.reviewedCatalogue,
          sourceReference: 'nutrient-evidence-missing',
        ),
        completeness: NutrientCompletenessState.unknown,
        missing: const ['energy'],
      );
      final result = filter.mapEvaluation(
        evaluation: _noKnownEvaluation(),
        output: B04NutritionSafetyOutput.adaptiveTarget,
        nutrientEvidence: nutrient,
      );

      expect(result.disposition, B04NutritionSafetyDisposition.unavailable);
      expect(result.reasonCodes, contains('unknown_nutrient'));
      expect(
        result.nutrientEvidence!.facts['energy']!.status,
        NutrientFactStatus.missing,
      );
      expect(result.nutrientEvidence!.facts['energy']!.point, isNull);
    },
  );

  test(
    'estimated ranges remain visible and crossing a boundary is unavailable',
    () {
      final safeRange = _nutrientEvidence(
        fact: _estimatedEnergy(lower: '100', point: '125', upper: '150'),
        completeness: NutrientCompletenessState.complete,
      );
      final crossingRange = _nutrientEvidence(
        fact: _estimatedEnergy(lower: '100', point: '200', upper: '300'),
        completeness: NutrientCompletenessState.complete,
      );
      final boundary = B04NutritionSafetyNutrientBoundary(
        nutrientId: 'energy',
        direction: B04NutritionSafetyBoundaryDirection.maximum,
        threshold: _amount('200'),
        reasonCode: 'approved_energy_limit',
      );

      final bounded = filter.mapEvaluation(
        evaluation: _noKnownEvaluation(),
        output: B04NutritionSafetyOutput.eatNow,
        nutrientEvidence: safeRange,
        nutrientBoundaries: [boundary],
      );
      expect(
        bounded.disposition,
        B04NutritionSafetyDisposition.noKnownConflict,
      );
      expect(bounded.nutrientRangeIds, ['energy']);
      expect(
        bounded.nutrientEvidence!.facts['energy']!.lower!.value.toString(),
        '100',
      );

      final crossing = filter.mapEvaluation(
        evaluation: _noKnownEvaluation(),
        output: B04NutritionSafetyOutput.eatNow,
        nutrientEvidence: crossingRange,
        nutrientBoundaries: [boundary],
      );
      expect(crossing.disposition, B04NutritionSafetyDisposition.unavailable);
      expect(crossing.reasonCodes, contains('nutrient_range_crosses_boundary'));
    },
  );

  test(
    'acknowledgement and override cannot change safety; logging stays separate',
    () {
      final evaluation = _evaluate(
        type: NutritionConstraintType.allergy,
        constraintTarget: _target(
          NutritionConstraintTargetType.allergen,
          'peanut',
        ),
        evidence: [
          _evidence(
            id: 'confirmed-peanut',
            target: _target(NutritionConstraintTargetType.allergen, 'peanut'),
            status: NutritionConstraintEvidenceStatus.confirmed,
          ),
        ],
      );
      final ordinary = filter.mapEvaluation(
        evaluation: evaluation,
        output: B04NutritionSafetyOutput.eatNow,
      );
      final overridden = filter.mapEvaluation(
        evaluation: evaluation,
        output: B04NutritionSafetyOutput.eatNow,
        acknowledgementRequested: true,
        userOverrideRequested: true,
      );
      expect(overridden.disposition, ordinary.disposition);
      expect(overridden.evaluatorOutcome, ordinary.evaluatorOutcome);
      expect(
        overridden.constraintEvaluation!.fingerprint,
        ordinary.constraintEvaluation!.fingerprint,
      );
      expect(
        overridden.reasonCodes,
        contains('acknowledgement_does_not_change_safety'),
      );
      expect(
        overridden.reasonCodes,
        contains('user_override_does_not_change_safety'),
      );

      final logging = filter.mapEvaluation(
        evaluation: evaluation,
        output: B04NutritionSafetyOutput.lowRiskLogging,
        acknowledgementRequested: true,
        userOverrideRequested: true,
      );
      expect(
        logging.disposition,
        B04NutritionSafetyDisposition.lowRiskLoggingOnly,
      );
      expect(logging.isHardBlock, isTrue);
      expect(logging.recommendationAllowed, isFalse);
      expect(
        logging.wording,
        'You may record a personal log, but acknowledgement does not make the item suitable or safe.',
      );
    },
  );

  test(
    'B03 validation failures and replay remain deterministic and offline',
    () {
      final invalid = filter.unavailableForInvalidEvidence(
        userId: 'user-1',
        subjectId: 'food-1',
        output: B04NutritionSafetyOutput.weeklyCoaching,
        errorCode: 'malformed_constraint_evidence',
      );
      expect(invalid.disposition, B04NutritionSafetyDisposition.unavailable);
      expect(invalid.isUnavailable, isTrue);
      expect(invalid.invalidEvidenceCode, 'malformed_constraint_evidence');
      expect(invalid.reasonCodes, contains('structurally_invalid_evidence'));

      final first = filter.mapEvaluation(
        evaluation: _noKnownEvaluation(),
        output: B04NutritionSafetyOutput.dailyCoaching,
      );
      final second = filter.mapEvaluation(
        evaluation: _noKnownEvaluation(),
        output: B04NutritionSafetyOutput.dailyCoaching,
      );
      expect(second.toRedactedMap(), first.toRedactedMap());
      expect(
        second.constraintEvaluation!.fingerprint,
        first.constraintEvaluation!.fingerprint,
      );
    },
  );
}

NutritionConstraintEvaluationResult _noKnownEvaluation() => _evaluate(
  type: NutritionConstraintType.allergy,
  constraintTarget: _target(NutritionConstraintTargetType.allergen, 'peanut'),
  evidence: [
    _evidence(
      id: 'reviewed-absence',
      target: _target(NutritionConstraintTargetType.allergen, 'peanut'),
      status: NutritionConstraintEvidenceStatus.notIndicated,
    ),
  ],
);

NutritionConstraintEvaluationResult _evaluate({
  required NutritionConstraintType type,
  required NutritionConstraintTarget constraintTarget,
  Iterable<NutritionConstraintEvidence> evidence = const [],
  bool crossContact = false,
}) => const NutritionConstraintEvaluator().evaluate(
  subject: NutritionConstraintEvaluationInput(
    userId: 'user-1',
    subjectId: 'food-1',
    foodId: 'food-1',
    evidence: evidence,
    evaluatedAtUtc: DateTime.utc(2026, 8, 4, 10),
  ),
  constraints: [
    _constraint(
      id: 'constraint-1',
      type: type,
      target: constraintTarget,
      crossContact: crossContact,
    ),
  ],
);

NutritionUserConstraint _constraint({
  required String id,
  required NutritionConstraintType type,
  required NutritionConstraintTarget target,
  bool crossContact = false,
  NutritionConstraintStrictness strictness =
      NutritionConstraintStrictness.avoid,
}) {
  final definition = NutritionConstraintTaxonomy.definitionForType(type);
  final timestamp = DateTime.utc(2026, 8, 1);
  return NutritionUserConstraint(
    id: id,
    userId: 'user-1',
    definitionId: definition.id,
    type: type,
    target: target,
    strictness: strictness,
    crossContact: crossContact,
    effectiveFrom: timestamp,
    source: NutritionConstraintSource.userEntered,
    createdAtUtc: timestamp,
    updatedAtUtc: timestamp,
  );
}

NutritionConstraintEvidence _evidence({
  required String id,
  required NutritionConstraintTarget target,
  required NutritionConstraintEvidenceStatus status,
  NutritionConstraintEvidenceSource source =
      NutritionConstraintEvidenceSource.reviewedCatalogue,
}) => NutritionConstraintEvidence(
  id: id,
  subjectId: 'food-1',
  target: target,
  status: status,
  source: source,
);

NutritionConstraintTarget _target(
  NutritionConstraintTargetType type,
  String id,
) => NutritionConstraintTarget(type: type, id: id);

NutrientAmount _amount(String value) => NutrientAmount(
  value: QuantityAmount.fromString(value),
  unit: NutrientUnit.kilocalorie,
);

NutrientFact _estimatedEnergy({
  required String lower,
  required String point,
  required String upper,
}) => NutrientFact.estimated(
  nutrientId: 'energy',
  point: _amount(point),
  lower: _amount(lower),
  upper: _amount(upper),
  basis: NutrientBasis(NutrientBasisKind.absolute),
  source: NutrientSourceType.reviewedCatalogue,
  sourceReference: 'energy-estimate-1',
  confidence: NutrientConfidence.medium,
);

NutrientAggregationResult _nutrientEvidence({
  required NutrientFact fact,
  required NutrientCompletenessState completeness,
  List<String> missing = const [],
}) => NutrientAggregationResult(
  facts: {fact.nutrientId: fact},
  completeness: NutrientCompleteness(
    state: completeness,
    requestedNutrientIds: [fact.nutrientId],
    availableNutrientIds: fact.isAvailable ? [fact.nutrientId] : const [],
    missingNutrientIds: missing,
    estimatedNutrientIds: fact.status == NutrientFactStatus.estimated
        ? [fact.nutrientId]
        : const [],
    notApplicableNutrientIds: const [],
    partiallyKnownNutrientIds: const [],
  ),
  sourceLineage: {
    fact.nutrientId: [fact.source],
  },
  factVersionLineage: {
    fact.nutrientId: [fact.factVersion],
  },
);
