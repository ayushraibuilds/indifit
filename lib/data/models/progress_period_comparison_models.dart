import 'package:flutter/foundation.dart';

/// Supported comparative range windows for historical drill-down.
///
/// Restricted to fixed-duration cycles to eliminate calendar-month variable-day
/// denominator skew (28 vs 30 vs 31 days).
enum PeriodComparisonRange {
  /// 7-Day civil week (Monday 00:00 through Sunday 23:59).
  week,

  /// 28-Day training cycle (Today minus 27 calendar days through Today).
  fourWeeks,
}

/// Factual completeness classification for a compared period.
enum PeriodCompletenessStatus {
  /// The period window has fully concluded in civil time.
  complete,

  /// The period window includes today's civil date; totals and counts are
  /// currently in progress.
  inProgress,

  /// Insufficient factual observations exist to make an evidence-backed
  /// comparative statement.
  sparse,
}

/// Civil date boundary and status for a discrete time window.
@immutable
class PeriodDateWindow {
  const PeriodDateWindow({
    required this.startLocalDate,
    required this.endLocalDate,
    required this.startUtc,
    required this.endExclusiveUtc,
    required this.daysCount,
    required this.status,
    this.inProgressDayIndex,
  });

  /// Canonical civil start date (YYYY-MM-DD).
  final String startLocalDate;

  /// Canonical civil end date (YYYY-MM-DD).
  final String endLocalDate;

  /// UTC start timestamp corresponding to 00:00:00 in the target timezone.
  final DateTime startUtc;

  /// UTC exclusive end timestamp corresponding to start of next day.
  final DateTime endExclusiveUtc;

  /// Total calendar days spanned by this window (7 or 28).
  final int daysCount;

  /// Completeness classification of this period.
  final PeriodCompletenessStatus status;

  /// When [status] is [PeriodCompletenessStatus.inProgress], this indicates
  /// the 1-indexed current day within the period (e.g., 4 of 7).
  final int? inProgressDayIndex;

  bool get isInProgress => status == PeriodCompletenessStatus.inProgress;
  bool get isComplete => status == PeriodCompletenessStatus.complete;
  bool get isSparse => status == PeriodCompletenessStatus.sparse;
}

/// Generic comparative container for a metric across current and prior periods.
@immutable
class ComparativeMetric<T> {
  const ComparativeMetric({
    required this.current,
    required this.previous,
    this.delta,
    this.percentChange,
    required this.status,
    this.evidenceDescription,
  });

  final T? current;
  final T? previous;
  final double? delta;
  final double? percentChange;
  final PeriodCompletenessStatus status;
  final String? evidenceDescription;

  bool get hasBothValues => current != null && previous != null;
  bool get hasDelta => delta != null;
}

/// Training consistency and volume metrics for a single period window.
@immutable
class TrainingPeriodSummary {
  const TrainingPeriodSummary({
    required this.window,
    required this.sessionCount,
    required this.trainingDayCount,
    required this.workingSetsCount,
    required this.totalDurationSeconds,
    required this.totalVolumeKg,
    required this.volumeIsTrustworthy,
    required this.partialSessionCount,
    required this.fullSessionCount,
  });

  final PeriodDateWindow window;
  final int sessionCount;
  final int trainingDayCount;
  final int workingSetsCount;
  final int totalDurationSeconds;
  final double totalVolumeKg;
  final bool volumeIsTrustworthy;
  final int partialSessionCount;
  final int fullSessionCount;

  bool get hasActivity => sessionCount > 0;
}

/// Nutrition metrics for a single period window.
///
/// Denominators strictly respect logged days: averages are never computed
/// by dividing across unlogged days.
@immutable
class NutritionPeriodSummary {
  const NutritionPeriodSummary({
    required this.window,
    required this.daysInPeriod,
    required this.loggedDaysCount,
    this.averageCaloriesKcal,
    this.averageProteinG,
    this.targetCaloriesKcal,
    this.targetProteinG,
    this.proteinTargetMetDaysCount = 0,
    required this.hasTarget,
  });

  final PeriodDateWindow window;
  final int daysInPeriod;
  final int loggedDaysCount;
  final double? averageCaloriesKcal;
  final double? averageProteinG;
  final double? targetCaloriesKcal;
  final double? targetProteinG;
  final int proteinTargetMetDaysCount;
  final bool hasTarget;

  bool get hasLoggedDays => loggedDaysCount > 0;
  double get loggingCoverage =>
      daysInPeriod > 0 ? (loggedDaysCount / daysInPeriod) : 0.0;
}

/// Body weight metrics for a single period window.
@immutable
class WeightPeriodSummary {
  const WeightPeriodSummary({
    required this.window,
    required this.observationCount,
    this.firstWeightKg,
    this.latestWeightKg,
    this.deltaKg,
    this.averageWeightKg,
    this.minWeightKg,
    this.maxWeightKg,
  });

  final PeriodDateWindow window;
  final int observationCount;
  final double? firstWeightKg;
  final double? latestWeightKg;
  final double? deltaKg;
  final double? averageWeightKg;
  final double? minWeightKg;
  final double? maxWeightKg;

  bool get hasObservations => observationCount > 0;
  bool get hasMeaningfulDelta => deltaKg != null && observationCount >= 2;
}

/// Comparative training metrics across current and prior periods.
@immutable
class ComparativeTrainingMetrics {
  const ComparativeTrainingMetrics({
    required this.current,
    required this.previous,
    required this.sessionCountMetric,
    required this.trainingDayMetric,
    required this.volumeMetric,
    required this.durationMetric,
  });

  final TrainingPeriodSummary current;
  final TrainingPeriodSummary previous;
  final ComparativeMetric<int> sessionCountMetric;
  final ComparativeMetric<int> trainingDayMetric;
  final ComparativeMetric<double> volumeMetric;
  final ComparativeMetric<int> durationMetric;

  bool get hasAnyActivity => current.hasActivity || previous.hasActivity;
}

/// Comparative nutrition metrics across current and prior periods.
@immutable
class ComparativeNutritionMetrics {
  const ComparativeNutritionMetrics({
    required this.current,
    required this.previous,
    required this.caloriesMetric,
    required this.proteinMetric,
    required this.loggedDaysMetric,
  });

  final NutritionPeriodSummary current;
  final NutritionPeriodSummary previous;
  final ComparativeMetric<double> caloriesMetric;
  final ComparativeMetric<double> proteinMetric;
  final ComparativeMetric<int> loggedDaysMetric;

  bool get hasAnyLoggedDays =>
      current.hasLoggedDays || previous.hasLoggedDays;
}

/// Comparative body weight metrics across current and prior periods.
@immutable
class ComparativeWeightMetrics {
  const ComparativeWeightMetrics({
    required this.current,
    required this.previous,
    this.weightDeltaBetweenPeriodsKg,
    this.ratePerWeekKg,
    required this.completeness,
  });

  final WeightPeriodSummary current;
  final WeightPeriodSummary previous;

  /// Delta between latest weight in current period and latest weight in
  /// previous period, when both exist.
  final double? weightDeltaBetweenPeriodsKg;

  /// Factual rate of change per 7-day civil week.
  final double? ratePerWeekKg;

  final PeriodCompletenessStatus completeness;

  bool get hasAnyObservations =>
      current.hasObservations || previous.hasObservations;
}

/// Factual heavy set and volume comparison for a top trained exercise.
@immutable
class StrengthExercisePeriodComparison {
  const StrengthExercisePeriodComparison({
    required this.exerciseId,
    required this.exerciseName,
    this.currentHeaviestLoadKg,
    this.currentHeaviestReps,
    this.previousHeaviestLoadKg,
    this.previousHeaviestReps,
    required this.currentVolumeKg,
    required this.previousVolumeKg,
    required this.currentSetCount,
    required this.previousSetCount,
    this.loadBasis = 'totalExternal',
  });

  final String exerciseId;
  final String exerciseName;
  final double? currentHeaviestLoadKg;
  final int? currentHeaviestReps;
  final double? previousHeaviestLoadKg;
  final int? previousHeaviestReps;
  final double currentVolumeKg;
  final double previousVolumeKg;
  final int currentSetCount;
  final int previousSetCount;
  final String loadBasis;

  double get volumeDeltaKg => currentVolumeKg - previousVolumeKg;
  bool get hasPriorData => previousSetCount > 0;
}

/// Complete period comparison snapshot used by the Progress screen.
@immutable
class ProgressPeriodComparisonSnapshot {
  const ProgressPeriodComparisonSnapshot({
    required this.range,
    required this.timezoneId,
    required this.currentWindow,
    required this.previousWindow,
    required this.trainingComparison,
    this.nutritionComparison,
    this.weightComparison,
    required this.strengthComparisons,
  });

  final PeriodComparisonRange range;
  final String timezoneId;
  final PeriodDateWindow currentWindow;
  final PeriodDateWindow previousWindow;
  final ComparativeTrainingMetrics trainingComparison;
  final ComparativeNutritionMetrics? nutritionComparison;
  final ComparativeWeightMetrics? weightComparison;
  final List<StrengthExercisePeriodComparison> strengthComparisons;

  bool get hasAnyData =>
      trainingComparison.hasAnyActivity ||
      (nutritionComparison?.hasAnyLoggedDays ?? false) ||
      (weightComparison?.hasAnyObservations ?? false);
}
