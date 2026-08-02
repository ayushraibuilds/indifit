import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/services/local_schedule_date_service.dart';
import '../database/app_database.dart';
import '../models/b02_execution_models.dart';
import '../models/b02_muscle_volume_models.dart';
import '../models/b02_progress_read_models.dart';
import 'b02_activity_session_repository.dart';
import 'b02_execution_compatibility_read_repository.dart';
import 'b02_muscle_volume_repository.dart';

/// Read source used by the controller. Keeping this interface small lets the
/// controller expose partial/recovery states without owning persistence.
abstract interface class B02ProgressReadSource {
  Future<List<B02ProgressActivityRecord>> readActivityHistory(
    B02ProgressQuery query,
  );

  Future<List<B02ProgressGroupHistory>> readGroupHistory(
    B02ProgressQuery query,
  );

  Future<List<B02ProgressTargetEvidence>> readTargetEvidence(
    B02ProgressQuery query,
  );

  Future<B02MuscleVolumeReadModel> readMuscleVolume(B02ProgressQuery query);
}

/// Composes the approved B02 read repositories into one progress-facing read
/// contract. It never writes, recommends, maps muscles, or infers a modality
/// from display text.
class B02ProgressReadRepository implements B02ProgressReadSource {
  final AppDatabase _db;
  final B02ExecutionCompatibilityReadRepository _compatibility;
  final ActivitySessionRepository _activitySessions;
  final B02MuscleVolumeRepository _muscleVolume;
  final LocalScheduleDateService _civilDates;

  B02ProgressReadRepository(
    this._db, {
    B02ExecutionCompatibilityReadRepository? compatibility,
    ActivitySessionRepository? activitySessions,
    B02MuscleVolumeRepository? muscleVolume,
    LocalScheduleDateService? civilDates,
  }) : _compatibility =
           compatibility ?? B02ExecutionCompatibilityReadRepository(_db),
       _activitySessions = activitySessions ?? ActivitySessionRepository(_db),
       _muscleVolume = muscleVolume ?? B02MuscleVolumeRepository(_db),
       _civilDates = civilDates ?? LocalScheduleDateService();

  Future<B02ProgressReadModel> read(B02ProgressQuery query) async {
    final results = await Future.wait<Object>([
      readActivityHistory(query),
      readGroupHistory(query),
      readTargetEvidence(query),
      readMuscleVolume(query),
    ]);
    return B02ProgressReadModel(
      query: query,
      activityHistory: results[0] as List<B02ProgressActivityRecord>,
      groupHistory: results[1] as List<B02ProgressGroupHistory>,
      targetEvidence: results[2] as List<B02ProgressTargetEvidence>,
      muscleVolume: results[3] as B02MuscleVolumeReadModel,
    );
  }

  @override
  Future<List<B02ProgressActivityRecord>> readActivityHistory(
    B02ProgressQuery query,
  ) async {
    final range = _resolveRange(query);
    final compatibility = await _compatibility.readHistory(
      limit: query.historyLimit,
      completedAtStartUtc: range.startUtc,
      completedAtEndExclusiveUtc: range.endExclusiveUtc,
    );
    final typed = await _activitySessions.readTypedHistory(
      limit: query.historyLimit,
      completedAtStartUtc: range.startUtc,
      completedAtEndExclusiveUtc: range.endExclusiveUtc,
    );
    final typedBySession = <int, B02TypedActivityHistoryRecord>{
      for (final record in typed) record.sessionId: record,
    };
    return [
      for (final item in compatibility)
        _toActivityRecord(item, typedBySession[item.sessionId]),
    ];
  }

  @override
  Future<List<B02ProgressGroupHistory>> readGroupHistory(
    B02ProgressQuery query,
  ) async {
    final range = _resolveRange(query);
    final groups = _db.performedExerciseGroups;
    final sessions = _db.workoutSessions;
    final groupRows =
        await (_db.select(groups).join([
                innerJoin(sessions, sessions.id.equalsExp(groups.sessionId)),
              ])
              ..where(
                sessions.activityType.equals(B02ActivityType.strength.dbValue),
              )
              ..where(sessions.completedAt.isBiggerOrEqualValue(range.startUtc))
              ..where(
                sessions.completedAt.isSmallerThanValue(range.endExclusiveUtc),
              )
              ..orderBy([
                OrderingTerm(
                  expression: sessions.completedAt,
                  mode: OrderingMode.desc,
                ),
                OrderingTerm.asc(groups.ordinal),
              ]))
            .get();
    if (groupRows.isEmpty) return const [];

    final groupIds = groupRows.map((row) => row.readTable(groups).id).toSet();
    final exerciseRows =
        await (_db.select(_db.performedExercises)
              ..where((table) => table.performedExerciseGroupId.isIn(groupIds))
              ..orderBy([
                (table) => OrderingTerm.asc(table.groupRoundOrdinal),
                (table) => OrderingTerm.asc(table.groupMemberOrdinal),
                (table) => OrderingTerm.asc(table.ordinal),
              ]))
            .get();
    final exerciseIds = exerciseRows.map((row) => row.id).toSet();
    final setRows = exerciseIds.isEmpty
        ? const <PerformedSet>[]
        : await (_db.select(_db.performedSets)
                ..where((table) => table.performedExerciseId.isIn(exerciseIds)))
              .get();
    final setsByExercise = <String, List<PerformedSet>>{};
    for (final set in setRows) {
      setsByExercise.putIfAbsent(set.performedExerciseId, () => []).add(set);
    }
    final exercisesByGroup = <String, List<PerformedExercise>>{};
    for (final exercise in exerciseRows) {
      final groupId = exercise.performedExerciseGroupId;
      if (groupId == null) continue;
      exercisesByGroup.putIfAbsent(groupId, () => []).add(exercise);
    }

    return [
      for (final joined in groupRows)
        _toGroupHistory(
          joined.readTable(groups),
          joined.readTable(sessions),
          exercisesByGroup[joined.readTable(groups).id] ?? const [],
          setsByExercise,
        ),
    ];
  }

  @override
  Future<List<B02ProgressTargetEvidence>> readTargetEvidence(
    B02ProgressQuery query,
  ) async {
    final range = _resolveRange(query);
    final exercises = _db.performedExercises;
    final sessions = _db.workoutSessions;
    final rows =
        await (_db.select(exercises).join([
                innerJoin(sessions, sessions.id.equalsExp(exercises.sessionId)),
              ])
              ..where(
                sessions.activityType.equals(B02ActivityType.strength.dbValue),
              )
              ..where(sessions.completedAt.isBiggerOrEqualValue(range.startUtc))
              ..where(
                sessions.completedAt.isSmallerThanValue(range.endExclusiveUtc),
              )
              ..orderBy([
                OrderingTerm(
                  expression: sessions.completedAt,
                  mode: OrderingMode.desc,
                ),
                OrderingTerm.asc(exercises.ordinal),
              ]))
            .get();
    if (rows.isEmpty) return const [];

    final performedExerciseIds = rows
        .map((row) => row.readTable(exercises).id)
        .toSet();
    final sets =
        await (_db.select(_db.performedSets)
              ..where(
                (table) => table.performedExerciseId.isIn(performedExerciseIds),
              )
              ..orderBy([
                (table) => OrderingTerm.asc(table.performedExerciseId),
                (table) => OrderingTerm.asc(table.ordinal),
              ]))
            .get();
    final setsByExercise = <String, List<PerformedSet>>{};
    for (final set in sets) {
      setsByExercise.putIfAbsent(set.performedExerciseId, () => []).add(set);
    }
    final recommendations =
        await (_db.select(_db.exerciseTargetRecommendations)..where(
              (table) => table.performedExerciseId.isIn(performedExerciseIds),
            ))
            .get();
    final recommendationsByExercise = <String, ExerciseTargetRecommendation>{
      for (final recommendation in recommendations)
        recommendation.performedExerciseId: recommendation,
    };

    return [
      for (final joined in rows)
        _toTargetEvidence(
          joined.readTable(exercises),
          joined.readTable(sessions),
          setsByExercise[joined.readTable(exercises).id] ?? const [],
          recommendationsByExercise[joined.readTable(exercises).id],
        ),
    ];
  }

  @override
  Future<B02MuscleVolumeReadModel> readMuscleVolume(B02ProgressQuery query) {
    return _muscleVolume.read(
      B02MuscleVolumeQuery(
        startLocalDate: query.startLocalDate,
        endLocalDate: query.endLocalDate,
        timezoneId: query.timezoneId,
      ),
    );
  }

  B02ProgressActivityRecord _toActivityRecord(
    B02ActivityHistoryItem item,
    B02TypedActivityHistoryRecord? typed,
  ) {
    return B02ProgressActivityRecord(
      sessionId: item.sessionId,
      name: item.name,
      activityType: item.activityType,
      recordKind: item.recordKind,
      completedAtUtc: item.completedAt.toUtc(),
      durationSeconds: item.durationSeconds,
      source: typed?.source,
      legacySetCount: item.legacySetCount,
      performedExerciseCount: item.performedExerciseCount,
      performedGroupCount: item.performedGroupCount,
      cardioIntervalCount: item.cardioIntervalCount,
      hasCardioDetail: item.hasCardioDetail,
      hasMobilityDetail: item.hasMobilityDetail,
      cardioDetail: typed?.cardioDetail,
      mobilityDetail: typed?.mobilityDetail,
    );
  }

  B02ProgressGroupHistory _toGroupHistory(
    PerformedExerciseGroup group,
    WorkoutSession session,
    List<PerformedExercise> exercises,
    Map<String, List<PerformedSet>> setsByExercise,
  ) {
    final members = [
      for (final exercise in exercises)
        _toGroupMember(exercise, setsByExercise[exercise.id] ?? const []),
    ];
    return B02ProgressGroupHistory(
      sessionId: session.id,
      sessionName: session.name,
      completedAtUtc: session.completedAt.toUtc(),
      groupId: group.id,
      groupType: B02GroupType.parse(group.groupTypeSnapshot),
      label: group.labelSnapshot,
      ordinal: group.ordinal,
      plannedRounds: group.plannedRounds,
      completedRounds: group.completedRounds,
      status: group.status,
      members: members,
    );
  }

  B02ProgressGroupMember _toGroupMember(
    PerformedExercise exercise,
    List<PerformedSet> sets,
  ) {
    return B02ProgressGroupMember(
      performedExerciseId: exercise.id,
      expectedExerciseId: exercise.expectedExerciseId,
      expectedExerciseName: exercise.expectedExerciseNameSnapshot,
      actualExerciseId: exercise.actualExerciseId,
      actualExerciseName: exercise.actualExerciseNameSnapshot,
      ordinal: exercise.ordinal,
      memberOrdinal: exercise.groupMemberOrdinal,
      roundOrdinal: exercise.groupRoundOrdinal,
      status: exercise.status,
      substitutionReason: exercise.substitutionReason,
      workingSetCount: sets
          .where((set) => set.role == B02SetRole.working.dbValue)
          .length,
      totalSetCount: sets.length,
    );
  }

  B02ProgressTargetEvidence _toTargetEvidence(
    PerformedExercise exercise,
    WorkoutSession session,
    List<PerformedSet> sets,
    ExerciseTargetRecommendation? recommendation,
  ) {
    return B02ProgressTargetEvidence(
      sessionId: session.id,
      completedAtUtc: session.completedAt.toUtc(),
      performedExerciseId: exercise.id,
      actualExerciseId: exercise.actualExerciseId,
      actualExerciseName: exercise.actualExerciseNameSnapshot,
      status: exercise.status,
      expectedExerciseName: exercise.expectedExerciseNameSnapshot,
      substitutionReason: exercise.substitutionReason,
      workingSetCount: sets
          .where((set) => set.role == B02SetRole.working.dbValue)
          .length,
      totalSetCount: sets.length,
      recommendation: recommendation == null
          ? null
          : _parseRecommendation(recommendation),
    );
  }

  B02TargetRecommendation _parseRecommendation(
    ExerciseTargetRecommendation row,
  ) {
    final completeness = jsonDecode(row.completenessJson);
    final rationale = jsonDecode(row.rationaleCodesJson);
    if (completeness is! Map || rationale is! List) {
      throw const B02ValidationException(
        'Persisted target evidence contains invalid JSON.',
      );
    }
    return B02TargetRecommendation.fromJson({
      'id': row.id,
      'performedExerciseId': row.performedExerciseId,
      'ruleVersion': row.ruleVersion,
      'confidence': row.confidence,
      'completeness': completeness.map((key, value) => MapEntry('$key', value)),
      if (row.recommendedLoadKg != null)
        'recommendedLoadKg': row.recommendedLoadKg,
      if (row.loadBasis != null) 'loadBasis': row.loadBasis,
      if (row.targetRepsMin != null) 'targetRepsMin': row.targetRepsMin,
      if (row.targetRepsMax != null) 'targetRepsMax': row.targetRepsMax,
      if (row.targetRpe != null) 'targetRpe': row.targetRpe,
      if (row.incrementKg != null) 'incrementKg': row.incrementKg,
      if (row.evidenceCutoffUtc != null)
        'evidenceCutoffUtc': row.evidenceCutoffUtc!.toUtc().toIso8601String(),
      'comparatorCount': row.comparatorCount,
      'rationaleCodes': rationale,
      'wasOverridden': row.wasOverridden,
    });
  }

  _ProgressUtcRange _resolveRange(B02ProgressQuery query) {
    if (query.historyLimit < 1 || query.historyLimit > 500) {
      throw ArgumentError.value(
        query.historyLimit,
        'historyLimit',
        'Must be between 1 and 500.',
      );
    }
    final start = _civilDates.normalizeLocalDate(query.startLocalDate);
    final end = _civilDates.normalizeLocalDate(query.endLocalDate);
    if (start.compareTo(end) > 0) {
      throw ArgumentError.value(
        query.endLocalDate,
        'endLocalDate',
        'Must not precede startLocalDate.',
      );
    }
    final location = _civilDates.locationFor(query.timezoneId);
    final startParts = _parseDate(start);
    final endParts = _parseDate(end);
    final startLocal = tz.TZDateTime(
      location,
      startParts.$1,
      startParts.$2,
      startParts.$3,
    );
    final endExclusiveLocal = tz.TZDateTime(
      location,
      endParts.$1,
      endParts.$2,
      endParts.$3 + 1,
    );
    return _ProgressUtcRange(
      startUtc: startLocal.toUtc(),
      endExclusiveUtc: endExclusiveLocal.toUtc(),
    );
  }

  (int, int, int) _parseDate(String value) {
    final parts = value.split('-').map(int.parse).toList(growable: false);
    return (parts[0], parts[1], parts[2]);
  }
}

class _ProgressUtcRange {
  final DateTime startUtc;
  final DateTime endExclusiveUtc;

  const _ProgressUtcRange({
    required this.startUtc,
    required this.endExclusiveUtc,
  });
}
