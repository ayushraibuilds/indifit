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
    final segmentedSetIds = await _segmentedSetIds(
      rows.map((row) => row.readTable(sets).id),
    );

    final records = <String, _MutableRecord>{};
    for (final row in rows) {
      final persistedSet = row.readTable(sets);
      final persistedExercise = row.readTable(exercises);
      final persistedSession = row.readTable(sessions);
      final set = _toPerformedSet(persistedSet);
      if (set == null || !_hasLoggedActual(set)) continue;

      final completionKind = persistedSession.completionKind;
      if (!const {'full', 'partial'}.contains(completionKind) ||
          !const {'completed', 'partial'}.contains(persistedExercise.status)) {
        // Do not present malformed completion state as completed evidence.
        // The affected occurrence is left out instead of being guessed.
        continue;
      }

      final key = '${persistedSession.id}:${persistedExercise.id}';
      final record = records.putIfAbsent(
        key,
        () => _MutableRecord(
          sessionId: persistedSession.id,
          performedExerciseId: persistedExercise.id,
          sessionName: persistedSession.name,
          completedAt: persistedSession.completedAt.toUtc(),
          completionKind: completionKind!,
          actualExerciseId: persistedExercise.actualExerciseId,
          actualExerciseName: persistedExercise.actualExerciseNameSnapshot,
          expectedExerciseId: persistedExercise.expectedExerciseId,
          expectedExerciseName: persistedExercise.expectedExerciseNameSnapshot,
          substitutionReason: persistedExercise.substitutionReason,
          exerciseStatus: persistedExercise.status,
          exerciseOrdinal: persistedExercise.ordinal,
        ),
      );
      record.sets.add(set);
      if (segmentedSetIds.contains(set.id)) record.segmentedSetIds.add(set.id);
    }

    return records.values
        .map((record) => record.freeze())
        .toList(growable: false);
  }

  /// The distinct exercises actually performed in one saved session, in
  /// workout order. Used to read each exercise's history for that session.
  Future<List<String>> readSessionExerciseIds(int sessionId) async {
    final exercises = _database.performedExercises;
    final rows =
        await (_database.select(exercises)
              ..where((table) => table.sessionId.equals(sessionId))
              ..orderBy([(table) => OrderingTerm.asc(table.ordinal)]))
            .get();
    final ids = <String>[];
    for (final row in rows) {
      final id = row.actualExerciseId.trim();
      if (id.isNotEmpty && !ids.contains(id)) ids.add(id);
    }
    return List.unmodifiable(ids);
  }

  /// Sets with persisted drop-set or rest-pause segments. The segment rows do
  /// not store which of the two techniques was used, so the set is flagged
  /// rather than rebuilt with a guessed intent.
  Future<Set<String>> _segmentedSetIds(Iterable<String> setIds) async {
    final ids = setIds.toSet();
    if (ids.isEmpty) return const {};
    final segments = _database.performedSetSegments;
    final rows =
        await (_database.selectOnly(segments, distinct: true)
              ..addColumns([segments.performedSetId])
              ..where(segments.performedSetId.isIn(ids)))
            .get();
    return {for (final row in rows) row.read(segments.performedSetId)!};
  }

  B02PerformedSet? _toPerformedSet(PerformedSet set) {
    final actualLoad = set.actualLoadKg;
    if (actualLoad != null && (!actualLoad.isFinite || actualLoad < 0)) {
      return null;
    }
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
        // Assistance, tempo and paused reps change what a set means, so bests
        // and the heaviest-set read must see them rather than an empty value.
        technique: B02TechniqueFields(
          effortMode: set.effortMode == null
              ? B02EffortMode.standard
              : B02EffortMode.parse(set.effortMode),
          endedAtFailure: set.endedAtFailure,
          tempoEccentricSeconds: set.tempoEccentricSeconds,
          tempoBottomPauseSeconds: set.tempoBottomPauseSeconds,
          tempoConcentricSeconds: set.tempoConcentricSeconds,
          tempoLockoutPauseSeconds: set.tempoLockoutPauseSeconds,
          pausedRepPosition: set.pausedRepPosition == null
              ? null
              : B02PausedRepPosition.parse(set.pausedRepPosition),
          pausedRepSeconds: set.pausedRepSeconds,
          assistanceMode: set.assistanceMode == null
              ? null
              : B02AssistanceMode.parse(set.assistanceMode),
          assistanceKg: set.assistanceKg,
        ),
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
    this.completionKind = 'full',
    this.actualExerciseId = '',
    this.actualExerciseName = '',
    this.expectedExerciseId,
    this.expectedExerciseName,
    this.substitutionReason,
    required this.exerciseStatus,
    required this.exerciseOrdinal,
    required this.sets,
    this.segmentedSetIds = const {},
  });

  final int sessionId;
  final String performedExerciseId;
  final String sessionName;
  final DateTime completedAt;
  final String completionKind;
  final String actualExerciseId;
  final String actualExerciseName;
  final String? expectedExerciseId;
  final String? expectedExerciseName;
  final String? substitutionReason;
  final String exerciseStatus;
  final int exerciseOrdinal;
  final List<B02PerformedSet> sets;

  /// IDs of [sets] that carry drop-set or rest-pause segments.
  final Set<String> segmentedSetIds;

  bool get isPartial => completionKind == 'partial';

  bool get wasSubstituted =>
      expectedExerciseId != null && expectedExerciseId != actualExerciseId;
}

class _MutableRecord {
  _MutableRecord({
    required this.sessionId,
    required this.performedExerciseId,
    required this.sessionName,
    required this.completedAt,
    required this.completionKind,
    required this.actualExerciseId,
    required this.actualExerciseName,
    required this.expectedExerciseId,
    required this.expectedExerciseName,
    required this.substitutionReason,
    required this.exerciseStatus,
    required this.exerciseOrdinal,
  });

  final int sessionId;
  final String performedExerciseId;
  final String sessionName;
  final DateTime completedAt;
  final String completionKind;
  final String actualExerciseId;
  final String actualExerciseName;
  final String? expectedExerciseId;
  final String? expectedExerciseName;
  final String? substitutionReason;
  final String exerciseStatus;
  final int exerciseOrdinal;
  final List<B02PerformedSet> sets = [];
  final Set<String> segmentedSetIds = {};

  B02ExercisePerformanceRecord freeze() => B02ExercisePerformanceRecord(
    sessionId: sessionId,
    performedExerciseId: performedExerciseId,
    sessionName: sessionName,
    completedAt: completedAt,
    completionKind: completionKind,
    actualExerciseId: actualExerciseId,
    actualExerciseName: actualExerciseName,
    expectedExerciseId: expectedExerciseId,
    expectedExerciseName: expectedExerciseName,
    substitutionReason: substitutionReason,
    exerciseStatus: exerciseStatus,
    exerciseOrdinal: exerciseOrdinal,
    sets: List.unmodifiable(sets),
    segmentedSetIds: Set.unmodifiable(segmentedSetIds),
  );
}
