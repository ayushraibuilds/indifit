import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/b02_execution_models.dart';

export '../models/b02_execution_models.dart' show B02HistoryRecordKind;

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
