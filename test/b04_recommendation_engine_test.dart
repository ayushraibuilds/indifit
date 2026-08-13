import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import 'package:indifit/data/models/b04_adaptive_target_models.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/models/b04_nutrition_safety_models.dart';
import 'package:indifit/data/models/b04_recommendation_context_models.dart';
import 'package:indifit/data/models/b04_recommendation_models.dart';
import 'package:indifit/data/models/b04_recovery_models.dart';
import 'package:indifit/data/services/b04_recommendation_engine.dart';

const _userId = 'user-recommendation';
const _timezoneId = 'Asia/Kolkata';
final _evaluatedAt = DateTime.utc(2026, 8, 6, 12);

void main() {
  const engine = B04RecommendationEngine();

  test('golden ranking is stable across action types and input order', () {
    final result = engine.evaluate(
      context: _context(),
      candidates: [
        _candidate(
          id: 'education-general',
          action: B04RecommendationAction.education,
        ),
        _candidate(
          id: 'training-urgent',
          action: B04RecommendationAction.training,
          urgent: true,
        ),
        _candidate(
          id: 'training-selected',
          action: B04RecommendationAction.training,
          userSelected: true,
        ),
      ],
    );

    expect(result.recommendations.map((item) => item.id), [
      'training-urgent',
      'training-selected',
      'education-general',
    ]);
    expect(result.recommendations.every(_isAvailable), isTrue);
    expect(result.recommendations.first.explanation, contains('Evidence:'));
    expect(
      result.recommendations.first.policyState,
      B04RecommendationPolicyState.hold,
    );
  });

  test(
    'weekly evaluation uses the same contract with explicit gate states',
    () {
      final result = engine.evaluate(
        context: _context(
          period: B04RecommendationPeriod.weekly,
          startLocalDate: '2026-08-03',
          endLocalDate: '2026-08-09',
          eligibilityResult: CoachingEligibilityResult.unknownAge,
          adaptiveConsentEnabled: false,
        ),
        candidates: [
          _candidate(
            id: 'training-weekly',
            action: B04RecommendationAction.training,
          ),
        ],
      );

      expect(result.period, B04RecommendationPeriod.weekly);
      expect(
        result.eligibilityState,
        B04RecommendationEligibilityState.unknownAge,
      );
      expect(result.consentState, B04RecommendationConsentState.disabled);
      expect(result.policyState, B04RecommendationPolicyState.hold);
      expect(
        result.recommendations.single.state,
        B04RecommendationState.unavailable,
      );
      expect(
        result.recommendations.single.unavailableReasons,
        contains('eligibility_unknown_age'),
      );
      expect(
        result.recommendations.single.unavailableReasons,
        contains('adaptive_consent_disabled'),
      );
    },
  );

  test(
    'direct engine input validates IANA timezone and civil period shape',
    () {
      expect(
        () => engine.evaluate(
          context: _context(timezoneId: 'Not/IANA'),
          candidates: [
            _candidate(
              id: 'training-invalid-time',
              action: B04RecommendationAction.training,
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => engine.evaluate(
          context: _context(
            period: B04RecommendationPeriod.weekly,
            startLocalDate: '2026-08-03',
            endLocalDate: '2026-08-08',
          ),
          candidates: [
            _candidate(
              id: 'training-invalid-week',
              action: B04RecommendationAction.training,
            ),
          ],
        ),
        throwsArgumentError,
      );
    },
  );

  test('ties use a stable candidate ID tie-breaker, never input order', () {
    final first = engine.evaluate(
      context: _context(),
      candidates: [
        _candidate(id: 'training-z', action: B04RecommendationAction.training),
        _candidate(id: 'training-a', action: B04RecommendationAction.training),
      ],
    );
    final second = engine.evaluate(
      context: _context(),
      candidates: [
        _candidate(id: 'training-a', action: B04RecommendationAction.training),
        _candidate(id: 'training-z', action: B04RecommendationAction.training),
      ],
    );

    expect(first.recommendations.map((item) => item.id), [
      'training-a',
      'training-z',
    ]);
    expect(first.toRedactedMap(), second.toRedactedMap());
  });

  test(
    'missing context evidence makes the entire ranked result unavailable',
    () {
      final result = engine.evaluate(
        context: _context(
          availability: B04ContextAvailability.evidenceLimited,
          missingEvidence: const [
            B04MissingEvidence(
              kind: B04MissingEvidenceKind.nutritionTotals,
              reasonCode: 'daily_totals_unknown',
              localDate: '2026-08-06',
            ),
          ],
        ),
        candidates: [
          _candidate(
            id: 'training-1',
            action: B04RecommendationAction.training,
          ),
        ],
      );

      final recommendation = result.recommendations.single;
      expect(recommendation.state, B04RecommendationState.unavailable);
      expect(
        recommendation.unavailableReasons,
        contains('daily_totals_unknown'),
      );
      expect(result.availableRecommendations, isEmpty);
    },
  );

  test(
    'hard, possible, unknown, insufficient, missing, and invalid dietary evidence cannot bypass safety',
    () {
      final cases = <B04NutritionSafetyResult>[
        _safety(
          disposition: B04NutritionSafetyDisposition.hardBlock,
          evaluatedDisposition: B04NutritionSafetyDisposition.hardBlock,
          evidenceIds: const ['confirmed-conflict'],
          hardBlockConstraintIds: const ['constraint-peanut'],
          reasonCodes: const ['confirmed_conflict'],
        ),
        _safety(
          disposition: B04NutritionSafetyDisposition.unavailable,
          evaluatedDisposition: B04NutritionSafetyDisposition.unavailable,
          evidenceIds: const ['possible-conflict'],
          uncertainConstraintIds: const ['constraint-peanut'],
          reasonCodes: const ['possible_conflict'],
        ),
        _safety(
          disposition: B04NutritionSafetyDisposition.unavailable,
          evaluatedDisposition: B04NutritionSafetyDisposition.unavailable,
          evidenceIds: const ['unknown-conflict'],
          uncertainConstraintIds: const ['constraint-peanut'],
          reasonCodes: const ['unknown_conflict'],
        ),
        _safety(
          disposition: B04NutritionSafetyDisposition.unavailable,
          evaluatedDisposition: B04NutritionSafetyDisposition.unavailable,
          missingEvidence: const ['insufficient_nutrient_evidence'],
          reasonCodes: const ['insufficient_evidence'],
        ),
        _safety(
          disposition: B04NutritionSafetyDisposition.unavailable,
          evaluatedDisposition: B04NutritionSafetyDisposition.unavailable,
          missingEvidence: const ['missing_constraint_evidence'],
          reasonCodes: const ['missing_evidence'],
        ),
        B04NutritionSafetyResult.invalidEvidence(
          userId: _userId,
          subjectId: 'meal-invalid',
          output: B04NutritionSafetyOutput.eatNow,
          errorCode: 'invalid_evidence',
        ),
      ];

      for (final item in cases) {
        final result = engine.evaluate(
          context: _context(),
          candidates: [
            _candidate(
              id: 'meal-${cases.indexOf(item)}',
              action: B04RecommendationAction.nutritionMeal,
              safety: item,
            ),
          ],
        );
        expect(
          result.recommendations.single.state,
          B04RecommendationState.unavailable,
        );
        expect(result.availableRecommendations, isEmpty);
      }
    },
  );

  test(
    'conflicting mapped safety state fails closed on the evaluator state',
    () {
      final result = engine.evaluate(
        context: _context(),
        candidates: [
          _candidate(
            id: 'conflicting-safety',
            action: B04RecommendationAction.nutritionMeal,
            safety: _safety(
              disposition: B04NutritionSafetyDisposition.noKnownConflict,
              evaluatedDisposition: B04NutritionSafetyDisposition.hardBlock,
              evidenceIds: const ['conflicting-evidence'],
              hardBlockConstraintIds: const ['constraint-conflict'],
            ),
          ),
          _candidate(
            id: 'training-available',
            action: B04RecommendationAction.training,
          ),
        ],
      );

      expect(result.availableRecommendations.map((item) => item.id), [
        'training-available',
      ]);
      expect(result.recommendations.first.id, 'conflicting-safety');
      expect(
        result.recommendations.first.explanation,
        contains('blocked by the recorded dietary constraint'),
      );
      expect(
        result.recommendations.first.explanation,
        isNot(contains('No known conflict')),
      );
      expect(
        result.recommendations.first.unavailableReasons,
        contains('dietary_hard_block'),
      );
      expect(
        result.recommendations.first.safetyDisposition,
        B04NutritionSafetyDisposition.hardBlock,
      );
    },
  );

  test('low-risk logging preserves the warning outside recommendations', () {
    final safety = _safety(
      output: B04NutritionSafetyOutput.lowRiskLogging,
      disposition: B04NutritionSafetyDisposition.lowRiskLoggingOnly,
      evaluatedDisposition: B04NutritionSafetyDisposition.unavailable,
      evidenceIds: const ['low-risk-evidence'],
      reasonCodes: const ['acknowledgement_does_not_change_safety'],
    );
    final result = engine.evaluate(
      context: _context(),
      candidates: [
        _candidate(
          id: 'meal-log-only',
          action: B04RecommendationAction.nutritionMeal,
          safety: safety,
        ),
      ],
    );

    expect(result.availableRecommendations, isEmpty);
    expect(result.lowRiskWarnings, hasLength(1));
    expect(result.lowRiskWarnings.single.wording, contains('does not make'));
    expect(result.recommendations, isEmpty);
  });

  test('blank evidence identifiers cannot make an available result valid', () {
    expect(
      () => B04Recommendation(
        id: 'blank-evidence',
        action: B04RecommendationAction.education,
        state: B04RecommendationState.available,
        priority: B04RecommendationPriority.education,
        rationaleCode: 'blank_evidence',
        explanation: 'General wellness guidance only; not medical advice.',
        confidence: B04RecommendationConfidence.high,
        completeness: B04RecommendationCompleteness.complete,
        evidenceIds: const [''],
        eligibilityState: B04RecommendationEligibilityState.eligible,
        consentState: B04RecommendationConsentState.enabled,
        policyState: B04RecommendationPolicyState.hold,
        policyVersion: kB04HoldPolicyVersion,
        ruleVersion: kB04RecommendationRuleVersion,
        algorithmVersion: kB04RecommendationAlgorithmVersion,
        copyVersion: kB04RecommendationCopyVersion,
        targetAcceptanceState:
            B04RecommendationTargetAcceptanceState.notApplicable,
        canonicalAdaptiveTarget: null,
        canonicalTrainingRecommendation: null,
        safetyDisposition: null,
      ),
      throwsArgumentError,
    );
  });

  test('range and conflict states remain explicit and unavailable', () {
    final rangeSafety = _safety(
      disposition: B04NutritionSafetyDisposition.unavailable,
      evaluatedDisposition: B04NutritionSafetyDisposition.unavailable,
      evidenceIds: const ['range-evidence'],
      nutrientRangeIds: const ['energy-range-1'],
      reasonCodes: const ['range_crosses_decision_boundary'],
    );
    final conflictSafety = _safety(
      disposition: B04NutritionSafetyDisposition.hardBlock,
      evaluatedDisposition: B04NutritionSafetyDisposition.hardBlock,
      evidenceIds: const ['conflict-evidence'],
      hardBlockConstraintIds: const ['constraint-1'],
      reasonCodes: const ['confirmed_conflict'],
    );
    final result = engine.evaluate(
      context: _context(),
      candidates: [
        _candidate(
          id: 'range',
          action: B04RecommendationAction.nutritionMeal,
          safety: rangeSafety,
        ),
        _candidate(
          id: 'conflict',
          action: B04RecommendationAction.nutritionMeal,
          safety: conflictSafety,
        ),
      ],
    );

    expect(result.recommendations[0].id, 'conflict');
    expect(result.recommendations[0].safetyConstraintIds, ['constraint-1']);
    expect(result.recommendations[1].safetyNutrientRangeIds, [
      'energy-range-1',
    ]);
    expect(
      result.recommendations[1].unavailableReasons,
      contains('dietary_unavailable'),
    );
    expect(result.availableRecommendations, isEmpty);
  });

  test(
    'readiness-incomplete training input is unavailable, not zero-filled',
    () {
      final result = engine.evaluate(
        context: _context(omitReadiness: true),
        candidates: [
          _candidate(
            id: 'training-1',
            action: B04RecommendationAction.training,
          ),
        ],
      );

      final recommendation = result.recommendations.single;
      expect(recommendation.state, B04RecommendationState.unavailable);
      expect(
        recommendation.unavailableReasons,
        contains('readiness_incomplete'),
      );
      expect(recommendation.explanation, contains('readiness_incomplete'));
    },
  );

  test(
    'HOLD-1 target recommendations are unavailable with canonical zero delta',
    () {
      final target = _target();
      final result = engine.evaluate(
        context: _context(target: target),
        candidates: [
          _candidate(
            id: 'adaptive-target',
            action: B04RecommendationAction.nutritionTarget,
            safety: _safety(
              output: B04NutritionSafetyOutput.adaptiveTarget,
              evidenceIds: const ['dietary-evidence'],
            ),
          ),
        ],
      );

      final recommendation = result.recommendations.single;
      expect(recommendation.state, B04RecommendationState.unavailable);
      expect(
        recommendation.unavailableReasons,
        contains('adaptive_policy_hold'),
      );
      expect(
        recommendation.targetAcceptanceState,
        B04RecommendationTargetAcceptanceState.unavailable,
      );
      expect(recommendation.canonicalAdaptiveTarget, same(target));
      expect(recommendation.canonicalAdaptiveTarget!.adaptiveDeltaKcal, 0);
      expect(
        recommendation.canonicalAdaptiveTarget!.proposedTargetKcal,
        isNull,
      );
    },
  );

  test(
    'frozen offline evaluation replays exactly without identity leakage',
    () {
      final candidates = [
        _candidate(id: 'training-1', action: B04RecommendationAction.training),
        _candidate(
          id: 'meal-1',
          action: B04RecommendationAction.nutritionMeal,
          safety: _safety(evidenceIds: const ['dietary-evidence']),
        ),
      ];
      final first = engine.evaluate(
        context: _context(),
        candidates: candidates,
      );
      final second = engine.evaluate(
        context: _context(),
        candidates: candidates,
      );

      expect(first.fingerprint, second.fingerprint);
      expect(first.contextFingerprint, second.contextFingerprint);
      expect(first.toRedactedMap(), second.toRedactedMap());
      final changedContext = engine.evaluate(
        context: _context(
          target: _target(evidenceId: 'changed-target-evidence'),
        ),
        candidates: candidates,
      );
      expect(
        changedContext.contextFingerprint,
        isNot(first.contextFingerprint),
      );
      expect(changedContext.fingerprint, isNot(first.fingerprint));
      final encoded = jsonEncode(first.toRedactedMap());
      expect(encoded, isNot(contains(_userId)));
      expect(encoded, isNot(contains('prompt')));
      expect(encoded, isNot(contains('raw_health')));
    },
  );

  test('nutrition safety output scope cannot be reused for another action', () {
    final result = engine.evaluate(
      context: _context(),
      candidates: [
        _candidate(
          id: 'wrong-safety-scope',
          action: B04RecommendationAction.nutritionTarget,
          safety: _safety(evidenceIds: const ['eat-now-evidence']),
        ),
      ],
    );

    expect(
      result.recommendations.single.state,
      B04RecommendationState.unavailable,
    );
    expect(
      result.recommendations.single.unavailableReasons,
      contains('dietary_safety_scope_mismatch'),
    );
    expect(
      result.recommendations.single.explanation,
      contains('Safety-sensitive guidance is unavailable'),
    );
  });
}

bool _isAvailable(B04Recommendation item) =>
    item.state != B04RecommendationState.unavailable;

B04RecommendationCandidate _candidate({
  required String id,
  required B04RecommendationAction action,
  bool urgent = false,
  bool userSelected = false,
  B04NutritionSafetyResult? safety,
  B04RecommendationEvidence? evidence,
}) => B04RecommendationCandidate(
  id: id,
  action: action,
  rationaleCode: 'fixture_$id',
  evidence:
      evidence ??
      B04RecommendationEvidence(
        state: B04RecommendationEvidenceState.complete,
        evidenceIds: ['evidence_$id'],
      ),
  urgent: urgent,
  userSelected: userSelected,
  nutritionSafety: safety,
);

B04RecommendationContext _context({
  B04ContextAvailability availability = B04ContextAvailability.available,
  Iterable<B04MissingEvidence> missingEvidence = const [],
  B04ReadinessContext? readiness,
  bool omitReadiness = false,
  B04AdaptiveTargetResult? target,
  B04RecommendationPeriod period = B04RecommendationPeriod.daily,
  String startLocalDate = '2026-08-06',
  String endLocalDate = '2026-08-06',
  String timezoneId = _timezoneId,
  CoachingEligibilityResult eligibilityResult =
      CoachingEligibilityResult.eligible,
  bool adaptiveConsentEnabled = true,
}) => B04RecommendationContext(
  contextId: 'context-1',
  userId: _userId,
  window: B04RecommendationWindow(
    period: period,
    startLocalDate: startLocalDate,
    endLocalDate: endLocalDate,
    timezoneId: timezoneId,
    targetEvaluationWindowDays: 21,
    aggregateWindowDays: 42,
  ),
  evaluatedAtUtc: _evaluatedAt,
  availability: availability,
  activeGoal: _goal(),
  preferences: CoachingPreferencesReadModel(
    userId: _userId,
    adaptiveCoachingEnabled: adaptiveConsentEnabled,
    optionalAiEnabled: false,
    adaptiveCoachingEvent: null,
    optionalAiEvent: null,
  ),
  eligibility: CoachingEligibilityReadModel(
    userId: _userId,
    result: eligibilityResult,
    reasonCode: 'eligible',
    policyVersion: 'B04-05-ELIGIBILITY-V1',
    evaluationLocalDate: startLocalDate,
    timezoneId: _timezoneId,
    evaluationUtc: _evaluatedAt,
  ),
  readiness: omitReadiness
      ? null
      : readiness ??
            const B04ReadinessContext(
              snapshotId: 'readiness-1',
              localDate: '2026-08-06',
              timezoneId: _timezoneId,
              completeness: ReadinessCompleteness.complete,
              status: ReadinessStatus.available,
              band: ReadinessBand.ready,
              confidence: 0.9,
              calculationVersion: 'B04-06-READINESS-V1',
              policyVersion: 'READINESS-HOLD-1',
              evidenceObservationIds: ['readiness-observation-1'],
            ),
  workload: null,
  schedule: null,
  nutrition: const B04NutritionContext(
    days: [],
    expectedLocalDates: ['2026-08-06'],
    missingLocalDates: [],
  ),
  constraints: const [],
  targetResult: target ?? _target(),
  mealOpportunity: null,
  missingEvidence: List.unmodifiable(missingEvidence),
  n8: B04N8Context.absent,
);

NutritionGoalVersionReadModel _goal() => NutritionGoalVersionReadModel(
  id: 'goal-1',
  userId: _userId,
  versionNumber: 1,
  goalType: NutritionGoalType.maintenance,
  source: NutritionGoalSource.userSet,
  calorieTargetKcal: 2000,
  proteinTargetG: 120,
  carbsTargetG: 240,
  fatTargetG: 70,
  policyVersion: kB04HoldPolicyVersion,
  calculationVersion: 'B04-07-TARGET-V1',
  algorithmVersion: 'B04-07-TREND-V1',
  effectiveFromLocalDate: '2026-08-01',
  effectiveToLocalDate: null,
  timezoneId: _timezoneId,
  supersedesGoalVersionId: null,
  evidenceFingerprint: 'goal-evidence',
  exactResultNumerator: null,
  exactResultDenominator: null,
  normalizedMaintenanceKcal: 2000,
  createdAtUtc: DateTime.utc(2026, 8, 1),
);

B04AdaptiveTargetResult _target({String evidenceId = 'target-evidence'}) =>
    B04AdaptiveTargetResult(
      status: B04AdaptiveTargetStatus.unavailable,
      reasonCode: 'adaptive_policy_hold',
      policyVersion: kB04HoldPolicyVersion,
      calculationVersion: 'B04-07-TARGET-V1',
      algorithmVersion: 'B04-07-TREND-V1',
      direction: B04AdaptiveTargetDirection.onTrack,
      adaptiveDeltaKcal: 0,
      currentTargetKcal: 2000,
      proposedTargetKcal: null,
      normalizedMaintenanceKcal: 2000,
      medianWeightGrams: null,
      slopeGramsPerDay: null,
      weeklyRatePercent: null,
      displayWeeklyRatePercent: null,
      evidenceIds: [evidenceId],
      proposal: null,
      trainingOverlay: B04TrainingOverlayResult.unavailable,
    );

B04NutritionSafetyResult _safety({
  B04NutritionSafetyOutput output = B04NutritionSafetyOutput.eatNow,
  B04NutritionSafetyDisposition disposition =
      B04NutritionSafetyDisposition.noKnownConflict,
  B04NutritionSafetyDisposition evaluatedDisposition =
      B04NutritionSafetyDisposition.noKnownConflict,
  Iterable<String> reasonCodes = const ['no_known_conflict'],
  Iterable<String> evidenceIds = const [],
  Iterable<String> missingEvidence = const [],
  Iterable<String> hardBlockConstraintIds = const [],
  Iterable<String> uncertainConstraintIds = const [],
  Iterable<String> nutrientRangeIds = const [],
}) => B04NutritionSafetyResult(
  userId: _userId,
  subjectId: 'meal-1',
  output: output,
  disposition: disposition,
  evaluatedDisposition: evaluatedDisposition,
  constraintEvaluation: null,
  evaluatorOutcome: null,
  nutrientEvidence: null,
  reasonCodes: reasonCodes,
  evidenceIds: evidenceIds,
  missingEvidence: missingEvidence,
  hardBlockConstraintIds: hardBlockConstraintIds,
  softFilterConstraintIds: const [],
  uncertainConstraintIds: uncertainConstraintIds,
  nutrientRangeIds: nutrientRangeIds,
  constraintContexts: const [],
);
