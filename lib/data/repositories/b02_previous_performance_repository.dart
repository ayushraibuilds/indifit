import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/b02_execution_models.dart';
import '../models/b02_previous_performance_models.dart';

/// Canonical B.3 read boundary for previous exercise performance.
///
/// This repository reads only finalized typed B02 strength history. It does
/// not read legacy name-based WorkoutSets, invoke the B02 target rule, or
/// calculate a recommendation of any kind.
class B02PreviousPerformanceRepository {
  const B02PreviousPerformanceRepository(this._database);

  final AppDatabase _database;

  Future<B02PreviousExercisePerformance> resolve(
    B02PreviousPerformanceQuery query,
  ) async {
    final canonicalId = query.canonicalExerciseId?.trim();
    if (canonicalId == null || canonicalId.isEmpty) {
      return const B02PreviousExercisePerformance.invalidQuery(
        canonicalExerciseId: null,
        reasonCode: 'canonical_exercise_id_required',
      );
    }
    if (query.activityType != B02ActivityType.strength) {
      return B02PreviousExercisePerformance.unavailable(
        status: B02PreviousPerformanceStatus.incompatible,
        canonicalExerciseId: canonicalId,
        reasonCode: 'unsupported_modality',
      );
    }
    if (query.setContext.hasTechniqueSegments) {
      return B02PreviousExercisePerformance.unavailable(
        status: B02PreviousPerformanceStatus.incompatible,
        canonicalExerciseId: canonicalId,
        reasonCode: 'technique_segments_unsupported',
      );
    }

    final asOfUtc = query.asOfUtc.toUtc();

    try {
      final rows = await _readRows(
        canonicalExerciseId: canonicalId,
        asOfUtc: asOfUtc,
      );
      final segmentsBySetId = await _readSegments(rows);
      final selection = _selectLatestComparableSession(
        rows: rows,
        segmentsBySetId: segmentsBySetId,
        query: query,
      );
      if (selection == null) {
        final excludedOnly =
            rows.isNotEmpty &&
            rows.every(
              (row) =>
                  query.excludeSessionId != null &&
                  row.session.id == query.excludeSessionId,
            );
        final hasIncompatibleRows = rows.any(
          (row) => row.session.id != query.excludeSessionId,
        );
        return B02PreviousExercisePerformance.unavailable(
          status: excludedOnly && !hasIncompatibleRows
              ? B02PreviousPerformanceStatus.noHistory
              : rows.isEmpty
              ? B02PreviousPerformanceStatus.noHistory
              : B02PreviousPerformanceStatus.incompatible,
          canonicalExerciseId: canonicalId,
          reasonCode: excludedOnly && !hasIncompatibleRows
              ? 'current_session_excluded'
              : rows.isEmpty
              ? 'no_history'
              : 'no_compatible_evidence',
        );
      }

      final occurrences =
          selection.occurrences.values
              .map((builder) => builder.freeze())
              .toList()
            ..sort(_compareOccurrences);
      final safePrefill = _safePrefill(
        sessionId: selection.session.id,
        occurrences: occurrences,
      );
      return B02PreviousExercisePerformance.available(
        canonicalExerciseId: canonicalId,
        sessionId: selection.session.id,
        sessionName: selection.session.name,
        completedAtUtc: selection.session.completedAt.toUtc(),
        occurrences: occurrences,
        safePrefill: safePrefill,
      );
    } catch (_) {
      // The consumer must be able to distinguish a broken read from the
      // normal no-history state without receiving raw database details.
      return B02PreviousExercisePerformance.unavailable(
        status: B02PreviousPerformanceStatus.queryFailure,
        canonicalExerciseId: canonicalId,
        reasonCode: 'database_query_failed',
      );
    }
  }

  Future<List<_JoinedHistoryRow>> _readRows({
    required String canonicalExerciseId,
    required DateTime asOfUtc,
  }) async {
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
              // This is the only identity predicate. Names, families,
              // technique suffixes and planned-slot ancestry never enter it.
              ..where(exercises.actualExerciseId.equals(canonicalExerciseId))
              ..where(sessions.completedAt.isSmallerOrEqualValue(asOfUtc)))
            .get();
    return [
      for (final row in rows)
        _JoinedHistoryRow(
          session: row.readTable(sessions),
          exercise: row.readTable(exercises),
          set: row.readTable(sets),
        ),
    ];
  }

  Future<Map<String, List<PerformedSetSegment>>> _readSegments(
    List<_JoinedHistoryRow> rows,
  ) async {
    final setIds = rows.map((row) => row.set.id).toSet();
    if (setIds.isEmpty) return const {};
    final segments = await (_database.select(
      _database.performedSetSegments,
    )..where((table) => table.performedSetId.isIn(setIds))).get();
    final bySet = <String, List<PerformedSetSegment>>{};
    for (final segment in segments) {
      bySet.putIfAbsent(segment.performedSetId, () => []).add(segment);
    }
    return bySet;
  }

  _SessionBuilder? _selectLatestComparableSession({
    required List<_JoinedHistoryRow> rows,
    required Map<String, List<PerformedSetSegment>> segmentsBySetId,
    required B02PreviousPerformanceQuery query,
  }) {
    final sessions = <int, _SessionBuilder>{};
    for (final row in rows) {
      final session = row.session;
      if (query.excludeSessionId != null &&
          session.id == query.excludeSessionId) {
        continue;
      }
      if (session.activityType != query.activityType.dbValue) {
        continue;
      }
      if (!_isAuthoritativeCompletionKind(session.completionKind)) {
        continue;
      }
      if (!_isAuthoritativeExerciseStatus(row.exercise.status)) {
        continue;
      }
      final parsed = _parseComparableSet(
        row.set,
        segmentsBySetId[row.set.id] ?? const [],
        query.setContext,
      );
      if (parsed == null) continue;

      final sessionBuilder = sessions.putIfAbsent(
        session.id,
        () => _SessionBuilder(session),
      );
      final occurrence = sessionBuilder.occurrences.putIfAbsent(
        row.exercise.id,
        () => _OccurrenceBuilder(
          performedExerciseId: row.exercise.id,
          exerciseOrdinal: row.exercise.ordinal,
          actualExerciseId: row.exercise.actualExerciseId,
          actualExerciseNameSnapshot: row.exercise.actualExerciseNameSnapshot,
          status: row.exercise.status,
          expectedExerciseId: row.exercise.expectedExerciseId,
          sourceExercisePrescriptionId:
              row.exercise.sourceExercisePrescriptionId,
          substitutionReason: row.exercise.substitutionReason,
        ),
      );
      occurrence.sets.add(parsed);
    }

    if (sessions.isEmpty) return null;
    final ordered = sessions.values.toList()..sort(_compareSessionsByRecency);
    final latest = ordered.first;
    for (final occurrence in latest.occurrences.values) {
      occurrence.sets.sort(_compareSetsByOrdinal);
    }
    return latest;
  }

  B02PreviousPerformanceSet? _parseComparableSet(
    PerformedSet set,
    List<PerformedSetSegment> segments,
    B02PreviousPerformanceSetContext context,
  ) {
    try {
      if (set.ordinal < 0) return null;
      final role = B02SetRole.parse(set.role);
      final loadBasis = set.actualLoadBasis == null
          ? null
          : B02LoadBasis.parse(set.actualLoadBasis);
      final effortMode = set.effortMode == null
          ? B02EffortMode.standard
          : B02EffortMode.parse(set.effortMode);
      final assistanceMode = set.assistanceMode == null
          ? null
          : B02AssistanceMode.parse(set.assistanceMode);
      final pausedPosition = set.pausedRepPosition == null
          ? null
          : B02PausedRepPosition.parse(set.pausedRepPosition);

      if (loadBasis == null || loadBasis != context.loadBasis) return null;
      final actualReps = set.actualReps;
      if (actualReps == null || actualReps <= 0) return null;
      final actualRpe = set.actualRpe;
      if (actualRpe != null && (actualRpe < 1 || actualRpe > 10)) {
        return null;
      }
      final actualLoad = set.actualLoadKg;
      if (loadBasis == B02LoadBasis.bodyweight) {
        // Bodyweight has no external-load default. A non-null kg value beside
        // bodyweight is ambiguous historical data and fails closed.
        if (actualLoad != null) return null;
      } else if (actualLoad == null || !actualLoad.isFinite || actualLoad < 0) {
        return null;
      }

      if (!_validAssistance(mode: assistanceMode, loadKg: set.assistanceKg)) {
        return null;
      }
      if (!_validTempo(set)) return null;
      if (!_validPausedRep(set, pausedPosition)) return null;
      // B02 persists segment rows without the complete technique-intent
      // envelope required to prove drop-set/rest-pause equivalence at this
      // boundary. Refuse every segmented row until B.3 has an exact segment
      // query/result model; never reduce it to a boolean or a header guess.
      if (segments.isNotEmpty) return null;

      final result = B02PreviousPerformanceSet(
        performedSetId: set.id,
        ordinal: set.ordinal,
        role: role,
        loadBasis: loadBasis,
        actualLoadKg: actualLoad,
        actualReps: actualReps,
        actualRpe: actualRpe,
        effortMode: effortMode,
        endedAtFailure: set.endedAtFailure,
        assistanceMode: assistanceMode,
        assistanceKg: set.assistanceKg,
        tempoEccentricSeconds: set.tempoEccentricSeconds,
        tempoBottomPauseSeconds: set.tempoBottomPauseSeconds,
        tempoConcentricSeconds: set.tempoConcentricSeconds,
        tempoLockoutPauseSeconds: set.tempoLockoutPauseSeconds,
        pausedRepPosition: pausedPosition,
        pausedRepSeconds: set.pausedRepSeconds,
        hasTechniqueSegments: segments.isNotEmpty,
      );
      return _matchesContext(result, context) ? result : null;
    } on B02ValidationException {
      return null;
    }
  }

  bool _matchesContext(
    B02PreviousPerformanceSet set,
    B02PreviousPerformanceSetContext context,
  ) {
    return set.role == context.role &&
        set.loadBasis == context.loadBasis &&
        set.effortMode == context.effortMode &&
        set.endedAtFailure == context.endedAtFailure &&
        set.assistanceMode == context.assistanceMode &&
        _sameDouble(set.assistanceKg, context.assistanceKg) &&
        set.tempoEccentricSeconds == context.tempoEccentricSeconds &&
        set.tempoBottomPauseSeconds == context.tempoBottomPauseSeconds &&
        set.tempoConcentricSeconds == context.tempoConcentricSeconds &&
        set.tempoLockoutPauseSeconds == context.tempoLockoutPauseSeconds &&
        set.pausedRepPosition == context.pausedRepPosition &&
        set.pausedRepSeconds == context.pausedRepSeconds &&
        set.hasTechniqueSegments == context.hasTechniqueSegments;
  }

  bool _validAssistance({
    required B02AssistanceMode? mode,
    required double? loadKg,
  }) {
    if (mode == null) return loadKg == null;
    return loadKg != null && loadKg.isFinite && loadKg > 0;
  }

  bool _validTempo(PerformedSet set) {
    final tempo = [
      set.tempoEccentricSeconds,
      set.tempoBottomPauseSeconds,
      set.tempoConcentricSeconds,
      set.tempoLockoutPauseSeconds,
    ];
    final hasTempo = tempo.any((value) => value != null);
    if (!hasTempo) return true;
    return tempo.every((value) => value != null && value >= 0) &&
        tempo.any((value) => value! > 0);
  }

  bool _validPausedRep(PerformedSet set, B02PausedRepPosition? pausedPosition) {
    final hasPosition = pausedPosition != null;
    final hasSeconds = set.pausedRepSeconds != null;
    if (hasPosition != hasSeconds) return false;
    return set.pausedRepSeconds == null || set.pausedRepSeconds! > 0;
  }

  B02PreviousPerformancePrefill? _safePrefill({
    required int sessionId,
    required List<B02PreviousPerformanceOccurrence> occurrences,
  }) {
    final sets = occurrences.expand((occurrence) => occurrence.sets).toList();
    if (sets.length != 1) return null;
    final occurrence = occurrences.single;
    final set = sets.single;
    if (set.hasTechniqueSegments) return null;
    return B02PreviousPerformancePrefill(
      sessionId: sessionId,
      performedExerciseId: occurrence.performedExerciseId,
      performedSetId: set.performedSetId,
      setOrdinal: set.ordinal,
      role: set.role,
      loadBasis: set.loadBasis,
      loadKg: set.actualLoadKg,
      reps: set.actualReps,
      rpe: set.actualRpe,
    );
  }

  static bool _isAuthoritativeCompletionKind(String? value) =>
      value == 'full' || value == 'partial';

  static bool _isAuthoritativeExerciseStatus(String value) =>
      value == 'completed' || value == 'partial';

  static int _compareSessionsByRecency(
    _SessionBuilder first,
    _SessionBuilder second,
  ) {
    final completed = second.session.completedAt.compareTo(
      first.session.completedAt,
    );
    return completed != 0
        ? completed
        : second.session.id.compareTo(first.session.id);
  }

  static int _compareSetsByOrdinal(
    B02PreviousPerformanceSet first,
    B02PreviousPerformanceSet second,
  ) {
    final ordinal = first.ordinal.compareTo(second.ordinal);
    return ordinal != 0
        ? ordinal
        : first.performedSetId.compareTo(second.performedSetId);
  }

  static int _compareOccurrences(
    B02PreviousPerformanceOccurrence first,
    B02PreviousPerformanceOccurrence second,
  ) {
    final ordinal = first.exerciseOrdinal.compareTo(second.exerciseOrdinal);
    return ordinal != 0
        ? ordinal
        : first.performedExerciseId.compareTo(second.performedExerciseId);
  }

  static bool _sameDouble(double? first, double? second) =>
      first == second || (first == null && second == null);
}

class _JoinedHistoryRow {
  final WorkoutSession session;
  final PerformedExercise exercise;
  final PerformedSet set;

  const _JoinedHistoryRow({
    required this.session,
    required this.exercise,
    required this.set,
  });
}

class _SessionBuilder {
  final WorkoutSession session;
  final Map<String, _OccurrenceBuilder> occurrences = {};

  _SessionBuilder(this.session);
}

class _OccurrenceBuilder {
  final String performedExerciseId;
  final int exerciseOrdinal;
  final String actualExerciseId;
  final String actualExerciseNameSnapshot;
  final String status;
  final String? expectedExerciseId;
  final String? sourceExercisePrescriptionId;
  final String? substitutionReason;
  final List<B02PreviousPerformanceSet> sets = [];

  _OccurrenceBuilder({
    required this.performedExerciseId,
    required this.exerciseOrdinal,
    required this.actualExerciseId,
    required this.actualExerciseNameSnapshot,
    required this.status,
    required this.expectedExerciseId,
    required this.sourceExercisePrescriptionId,
    required this.substitutionReason,
  });

  B02PreviousPerformanceOccurrence freeze() => B02PreviousPerformanceOccurrence(
    performedExerciseId: performedExerciseId,
    exerciseOrdinal: exerciseOrdinal,
    actualExerciseId: actualExerciseId,
    actualExerciseNameSnapshot: actualExerciseNameSnapshot,
    status: status,
    expectedExerciseId: expectedExerciseId,
    sourceExercisePrescriptionId: sourceExercisePrescriptionId,
    substitutionReason: substitutionReason,
    sets: List.unmodifiable(sets),
  );
}
