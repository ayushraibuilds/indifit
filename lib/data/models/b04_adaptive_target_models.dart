import '../../core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../services/b02_load_target_recommendation_service.dart';
import 'b04_goal_models.dart';
import 'b04_recovery_models.dart';

/// Exact rational used by the B04-07 production rule.
///
/// The contract deliberately does not use doubles for a policy decision. This
/// type is separate from the B04 fixture rational so fixtures cannot become a
/// runtime calculation authority by accident.
class B04ExactRational implements Comparable<B04ExactRational> {
  final BigInt numerator;
  final BigInt denominator;

  factory B04ExactRational(BigInt numerator, [BigInt? denominator]) {
    final rawDenominator = denominator ?? BigInt.one;
    if (rawDenominator == BigInt.zero) {
      throw ArgumentError.value(denominator, 'denominator', 'must be non-zero');
    }
    final sign = rawDenominator.isNegative ? -BigInt.one : BigInt.one;
    final positiveDenominator = rawDenominator * sign;
    final positiveNumerator = numerator * sign;
    final divisor = _gcd(positiveNumerator.abs(), positiveDenominator);
    return B04ExactRational._(
      positiveNumerator ~/ divisor,
      positiveDenominator ~/ divisor,
    );
  }

  B04ExactRational._(this.numerator, this.denominator);

  factory B04ExactRational.fromInt(int value) =>
      B04ExactRational(BigInt.from(value));

  factory B04ExactRational.parse(String value) {
    final trimmed = value.trim();
    if (!RegExp(r'^[+-]?\d+(?:\.\d+)?$').hasMatch(trimmed)) {
      throw const FormatException('Value is not a finite decimal.');
    }
    final negative = trimmed.startsWith('-');
    final unsigned = trimmed.startsWith('-') || trimmed.startsWith('+')
        ? trimmed.substring(1)
        : trimmed;
    final parts = unsigned.split('.');
    final fraction = parts.length == 2 ? parts[1] : '';
    final scale = fraction.isEmpty
        ? BigInt.one
        : BigInt.from(10).pow(fraction.length);
    final whole = BigInt.parse(parts.first);
    final fractional = fraction.isEmpty ? BigInt.zero : BigInt.parse(fraction);
    final raw = whole * scale + fractional;
    return B04ExactRational(negative ? -raw : raw, scale);
  }

  B04ExactRational operator +(B04ExactRational other) => B04ExactRational(
    numerator * other.denominator + other.numerator * denominator,
    denominator * other.denominator,
  );

  B04ExactRational operator -(B04ExactRational other) => B04ExactRational(
    numerator * other.denominator - other.numerator * denominator,
    denominator * other.denominator,
  );

  B04ExactRational operator -() => B04ExactRational(-numerator, denominator);

  B04ExactRational operator *(B04ExactRational other) => B04ExactRational(
    numerator * other.numerator,
    denominator * other.denominator,
  );

  B04ExactRational operator /(B04ExactRational other) {
    if (other.numerator == BigInt.zero) {
      throw ArgumentError('Cannot divide by zero.');
    }
    return B04ExactRational(
      numerator * other.denominator,
      denominator * other.numerator,
    );
  }

  bool get isZero => numerator == BigInt.zero;
  bool get isNegative => numerator.isNegative;
  bool get isInteger => denominator == BigInt.one;

  BigInt floorInteger() {
    if (!numerator.isNegative) return numerator ~/ denominator;
    return -((-numerator + denominator - BigInt.one) ~/ denominator);
  }

  BigInt ceilInteger() {
    if (numerator.isNegative) return -((-numerator) ~/ denominator);
    return (numerator + denominator - BigInt.one) ~/ denominator;
  }

  BigInt roundAwayFromZero() {
    final absolute = numerator.abs();
    final quotient = absolute ~/ denominator;
    final remainder = absolute % denominator;
    final rounded = remainder * BigInt.from(2) >= denominator
        ? quotient + BigInt.one
        : quotient;
    return numerator.isNegative ? -rounded : rounded;
  }

  int toIntExact() {
    if (!isInteger) throw StateError('Rational is not an integer.');
    return numerator.toInt();
  }

  /// Conversion is only for presentation; policy comparisons never use it.
  double toDouble() => numerator.toDouble() / denominator.toDouble();

  /// [this] is a percentage-point value, e.g. `0.125` becomes `0.13`.
  String displayPercent() {
    final scaled = this * B04ExactRational.fromInt(100);
    final rounded = scaled.roundAwayFromZero();
    final negative = rounded.isNegative;
    final absolute = rounded.abs().toString().padLeft(3, '0');
    final whole = absolute.substring(0, absolute.length - 2);
    final fraction = absolute.substring(absolute.length - 2);
    return '${negative ? '-' : ''}$whole.$fraction';
  }

  @override
  int compareTo(B04ExactRational other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);

  bool operator <(B04ExactRational other) => compareTo(other) < 0;
  bool operator <=(B04ExactRational other) => compareTo(other) <= 0;
  bool operator >(B04ExactRational other) => compareTo(other) > 0;
  bool operator >=(B04ExactRational other) => compareTo(other) >= 0;

  String get canonical => '$numerator/$denominator';

  @override
  bool operator ==(Object other) =>
      other is B04ExactRational && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => canonical;
}

BigInt _gcd(BigInt left, BigInt right) {
  var a = left;
  var b = right;
  while (b != BigInt.zero) {
    final remainder = a % b;
    a = b;
    b = remainder;
  }
  return a == BigInt.zero ? BigInt.one : a;
}

enum B04AdaptiveTargetStatus {
  available,
  onTrack,
  unavailable,
  invalidEvidence,
  policyBoundaryReached,
  rapidChangeReview,
  expired,
  inactive,
}

extension B04AdaptiveTargetStatusId on B04AdaptiveTargetStatus {
  String get stableId => switch (this) {
    B04AdaptiveTargetStatus.available => 'available',
    B04AdaptiveTargetStatus.onTrack => 'on_track',
    B04AdaptiveTargetStatus.unavailable => 'unavailable',
    B04AdaptiveTargetStatus.invalidEvidence => 'invalid_evidence',
    B04AdaptiveTargetStatus.policyBoundaryReached => 'policy_boundary_reached',
    B04AdaptiveTargetStatus.rapidChangeReview => 'rapid_change_review',
    B04AdaptiveTargetStatus.expired => 'expired',
    B04AdaptiveTargetStatus.inactive => 'inactive',
  };
}

enum B04AdaptiveTargetDirection { increaseCalories, decreaseCalories, onTrack }

extension B04AdaptiveTargetDirectionId on B04AdaptiveTargetDirection {
  String get stableId => switch (this) {
    B04AdaptiveTargetDirection.increaseCalories => 'increase_calories',
    B04AdaptiveTargetDirection.decreaseCalories => 'decrease_calories',
    B04AdaptiveTargetDirection.onTrack => 'on_track',
  };
}

enum B04EvidenceState {
  known,
  estimated,
  missing,
  unknown,
  invalid,
  stale,
  conflicting,
}

extension B04EvidenceStateId on B04EvidenceState {
  String get stableId => name;
}

enum B04AdaptiveProposalState {
  pending,
  accepted,
  rejected,
  dismissed,
  expired,
}

extension B04AdaptiveProposalStateId on B04AdaptiveProposalState {
  String get stableId => name;
}

enum B04SafetyState {
  clear,
  possible,
  unknown,
  insufficient,
  confirmedConflict,
  invalid,
}

extension B04SafetyStateId on B04SafetyState {
  String get stableId => switch (this) {
    B04SafetyState.clear => 'clear',
    B04SafetyState.possible => 'possible',
    B04SafetyState.unknown => 'unknown',
    B04SafetyState.insufficient => 'insufficient',
    B04SafetyState.confirmedConflict => 'confirmed_conflict',
    B04SafetyState.invalid => 'invalid',
  };
}

/// Production copy of the approved numerical rule contract. The fixture
/// matrix is used to verify these values, but the engine owns its own rule
/// object so fixture arithmetic is never imported into the production path.
class B04AdaptiveTargetPolicy {
  final String policyVersion;
  final String calculationVersion;
  final String algorithmVersion;
  final int evaluationWindowDays;
  final int minimumValidWeightDays;
  final int minimumWeightSpanDays;
  final int minimumBlockWeightDays;
  final int latestWeightFreshnessDays;
  final int minimumNutritionValidDays;
  final String nutritionCompletenessPercent;
  final String nutritionMaximumRangePercent;
  final int maintenanceFreshnessDays;
  final String maintenanceMaximumRangePercent;
  final List<String> supportedGoalRates;
  final String lossGainDeadbandPercent;
  final String maintenanceDeadbandPercent;
  final String lossRapidChangePercent;
  final String gainRapidChangePercent;
  final int proposalStepKcal;
  final int proposalCadenceDays;
  final int proposalExpiryDays;
  final int aggregateWindowDays;
  final int aggregateMinimumKcal;
  final int aggregateMaximumKcal;
  final int lossMaximumDeficitKcal;
  final String lossMaximumDeficitPercent;
  final int lossMinimumFloorKcal;
  final String lossMinimumFloorPercent;
  final int gainMaximumSurplusKcal;
  final String gainMaximumSurplusPercent;

  const B04AdaptiveTargetPolicy({
    required this.policyVersion,
    required this.calculationVersion,
    required this.algorithmVersion,
    required this.evaluationWindowDays,
    required this.minimumValidWeightDays,
    required this.minimumWeightSpanDays,
    required this.minimumBlockWeightDays,
    required this.latestWeightFreshnessDays,
    required this.minimumNutritionValidDays,
    required this.nutritionCompletenessPercent,
    required this.nutritionMaximumRangePercent,
    required this.maintenanceFreshnessDays,
    required this.maintenanceMaximumRangePercent,
    required this.supportedGoalRates,
    required this.lossGainDeadbandPercent,
    required this.maintenanceDeadbandPercent,
    required this.lossRapidChangePercent,
    required this.gainRapidChangePercent,
    required this.proposalStepKcal,
    required this.proposalCadenceDays,
    required this.proposalExpiryDays,
    required this.aggregateWindowDays,
    required this.aggregateMinimumKcal,
    required this.aggregateMaximumKcal,
    required this.lossMaximumDeficitKcal,
    required this.lossMaximumDeficitPercent,
    required this.lossMinimumFloorKcal,
    required this.lossMinimumFloorPercent,
    required this.gainMaximumSurplusKcal,
    required this.gainMaximumSurplusPercent,
  });

  static const current = B04AdaptiveTargetPolicy(
    policyVersion: kB04EnabledPolicyVersion,
    calculationVersion: 'B04-07-TARGET-V1',
    algorithmVersion: kB04TrendAlgorithmVersion,
    evaluationWindowDays: 21,
    minimumValidWeightDays: 10,
    minimumWeightSpanDays: 14,
    minimumBlockWeightDays: 3,
    latestWeightFreshnessDays: 4,
    minimumNutritionValidDays: 14,
    nutritionCompletenessPercent: '80',
    nutritionMaximumRangePercent: '20',
    maintenanceFreshnessDays: 30,
    maintenanceMaximumRangePercent: '15',
    supportedGoalRates: [
      'loss:-0.25% body weight/week',
      'loss:-0.50% body weight/week',
      'maintenance:0.00% body weight/week',
      'gain:+0.10% body weight/week',
      'gain:+0.25% body weight/week',
    ],
    lossGainDeadbandPercent: '0.15',
    maintenanceDeadbandPercent: '0.25',
    lossRapidChangePercent: '-1.00',
    gainRapidChangePercent: '+0.50',
    proposalStepKcal: 100,
    proposalCadenceDays: 21,
    proposalExpiryDays: 7,
    aggregateWindowDays: 42,
    aggregateMinimumKcal: -200,
    aggregateMaximumKcal: 200,
    lossMaximumDeficitKcal: 500,
    lossMaximumDeficitPercent: '20',
    lossMinimumFloorKcal: 1200,
    lossMinimumFloorPercent: '80',
    gainMaximumSurplusKcal: 300,
    gainMaximumSurplusPercent: '15',
  );

  B04ExactRational get nutritionCompleteness =>
      B04ExactRational.parse(nutritionCompletenessPercent);
  B04ExactRational get nutritionMaximumRange =>
      B04ExactRational.parse(nutritionMaximumRangePercent);
  B04ExactRational get maintenanceMaximumRange =>
      B04ExactRational.parse(maintenanceMaximumRangePercent);
  B04ExactRational get lossGainDeadband =>
      B04ExactRational.parse(lossGainDeadbandPercent);
  B04ExactRational get maintenanceDeadband =>
      B04ExactRational.parse(maintenanceDeadbandPercent);
  B04ExactRational get lossRapidChange =>
      B04ExactRational.parse(lossRapidChangePercent);
  B04ExactRational get gainRapidChange =>
      B04ExactRational.parse(gainRapidChangePercent);
  B04ExactRational get lossMaximumDeficit =>
      B04ExactRational.parse(lossMaximumDeficitPercent);
  B04ExactRational get lossMinimumFloor =>
      B04ExactRational.parse(lossMinimumFloorPercent);
  B04ExactRational get gainMaximumSurplus =>
      B04ExactRational.parse(gainMaximumSurplusPercent);
}

/// The four independent conditions required to select ENABLED-1. The default
/// object intentionally represents current HOLD-1 behavior.
class B04ActivationMetadata {
  final String policyVersion;
  final bool productOwnerApproved;
  final bool freshIndependentSolApproved;
  final bool policyBranchMerged;
  final bool releasePolicySelected;
  final String? effectiveFromLocalDate;
  final String? timezoneId;
  final String? scopeUserId;
  final String? mergedBranch;
  final String? releaseSelection;

  const B04ActivationMetadata({
    this.policyVersion = kB04HoldPolicyVersion,
    this.productOwnerApproved = false,
    this.freshIndependentSolApproved = false,
    this.policyBranchMerged = false,
    this.releasePolicySelected = false,
    this.effectiveFromLocalDate,
    this.timezoneId,
    this.scopeUserId,
    this.mergedBranch,
    this.releaseSelection,
  });

  const B04ActivationMetadata.enabled({
    required String effectiveFromLocalDate,
    required String timezoneId,
    String? scopeUserId,
    String? mergedBranch,
    String? releaseSelection,
  }) : this(
         policyVersion: kB04EnabledPolicyVersion,
         productOwnerApproved: true,
         freshIndependentSolApproved: true,
         policyBranchMerged: true,
         releasePolicySelected: true,
         effectiveFromLocalDate: effectiveFromLocalDate,
         timezoneId: timezoneId,
         scopeUserId: scopeUserId,
         mergedBranch: mergedBranch,
         releaseSelection: releaseSelection,
       );

  bool get hasAllActivationGates =>
      policyVersion == kB04EnabledPolicyVersion &&
      productOwnerApproved &&
      freshIndependentSolApproved &&
      policyBranchMerged &&
      releasePolicySelected &&
      effectiveFromLocalDate != null &&
      timezoneId != null &&
      mergedBranch?.trim().isNotEmpty == true &&
      releaseSelection?.trim().isNotEmpty == true;

  bool isActiveFor({
    required String userId,
    required String localDate,
    required String timezoneId,
    required LocalScheduleDateService dates,
  }) {
    if (!hasAllActivationGates || this.timezoneId != timezoneId) return false;
    if (scopeUserId != null && scopeUserId != userId) return false;
    try {
      final effective = dates.normalizeLocalDate(effectiveFromLocalDate!);
      return dates.compare(localDate, effective) >= 0;
    } on Object {
      return false;
    }
  }
}

class B04BodyMetricsEvidence {
  final String id;
  final String userId;
  final String heightCm;
  final String weightGrams;
  final String heightUnit;
  final String weightUnit;
  final B04EvidenceState state;
  final String sourceId;
  final String sourceVersion;
  final String localDate;
  final String timezoneId;
  final DateTime observedAtUtc;

  const B04BodyMetricsEvidence({
    required this.id,
    required this.userId,
    required this.heightCm,
    required this.weightGrams,
    this.heightUnit = 'cm',
    this.weightUnit = 'g',
    this.state = B04EvidenceState.known,
    required this.sourceId,
    required this.sourceVersion,
    required this.localDate,
    required this.timezoneId,
    required this.observedAtUtc,
  });
}

class B04WeightObservation {
  final String id;
  final String userId;
  final String localDate;
  final String timezoneId;
  final String grams;
  final String unit;
  final B04EvidenceState state;
  final String sourceId;
  final String sourceVersion;
  final DateTime observedAtUtc;
  final String? supersedesObservationId;

  const B04WeightObservation({
    required this.id,
    required this.userId,
    required this.localDate,
    required this.timezoneId,
    required this.grams,
    this.unit = 'g',
    this.state = B04EvidenceState.known,
    required this.sourceId,
    required this.sourceVersion,
    required this.observedAtUtc,
    this.supersedesObservationId,
  });
}

class B04NumericRangeEvidence {
  final String? point;
  final String? lower;
  final String? upper;
  final String unit;
  final String? lowerUnit;
  final String? upperUnit;
  final B04EvidenceState state;
  final bool stale;
  final bool conflicting;
  final String? actionAtLower;
  final String? actionAtUpper;

  const B04NumericRangeEvidence({
    this.point,
    this.lower,
    this.upper,
    required this.unit,
    this.lowerUnit,
    this.upperUnit,
    this.state = B04EvidenceState.known,
    this.stale = false,
    this.conflicting = false,
    this.actionAtLower,
    this.actionAtUpper,
  });
}

class B04NutritionDayEvidence {
  final String id;
  final String userId;
  final String localDate;
  final String timezoneId;
  final B04NumericRangeEvidence energy;
  final String completenessPercent;
  final String sourceId;
  final String sourceVersion;
  final bool historicalSnapshot;
  final DateTime observedAtUtc;
  final String? supersedesEvidenceId;

  const B04NutritionDayEvidence({
    required this.id,
    required this.userId,
    required this.localDate,
    required this.timezoneId,
    required this.energy,
    required this.completenessPercent,
    required this.sourceId,
    required this.sourceVersion,
    required this.historicalSnapshot,
    required this.observedAtUtc,
    this.supersedesEvidenceId,
  });
}

class B04MaintenanceEnergyEvidence {
  final String id;
  final String userId;
  final String localDate;
  final String timezoneId;
  final B04NumericRangeEvidence energy;
  final String sourceId;
  final String sourceVersion;
  final String policyVersion;
  final bool historicalSnapshot;
  final DateTime observedAtUtc;
  final String? supersedesEvidenceId;

  const B04MaintenanceEnergyEvidence({
    required this.id,
    required this.userId,
    required this.localDate,
    required this.timezoneId,
    required this.energy,
    required this.sourceId,
    required this.sourceVersion,
    required this.policyVersion,
    required this.historicalSnapshot,
    required this.observedAtUtc,
    this.supersedesEvidenceId,
  });
}

class B04AdaptiveTargetHistoryEvent {
  final String id;
  final String userId;
  final String localDate;
  final String timezoneId;
  final int deltaKcal;
  final bool engineAuthored;
  final bool accepted;
  final B04AdaptiveProposalState state;
  final String policyVersion;
  final String? proposalId;
  final String? supersedesEventId;

  const B04AdaptiveTargetHistoryEvent({
    required this.id,
    required this.userId,
    required this.localDate,
    required this.timezoneId,
    required this.deltaKcal,
    required this.engineAuthored,
    required this.accepted,
    required this.state,
    required this.policyVersion,
    this.proposalId,
    this.supersedesEventId,
  });
}

class B04SafetyInput {
  final B04SafetyState state;
  final bool pregnancyOrBreastfeeding;
  final bool clinicianManagedPlan;
  final bool eatingDisorderRestriction;

  const B04SafetyInput({
    this.state = B04SafetyState.clear,
    this.pregnancyOrBreastfeeding = false,
    this.clinicianManagedPlan = false,
    this.eatingDisorderRestriction = false,
  });
}

class B04AdaptiveTargetRequest {
  final String evaluationId;
  final String userId;
  final String evaluationLocalDate;
  final String timezoneId;
  final DateTime evaluatedAtUtc;
  final bool explicitlyInitiated;
  final bool adaptiveConsentEnabled;
  final bool offline;
  final bool userOverrideRequested;
  final int? aiSuggestedDeltaKcal;
  final String? storedPolicyVersion;
  final B04ActivationMetadata activation;
  final CoachingEligibilityReadModel? eligibility;
  final NutritionGoalVersionReadModel? activeGoal;
  final String? goalRate;
  final B04BodyMetricsEvidence? bodyMetrics;
  final List<B04WeightObservation> weightObservations;
  final List<B04NutritionDayEvidence> nutritionDays;
  final B04MaintenanceEnergyEvidence? maintenanceEvidence;
  final List<B04AdaptiveTargetHistoryEvent> history;
  final B04SafetyInput safety;

  B04AdaptiveTargetRequest({
    required this.evaluationId,
    required this.userId,
    required this.evaluationLocalDate,
    required this.timezoneId,
    required this.evaluatedAtUtc,
    this.explicitlyInitiated = false,
    this.adaptiveConsentEnabled = false,
    this.offline = false,
    this.userOverrideRequested = false,
    this.aiSuggestedDeltaKcal,
    this.storedPolicyVersion,
    this.activation = const B04ActivationMetadata(),
    required this.eligibility,
    required this.activeGoal,
    required this.goalRate,
    required this.bodyMetrics,
    List<B04WeightObservation> weightObservations = const [],
    List<B04NutritionDayEvidence> nutritionDays = const [],
    required this.maintenanceEvidence,
    List<B04AdaptiveTargetHistoryEvent> history = const [],
    this.safety = const B04SafetyInput(),
  }) : weightObservations = List.unmodifiable(weightObservations),
       nutritionDays = List.unmodifiable(nutritionDays),
       history = List.unmodifiable(history);
}

class B04TrainingOverlayResult {
  final String policyVersion;
  final String status;
  final String reasonCode;
  final ReadinessSnapshotReadModel? readinessSnapshot;
  final B02LoadTargetRecommendationResult? baseB02Recommendation;
  final int calorieDeltaKcal;
  final int trainingLoadDeltaPercent;
  final int trainingIntensityDeltaPercent;
  final int scheduleDurationDelta;
  final bool numericalProposalAllowed;
  final bool descriptiveCoachingAllowed;

  const B04TrainingOverlayResult({
    required this.policyVersion,
    required this.status,
    required this.reasonCode,
    required this.readinessSnapshot,
    required this.baseB02Recommendation,
    required this.calorieDeltaKcal,
    required this.trainingLoadDeltaPercent,
    required this.trainingIntensityDeltaPercent,
    required this.scheduleDurationDelta,
    required this.numericalProposalAllowed,
    required this.descriptiveCoachingAllowed,
  });

  static const unavailable = B04TrainingOverlayResult(
    policyVersion: kB04ReadinessHoldPolicyVersion,
    status: 'unavailable',
    reasonCode: 'readiness_unavailable',
    readinessSnapshot: null,
    baseB02Recommendation: null,
    calorieDeltaKcal: 0,
    trainingLoadDeltaPercent: 0,
    trainingIntensityDeltaPercent: 0,
    scheduleDurationDelta: 0,
    numericalProposalAllowed: false,
    descriptiveCoachingAllowed: false,
  );
}

class B04AdaptiveTargetResult {
  final B04AdaptiveTargetStatus status;
  final String reasonCode;
  final String policyVersion;
  final String calculationVersion;
  final String algorithmVersion;
  final B04AdaptiveTargetDirection direction;
  final int adaptiveDeltaKcal;
  final int? currentTargetKcal;
  final int? proposedTargetKcal;
  final int? normalizedMaintenanceKcal;
  final B04ExactRational? medianWeightGrams;
  final B04ExactRational? slopeGramsPerDay;
  final B04ExactRational? weeklyRatePercent;
  final String? displayWeeklyRatePercent;
  final List<String> evidenceIds;
  final AdaptiveGoalProposal? proposal;
  final B04TrainingOverlayResult trainingOverlay;

  B04AdaptiveTargetResult({
    required this.status,
    required this.reasonCode,
    required this.policyVersion,
    required this.calculationVersion,
    required this.algorithmVersion,
    required this.direction,
    required this.adaptiveDeltaKcal,
    required this.currentTargetKcal,
    required this.proposedTargetKcal,
    required this.normalizedMaintenanceKcal,
    required this.medianWeightGrams,
    required this.slopeGramsPerDay,
    required this.weeklyRatePercent,
    required this.displayWeeklyRatePercent,
    required List<String> evidenceIds,
    required this.proposal,
    required this.trainingOverlay,
  }) : evidenceIds = List.unmodifiable(evidenceIds);

  bool get hasProposal => proposal != null;
}
