import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b04_current_food_fixture_matrix.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/models/b04_adaptive_target_models.dart';
import 'package:indifit/data/models/b04_current_food_models.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/models/b04_nutrition_safety_models.dart';
import 'package:indifit/data/models/b04_recommendation_context_models.dart';
import 'package:indifit/data/services/b04_current_food_guidance_service.dart';
import 'package:indifit/data/services/b04_meal_opportunity_service.dart';
import 'package:indifit/features/nutrition/current_food_controller.dart';

const _userId = 'current-food-user';
const _timezoneId = 'Asia/Kolkata';
const _localDate = '2026-08-06';
final _evaluatedAtUtc = DateTime.utc(2026, 8, 6, 12);

void main() {
  const service = B04CurrentFoodGuidanceService();

  test(
    'fixture matrix covers the documented positive, boundary, and failure cases',
    () {
      expect(
        B04CurrentFoodFixtureMatrix.cases.map((item) => item.id),
        containsAll([
          'local_candidate_ranking',
          'no_explicit_candidate',
          'estimated_consumed_range',
          'missing_consumed_totals',
          'confirmed_allergy_hard_block',
          'uncertain_safety_evidence',
          'low_risk_logging_acknowledgement',
          'effective_goal_version',
          'no_safety_acknowledgement_bypass',
          'n8_absent',
        ]),
      );
    },
  );

  test('ranks explicit local candidates against known remaining targets', () {
    final first = _selection('selection-a', 'food-a');
    final second = _selection('selection-b', 'food-b');
    final guidance = service.evaluate(
      context: _context(opportunity: _opportunity([first, second])),
      candidates: [
        _candidate(selection: second, energy: 1800),
        _candidate(selection: first, energy: 300),
      ],
    );

    expect(guidance.status, B04CurrentFoodGuidanceStatus.available);
    expect(guidance.cards.map((item) => item.selectionId), [
      'selection-a',
      'selection-b',
    ]);
    expect(
      guidance.cards.first.targetFit.state,
      B04CurrentFoodTargetFitState.fits,
    );
    expect(
      guidance.cards.last.targetFit.state,
      B04CurrentFoodTargetFitState.exceeds,
    );
    expect(
      guidance.remainingTargets.energy?.state,
      B04CurrentFoodValueState.known,
    );
    expect(guidance.remainingTargets.energy?.point, '1600');
    expect(guidance.remainingTargets.consumedRecordIds, ['record-1']);
    expect(
      guidance.cards.first.recommendation.explanation,
      contains('No known conflict was detected for the checked evidence.'),
    );
  });

  test(
    'filters partial candidate evidence independently from complete candidates',
    () {
      final complete = _selection('selection-complete', 'food-complete');
      final partial = B04MealCandidate.fromSourceId(
        selectionId: 'selection-partial',
        sourceId: 'canonical_food',
        subjectId: 'food-partial',
        evidence: const B04MealCandidateEvidence.partial(
          identityReference: 'identity-food-partial',
        ),
      );
      final guidance = service.evaluate(
        context: _context(opportunity: _opportunity([complete, partial])),
        candidates: [
          _candidate(selection: complete, energy: 300),
          _candidate(selection: partial, energy: 300),
        ],
      );

      expect(guidance.status, B04CurrentFoodGuidanceStatus.available);
      expect(guidance.cards.map((item) => item.selectionId), [
        'selection-complete',
      ]);
      expect(guidance.excludedCandidates.map((item) => item.selectionId), [
        'selection-partial',
      ]);
      expect(
        guidance.excludedCandidates.single.reasonCodes,
        contains('candidate_evidence_partial'),
      );
    },
  );

  test('returns no candidate without inventing an available food', () {
    final guidance = service.evaluate(
      context: _context(opportunity: _opportunity(const [])),
      candidates: const [],
    );

    expect(guidance.status, B04CurrentFoodGuidanceStatus.noCandidate);
    expect(guidance.cards, isEmpty);
    expect(guidance.excludedCandidates, isEmpty);
    expect(guidance.reasonCodes, contains('no_candidate'));
  });

  test('preserves estimated consumed bounds as a remaining range', () {
    final guidance = service.evaluate(
      context: _context(
        totals: _totals(estimatedEnergy: true),
        opportunity: _opportunity([
          _selection('selection-range', 'food-range'),
        ]),
      ),
      candidates: [
        _candidate(
          selection: _selection('selection-range', 'food-range'),
          energy: 1600,
        ),
      ],
    );

    final energy = guidance.remainingTargets.energy!;
    expect(energy.state, B04CurrentFoodValueState.range);
    expect(energy.lower, '1500');
    expect(energy.upper, '1700');
    expect(
      guidance.cards.single.targetFit.state,
      B04CurrentFoodTargetFitState.uncertain,
    );
  });

  test('missing consumed energy is unavailable and never coerced to zero', () {
    final selection = _selection('selection-missing', 'food-missing');
    final guidance = service.evaluate(
      context: _context(
        totals: _totals(missingEnergy: true),
        opportunity: _opportunity([selection]),
      ),
      candidates: [_candidate(selection: selection, energy: 300)],
    );

    expect(guidance.status, B04CurrentFoodGuidanceStatus.unavailable);
    expect(guidance.cards, isEmpty);
    expect(
      guidance.remainingTargets.energy?.state,
      B04CurrentFoodValueState.missing,
    );
    expect(guidance.remainingTargets.energy?.point, isNull);
    expect(guidance.remainingTargets.energy?.point, isNot('0'));
    expect(
      guidance.excludedCandidates.single.reasonCodes,
      contains('remaining_target_unavailable'),
    );
  });

  test(
    'confirmed dietary conflicts remain hard blocks even with acknowledgement or override',
    () {
      final selection = _selection('selection-allergy', 'food-allergy');
      final guidance = service.evaluate(
        context: _context(opportunity: _opportunity([selection])),
        candidates: [
          _candidate(
            selection: selection,
            energy: 300,
            safety: _safety(
              subjectId: selection.subjectId,
              disposition: B04NutritionSafetyDisposition.hardBlock,
              evaluatedDisposition: B04NutritionSafetyDisposition.hardBlock,
              reasonCodes: const ['confirmed_allergy_conflict'],
              hardBlockConstraintIds: const ['allergy-peanut'],
              acknowledgementRequested: true,
              userOverrideRequested: true,
            ),
          ),
        ],
      );

      expect(guidance.status, B04CurrentFoodGuidanceStatus.noCandidate);
      expect(guidance.cards, isEmpty);
      expect(
        guidance.excludedCandidates.single.reasonCodes,
        contains('dietary_hard_block'),
      );
      expect(
        guidance.excludedCandidates.single.safetyDisposition,
        B04NutritionSafetyDisposition.hardBlock,
      );
    },
  );

  test(
    'possible, unknown, insufficient, missing, and invalid safety evidence fail closed',
    () {
      final cases = <(String, List<String>, List<String>)>[
        (
          'possible',
          const ['possible_cross_contact'],
          const ['possible-conflict'],
        ),
        ('unknown', const ['unknown_ingredient'], const ['unknown-conflict']),
        ('insufficient', const ['insufficient_ingredient_evidence'], const []),
        ('missing', const ['missing_ingredient_evidence'], const []),
      ];

      for (final entry in cases) {
        final selection = _selection(
          'selection-${entry.$1}',
          'food-${entry.$1}',
        );
        final guidance = service.evaluate(
          context: _context(opportunity: _opportunity([selection])),
          candidates: [
            _candidate(
              selection: selection,
              energy: 300,
              safety: _safety(
                subjectId: selection.subjectId,
                disposition: B04NutritionSafetyDisposition.unavailable,
                evaluatedDisposition: B04NutritionSafetyDisposition.unavailable,
                reasonCodes: entry.$2,
                missingEvidence: entry.$2,
                uncertainConstraintIds: entry.$3,
              ),
            ),
          ],
        );

        expect(guidance.status, B04CurrentFoodGuidanceStatus.unavailable);
        expect(guidance.cards, isEmpty);
        expect(
          guidance.excludedCandidates.single.reasonCodes,
          contains('dietary_unavailable'),
        );
      }

      final invalidSelection = _selection('selection-invalid', 'food-invalid');
      final invalidGuidance = service.evaluate(
        context: _context(opportunity: _opportunity([invalidSelection])),
        candidates: [
          _candidate(
            selection: invalidSelection,
            energy: 300,
            safety: B04NutritionSafetyResult.invalidEvidence(
              userId: _userId,
              subjectId: invalidSelection.subjectId,
              output: B04NutritionSafetyOutput.eatNow,
              errorCode: 'invalid_ingredient_evidence',
            ),
          ),
        ],
      );

      expect(invalidGuidance.status, B04CurrentFoodGuidanceStatus.unavailable);
      expect(invalidGuidance.cards, isEmpty);
      expect(
        invalidGuidance.excludedCandidates.single.reasonCodes,
        contains('dietary_unavailable'),
      );
    },
  );

  test(
    'low-risk acknowledgement stays a warning outside safety-sensitive recommendations',
    () {
      final selection = _selection('selection-log', 'food-log');
      final guidance = service.evaluate(
        context: _context(opportunity: _opportunity([selection])),
        candidates: [
          _candidate(
            selection: selection,
            energy: 300,
            safety: _safety(
              subjectId: selection.subjectId,
              output: B04NutritionSafetyOutput.lowRiskLogging,
              disposition: B04NutritionSafetyDisposition.lowRiskLoggingOnly,
              evaluatedDisposition: B04NutritionSafetyDisposition.unavailable,
              reasonCodes: const ['acknowledgement_requested'],
              acknowledgementRequested: true,
            ),
          ),
        ],
      );

      expect(guidance.cards, isEmpty);
      expect(guidance.status, B04CurrentFoodGuidanceStatus.noCandidate);
      expect(guidance.lowRiskWarnings, hasLength(1));
      expect(
        guidance.lowRiskWarnings.single.wording,
        contains('acknowledgement does not make the item suitable or safe'),
      );
      expect(guidance.recommendationEvaluation?.recommendations, isEmpty);
    },
  );

  test('effective goal versions change the remaining-target read model', () {
    final selection = _selection('selection-goal', 'food-goal');
    final guidance = service.evaluate(
      context: _context(
        goal: _goal(id: 'goal-v2', version: 2, calorieTargetKcal: 2500),
        opportunity: _opportunity([selection]),
      ),
      candidates: [_candidate(selection: selection, energy: 300)],
    );

    expect(guidance.remainingTargets.goalVersionId, 'goal-v2');
    expect(guidance.remainingTargets.energy?.point, '2100');
  });

  test(
    'replay is deterministic, offline-capable, and does not infer N8 context',
    () {
      final selection = _selection('selection-offline', 'food-offline');
      final context = _context(opportunity: _opportunity([selection]));
      final candidates = [_candidate(selection: selection, energy: 300)];
      final first = service.evaluate(context: context, candidates: candidates);
      final second = service.evaluate(context: context, candidates: candidates);

      expect(first.isOfflineCapable, isTrue);
      expect(first.toRedactedMap(), second.toRedactedMap());
      expect(first.toRedactedMap()['n8'], 'absent');
      expect(first.toRedactedMap(), isNot(contains('user_id')));
    },
  );

  test(
    'controller exposes the local result and retry without adding a provider',
    () async {
      final selection = _selection('selection-controller', 'food-controller');
      final controller = B04CurrentFoodController(service: service);
      addTearDown(controller.dispose);

      await controller.load(
        context: _context(opportunity: _opportunity([selection])),
        candidates: [_candidate(selection: selection, energy: 300)],
      );
      expect(controller.state.status, B04CurrentFoodControllerStatus.ready);
      expect(controller.state.guidance?.cards, hasLength(1));

      await controller.retry();
      expect(controller.state.status, B04CurrentFoodControllerStatus.ready);

      final invalidSelection = _selection(
        'selection-not-in-opportunity',
        'food-not-in-opportunity',
      );
      await controller.load(
        context: _context(opportunity: _opportunity([selection])),
        candidates: [_candidate(selection: invalidSelection, energy: 300)],
      );
      expect(controller.state.status, B04CurrentFoodControllerStatus.failure);
      expect(controller.state.guidance, isNull);
      expect(controller.state.retryable, isTrue);
    },
  );

  test(
    'external and legacy candidate sources are rejected at the opportunity boundary',
    () {
      expect(
        () => B04MealCandidate.fromSourceId(
          selectionId: 'external',
          sourceId: 'external_search',
          subjectId: 'external-subject',
        ),
        throwsArgumentError,
      );
      expect(
        () => B04MealCandidate.fromSourceId(
          selectionId: 'legacy',
          sourceId: 'legacy_food_log',
          subjectId: 'legacy-subject',
        ),
        throwsArgumentError,
      );
    },
  );
}

B04MealCandidate _selection(String selectionId, String subjectId) =>
    B04MealCandidate.fromSourceId(
      selectionId: selectionId,
      sourceId: 'canonical_food',
      subjectId: subjectId,
      evidence: B04MealCandidateEvidence.complete(
        identityReference: 'identity-$subjectId',
        nutrientReference: 'nutrient-$subjectId',
        constraintReference: 'constraint-$subjectId',
      ),
    );

B04MealOpportunity _opportunity(Iterable<B04MealCandidate> candidates) =>
    B04MealOpportunityService().create(
      currentInstantUtc: _evaluatedAtUtc,
      timezoneId: _timezoneId,
      kind: B04MealOpportunityKind.now,
      candidates: candidates.toList(),
    );

B04CurrentFoodCandidateInput _candidate({
  required B04MealCandidate selection,
  required double energy,
  B04NutritionSafetyResult? safety,
}) => B04CurrentFoodCandidateInput(
  selection: selection,
  displayLabel: 'Local ${selection.subjectId}',
  nutrientEvidence: _totals(
    candidateEnergy: energy,
    sourceReferencePrefix: 'candidate-${selection.subjectId}',
  ),
  safety: safety ?? _safety(subjectId: selection.subjectId),
);

B04RecommendationContext _context({
  required B04MealOpportunity opportunity,
  NutrientAggregationResult? totals,
  NutritionGoalVersionReadModel? goal,
  bool includeDay = true,
  Iterable<B04MissingEvidence> missingEvidence = const [],
}) {
  final day = includeDay
      ? [
          B04NutritionDayContext(
            localDate: _localDate,
            totals: totals ?? _totals(),
            recordIds: const ['record-1'],
            sourceCounts: const {'canonical': 1},
            compatibilityIssueIds: const [],
            estimateIds: const [],
            containsLegacyCompatibility: false,
          ),
        ]
      : const <B04NutritionDayContext>[];
  return B04RecommendationContext(
    contextId: 'current-food-context',
    userId: _userId,
    window: const B04RecommendationWindow(
      period: B04RecommendationPeriod.daily,
      startLocalDate: _localDate,
      endLocalDate: _localDate,
      timezoneId: _timezoneId,
      targetEvaluationWindowDays: 1,
      aggregateWindowDays: 1,
    ),
    evaluatedAtUtc: _evaluatedAtUtc,
    availability: B04ContextAvailability.available,
    activeGoal: goal ?? _goal(),
    preferences: CoachingPreferencesReadModel(
      userId: _userId,
      adaptiveCoachingEnabled: false,
      optionalAiEnabled: false,
      adaptiveCoachingEvent: null,
      optionalAiEvent: null,
    ),
    eligibility: CoachingEligibilityReadModel(
      userId: _userId,
      result: CoachingEligibilityResult.eligible,
      reasonCode: 'eligible',
      policyVersion: 'B04-12-TEST-ELIGIBILITY-V1',
      evaluationLocalDate: _localDate,
      timezoneId: _timezoneId,
      evaluationUtc: _evaluatedAtUtc,
    ),
    readiness: null,
    workload: null,
    schedule: null,
    nutrition: B04NutritionContext(
      days: day,
      expectedLocalDates: const [_localDate],
      missingLocalDates: includeDay ? const [] : const [_localDate],
    ),
    constraints: const [],
    targetResult: _target(),
    mealOpportunity: opportunity,
    missingEvidence: List.unmodifiable(missingEvidence),
    n8: B04N8Context.absent,
  );
}

NutritionGoalVersionReadModel _goal({
  String id = 'goal-v1',
  int version = 1,
  int calorieTargetKcal = 2000,
}) => NutritionGoalVersionReadModel(
  id: id,
  userId: _userId,
  versionNumber: version,
  goalType: NutritionGoalType.maintenance,
  source: NutritionGoalSource.userSet,
  calorieTargetKcal: calorieTargetKcal,
  proteinTargetG: 120,
  carbsTargetG: 240,
  fatTargetG: 70,
  policyVersion: 'B04-12-TEST-GOAL-POLICY-V1',
  calculationVersion: 'B04-12-TEST-GOAL-CALC-V1',
  algorithmVersion: 'B04-12-TEST-GOAL-ALGO-V1',
  effectiveFromLocalDate: _localDate,
  effectiveToLocalDate: null,
  timezoneId: _timezoneId,
  supersedesGoalVersionId: null,
  evidenceFingerprint: 'goal-fingerprint-$version',
  exactResultNumerator: null,
  exactResultDenominator: null,
  normalizedMaintenanceKcal: calorieTargetKcal,
  createdAtUtc: DateTime.utc(2026, 8, 1),
);

B04AdaptiveTargetResult _target() => B04AdaptiveTargetResult(
  status: B04AdaptiveTargetStatus.unavailable,
  reasonCode: 'adaptive_policy_hold',
  policyVersion: 'B04-12-TEST-TARGET-POLICY-V1',
  calculationVersion: 'B04-12-TEST-TARGET-CALC-V1',
  algorithmVersion: 'B04-12-TEST-TARGET-ALGO-V1',
  direction: B04AdaptiveTargetDirection.onTrack,
  adaptiveDeltaKcal: 0,
  currentTargetKcal: 2000,
  proposedTargetKcal: null,
  normalizedMaintenanceKcal: 2000,
  medianWeightGrams: null,
  slopeGramsPerDay: null,
  weeklyRatePercent: null,
  displayWeeklyRatePercent: null,
  evidenceIds: const ['target-evidence'],
  proposal: null,
  trainingOverlay: B04TrainingOverlayResult.unavailable,
);

NutrientAggregationResult _totals({
  bool estimatedEnergy = false,
  bool missingEnergy = false,
  double? candidateEnergy,
  String sourceReferencePrefix = 'consumed',
}) {
  final facts = <String, NutrientFact>{
    'energy': missingEnergy
        ? _missingFact(
            'energy',
            NutrientUnit.kilocalorie,
            sourceReferencePrefix,
          )
        : estimatedEnergy
        ? _estimatedFact(
            'energy',
            NutrientUnit.kilocalorie,
            candidateEnergy ?? 400,
            lower: 300,
            upper: 500,
            sourceReferencePrefix: sourceReferencePrefix,
          )
        : _knownFact(
            'energy',
            NutrientUnit.kilocalorie,
            candidateEnergy ?? 400,
            sourceReferencePrefix,
          ),
    'protein': _knownFact(
      'protein',
      NutrientUnit.gram,
      20,
      sourceReferencePrefix,
    ),
    'carbohydrate': _knownFact(
      'carbohydrate',
      NutrientUnit.gram,
      50,
      sourceReferencePrefix,
    ),
    'fat': _knownFact('fat', NutrientUnit.gram, 10, sourceReferencePrefix),
  };
  final requested = facts.keys.toSet();
  final available = facts.entries
      .where((entry) => entry.value.isAvailable)
      .map((entry) => entry.key);
  final missing = facts.entries
      .where((entry) => !entry.value.isAvailable)
      .map((entry) => entry.key);
  final estimated = facts.entries
      .where((entry) => entry.value.status == NutrientFactStatus.estimated)
      .map((entry) => entry.key);
  final state = missing.isNotEmpty
      ? available.isEmpty
            ? NutrientCompletenessState.unknown
            : NutrientCompletenessState.partial
      : NutrientCompletenessState.complete;
  return NutrientAggregationResult(
    facts: Map.unmodifiable(facts),
    completeness: NutrientCompleteness(
      state: state,
      requestedNutrientIds: requested,
      availableNutrientIds: available,
      missingNutrientIds: missing,
      estimatedNutrientIds: estimated,
      notApplicableNutrientIds: const [],
      partiallyKnownNutrientIds: const [],
    ),
    sourceLineage: {
      for (final entry in facts.entries)
        entry.key: const [NutrientSourceType.bundledCatalogue],
    },
    factVersionLineage: {
      for (final entry in facts.entries) entry.key: [entry.value.factVersion],
    },
  );
}

NutrientFact _knownFact(
  String nutrientId,
  NutrientUnit unit,
  double value,
  String sourceReferencePrefix,
) => NutrientFact.known(
  nutrientId: nutrientId,
  point: NutrientAmount(value: QuantityAmount.fromNum(value), unit: unit),
  basis: NutrientBasis(NutrientBasisKind.absolute),
  source: NutrientSourceType.bundledCatalogue,
  sourceReference: '$sourceReferencePrefix-$nutrientId',
  factVersion: 'B03-12-TEST-V1',
);

NutrientFact _estimatedFact(
  String nutrientId,
  NutrientUnit unit,
  double value, {
  required double lower,
  required double upper,
  required String sourceReferencePrefix,
}) => NutrientFact.estimated(
  nutrientId: nutrientId,
  point: NutrientAmount(value: QuantityAmount.fromNum(value), unit: unit),
  lower: NutrientAmount(value: QuantityAmount.fromNum(lower), unit: unit),
  upper: NutrientAmount(value: QuantityAmount.fromNum(upper), unit: unit),
  basis: NutrientBasis(NutrientBasisKind.absolute),
  source: NutrientSourceType.bundledCatalogue,
  sourceReference: '$sourceReferencePrefix-$nutrientId',
  factVersion: 'B03-12-TEST-V1',
);

NutrientFact _missingFact(
  String nutrientId,
  NutrientUnit unit,
  String sourceReferencePrefix,
) => NutrientFact.missing(
  nutrientId: nutrientId,
  unit: unit,
  basis: NutrientBasis(NutrientBasisKind.absolute),
  source: NutrientSourceType.bundledCatalogue,
  sourceReference: '$sourceReferencePrefix-$nutrientId',
  factVersion: 'B03-12-TEST-V1',
);

B04NutritionSafetyResult _safety({
  required String subjectId,
  B04NutritionSafetyOutput output = B04NutritionSafetyOutput.eatNow,
  B04NutritionSafetyDisposition disposition =
      B04NutritionSafetyDisposition.noKnownConflict,
  B04NutritionSafetyDisposition evaluatedDisposition =
      B04NutritionSafetyDisposition.noKnownConflict,
  Iterable<String> reasonCodes = const ['no_known_conflict'],
  Iterable<String> missingEvidence = const [],
  Iterable<String> hardBlockConstraintIds = const [],
  Iterable<String> uncertainConstraintIds = const [],
  bool acknowledgementRequested = false,
  bool userOverrideRequested = false,
}) => B04NutritionSafetyResult(
  userId: _userId,
  subjectId: subjectId,
  output: output,
  disposition: disposition,
  evaluatedDisposition: evaluatedDisposition,
  constraintEvaluation: null,
  evaluatorOutcome: null,
  nutrientEvidence: null,
  reasonCodes: reasonCodes,
  evidenceIds: ['safety-$subjectId'],
  missingEvidence: missingEvidence,
  hardBlockConstraintIds: hardBlockConstraintIds,
  softFilterConstraintIds: const [],
  uncertainConstraintIds: uncertainConstraintIds,
  nutrientRangeIds: const [],
  constraintContexts: const [],
  acknowledgementRequested: acknowledgementRequested,
  userOverrideRequested: userOverrideRequested,
);
