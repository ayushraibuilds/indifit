import 'package:drift/drift.dart';

import '../../core/services/local_schedule_date_service.dart';
import '../database/app_database.dart';
import '../models/b02_execution_models.dart';
import '../models/b02_muscle_volume_models.dart';
import '../models/progress_dashboard_models.dart';
import 'b02_muscle_volume_repository.dart';
import 'workout_repository.dart';

/// Read-only composition for the consumer Progress tab.
///
/// It deliberately reads completed-session facts, persisted measurements, B02
/// performed values, and the existing B02 muscle-volume output. It neither
/// persists aggregate data nor converts prescribed/recommended targets into
/// achievements.
class ProgressDashboardReadRepository {
  ProgressDashboardReadRepository(
    this._database, {
    WorkoutRepository? workouts,
    B02MuscleVolumeRepository? muscleVolume,
    LocalScheduleDateService? dates,
  }) : _workouts = workouts ?? WorkoutRepository(_database),
       _muscleVolume = muscleVolume ?? B02MuscleVolumeRepository(_database),
       _dates = dates ?? LocalScheduleDateService();

  final AppDatabase _database;
  final WorkoutRepository _workouts;
  final B02MuscleVolumeRepository _muscleVolume;
  final LocalScheduleDateService _dates;

  Future<ProgressDashboardSnapshot> read({
    required DateTime nowUtc,
    required String timezoneId,
    ProgressWeightGoal? weightGoal,
  }) async {
    final unavailable = <ProgressDataSection>{};
    final now = nowUtc.toUtc();

    final measurements = await _readSafely(
      section: ProgressDataSection.measurements,
      unavailable: unavailable,
      read: () => _readMeasurements(now, timezoneId),
    );
    final workouts = await _readSafely(
      section: ProgressDataSection.workouts,
      unavailable: unavailable,
      read: () => _readWorkouts(now, timezoneId),
    );
    final strengthSets = await _readSafely(
      section: ProgressDataSection.strength,
      unavailable: unavailable,
      read: () => _readPerformedStrengthSets(now, timezoneId),
    );
    final muscleBalance = await _readSafely(
      section: ProgressDataSection.muscleBalance,
      unavailable: unavailable,
      read: () =>
          _readRecentCompletedMuscleVolume(now: now, timezoneId: timezoneId),
    );

    return ProgressDashboardSnapshot(
      nowUtc: now,
      timezoneId: timezoneId,
      todayLocalDate: _dates.localDateFor(now, timezoneId),
      measurements: measurements,
      workouts: workouts,
      strengthSets: strengthSets,
      muscleBalance: muscleBalance,
      unavailableSections: unavailable,
      weightGoal: weightGoal,
    );
  }

  Future<T?> _readSafely<T>({
    required ProgressDataSection section,
    required Set<ProgressDataSection> unavailable,
    required Future<T> Function() read,
  }) async {
    try {
      return await read();
    } catch (_) {
      unavailable.add(section);
      return null;
    }
  }

  Future<List<ProgressMeasurementRecord>> _readMeasurements(
    DateTime nowUtc,
    String timezoneId,
  ) async {
    final rows = await _workouts.getBodyMeasurements();
    final result = [
      for (final row in rows)
        if (!row.recordedAt.toUtc().isAfter(nowUtc))
          ProgressMeasurementRecord(
            id: row.id,
            recordedAt: row.recordedAt,
            localDate: _dates.localDateFor(row.recordedAt.toUtc(), timezoneId),
            weightKg: row.weight,
            waistCm: row.waist,
            chestCm: row.chest,
            armsCm: row.arms,
          ),
    ];
    result.sort(
      (first, second) => second.recordedAt.compareTo(first.recordedAt),
    );
    return result;
  }

  Future<List<ProgressWorkoutRecord>> _readWorkouts(
    DateTime nowUtc,
    String timezoneId,
  ) async {
    final rows = await _workouts.getSessions();
    final result = [
      for (final row in rows)
        if (!row.completedAt.toUtc().isAfter(nowUtc))
          ProgressWorkoutRecord(
            id: row.id,
            name: row.name,
            completedAtUtc: row.completedAt.toUtc(),
            localDate: _dates.localDateFor(row.completedAt.toUtc(), timezoneId),
            activityType: row.activityType,
            totalVolumeKg: row.totalVolume,
          ),
    ];
    result.sort(
      (first, second) => second.completedAtUtc.compareTo(first.completedAtUtc),
    );
    return result;
  }

  Future<List<ProgressStrengthSetRecord>> _readPerformedStrengthSets(
    DateTime nowUtc,
    String timezoneId,
  ) async {
    final sets = _database.performedSets;
    final exercises = _database.performedExercises;
    final sessions = _database.workoutSessions;
    final rows =
        await (_database.select(sets).join([
                innerJoin(
                  exercises,
                  exercises.id.equalsExp(sets.performedExerciseId),
                ),
                innerJoin(sessions, sessions.id.equalsExp(exercises.sessionId)),
              ])
              ..where(
                sessions.activityType.equals(B02ActivityType.strength.dbValue),
              )
              ..where(sets.role.equals(B02SetRole.working.dbValue))
              ..orderBy([
                OrderingTerm.desc(sessions.completedAt),
                OrderingTerm.asc(exercises.ordinal),
                OrderingTerm.asc(sets.ordinal),
              ]))
            .get();

    final result = <ProgressStrengthSetRecord>[];
    for (final row in rows) {
      final set = row.readTable(sets);
      final exercise = row.readTable(exercises);
      final session = row.readTable(sessions);
      final completedAtUtc = session.completedAt.toUtc();
      final actualLoad = set.actualLoadKg;
      final actualReps = set.actualReps;
      final loadBasis = set.actualLoadBasis;
      if (completedAtUtc.isAfter(nowUtc) ||
          actualLoad == null ||
          actualReps == null ||
          actualReps < 1 ||
          loadBasis == null) {
        continue;
      }
      // The database constraint protects writes, but preserve the fail-closed
      // B02 meaning at this presentation boundary as well.
      try {
        B02LoadBasis.parse(loadBasis);
      } on B02ValidationException {
        continue;
      }
      result.add(
        ProgressStrengthSetRecord(
          performedSetId: set.id,
          exerciseId: exercise.actualExerciseId,
          exerciseName: exercise.actualExerciseNameSnapshot,
          completedAtUtc: completedAtUtc,
          localDate: _dates.localDateFor(completedAtUtc, timezoneId),
          loadKg: actualLoad,
          reps: actualReps,
          loadBasis: loadBasis,
        ),
      );
    }
    return result;
  }

  Future<B02MuscleVolumeReadModel> _readRecentCompletedMuscleVolume({
    required DateTime now,
    required String timezoneId,
  }) {
    // The existing B02 output is civil-date based. Use the last 28 completed
    // civil days: ending on yesterday keeps a future-dated row later today out
    // of a consumer summary while avoiding a second muscle-volume calculation
    // in the UI.
    final today = _dates.localDateFor(now, timezoneId);
    final endDate = _dates.addCalendarDays(today, timezoneId, -1);
    final startDate = _dates.addCalendarDays(endDate, timezoneId, -27);
    return _muscleVolume.read(
      B02MuscleVolumeQuery(
        startLocalDate: startDate,
        endLocalDate: endDate,
        timezoneId: timezoneId,
      ),
    );
  }
}
