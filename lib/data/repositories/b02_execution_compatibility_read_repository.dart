import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/b02_execution_models.dart';

export '../models/b02_execution_models.dart' show B02HistoryRecordKind;

/// Persisted strength-session detail used by review/history presentation.
///
/// This is deliberately a read model. It does not finalize, mutate, or infer
/// anything from display names. The repository reconstructs it from the
/// immutable B02 performed tables and preserves the exact IDs and ordinals
/// written by the execution authority.
class B02StrengthHistoryDetail {
  final int sessionId;
  final String name;
  final DateTime completedAt;
  final int durationSeconds;
  final String completionKind;
  final double totalVolumeKg;
  final String? scheduledOccurrenceId;
  final List<B02PerformedExerciseGroupHistory> groups;
  final List<B02PerformedExerciseHistory> exercises;

  const B02StrengthHistoryDetail({
    required this.sessionId,
    required this.name,
    required this.completedAt,
    required this.durationSeconds,
    required this.completionKind,
    required this.totalVolumeKg,
    required this.scheduledOccurrenceId,
    required this.groups,
    required this.exercises,
  });

  bool get isPartial => completionKind == 'partial';
}

class B02PerformedExerciseGroupHistory {
  final String id;
  final String groupType;
  final String? label;
  final int ordinal;
  final int plannedRounds;
  final int completedRounds;
  final String status;

  const B02PerformedExerciseGroupHistory({
    required this.id,
    required this.groupType,
    required this.label,
    required this.ordinal,
    required this.plannedRounds,
    required this.completedRounds,
    required this.status,
  });
}

class B02PerformedExerciseHistory {
  final String id;
  final String? performedExerciseGroupId;
  final String? sourceExercisePrescriptionId;
  final int? groupMemberOrdinal;
  final int? groupRoundOrdinal;
  final int ordinal;
  final String? expectedExerciseId;
  final String? expectedExerciseNameSnapshot;
  final String actualExerciseId;
  final String actualExerciseNameSnapshot;
  final String status;
  final String? substitutionReason;
  final List<B02PerformedSet> sets;
  final Map<String, List<B02SetSegment>> segmentsBySetId;

  const B02PerformedExerciseHistory({
    required this.id,
    required this.performedExerciseGroupId,
    required this.sourceExercisePrescriptionId,
    required this.groupMemberOrdinal,
    required this.groupRoundOrdinal,
    required this.ordinal,
    required this.expectedExerciseId,
    required this.expectedExerciseNameSnapshot,
    required this.actualExerciseId,
    required this.actualExerciseNameSnapshot,
    required this.status,
    required this.substitutionReason,
    required this.sets,
    this.segmentsBySetId = const {},
  });

  bool get wasSubstituted =>
      expectedExerciseId != null && actualExerciseId != expectedExerciseId;

  List<B02SetSegment> segmentsFor(B02PerformedSet set) =>
      segmentsBySetId[set.id] ?? const [];
}

/// Stable, read-only history contract shared by later B02 consumers.
///
/// Legacy rows expose only the information that exists in the old session/set
/// tables. Canonical rows expose counts from typed B02 tables. No field is
/// populated by inspecting a session or exercise display name.
class B02ActivityHistoryItem {
  final int sessionId;
  final String name;
  final B02ActivityType activityType;
  final B02HistoryRecordKind recordKind;
  final DateTime completedAt;
  final int durationSeconds;
  final String? scheduledOccurrenceId;
  final int legacySetCount;
  final int performedExerciseCount;
  final int performedGroupCount;
  final int cardioIntervalCount;
  final bool hasCardioDetail;
  final bool hasMobilityDetail;

  const B02ActivityHistoryItem({
    required this.sessionId,
    required this.name,
    required this.activityType,
    required this.recordKind,
    required this.completedAt,
    required this.durationSeconds,
    required this.scheduledOccurrenceId,
    required this.legacySetCount,
    required this.performedExerciseCount,
    required this.performedGroupCount,
    required this.cardioIntervalCount,
    required this.hasCardioDetail,
    required this.hasMobilityDetail,
  });

  bool get isLegacy => recordKind == B02HistoryRecordKind.legacyProjection;
  bool get isCanonical => recordKind == B02HistoryRecordKind.canonical;
}

/// Compatibility read contract for the transition from B01 session/set rows
/// to typed B02 activity records.
class B02ExecutionCompatibilityReadRepository {
  final AppDatabase _db;

  B02ExecutionCompatibilityReadRepository(this._db);

  Future<List<B02ActivityHistoryItem>> readHistory({
    B02ActivityType? activityType,
    int limit = 100,
    DateTime? completedAtStartUtc,
    DateTime? completedAtEndExclusiveUtc,
  }) async {
    if (limit < 1 || limit > 500) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 500.');
    }
    final query = _db.select(_db.workoutSessions)
      ..orderBy([
        (table) => OrderingTerm(
          expression: table.completedAt,
          mode: OrderingMode.desc,
        ),
      ])
      ..limit(limit);
    if (activityType != null) {
      query.where((table) => table.activityType.equals(activityType.dbValue));
    }
    if (completedAtStartUtc != null) {
      query.where(
        (table) =>
            table.completedAt.isBiggerOrEqualValue(completedAtStartUtc.toUtc()),
      );
    }
    if (completedAtEndExclusiveUtc != null) {
      query.where(
        (table) => table.completedAt.isSmallerThanValue(
          completedAtEndExclusiveUtc.toUtc(),
        ),
      );
    }
    final sessions = await query.get();
    return [for (final session in sessions) await _readSession(session)];
  }

  Future<B02ActivityHistoryItem?> readSession(int sessionId) async {
    final session = await (_db.select(
      _db.workoutSessions,
    )..where((table) => table.id.equals(sessionId))).getSingleOrNull();
    if (session == null) return null;
    return _readSession(session);
  }

  /// Reads the complete immutable strength result for a saved session.
  ///
  /// Unknown or malformed typed values are rejected instead of being shown as
  /// trusted evidence. Callers can still present the saved-state shell with a
  /// safe "some details unavailable" message.
  Future<B02StrengthHistoryDetail?> readStrengthSession(int sessionId) async {
    final session = await (_db.select(
      _db.workoutSessions,
    )..where((table) => table.id.equals(sessionId))).getSingleOrNull();
    if (session == null ||
        session.activityType != B02ActivityType.strength.dbValue) {
      return null;
    }

    final groupRows =
        await (_db.select(_db.performedExerciseGroups)
              ..where((table) => table.sessionId.equals(sessionId))
              ..orderBy([(table) => OrderingTerm.asc(table.ordinal)]))
            .get();
    final exerciseRows =
        await (_db.select(_db.performedExercises)
              ..where((table) => table.sessionId.equals(sessionId))
              ..orderBy([(table) => OrderingTerm.asc(table.ordinal)]))
            .get();
    final completionKind = session.completionKind ?? 'full';
    if (!const {'full', 'partial'}.contains(completionKind)) {
      throw const B02ValidationException(
        'Saved strength completion has an unsupported completion state.',
      );
    }
    final groupIds = groupRows.map((row) => row.id).toSet();
    for (final row in groupRows) {
      B02GroupType.parse(row.groupTypeSnapshot);
      if (!const {'inProgress', 'completed', 'partial'}.contains(row.status)) {
        throw const B02ValidationException(
          'Saved strength group has an unsupported status.',
        );
      }
    }
    for (final row in exerciseRows) {
      if (!const {
        'inProgress',
        'completed',
        'partial',
        'skipped',
      }.contains(row.status)) {
        throw const B02ValidationException(
          'Saved strength exercise has an unsupported status.',
        );
      }
      if (row.performedExerciseGroupId != null &&
          !groupIds.contains(row.performedExerciseGroupId)) {
        throw const B02ValidationException(
          'Saved strength exercise references an unknown group.',
        );
      }
      if (row.actualExerciseId.trim().isEmpty ||
          row.actualExerciseNameSnapshot.trim().isEmpty) {
        throw const B02ValidationException(
          'Saved strength exercise identity is incomplete.',
        );
      }
    }
    final exerciseIds = exerciseRows.map((row) => row.id).toList();
    final setRows = exerciseIds.isEmpty
        ? const <PerformedSet>[]
        : await (_db.select(_db.performedSets)
                ..where((table) => table.performedExerciseId.isIn(exerciseIds))
                ..orderBy([
                  (table) => OrderingTerm.asc(table.performedExerciseId),
                  (table) => OrderingTerm.asc(table.ordinal),
                ]))
              .get();
    final setIds = setRows.map((row) => row.id).toList();
    final segmentRows = setIds.isEmpty
        ? const <PerformedSetSegment>[]
        : await (_db.select(_db.performedSetSegments)
                ..where((table) => table.performedSetId.isIn(setIds))
                ..orderBy([
                  (table) => OrderingTerm.asc(table.performedSetId),
                  (table) => OrderingTerm.asc(table.ordinal),
                ]))
              .get();
    final segmentsBySet = <String, List<PerformedSetSegment>>{};
    for (final segment in segmentRows) {
      segmentsBySet.putIfAbsent(segment.performedSetId, () => []).add(segment);
    }
    final setsByExercise = <String, List<B02PerformedSet>>{};
    final segmentsByExercise = <String, Map<String, List<B02SetSegment>>>{};
    for (final row in setRows) {
      final persistedSegments = [
        for (final segment in segmentsBySet[row.id] ?? const [])
          _readSetSegment(segment),
      ];
      final converted = _readPerformedSet(row);
      setsByExercise
          .putIfAbsent(row.performedExerciseId, () => [])
          .add(converted);
      if (persistedSegments.isNotEmpty) {
        segmentsByExercise.putIfAbsent(
          row.performedExerciseId,
          () => {},
        )[row.id] = List.unmodifiable(
          persistedSegments,
        );
      }
    }

    return B02StrengthHistoryDetail(
      sessionId: session.id,
      name: session.name,
      completedAt: session.completedAt.toUtc(),
      durationSeconds: session.durationSeconds,
      completionKind: completionKind,
      totalVolumeKg: session.totalVolume,
      scheduledOccurrenceId: session.scheduledOccurrenceId,
      groups: [
        for (final row in groupRows)
          B02PerformedExerciseGroupHistory(
            id: row.id,
            groupType: B02GroupType.parse(row.groupTypeSnapshot).dbValue,
            label: row.labelSnapshot,
            ordinal: row.ordinal,
            plannedRounds: row.plannedRounds,
            completedRounds: row.completedRounds,
            status: row.status,
          ),
      ],
      exercises: [
        for (final row in exerciseRows)
          B02PerformedExerciseHistory(
            id: row.id,
            performedExerciseGroupId: row.performedExerciseGroupId,
            sourceExercisePrescriptionId: row.sourceExercisePrescriptionId,
            groupMemberOrdinal: row.groupMemberOrdinal,
            groupRoundOrdinal: row.groupRoundOrdinal,
            ordinal: row.ordinal,
            expectedExerciseId: row.expectedExerciseId,
            expectedExerciseNameSnapshot: row.expectedExerciseNameSnapshot,
            actualExerciseId: row.actualExerciseId,
            actualExerciseNameSnapshot: row.actualExerciseNameSnapshot,
            status: row.status,
            substitutionReason: row.substitutionReason,
            sets: List.unmodifiable(setsByExercise[row.id] ?? const []),
            segmentsBySetId: {
              for (final entry
                  in segmentsByExercise[row.id]?.entries ??
                      const <MapEntry<String, List<B02SetSegment>>>[])
                entry.key: entry.value,
            },
          ),
      ],
    );
  }

  B02PerformedSet _readPerformedSet(PerformedSet row) {
    return B02PerformedSet(
      id: row.id,
      performedExerciseId: row.performedExerciseId,
      ordinal: row.ordinal,
      role: B02SetRole.parse(row.role),
      targetLoadKg: row.targetLoadKg,
      targetLoadBasis: row.targetLoadBasis == null
          ? null
          : B02LoadBasis.parse(row.targetLoadBasis),
      targetRepsMin: row.targetRepsMin,
      targetRepsMax: row.targetRepsMax,
      targetRpe: row.targetRpe,
      actualLoadKg: row.actualLoadKg,
      actualLoadBasis: row.actualLoadBasis == null
          ? null
          : B02LoadBasis.parse(row.actualLoadBasis),
      actualReps: row.actualReps,
      actualRpe: row.actualRpe,
      technique: B02TechniqueFields(
        effortMode: row.effortMode == null
            ? B02EffortMode.standard
            : B02EffortMode.parse(row.effortMode),
        endedAtFailure: row.endedAtFailure,
        tempoEccentricSeconds: row.tempoEccentricSeconds,
        tempoBottomPauseSeconds: row.tempoBottomPauseSeconds,
        tempoConcentricSeconds: row.tempoConcentricSeconds,
        tempoLockoutPauseSeconds: row.tempoLockoutPauseSeconds,
        pausedRepPosition: row.pausedRepPosition == null
            ? null
            : B02PausedRepPosition.parse(row.pausedRepPosition),
        pausedRepSeconds: row.pausedRepSeconds,
        assistanceMode: row.assistanceMode == null
            ? null
            : B02AssistanceMode.parse(row.assistanceMode),
        assistanceKg: row.assistanceKg,
      ),
      notes: row.notes,
    );
  }

  B02SetSegment _readSetSegment(PerformedSetSegment segment) {
    return B02SetSegment(
      id: segment.id,
      ordinal: segment.ordinal,
      reps: segment.reps,
      externalLoadKg: segment.externalLoadKg,
      loadBasis: segment.loadBasis == null
          ? null
          : B02LoadBasis.parse(segment.loadBasis),
      assistanceKg: segment.assistanceKg,
      restBeforeSeconds: segment.restBeforeSeconds,
    );
  }

  Future<B02ActivityHistoryItem> _readSession(WorkoutSession session) async {
    final activityType = B02ActivityType.parse(session.activityType);
    if (activityType == B02ActivityType.legacy) {
      final legacySets = await (_db.select(
        _db.workoutSets,
      )..where((table) => table.sessionId.equals(session.id))).get();
      return B02ActivityHistoryItem(
        sessionId: session.id,
        name: session.name,
        activityType: activityType,
        recordKind: B02HistoryRecordKind.legacyProjection,
        completedAt: session.completedAt,
        durationSeconds: session.durationSeconds,
        scheduledOccurrenceId: session.scheduledOccurrenceId,
        legacySetCount: legacySets.length,
        performedExerciseCount: 0,
        performedGroupCount: 0,
        cardioIntervalCount: 0,
        hasCardioDetail: false,
        hasMobilityDetail: false,
      );
    }

    final performedExercises = await (_db.select(
      _db.performedExercises,
    )..where((table) => table.sessionId.equals(session.id))).get();
    final performedGroups = await (_db.select(
      _db.performedExerciseGroups,
    )..where((table) => table.sessionId.equals(session.id))).get();
    final cardioDetail = await (_db.select(
      _db.cardioSessionDetails,
    )..where((table) => table.sessionId.equals(session.id))).getSingleOrNull();
    final cardioIntervalCount = cardioDetail == null
        ? 0
        : (await (_db.select(
                    _db.cardioIntervals,
                  )..where((table) => table.cardioSessionId.equals(session.id)))
                  .get())
              .length;
    final mobilityDetail = await (_db.select(
      _db.mobilitySessionDetails,
    )..where((table) => table.sessionId.equals(session.id))).getSingleOrNull();

    return B02ActivityHistoryItem(
      sessionId: session.id,
      name: session.name,
      activityType: activityType,
      recordKind: B02HistoryRecordKind.canonical,
      completedAt: session.completedAt,
      durationSeconds: session.durationSeconds,
      scheduledOccurrenceId: session.scheduledOccurrenceId,
      legacySetCount: 0,
      performedExerciseCount: performedExercises.length,
      performedGroupCount: performedGroups.length,
      cardioIntervalCount: cardioIntervalCount,
      hasCardioDetail: cardioDetail != null,
      hasMobilityDetail: mobilityDetail != null,
    );
  }
}
