import '../../core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import 'b04_recommendation_history_models.dart';
import 'b04_recommendation_models.dart';

/// Versioned, ephemeral B04-13 projection contracts.
const String kB04BriefingReadModelVersion = 'B04-13-BRIEFING-READ-MODEL-V1';

enum B04BriefingReadStatus { available, noData, unavailable }

extension B04BriefingReadStatusId on B04BriefingReadStatus {
  String get stableId => name;
}

enum B04BriefingFeedbackState {
  untouched,
  acknowledged,
  accepted,
  overridden,
  dismissed,
  snoozed,
  notRelevant,
}

extension B04BriefingFeedbackStateId on B04BriefingFeedbackState {
  String get stableId => switch (this) {
    B04BriefingFeedbackState.untouched => 'untouched',
    B04BriefingFeedbackState.acknowledged => 'acknowledged',
    B04BriefingFeedbackState.accepted => 'accepted',
    B04BriefingFeedbackState.overridden => 'overridden',
    B04BriefingFeedbackState.dismissed => 'dismissed',
    B04BriefingFeedbackState.snoozed => 'snoozed',
    B04BriefingFeedbackState.notRelevant => 'not_relevant',
  };
}

enum B04BriefingTargetAcceptanceState {
  notApplicable,
  unavailable,
  proposalAvailable,
  accepted,
  unchanged,
}

extension B04BriefingTargetAcceptanceStateId
    on B04BriefingTargetAcceptanceState {
  String get stableId => switch (this) {
    B04BriefingTargetAcceptanceState.notApplicable => 'not_applicable',
    B04BriefingTargetAcceptanceState.unavailable => 'unavailable',
    B04BriefingTargetAcceptanceState.proposalAvailable => 'proposal_available',
    B04BriefingTargetAcceptanceState.accepted => 'accepted',
    B04BriefingTargetAcceptanceState.unchanged => 'unchanged',
  };
}

/// Canonical numerical output already attached to a recommendation. B04-13
/// carries it for display and history; it never recalculates or rounds it.
class B04BriefingNumericalResult {
  final String? exactResultNumerator;
  final String? exactResultDenominator;
  final int? normalizedMaintenanceKcal;
  final int? proposedDeltaKcal;

  const B04BriefingNumericalResult({
    required this.exactResultNumerator,
    required this.exactResultDenominator,
    required this.normalizedMaintenanceKcal,
    required this.proposedDeltaKcal,
  });

  bool get hasCanonicalResult =>
      exactResultNumerator != null ||
      exactResultDenominator != null ||
      normalizedMaintenanceKcal != null ||
      proposedDeltaKcal != null;

  Map<String, dynamic> toRedactedMap() => {
    if (exactResultNumerator != null)
      'exact_result_numerator': exactResultNumerator,
    if (exactResultDenominator != null)
      'exact_result_denominator': exactResultDenominator,
    if (normalizedMaintenanceKcal != null)
      'normalized_maintenance_kcal': normalizedMaintenanceKcal,
    if (proposedDeltaKcal != null) 'proposed_delta_kcal': proposedDeltaKcal,
  };
}

/// One daily/weekly item. It can carry either an in-memory engine result or
/// its immutable historical row, but never a second calculated result.
class B04BriefingRecommendation {
  final String id;
  final String action;
  final B04RecommendationState state;
  final B04RecommendationPriority priority;
  final String? rationaleCode;
  final B04RecommendationConfidence? confidence;
  final B04RecommendationCompleteness? completeness;
  final String explanation;
  final List<String> alternatives;
  final List<String> missingEvidence;
  final List<String> uncertainty;
  final List<String> evidenceIds;
  final String? goalVersionId;
  final String? readinessSnapshotId;
  final String? consentEventId;
  final String? eligibilityEvaluationId;
  final String? policyVersion;
  final String? calculationVersion;
  final String? ruleVersion;
  final String? algorithmVersion;
  final String? modelVersion;
  final String? providerVersion;
  final String? copyVersion;
  final B04RecommendationEligibilityState? eligibilityState;
  final B04RecommendationConsentState? consentState;
  final B04BriefingNumericalResult? canonicalResult;
  final B04BriefingTargetAcceptanceState targetAcceptanceState;
  final B04BriefingFeedbackState feedbackState;
  final List<B04RecommendationFeedbackRecord> feedback;
  final bool isVisible;
  final B04Recommendation? engineRecommendation;
  final B04HistoricalRecommendation? historicalRecommendation;

  const B04BriefingRecommendation({
    required this.id,
    required this.action,
    required this.state,
    required this.priority,
    required this.rationaleCode,
    required this.confidence,
    required this.completeness,
    required this.explanation,
    required this.alternatives,
    required this.missingEvidence,
    required this.uncertainty,
    required this.evidenceIds,
    required this.goalVersionId,
    required this.readinessSnapshotId,
    required this.consentEventId,
    required this.eligibilityEvaluationId,
    required this.policyVersion,
    required this.calculationVersion,
    required this.ruleVersion,
    required this.algorithmVersion,
    required this.modelVersion,
    required this.providerVersion,
    required this.copyVersion,
    required this.eligibilityState,
    required this.consentState,
    required this.canonicalResult,
    required this.targetAcceptanceState,
    required this.feedbackState,
    required this.feedback,
    required this.isVisible,
    required this.engineRecommendation,
    required this.historicalRecommendation,
  });

  factory B04BriefingRecommendation.fromEngine(
    B04Recommendation recommendation, {
    Iterable<B04RecommendationFeedbackRecord> feedback = const [],
  }) {
    final List<B04RecommendationFeedbackRecord> feedbackList =
        List.unmodifiable(feedback);
    return B04BriefingRecommendation(
      id: recommendation.id,
      action: recommendation.action.stableId,
      state: recommendation.state,
      priority: recommendation.priority,
      rationaleCode: recommendation.rationaleCode,
      confidence: recommendation.confidence,
      completeness: recommendation.completeness,
      explanation: recommendation.explanation,
      alternatives: recommendation.alternativeIds,
      missingEvidence: {
        ...recommendation.missingEvidence,
        ...recommendation.unavailableReasons,
      }.toList()..sort(),
      uncertainty: recommendation.uncertaintyCodes,
      evidenceIds: recommendation.evidenceIds,
      goalVersionId: null,
      readinessSnapshotId: null,
      consentEventId: null,
      eligibilityEvaluationId: null,
      policyVersion: recommendation.policyVersion,
      calculationVersion:
          recommendation.canonicalAdaptiveTarget?.calculationVersion ??
          recommendation
              .canonicalTrainingRecommendation
              ?.recommendation
              .ruleVersion,
      ruleVersion: recommendation.ruleVersion,
      algorithmVersion: recommendation.algorithmVersion,
      modelVersion: null,
      providerVersion: null,
      copyVersion: recommendation.copyVersion,
      eligibilityState: recommendation.eligibilityState,
      consentState: recommendation.consentState,
      canonicalResult: _numericalResult(recommendation),
      targetAcceptanceState: _targetAcceptanceFromEngine(recommendation),
      feedbackState: _feedbackState(feedbackList),
      feedback: feedbackList,
      isVisible: _isVisible(feedbackList),
      engineRecommendation: recommendation,
      historicalRecommendation: null,
    );
  }

  factory B04BriefingRecommendation.fromHistory(
    B04HistoricalRecommendation recommendation,
  ) {
    final feedback = recommendation.feedback;
    return B04BriefingRecommendation(
      id: recommendation.id,
      action: recommendation.action,
      state: recommendation.state,
      priority: recommendation.priority,
      rationaleCode: null,
      confidence: _confidenceFromHistory(recommendation.confidence),
      completeness: recommendation.completeness,
      explanation: recommendation.explanation,
      alternatives: recommendation.alternatives,
      missingEvidence: recommendation.reasonCodes,
      uncertainty: recommendation.uncertainty,
      evidenceIds: [
        ...recommendation.evidence.map((item) => item.sourceId),
        ...recommendation.evidence.map((item) => item.id),
      ].whereType<String>().toSet().toList()..sort(),
      goalVersionId: recommendation.goalVersionId,
      readinessSnapshotId: recommendation.readinessSnapshotId,
      consentEventId: recommendation.consentEventId,
      eligibilityEvaluationId: recommendation.eligibilityEvaluationId,
      policyVersion: recommendation.policyVersion,
      calculationVersion: recommendation.calculationVersion,
      ruleVersion: recommendation.ruleVersion,
      algorithmVersion: recommendation.algorithmVersion,
      modelVersion: recommendation.modelVersion,
      providerVersion: recommendation.providerVersion,
      copyVersion: null,
      eligibilityState: _eligibilityStateFromEvidence(recommendation.evidence),
      consentState: _consentStateFromEvidence(recommendation.evidence),
      canonicalResult: _historicalNumericalResult(recommendation),
      targetAcceptanceState: _targetAcceptanceFromHistory(recommendation),
      feedbackState: _feedbackState(feedback),
      feedback: feedback,
      isVisible:
          recommendation.state != B04RecommendationState.dismissed &&
          recommendation.state != B04RecommendationState.superseded &&
          !recommendation.isDismissed,
      engineRecommendation: null,
      historicalRecommendation: recommendation,
    );
  }

  String get accessibilityLabel {
    final stateLabel = switch (state) {
      B04RecommendationState.available => 'available',
      B04RecommendationState.cautious => 'use caution',
      B04RecommendationState.confirm => 'needs confirmation',
      B04RecommendationState.unavailable => 'unavailable',
      B04RecommendationState.dismissed => 'dismissed',
      B04RecommendationState.superseded => 'superseded',
    };
    final feedbackLabel = feedbackState == B04BriefingFeedbackState.untouched
        ? ''
        : ', feedback ${feedbackState.stableId.replaceAll('_', ' ')}';
    return '$explanation, $stateLabel$feedbackLabel';
  }
}

/// A recomputable projection for either one local civil day or one explicit
/// seven-civil-day period. No instance of this model is persisted.
class B04BriefingReadModel {
  final String version;
  final B04RecommendationHistoryScope scope;
  final String userId;
  final String startLocalDate;
  final String endLocalDate;
  final String timezoneId;
  final B04BriefingReadStatus status;
  final List<String> unavailableReasons;
  final B04RecommendationEligibilityState? eligibilityState;
  final B04RecommendationConsentState? consentState;
  final B04RecommendationPolicyState? policyState;
  final List<String> missingEvidence;
  final List<B04BriefingRecommendation> recommendations;
  final List<B04RecommendationWarning> lowRiskWarnings;

  const B04BriefingReadModel({
    this.version = kB04BriefingReadModelVersion,
    required this.scope,
    required this.userId,
    required this.startLocalDate,
    required this.endLocalDate,
    required this.timezoneId,
    required this.status,
    required this.unavailableReasons,
    required this.eligibilityState,
    required this.consentState,
    required this.policyState,
    required this.missingEvidence,
    required this.recommendations,
    required this.lowRiskWarnings,
  });

  bool get hasData => visibleRecommendations.isNotEmpty;

  String get accessibilityLabel {
    final period = scope == B04RecommendationHistoryScope.daily
        ? 'daily briefing for $startLocalDate'
        : 'weekly review from $startLocalDate to $endLocalDate';
    final statusLabel = switch (status) {
      B04BriefingReadStatus.available => 'available',
      B04BriefingReadStatus.noData => 'no recommendations yet',
      B04BriefingReadStatus.unavailable => 'unavailable',
    };
    final reasons = unavailableReasons.isEmpty
        ? ''
        : '. Reasons: ${unavailableReasons.join(', ').replaceAll('_', ' ')}';
    return '$period, $statusLabel$reasons';
  }

  Map<String, dynamic> toRedactedMap() => {
    'version': version,
    'scope': scope.stableId,
    'user_id': userId,
    'start_local_date': startLocalDate,
    'end_local_date': endLocalDate,
    'timezone_id': timezoneId,
    'status': status.stableId,
    'unavailable_reasons': unavailableReasons,
    if (eligibilityState != null)
      'eligibility_state': eligibilityState!.stableId,
    if (consentState != null) 'consent_state': consentState!.stableId,
    if (policyState != null) 'policy_state': policyState!.stableId,
    'missing_evidence': missingEvidence,
    'recommendations': recommendations
        .map(
          (item) => {
            'id': item.id,
            'action': item.action,
            'state': item.state.stableId,
            'priority': item.priority.stableId,
            if (item.rationaleCode != null)
              'rationale_code': item.rationaleCode,
            if (item.confidence != null)
              'confidence': item.confidence!.stableId,
            if (item.completeness != null)
              'completeness': item.completeness!.stableId,
            'explanation': item.explanation,
            'alternatives': item.alternatives,
            'missing_evidence': item.missingEvidence,
            'uncertainty': item.uncertainty,
            'evidence_ids': item.evidenceIds,
            if (item.goalVersionId != null)
              'goal_version_id': item.goalVersionId,
            if (item.readinessSnapshotId != null)
              'readiness_snapshot_id': item.readinessSnapshotId,
            if (item.consentEventId != null)
              'consent_event_id': item.consentEventId,
            if (item.eligibilityEvaluationId != null)
              'eligibility_evaluation_id': item.eligibilityEvaluationId,
            if (item.policyVersion != null)
              'policy_version': item.policyVersion,
            if (item.calculationVersion != null)
              'calculation_version': item.calculationVersion,
            if (item.ruleVersion != null) 'rule_version': item.ruleVersion,
            if (item.algorithmVersion != null)
              'algorithm_version': item.algorithmVersion,
            if (item.modelVersion != null) 'model_version': item.modelVersion,
            if (item.providerVersion != null)
              'provider_version': item.providerVersion,
            if (item.copyVersion != null) 'copy_version': item.copyVersion,
            if (item.eligibilityState != null)
              'eligibility_state': item.eligibilityState!.stableId,
            if (item.consentState != null)
              'consent_state': item.consentState!.stableId,
            if (item.canonicalResult?.hasCanonicalResult == true)
              'canonical_result': item.canonicalResult!.toRedactedMap(),
            'target_acceptance_state': item.targetAcceptanceState.stableId,
            'feedback_state': item.feedbackState.stableId,
            'visible': item.isVisible,
          },
        )
        .toList(),
    'low_risk_warnings': lowRiskWarnings
        .map((item) => item.toRedactedMap())
        .toList(),
  };

  List<B04BriefingRecommendation> get visibleRecommendations =>
      recommendations.where((item) => item.isVisible).toList(growable: false);
}

/// These aliases make the two consumers explicit without creating two model
/// authorities or two projection contracts.
typedef B04DailyBriefingReadModel = B04BriefingReadModel;
typedef B04WeeklyReviewReadModel = B04BriefingReadModel;

B04BriefingNumericalResult? _numericalResult(B04Recommendation recommendation) {
  if (recommendation.state == B04RecommendationState.unavailable ||
      recommendation.targetAcceptanceState ==
          B04RecommendationTargetAcceptanceState.unavailable) {
    return null;
  }
  final target = recommendation.canonicalAdaptiveTarget;
  if (target == null) return null;
  final proposal = target.proposal;
  return B04BriefingNumericalResult(
    exactResultNumerator: proposal?.exactResultNumerator,
    exactResultDenominator: proposal?.exactResultDenominator,
    normalizedMaintenanceKcal: target.normalizedMaintenanceKcal,
    proposedDeltaKcal: target.adaptiveDeltaKcal,
  );
}

B04BriefingTargetAcceptanceState _targetAcceptanceFromEngine(
  B04Recommendation recommendation,
) => switch (recommendation.targetAcceptanceState) {
  B04RecommendationTargetAcceptanceState.notApplicable =>
    B04BriefingTargetAcceptanceState.notApplicable,
  B04RecommendationTargetAcceptanceState.unavailable =>
    B04BriefingTargetAcceptanceState.unavailable,
  B04RecommendationTargetAcceptanceState.proposalAvailable =>
    B04BriefingTargetAcceptanceState.proposalAvailable,
  B04RecommendationTargetAcceptanceState.unchanged =>
    B04BriefingTargetAcceptanceState.unchanged,
};

B04BriefingTargetAcceptanceState _targetAcceptanceFromHistory(
  B04HistoricalRecommendation recommendation,
) {
  final baseState = switch (recommendation.targetAcceptanceState) {
    B04RecommendationTargetAcceptanceState.notApplicable =>
      B04BriefingTargetAcceptanceState.notApplicable,
    B04RecommendationTargetAcceptanceState.unavailable =>
      B04BriefingTargetAcceptanceState.unavailable,
    B04RecommendationTargetAcceptanceState.unchanged =>
      B04BriefingTargetAcceptanceState.unchanged,
    B04RecommendationTargetAcceptanceState.proposalAvailable =>
      B04BriefingTargetAcceptanceState.proposalAvailable,
  };
  if (baseState != B04BriefingTargetAcceptanceState.proposalAvailable) {
    return baseState;
  }
  final acceptedEvents = recommendation.feedback
      .where((item) => item.action == B04RecommendationFeedbackAction.accept)
      .toList();
  if (acceptedEvents.any(
    (item) =>
        item.userId != recommendation.userId ||
        item.recommendationId != recommendation.id,
  )) {
    return B04BriefingTargetAcceptanceState.unavailable;
  }
  if (acceptedEvents.isNotEmpty) {
    return B04BriefingTargetAcceptanceState.accepted;
  }
  return baseState;
}

B04BriefingNumericalResult? _historicalNumericalResult(
  B04HistoricalRecommendation recommendation,
) {
  if (recommendation.state == B04RecommendationState.unavailable ||
      (recommendation.action ==
              B04RecommendationAction.nutritionTarget.stableId &&
          recommendation.policyVersion != kB04EnabledPolicyVersion) ||
      (recommendation.exactResultNumerator == null &&
          recommendation.exactResultDenominator == null &&
          recommendation.normalizedMaintenanceKcal == null &&
          recommendation.proposedDeltaKcal == null)) {
    return null;
  }
  return B04BriefingNumericalResult(
    exactResultNumerator: recommendation.exactResultNumerator,
    exactResultDenominator: recommendation.exactResultDenominator,
    normalizedMaintenanceKcal: recommendation.normalizedMaintenanceKcal,
    proposedDeltaKcal: recommendation.proposedDeltaKcal,
  );
}

B04RecommendationConfidence? _confidenceFromHistory(double? value) {
  if (value == null) return B04RecommendationConfidence.unknown;
  if (value >= .83) return B04RecommendationConfidence.high;
  if (value >= .5) return B04RecommendationConfidence.medium;
  return B04RecommendationConfidence.low;
}

B04RecommendationConsentState _consentStateFromEvidence(
  Iterable<B04RecommendationEvidenceRecord> evidence,
) {
  final events =
      evidence.where((item) => item.evidenceKind == 'consent').toList()
        ..sort((left, right) {
          final time = left.createdAtUtc.compareTo(right.createdAtUtc);
          return time == 0 ? left.id.compareTo(right.id) : time;
        });
  if (events.isEmpty) return B04RecommendationConsentState.missing;
  return events.last.status == 'enable'
      ? B04RecommendationConsentState.enabled
      : B04RecommendationConsentState.disabled;
}

B04RecommendationEligibilityState _eligibilityStateFromEvidence(
  Iterable<B04RecommendationEvidenceRecord> evidence,
) {
  final events =
      evidence.where((item) => item.evidenceKind == 'eligibility').toList()
        ..sort((left, right) {
          final time = left.createdAtUtc.compareTo(right.createdAtUtc);
          return time == 0 ? left.id.compareTo(right.id) : time;
        });
  if (events.isEmpty) return B04RecommendationEligibilityState.missing;
  return switch (events.last.status) {
    'eligible' => B04RecommendationEligibilityState.eligible,
    'underage' => B04RecommendationEligibilityState.underage,
    'unknown_age' => B04RecommendationEligibilityState.unknownAge,
    'conflicting_age' => B04RecommendationEligibilityState.conflictingAge,
    'withheld_age' => B04RecommendationEligibilityState.withheldAge,
    'invalid_evidence' => B04RecommendationEligibilityState.invalidEvidence,
    'policy_unavailable' => B04RecommendationEligibilityState.policyUnavailable,
    _ => B04RecommendationEligibilityState.missing,
  };
}

B04BriefingFeedbackState _feedbackState(
  Iterable<B04RecommendationFeedbackRecord> events,
) {
  final ordered = [...events]
    ..sort((left, right) {
      final time = left.createdAtUtc.compareTo(right.createdAtUtc);
      return time == 0 ? left.id.compareTo(right.id) : time;
    });
  if (ordered.isEmpty) return B04BriefingFeedbackState.untouched;
  return switch (ordered.last.action) {
    B04RecommendationFeedbackAction.acknowledge =>
      B04BriefingFeedbackState.acknowledged,
    B04RecommendationFeedbackAction.accept => B04BriefingFeedbackState.accepted,
    B04RecommendationFeedbackAction.override =>
      B04BriefingFeedbackState.overridden,
    B04RecommendationFeedbackAction.dismiss =>
      B04BriefingFeedbackState.dismissed,
    B04RecommendationFeedbackAction.snooze => B04BriefingFeedbackState.snoozed,
    B04RecommendationFeedbackAction.notRelevant =>
      B04BriefingFeedbackState.notRelevant,
  };
}

bool _isVisible(Iterable<B04RecommendationFeedbackRecord> events) {
  var visible = true;
  final ordered = [...events]
    ..sort((left, right) {
      final time = left.createdAtUtc.compareTo(right.createdAtUtc);
      return time == 0 ? left.id.compareTo(right.id) : time;
    });
  for (final event in ordered) {
    switch (event.action) {
      case B04RecommendationFeedbackAction.dismiss:
      case B04RecommendationFeedbackAction.notRelevant:
        visible = false;
      case B04RecommendationFeedbackAction.acknowledge:
      case B04RecommendationFeedbackAction.accept:
      case B04RecommendationFeedbackAction.override:
        visible = true;
      case B04RecommendationFeedbackAction.snooze:
        break;
    }
  }
  return visible;
}
