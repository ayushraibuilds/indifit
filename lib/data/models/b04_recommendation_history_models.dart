import '../../core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import 'b04_recommendation_models.dart';

/// Durable scope for a recommendation history row. Daily and weekly rows are
/// historical inputs to recomputable projections; they are not caches.
enum B04RecommendationHistoryScope {
  daily,
  weekly,
  training,
  nutrition,
  mealOpportunity,
}

extension B04RecommendationHistoryScopeId on B04RecommendationHistoryScope {
  String get stableId => switch (this) {
    B04RecommendationHistoryScope.daily => 'daily',
    B04RecommendationHistoryScope.weekly => 'weekly',
    B04RecommendationHistoryScope.training => 'training',
    B04RecommendationHistoryScope.nutrition => 'nutrition',
    B04RecommendationHistoryScope.mealOpportunity => 'meal_opportunity',
  };

  static B04RecommendationHistoryScope parse(String value) =>
      switch (value.trim()) {
        'daily' => B04RecommendationHistoryScope.daily,
        'weekly' => B04RecommendationHistoryScope.weekly,
        'training' => B04RecommendationHistoryScope.training,
        'nutrition' => B04RecommendationHistoryScope.nutrition,
        'meal_opportunity' => B04RecommendationHistoryScope.mealOpportunity,
        _ => throw const B04RecommendationHistoryError(
          'invalid_scope',
          'The recommendation history scope is not supported.',
        ),
      };
}

/// A typed, privacy-minimized source snapshot attached to one recommendation.
/// Values and ranges are frozen at issue time; raw prompts and provider
/// payloads are intentionally not representable here.
class B04RecommendationEvidenceInput {
  final String evidenceKind;
  final String sourceType;
  final String? sourceId;
  final String? sourceVersion;
  final String status;
  final double? value;
  final double? lower;
  final double? upper;
  final String? unit;
  final String? exactResultNumerator;
  final String? exactResultDenominator;
  final int? normalizedMaintenanceKcal;
  final String? localDate;
  final String? timezoneId;

  const B04RecommendationEvidenceInput({
    required this.evidenceKind,
    required this.sourceType,
    this.sourceId,
    this.sourceVersion,
    required this.status,
    this.value,
    this.lower,
    this.upper,
    this.unit,
    this.exactResultNumerator,
    this.exactResultDenominator,
    this.normalizedMaintenanceKcal,
    this.localDate,
    this.timezoneId,
  });

  Map<String, dynamic> toRedactedMap() => {
    'evidence_kind': evidenceKind,
    'source_type': sourceType,
    if (sourceId != null) 'source_id': sourceId,
    if (sourceVersion != null) 'source_version': sourceVersion,
    'status': status,
    if (value != null) 'value': value,
    if (lower != null) 'lower': lower,
    if (upper != null) 'upper': upper,
    if (unit != null) 'unit': unit,
    if (exactResultNumerator != null)
      'exact_result_numerator': exactResultNumerator,
    if (exactResultDenominator != null)
      'exact_result_denominator': exactResultDenominator,
    if (normalizedMaintenanceKcal != null)
      'normalized_maintenance_kcal': normalizedMaintenanceKcal,
    if (localDate != null) 'local_date': localDate,
    if (timezoneId != null) 'timezone_id': timezoneId,
  };
}

/// The complete immutable lineage required to issue an evaluation into
/// durable recommendation history.
class B04RecommendationHistoryCommand {
  final B04RecommendationEvaluation evaluation;
  final B04RecommendationHistoryScope scope;
  final String? consentEventId;
  final String? eligibilityEvaluationId;
  final String? goalVersionId;
  final String? readinessSnapshotId;
  final Map<String, List<B04RecommendationEvidenceInput>>
  evidenceByRecommendationId;
  final Map<String, String?> supersedesByRecommendationId;

  B04RecommendationHistoryCommand({
    required this.evaluation,
    required this.scope,
    String? consentEventId,
    String? eligibilityEvaluationId,
    this.goalVersionId,
    this.readinessSnapshotId,
    Map<String, Iterable<B04RecommendationEvidenceInput>>
        evidenceByRecommendationId =
        const {},
    Map<String, String?> supersedesByRecommendationId = const {},
  }) : consentEventId = consentEventId?.trim().isEmpty == true
           ? null
           : consentEventId?.trim(),
       eligibilityEvaluationId = eligibilityEvaluationId?.trim().isEmpty == true
           ? null
           : eligibilityEvaluationId?.trim(),
       evidenceByRecommendationId = Map.unmodifiable(
         <String, List<B04RecommendationEvidenceInput>>{
           for (final entry in evidenceByRecommendationId.entries)
             entry.key.trim():
                 List<B04RecommendationEvidenceInput>.unmodifiable(entry.value),
         },
       ),
       supersedesByRecommendationId = Map.unmodifiable(<String, String?>{
         for (final entry in supersedesByRecommendationId.entries)
           entry.key.trim(): entry.value?.trim(),
       }) {
    final requiresAdaptiveLineage =
        scope != B04RecommendationHistoryScope.mealOpportunity;
    if (requiresAdaptiveLineage &&
        (this.consentEventId == null || this.eligibilityEvaluationId == null)) {
      throw const B04RecommendationHistoryError(
        'missing_lineage_reference',
        'Recommendation history requires consent and eligibility references.',
      );
    }
    if (this.evidenceByRecommendationId.keys.any((key) => key.isEmpty) ||
        this.supersedesByRecommendationId.keys.any((key) => key.isEmpty)) {
      throw const B04RecommendationHistoryError(
        'invalid_lineage_reference',
        'Recommendation history lineage keys cannot be blank.',
      );
    }
  }

  List<B04RecommendationEvidenceInput> evidenceFor(String recommendationId) {
    return evidenceByRecommendationId[recommendationId] ?? const [];
  }

  String? supersedesFor(String recommendationId) =>
      supersedesByRecommendationId[recommendationId];
}

class B04RecommendationEvidenceRecord {
  final String id;
  final String recommendationId;
  final String userId;
  final String evidenceKind;
  final String sourceType;
  final String? sourceId;
  final String? sourceVersion;
  final String status;
  final double? value;
  final double? lower;
  final double? upper;
  final String? unit;
  final String? exactResultNumerator;
  final String? exactResultDenominator;
  final int? normalizedMaintenanceKcal;
  final String? localDate;
  final String? timezoneId;
  final DateTime createdAtUtc;

  const B04RecommendationEvidenceRecord({
    required this.id,
    required this.recommendationId,
    required this.userId,
    required this.evidenceKind,
    required this.sourceType,
    required this.sourceId,
    required this.sourceVersion,
    required this.status,
    required this.value,
    required this.lower,
    required this.upper,
    required this.unit,
    required this.exactResultNumerator,
    required this.exactResultDenominator,
    required this.normalizedMaintenanceKcal,
    required this.localDate,
    required this.timezoneId,
    required this.createdAtUtc,
  });

  Map<String, dynamic> toRedactedMap() => {
    'id': id,
    'recommendation_id': recommendationId,
    'evidence_kind': evidenceKind,
    'source_type': sourceType,
    if (sourceId != null) 'source_id': sourceId,
    if (sourceVersion != null) 'source_version': sourceVersion,
    'status': status,
    if (value != null) 'value': value,
    if (lower != null) 'lower': lower,
    if (upper != null) 'upper': upper,
    if (unit != null) 'unit': unit,
    if (exactResultNumerator != null)
      'exact_result_numerator': exactResultNumerator,
    if (exactResultDenominator != null)
      'exact_result_denominator': exactResultDenominator,
    if (normalizedMaintenanceKcal != null)
      'normalized_maintenance_kcal': normalizedMaintenanceKcal,
    if (localDate != null) 'local_date': localDate,
    if (timezoneId != null) 'timezone_id': timezoneId,
    'created_at_utc': createdAtUtc.toIso8601String(),
  };
}

enum B04RecommendationFeedbackAction {
  acknowledge,
  dismiss,
  accept,
  override,
  snooze,
  notRelevant,
}

extension B04RecommendationFeedbackActionId on B04RecommendationFeedbackAction {
  String get stableId => switch (this) {
    B04RecommendationFeedbackAction.acknowledge => 'acknowledge',
    B04RecommendationFeedbackAction.dismiss => 'dismiss',
    B04RecommendationFeedbackAction.accept => 'accept',
    B04RecommendationFeedbackAction.override => 'override',
    B04RecommendationFeedbackAction.snooze => 'snooze',
    B04RecommendationFeedbackAction.notRelevant => 'not_relevant',
  };

  static B04RecommendationFeedbackAction parse(String value) =>
      switch (value.trim()) {
        'acknowledge' => B04RecommendationFeedbackAction.acknowledge,
        'dismiss' => B04RecommendationFeedbackAction.dismiss,
        'accept' => B04RecommendationFeedbackAction.accept,
        'override' => B04RecommendationFeedbackAction.override,
        'snooze' => B04RecommendationFeedbackAction.snooze,
        'not_relevant' => B04RecommendationFeedbackAction.notRelevant,
        _ => throw const B04RecommendationHistoryError(
          'invalid_feedback_action',
          'The recommendation feedback action is not supported.',
        ),
      };
}

class B04RecommendationFeedbackCommand {
  final String userId;
  final String recommendationId;
  final B04RecommendationFeedbackAction action;
  final String? reason;
  final String source;
  final String localDate;
  final String timezoneId;
  final DateTime createdAtUtc;
  final String? relatedFeedbackId;
  final String? id;

  const B04RecommendationFeedbackCommand({
    required this.userId,
    required this.recommendationId,
    required this.action,
    this.reason,
    required this.source,
    required this.localDate,
    required this.timezoneId,
    required this.createdAtUtc,
    this.relatedFeedbackId,
    this.id,
  });
}

class B04RecommendationFeedbackRecord {
  final String id;
  final String userId;
  final String recommendationId;
  final B04RecommendationFeedbackAction action;
  final String? reason;
  final String source;
  final String localDate;
  final String timezoneId;
  final DateTime createdAtUtc;
  final String? relatedFeedbackId;

  const B04RecommendationFeedbackRecord({
    required this.id,
    required this.userId,
    required this.recommendationId,
    required this.action,
    required this.reason,
    required this.source,
    required this.localDate,
    required this.timezoneId,
    required this.createdAtUtc,
    required this.relatedFeedbackId,
  });

  Map<String, dynamic> toRedactedMap() => {
    'id': id,
    'recommendation_id': recommendationId,
    'action': action.stableId,
    if (reason != null) 'reason': reason,
    'source': source,
    'local_date': localDate,
    'timezone_id': timezoneId,
    'created_at_utc': createdAtUtc.toIso8601String(),
    if (relatedFeedbackId != null) 'related_feedback_id': relatedFeedbackId,
  };
}

/// Read model for one immutable issued recommendation and its append-only
/// feedback/evidence children.
class B04HistoricalRecommendation {
  final String id;
  final String userId;
  final B04RecommendationHistoryScope scope;
  final String localPeriodStart;
  final String localPeriodEnd;
  final String timezoneId;
  final B04RecommendationState state;
  final B04RecommendationPriority priority;
  final double? confidence;
  final B04RecommendationCompleteness? completeness;
  final String action;
  final String explanation;
  final List<String> missingInputs;
  final List<String> unavailableReasons;
  final List<String> uncertainty;
  final List<String> alternatives;
  final String ruleVersion;
  final String? calculationVersion;
  final String? algorithmVersion;
  final String? modelVersion;
  final String? providerVersion;
  final String? policyVersion;
  final String? goalVersionId;
  final String? readinessSnapshotId;
  final String contextFingerprint;
  final String? evidenceFingerprint;
  final String? exactResultNumerator;
  final String? exactResultDenominator;
  final int? normalizedMaintenanceKcal;
  final int? proposedDeltaKcal;
  final DateTime createdAtUtc;
  final DateTime? effectiveAtUtc;
  final DateTime? supersededAtUtc;
  final String? supersedesRecommendationId;
  final String replayHash;
  final List<B04RecommendationEvidenceRecord> evidence;
  final List<B04RecommendationFeedbackRecord> feedback;

  B04HistoricalRecommendation({
    required this.id,
    required this.userId,
    required this.scope,
    required this.localPeriodStart,
    required this.localPeriodEnd,
    required this.timezoneId,
    required this.state,
    required this.priority,
    required this.confidence,
    required this.completeness,
    required this.action,
    required this.explanation,
    Iterable<String> missingInputs = const [],
    Iterable<String> unavailableReasons = const [],
    Iterable<String> uncertainty = const [],
    Iterable<String> alternatives = const [],
    required this.ruleVersion,
    required this.calculationVersion,
    required this.algorithmVersion,
    required this.modelVersion,
    required this.providerVersion,
    required this.policyVersion,
    required this.goalVersionId,
    required this.readinessSnapshotId,
    required this.contextFingerprint,
    required this.evidenceFingerprint,
    required this.exactResultNumerator,
    required this.exactResultDenominator,
    required this.normalizedMaintenanceKcal,
    required this.proposedDeltaKcal,
    required this.createdAtUtc,
    required this.effectiveAtUtc,
    required this.supersededAtUtc,
    required this.supersedesRecommendationId,
    required this.replayHash,
    Iterable<B04RecommendationEvidenceRecord> evidence = const [],
    Iterable<B04RecommendationFeedbackRecord> feedback = const [],
  }) : missingInputs = List.unmodifiable(missingInputs),
       unavailableReasons = List.unmodifiable(unavailableReasons),
       uncertainty = List.unmodifiable(uncertainty),
       alternatives = List.unmodifiable(alternatives),
       evidence = List.unmodifiable(evidence),
       feedback = List.unmodifiable(feedback);

  String? get consentEventId => _sourceId('consent');

  String? get eligibilityEvaluationId => _sourceId('eligibility');

  /// All portable reason identifiers attached to this historical result. The
  /// v18 column is named `missing_inputs`, but it is the reason-lineage bucket
  /// for both missing evidence and unavailable output reasons.
  List<String> get reasonCodes {
    final values = <String>{
      ...missingInputs,
      ...unavailableReasons,
    }.where((value) => value.trim().isNotEmpty).toList()..sort();
    return List.unmodifiable(values);
  }

  /// The target-acceptance state frozen by the historical recommendation.
  /// A non-null delta alone is not enough: a zero-delta on-track result is
  /// unchanged, while only an actual proposal may be accepted.
  B04RecommendationTargetAcceptanceState get targetAcceptanceState {
    if (action != B04RecommendationAction.nutritionTarget.stableId) {
      return B04RecommendationTargetAcceptanceState.notApplicable;
    }
    if (state == B04RecommendationState.unavailable ||
        state == B04RecommendationState.dismissed ||
        state == B04RecommendationState.superseded ||
        policyVersion != kB04EnabledPolicyVersion ||
        proposedDeltaKcal == null) {
      return B04RecommendationTargetAcceptanceState.unavailable;
    }
    if (state != B04RecommendationState.confirm &&
        state != B04RecommendationState.available) {
      return B04RecommendationTargetAcceptanceState.unavailable;
    }
    return state == B04RecommendationState.confirm || proposedDeltaKcal != 0
        ? B04RecommendationTargetAcceptanceState.proposalAvailable
        : B04RecommendationTargetAcceptanceState.unchanged;
  }

  bool get isDismissed => _foldVisibility(feedback) == false;

  Map<String, dynamic> toRedactedMap() => {
    'id': id,
    'user_id': userId,
    'scope': scope.stableId,
    'local_period_start': localPeriodStart,
    'local_period_end': localPeriodEnd,
    'timezone_id': timezoneId,
    'state': state.stableId,
    'priority': priority.stableId,
    'confidence': confidence,
    'completeness': completeness?.stableId,
    'action': action,
    'explanation': explanation,
    'missing_inputs': missingInputs,
    'unavailable_reasons': unavailableReasons,
    'reason_codes': reasonCodes,
    'uncertainty': uncertainty,
    'alternatives': alternatives,
    'rule_version': ruleVersion,
    'calculation_version': calculationVersion,
    'algorithm_version': algorithmVersion,
    'model_version': modelVersion,
    'provider_version': providerVersion,
    'policy_version': policyVersion,
    'goal_version_id': goalVersionId,
    'readiness_snapshot_id': readinessSnapshotId,
    'context_fingerprint': contextFingerprint,
    'evidence_fingerprint': evidenceFingerprint,
    'exact_result_numerator': exactResultNumerator,
    'exact_result_denominator': exactResultDenominator,
    'normalized_maintenance_kcal': normalizedMaintenanceKcal,
    'proposed_delta_kcal': proposedDeltaKcal,
    'target_acceptance_state': targetAcceptanceState.stableId,
    'created_at_utc': createdAtUtc.toIso8601String(),
    'effective_at_utc': effectiveAtUtc?.toIso8601String(),
    'superseded_at_utc': supersededAtUtc?.toIso8601String(),
    'supersedes_recommendation_id': supersedesRecommendationId,
    'replay_hash': replayHash,
    'evidence': evidence.map((item) => item.toRedactedMap()).toList(),
    'feedback': feedback.map((item) => item.toRedactedMap()).toList(),
  };

  String? _sourceId(String kind) {
    for (final item in evidence) {
      if (item.evidenceKind == kind) return item.sourceId;
    }
    return null;
  }
}

bool _foldVisibility(List<B04RecommendationFeedbackRecord> events) {
  var visible = true;
  final ordered = [...events]
    ..sort((left, right) {
      final time = left.createdAtUtc.compareTo(right.createdAtUtc);
      if (time != 0) return time;
      return left.id.compareTo(right.id);
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
        // The v18 schema records the event but does not invent an expiry.
        // Presentation may apply a separately supplied snooze window.
        break;
    }
  }
  return visible;
}

class B04RecommendationHistoryError extends FormatException {
  final String code;

  const B04RecommendationHistoryError(this.code, String message)
    : super(message);
}
