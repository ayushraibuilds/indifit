import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/b02_execution_models.dart';

/// Read-only, exact-identity history for strength performance.
///
/// This deliberately reads the canonical B02 performed tables rather than the
/// legacy name-based workout-set table. A display-name change or a similarly
/// named exercise must not change which history is shown.
class B02ExercisePerformanceReadRepository {
  const B02ExercisePerformanceReadRepository(this._database);

  final AppDatabase _database;

  Future<List<B02ExercisePerformanceRecord>> read({
    required String stableExerciseId,
  }) async {
    final exerciseId = stableExerciseId.trim();
    if (exerciseId.isEmpty) {
      throw ArgumentError.value(
        stableExerciseId,
        'stableExerciseId',
        'A stable exercise ID is required.',
      );
    }

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
              ..where(exercises.actualExerciseId.equals(exerciseId))
              ..where(
                sessions.activityType.equals(B02ActivityType.strength.dbValue),
              )
              ..orderBy([
                OrderingTerm.desc(sessions.completedAt),
                OrderingTerm.desc(sessions.id),
                OrderingTerm.asc(exercises.ordinal),
                OrderingTerm.asc(sets.ordinal),
              ]))
            .get();

    final records = <String, _MutableRecord>{};
    for (final row in rows) {
      final persistedSet = row.readTable(sets);
      final persistedExercise = row.readTable(exercises);
      final persistedSession = row.readTable(sessions);
      final set = _toPerformedSet(persistedSet);
      if (set == null || !_hasLoggedActual(set)) continue;

      final key = '${persistedSession.id}:${persistedExercise.id}';
      final record = records.putIfAbsent(
        key,
        () => _MutableRecord(
          sessionId: persistedSession.id,
          performedExerciseId: persistedExercise.id,
          sessionName: persistedSession.name,
          completedAt: persistedSession.completedAt.toUtc(),
          exerciseStatus: persistedExercise.status,
          exerciseOrdinal: persistedExercise.ordinal,
        ),
      );
      record.sets.add(set);
    }

    return records.values
        .map((record) => record.freeze())
        .toList(growable: false);
  }

  B02PerformedSet? _toPerformedSet(PerformedSet set) {
    try {
      return B02PerformedSet(
        id: set.id,
        performedExerciseId: set.performedExerciseId,
        ordinal: set.ordinal,
        role: B02SetRole.parse(set.role),
        targetLoadKg: set.targetLoadKg,
        targetLoadBasis: set.targetLoadBasis == null
            ? null
            : B02LoadBasis.parse(set.targetLoadBasis),
        targetRepsMin: set.targetRepsMin,
        targetRepsMax: set.targetRepsMax,
        targetRpe: set.targetRpe,
        actualLoadKg: set.actualLoadKg,
        actualLoadBasis: set.actualLoadBasis == null
            ? null
            : B02LoadBasis.parse(set.actualLoadBasis),
        actualReps: set.actualReps,
        actualRpe: set.actualRpe,
        notes: set.notes,
      );
    } on B02ValidationException {
      // Fail closed when a persisted value is outside the B02 contract rather
      // than displaying an untyped value as trusted performance.
      return null;
    }
  }

  static bool _hasLoggedActual(B02PerformedSet set) =>
      set.actualLoadKg != null ||
      set.actualLoadBasis != null ||
      set.actualReps != null ||
      set.actualRpe != null;
}

/// One actual exercise occurrence within a completed canonical session.
///
/// A workout may intentionally contain the same exercise more than once. The
/// occurrence ID and ordinal retain that distinction instead of merging those
/// sets by display name or by an invented aggregate.
class B02ExercisePerformanceRecord {
  const B02ExercisePerformanceRecord({
    required this.sessionId,
    required this.performedExerciseId,
    required this.sessionName,
    required this.completedAt,
    required this.exerciseStatus,
    required this.exerciseOrdinal,
    required this.sets,
  });

  final int sessionId;
  final String performedExerciseId;
  final String sessionName;
  final DateTime completedAt;
  final String exerciseStatus;
  final int exerciseOrdinal;
  final List<B02PerformedSet> sets;
}

class _MutableRecord {
  _MutableRecord({
    required this.sessionId,
    required this.performedExerciseId,
    required this.sessionName,
    required this.completedAt,
    required this.exerciseStatus,
    required this.exerciseOrdinal,
  });

  final int sessionId;
  final String performedExerciseId;
  final String sessionName;
  final DateTime completedAt;
  final String exerciseStatus;
  final int exerciseOrdinal;
  final List<B02PerformedSet> sets = [];

  B02ExercisePerformanceRecord freeze() => B02ExercisePerformanceRecord(
    sessionId: sessionId,
    performedExerciseId: performedExerciseId,
    sessionName: sessionName,
    completedAt: completedAt,
    exerciseStatus: exerciseStatus,
    exerciseOrdinal: exerciseOrdinal,
    sets: List.unmodifiable(sets),
  );
}
