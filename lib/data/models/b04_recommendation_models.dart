import '../services/b02_load_target_recommendation_service.dart';
import 'b04_adaptive_target_models.dart';
import 'b04_nutrition_safety_models.dart';
import 'b04_recommendation_context_models.dart';

/// Versioned contract owned by the B04 recommendation engine.
const String kB04RecommendationRuleVersion = 'B04-10-RECOMMENDATION-V1';
const String kB04RecommendationAlgorithmVersion = 'B04-10-PRIORITY-V1';
const String kB04RecommendationCopyVersion = 'B04-D04-13-COPY-V1';

enum B04RecommendationAction {
  training,
  nutritionTarget,
  nutritionMeal,
  education,
}

extension B04RecommendationActionId on B04RecommendationAction {
  String get stableId => switch (this) {
    B04RecommendationAction.training => 'training',
    B04RecommendationAction.nutritionTarget => 'nutrition_target',
    B04RecommendationAction.nutritionMeal => 'nutrition_meal',
    B04RecommendationAction.education => 'education',
  };

  bool get isNutrition =>
      this == B04RecommendationAction.nutritionTarget ||
      this == B04RecommendationAction.nutritionMeal;
}

enum B04RecommendationState {
  available,
  cautious,
  confirm,
  unavailable,
  dismissed,
  superseded,
}

extension B04RecommendationStateId on B04RecommendationState {
  String get stableId => name;
}

enum B04RecommendationPriority {
  safetyBlock,
  urgent,
  userSelected,
  training,
  nutrition,
  education,
}

extension B04RecommendationPriorityId on B04RecommendationPriority {
  String get stableId => switch (this) {
    B04RecommendationPriority.safetyBlock => 'safety_block',
    B04RecommendationPriority.urgent => 'urgent',
    B04RecommendationPriority.userSelected => 'user_selected',
    B04RecommendationPriority.training => 'training',
    B04RecommendationPriority.nutrition => 'nutrition',
    B04RecommendationPriority.education => 'education',
  };

  int get rank => switch (this) {
    B04RecommendationPriority.safetyBlock => 0,
    B04RecommendationPriority.urgent => 1,
    B04RecommendationPriority.userSelected => 2,
    B04RecommendationPriority.training => 3,
    B04RecommendationPriority.nutrition => 4,
    B04RecommendationPriority.education => 5,
  };
}

enum B04RecommendationEvidenceState {
  complete,
  partial,
  missing,
  unknown,
  invalid,
}

extension B04RecommendationEvidenceStateId on B04RecommendationEvidenceState {
  String get stableId => name;
}

enum B04RecommendationConfidence { high, medium, low, unknown }

extension B04RecommendationConfidenceId on B04RecommendationConfidence {
  String get stableId => name;
}

enum B04RecommendationCompleteness { complete, partial, missing, invalid }

extension B04RecommendationCompletenessId on B04RecommendationCompleteness {
  String get stableId => name;
}

enum B04RecommendationEligibilityState {
  eligible,
  underage,
  unknownAge,
  conflictingAge,
  withheldAge,
  invalidEvidence,
  policyUnavailable,
  missing,
}

extension B04RecommendationEligibilityStateId
    on B04RecommendationEligibilityState {
  String get stableId => switch (this) {
    B04RecommendationEligibilityState.eligible => 'eligible',
    B04RecommendationEligibilityState.underage => 'underage',
    B04RecommendationEligibilityState.unknownAge => 'unknown_age',
    B04RecommendationEligibilityState.conflictingAge => 'conflicting_age',
    B04RecommendationEligibilityState.withheldAge => 'withheld_age',
    B04RecommendationEligibilityState.invalidEvidence => 'invalid_evidence',
    B04RecommendationEligibilityState.policyUnavailable => 'policy_unavailable',
    B04RecommendationEligibilityState.missing => 'missing',
  };
}

enum B04RecommendationConsentState { enabled, disabled, missing }

extension B04RecommendationConsentStateId on B04RecommendationConsentState {
  String get stableId => name;
}

enum B04RecommendationPolicyState { hold, enabled, unavailable, missing }

extension B04RecommendationPolicyStateId on B04RecommendationPolicyState {
  String get stableId => name;
}

/// The engine never accepts a target. It reports the acceptance state that
/// belongs to the already-issued B04 target result.
enum B04RecommendationTargetAcceptanceState {
  notApplicable,
  unavailable,
  unchanged,
  proposalAvailable,
}

extension B04RecommendationTargetAcceptanceStateId
    on B04RecommendationTargetAcceptanceState {
  String get stableId => switch (this) {
    B04RecommendationTargetAcceptanceState.notApplicable => 'not_applicable',
    B04RecommendationTargetAcceptanceState.unavailable => 'unavailable',
    B04RecommendationTargetAcceptanceState.unchanged => 'unchanged',
    B04RecommendationTargetAcceptanceState.proposalAvailable =>
      'proposal_available',
  };
}

class B04RecommendationEvidence {
  final B04RecommendationEvidenceState state;
  final List<String> evidenceIds;
  final List<String> missingEvidence;
  final List<String> uncertaintyCodes;

  B04RecommendationEvidence({
    required this.state,
    Iterable<String> evidenceIds = const [],
    Iterable<String> missingEvidence = const [],
    Iterable<String> uncertaintyCodes = const [],
  }) : evidenceIds = _sortedUnique(evidenceIds),
       missingEvidence = _sortedUnique(missingEvidence),
       uncertaintyCodes = _sortedUnique(uncertaintyCodes) {
    if (this.evidenceIds.any((item) => item.trim().isEmpty) ||
        this.missingEvidence.any((item) => item.trim().isEmpty) ||
        this.uncertaintyCodes.any((item) => item.trim().isEmpty)) {
      throw ArgumentError(
        'Recommendation evidence identifiers cannot be blank.',
      );
    }
    if (state == B04RecommendationEvidenceState.complete &&
        (this.evidenceIds.isEmpty ||
            this.missingEvidence.isNotEmpty ||
            this.uncertaintyCodes.isNotEmpty)) {
      throw ArgumentError(
        'Complete recommendation evidence must be identified and certain.',
      );
    }
  }

  const B04RecommendationEvidence.missing({
    this.evidenceIds = const [],
    this.missingEvidence = const ['recommendation_evidence_missing'],
    this.uncertaintyCodes = const [],
  }) : state = B04RecommendationEvidenceState.missing;

  Map<String, dynamic> toRedactedMap() => {
    'state': state.stableId,
    'evidence_ids': evidenceIds,
    'missing_evidence': missingEvidence,
    'uncertainty_codes': uncertaintyCodes,
  };
}

/// A candidate is an immutable, already-evaluated action. The B04 engine
/// ranks it and carries its authorities; it does not calculate a new target,
/// evaluate a constraint, or invent evidence.
class B04RecommendationCandidate {
  final String id;
  final B04RecommendationAction action;
  final String rationaleCode;
  final B04RecommendationEvidence evidence;
  final bool urgent;
  final bool userSelected;
  final B04NutritionSafetyResult? nutritionSafety;
  final B02LoadTargetRecommendationResult? trainingRecommendation;

  B04RecommendationCandidate({
    required String id,
    required this.action,
    required String rationaleCode,
    required this.evidence,
    this.urgent = false,
    this.userSelected = false,
    this.nutritionSafety,
    this.trainingRecommendation,
  }) : id = id.trim(),
       rationaleCode = rationaleCode.trim() {
    if (this.id.isEmpty || this.rationaleCode.isEmpty) {
      throw ArgumentError(
        'Recommendation candidates require stable identity and rationale.',
      );
    }
    if (!action.isNutrition && nutritionSafety != null) {
      throw ArgumentError(
        'Dietary safety evidence is only valid for nutrition actions.',
      );
    }
  }

  Map<String, dynamic> toRedactedMap() => {
    'id': id,
    'action': action.stableId,
    'rationale_code': rationaleCode,
    'evidence': evidence.toRedactedMap(),
    'urgent': urgent,
    'user_selected': userSelected,
    if (nutritionSafety != null)
      'nutrition_safety': nutritionSafety!.toRedactedMap(),
    if (trainingRecommendation != null)
      'training_recommendation': trainingRecommendation!.recommendation
          .toJson(),
  };
}

class B04RecommendationWarning {
  final String candidateId;
  final String wording;
  final List<String> evidenceIds;
  final List<String> reasonCodes;

  B04RecommendationWarning({
    required String candidateId,
    required this.wording,
    Iterable<String> evidenceIds = const [],
    Iterable<String> reasonCodes = const [],
  }) : candidateId = candidateId.trim(),
       evidenceIds = _sortedUnique(evidenceIds),
       reasonCodes = _sortedUnique(reasonCodes) {
    if (this.candidateId.isEmpty || wording.trim().isEmpty) {
      throw ArgumentError('Recommendation warnings require identity and text.');
    }
  }

  Map<String, dynamic> toRedactedMap() => {
    'candidate_id': candidateId,
    'wording': wording,
    'evidence_ids': evidenceIds,
    'reason_codes': reasonCodes,
  };
}

class B04Recommendation {
  final String id;
  final B04RecommendationAction action;
  final B04RecommendationState state;
  final B04RecommendationPriority priority;
  final String rationaleCode;
  final String explanation;
  final B04RecommendationConfidence confidence;
  final B04RecommendationCompleteness completeness;
  final List<String> evidenceIds;
  final List<String> missingEvidence;
  final List<String> uncertaintyCodes;
  final List<String> unavailableReasons;
  final List<String> alternativeIds;
  final B04RecommendationEligibilityState eligibilityState;
  final B04RecommendationConsentState consentState;
  final B04RecommendationPolicyState policyState;
  final String policyVersion;
  final String ruleVersion;
  final String algorithmVersion;
  final String copyVersion;
  final B04RecommendationTargetAcceptanceState targetAcceptanceState;
  final B04AdaptiveTargetResult? canonicalAdaptiveTarget;
  final B02LoadTargetRecommendationResult? canonicalTrainingRecommendation;
  final B04NutritionSafetyDisposition? safetyDisposition;
  final List<String> safetyConstraintIds;
  final List<String> safetyNutrientRangeIds;

  B04Recommendation({
    required String id,
    required this.action,
    required this.state,
    required this.priority,
    required String rationaleCode,
    required String explanation,
    required this.confidence,
    required this.completeness,
    Iterable<String> evidenceIds = const [],
    Iterable<String> missingEvidence = const [],
    Iterable<String> uncertaintyCodes = const [],
    Iterable<String> unavailableReasons = const [],
    Iterable<String> alternativeIds = const [],
    required this.eligibilityState,
    required this.consentState,
    required this.policyState,
    required this.policyVersion,
    required this.ruleVersion,
    required this.algorithmVersion,
    required this.copyVersion,
    required this.targetAcceptanceState,
    required this.canonicalAdaptiveTarget,
    required this.canonicalTrainingRecommendation,
    required this.safetyDisposition,
    Iterable<String> safetyConstraintIds = const [],
    Iterable<String> safetyNutrientRangeIds = const [],
  }) : id = id.trim(),
       rationaleCode = rationaleCode.trim(),
       explanation = explanation.trim(),
       evidenceIds = _sortedUnique(evidenceIds),
       missingEvidence = _sortedUnique(missingEvidence),
       uncertaintyCodes = _sortedUnique(uncertaintyCodes),
       unavailableReasons = _sortedUnique(unavailableReasons),
       alternativeIds = _sortedUnique(alternativeIds),
       safetyConstraintIds = _sortedUnique(safetyConstraintIds),
       safetyNutrientRangeIds = _sortedUnique(safetyNutrientRangeIds) {
    if (this.id.isEmpty ||
        this.rationaleCode.isEmpty ||
        this.explanation.isEmpty) {
      throw ArgumentError(
        'Recommendations require identity, rationale, and explanation.',
      );
    }
    if (state == B04RecommendationState.unavailable &&
        unavailableReasons.isEmpty) {
      throw ArgumentError('Unavailable recommendations require a reason.');
    }
    if (state != B04RecommendationState.unavailable && evidenceIds.isEmpty) {
      throw ArgumentError(
        'Available recommendation states require evidence identifiers.',
      );
    }
  }

  B04Recommendation copyWithAlternatives(Iterable<String> values) =>
      B04Recommendation(
        id: id,
        action: action,
        state: state,
        priority: priority,
        rationaleCode: rationaleCode,
        explanation: explanation,
        confidence: confidence,
        completeness: completeness,
        evidenceIds: evidenceIds,
        missingEvidence: missingEvidence,
        uncertaintyCodes: uncertaintyCodes,
        unavailableReasons: unavailableReasons,
        alternativeIds: values,
        eligibilityState: eligibilityState,
        consentState: consentState,
        policyState: policyState,
        policyVersion: policyVersion,
        ruleVersion: ruleVersion,
        algorithmVersion: algorithmVersion,
        copyVersion: copyVersion,
        targetAcceptanceState: targetAcceptanceState,
        canonicalAdaptiveTarget: canonicalAdaptiveTarget,
        canonicalTrainingRecommendation: canonicalTrainingRecommendation,
        safetyDisposition: safetyDisposition,
        safetyConstraintIds: safetyConstraintIds,
        safetyNutrientRangeIds: safetyNutrientRangeIds,
      );

  Map<String, dynamic> toRedactedMap() => {
    'id': id,
    'action': action.stableId,
    'state': state.stableId,
    'priority': priority.stableId,
    'priority_rank': priority.rank,
    'rationale_code': rationaleCode,
    'explanation': explanation,
    'confidence': confidence.stableId,
    'completeness': completeness.stableId,
    'evidence_ids': evidenceIds,
    'missing_evidence': missingEvidence,
    'uncertainty_codes': uncertaintyCodes,
    'unavailable_reasons': unavailableReasons,
    'alternative_ids': alternativeIds,
    'eligibility_state': eligibilityState.stableId,
    'consent_state': consentState.stableId,
    'policy_state': policyState.stableId,
    'policy_version': policyVersion,
    'rule_version': ruleVersion,
    'algorithm_version': algorithmVersion,
    'copy_version': copyVersion,
    'target_acceptance_state': targetAcceptanceState.stableId,
    if (canonicalAdaptiveTarget != null)
      'canonical_adaptive_target': _adaptiveTargetMap(canonicalAdaptiveTarget!),
    if (canonicalTrainingRecommendation != null)
      'canonical_training_recommendation': {
        'disposition': canonicalTrainingRecommendation!.disposition.name,
        'recommendation': canonicalTrainingRecommendation!.recommendation
            .toJson(),
      },
    if (safetyDisposition != null)
      'safety_disposition': safetyDisposition!.stableId,
    'safety_constraint_ids': safetyConstraintIds,
    'safety_nutrient_range_ids': safetyNutrientRangeIds,
  };
}

class B04RecommendationEvaluation {
  final String contextId;
  final String userId;
  final B04RecommendationPeriod period;
  final String startLocalDate;
  final String endLocalDate;
  final String timezoneId;
  final DateTime evaluatedAtUtc;
  final B04RecommendationEligibilityState eligibilityState;
  final B04RecommendationConsentState consentState;
  final B04RecommendationPolicyState policyState;
  final String policyVersion;
  final String ruleVersion;
  final String algorithmVersion;
  final String copyVersion;
  final List<B04Recommendation> recommendations;
  final List<B04RecommendationWarning> lowRiskWarnings;
  final String fingerprint;

  B04RecommendationEvaluation({
    required String contextId,
    required String userId,
    required this.period,
    required this.startLocalDate,
    required this.endLocalDate,
    required this.timezoneId,
    required this.evaluatedAtUtc,
    required this.eligibilityState,
    required this.consentState,
    required this.policyState,
    required this.policyVersion,
    this.ruleVersion = kB04RecommendationRuleVersion,
    this.algorithmVersion = kB04RecommendationAlgorithmVersion,
    this.copyVersion = kB04RecommendationCopyVersion,
    required Iterable<B04Recommendation> recommendations,
    required Iterable<B04RecommendationWarning> lowRiskWarnings,
    required this.fingerprint,
  }) : contextId = contextId.trim(),
       userId = userId.trim(),
       recommendations = List.unmodifiable(recommendations),
       lowRiskWarnings = List.unmodifiable(lowRiskWarnings) {
    if (this.contextId.isEmpty ||
        this.userId.isEmpty ||
        timezoneId.trim().isEmpty) {
      throw ArgumentError(
        'Recommendation evaluations require context identity.',
      );
    }
    if (fingerprint.trim().isEmpty) {
      throw ArgumentError('Recommendation evaluations require a fingerprint.');
    }
  }

  List<B04Recommendation> get availableRecommendations => recommendations
      .where((item) => item.state != B04RecommendationState.unavailable)
      .toList(growable: false);

  Map<String, dynamic> toRedactedMap() => {
    'context_id': contextId,
    'period': period.stableId,
    'start_local_date': startLocalDate,
    'end_local_date': endLocalDate,
    'timezone_id': timezoneId,
    'evaluated_at_utc': evaluatedAtUtc.toIso8601String(),
    'eligibility_state': eligibilityState.stableId,
    'consent_state': consentState.stableId,
    'policy_state': policyState.stableId,
    'policy_version': policyVersion,
    'rule_version': ruleVersion,
    'algorithm_version': algorithmVersion,
    'copy_version': copyVersion,
    'recommendations': recommendations
        .map((item) => item.toRedactedMap())
        .toList(),
    'low_risk_warnings': lowRiskWarnings
        .map((item) => item.toRedactedMap())
        .toList(),
    'fingerprint': fingerprint,
  };
}

List<String> _sortedUnique(Iterable<String> values) {
  final result = values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();
  result.sort();
  return List.unmodifiable(result);
}

Map<String, dynamic> _adaptiveTargetMap(B04AdaptiveTargetResult result) => {
  'status': result.status.stableId,
  'reason_code': result.reasonCode,
  'policy_version': result.policyVersion,
  'calculation_version': result.calculationVersion,
  'algorithm_version': result.algorithmVersion,
  'direction': result.direction.stableId,
  'adaptive_delta_kcal': result.adaptiveDeltaKcal,
  if (result.currentTargetKcal != null)
    'current_target_kcal': result.currentTargetKcal,
  if (result.proposedTargetKcal != null)
    'proposed_target_kcal': result.proposedTargetKcal,
  if (result.normalizedMaintenanceKcal != null)
    'normalized_maintenance_kcal': result.normalizedMaintenanceKcal,
  if (result.medianWeightGrams != null)
    'median_weight_grams': result.medianWeightGrams!.toString(),
  if (result.slopeGramsPerDay != null)
    'slope_grams_per_day': result.slopeGramsPerDay!.toString(),
  if (result.weeklyRatePercent != null)
    'weekly_rate_percent': result.weeklyRatePercent!.toString(),
  if (result.displayWeeklyRatePercent != null)
    'display_weekly_rate_percent': result.displayWeeklyRatePercent,
  'evidence_ids': result.evidenceIds,
};
