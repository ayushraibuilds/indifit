import 'b02_muscle_volume_models.dart';
import 'b04_goal_models.dart';

/// The presentation-facing facts used by the Progress tab.
///
/// These models intentionally retain the authority that supplied the value:
/// body measurements, completed sessions, B02 performed sets, and B03 nutrition
/// daily totals are never replaced with an ungrounded estimate.
enum ProgressDataSection {
  measurements,
  workouts,
  strength,
  muscleBalance,
  nutrition,
}

enum ProgressWeightGoalDirection { loss, gain, maintenance }

class ProgressWeightGoal {
  /// Compatibility input reserved for a future canonical goal read model.
  /// Progress does not render this value until an owning authority supplies
  /// it; legacy onboarding preferences are not a target authority.
  const ProgressWeightGoal({required this.targetKg, required this.direction});

  final double targetKg;
  final ProgressWeightGoalDirection direction;
}

class ProgressMeasurementRecord {
  const ProgressMeasurementRecord({
    required this.id,
    required this.recordedAt,
    required this.localDate,
    this.weightKg,
    this.waistCm,
    this.chestCm,
    this.armsCm,
  });

  final int id;
  final DateTime recordedAt;

  /// Civil date in the same explicit timezone used for Progress ranges and
  /// Today’s workout-history reads. Never derive a measurement label from the
  /// device's current UTC offset at render time.
  final String localDate;
  final double? weightKg;
  final double? waistCm;
  final double? chestCm;
  final double? armsCm;

  bool get hasAnyBodyMeasurement =>
      _isPositive(waistCm) || _isPositive(chestCm) || _isPositive(armsCm);

  static bool _isPositive(double? value) => value != null && value > 0;
}

class ProgressWorkoutRecord {
  const ProgressWorkoutRecord({
    required this.id,
    required this.name,
    required this.completedAtUtc,
    required this.localDate,
    required this.activityType,
    required this.totalVolumeKg,
    this.durationSeconds = 0,
    this.workingSetsCount = 0,
    this.volumeIsTrustworthy = true,
  });

  final int id;
  final String name;
  final DateTime completedAtUtc;

  /// Local civil date in the same timezone used by Today’s B02 read.
  final String localDate;
  final String activityType;
  final double totalVolumeKg;
  final int durationSeconds;
  final int workingSetsCount;

  /// B02 volume is only displayable when every contributing performed set has
  /// a compatible, explicit external-load basis. A zero value is not used as
  /// a proxy for unavailable volume.
  final bool volumeIsTrustworthy;

  bool get isCanonicalStrength => activityType == 'strength';
}

class ProgressStrengthSetRecord {
  const ProgressStrengthSetRecord({
    required this.performedSetId,
    required this.exerciseId,
    required this.exerciseName,
    this.sessionId,
    this.performedExerciseId,
    required this.completedAtUtc,
    required this.localDate,
    required this.loadKg,
    required this.reps,
    required this.loadBasis,
  });

  final String performedSetId;
  final String exerciseId;
  final String exerciseName;
  final int? sessionId;
  final String? performedExerciseId;
  final DateTime completedAtUtc;
  final String localDate;
  final double loadKg;
  final int reps;

  /// B02 load-basis IDs are intentionally preserved so unlike loads are never
  /// compared or silently converted in consumer presentation.
  final String loadBasis;
}

class ProgressStrengthExerciseSummary {
  const ProgressStrengthExerciseSummary({
    required this.exerciseId,
    required this.exerciseName,
    required this.latestSet,
    required this.bestSet,
    required this.sessionCount,
    this.comparisonText,
    required this.history,
  });

  final String exerciseId;
  final String exerciseName;
  final ProgressStrengthSetRecord latestSet;

  /// The heaviest recorded set when the B02 basis is comparable. This is a
  /// descriptive performed fact, not a personal-record or strength estimate.
  final ProgressStrengthSetRecord bestSet;
  final int sessionCount;
  final String? comparisonText;
  final List<ProgressStrengthSetRecord> history;
}

class ProgressNutritionDaySummary {
  const ProgressNutritionDaySummary({
    required this.localDate,
    required this.dayLabel,
    required this.isToday,
    this.caloriesKcal,
    this.calorieTargetKcal,
    this.proteinG,
    this.proteinTargetG,
    required this.hasFoodLog,
    required this.isProteinTargetMet,
    required this.isNutrientIncomplete,
  });

  final String localDate;
  final String dayLabel;
  final bool isToday;
  final double? caloriesKcal;
  final double? calorieTargetKcal;
  final double? proteinG;
  final double? proteinTargetG;
  final bool hasFoodLog;
  final bool isProteinTargetMet;
  final bool isNutrientIncomplete;
}

class ProgressNutritionSummary {
  const ProgressNutritionSummary({
    required this.days,
    required this.loggedDaysCount,
    required this.calorieEvidenceDaysCount,
    required this.proteinEvidenceDaysCount,
    required this.proteinTargetMetDaysCount,
    this.averageCaloriesKcal,
    this.averageProteinG,
    this.targetCaloriesKcal,
    this.targetProteinG,
    this.targetGoalType,
    required this.hasTarget,
  });

  final List<ProgressNutritionDaySummary> days;
  final int loggedDaysCount;
  final int calorieEvidenceDaysCount;
  final int proteinEvidenceDaysCount;
  final int proteinTargetMetDaysCount;
  final double? averageCaloriesKcal;
  final double? averageProteinG;
  final double? targetCaloriesKcal;
  final double? targetProteinG;

  /// The B04 nutrition goal type effective for the current Progress date.
  /// This is a read-only projection of the date-scoped target authority; it
  /// is not a body-weight goal or a second Progress goal authority.
  final NutritionGoalType? targetGoalType;
  final bool hasTarget;

  bool get hasAnyLoggedDays => loggedDaysCount > 0;
}

/// A compact, failure-tolerant Progress read. A null collection is unknown;
/// an empty collection is known empty. This prevents an unavailable source
/// from becoming a misleading zero on the consumer screen.
class ProgressDashboardSnapshot {
  const ProgressDashboardSnapshot({
    required this.nowUtc,
    required this.timezoneId,
    required this.todayLocalDate,
    required this.measurements,
    required this.workouts,
    required this.strengthSets,
    required this.muscleBalance,
    required this.unavailableSections,
    this.weightGoal,
    this.nutritionSummary,
    this.strengthExercises,
    this.weeklyTrainedDates = const {},
  });

  final DateTime nowUtc;
  final String timezoneId;
  final String todayLocalDate;
  final List<ProgressMeasurementRecord>? measurements;
  final List<ProgressWorkoutRecord>? workouts;
  final List<ProgressStrengthSetRecord>? strengthSets;
  final B02MuscleVolumeReadModel? muscleBalance;
  final Set<ProgressDataSection> unavailableSections;

  /// Reserved compatibility input. Consumer Progress must only render a goal
  /// after a canonical body-target authority is introduced.
  final ProgressWeightGoal? weightGoal;
  final ProgressNutritionSummary? nutritionSummary;
  final List<ProgressStrengthExerciseSummary>? strengthExercises;
  final Set<String> weeklyTrainedDates;

  bool get measurementsAvailable => measurements != null;
  bool get workoutsAvailable => workouts != null;
  bool get strengthAvailable => strengthSets != null;
  bool get nutritionAvailable => nutritionSummary != null;

  List<ProgressMeasurementRecord> get weightMeasurements =>
      (measurements ?? const [])
          .where(
            (measurement) =>
                measurement.weightKg != null &&
                measurement.weightKg!.isFinite &&
                measurement.weightKg! > 0,
          )
          .toList(growable: false);

  List<ProgressMeasurementRecord> get bodyMeasurements =>
      (measurements ?? const [])
          .where((measurement) => measurement.hasAnyBodyMeasurement)
          .toList(growable: false);

  bool get hasAnyUsefulData =>
      weightMeasurements.isNotEmpty ||
      bodyMeasurements.isNotEmpty ||
      (workouts?.isNotEmpty ?? false) ||
      (strengthSets?.isNotEmpty ?? false) ||
      (muscleBalance != null && !muscleBalance!.isEmpty) ||
      (nutritionSummary != null && nutritionSummary!.hasAnyLoggedDays);

  /// A secondary analytics read may be unavailable for a brand-new account.
  /// When the primary histories are known empty, retain the useful first
  /// Progress state rather than turning that ordinary starting point into an
  /// error panel.
  bool get hasKnownZeroData =>
      measurements != null &&
      workouts != null &&
      (nutritionSummary == null || !nutritionSummary!.hasAnyLoggedDays) &&
      !hasAnyUsefulData;

  /// A primary-history failure without any independently available fact cannot
  /// honestly be represented as a zero-data state. Let the consumer offer one
  /// safe retry instead of rendering an empty diagnostic shell.
  bool get hasPrimaryDataFailureWithoutUsefulFacts =>
      !hasAnyUsefulData &&
      (unavailableSections.contains(ProgressDataSection.measurements) ||
          unavailableSections.contains(ProgressDataSection.workouts));
}
