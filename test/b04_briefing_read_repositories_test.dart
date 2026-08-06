import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import 'package:indifit/data/models/b04_adaptive_target_models.dart';
import 'package:indifit/data/models/b04_briefing_read_models.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/models/b04_recommendation_context_models.dart';
import 'package:indifit/data/models/b04_recommendation_history_models.dart';
import 'package:indifit/data/models/b04_recommendation_models.dart';
import 'package:indifit/data/models/b04_recovery_models.dart';
import 'package:indifit/data/repositories/b04_briefing_read_repositories.dart';
import 'package:indifit/data/repositories/b04_recommendation_history_repository.dart';
import 'package:indifit/features/dashboard/b04_daily_briefing_controller.dart';

const _userId = 'briefing-user';
const _timezoneId = 'America/New_York';
final _createdAt = DateTime.utc(2026, 3, 8, 12);

void main() {
  group('B04-13 daily and weekly read projections', () {
    test(
      'daily uses the requested stored local date and preserves lineage',
      () async {
        final row = _historyRow(
          id: 'daily-recommendation',
          scope: B04RecommendationHistoryScope.daily,
          start: '2026-03-08',
          end: '2026-03-08',
          timezoneId: _timezoneId,
          action: B04RecommendationAction.nutritionMeal.stableId,
          goalVersionId: 'goal-before-travel',
          readinessSnapshotId: 'readiness-daily',
        );
        final repository = B04DailyBriefingReadRepository(
          history: _FakeHistory([row]),
        );

        final result = await repository.read(
          userId: _userId,
          localDate: '2026-03-08',
          timezoneId: _timezoneId,
        );

        expect(result.status, B04BriefingReadStatus.available);
        expect(result.startLocalDate, '2026-03-08');
        expect(result.endLocalDate, '2026-03-08');
        expect(result.timezoneId, _timezoneId);
        expect(
          result.recommendations.single.goalVersionId,
          'goal-before-travel',
        );
        expect(
          result.recommendations.single.readinessSnapshotId,
          'readiness-daily',
        );
        expect(result.recommendations.single.explanation, contains('meal'));
        expect(result.accessibilityLabel, contains('2026-03-08'));
      },
    );

    test(
      'weekly requires an explicit seven-civil-day period across DST',
      () async {
        final row = _historyRow(
          id: 'weekly-recommendation',
          scope: B04RecommendationHistoryScope.weekly,
          start: '2026-03-08',
          end: '2026-03-14',
          timezoneId: _timezoneId,
          action: B04RecommendationAction.training.stableId,
        );
        final repository = B04WeeklyReviewReadRepository(
          history: _FakeHistory([row]),
        );

        final result = await repository.read(
          userId: _userId,
          startLocalDate: '2026-03-08',
          endLocalDate: '2026-03-14',
          timezoneId: _timezoneId,
        );

        expect(result.status, B04BriefingReadStatus.available);
        expect(result.recommendations.single.id, 'weekly-recommendation');

        await expectLater(
          repository.read(
            userId: _userId,
            startLocalDate: '2026-03-08',
            endLocalDate: '2026-03-13',
            timezoneId: _timezoneId,
          ),
          throwsA(
            isA<B04BriefingReadRepositoryError>().having(
              (error) => error.code,
              'code',
              'invalid_weekly_period',
            ),
          ),
        );
      },
    );

    test(
      'timezone is part of the period and cross-midnight rows do not leak',
      () async {
        final row = _historyRow(
          id: 'kolkata-row',
          scope: B04RecommendationHistoryScope.daily,
          start: '2026-08-07',
          end: '2026-08-07',
          timezoneId: 'Asia/Kolkata',
        );
        final repository = B04DailyBriefingReadRepository(
          history: _FakeHistory([row]),
        );

        final result = await repository.read(
          userId: _userId,
          localDate: '2026-08-07',
          timezoneId: 'UTC',
        );

        expect(result.status, B04BriefingReadStatus.noData);
        expect(result.recommendations, isEmpty);
      },
    );

    test(
      'no history is a truthful no-data state and remains local/offline',
      () async {
        final repository = B04DailyBriefingReadRepository(
          history: _FakeHistory(const []),
        );

        final result = await repository.read(
          userId: _userId,
          localDate: '2026-08-07',
          timezoneId: 'UTC',
        );

        expect(result.status, B04BriefingReadStatus.noData);
        expect(result.unavailableReasons, isEmpty);
        expect(result.accessibilityLabel, contains('no recommendations yet'));
      },
    );

    test(
      'under-age or unknown age, withdrawn consent and HOLD-1 stay unavailable',
      () async {
        final cases = <String, B04RecommendationEligibilityState>{
          'underage': B04RecommendationEligibilityState.underage,
          'unknown_age': B04RecommendationEligibilityState.unknownAge,
          'withheld_age': B04RecommendationEligibilityState.withheldAge,
        };
        for (final entry in cases.entries) {
          final row = _historyRow(
            id: 'held-${entry.key}',
            scope: B04RecommendationHistoryScope.daily,
            start: '2026-08-07',
            end: '2026-08-07',
            action: B04RecommendationAction.nutritionTarget.stableId,
            state: B04RecommendationState.unavailable,
            policyVersion: kB04HoldPolicyVersion,
            missingInputs: ['adaptive_policy_hold', entry.key],
            consentStatus: 'withdraw',
            eligibilityStatus: entry.key,
          );
          final repository = B04DailyBriefingReadRepository(
            history: _FakeHistory([row]),
          );

          final result = await repository.read(
            userId: _userId,
            localDate: '2026-08-07',
            timezoneId: 'UTC',
          );
          final item = result.recommendations.single;

          expect(result.status, B04BriefingReadStatus.unavailable);
          expect(result.policyState, B04RecommendationPolicyState.hold);
          expect(result.consentState, B04RecommendationConsentState.disabled);
          expect(result.eligibilityState, entry.value);
          expect(
            item.targetAcceptanceState,
            B04BriefingTargetAcceptanceState.unavailable,
          );
          expect(item.canonicalResult?.proposedDeltaKcal, isNull);
          expect(result.accessibilityLabel, contains('adaptive policy hold'));
        }
      },
    );

    test(
      'feedback is projected without rewriting history and target acceptance remains reachable',
      () async {
        final dismissed = _historyRow(
          id: 'dismissed',
          scope: B04RecommendationHistoryScope.weekly,
          start: '2026-08-03',
          end: '2026-08-09',
          goalVersionId: 'goal-old',
          feedback: [
            _feedback(
              'dismissed-feedback',
              B04RecommendationFeedbackAction.dismiss,
            ),
          ],
        );
        final accepted = _historyRow(
          id: 'accepted-target',
          scope: B04RecommendationHistoryScope.weekly,
          start: '2026-08-03',
          end: '2026-08-09',
          action: B04RecommendationAction.nutritionTarget.stableId,
          policyVersion: kB04EnabledPolicyVersion,
          goalVersionId: 'goal-new',
          proposedDeltaKcal: 100,
          feedback: [
            _feedback(
              'accepted-feedback',
              B04RecommendationFeedbackAction.accept,
            ),
          ],
        );
        final repository = B04WeeklyReviewReadRepository(
          history: _FakeHistory([dismissed, accepted]),
        );

        final result = await repository.read(
          userId: _userId,
          startLocalDate: '2026-08-03',
          endLocalDate: '2026-08-09',
          timezoneId: 'UTC',
        );

        final dismissedItem = result.recommendations.singleWhere(
          (item) => item.id == 'dismissed',
        );
        final acceptedItem = result.recommendations.singleWhere(
          (item) => item.id == 'accepted-target',
        );
        expect(result.recommendations, hasLength(2));
        expect(dismissedItem.feedbackState, B04BriefingFeedbackState.dismissed);
        expect(dismissedItem.isVisible, isFalse);
        expect(dismissedItem.goalVersionId, 'goal-old');
        expect(acceptedItem.feedbackState, B04BriefingFeedbackState.accepted);
        expect(
          acceptedItem.targetAcceptanceState,
          B04BriefingTargetAcceptanceState.accepted,
        );
        expect(acceptedItem.canonicalResult?.proposedDeltaKcal, 100);
        expect(acceptedItem.goalVersionId, 'goal-new');
      },
    );

    test(
      'live projection delegates to the canonical engine and preserves its explanation',
      () {
        final repository = B04DailyBriefingReadRepository(
          history: _FakeHistory(const []),
        );
        final context = _context();

        final result = repository.evaluate(
          context: context,
          candidates: [
            B04RecommendationCandidate(
              id: 'education-1',
              action: B04RecommendationAction.education,
              rationaleCode: 'evidence_review',
              evidence: B04RecommendationEvidence(
                state: B04RecommendationEvidenceState.complete,
                evidenceIds: const ['education-evidence'],
              ),
            ),
          ],
        );

        expect(result.status, B04BriefingReadStatus.available);
        expect(result.recommendations.single.engineRecommendation, isNotNull);
        expect(
          result.recommendations.single.explanation,
          result.recommendations.single.engineRecommendation!.explanation,
        );
        expect(result.recommendations.single.evidenceIds, [
          'education-evidence',
        ]);
      },
    );

    test(
      'missing nutrition and readiness evidence remains unavailable, never zero',
      () {
        final repository = B04DailyBriefingReadRepository(
          history: _FakeHistory(const []),
        );

        final result = repository.evaluate(
          context: _context(
            omitReadiness: true,
            availability: B04ContextAvailability.evidenceLimited,
            missingEvidence: const [
              B04MissingEvidence(
                kind: B04MissingEvidenceKind.nutritionTotals,
                reasonCode: 'daily_totals_unavailable',
              ),
              B04MissingEvidence(
                kind: B04MissingEvidenceKind.readiness,
                reasonCode: 'readiness_unavailable',
              ),
            ],
          ),
          candidates: [
            B04RecommendationCandidate(
              id: 'training-1',
              action: B04RecommendationAction.training,
              rationaleCode: 'readiness_review',
              evidence: B04RecommendationEvidence(
                state: B04RecommendationEvidenceState.complete,
                evidenceIds: const ['training-evidence'],
              ),
            ),
          ],
        );

        expect(result.status, B04BriefingReadStatus.unavailable);
        expect(result.missingEvidence, contains('daily_totals_unavailable'));
        expect(result.missingEvidence, contains('readiness_unavailable'));
        expect(
          result.recommendations.single.state,
          B04RecommendationState.unavailable,
        );
        expect(result.recommendations.single.canonicalResult, isNull);
      },
    );

    test(
      'controller exposes failure instead of converting a read error to empty data',
      () async {
        final repository = B04DailyBriefingReadRepository(
          history: _FakeHistory.failure(),
        );
        final controller = B04DailyBriefingController(repository: repository);

        await controller.load(
          userId: _userId,
          localDate: '2026-08-07',
          timezoneId: 'UTC',
        );

        expect(
          controller.state.status,
          B04DailyBriefingControllerStatus.failure,
        );
        expect(controller.state.errorCode, 'history_offline');
        expect(controller.state.retryable, isTrue);
      },
    );
  });
}

class _FakeHistory implements B04BriefingHistorySource {
  final List<B04HistoricalRecommendation> rows;
  final Object? error;

  const _FakeHistory(this.rows) : error = null;

  _FakeHistory.failure() : rows = const [], error = _HistoryOfflineError();

  @override
  Future<List<B04HistoricalRecommendation>> listHistory({
    required String userId,
    B04RecommendationHistoryScope? scope,
  }) async {
    if (error != null) {
      throw const B04BriefingReadRepositoryError(
        'history_offline',
        'History is unavailable offline.',
      );
    }
    return [
      for (final row in rows)
        if (scope == null || row.scope == scope) row,
    ];
  }
}

class _HistoryOfflineError implements Exception {
  const _HistoryOfflineError();
}

B04HistoricalRecommendation _historyRow({
  required String id,
  required B04RecommendationHistoryScope scope,
  required String start,
  required String end,
  String timezoneId = 'UTC',
  String action = 'nutrition_meal',
  B04RecommendationState state = B04RecommendationState.available,
  String policyVersion = kB04HoldPolicyVersion,
  List<String> missingInputs = const [],
  String? goalVersionId,
  String? readinessSnapshotId,
  int? proposedDeltaKcal,
  String consentStatus = 'enable',
  String eligibilityStatus = 'eligible',
  List<B04RecommendationFeedbackRecord> feedback = const [],
}) => B04HistoricalRecommendation(
  id: id,
  userId: _userId,
  scope: scope,
  localPeriodStart: start,
  localPeriodEnd: end,
  timezoneId: timezoneId,
  state: state,
  priority: action == B04RecommendationAction.nutritionTarget.stableId
      ? B04RecommendationPriority.nutrition
      : B04RecommendationPriority.education,
  confidence: state == B04RecommendationState.unavailable ? null : 1,
  completeness: state == B04RecommendationState.unavailable
      ? B04RecommendationCompleteness.missing
      : B04RecommendationCompleteness.complete,
  action: action,
  explanation: 'Review this meal or training evidence.',
  missingInputs: missingInputs,
  uncertainty: const [],
  alternatives: const ['alternative-1'],
  ruleVersion: kB04RecommendationRuleVersion,
  calculationVersion: 'B04-07-TARGET-V1',
  algorithmVersion: kB04RecommendationAlgorithmVersion,
  modelVersion: null,
  providerVersion: null,
  policyVersion: policyVersion,
  goalVersionId: goalVersionId ?? 'goal-default',
  readinessSnapshotId: readinessSnapshotId,
  contextFingerprint: 'context-fingerprint-$id',
  evidenceFingerprint: 'evidence-fingerprint-$id',
  exactResultNumerator: proposedDeltaKcal == null ? null : '1',
  exactResultDenominator: proposedDeltaKcal == null ? null : '1',
  normalizedMaintenanceKcal: proposedDeltaKcal == null ? null : 2000,
  proposedDeltaKcal: proposedDeltaKcal,
  createdAtUtc: _createdAt,
  effectiveAtUtc: _createdAt,
  supersededAtUtc: null,
  supersedesRecommendationId: null,
  replayHash: 'replay-$id',
  evidence: [
    _evidence(
      id: 'consent-evidence-$id',
      recommendationId: id,
      kind: 'consent',
      status: consentStatus,
      sourceId: 'consent-$id',
    ),
    _evidence(
      id: 'eligibility-evidence-$id',
      recommendationId: id,
      kind: 'eligibility',
      status: eligibilityStatus,
      sourceId: 'eligibility-$id',
    ),
  ],
  feedback: feedback,
);

B04RecommendationEvidenceRecord _evidence({
  required String id,
  required String recommendationId,
  required String kind,
  required String status,
  required String sourceId,
}) => B04RecommendationEvidenceRecord(
  id: id,
  recommendationId: recommendationId,
  userId: _userId,
  evidenceKind: kind,
  sourceType: '${kind}_source',
  sourceId: sourceId,
  sourceVersion: 'v1',
  status: status,
  value: null,
  lower: null,
  upper: null,
  unit: null,
  exactResultNumerator: null,
  exactResultDenominator: null,
  normalizedMaintenanceKcal: null,
  localDate: '2026-08-07',
  timezoneId: 'UTC',
  createdAtUtc: _createdAt,
);

B04RecommendationFeedbackRecord _feedback(
  String id,
  B04RecommendationFeedbackAction action,
) => B04RecommendationFeedbackRecord(
  id: id,
  userId: _userId,
  recommendationId: id.startsWith('dismissed')
      ? 'dismissed'
      : 'accepted-target',
  action: action,
  reason: null,
  source: 'test',
  localDate: '2026-08-07',
  timezoneId: 'UTC',
  createdAtUtc: _createdAt,
  relatedFeedbackId: null,
);

B04RecommendationContext _context({
  B04ContextAvailability availability = B04ContextAvailability.available,
  Iterable<B04MissingEvidence> missingEvidence = const [],
  bool omitReadiness = false,
}) => B04RecommendationContext(
  contextId: 'context-1',
  userId: _userId,
  window: const B04RecommendationWindow(
    period: B04RecommendationPeriod.daily,
    startLocalDate: '2026-08-07',
    endLocalDate: '2026-08-07',
    timezoneId: 'UTC',
    targetEvaluationWindowDays: 21,
    aggregateWindowDays: 42,
  ),
  evaluatedAtUtc: DateTime.utc(2026, 8, 7, 12),
  availability: availability,
  activeGoal: NutritionGoalVersionReadModel(
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
    timezoneId: 'UTC',
    supersedesGoalVersionId: null,
    evidenceFingerprint: 'goal-evidence',
    exactResultNumerator: null,
    exactResultDenominator: null,
    normalizedMaintenanceKcal: 2000,
    createdAtUtc: DateTime.utc(2026, 8, 1),
  ),
  preferences: const CoachingPreferencesReadModel(
    userId: _userId,
    adaptiveCoachingEnabled: true,
    optionalAiEnabled: false,
    adaptiveCoachingEvent: null,
    optionalAiEvent: null,
  ),
  eligibility: CoachingEligibilityReadModel(
    userId: _userId,
    result: CoachingEligibilityResult.eligible,
    reasonCode: 'eligible',
    policyVersion: 'B04-05-ELIGIBILITY-V1',
    evaluationLocalDate: '2026-08-07',
    timezoneId: 'UTC',
    evaluationUtc: DateTime.utc(2026, 8, 7),
  ),
  readiness: omitReadiness
      ? null
      : const B04ReadinessContext(
          snapshotId: 'readiness-1',
          localDate: '2026-08-07',
          timezoneId: 'UTC',
          completeness: ReadinessCompleteness.complete,
          status: ReadinessStatus.available,
          band: ReadinessBand.ready,
          confidence: 1,
          calculationVersion: 'B04-06-READINESS-V1',
          policyVersion: 'READINESS-HOLD-1',
          evidenceObservationIds: ['readiness-evidence'],
        ),
  workload: null,
  schedule: null,
  nutrition: const B04NutritionContext(
    days: [],
    expectedLocalDates: ['2026-08-07'],
    missingLocalDates: [],
  ),
  constraints: const [],
  targetResult: B04AdaptiveTargetResult(
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
    evidenceIds: ['target-evidence'],
    proposal: null,
    trainingOverlay: B04TrainingOverlayResult.unavailable,
  ),
  mealOpportunity: null,
  missingEvidence: List.unmodifiable(missingEvidence),
  n8: B04N8Context.absent,
);
