import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_v9.dart';
import 'package:indifit/core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b04_adaptive_target_models.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/models/b04_recommendation_context_models.dart';
import 'package:indifit/data/models/b04_recommendation_history_models.dart';
import 'package:indifit/data/models/b04_recommendation_models.dart';
import 'package:indifit/data/repositories/b04_recommendation_history_repository.dart';
import 'package:indifit/data/repositories/coaching_preference_repository.dart';
import 'package:indifit/data/repositories/nutrition_goal_repository.dart';

const _userId = 'history-user';
const _timezoneId = 'Asia/Kolkata';
final _issuedAt = DateTime.utc(2026, 8, 6, 12);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late B04RecommendationHistoryRepository history;

  setUp(() {
    db = AppDatabase.memory();
    history = B04RecommendationHistoryRepository(database: db);
  });

  tearDown(() => db.close());

  test(
    'issued history freezes typed lineage and survives later corrections',
    () async {
      final lineage = await _seedLineage(db);
      final command = _command(
        consentEventId: lineage.consentId,
        eligibilityEvaluationId: lineage.eligibilityId,
        goalVersionId: lineage.goalId,
      );

      final issued = (await history.issue(command)).single;
      expect(issued.consentEventId, lineage.consentId);
      expect(issued.eligibilityEvaluationId, lineage.eligibilityId);
      expect(issued.goalVersionId, lineage.goalId);
      expect(issued.ruleVersion, kB04RecommendationRuleVersion);
      expect(issued.contextFingerprint, 'context-v1');
      expect(
        issued.evidence
            .singleWhere((item) => item.evidenceKind == 'training')
            .sourceId,
        'training-source',
      );
      expect(issued.evidenceFingerprint, isNotEmpty);

      await CoachingPreferenceRepository(database: db).recordConsent(
        CoachingConsentCommand(
          userId: _userId,
          category: CoachingConsentCategory.adaptiveCoaching,
          action: CoachingConsentAction.disable,
          consentPolicyVersion: kB04EnabledPolicyVersion,
          copyVersion: 'copy-v1',
          timestampUtc: DateTime.utc(2026, 8, 7),
          localDate: '2026-08-07',
          timezoneId: _timezoneId,
          actorSource: 'settings',
          eventId: 'consent-disable',
        ),
      );
      await db
          .into(db.coachingEligibilityEvaluations)
          .insert(
            CoachingEligibilityEvaluationsCompanion.insert(
              id: 'eligibility-underage',
              userId: _userId,
              result: 'underage',
              reasonCode: 'age_changed',
              ageInputSource: 'verified_dob',
              evidenceTimestampUtc: DateTime.utc(2026, 8, 7),
              evaluationUtc: DateTime.utc(2026, 8, 7),
              evaluationLocalDate: '2026-08-07',
              timezoneId: _timezoneId,
              policyVersion: kB04EnabledPolicyVersion,
              minimumAgeRuleVersion: 'minimum-age-v1',
            ),
          );

      final reread = (await history.listHistory(userId: _userId)).single;
      expect(reread.id, issued.id);
      expect(reread.consentEventId, lineage.consentId);
      expect(reread.eligibilityEvaluationId, lineage.eligibilityId);
      expect(reread.explanation, 'Use the planned training session.');
    },
  );

  test(
    'supersession is an append-only lineage edge and current reads are derived',
    () async {
      final lineage = await _seedLineage(db);
      final first = (await history.issue(
        _command(
          consentEventId: lineage.consentId,
          eligibilityEvaluationId: lineage.eligibilityId,
          goalVersionId: lineage.goalId,
        ),
      )).single;
      final second = (await history.issue(
        _command(
          id: 'training-2',
          fingerprint: 'evaluation-v2',
          contextFingerprint: 'context-v2',
          evaluatedAtUtc: DateTime.utc(2026, 8, 6, 13),
          evidenceId: 'training-source-v2',
          consentEventId: lineage.consentId,
          eligibilityEvaluationId: lineage.eligibilityId,
          goalVersionId: lineage.goalId,
          supersedes: first.id,
        ),
      )).single;

      expect(second.supersedesRecommendationId, first.id);
      expect((await history.listHistory(userId: _userId)), hasLength(2));
      expect(
        (await history.listHistory(userId: _userId)).first.state,
        B04RecommendationState.available,
      );
      expect(
        (await history.listCurrent(userId: _userId)).map((row) => row.id),
        [second.id],
      );
    },
  );

  test(
    'duplicate issue and feedback commands are idempotent without rewriting history',
    () async {
      final lineage = await _seedLineage(db);
      final command = _command(
        consentEventId: lineage.consentId,
        eligibilityEvaluationId: lineage.eligibilityId,
        goalVersionId: lineage.goalId,
      );
      final first = (await history.issue(command)).single;
      final retry = (await history.issue(command)).single;
      expect(retry.id, first.id);
      expect(await db.select(db.recommendations).get(), hasLength(1));
      expect(await db.select(db.recommendationEvidence).get(), hasLength(4));

      final feedback = B04RecommendationFeedbackCommand(
        userId: _userId,
        recommendationId: 'recommendation-placeholder',
        action: B04RecommendationFeedbackAction.dismiss,
        reason: 'Not useful today',
        source: 'recommendation_card',
        localDate: '2026-08-06',
        timezoneId: _timezoneId,
        createdAtUtc: DateTime.utc(2026, 8, 6, 13),
        id: 'feedback-dismiss',
      );
      final feedbackCommand = B04RecommendationFeedbackCommand(
        userId: feedback.userId,
        recommendationId: first.id,
        action: feedback.action,
        reason: feedback.reason,
        source: feedback.source,
        localDate: feedback.localDate,
        timezoneId: feedback.timezoneId,
        createdAtUtc: feedback.createdAtUtc,
        id: feedback.id,
      );
      final recorded = await history.recordFeedback(feedbackCommand);
      final feedbackRetry = await history.recordFeedback(
        B04RecommendationFeedbackCommand(
          userId: _userId,
          recommendationId: first.id,
          action: B04RecommendationFeedbackAction.dismiss,
          reason: 'Not useful today',
          source: 'recommendation_card',
          localDate: '2026-08-06',
          timezoneId: _timezoneId,
          createdAtUtc: DateTime.utc(2026, 8, 6, 13),
          id: 'transport-retry-id',
        ),
      );
      expect(feedbackRetry.id, recorded.id);
      expect(await db.select(db.recommendationFeedback).get(), hasLength(1));
      expect(await history.listCurrent(userId: _userId), isEmpty);

      await history.recordFeedback(
        B04RecommendationFeedbackCommand(
          userId: _userId,
          recommendationId: first.id,
          action: B04RecommendationFeedbackAction.acknowledge,
          source: 'recommendation_card',
          localDate: '2026-08-06',
          timezoneId: _timezoneId,
          createdAtUtc: DateTime.utc(2026, 8, 6, 14),
          id: 'feedback-acknowledge',
        ),
      );
      expect((await history.listCurrent(userId: _userId)).single.id, first.id);
      expect(
        (await history.listHistory(userId: _userId)).single.feedback,
        hasLength(2),
      );
      for (final entry in [
        (B04RecommendationFeedbackAction.accept, 'feedback-accept', 15),
        (B04RecommendationFeedbackAction.override, 'feedback-override', 16),
        (B04RecommendationFeedbackAction.snooze, 'feedback-snooze', 17),
        (
          B04RecommendationFeedbackAction.notRelevant,
          'feedback-not-relevant',
          18,
        ),
      ]) {
        await history.recordFeedback(
          B04RecommendationFeedbackCommand(
            userId: _userId,
            recommendationId: first.id,
            action: entry.$1,
            source: 'recommendation_card',
            localDate: '2026-08-06',
            timezoneId: _timezoneId,
            createdAtUtc: DateTime.utc(2026, 8, 6, entry.$3),
            id: entry.$2,
          ),
        );
      }
      expect(
        (await history.listHistory(userId: _userId)).single.feedback,
        hasLength(6),
      );
      expect(await history.listCurrent(userId: _userId), isEmpty);
    },
  );

  test(
    'invalid evidence rolls back the recommendation and rejects cross-user lineage',
    () async {
      final lineage = await _seedLineage(db);
      final duplicateEvidence = _command(
        consentEventId: lineage.consentId,
        eligibilityEvaluationId: lineage.eligibilityId,
        goalVersionId: lineage.goalId,
        evidence: const [
          B04RecommendationEvidenceInput(
            evidenceKind: 'training',
            sourceType: 'b02_load_target',
            sourceId: 'training-source',
            sourceVersion: 'B02-v1',
            status: 'confirmed',
            value: 1,
            localDate: '2026-08-06',
            timezoneId: _timezoneId,
          ),
          B04RecommendationEvidenceInput(
            evidenceKind: 'training',
            sourceType: 'b02_load_target',
            sourceId: 'training-source',
            sourceVersion: 'B02-v1',
            status: 'confirmed',
            value: 1,
            localDate: '2026-08-06',
            timezoneId: _timezoneId,
          ),
        ],
      );
      await expectLater(
        history.issue(duplicateEvidence),
        throwsA(isA<Exception>()),
      );
      expect(await db.select(db.recommendations).get(), isEmpty);
      expect(await db.select(db.recommendationEvidence).get(), isEmpty);

      await db
          .into(db.coachingEligibilityEvaluations)
          .insert(
            CoachingEligibilityEvaluationsCompanion.insert(
              id: 'eligibility-other-user',
              userId: 'other-user',
              result: 'eligible',
              reasonCode: 'eligible',
              ageInputSource: 'verified_dob',
              evidenceTimestampUtc: DateTime.utc(2026, 8, 5),
              evaluationUtc: DateTime.utc(2026, 8, 5),
              evaluationLocalDate: '2026-08-05',
              timezoneId: _timezoneId,
              policyVersion: kB04EnabledPolicyVersion,
              minimumAgeRuleVersion: 'minimum-age-v1',
            ),
          );
      await expectLater(
        history.issue(
          _command(
            fingerprint: 'cross-user',
            consentEventId: lineage.consentId,
            eligibilityEvaluationId: 'eligibility-other-user',
            goalVersionId: lineage.goalId,
          ),
        ),
        throwsA(
          isA<B04RecommendationHistoryError>().having(
            (error) => error.code,
            'code',
            'cross_user_reference',
          ),
        ),
      );
    },
  );

  test(
    'exact adaptive result, retention and Backup-v9 round trip preserve lineage',
    () async {
      final lineage = await _seedLineage(db);
      final result = B04AdaptiveTargetResult(
        status: B04AdaptiveTargetStatus.available,
        reasonCode: 'proposal_available',
        policyVersion: kB04EnabledPolicyVersion,
        calculationVersion: 'B04-07-CALC-V1',
        algorithmVersion: 'B04-07-ALGORITHM-V1',
        direction: B04AdaptiveTargetDirection.decreaseCalories,
        adaptiveDeltaKcal: -100,
        currentTargetKcal: 2000,
        proposedTargetKcal: 1900,
        normalizedMaintenanceKcal: 2000,
        medianWeightGrams: null,
        slopeGramsPerDay: null,
        weeklyRatePercent: null,
        displayWeeklyRatePercent: null,
        evidenceIds: const ['target-source'],
        proposal: const AdaptiveGoalProposal(
          id: 'proposal-1',
          userId: _userId,
          goalType: NutritionGoalType.loss,
          goalRate: '0.5',
          calorieTargetKcal: 1900,
          policyVersion: kB04EnabledPolicyVersion,
          calculationVersion: 'B04-07-CALC-V1',
          algorithmVersion: 'B04-07-ALGORITHM-V1',
          effectiveFromLocalDate: '2026-08-06',
          timezoneId: _timezoneId,
          exactResultNumerator: '1900',
          exactResultDenominator: '1',
          normalizedMaintenanceKcal: 2000,
        ),
        trainingOverlay: B04TrainingOverlayResult.unavailable,
      );
      final evaluation = _evaluation(
        id: 'nutrition-target-1',
        fingerprint: 'target-evaluation',
        action: B04RecommendationAction.nutritionTarget,
        evidenceId: 'target-source',
        target: result,
      );
      final command = B04RecommendationHistoryCommand(
        evaluation: evaluation,
        scope: B04RecommendationHistoryScope.daily,
        consentEventId: lineage.consentId,
        eligibilityEvaluationId: lineage.eligibilityId,
        goalVersionId: lineage.goalId,
        evidenceByRecommendationId: const {
          'nutrition-target-1': [
            B04RecommendationEvidenceInput(
              evidenceKind: 'target',
              sourceType: 'b04_adaptive_target',
              sourceId: 'target-source',
              sourceVersion: 'B04-07-CALC-V1',
              status: 'available',
              value: 1900,
              exactResultNumerator: '1900',
              exactResultDenominator: '1',
              normalizedMaintenanceKcal: 2000,
              localDate: '2026-08-06',
              timezoneId: _timezoneId,
            ),
          ],
        },
      );
      final issued = (await history.issue(command)).single;
      expect(issued.exactResultNumerator, '1900');
      expect(issued.exactResultDenominator, '1');
      expect(issued.normalizedMaintenanceKcal, 2000);
      expect(issued.proposedDeltaKcal, -100);

      await history.recordFeedback(
        B04RecommendationFeedbackCommand(
          userId: _userId,
          recommendationId: issued.id,
          action: B04RecommendationFeedbackAction.dismiss,
          source: 'recommendation_card',
          localDate: '2026-08-06',
          timezoneId: _timezoneId,
          createdAtUtc: DateTime.utc(2026, 8, 6, 13),
          id: 'target-dismiss',
        ),
      );
      expect(await history.listCurrent(userId: _userId), isEmpty);
      final sourceBackup = await BackupV9Data.createFromDatabase(db);
      final targetDb = AppDatabase.memory();
      addTearDown(targetDb.close);
      final decoded = BackupV9Data.fromJson(
        jsonDecode(jsonEncode(sourceBackup.toJson())) as Map<String, dynamic>,
      );
      await decoded.restoreToDatabase(targetDb);
      final restored = B04RecommendationHistoryRepository(database: targetDb);
      expect(
        (await restored.listHistory(userId: _userId)).single.id,
        issued.id,
      );
      expect(
        (await restored.listHistory(userId: _userId)).single.feedback,
        hasLength(1),
      );
      expect(await restored.listCurrent(userId: _userId), isEmpty);
    },
  );
}

class _Lineage {
  final String consentId;
  final String eligibilityId;
  final String goalId;

  const _Lineage(this.consentId, this.eligibilityId, this.goalId);
}

Future<_Lineage> _seedLineage(AppDatabase db) async {
  final goals = NutritionGoalRepository(database: db);
  final goal = await goals.ensureCompatibilityImport(
    userId: _userId,
    legacyProfile: const NutritionGoalCommand(
      userId: _userId,
      goalType: NutritionGoalType.maintenance,
      source: NutritionGoalSource.compatibility,
      calorieTargetKcal: 2000,
      effectiveFromLocalDate: '2026-08-01',
      timezoneId: _timezoneId,
    ),
  );
  final consent = await CoachingPreferenceRepository(database: db)
      .recordConsent(
        CoachingConsentCommand(
          userId: _userId,
          category: CoachingConsentCategory.adaptiveCoaching,
          action: CoachingConsentAction.enable,
          consentPolicyVersion: kB04EnabledPolicyVersion,
          copyVersion: 'copy-v1',
          timestampUtc: DateTime.utc(2026, 8, 5),
          localDate: '2026-08-05',
          timezoneId: _timezoneId,
          actorSource: 'settings',
          eventId: 'consent-enable',
        ),
      );
  await db
      .into(db.coachingEligibilityEvaluations)
      .insert(
        CoachingEligibilityEvaluationsCompanion.insert(
          id: 'eligibility-1',
          userId: _userId,
          result: 'eligible',
          reasonCode: 'eligible',
          ageInputSource: 'verified_dob',
          evidenceTimestampUtc: DateTime.utc(2026, 8, 5),
          evaluationUtc: DateTime.utc(2026, 8, 5, 1),
          evaluationLocalDate: '2026-08-05',
          timezoneId: _timezoneId,
          policyVersion: kB04EnabledPolicyVersion,
          minimumAgeRuleVersion: 'minimum-age-v1',
        ),
      );
  return _Lineage(consent.id, 'eligibility-1', goal.id);
}

B04RecommendationHistoryCommand _command({
  String id = 'training-1',
  String fingerprint = 'evaluation-v1',
  String contextFingerprint = 'context-v1',
  DateTime? evaluatedAtUtc,
  String evidenceId = 'training-source',
  required String consentEventId,
  required String eligibilityEvaluationId,
  String? goalVersionId,
  String? supersedes,
  Iterable<B04RecommendationEvidenceInput>? evidence,
}) => B04RecommendationHistoryCommand(
  evaluation: _evaluation(
    id: id,
    fingerprint: fingerprint,
    contextFingerprint: contextFingerprint,
    evaluatedAtUtc: evaluatedAtUtc ?? _issuedAt,
    evidenceId: evidenceId,
  ),
  scope: B04RecommendationHistoryScope.daily,
  consentEventId: consentEventId,
  eligibilityEvaluationId: eligibilityEvaluationId,
  goalVersionId: goalVersionId,
  evidenceByRecommendationId: {
    id:
        evidence ??
        [
          B04RecommendationEvidenceInput(
            evidenceKind: 'training',
            sourceType: 'b02_load_target',
            sourceId: evidenceId,
            sourceVersion: 'B02-v1',
            status: 'confirmed',
            value: 1,
            localDate: '2026-08-06',
            timezoneId: _timezoneId,
          ),
        ],
  },
  supersedesByRecommendationId: {id: supersedes},
);

B04RecommendationEvaluation _evaluation({
  String id = 'training-1',
  String fingerprint = 'evaluation-v1',
  String contextFingerprint = 'context-v1',
  DateTime? evaluatedAtUtc,
  B04RecommendationAction action = B04RecommendationAction.training,
  String evidenceId = 'training-source',
  B04AdaptiveTargetResult? target,
}) => B04RecommendationEvaluation(
  contextId: 'context-id',
  userId: _userId,
  period: B04RecommendationPeriod.daily,
  startLocalDate: '2026-08-06',
  endLocalDate: '2026-08-06',
  timezoneId: _timezoneId,
  evaluatedAtUtc: evaluatedAtUtc ?? _issuedAt,
  eligibilityState: B04RecommendationEligibilityState.eligible,
  consentState: B04RecommendationConsentState.enabled,
  policyState: B04RecommendationPolicyState.enabled,
  policyVersion: kB04EnabledPolicyVersion,
  recommendations: [
    B04Recommendation(
      id: id,
      action: action,
      state: action == B04RecommendationAction.nutritionTarget
          ? B04RecommendationState.confirm
          : B04RecommendationState.available,
      priority: action == B04RecommendationAction.nutritionTarget
          ? B04RecommendationPriority.nutrition
          : B04RecommendationPriority.training,
      rationaleCode: 'evidence_backed',
      explanation: action == B04RecommendationAction.nutritionTarget
          ? 'Use the proposed nutrition target.'
          : 'Use the planned training session.',
      confidence: B04RecommendationConfidence.high,
      completeness: B04RecommendationCompleteness.complete,
      evidenceIds: [evidenceId],
      eligibilityState: B04RecommendationEligibilityState.eligible,
      consentState: B04RecommendationConsentState.enabled,
      policyState: B04RecommendationPolicyState.enabled,
      policyVersion: kB04EnabledPolicyVersion,
      ruleVersion: kB04RecommendationRuleVersion,
      algorithmVersion: kB04RecommendationAlgorithmVersion,
      copyVersion: kB04RecommendationCopyVersion,
      targetAcceptanceState: target == null
          ? B04RecommendationTargetAcceptanceState.notApplicable
          : B04RecommendationTargetAcceptanceState.proposalAvailable,
      canonicalAdaptiveTarget: target,
      canonicalTrainingRecommendation: null,
      safetyDisposition: null,
    ),
  ],
  lowRiskWarnings: const [],
  contextFingerprint: contextFingerprint,
  fingerprint: fingerprint,
);
