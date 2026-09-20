import 'b04_adaptive_target_models.dart';

/// Hyperparameters for the on-device Adaptive TDEE Expenditure Engine.
///
/// Pinned under a versioned policy identifier so future algorithm adjustments
/// do not silently rewrite historical evaluations.
class AdaptiveTdeePolicy {
  final String policyVersion;
  final double alphaWeight;
  final double betaTdee;
  final double maxDailyDeltaKcal;
  final double tissueKcalPerKg;
  final int warmupDays;
  final int windowDays;
  final int minFoodDaysModerate;
  final int minWeightDaysModerate;
  final int minFoodDaysHigh;
  final int minWeightDaysHigh;
  final double bmrFloorMultiplier;
  final double bmrCeilingMultiplier;
  final double absoluteFloorKcal;
  final double absoluteCeilingKcal;
  final int maxHistoryDays;

  const AdaptiveTdeePolicy({
    this.policyVersion = 'adaptive_tdee_v1',
    this.alphaWeight = 0.12,
    this.betaTdee = 0.06,
    this.maxDailyDeltaKcal = 35.0,
    this.tissueKcalPerKg = 7700.0,
    this.warmupDays = 14,
    this.windowDays = 21,
    this.minFoodDaysModerate = 7,
    this.minWeightDaysModerate = 5,
    this.minFoodDaysHigh = 14,
    this.minWeightDaysHigh = 10,
    this.bmrFloorMultiplier = 0.8,
    this.bmrCeilingMultiplier = 3.0,
    this.absoluteFloorKcal = 1000.0,
    this.absoluteCeilingKcal = 6000.0,
    this.maxHistoryDays = 365,
  });

  static const v1 = AdaptiveTdeePolicy();
}

/// Estimation confidence based on logging cadence in the rolling evaluation window.
enum AdaptiveTdeeConfidence {
  calibrating,
  moderate,
  high,
}

/// Origin of daily caloric intake evidence.
enum AdaptiveTdeeIntakeSource {
  snapshot,
  foodLog,
  none,
}

/// An individual civil day's input data for adaptive evaluation.
class AdaptiveTdeeDayInput {
  final String localDate;
  final double? scaleWeightKg;
  final double? caloriesConsumed;
  final AdaptiveTdeeIntakeSource intakeSource;

  const AdaptiveTdeeDayInput({
    required this.localDate,
    this.scaleWeightKg,
    this.caloriesConsumed,
    this.intakeSource = AdaptiveTdeeIntakeSource.none,
  });

  bool get hasObservedIntake =>
      caloriesConsumed != null && caloriesConsumed! > 0;
  bool get hasWeight => scaleWeightKg != null && scaleWeightKg! > 0;
}

/// An individual civil day's output state after running the adaptive engine.
class AdaptiveTdeeDayOutput {
  final String localDate;
  final double? scaleWeightKg;
  final double? trendWeightKg;
  final double? rawExpenditureKcal;
  final double smoothedTdeeKcal;
  final bool hasObservedIntake;

  const AdaptiveTdeeDayOutput({
    required this.localDate,
    required this.scaleWeightKg,
    required this.trendWeightKg,
    required this.rawExpenditureKcal,
    required this.smoothedTdeeKcal,
    required this.hasObservedIntake,
  });
}

/// Complete evaluated snapshot of an individual's dynamic energy expenditure.
class AdaptiveTdeeEstimate {
  final double currentTdeeKcal;
  final double baselineTdeeKcal;
  final double? currentScaleWeightKg;
  final double? trendWeightKg;
  final AdaptiveTdeeConfidence confidence;
  final String confidenceMessage;
  final int loggedFoodDaysInWindow;
  final int loggedWeightDaysInWindow;
  final int totalObservedFoodDays;
  final String policyVersion;
  final List<AdaptiveTdeeDayOutput> history;

  const AdaptiveTdeeEstimate({
    required this.currentTdeeKcal,
    required this.baselineTdeeKcal,
    required this.currentScaleWeightKg,
    required this.trendWeightKg,
    required this.confidence,
    required this.confidenceMessage,
    required this.loggedFoodDaysInWindow,
    required this.loggedWeightDaysInWindow,
    required this.totalObservedFoodDays,
    required this.policyVersion,
    required this.history,
  });

  /// Formats this estimate into authoritative [B04MaintenanceEnergyEvidence]
  /// for consumption by the canonical B04 target engine.
  ///
  /// Strictly respects the B04 contract:
  /// - [policyVersion] is B04's active policy version (not the engine's internal version).
  /// - [sourceId] identifies this engine.
  /// - [sourceVersion] preserves the versioned engine policy.
  /// - [energy] provides a point estimate with equal lower and upper bounds.
  B04MaintenanceEnergyEvidence toMaintenanceEvidence({
    required String userId,
    required String localDate,
    required String timezoneId,
    required DateTime observedAtUtc,
    String? b04PolicyVersion,
    String? supersedesEvidenceId,
  }) {
    if (!observedAtUtc.isUtc) {
      throw ArgumentError('observedAtUtc must be in UTC.');
    }
    final point = currentTdeeKcal.round();
    final pointStr = point.toString();
    final activeB04Policy =
        b04PolicyVersion ?? B04AdaptiveTargetPolicy.current.policyVersion;

    return B04MaintenanceEnergyEvidence(
      id: 'maint_tdee_${localDate}_$userId',
      userId: userId,
      localDate: localDate,
      timezoneId: timezoneId,
      energy: B04NumericRangeEvidence(
        point: pointStr,
        lower: pointStr,
        upper: pointStr,
        unit: 'kcal/day',
        state: B04EvidenceState.known,
        stale: false,
        conflicting: false,
      ),
      sourceId: 'adaptive_tdee_engine',
      sourceVersion: policyVersion,
      policyVersion: activeB04Policy,
      historicalSnapshot: true,
      observedAtUtc: observedAtUtc,
      supersedesEvidenceId: supersedesEvidenceId,
    );
  }
}
