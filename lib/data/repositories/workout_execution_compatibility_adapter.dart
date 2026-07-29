import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/fixtures/workout_draft_codec.dart';
import '../database/app_database.dart';
import 'calendar_repository.dart';
import 'equipment_preference_repository.dart';
import 'travel_repository.dart';
import 'workout_repository.dart';

class ScheduledWorkoutRecoveryException implements Exception {
  final String message;

  const ScheduledWorkoutRecoveryException(this.message);

  @override
  String toString() => 'ScheduledWorkoutRecoveryException: $message';
}

class ScheduledWorkoutFinalizationException implements Exception {
  final String message;

  const ScheduledWorkoutFinalizationException(this.message);

  @override
  String toString() => 'ScheduledWorkoutFinalizationException: $message';
}

/// Player route data reconstructed only from the frozen occurrence snapshot.
/// It deliberately carries legacy-shaped exercises so the existing player and
/// name-based history APIs remain compatible during B01.
class WorkoutPlayerLaunchData {
  final String occurrenceId;
  final String routineName;
  final String executionSnapshotJson;
  final List<RoutineExercise> exercises;
  final Map<String, Map<String, dynamic>> personalExerciseContextByName;

  const WorkoutPlayerLaunchData({
    required this.occurrenceId,
    required this.routineName,
    required this.executionSnapshotJson,
    required this.exercises,
    required this.personalExerciseContextByName,
  });
}

/// Sole owner for scheduled workout launch/resume/finalization. It adapts the
/// existing single-draft player and name-based history without expanding
/// [WorkoutRepository] into a scheduling owner.
class WorkoutExecutionCompatibilityAdapter {
  final AppDatabase _db;
  final CalendarRepository _calendarRepo;
  final ExercisePreferenceRepository _preferenceRepo;
  final TravelRepository? _travelRepo;
  final Uuid _uuid;

  WorkoutExecutionCompatibilityAdapter({
    required AppDatabase db,
    required CalendarRepository calendarRepo,
    required ExercisePreferenceRepository preferenceRepo,
    TravelRepository? travelRepo,
    WorkoutRepository? workoutRepo,
    Uuid? uuid,
  }) : _db = db,
       _calendarRepo = calendarRepo,
       _preferenceRepo = preferenceRepo,
       _travelRepo = travelRepo,
       _uuid = uuid ?? const Uuid();

  Future<WorkoutPlayerLaunchData> startScheduledOccurrence({
    required String occurrenceId,
    required String commandId,
    bool confirmedOutsideEffectiveDate = false,
  }) async {
    final occurrence = await _requireOccurrence(occurrenceId);
    final result = await _calendarRepo.start(
      StartOccurrenceCommand(
        occurrenceId: occurrenceId,
        commandId: commandId,
        expectedStatus: _status(occurrence.status),
        confirmedOutsideEffectiveDate: confirmedOutsideEffectiveDate,
        executionContext: await _buildExecutionContext(occurrence),
      ),
    );
    final snapshot = result.occurrence.executionSnapshotJson;
    if (snapshot == null) {
      throw const ScheduledWorkoutRecoveryException(
        'Started occurrence has no execution snapshot.',
      );
    }
    return _launchFromSnapshot(
      occurrenceId: occurrenceId,
      snapshotJson: snapshot,
    );
  }

  /// Resume never starts or refreezes an occurrence. It only validates the
  /// persisted in-progress draft and reconstructs the player from its original
  /// snapshot.
  Future<WorkoutPlayerLaunchData> resumeScheduledDraft(
    WorkoutDraft draft,
  ) async {
    final occurrenceId = draft.scheduledOccurrenceId;
    if (occurrenceId == null) {
      throw const ScheduledWorkoutRecoveryException(
        'Draft is not linked to a scheduled occurrence.',
      );
    }
    // A corrupt set payload is a recoverable error, never implicit completion.
    WorkoutDraftCodec.decodeLoggedSets(draft.loggedSetsJson);
    final occurrence = await _requireOccurrence(occurrenceId);
    if (occurrence.status != OccurrenceStatus.inProgress.dbValue) {
      throw const ScheduledWorkoutRecoveryException(
        'Scheduled draft does not have an in-progress occurrence.',
      );
    }
    final snapshot =
        draft.executionSnapshotJson ?? occurrence.executionSnapshotJson;
    if (snapshot == null || snapshot != occurrence.executionSnapshotJson) {
      throw const ScheduledWorkoutRecoveryException(
        'Scheduled draft snapshot is missing or does not match its occurrence.',
      );
    }
    return _launchFromSnapshot(
      occurrenceId: occurrenceId,
      snapshotJson: snapshot,
    );
  }

  /// Inserts session, sets, event/status and deletes the exact linked draft in
  /// one transaction. A retry with the same command and payload returns the
  /// original session; a different command/payload is rejected.
  Future<int> finalizeScheduledWorkoutSession({
    required String occurrenceId,
    required String commandId,
    required String name,
    required double volume,
    required int durationSeconds,
    required int calories,
    required List<WorkoutSetsCompanion> sets,
    DateTime? completedAt,
    CompletionKind completionKind = CompletionKind.full,
    String? reason,
  }) async {
    if (commandId.trim().isEmpty) {
      throw ArgumentError.value(commandId, 'commandId', 'Must not be blank.');
    }
    final payload = _completionPayload(
      name: name,
      volume: volume,
      durationSeconds: durationSeconds,
      calories: calories,
      sets: sets,
      completedAt: completedAt,
      completionKind: completionKind,
      reason: reason,
    );
    return _db.transaction(() async {
      final existing = await _existingEvent(occurrenceId, commandId);
      if (existing != null) {
        return _existingCompletionResult(
          occurrenceId: occurrenceId,
          event: existing,
          payload: payload,
          completionKind: completionKind,
        );
      }
      final occurrence = await _requireOccurrence(occurrenceId);
      if (occurrence.status != OccurrenceStatus.inProgress.dbValue) {
        throw const ScheduledWorkoutFinalizationException(
          'Only an in-progress occurrence can be finalized.',
        );
      }
      final draft =
          await (_db.select(_db.workoutDrafts)..where(
                (table) => table.scheduledOccurrenceId.equals(occurrenceId),
              ))
              .getSingleOrNull();
      if (draft == null) {
        throw const ScheduledWorkoutRecoveryException(
          'The scheduled draft is missing; recover or discard explicitly.',
        );
      }
      try {
        WorkoutDraftCodec.decodeLoggedSets(draft.loggedSetsJson);
      } on FormatException catch (error) {
        throw ScheduledWorkoutRecoveryException(
          'The scheduled draft is invalid and cannot be finalized: $error',
        );
      }
      final snapshot = occurrence.executionSnapshotJson;
      if (snapshot == null || draft.executionSnapshotJson != snapshot) {
        throw const ScheduledWorkoutRecoveryException(
          'The scheduled execution snapshot is missing or inconsistent.',
        );
      }
      final existingSession =
          await (_db.select(_db.workoutSessions)..where(
                (table) => table.scheduledOccurrenceId.equals(occurrenceId),
              ))
              .getSingleOrNull();
      if (existingSession != null) {
        throw const ScheduledWorkoutFinalizationException(
          'This occurrence already has a persisted session.',
        );
      }
      final now = DateTime.now().toUtc();
      final sessionId = await _db
          .into(_db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              name: name.trim(),
              totalVolume: volume,
              durationSeconds: durationSeconds,
              estimatedCalories: calories,
              uuid: Value(_uuid.v4()),
              completedAt: Value((completedAt ?? now).toUtc()),
              scheduledOccurrenceId: Value(occurrenceId),
              executionSnapshotJson: Value(snapshot),
              executionTimezoneId: Value(occurrence.effectiveTimezoneId),
              completionKind: Value(completionKind.dbValue),
            ),
          );
      for (final set in _withSafeSnapshotExerciseIds(sets, snapshot)) {
        await _db
            .into(_db.workoutSets)
            .insert(
              set.copyWith(
                sessionId: Value(sessionId),
                uuid: Value(_uuid.v4()),
              ),
            );
      }
      final completion = await _calendarRepo
          .completeWithPersistedSessionInTransaction(
            CompleteOccurrenceCommand(
              occurrenceId: occurrenceId,
              commandId: commandId,
              expectedStatus: OccurrenceStatus.inProgress,
              workoutSessionId: sessionId,
              completionKind: completionKind,
              reason: reason,
            ),
          );
      await (_db.update(
        _db.occurrenceEvents,
      )..where((table) => table.id.equals(completion.event.id))).write(
        OccurrenceEventsCompanion(
          metadataJson: Value(
            jsonEncode({
              'workoutSessionId': sessionId,
              'completionKind': completionKind.dbValue,
              'payload': payload,
            }),
          ),
        ),
      );
      // Last durable mutation: no successful finalization ever leaves a draft.
      await (_db.delete(_db.workoutDrafts)..where(
            (table) =>
                table.id.equals(draft.id) &
                table.scheduledOccurrenceId.equals(occurrenceId),
          ))
          .go();
      return sessionId;
    });
  }

  Future<void> discardScheduledOccurrenceDraft({
    required String occurrenceId,
    required String commandId,
  }) async {
    final occurrence = await _requireOccurrence(occurrenceId);
    await _calendarRepo.discardStarted(
      DiscardStartedOccurrenceCommand(
        occurrenceId: occurrenceId,
        commandId: commandId,
        expectedStatus: _status(occurrence.status),
      ),
    );
  }

  Future<ScheduledSessionOccurrence> _requireOccurrence(String id) async {
    final occurrence = await _calendarRepo.getOccurrence(id);
    if (occurrence == null) {
      throw StateError('Scheduled occurrence $id was not found.');
    }
    return occurrence;
  }

  Future<Map<String, dynamic>> _buildExecutionContext(
    ScheduledSessionOccurrence occurrence,
  ) async {
    final prescriptions =
        await (_db.select(_db.exercisePrescriptions)
              ..where(
                (table) => table.sessionTemplateId.equals(
                  occurrence.sessionTemplateId,
                ),
              )
              ..orderBy([(table) => OrderingTerm(expression: table.ordinal)]))
            .get();
    final entries = <Map<String, dynamic>>[];
    for (final prescription in prescriptions) {
      final preference = prescription.exerciseId != null
          ? await _preferenceRepo.getPreference(
              stableId: prescription.exerciseId,
            )
          : await _preferenceRepo.getPreference(
              rawName: prescription.exerciseNameSnapshot,
            );
      entries.add({
        'prescriptionId': prescription.id,
        'exerciseId': prescription.exerciseId,
        'exerciseName': prescription.exerciseNameSnapshot,
        'generalNote': preference?.preference.generalNote,
        'setupValues':
            preference?.setupValues
                .map((value) => {'label': value.label, 'value': value.value})
                .toList() ??
            const [],
        'personalCues':
            preference?.personalCues.map((cue) => cue.cueText).toList() ??
            const [],
      });
    }
    final profile = _travelRepo == null
        ? null
        : await _travelRepo.resolveEffectiveProfile(
            occurrenceId: occurrence.id,
          );
    return {
      'version': 1,
      'exercises': entries,
      // This is immutable player provenance, not a new profile authority.
      'equipmentProfile': profile?.toSnapshotJson(),
    };
  }

  WorkoutPlayerLaunchData _launchFromSnapshot({
    required String occurrenceId,
    required String snapshotJson,
  }) {
    final decoded = _decodeSnapshot(snapshotJson);
    final routineName = decoded['routineName'];
    final prescriptions = decoded['prescriptions'];
    if (routineName is! String || prescriptions is! List) {
      throw const ScheduledWorkoutRecoveryException(
        'Execution snapshot lacks player data.',
      );
    }
    final exercises = <RoutineExercise>[];
    for (var index = 0; index < prescriptions.length; index++) {
      final raw = prescriptions[index];
      if (raw is! Map) {
        throw const ScheduledWorkoutRecoveryException(
          'Invalid prescription snapshot.',
        );
      }
      final map = Map<String, dynamic>.from(raw);
      final name = map['exerciseNameSnapshot'];
      final sets = map['plannedSets'];
      final reps = map['repsRange'];
      if (name is! String || sets is! int || reps is! String) {
        throw const ScheduledWorkoutRecoveryException(
          'Invalid prescription fields.',
        );
      }
      exercises.add(
        RoutineExercise(
          id: -(index + 1),
          dayId: 0,
          exerciseName: name,
          sets: sets,
          repsRange: reps,
          orderIndex: index,
        ),
      );
    }
    final contexts = <String, Map<String, dynamic>>{};
    final rawContext = decoded['personalExerciseContext'];
    if (rawContext is Map && rawContext['exercises'] is List) {
      for (final raw in rawContext['exercises'] as List) {
        if (raw is! Map) continue;
        final context = Map<String, dynamic>.from(raw);
        final name = context['exerciseName'];
        if (name is String && !contexts.containsKey(name)) {
          contexts[name] = context;
        }
      }
    }
    return WorkoutPlayerLaunchData(
      occurrenceId: occurrenceId,
      routineName: routineName,
      executionSnapshotJson: snapshotJson,
      exercises: exercises,
      personalExerciseContextByName: contexts,
    );
  }

  Future<int> _existingCompletionResult({
    required String occurrenceId,
    required OccurrenceEvent event,
    required String payload,
    required CompletionKind completionKind,
  }) async {
    final expectedType = completionKind == CompletionKind.full
        ? 'completed'
        : 'partiallyCompleted';
    if (event.eventType != expectedType || event.metadataJson == null) {
      throw const ScheduledWorkoutFinalizationException(
        'This command ID belongs to a different occurrence action.',
      );
    }
    final metadata = _decodeMetadata(event.metadataJson!);
    if (metadata['payload'] != payload ||
        metadata['completionKind'] != completionKind.dbValue) {
      throw const ScheduledWorkoutFinalizationException(
        'A retry must use the original completion payload.',
      );
    }
    final sessionId = metadata['workoutSessionId'];
    if (sessionId is! int) {
      throw const ScheduledWorkoutFinalizationException(
        'Completion event does not identify its session.',
      );
    }
    final session =
        await (_db.select(_db.workoutSessions)..where(
              (table) =>
                  table.id.equals(sessionId) &
                  table.scheduledOccurrenceId.equals(occurrenceId),
            ))
            .getSingleOrNull();
    if (session == null) {
      throw const ScheduledWorkoutFinalizationException(
        'Completion event/session ancestry is inconsistent.',
      );
    }
    return session.id;
  }

  Future<OccurrenceEvent?> _existingEvent(
    String occurrenceId,
    String commandId,
  ) {
    return (_db.select(_db.occurrenceEvents)..where(
          (table) =>
              table.occurrenceId.equals(occurrenceId) &
              table.commandId.equals(commandId),
        ))
        .getSingleOrNull();
  }

  List<WorkoutSetsCompanion> _withSafeSnapshotExerciseIds(
    List<WorkoutSetsCompanion> sets,
    String snapshotJson,
  ) {
    final byName = <String, String>{};
    final duplicates = <String>{};
    for (final raw
        in _decodeSnapshot(snapshotJson)['prescriptions'] as List? ??
            const []) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final name = map['exerciseNameSnapshot'];
      final id = map['exerciseId'];
      if (name is! String || id is! String || id.isEmpty) continue;
      if (byName.containsKey(name) && byName[name] != id) {
        duplicates.add(name);
      } else {
        byName[name] = id;
      }
    }
    return sets.map((set) {
      final name = set.exerciseName.value;
      final canBackfill =
          !set.exerciseId.present &&
          byName[name] != null &&
          !duplicates.contains(name);
      return canBackfill ? set.copyWith(exerciseId: Value(byName[name]!)) : set;
    }).toList();
  }

  static String _completionPayload({
    required String name,
    required double volume,
    required int durationSeconds,
    required int calories,
    required List<WorkoutSetsCompanion> sets,
    required DateTime? completedAt,
    required CompletionKind completionKind,
    required String? reason,
  }) => jsonEncode({
    'name': name.trim(),
    'volume': volume,
    'durationSeconds': durationSeconds,
    'calories': calories,
    'completedAt': completedAt?.toUtc().toIso8601String(),
    'completionKind': completionKind.dbValue,
    'reason': reason?.trim(),
    'sets': sets.map(_setPayload).toList(),
  });

  static Map<String, dynamic> _setPayload(WorkoutSetsCompanion set) => {
    'exerciseName': set.exerciseName.present ? set.exerciseName.value : null,
    'weight': set.weight.present ? set.weight.value : null,
    'reps': set.reps.present ? set.reps.value : null,
    'setNumber': set.setNumber.present ? set.setNumber.value : null,
    'isPr': set.isPr.present ? set.isPr.value : null,
    'rpe': set.rpe.present ? set.rpe.value : null,
    'isWarmUp': set.isWarmUp.present ? set.isWarmUp.value : null,
    'setType': set.setType.present ? set.setType.value : null,
    'setNotes': set.setNotes.present ? set.setNotes.value : null,
    'durationSeconds': set.durationSeconds.present
        ? set.durationSeconds.value
        : null,
    'distanceKm': set.distanceKm.present ? set.distanceKm.value : null,
    'inclinePercentage': set.inclinePercentage.present
        ? set.inclinePercentage.value
        : null,
    'exerciseId': set.exerciseId.present ? set.exerciseId.value : null,
  };

  static Map<String, dynamic> _decodeSnapshot(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) {
        throw const FormatException('Snapshot must be an object.');
      }
      return Map<String, dynamic>.from(decoded);
    } catch (error) {
      throw ScheduledWorkoutRecoveryException(
        'Execution snapshot is invalid: $error',
      );
    }
  }

  static Map<String, dynamic> _decodeMetadata(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) {
        throw const FormatException('Metadata must be an object.');
      }
      return Map<String, dynamic>.from(decoded);
    } catch (error) {
      throw ScheduledWorkoutFinalizationException(
        'Completion metadata is invalid: $error',
      );
    }
  }

  static OccurrenceStatus _status(String dbValue) =>
      OccurrenceStatus.values.firstWhere((status) => status.dbValue == dbValue);
}
