import '../../core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';

enum NutritionGoalType { loss, maintenance, gain, custom }

enum NutritionGoalSource {
  userSet,
  calculated,
  adaptive,
  override,
  compatibility,
}

extension NutritionGoalTypeId on NutritionGoalType {
  String get stableId => switch (this) {
    NutritionGoalType.loss => 'loss',
    NutritionGoalType.maintenance => 'maintenance',
    NutritionGoalType.gain => 'gain',
    NutritionGoalType.custom => 'custom',
  };

  static NutritionGoalType parse(String value) => switch (value.trim()) {
    'loss' || 'lose' => NutritionGoalType.loss,
    'maintenance' || 'maintain' => NutritionGoalType.maintenance,
    'gain' => NutritionGoalType.gain,
    'custom' => NutritionGoalType.custom,
    _ => throw const B04GoalValidationError(
      'invalid_goal_type',
      'The nutrition goal type is not supported.',
    ),
  };
}

extension NutritionGoalSourceId on NutritionGoalSource {
  String get stableId => switch (this) {
    NutritionGoalSource.userSet => 'user_set',
    NutritionGoalSource.calculated => 'calculated',
    NutritionGoalSource.adaptive => 'adaptive',
    NutritionGoalSource.override => 'override',
    NutritionGoalSource.compatibility => 'compatibility',
  };
}

enum CoachingConsentCategory { adaptiveCoaching, optionalAi }

extension CoachingConsentCategoryId on CoachingConsentCategory {
  String get stableId => switch (this) {
    CoachingConsentCategory.adaptiveCoaching => 'adaptive_coaching',
    CoachingConsentCategory.optionalAi => 'optional_ai',
  };
}

enum CoachingConsentAction { enable, disable, withdraw }

extension CoachingConsentActionId on CoachingConsentAction {
  String get stableId => name;
}

enum CoachingEligibilityResult {
  eligible,
  underage,
  unknownAge,
  conflictingAge,
  withheldAge,
  invalidEvidence,
  policyUnavailable,
}

extension CoachingEligibilityResultId on CoachingEligibilityResult {
  String get stableId => switch (this) {
    CoachingEligibilityResult.eligible => 'eligible',
    CoachingEligibilityResult.underage => 'underage',
    CoachingEligibilityResult.unknownAge => 'unknown_age',
    CoachingEligibilityResult.conflictingAge => 'conflicting_age',
    CoachingEligibilityResult.withheldAge => 'withheld_age',
    CoachingEligibilityResult.invalidEvidence => 'invalid_evidence',
    CoachingEligibilityResult.policyUnavailable => 'policy_unavailable',
  };
}

class NutritionGoalVersionReadModel {
  final String id;
  final String userId;
  final int versionNumber;
  final NutritionGoalType goalType;
  final NutritionGoalSource source;
  final int? calorieTargetKcal;
  final double? proteinTargetG;
  final double? carbsTargetG;
  final double? fatTargetG;
  final String? policyVersion;
  final String? calculationVersion;
  final String? algorithmVersion;
  final String effectiveFromLocalDate;
  final String? effectiveToLocalDate;
  final String timezoneId;
  final String? supersedesGoalVersionId;
  final String? evidenceFingerprint;
  final String? exactResultNumerator;
  final String? exactResultDenominator;
  final int? normalizedMaintenanceKcal;
  final DateTime createdAtUtc;

  const NutritionGoalVersionReadModel({
    required this.id,
    required this.userId,
    required this.versionNumber,
    required this.goalType,
    required this.source,
    required this.calorieTargetKcal,
    required this.proteinTargetG,
    required this.carbsTargetG,
    required this.fatTargetG,
    required this.policyVersion,
    required this.calculationVersion,
    required this.algorithmVersion,
    required this.effectiveFromLocalDate,
    required this.effectiveToLocalDate,
    required this.timezoneId,
    required this.supersedesGoalVersionId,
    required this.evidenceFingerprint,
    required this.exactResultNumerator,
    required this.exactResultDenominator,
    required this.normalizedMaintenanceKcal,
    required this.createdAtUtc,
  });

  bool get isUserSet =>
      source == NutritionGoalSource.userSet ||
      source == NutritionGoalSource.override ||
      source == NutritionGoalSource.compatibility;
}

class NutritionGoalCommand {
  final String userId;
  final NutritionGoalType goalType;
  final NutritionGoalSource source;
  final int? calorieTargetKcal;
  final double? proteinTargetG;
  final double? carbsTargetG;
  final double? fatTargetG;
  final String effectiveFromLocalDate;
  final String timezoneId;
  final String? effectiveToLocalDate;
  final String? commandId;
  final String? id;

  const NutritionGoalCommand({
    required this.userId,
    required this.goalType,
    this.source = NutritionGoalSource.userSet,
    this.calorieTargetKcal,
    this.proteinTargetG,
    this.carbsTargetG,
    this.fatTargetG,
    required this.effectiveFromLocalDate,
    required this.timezoneId,
    this.effectiveToLocalDate,
    this.commandId,
    this.id,
  });
}

/// A read-only result from the canonical policy/target engine. B04-05 stores
/// its exact metadata but never calculates or rounds it.
class AdaptiveGoalProposal {
  final String id;
  final String userId;
  final NutritionGoalType goalType;
  final String goalRate;
  final int calorieTargetKcal;
  final double? proteinTargetG;
  final double? carbsTargetG;
  final double? fatTargetG;
  final String policyVersion;
  final String? calculationVersion;
  final String? algorithmVersion;
  final String effectiveFromLocalDate;
  final String timezoneId;
  final String? evidenceFingerprint;
  final String? exactResultNumerator;
  final String? exactResultDenominator;
  final int normalizedMaintenanceKcal;

  const AdaptiveGoalProposal({
    required this.id,
    required this.userId,
    required this.goalType,
    required this.goalRate,
    required this.calorieTargetKcal,
    this.proteinTargetG,
    this.carbsTargetG,
    this.fatTargetG,
    required this.policyVersion,
    this.calculationVersion,
    this.algorithmVersion,
    required this.effectiveFromLocalDate,
    required this.timezoneId,
    this.evidenceFingerprint,
    this.exactResultNumerator,
    this.exactResultDenominator,
    required this.normalizedMaintenanceKcal,
  });

  void validate() {
    if (id.trim().isEmpty || userId.trim().isEmpty) {
      throw const B04GoalValidationError(
        'missing_proposal_identity',
        'An adaptive proposal requires a portable ID and owner.',
      );
    }
    if (policyVersion != kB04EnabledPolicyVersion) {
      throw const B04GoalValidationError(
        'adaptive_policy_not_enabled',
        'Only an explicitly enabled canonical policy result can be accepted.',
      );
    }
    final policy = B04EnabledPolicyContract.current;
    final rate = '${goalType.stableId}:$goalRate';
    if (!policy.supportedGoalRates.contains(rate)) {
      throw const B04GoalValidationError(
        'unsupported_goal_rate',
        'The requested adaptive goal rate is not supported by the canonical policy.',
      );
    }
    if (normalizedMaintenanceKcal <= 0 || calorieTargetKcal <= 0) {
      throw const B04GoalValidationError(
        'invalid_policy_result',
        'Canonical maintenance and target values must be positive.',
      );
    }
    if ((exactResultNumerator == null) != (exactResultDenominator == null) ||
        exactResultDenominator == '0') {
      throw const B04GoalValidationError(
        'invalid_exact_result',
        'Exact policy results require a non-zero numerator and denominator.',
      );
    }
    if (exactResultNumerator != null) {
      try {
        BigInt.parse(exactResultNumerator!);
        BigInt.parse(exactResultDenominator!);
      } on FormatException {
        throw const B04GoalValidationError(
          'invalid_exact_result',
          'Exact policy results must use canonical integer strings.',
        );
      }
    }
  }
}

class CoachingConsentEventReadModel {
  final String id;
  final String userId;
  final CoachingConsentCategory category;
  final CoachingConsentAction action;
  final String consentPolicyVersion;
  final String copyVersion;
  final DateTime timestampUtc;
  final String localDate;
  final String timezoneId;
  final String actorSource;
  final String? relatedOrSupersededEventId;

  const CoachingConsentEventReadModel({
    required this.id,
    required this.userId,
    required this.category,
    required this.action,
    required this.consentPolicyVersion,
    required this.copyVersion,
    required this.timestampUtc,
    required this.localDate,
    required this.timezoneId,
    required this.actorSource,
    required this.relatedOrSupersededEventId,
  });
}

class CoachingConsentCommand {
  final String userId;
  final CoachingConsentCategory category;
  final CoachingConsentAction action;
  final String consentPolicyVersion;
  final String copyVersion;
  final DateTime timestampUtc;
  final String localDate;
  final String timezoneId;
  final String actorSource;
  final String? eventId;
  final String? relatedOrSupersededEventId;

  const CoachingConsentCommand({
    required this.userId,
    required this.category,
    required this.action,
    required this.consentPolicyVersion,
    required this.copyVersion,
    required this.timestampUtc,
    required this.localDate,
    required this.timezoneId,
    required this.actorSource,
    this.eventId,
    this.relatedOrSupersededEventId,
  });
}

class CoachingPreferencesReadModel {
  final String userId;
  final bool adaptiveCoachingEnabled;
  final bool optionalAiEnabled;
  final CoachingConsentEventReadModel? adaptiveCoachingEvent;
  final CoachingConsentEventReadModel? optionalAiEvent;

  const CoachingPreferencesReadModel({
    required this.userId,
    required this.adaptiveCoachingEnabled,
    required this.optionalAiEnabled,
    required this.adaptiveCoachingEvent,
    required this.optionalAiEvent,
  });
}

class CoachingEligibilityReadModel {
  final String userId;
  final CoachingEligibilityResult result;
  final String reasonCode;
  final String policyVersion;
  final String evaluationLocalDate;
  final String timezoneId;
  final DateTime evaluationUtc;

  const CoachingEligibilityReadModel({
    required this.userId,
    required this.result,
    required this.reasonCode,
    required this.policyVersion,
    required this.evaluationLocalDate,
    required this.timezoneId,
    required this.evaluationUtc,
  });

  bool get isEligible => result == CoachingEligibilityResult.eligible;
}

class CoachingAvailabilityReadModel {
  final bool available;
  final String reasonCode;
  final CoachingEligibilityReadModel? eligibility;
  final CoachingPreferencesReadModel preferences;

  const CoachingAvailabilityReadModel({
    required this.available,
    required this.reasonCode,
    required this.eligibility,
    required this.preferences,
  });
}

class GoalEvaluationWindowReadModel {
  final String? activeGoalVersionId;
  final String? resetReason;
  final String? activeGoalEffectiveFromLocalDate;
  final String? earliestEvaluationLocalDate;
  final int requiredNewCompletedDays;

  const GoalEvaluationWindowReadModel({
    required this.activeGoalVersionId,
    required this.resetReason,
    required this.activeGoalEffectiveFromLocalDate,
    required this.earliestEvaluationLocalDate,
    this.requiredNewCompletedDays = 21,
  });

  bool isReadyOn(String localDate) =>
      earliestEvaluationLocalDate != null &&
      localDate.compareTo(earliestEvaluationLocalDate!) >= 0;
}

class B04GoalValidationError implements Exception {
  final String code;
  final String message;

  const B04GoalValidationError(this.code, this.message);

  @override
  String toString() => 'B04GoalValidationError($code): $message';
}

class B04GoalConflictError extends B04GoalValidationError {
  const B04GoalConflictError(super.code, super.message);
}
