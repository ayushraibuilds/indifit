import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/fixtures/b02_execution_draft_codec.dart';
import '../database/app_database.dart';
import '../models/b02_execution_models.dart';

class B02ActivityDraftRecord {
  final int id;
  final B02ExecutionDraftState state;
  final DateTime updatedAtUtc;
  final String? scheduledOccurrenceId;

  const B02ActivityDraftRecord({
    required this.id,
    required this.state,
    required this.updatedAtUtc,
    required this.scheduledOccurrenceId,
  });
}

class B02TypedActivityHistoryRecord {
  final int sessionId;
  final String name;
  final B02ActivityType activityType;
  final B02ActivitySource source;
  final DateTime completedAtUtc;
  final int durationSeconds;
  final int estimatedCalories;
  final B02CardioSessionDetail? cardioDetail;
  final List<B02CardioInterval> cardioIntervals;
  final B02MobilitySessionDetail? mobilityDetail;
  final HealthProvenance? provenance;

  const B02TypedActivityHistoryRecord({
    required this.sessionId,
    required this.name,
    required this.activityType,
    required this.source,
    required this.completedAtUtc,
    required this.durationSeconds,
    required this.estimatedCalories,
    required this.cardioDetail,
    required this.cardioIntervals,
    required this.mobilityDetail,
    required this.provenance,
  });

  bool get isImported => source == B02ActivitySource.healthImport;

  bool get isImmutable => true;
}

class CardioSessionRepository {
  final AppDatabase _db;

  CardioSessionRepository(this._db);

  B02CardioSessionDetail validate(B02CardioSessionDetail detail) {
    if (detail.intervals.isNotEmpty && !detail.isIntervalWorkout) {
      throw const B02ValidationException(
        'Cardio intervals require interval-workout intent.',
      );
    }
    return detail;
  }

  Future<void> insertForSession({
    required int sessionId,
    required B02CardioSessionDetail detail,
  }) async {
    final validated = validate(detail);
    await _db
        .into(_db.cardioSessionDetails)
        .insert(
          CardioSessionDetailsCompanion.insert(
            sessionId: Value(sessionId),
            distanceMetres: Value(validated.distanceMetres),
            observedPaceSecondsPerKm: Value(validated.observedPaceSecondsPerKm),
            observedSpeedKph: Value(validated.observedSpeedKph),
            inclinePercentage: Value(validated.inclinePercentage),
            elevationMetres: Value(validated.elevationMetres),
            averageHeartRate: Value(validated.averageHeartRate),
            perceivedExertion: Value(validated.perceivedExertion),
            isIntervalWorkout: Value(validated.isIntervalWorkout),
            inputMode: Value(validated.inputMode.dbValue),
          ),
        );
    for (final interval in validated.intervals) {
      await _db
          .into(_db.cardioIntervals)
          .insert(
            CardioIntervalsCompanion.insert(
              id: interval.id,
              cardioSessionId: sessionId,
              ordinal: interval.ordinal,
              segmentType: interval.segmentType.dbValue,
              durationSeconds: Value(interval.durationSeconds),
              distanceMetres: Value(interval.distanceMetres),
              targetPaceSecondsPerKm: Value(interval.targetPaceSecondsPerKm),
              actualPaceSecondsPerKm: Value(interval.actualPaceSecondsPerKm),
              targetIntensity: Value(interval.targetIntensity),
              actualIntensity: Value(interval.actualIntensity),
              averageHeartRate: Value(interval.averageHeartRate),
            ),
          );
    }
  }

  Future<B02CardioSessionDetail?> readForSession({
    required int sessionId,
    required B02ActivityType activityType,
  }) async {
    final row = await (_db.select(
      _db.cardioSessionDetails,
    )..where((table) => table.sessionId.equals(sessionId))).getSingleOrNull();
    if (row == null) return null;
    final inputMode = row.inputMode;
    if (inputMode == null) {
      throw const B02ValidationException(
        'Canonical cardio detail has no input mode.',
      );
    }
    final intervals =
        await (_db.select(_db.cardioIntervals)
              ..where((table) => table.cardioSessionId.equals(sessionId))
              ..orderBy([(table) => OrderingTerm(expression: table.ordinal)]))
            .get();
    return B02CardioSessionDetail(
      activityType: activityType,
      durationSeconds: (await _readSessionDuration(sessionId)),
      distanceMetres: row.distanceMetres,
      observedPaceSecondsPerKm: row.observedPaceSecondsPerKm,
      observedSpeedKph: row.observedSpeedKph,
      inclinePercentage: row.inclinePercentage,
      elevationMetres: row.elevationMetres,
      averageHeartRate: row.averageHeartRate,
      perceivedExertion: row.perceivedExertion,
      isIntervalWorkout: row.isIntervalWorkout,
      inputMode: B02InputMode.parse(inputMode),
      intervals: intervals
          .map(
            (interval) => B02CardioInterval(
              id: interval.id,
              ordinal: interval.ordinal,
              segmentType: B02CardioSegmentType.parse(interval.segmentType),
              durationSeconds: interval.durationSeconds,
              distanceMetres: interval.distanceMetres,
              targetPaceSecondsPerKm: interval.targetPaceSecondsPerKm,
              actualPaceSecondsPerKm: interval.actualPaceSecondsPerKm,
              targetIntensity: interval.targetIntensity,
              actualIntensity: interval.actualIntensity,
              averageHeartRate: interval.averageHeartRate,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<int> _readSessionDuration(int sessionId) async {
    final session = await (_db.select(
      _db.workoutSessions,
    )..where((table) => table.id.equals(sessionId))).getSingleOrNull();
    if (session == null) {
      throw StateError('Activity session $sessionId was not found.');
    }
    return session.durationSeconds;
  }
}

class MobilitySessionRepository {
  final AppDatabase _db;

  MobilitySessionRepository(this._db);

  B02MobilitySessionDetail validate(B02MobilitySessionDetail detail) => detail;

  Future<void> insertForSession({
    required int sessionId,
    required B02MobilitySessionDetail detail,
  }) async {
    final validated = validate(detail);
    await _db
        .into(_db.mobilitySessionDetails)
        .insert(
          MobilitySessionDetailsCompanion.insert(
            sessionId: Value(sessionId),
            practiceType: validated.practiceType.dbValue,
            style: Value(validated.style),
            intensity: Value(validated.intensity),
            focusNote: Value(validated.focusNote),
            averageHeartRate: Value(validated.averageHeartRate),
          ),
        );
  }

  Future<B02MobilitySessionDetail?> readForSession({
    required int sessionId,
  }) async {
    final row = await (_db.select(
      _db.mobilitySessionDetails,
    )..where((table) => table.sessionId.equals(sessionId))).getSingleOrNull();
    if (row == null) return null;
    return B02MobilitySessionDetail(
      practiceType: B02ActivityType.parse(row.practiceType),
      durationSeconds: await _readSessionDuration(sessionId),
      style: row.style,
      intensity: row.intensity,
      focusNote: row.focusNote,
      averageHeartRate: row.averageHeartRate,
    );
  }

  Future<int> _readSessionDuration(int sessionId) async {
    final session = await (_db.select(
      _db.workoutSessions,
    )..where((table) => table.id.equals(sessionId))).getSingleOrNull();
    if (session == null) {
      throw StateError('Activity session $sessionId was not found.');
    }
    return session.durationSeconds;
  }
}

/// Owner of manual B02 activity drafts, typed modality details and immutable
/// activity-session completion. It never writes strength-set rows for cardio
/// or yoga/mobility records.
class ActivitySessionRepository {
  final AppDatabase _db;
  final Uuid _uuid;
  late final CardioSessionRepository cardio = CardioSessionRepository(_db);
  late final MobilitySessionRepository mobility = MobilitySessionRepository(
    _db,
  );

  ActivitySessionRepository(this._db, [Uuid? uuid])
    : _uuid = uuid ?? const Uuid();

  Future<B02ActivityDraftRecord> startManualDraft({
    required String routineName,
    required B02ActivityType activityType,
    B02CardioSessionDetail? cardioDetail,
    B02MobilitySessionDetail? mobilityDetail,
    DateTime? nowUtc,
  }) {
    return createManualDraft(
      routineName: routineName,
      activityType: activityType,
      cardioDetail: cardioDetail,
      mobilityDetail: mobilityDetail,
      nowUtc: nowUtc,
    );
  }

  Future<B02ActivityDraftRecord> createManualDraft({
    required String routineName,
    required B02ActivityType activityType,
    B02CardioSessionDetail? cardioDetail,
    B02MobilitySessionDetail? mobilityDetail,
    DateTime? nowUtc,
  }) async {
    final cleanName = _requiredName(routineName);
    _validateActivityDetails(
      activityType: activityType,
      cardioDetail: cardioDetail,
      mobilityDetail: mobilityDetail,
      expectedInputMode: B02InputMode.manual,
    );
    final now = (nowUtc ?? DateTime.now()).toUtc();
    final state = B02ExecutionDraftState(
      snapshotId: _uuid.v4(),
      snapshotVersion: 1,
      activityType: activityType,
      routineName: cleanName,
      elapsedSeconds: 0,
      currentExerciseOrdinal: 0,
      currentSetOrdinal: 0,
      cardioDetail: cardioDetail,
      mobilityDetail: mobilityDetail,
    );
    final id = await _db
        .into(_db.workoutDrafts)
        .insert(
          WorkoutDraftsCompanion.insert(
            routineName: cleanName,
            currentExerciseIndex: 0,
            currentSetIndex: 0,
            elapsedSeconds: 0,
            loggedSetsJson: '[]',
            updatedAt: Value(now),
            draftSchemaVersion: const Value(
              B02ExecutionDraftState.schemaVersion,
            ),
            activityType: Value(activityType.dbValue),
            executionStateJson: Value(B02ExecutionDraftCodec.encode(state)),
          ),
        );
    return B02ActivityDraftRecord(
      id: id,
      state: state,
      updatedAtUtc: now,
      scheduledOccurrenceId: null,
    );
  }

  Future<B02ActivityDraftRecord?> readDraft(int draftId) async {
    final row = await (_db.select(
      _db.workoutDrafts,
    )..where((table) => table.id.equals(draftId))).getSingleOrNull();
    if (row == null || row.executionStateJson == null) return null;
    final decoded = B02ExecutionDraftCodec.decode(row.executionStateJson!);
    if (!decoded.isCanonical) return null;
    return B02ActivityDraftRecord(
      id: row.id,
      state: decoded.state!,
      updatedAtUtc: row.updatedAt.toUtc(),
      scheduledOccurrenceId: row.scheduledOccurrenceId,
    );
  }

  Future<void> saveDraft({
    required int draftId,
    required B02ExecutionDraftState state,
    DateTime? nowUtc,
  }) async {
    _validateActivityDetails(
      activityType: state.activityType,
      cardioDetail: state.cardioDetail,
      mobilityDetail: state.mobilityDetail,
      expectedInputMode: B02InputMode.manual,
    );
    final now = (nowUtc ?? DateTime.now()).toUtc();
    final changed =
        await (_db.update(
          _db.workoutDrafts,
        )..where((table) => table.id.equals(draftId))).write(
          WorkoutDraftsCompanion(
            routineName: Value(state.routineName),
            currentExerciseIndex: Value(state.currentExerciseOrdinal),
            currentSetIndex: Value(state.currentSetOrdinal),
            elapsedSeconds: Value(state.elapsedSeconds),
            loggedSetsJson: const Value('[]'),
            updatedAt: Value(now),
            draftSchemaVersion: const Value(
              B02ExecutionDraftState.schemaVersion,
            ),
            activityType: Value(state.activityType.dbValue),
            executionStateJson: Value(B02ExecutionDraftCodec.encode(state)),
          ),
        );
    if (changed != 1) {
      throw StateError('Activity draft $draftId was not found.');
    }
  }

  Future<int> completeDraft(int draftId, {DateTime? completedAtUtc}) async {
    final draft = await readDraft(draftId);
    if (draft == null) {
      throw StateError('Canonical activity draft $draftId was not found.');
    }
    final state = draft.state;
    _validateActivityDetails(
      activityType: state.activityType,
      cardioDetail: state.cardioDetail,
      mobilityDetail: state.mobilityDetail,
      expectedInputMode: B02InputMode.manual,
    );
    final durationSeconds =
        state.cardioDetail?.durationSeconds ??
        state.mobilityDetail?.durationSeconds;
    if (durationSeconds == null || durationSeconds < 1) {
      throw const B02ValidationException(
        'A typed activity requires duration at completion.',
      );
    }
    final completed = (completedAtUtc ?? DateTime.now()).toUtc();

    return _complete(
      draftId: draftId,
      state: state,
      durationSeconds: durationSeconds,
      estimatedCalories: 0,
      completedAtUtc: completed,
      provenance: null,
    );
  }

  Future<int> completeImportedActivity({
    required B02ExecutionDraftState state,
    required String provider,
    required String sourceName,
    required String? externalId,
    required String fingerprint,
    int estimatedCalories = 0,
    DateTime? completedAtUtc,
  }) async {
    _validateActivityDetails(
      activityType: state.activityType,
      cardioDetail: state.cardioDetail,
      mobilityDetail: state.mobilityDetail,
      expectedInputMode: B02InputMode.healthImport,
    );
    final durationSeconds =
        state.cardioDetail?.durationSeconds ??
        state.mobilityDetail?.durationSeconds;
    if (durationSeconds == null || durationSeconds < 1) {
      throw const B02ValidationException(
        'A typed activity requires duration at completion.',
      );
    }
    return _complete(
      state: state,
      durationSeconds: durationSeconds,
      estimatedCalories: estimatedCalories,
      completedAtUtc: (completedAtUtc ?? DateTime.now()).toUtc(),
      provenance: _B02ProvenanceInput(
        provider: _requiredName(provider),
        sourceName: _requiredName(sourceName),
        externalId: externalId,
        fingerprint: _requiredName(fingerprint),
      ),
    );
  }

  Future<List<B02TypedActivityHistoryRecord>> readTypedHistory({
    B02ActivityType? activityType,
    int limit = 100,
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
    } else {
      query.where((table) => table.activityType.isNotIn(const ['legacy']));
    }
    final sessions = await query.get();
    return [for (final session in sessions) await _readHistoryRecord(session)];
  }

  Future<B02TypedActivityHistoryRecord?> readTypedActivity(
    int sessionId,
  ) async {
    final session = await (_db.select(
      _db.workoutSessions,
    )..where((table) => table.id.equals(sessionId))).getSingleOrNull();
    if (session == null) return null;
    final type = B02ActivityType.parse(session.activityType);
    if (type == B02ActivityType.legacy) return null;
    return _readHistoryRecord(session);
  }

  Future<int> _complete({
    int? draftId,
    required B02ExecutionDraftState state,
    required int durationSeconds,
    required int estimatedCalories,
    required DateTime completedAtUtc,
    required _B02ProvenanceInput? provenance,
  }) async {
    if (estimatedCalories < 0) {
      throw const B02ValidationException(
        'Estimated calories cannot be negative.',
      );
    }
    return _db.transaction(() async {
      final existing =
          await (_db.select(_db.workoutSessions)
                ..where((table) => table.uuid.equals(state.snapshotId)))
              .getSingleOrNull();
      if (existing != null) return existing.id;

      final sessionId = await _db
          .into(_db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              name: state.routineName,
              totalVolume: 0,
              durationSeconds: durationSeconds,
              estimatedCalories: estimatedCalories,
              completedAt: Value(completedAtUtc),
              isSynced: Value(provenance != null),
              uuid: Value(state.snapshotId),
              completionKind: const Value('full'),
              activityType: Value(state.activityType.dbValue),
              activitySchemaVersion: const Value(1),
              executionSnapshotJson: Value(
                B02ExecutionDraftCodec.encode(state),
              ),
            ),
          );
      if (state.cardioDetail != null) {
        await cardio.insertForSession(
          sessionId: sessionId,
          detail: state.cardioDetail!,
        );
      }
      if (state.mobilityDetail != null) {
        await mobility.insertForSession(
          sessionId: sessionId,
          detail: state.mobilityDetail!,
        );
      }
      if (provenance != null) {
        await _db
            .into(_db.healthProvenances)
            .insert(
              HealthProvenancesCompanion.insert(
                provider: provenance.provider,
                externalId: Value(provenance.externalId),
                sourceName: provenance.sourceName,
                localSessionId: Value(sessionId),
                fingerprint: provenance.fingerprint,
              ),
            );
      }
      if (draftId != null) {
        final deleted = await (_db.delete(
          _db.workoutDrafts,
        )..where((table) => table.id.equals(draftId))).go();
        if (deleted != 1) {
          throw StateError('Activity draft $draftId was not deleted.');
        }
      }
      return sessionId;
    });
  }

  Future<B02TypedActivityHistoryRecord> _readHistoryRecord(
    WorkoutSession session,
  ) async {
    final type = B02ActivityType.parse(session.activityType);
    final provenance =
        await (_db.select(_db.healthProvenances)
              ..where((table) => table.localSessionId.equals(session.id))
              ..limit(1))
            .getSingleOrNull();
    final cardioDetail =
        type == B02ActivityType.running ||
            type == B02ActivityType.cycling ||
            type == B02ActivityType.walking
        ? await cardio.readForSession(sessionId: session.id, activityType: type)
        : null;
    final mobilityDetail =
        type == B02ActivityType.yoga || type == B02ActivityType.mobility
        ? await mobility.readForSession(sessionId: session.id)
        : null;
    final intervals = cardioDetail == null
        ? const <B02CardioInterval>[]
        : cardioDetail.intervals;
    return B02TypedActivityHistoryRecord(
      sessionId: session.id,
      name: session.name,
      activityType: type,
      source: provenance == null
          ? B02ActivitySource.manual
          : B02ActivitySource.healthImport,
      completedAtUtc: session.completedAt.toUtc(),
      durationSeconds: session.durationSeconds,
      estimatedCalories: session.estimatedCalories,
      cardioDetail: cardioDetail,
      cardioIntervals: intervals,
      mobilityDetail: mobilityDetail,
      provenance: provenance,
    );
  }

  void _validateActivityDetails({
    required B02ActivityType activityType,
    required B02CardioSessionDetail? cardioDetail,
    required B02MobilitySessionDetail? mobilityDetail,
    required B02InputMode expectedInputMode,
  }) {
    final cardioTypes = {
      B02ActivityType.running,
      B02ActivityType.cycling,
      B02ActivityType.walking,
    };
    final mobilityTypes = {B02ActivityType.yoga, B02ActivityType.mobility};
    if (cardioTypes.contains(activityType)) {
      if (cardioDetail == null || cardioDetail.activityType != activityType) {
        throw const B02ValidationException(
          'Cardio completion requires matching cardio detail.',
        );
      }
      if (cardioDetail.inputMode != expectedInputMode) {
        throw B02ValidationException(
          'Cardio detail input mode must be ${expectedInputMode.dbValue}.',
        );
      }
      cardio.validate(cardioDetail);
      return;
    }
    if (mobilityTypes.contains(activityType)) {
      if (mobilityDetail == null ||
          mobilityDetail.practiceType != activityType) {
        throw const B02ValidationException(
          'Mobility completion requires matching practice detail.',
        );
      }
      if (expectedInputMode == B02InputMode.healthImport) {
        throw const B02ValidationException(
          'This Health mapping does not import yoga or mobility.',
        );
      }
      mobility.validate(mobilityDetail);
      return;
    }
    throw B02ValidationException(
      'Activity type ${activityType.dbValue} is outside the typed modality repository.',
    );
  }

  static String _requiredName(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, 'value', 'Must not be blank.');
    }
    return value.trim();
  }
}

class _B02ProvenanceInput {
  final String provider;
  final String sourceName;
  final String? externalId;
  final String fingerprint;

  const _B02ProvenanceInput({
    required this.provider,
    required this.sourceName,
    required this.externalId,
    required this.fingerprint,
  });
}
