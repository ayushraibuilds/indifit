import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../core/services/local_schedule_date_service.dart';
import '../database/app_database.dart' as db;
import '../models/b04_recommendation_context_models.dart';
import '../models/b04_recommendation_history_models.dart';
import '../models/b04_recommendation_models.dart';

/// Durable command/read owner for B04 recommendation lineage and feedback.
///
/// A recommendation row is an immutable issued result. The repository only
/// appends rows and derives current visibility from the feedback stream; it
/// never stores a daily or weekly cache and never stores provider payloads.
class B04RecommendationHistoryRepository {
  final db.AppDatabase _db;
  final LocalScheduleDateService _dates;

  B04RecommendationHistoryRepository({
    required db.AppDatabase database,
    LocalScheduleDateService? dates,
  }) : _db = database,
       _dates = dates ?? LocalScheduleDateService();

  Future<List<B04HistoricalRecommendation>> issue(
    B04RecommendationHistoryCommand command,
  ) async {
    _validateEvaluation(command);
    final owner = _owner(command.evaluation.userId);
    return _db.transaction(() async {
      final consent = await _consent(command, owner);
      final eligibility = await _eligibility(command, owner);
      final goal = await _goal(command, owner);
      final readiness = await _readiness(command, owner);
      final issued = <String>[];

      final ids = command.evaluation.recommendations.map((item) => item.id);
      if (ids.length != ids.toSet().length) {
        throw const B04RecommendationHistoryError(
          'duplicate_recommendation_id',
          'An evaluation cannot issue the same recommendation twice.',
        );
      }
      final knownIds = ids.toSet();
      for (final key in command.evidenceByRecommendationId.keys) {
        if (!knownIds.contains(key)) {
          throw const B04RecommendationHistoryError(
            'unknown_recommendation_reference',
            'Evidence must belong to a recommendation in the evaluation.',
          );
        }
      }
      for (final key in command.supersedesByRecommendationId.keys) {
        if (!knownIds.contains(key)) {
          throw const B04RecommendationHistoryError(
            'unknown_recommendation_reference',
            'Supersession must belong to a recommendation in the evaluation.',
          );
        }
      }

      for (final recommendation in command.evaluation.recommendations) {
        _validateRecommendation(recommendation);
        final evidence = _lineageEvidence(
          command: command,
          recommendation: recommendation,
          consent: consent,
          eligibility: eligibility,
          goal: goal,
          readiness: readiness,
        );
        final evidenceFingerprint = _sha256(
          evidence.map((item) => item.toRedactedMap()).toList(),
        );
        final supersedes = command.supersedesFor(recommendation.id);
        final replayHash = _sha256({
          'evaluation_fingerprint': command.evaluation.fingerprint,
          'recommendation_id': recommendation.id,
          'scope': command.scope.stableId,
          'user_id': owner,
          'consent_event_id': command.consentEventId,
          'eligibility_evaluation_id': command.eligibilityEvaluationId,
          'goal_version_id': command.goalVersionId,
          'readiness_snapshot_id': command.readinessSnapshotId,
          'evidence_fingerprint': evidenceFingerprint,
          'supersedes_recommendation_id': supersedes,
        });
        final existing =
            await (_db.select(_db.recommendations)..where(
                  (row) =>
                      row.userId.equals(owner) &
                      row.replayHash.equals(replayHash),
                ))
                .getSingleOrNull();
        if (existing != null) {
          _assertReplay(
            existing,
            recommendation,
            command,
            evidenceFingerprint,
            supersedes,
          );
          issued.add(existing.id);
          continue;
        }

        await _validateSupersession(
          owner: owner,
          recommendation: recommendation,
          supersedes: supersedes,
          evaluatedAtUtc: command.evaluation.evaluatedAtUtc,
        );
        final target = recommendation.canonicalAdaptiveTarget;
        final proposal = target?.proposal;
        final recommendationId =
            'recommendation-${replayHash.substring(0, 32)}';
        await _db
            .into(_db.recommendations)
            .insert(
              db.RecommendationsCompanion.insert(
                id: recommendationId,
                userId: owner,
                scope: command.scope.stableId,
                localPeriodStart: command.evaluation.startLocalDate,
                localPeriodEnd: command.evaluation.endLocalDate,
                timezoneId: command.evaluation.timezoneId,
                status: recommendation.state.stableId,
                priority: recommendation.priority.rank,
                confidence: Value(_confidence(recommendation.confidence)),
                completeness: Value(recommendation.completeness.stableId),
                action: recommendation.action.stableId,
                explanation: recommendation.explanation,
                missingInputs: Value(
                  _encodeList(recommendation.missingEvidence),
                ),
                uncertainty: Value(
                  _encodeList(recommendation.uncertaintyCodes),
                ),
                alternatives: Value(_encodeList(recommendation.alternativeIds)),
                ruleVersion: recommendation.ruleVersion,
                calculationVersion: Value(
                  target?.calculationVersion ?? proposal?.calculationVersion,
                ),
                algorithmVersion: Value(
                  target?.algorithmVersion ??
                      proposal?.algorithmVersion ??
                      recommendation.algorithmVersion,
                ),
                modelVersion: const Value.absent(),
                providerVersion: const Value.absent(),
                policyVersion: Value(recommendation.policyVersion),
                goalVersionId: Value(command.goalVersionId),
                readinessSnapshotId: Value(command.readinessSnapshotId),
                contextFingerprint: command.evaluation.contextFingerprint,
                evidenceFingerprint: Value(evidenceFingerprint),
                exactResultNumerator: Value(proposal?.exactResultNumerator),
                exactResultDenominator: Value(proposal?.exactResultDenominator),
                normalizedMaintenanceKcal: Value(
                  target?.normalizedMaintenanceKcal ??
                      proposal?.normalizedMaintenanceKcal,
                ),
                proposedDeltaKcal: Value(target?.adaptiveDeltaKcal),
                createdAtUtc: Value(command.evaluation.evaluatedAtUtc),
                effectiveAtUtc: Value(command.evaluation.evaluatedAtUtc),
                supersedesRecommendationId: Value(supersedes),
                replayHash: Value(replayHash),
              ),
            );
        issued.add(recommendationId);
        for (final item in evidence) {
          final evidenceId =
              'recommendation-evidence-${_sha256({'recommendation_id': recommendationId, ...item.toRedactedMap()}).substring(0, 32)}';
          await _db
              .into(_db.recommendationEvidence)
              .insert(
                db.RecommendationEvidenceCompanion.insert(
                  id: evidenceId,
                  recommendationId: recommendationId,
                  userId: owner,
                  evidenceKind: item.evidenceKind,
                  sourceType: item.sourceType,
                  sourceId: Value(item.sourceId),
                  sourceVersion: Value(item.sourceVersion),
                  status: item.status,
                  value: Value(item.value),
                  lower: Value(item.lower),
                  upper: Value(item.upper),
                  unit: Value(item.unit),
                  exactResultNumerator: Value(item.exactResultNumerator),
                  exactResultDenominator: Value(item.exactResultDenominator),
                  normalizedMaintenanceKcal: Value(
                    item.normalizedMaintenanceKcal,
                  ),
                  localDate: Value(item.localDate),
                  timezoneId: Value(item.timezoneId),
                  createdAtUtc: Value(command.evaluation.evaluatedAtUtc),
                ),
              );
        }
      }
      return _readRows(issued, owner);
    });
  }

  Future<List<B04HistoricalRecommendation>> issueEvaluation(
    B04RecommendationHistoryCommand command,
  ) => issue(command);

  Future<List<B04HistoricalRecommendation>> persistEvaluation(
    B04RecommendationHistoryCommand command,
  ) => issue(command);

  Future<B04RecommendationFeedbackRecord> recordFeedback(
    B04RecommendationFeedbackCommand command,
  ) async {
    _validateFeedback(command);
    final owner = _owner(command.userId);
    final recommendationId = command.recommendationId.trim();
    return _db.transaction(() async {
      final recommendation = await (_db.select(
        _db.recommendations,
      )..where((row) => row.id.equals(recommendationId))).getSingleOrNull();
      if (recommendation == null) {
        throw const B04RecommendationHistoryError(
          'dangling_recommendation_reference',
          'Feedback must reference an existing recommendation.',
        );
      }
      if (recommendation.userId != owner) {
        throw const B04RecommendationHistoryError(
          'cross_user_reference',
          'Feedback cannot reference another user’s recommendation.',
        );
      }
      final relatedId = command.relatedFeedbackId?.trim();
      if (relatedId != null && relatedId.isNotEmpty) {
        final related = await (_db.select(
          _db.recommendationFeedback,
        )..where((row) => row.id.equals(relatedId))).getSingleOrNull();
        if (related == null) {
          throw const B04RecommendationHistoryError(
            'dangling_feedback_reference',
            'Related feedback must reference an existing event.',
          );
        }
        if (related.userId != owner ||
            related.recommendationId != recommendationId) {
          throw const B04RecommendationHistoryError(
            'cross_user_reference',
            'Related feedback must belong to the same user and recommendation.',
          );
        }
        if (!related.createdAtUtc.isBefore(command.createdAtUtc.toUtc())) {
          throw const B04RecommendationHistoryError(
            'invalid_feedback_order',
            'Related feedback must precede the new feedback event.',
          );
        }
      }

      final id = command.id?.trim();
      if (id != null && id.isNotEmpty) {
        final byId = await (_db.select(
          _db.recommendationFeedback,
        )..where((row) => row.id.equals(id))).getSingleOrNull();
        if (byId != null) {
          _assertFeedback(byId, command, owner);
          return _feedbackFromRow(byId);
        }
      }
      final sameAction =
          await (_db.select(_db.recommendationFeedback)..where(
                (row) =>
                    row.userId.equals(owner) &
                    row.recommendationId.equals(recommendationId) &
                    row.action.equals(command.action.stableId),
              ))
              .get();
      for (final row in sameAction) {
        if (row.relatedFeedbackId == relatedId) {
          _assertFeedback(row, command, owner);
          return _feedbackFromRow(row);
        }
      }

      final feedbackId = id == null || id.isEmpty
          ? 'recommendation-feedback-${_sha256({'user_id': owner, 'recommendation_id': recommendationId, 'action': command.action.stableId, 'reason': command.reason?.trim(), 'source': command.source.trim(), 'local_date': command.localDate, 'timezone_id': command.timezoneId, 'created_at_utc': command.createdAtUtc.toUtc().toIso8601String(), 'related_feedback_id': relatedId}).substring(0, 32)}'
          : id;
      await _db
          .into(_db.recommendationFeedback)
          .insert(
            db.RecommendationFeedbackCompanion.insert(
              id: feedbackId,
              userId: owner,
              recommendationId: recommendationId,
              action: command.action.stableId,
              reason: Value(_trimmedOrNull(command.reason)),
              source: command.source.trim(),
              localDate: command.localDate,
              timezoneId: command.timezoneId,
              createdAtUtc: Value(command.createdAtUtc.toUtc()),
              relatedFeedbackId: Value(relatedId),
            ),
          );
      final row = await (_db.select(
        _db.recommendationFeedback,
      )..where((item) => item.id.equals(feedbackId))).getSingle();
      return _feedbackFromRow(row);
    });
  }

  Future<List<B04HistoricalRecommendation>> listHistory({
    required String userId,
    B04RecommendationHistoryScope? scope,
  }) async {
    final owner = _owner(userId);
    final rows =
        await (_db.select(_db.recommendations)
              ..where(
                (row) =>
                    row.userId.equals(owner) &
                    (scope == null
                        ? const Constant(true)
                        : row.scope.equals(scope.stableId)),
              )
              ..orderBy([
                (row) => OrderingTerm(
                  expression: row.createdAtUtc,
                  mode: OrderingMode.asc,
                ),
                (row) => OrderingTerm(expression: row.id),
              ]))
            .get();
    return _fromRows(rows);
  }

  Future<List<B04HistoricalRecommendation>> listCurrent({
    required String userId,
    B04RecommendationHistoryScope? scope,
  }) async {
    final history = await listHistory(userId: userId, scope: scope);
    final superseded = history
        .map((row) => row.supersedesRecommendationId)
        .whereType<String>()
        .toSet();
    return List.unmodifiable(
      history.where(
        (row) =>
            row.state != B04RecommendationState.superseded &&
            row.state != B04RecommendationState.dismissed &&
            !superseded.contains(row.id) &&
            !row.isDismissed,
      ),
    );
  }

  Future<List<B04HistoricalRecommendation>> history({
    required String userId,
    B04RecommendationHistoryScope? scope,
  }) => listHistory(userId: userId, scope: scope);

  Future<List<B04HistoricalRecommendation>> current({
    required String userId,
    B04RecommendationHistoryScope? scope,
  }) => listCurrent(userId: userId, scope: scope);

  Future<List<B04HistoricalRecommendation>> _readRows(
    List<String> ids,
    String owner,
  ) async {
    if (ids.isEmpty) return const [];
    final rows = await (_db.select(
      _db.recommendations,
    )..where((row) => row.userId.equals(owner) & row.id.isIn(ids))).get();
    final byId = {for (final row in rows) row.id: row};
    return _fromRows([
      for (final id in ids)
        byId[id] ??
            (throw const B04RecommendationHistoryError(
              'missing_issued_row',
              'An issued recommendation disappeared before it could be read.',
            )),
    ]);
  }

  Future<List<B04HistoricalRecommendation>> _fromRows(
    List<db.Recommendation> rows,
  ) async {
    final result = <B04HistoricalRecommendation>[];
    for (final row in rows) {
      final evidence =
          await (_db.select(_db.recommendationEvidence)
                ..where((item) => item.recommendationId.equals(row.id))
                ..orderBy([
                  (item) => OrderingTerm(expression: item.createdAtUtc),
                  (item) => OrderingTerm(expression: item.id),
                ]))
              .get();
      final feedback =
          await (_db.select(_db.recommendationFeedback)
                ..where((item) => item.recommendationId.equals(row.id))
                ..orderBy([
                  (item) => OrderingTerm(expression: item.createdAtUtc),
                  (item) => OrderingTerm(expression: item.id),
                ]))
              .get();
      result.add(
        B04HistoricalRecommendation(
          id: row.id,
          userId: row.userId,
          scope: B04RecommendationHistoryScopeId.parse(row.scope),
          localPeriodStart: row.localPeriodStart,
          localPeriodEnd: row.localPeriodEnd,
          timezoneId: row.timezoneId,
          state: _state(row.status),
          priority: _priority(row.priority),
          confidence: row.confidence,
          completeness: row.completeness == null
              ? null
              : _completeness(row.completeness!),
          action: row.action,
          explanation: row.explanation,
          missingInputs: _decodeList(row.missingInputs),
          uncertainty: _decodeList(row.uncertainty),
          alternatives: _decodeList(row.alternatives),
          ruleVersion: row.ruleVersion,
          calculationVersion: row.calculationVersion,
          algorithmVersion: row.algorithmVersion,
          modelVersion: row.modelVersion,
          providerVersion: row.providerVersion,
          policyVersion: row.policyVersion,
          goalVersionId: row.goalVersionId,
          readinessSnapshotId: row.readinessSnapshotId,
          contextFingerprint: row.contextFingerprint,
          evidenceFingerprint: row.evidenceFingerprint,
          exactResultNumerator: row.exactResultNumerator,
          exactResultDenominator: row.exactResultDenominator,
          normalizedMaintenanceKcal: row.normalizedMaintenanceKcal,
          proposedDeltaKcal: row.proposedDeltaKcal,
          createdAtUtc: row.createdAtUtc.toUtc(),
          effectiveAtUtc: row.effectiveAtUtc?.toUtc(),
          supersededAtUtc: row.supersededAtUtc?.toUtc(),
          supersedesRecommendationId: row.supersedesRecommendationId,
          replayHash:
              row.replayHash ??
              (throw const B04RecommendationHistoryError(
                'missing_replay_hash',
                'A recommendation history row must have a replay hash.',
              )),
          evidence: List.unmodifiable([
            for (final item in evidence) _evidenceFromRow(item),
          ]),
          feedback: List.unmodifiable([
            for (final item in feedback) _feedbackFromRow(item),
          ]),
        ),
      );
    }
    return List.unmodifiable(result);
  }

  List<B04RecommendationEvidenceRecord> _lineageEvidence({
    required B04RecommendationHistoryCommand command,
    required B04Recommendation recommendation,
    required db.CoachingConsentEvent consent,
    required db.CoachingEligibilityEvaluation eligibility,
    required db.NutritionGoalVersion? goal,
    required db.ReadinessSnapshot? readiness,
  }) {
    final values = <B04RecommendationEvidenceRecord>[
      B04RecommendationEvidenceRecord(
        id: '',
        recommendationId: recommendation.id,
        userId: command.evaluation.userId,
        evidenceKind: 'consent',
        sourceType: 'coaching_consent_event',
        sourceId: consent.id,
        sourceVersion: consent.consentPolicyVersion,
        status: consent.action,
        value: null,
        lower: null,
        upper: null,
        unit: null,
        exactResultNumerator: null,
        exactResultDenominator: null,
        normalizedMaintenanceKcal: null,
        localDate: consent.localDate,
        timezoneId: consent.timezoneId,
        createdAtUtc: command.evaluation.evaluatedAtUtc,
      ),
      B04RecommendationEvidenceRecord(
        id: '',
        recommendationId: recommendation.id,
        userId: command.evaluation.userId,
        evidenceKind: 'eligibility',
        sourceType: 'coaching_eligibility_evaluation',
        sourceId: eligibility.id,
        sourceVersion: eligibility.minimumAgeRuleVersion,
        status: eligibility.result,
        value: null,
        lower: null,
        upper: null,
        unit: null,
        exactResultNumerator: null,
        exactResultDenominator: null,
        normalizedMaintenanceKcal: null,
        localDate: eligibility.evaluationLocalDate,
        timezoneId: eligibility.timezoneId,
        createdAtUtc: command.evaluation.evaluatedAtUtc,
      ),
    ];
    if (goal != null) {
      values.add(
        B04RecommendationEvidenceRecord(
          id: '',
          recommendationId: recommendation.id,
          userId: command.evaluation.userId,
          evidenceKind: 'goal',
          sourceType: 'nutrition_goal_version',
          sourceId: goal.id,
          sourceVersion: goal.calculationVersion ?? goal.policyVersion,
          status: goal.targetSource,
          value: goal.calorieTargetKcal?.toDouble(),
          lower: null,
          upper: null,
          unit: 'kcal',
          exactResultNumerator: goal.exactResultNumerator,
          exactResultDenominator: goal.exactResultDenominator,
          normalizedMaintenanceKcal: goal.normalizedMaintenanceKcal,
          localDate: goal.effectiveFromLocalDate,
          timezoneId: goal.timezoneId,
          createdAtUtc: command.evaluation.evaluatedAtUtc,
        ),
      );
    }
    if (readiness != null) {
      values.add(
        B04RecommendationEvidenceRecord(
          id: '',
          recommendationId: recommendation.id,
          userId: command.evaluation.userId,
          evidenceKind: 'readiness',
          sourceType: 'readiness_snapshot',
          sourceId: readiness.id,
          sourceVersion: readiness.calculationVersion,
          status: readiness.status,
          value: readiness.confidence,
          lower: null,
          upper: null,
          unit: 'confidence',
          exactResultNumerator: null,
          exactResultDenominator: null,
          normalizedMaintenanceKcal: null,
          localDate: readiness.localDate,
          timezoneId: readiness.timezoneId,
          createdAtUtc: command.evaluation.evaluatedAtUtc,
        ),
      );
    }
    final inputs = command.evidenceFor(recommendation.id);
    final requiredIds = recommendation.evidenceIds.toSet();
    final suppliedIds = inputs.map((item) => item.sourceId).whereType<String>();
    if (recommendation.state != B04RecommendationState.unavailable &&
        inputs.isEmpty) {
      throw const B04RecommendationHistoryError(
        'missing_evidence',
        'An issued recommendation must persist typed evidence rows.',
      );
    }
    if (!requiredIds.every(suppliedIds.contains)) {
      throw const B04RecommendationHistoryError(
        'missing_evidence',
        'Every engine evidence identifier must be frozen in a typed evidence row.',
      );
    }
    for (final input in inputs) {
      _validateEvidence(input, command.evaluation.timezoneId);
      values.add(
        B04RecommendationEvidenceRecord(
          id: '',
          recommendationId: recommendation.id,
          userId: command.evaluation.userId,
          evidenceKind: input.evidenceKind.trim(),
          sourceType: input.sourceType.trim(),
          sourceId: _trimmedOrNull(input.sourceId),
          sourceVersion: _trimmedOrNull(input.sourceVersion),
          status: input.status.trim(),
          value: input.value,
          lower: input.lower,
          upper: input.upper,
          unit: _trimmedOrNull(input.unit),
          exactResultNumerator: _trimmedOrNull(input.exactResultNumerator),
          exactResultDenominator: _trimmedOrNull(input.exactResultDenominator),
          normalizedMaintenanceKcal: input.normalizedMaintenanceKcal,
          localDate: input.localDate == null
              ? null
              : _dates.normalizeLocalDate(input.localDate!),
          timezoneId: input.timezoneId?.trim(),
          createdAtUtc: command.evaluation.evaluatedAtUtc,
        ),
      );
    }
    return values;
  }

  Future<db.CoachingConsentEvent> _consent(
    B04RecommendationHistoryCommand command,
    String owner,
  ) async {
    final row =
        await (_db.select(_db.coachingConsentEvents)
              ..where((item) => item.id.equals(command.consentEventId)))
            .getSingleOrNull();
    if (row == null) {
      throw const B04RecommendationHistoryError(
        'dangling_consent_reference',
        'Recommendation history requires an existing consent event.',
      );
    }
    if (row.userId != owner || row.consentCategory != 'adaptive_coaching') {
      throw const B04RecommendationHistoryError(
        'cross_user_reference',
        'Recommendation history consent must belong to the same adaptive-coaching user.',
      );
    }
    if (row.timestampUtc.isAfter(command.evaluation.evaluatedAtUtc.toUtc())) {
      throw const B04RecommendationHistoryError(
        'invalid_lineage_order',
        'Consent must precede the issued recommendation.',
      );
    }
    if (command.evaluation.consentState ==
            B04RecommendationConsentState.enabled &&
        row.action != 'enable') {
      throw const B04RecommendationHistoryError(
        'invalid_consent_state',
        'An enabled recommendation must reference an enable consent event.',
      );
    }
    if (command.evaluation.consentState ==
            B04RecommendationConsentState.disabled &&
        row.action != 'disable' &&
        row.action != 'withdraw') {
      throw const B04RecommendationHistoryError(
        'invalid_consent_state',
        'A disabled recommendation must reference a disable or withdraw consent event.',
      );
    }
    final current =
        await (_db.select(_db.coachingConsentEvents)..where(
              (item) =>
                  item.userId.equals(owner) &
                  item.consentCategory.equals('adaptive_coaching') &
                  item.timestampUtc.isSmallerOrEqualValue(
                    command.evaluation.evaluatedAtUtc.toUtc(),
                  ),
            ))
            .get();
    current.sort(_consentOrder);
    if (current.isEmpty || current.first.id != row.id) {
      throw const B04RecommendationHistoryError(
        'stale_consent_reference',
        'Recommendation history must reference the consent state effective at issue time.',
      );
    }
    return row;
  }

  Future<db.CoachingEligibilityEvaluation> _eligibility(
    B04RecommendationHistoryCommand command,
    String owner,
  ) async {
    final row =
        await (_db.select(
              _db.coachingEligibilityEvaluations,
            )..where((item) => item.id.equals(command.eligibilityEvaluationId)))
            .getSingleOrNull();
    if (row == null) {
      throw const B04RecommendationHistoryError(
        'dangling_eligibility_reference',
        'Recommendation history requires an existing eligibility evaluation.',
      );
    }
    if (row.userId != owner) {
      throw const B04RecommendationHistoryError(
        'cross_user_reference',
        'Recommendation history eligibility must belong to the same user.',
      );
    }
    if (row.evaluationUtc.isAfter(command.evaluation.evaluatedAtUtc.toUtc()) ||
        row.result != command.evaluation.eligibilityState.stableId) {
      throw const B04RecommendationHistoryError(
        'invalid_lineage_order',
        'The eligibility authority must describe the issued evaluation.',
      );
    }
    final current =
        await (_db.select(_db.coachingEligibilityEvaluations)..where(
              (item) =>
                  item.userId.equals(owner) &
                  item.evaluationUtc.isSmallerOrEqualValue(
                    command.evaluation.evaluatedAtUtc.toUtc(),
                  ),
            ))
            .get();
    current.sort(_eligibilityOrder);
    if (current.isEmpty || current.first.id != row.id) {
      throw const B04RecommendationHistoryError(
        'stale_eligibility_reference',
        'Recommendation history must reference the eligibility state effective at issue time.',
      );
    }
    return row;
  }

  Future<db.NutritionGoalVersion?> _goal(
    B04RecommendationHistoryCommand command,
    String owner,
  ) async {
    final id = command.goalVersionId;
    if (id == null || id.isEmpty) return null;
    final row = await (_db.select(
      _db.nutritionGoalVersions,
    )..where((item) => item.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const B04RecommendationHistoryError(
        'dangling_goal_reference',
        'Recommendation history goal lineage must resolve.',
      );
    }
    if (row.userId != owner) {
      throw const B04RecommendationHistoryError(
        'cross_user_reference',
        'Recommendation history goal lineage must belong to the same user.',
      );
    }
    if (row.effectiveFromLocalDate.compareTo(
              command.evaluation.startLocalDate,
            ) >
            0 ||
        (row.effectiveToLocalDate != null &&
            row.effectiveToLocalDate!.compareTo(
                  command.evaluation.endLocalDate,
                ) <
                0)) {
      throw const B04RecommendationHistoryError(
        'goal_not_effective',
        'The referenced goal version must cover the recommendation period.',
      );
    }
    return row;
  }

  Future<db.ReadinessSnapshot?> _readiness(
    B04RecommendationHistoryCommand command,
    String owner,
  ) async {
    final id = command.readinessSnapshotId;
    if (id == null || id.isEmpty) return null;
    final row = await (_db.select(
      _db.readinessSnapshots,
    )..where((item) => item.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const B04RecommendationHistoryError(
        'dangling_readiness_reference',
        'Recommendation history readiness lineage must resolve.',
      );
    }
    if (row.userId != owner) {
      throw const B04RecommendationHistoryError(
        'cross_user_reference',
        'Recommendation history readiness lineage must belong to the same user.',
      );
    }
    try {
      _dates.validateTimezone(row.timezoneId);
      final localDate = _dates.normalizeLocalDate(row.localDate);
      final evaluation = command.evaluation;
      if (row.timezoneId != evaluation.timezoneId ||
          _dates.compare(localDate, evaluation.startLocalDate) < 0 ||
          _dates.compare(localDate, evaluation.endLocalDate) > 0) {
        throw const B04RecommendationHistoryError(
          'invalid_readiness_reference',
          'Readiness lineage must belong to the issued recommendation period and timezone.',
        );
      }
    } on B04RecommendationHistoryError {
      rethrow;
    } catch (_) {
      throw const B04RecommendationHistoryError(
        'invalid_readiness_reference',
        'Readiness lineage must carry a valid local date and IANA timezone.',
      );
    }
    return row;
  }

  Future<void> _validateSupersession({
    required String owner,
    required B04Recommendation recommendation,
    required String? supersedes,
    required DateTime evaluatedAtUtc,
  }) async {
    if (supersedes == null || supersedes.isEmpty) return;
    if (supersedes == recommendation.id) {
      throw const B04RecommendationHistoryError(
        'invalid_supersession',
        'A recommendation cannot supersede itself.',
      );
    }
    final row = await (_db.select(
      _db.recommendations,
    )..where((item) => item.id.equals(supersedes))).getSingleOrNull();
    if (row == null) {
      throw const B04RecommendationHistoryError(
        'dangling_supersession_reference',
        'A supersession must reference an existing recommendation.',
      );
    }
    if (row.userId != owner || row.action != recommendation.action.stableId) {
      throw const B04RecommendationHistoryError(
        'cross_user_reference',
        'A supersession must reference the same user and action.',
      );
    }
    if (!row.createdAtUtc.isBefore(evaluatedAtUtc.toUtc())) {
      throw const B04RecommendationHistoryError(
        'invalid_supersession_order',
        'A superseded recommendation must be historical.',
      );
    }
  }

  void _validateEvaluation(B04RecommendationHistoryCommand command) {
    final evaluation = command.evaluation;
    if (!evaluation.evaluatedAtUtc.isUtc) {
      throw const B04RecommendationHistoryError(
        'invalid_timestamp',
        'Recommendation issue timestamps must be UTC.',
      );
    }
    try {
      _dates.validateTimezone(evaluation.timezoneId);
      _dates.normalizeLocalDate(evaluation.startLocalDate);
      _dates.normalizeLocalDate(evaluation.endLocalDate);
    } catch (_) {
      throw const B04RecommendationHistoryError(
        'invalid_period',
        'Recommendation history requires valid local dates and IANA timezone.',
      );
    }
    if (_dates.compare(evaluation.startLocalDate, evaluation.endLocalDate) >
        0) {
      throw const B04RecommendationHistoryError(
        'invalid_period',
        'Recommendation history periods must be ordered.',
      );
    }
    if (evaluation.period == B04RecommendationPeriod.daily &&
        evaluation.startLocalDate != evaluation.endLocalDate) {
      throw const B04RecommendationHistoryError(
        'invalid_period',
        'A daily recommendation must cover one local civil date.',
      );
    }
    if (evaluation.period == B04RecommendationPeriod.weekly &&
        _dates.addCalendarDays(
              evaluation.startLocalDate,
              evaluation.timezoneId,
              6,
            ) !=
            evaluation.endLocalDate) {
      throw const B04RecommendationHistoryError(
        'invalid_period',
        'A weekly recommendation must cover seven local civil dates.',
      );
    }
    if (evaluation.userId.trim().isEmpty ||
        evaluation.contextFingerprint.trim().isEmpty ||
        evaluation.fingerprint.trim().isEmpty) {
      throw const B04RecommendationHistoryError(
        'invalid_evaluation',
        'Recommendation history requires a user and replayable evaluation fingerprints.',
      );
    }
  }

  void _validateEvidence(
    B04RecommendationEvidenceInput input,
    String evaluationTimezone,
  ) {
    final kind = input.evidenceKind.trim();
    final source = input.sourceType.trim();
    final status = input.status.trim();
    if (kind.isEmpty || source.isEmpty || status.isEmpty) {
      throw const B04RecommendationHistoryError(
        'invalid_evidence',
        'Typed recommendation evidence requires kind, source and status.',
      );
    }
    final sourceId = input.sourceId?.trim();
    if (sourceId == null || sourceId.isEmpty) {
      throw const B04RecommendationHistoryError(
        'missing_source_id',
        'Typed recommendation evidence requires a portable source ID.',
      );
    }
    _validateBounded(kind, 'evidence kind', 128);
    _validateBounded(source, 'evidence source', 128);
    _validateBounded(status, 'evidence status', 128);
    _validateBounded(sourceId, 'evidence source ID', 128);
    _validateBounded(input.sourceVersion, 'evidence source version', 128);
    _validateBounded(input.unit, 'evidence unit', 32);
    _validateBounded(input.exactResultNumerator, 'exact numerator', 128);
    _validateBounded(input.exactResultDenominator, 'exact denominator', 128);
    final forbidden = RegExp(
      r'(prompt|image|payload|token|secret|password|raw[_ ]?provider|medical[_ ]?restriction)',
      caseSensitive: false,
    );
    if (forbidden.hasMatch(kind) || forbidden.hasMatch(source)) {
      throw const B04RecommendationHistoryError(
        'forbidden_payload',
        'Raw prompts, images, provider payloads and sensitive payloads are not durable evidence.',
      );
    }
    if (RegExp(r'[\{\}\[\]"\r\n]').hasMatch(sourceId)) {
      throw const B04RecommendationHistoryError(
        'forbidden_payload',
        'Evidence source IDs must be identifiers, not structured payloads.',
      );
    }
    for (final value in [input.value, input.lower, input.upper]) {
      if (value != null && !value.isFinite) {
        throw const B04RecommendationHistoryError(
          'invalid_evidence',
          'Evidence numeric values must be finite.',
        );
      }
    }
    if (input.lower != null &&
        input.upper != null &&
        input.lower! > input.upper!) {
      throw const B04RecommendationHistoryError(
        'invalid_evidence',
        'Evidence ranges must be ordered.',
      );
    }
    final numerator = input.exactResultNumerator?.trim();
    final denominator = input.exactResultDenominator?.trim();
    if ((numerator == null) != (denominator == null) || denominator == '0') {
      throw const B04RecommendationHistoryError(
        'invalid_exact_result',
        'Exact evidence results require a non-zero numerator and denominator.',
      );
    }
    if (numerator != null) {
      try {
        BigInt.parse(numerator);
        BigInt.parse(denominator!);
      } on FormatException {
        throw const B04RecommendationHistoryError(
          'invalid_exact_result',
          'Exact evidence results must use integer strings.',
        );
      }
    }
    if (input.normalizedMaintenanceKcal != null &&
        input.normalizedMaintenanceKcal! <= 0) {
      throw const B04RecommendationHistoryError(
        'invalid_evidence',
        'Normalized maintenance must be positive.',
      );
    }
    final localDate = input.localDate;
    final timezoneId = input.timezoneId;
    if ((localDate == null) != (timezoneId == null)) {
      throw const B04RecommendationHistoryError(
        'invalid_evidence',
        'Evidence local date and timezone must be supplied together.',
      );
    }
    if (localDate != null) {
      try {
        _dates.normalizeLocalDate(localDate);
        _dates.validateTimezone(timezoneId!);
      } catch (_) {
        throw const B04RecommendationHistoryError(
          'invalid_evidence',
          'Evidence must carry a valid local date and IANA timezone.',
        );
      }
    } else if (evaluationTimezone.trim().isEmpty) {
      throw const B04RecommendationHistoryError(
        'invalid_evidence',
        'Evidence requires a valid historical timezone.',
      );
    }
  }

  void _validateFeedback(B04RecommendationFeedbackCommand command) {
    if (command.userId.trim().isEmpty ||
        command.recommendationId.trim().isEmpty) {
      throw const B04RecommendationHistoryError(
        'invalid_feedback',
        'Feedback requires an owner and recommendation identity.',
      );
    }
    if (!command.createdAtUtc.isUtc) {
      throw const B04RecommendationHistoryError(
        'invalid_timestamp',
        'Feedback timestamps must be UTC.',
      );
    }
    if (command.source.trim().isEmpty || command.localDate.trim().isEmpty) {
      throw const B04RecommendationHistoryError(
        'invalid_feedback',
        'Feedback requires source and local date.',
      );
    }
    _validateBounded(command.source, 'feedback source', 128);
    _validateBounded(command.reason, 'feedback reason', 512);
    _validateBounded(command.id, 'feedback ID', 128);
    _validateBounded(command.relatedFeedbackId, 'related feedback ID', 128);
    try {
      _dates.normalizeLocalDate(command.localDate);
      _dates.validateTimezone(command.timezoneId);
      if (_dates.localDateFor(command.createdAtUtc, command.timezoneId) !=
          command.localDate) {
        throw const B04RecommendationHistoryError(
          'feedback_local_date_mismatch',
          'Feedback local date must be derived from its UTC timestamp and IANA timezone.',
        );
      }
    } on B04RecommendationHistoryError {
      rethrow;
    } catch (_) {
      throw const B04RecommendationHistoryError(
        'invalid_feedback',
        'Feedback requires a valid local date and IANA timezone.',
      );
    }
  }

  void _assertReplay(
    db.Recommendation row,
    B04Recommendation recommendation,
    B04RecommendationHistoryCommand command,
    String evidenceFingerprint,
    String? supersedes,
  ) {
    final target = recommendation.canonicalAdaptiveTarget;
    final proposal = target?.proposal;
    if (row.userId != command.evaluation.userId ||
        row.action != recommendation.action.stableId ||
        row.status != recommendation.state.stableId ||
        row.priority != recommendation.priority.rank ||
        row.confidence != _confidence(recommendation.confidence) ||
        row.completeness != recommendation.completeness.stableId ||
        row.explanation != recommendation.explanation ||
        row.missingInputs != _encodeList(recommendation.missingEvidence) ||
        row.uncertainty != _encodeList(recommendation.uncertaintyCodes) ||
        row.alternatives != _encodeList(recommendation.alternativeIds) ||
        row.ruleVersion != recommendation.ruleVersion ||
        row.calculationVersion !=
            (target?.calculationVersion ?? proposal?.calculationVersion) ||
        row.algorithmVersion !=
            (target?.algorithmVersion ??
                proposal?.algorithmVersion ??
                recommendation.algorithmVersion) ||
        row.policyVersion != recommendation.policyVersion ||
        row.goalVersionId != command.goalVersionId ||
        row.readinessSnapshotId != command.readinessSnapshotId ||
        row.contextFingerprint != command.evaluation.contextFingerprint ||
        row.evidenceFingerprint != evidenceFingerprint ||
        row.exactResultNumerator != proposal?.exactResultNumerator ||
        row.exactResultDenominator != proposal?.exactResultDenominator ||
        row.normalizedMaintenanceKcal !=
            (target?.normalizedMaintenanceKcal ??
                proposal?.normalizedMaintenanceKcal) ||
        row.proposedDeltaKcal != target?.adaptiveDeltaKcal ||
        row.supersedesRecommendationId != supersedes ||
        row.scope != command.scope.stableId ||
        row.localPeriodStart != command.evaluation.startLocalDate ||
        row.localPeriodEnd != command.evaluation.endLocalDate ||
        row.createdAtUtc.toUtc() != command.evaluation.evaluatedAtUtc.toUtc() ||
        row.effectiveAtUtc?.toUtc() !=
            command.evaluation.evaluatedAtUtc.toUtc()) {
      throw const B04RecommendationHistoryError(
        'replay_conflict',
        'A replay identity already belongs to different immutable content.',
      );
    }
  }

  void _assertFeedback(
    db.RecommendationFeedbackData row,
    B04RecommendationFeedbackCommand command,
    String owner,
  ) {
    if (row.userId != owner) {
      throw const B04RecommendationHistoryError(
        'cross_user_reference',
        'Feedback identity cannot be reused across users.',
      );
    }
    if (row.recommendationId != command.recommendationId.trim() ||
        row.action != command.action.stableId ||
        row.reason != _trimmedOrNull(command.reason) ||
        row.source != command.source.trim() ||
        row.localDate != command.localDate ||
        row.timezoneId != command.timezoneId ||
        row.createdAtUtc.toUtc() != command.createdAtUtc.toUtc() ||
        row.relatedFeedbackId != command.relatedFeedbackId?.trim()) {
      throw const B04RecommendationHistoryError(
        'feedback_replay_conflict',
        'A feedback identity already belongs to different immutable content.',
      );
    }
  }

  B04RecommendationEvidenceRecord _evidenceFromRow(
    db.RecommendationEvidenceData row,
  ) => B04RecommendationEvidenceRecord(
    id: row.id,
    recommendationId: row.recommendationId,
    userId: row.userId,
    evidenceKind: row.evidenceKind,
    sourceType: row.sourceType,
    sourceId: row.sourceId,
    sourceVersion: row.sourceVersion,
    status: row.status,
    value: row.value,
    lower: row.lower,
    upper: row.upper,
    unit: row.unit,
    exactResultNumerator: row.exactResultNumerator,
    exactResultDenominator: row.exactResultDenominator,
    normalizedMaintenanceKcal: row.normalizedMaintenanceKcal,
    localDate: row.localDate,
    timezoneId: row.timezoneId,
    createdAtUtc: row.createdAtUtc.toUtc(),
  );

  B04RecommendationFeedbackRecord _feedbackFromRow(
    db.RecommendationFeedbackData row,
  ) => B04RecommendationFeedbackRecord(
    id: row.id,
    userId: row.userId,
    recommendationId: row.recommendationId,
    action: B04RecommendationFeedbackActionId.parse(row.action),
    reason: row.reason,
    source: row.source,
    localDate: row.localDate,
    timezoneId: row.timezoneId,
    createdAtUtc: row.createdAtUtc.toUtc(),
    relatedFeedbackId: row.relatedFeedbackId,
  );

  String _owner(String userId) {
    final owner = userId.trim();
    if (owner.isEmpty) {
      throw const B04RecommendationHistoryError(
        'invalid_user',
        'A recommendation history owner cannot be blank.',
      );
    }
    return owner;
  }

  void _validateRecommendation(B04Recommendation recommendation) {
    _validateBounded(recommendation.id, 'recommendation ID', 128);
    _validateBounded(recommendation.rationaleCode, 'rationale code', 128);
    _validateBounded(
      recommendation.explanation,
      'recommendation explanation',
      1024,
    );
    _validateBounded(recommendation.ruleVersion, 'rule version', 128);
    _validateBounded(recommendation.algorithmVersion, 'algorithm version', 128);
    _validateBounded(recommendation.copyVersion, 'copy version', 128);
    _validateBounded(recommendation.policyVersion, 'policy version', 128);
    for (final value in [
      ...recommendation.evidenceIds,
      ...recommendation.missingEvidence,
      ...recommendation.uncertaintyCodes,
      ...recommendation.unavailableReasons,
      ...recommendation.alternativeIds,
    ]) {
      _validateBounded(value, 'recommendation identifier', 128);
    }
  }
}

String _encodeList(Iterable<String> values) =>
    values.map((item) => item.trim()).toList().isEmpty
    ? '[]'
    : jsonEncode(values.map((item) => item.trim()).toList());

List<String> _decodeList(String? value) {
  if (value == null || value.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(value);
    if (decoded is! List || decoded.any((item) => item is! String)) {
      throw const FormatException();
    }
    return List.unmodifiable(decoded.cast<String>());
  } on FormatException {
    throw const B04RecommendationHistoryError(
      'invalid_serialized_history',
      'Recommendation history list fields must be JSON string arrays.',
    );
  }
}

double? _confidence(B04RecommendationConfidence value) => switch (value) {
  B04RecommendationConfidence.high => 1,
  B04RecommendationConfidence.medium => .66,
  B04RecommendationConfidence.low => .33,
  B04RecommendationConfidence.unknown => null,
};

B04RecommendationState _state(String value) => switch (value.trim()) {
  'available' => B04RecommendationState.available,
  'cautious' => B04RecommendationState.cautious,
  'confirm' => B04RecommendationState.confirm,
  'unavailable' => B04RecommendationState.unavailable,
  'dismissed' => B04RecommendationState.dismissed,
  'superseded' => B04RecommendationState.superseded,
  _ => throw const B04RecommendationHistoryError(
    'invalid_history_state',
    'Recommendation history contains an unsupported state.',
  ),
};

B04RecommendationPriority _priority(int value) =>
    B04RecommendationPriority.values.firstWhere(
      (item) => item.rank == value,
      orElse: () => throw const B04RecommendationHistoryError(
        'invalid_history_priority',
        'Recommendation history contains an unsupported priority.',
      ),
    );

B04RecommendationCompleteness _completeness(String value) => switch (value) {
  'complete' => B04RecommendationCompleteness.complete,
  'partial' => B04RecommendationCompleteness.partial,
  'missing' => B04RecommendationCompleteness.missing,
  'invalid' => B04RecommendationCompleteness.invalid,
  _ => throw const B04RecommendationHistoryError(
    'invalid_history_completeness',
    'Recommendation history contains unsupported completeness.',
  ),
};

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

int _consentOrder(db.CoachingConsentEvent left, db.CoachingConsentEvent right) {
  final timestamp = right.timestampUtc.compareTo(left.timestampUtc);
  if (timestamp != 0) return timestamp;
  final created = right.createdAtUtc.compareTo(left.createdAtUtc);
  if (created != 0) return created;
  return right.id.compareTo(left.id);
}

int _eligibilityOrder(
  db.CoachingEligibilityEvaluation left,
  db.CoachingEligibilityEvaluation right,
) {
  final timestamp = right.evaluationUtc.compareTo(left.evaluationUtc);
  if (timestamp != 0) return timestamp;
  final created = right.createdAtUtc.compareTo(left.createdAtUtc);
  if (created != 0) return created;
  return right.id.compareTo(left.id);
}

void _validateBounded(String? value, String label, int maximum) {
  if (value != null && value.length > maximum) {
    throw B04RecommendationHistoryError(
      'unbounded_payload',
      '$label exceeds the durable history limit.',
    );
  }
}

String _sha256(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonicalize(value)))).toString();

dynamic _canonicalize(dynamic value) {
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    return {
      for (final entry in entries)
        entry.key.toString(): _canonicalize(entry.value),
    };
  }
  if (value is Iterable) return value.map(_canonicalize).toList();
  if (value is DateTime) return value.toUtc().toIso8601String();
  return value;
}
