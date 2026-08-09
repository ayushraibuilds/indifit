import 'b02_muscle_volume_models.dart';

/// The presentation-facing facts used by the Progress tab.
///
/// These models intentionally retain the authority that supplied the value:
/// body measurements, completed sessions, and B02 performed sets are never
/// replaced with a recommendation or a derived strength estimate.
enum ProgressDataSection { measurements, workouts, strength, muscleBalance }

enum ProgressWeightGoalDirection { loss, gain, maintenance }

class ProgressWeightGoal {
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
  });

  final int id;
  final String name;
  final DateTime completedAtUtc;

  /// Local civil date in the same timezone used by Today’s B02 read.
  final String localDate;
  final String activityType;
  final double totalVolumeKg;

  bool get isCanonicalStrength => activityType == 'strength';
}

class ProgressStrengthSetRecord {
  const ProgressStrengthSetRecord({
    required this.performedSetId,
    required this.exerciseId,
    required this.exerciseName,
    required this.completedAtUtc,
    required this.localDate,
    required this.loadKg,
    required this.reps,
    required this.loadBasis,
  });

  final String performedSetId;
  final String exerciseId;
  final String exerciseName;
  final DateTime completedAtUtc;
  final String localDate;
  final double loadKg;
  final int reps;

  /// B02 load-basis IDs are intentionally preserved so unlike loads are never
  /// compared or silently converted in consumer presentation.
  final String loadBasis;
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
  });

  final DateTime nowUtc;
  final String timezoneId;
  final String todayLocalDate;
  final List<ProgressMeasurementRecord>? measurements;
  final List<ProgressWorkoutRecord>? workouts;
  final List<ProgressStrengthSetRecord>? strengthSets;
  final B02MuscleVolumeReadModel? muscleBalance;
  final Set<ProgressDataSection> unavailableSections;
  final ProgressWeightGoal? weightGoal;

  bool get measurementsAvailable => measurements != null;
  bool get workoutsAvailable => workouts != null;
  bool get strengthAvailable => strengthSets != null;

  List<ProgressMeasurementRecord> get weightMeasurements =>
      (measurements ?? const [])
          .where(
            (measurement) =>
                measurement.weightKg != null && measurement.weightKg! > 0,
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
      (muscleBalance != null && !muscleBalance!.isEmpty);

  /// A secondary analytics read may be unavailable for a brand-new account.
  /// When the two primary histories are known empty, retain the useful first
  /// Progress state rather than turning that ordinary starting point into an
  /// error panel.
  bool get hasKnownZeroData =>
      measurements != null && workouts != null && !hasAnyUsefulData;

  /// A primary-history failure without any independently available fact cannot
  /// honestly be represented as a zero-data state. Let the consumer offer one
  /// safe retry instead of rendering an empty diagnostic shell.
  bool get hasPrimaryDataFailureWithoutUsefulFacts =>
      !hasAnyUsefulData &&
      (unavailableSections.contains(ProgressDataSection.measurements) ||
          unavailableSections.contains(ProgressDataSection.workouts));
}
