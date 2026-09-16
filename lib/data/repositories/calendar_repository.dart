import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/local_schedule_date_service.dart';
import '../database/app_database.dart';
import '../services/b02_occurrence_snapshot_customizer.dart';
import 'calendar/handlers/occurrence_command_handler.dart';
import 'calendar/handlers/occurrence_customization_handlers.dart';
import 'calendar/handlers/occurrence_execution_handlers.dart';
import 'calendar/handlers/occurrence_scheduling_handlers.dart';
import 'calendar/occurrence_transition_validator.dart';

enum OccurrenceStatus {
  planned,
  rescheduled,
  inProgress,
  completed,
  partiallyCompleted,
  skipped,
  cancelled;

  String get dbValue => switch (this) {
    OccurrenceStatus.planned => 'planned',
    OccurrenceStatus.rescheduled => 'rescheduled',
    OccurrenceStatus.inProgress => 'inProgress',
    OccurrenceStatus.completed => 'completed',
    OccurrenceStatus.partiallyCompleted => 'partiallyCompleted',
    OccurrenceStatus.skipped => 'skipped',
    OccurrenceStatus.cancelled => 'cancelled',
  };

  bool get isTerminal => switch (this) {
    OccurrenceStatus.completed ||
    OccurrenceStatus.partiallyCompleted ||
    OccurrenceStatus.skipped ||
    OccurrenceStatus.cancelled => true,
    _ => false,
  };
}

enum SkipDisposition {
  keepPending('keepPending', 'pending'),
  advance('advance', 'bypassed');

  final String skipMode;
  final String progressionDisposition;

  const SkipDisposition(this.skipMode, this.progressionDisposition);
}

enum RepeatPurpose {
  makeUp('makeUp'),
  extra('extra');

  final String dbValue;

  const RepeatPurpose(this.dbValue);
}

enum CompletionKind {
  full('full'),
  partial('partial');

  final String dbValue;

  const CompletionKind(this.dbValue);
}

class InvalidOccurrenceTransitionException implements Exception {
  final String message;

  const InvalidOccurrenceTransitionException(this.message);

  @override
  String toString() => 'InvalidOccurrenceTransitionException: $message';
}

abstract class OccurrenceCommand {
  final String occurrenceId;
  final String commandId;
  final OccurrenceStatus expectedStatus;

  const OccurrenceCommand({
    required this.occurrenceId,
    required this.commandId,
    required this.expectedStatus,
  });
}

class RescheduleOccurrenceCommand extends OccurrenceCommand {
  final String effectiveLocalDate;
  final String effectiveTimezoneId;
  final String? reason;

  /// The UI must only submit this after the user confirms the selected move.
  /// The repository never shifts another occurrence or changes its ordinal.
  final bool confirmed;

  const RescheduleOccurrenceCommand({
    required super.occurrenceId,
    required super.commandId,
    required super.expectedStatus,
    required this.effectiveLocalDate,
    required this.effectiveTimezoneId,
    required this.confirmed,
    this.reason,
  });
}

class SkipOccurrenceCommand extends OccurrenceCommand {
  final SkipDisposition disposition;
  final String? reason;

  const SkipOccurrenceCommand({
    required super.occurrenceId,
    required super.commandId,
    required super.expectedStatus,
    required this.disposition,
    this.reason,
  });
}

class CancelOccurrenceCommand extends OccurrenceCommand {
  final String? reason;

  const CancelOccurrenceCommand({
    required super.occurrenceId,
    required super.commandId,
    required super.expectedStatus,
    this.reason,
  });
}

class RestoreOccurrenceCommand extends OccurrenceCommand {
  const RestoreOccurrenceCommand({
    required super.occurrenceId,
    required super.commandId,
    required super.expectedStatus,
  });
}

class RepeatOccurrenceCommand extends OccurrenceCommand {
  final String localDate;
  final String timezoneId;
  final RepeatPurpose purpose;

  const RepeatOccurrenceCommand({
    required super.occurrenceId,
    required super.commandId,
    required super.expectedStatus,
    required this.localDate,
    required this.timezoneId,
    required this.purpose,
  });
}

class StartOccurrenceCommand extends OccurrenceCommand {
  /// Past or future starts require an explicit confirmation. A current local
  /// date starts without an additional confirmation.
  final bool confirmedOutsideEffectiveDate;

  /// JSON-safe user context displayed by the player (for example personal
  /// setup values and cues). It is merged into the immutable execution
  /// snapshot in the same transaction that starts the occurrence and creates
  /// its draft. Template content itself remains owned by this repository.
  final Map<String, dynamic>? executionContext;

  const StartOccurrenceCommand({
    required super.occurrenceId,
    required super.commandId,
    required super.expectedStatus,
    this.confirmedOutsideEffectiveDate = false,
    this.executionContext,
  });
}

/// Applies a deliberately chosen edit to one unstarted occurrence's launch
/// snapshot. The program version, session template, prescription IDs, and
/// occurrence row identity remain unchanged.
class CustomizeOccurrenceCommand extends OccurrenceCommand {
  final String baseSnapshotJson;
  final List<OccurrenceExerciseCustomization> changes;

  const CustomizeOccurrenceCommand({
    required super.occurrenceId,
    required super.commandId,
    required super.expectedStatus,
    required this.baseSnapshotJson,
    required this.changes,
  });
}

/// Applies a chosen edit to an unstarted occurrence and cascades it across all
/// upcoming unstarted occurrences of the same session template in the active plan.
class CustomizeFutureOccurrencesCommand extends OccurrenceCommand {
  final String baseSnapshotJson;
  final List<OccurrenceExerciseCustomization> changes;

  const CustomizeFutureOccurrencesCommand({
    required super.occurrenceId,
    required super.commandId,
    required super.expectedStatus,
    required this.baseSnapshotJson,
    required this.changes,
  });
}

/// Resets customization by clearing executionSnapshotJson back to null,
/// restoring dynamic template resolution. Can apply to a single unstarted
/// occurrence or cascade across all upcoming unstarted occurrences.
class ResetOccurrenceCustomizationCommand extends OccurrenceCommand {
  final bool allFuture;

  const ResetOccurrenceCustomizationCommand({
    required super.occurrenceId,
    required super.commandId,
    required super.expectedStatus,
    this.allFuture = false,
  });
}

class FutureCustomizationResult {
  final int affectedCount;
  final OccurrenceMutationResult sourceResult;

  const FutureCustomizationResult({
    required this.affectedCount,
    required this.sourceResult,
  });
}

class DiscardStartedOccurrenceCommand extends OccurrenceCommand {
  const DiscardStartedOccurrenceCommand({
    required super.occurrenceId,
    required super.commandId,
    required super.expectedStatus,
  });
}

/// This guard is called by B01-09's finalization adapter *inside its one Drift
/// transaction* after it has inserted the linked session. It intentionally
/// does not save sets or delete a draft itself.
class CompleteOccurrenceCommand extends OccurrenceCommand {
  final int workoutSessionId;
  final CompletionKind completionKind;
  final String? reason;

  const CompleteOccurrenceCommand({
    required super.occurrenceId,
    required super.commandId,
    required super.expectedStatus,
    required this.workoutSessionId,
    required this.completionKind,
    this.reason,
  });
}

class OccurrenceMutationResult {
  final ScheduledSessionOccurrence occurrence;
  final OccurrenceEvent event;
  final bool wasIdempotent;

  const OccurrenceMutationResult({
    required this.occurrence,
    required this.event,
    required this.wasIdempotent,
  });
}

class RepeatOccurrenceResult {
  final ScheduledSessionOccurrence source;
  final ScheduledSessionOccurrence repeatedOccurrence;
  final OccurrenceEvent event;
  final bool wasIdempotent;

  const RepeatOccurrenceResult({
    required this.source,
    required this.repeatedOccurrence,
    required this.event,
    required this.wasIdempotent,
  });
}

/// The sole mutation owner for occurrence state and append-only event history.
/// It contains no player UI, preference substitution, travel coordination, or
/// progression cursor; next work is derived from durable occurrence rows.
class CalendarRepository {
  final AppDatabase _db;
  final LocalScheduleDateService _dates;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;
  final OccurrenceTransitionValidator validator;
  late final OccurrenceCommandDispatcher _dispatcher;
  late final CompleteOccurrenceHandler _completeOccurrenceHandler;

  AppDatabase get db => _db;
  LocalScheduleDateService get dates => _dates;
  Uuid get uuid => _uuid;
  DateTime Function() get nowUtc => _nowUtc;

  CalendarRepository(
    this._db, {
    LocalScheduleDateService? dates,
    Uuid? uuid,
    DateTime Function()? nowUtc,
    OccurrenceTransitionValidator? validator,
  }) : _dates = dates ?? LocalScheduleDateService(nowUtc: nowUtc),
       _uuid = uuid ?? const Uuid(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       validator = validator ?? const OccurrenceTransitionValidator() {
    _dispatcher = OccurrenceCommandDispatcher();
    _registerCommandHandlers();
  }

  void _registerCommandHandlers() {
    _dispatcher.register(RescheduleOccurrenceHandler(this));
    _dispatcher.register(SkipOccurrenceHandler(this));
    _dispatcher.register(CancelOccurrenceHandler(this));
    _dispatcher.register(RestoreOccurrenceHandler(this));
    _dispatcher.register(RepeatOccurrenceHandler(this));
    _dispatcher.register(StartOccurrenceHandler(this));
    _dispatcher.register(DiscardStartedOccurrenceHandler(this));
    _completeOccurrenceHandler = CompleteOccurrenceHandler(this);
    _dispatcher.register(_completeOccurrenceHandler);
    _dispatcher.register(CustomizeOccurrenceHandler(this));
    _dispatcher.register(CustomizeFutureOccurrencesHandler(this));
    _dispatcher.register(ResetOccurrenceCustomizationHandler(this));
  }

  Future<ScheduledSessionOccurrence?> getOccurrence(String occurrenceId) {
    return (_db.select(
      _db.scheduledSessionOccurrences,
    )..where((table) => table.id.equals(occurrenceId))).getSingleOrNull();
  }

  /// Reads the exact prescription snapshot that a scheduled occurrence would
  /// use at launch, without changing its lifecycle or creating a draft.
  ///
  /// A started occurrence already owns an immutable execution snapshot, so it
  /// is returned as-is even after the active plan changes. An unstarted
  /// occurrence with a prepared customization snapshot returns that exact
  /// prepared content, while still requiring the active-plan guard. A plain
  /// unstarted occurrence is projected through the same ancestry builder used
  /// by [start]; it is never rebuilt from display names.
  Future<String> readWorkoutPreviewSnapshot(String occurrenceId) async {
    final occurrence = await getOccurrence(occurrenceId);
    if (occurrence == null) {
      throw const InvalidOccurrenceTransitionException(
        'Workout was not found.',
      );
    }
    final existing = occurrence.executionSnapshotJson?.trim();
    if (existing != null && existing.isNotEmpty) {
      validator.decodeAndValidateOccurrenceSnapshot(existing, occurrence);
      if (occurrence.status == OccurrenceStatus.planned.dbValue ||
          occurrence.status == OccurrenceStatus.rescheduled.dbValue) {
        await requireActivePlan(occurrence);
      }
      return existing;
    }
    await requireActivePlan(occurrence);
    return buildExecutionSnapshot(occurrence);
  }

  /// Saves a per-occurrence launch snapshot without changing the published
  /// program or the occurrence's schedule/status. This is the only mutation
  /// path for the Training customization surface; it is intentionally
  /// unavailable after start or for terminal history.
  Future<OccurrenceMutationResult> customize(
    CustomizeOccurrenceCommand command,
  ) => _dispatcher.dispatch(command);

  /// Saves an occurrence launch snapshot and cascades it across all upcoming
  /// unstarted occurrences of the same template in the active plan.
  Future<FutureCustomizationResult> customizeFutureOccurrences(
    CustomizeFutureOccurrencesCommand command,
  ) => _dispatcher.dispatch(command);

  /// Resets customization by clearing executionSnapshotJson back to null,
  /// restoring dynamic template resolution. If [command.allFuture] is true,
  /// resets all upcoming unstarted occurrences of the same template.
  Future<FutureCustomizationResult> resetOccurrenceCustomization(
    ResetOccurrenceCustomizationCommand command,
  ) => _dispatcher.dispatch(command);

  Future<List<ScheduledSessionOccurrence>> getOccurrencesInLocalDateRange({
    required String startLocalDate,
    required String endLocalDate,
    bool includeTerminal = true,
  }) {
    final start = _dates.normalizeLocalDate(startLocalDate);
    final end = _dates.normalizeLocalDate(endLocalDate);
    if (_dates.compare(start, end) > 0) {
      throw ArgumentError(
        'Start local date must be on or before end local date.',
      );
    }
    final query = _db.select(_db.scheduledSessionOccurrences)
      ..where(
        (table) =>
            table.effectiveLocalDate.isBiggerOrEqualValue(start) &
            table.effectiveLocalDate.isSmallerOrEqualValue(end),
      )
      ..orderBy([
        (table) => OrderingTerm(expression: table.effectiveLocalDate),
        (table) => OrderingTerm(expression: table.programWeekOrdinal),
        (table) => OrderingTerm(expression: table.sessionOrdinal),
        (table) => OrderingTerm(expression: table.repeatOrdinal),
      ]);
    if (!includeTerminal) {
      query.where(
        (table) => table.status.isNotIn(const [
          'completed',
          'partiallyCompleted',
          'skipped',
          'cancelled',
        ]),
      );
    }
    return query.get();
  }

  Stream<List<ScheduledSessionOccurrence>> watchOccurrencesInLocalDateRange({
    required String startLocalDate,
    required String endLocalDate,
    bool includeTerminal = true,
  }) {
    final start = _dates.normalizeLocalDate(startLocalDate);
    final end = _dates.normalizeLocalDate(endLocalDate);
    if (_dates.compare(start, end) > 0) {
      throw ArgumentError(
        'Start local date must be on or before end local date.',
      );
    }
    final query = _db.select(_db.scheduledSessionOccurrences)
      ..where(
        (table) =>
            table.effectiveLocalDate.isBiggerOrEqualValue(start) &
            table.effectiveLocalDate.isSmallerOrEqualValue(end),
      )
      ..orderBy([
        (table) => OrderingTerm(expression: table.effectiveLocalDate),
        (table) => OrderingTerm(expression: table.programWeekOrdinal),
        (table) => OrderingTerm(expression: table.sessionOrdinal),
        (table) => OrderingTerm(expression: table.repeatOrdinal),
      ]);
    if (!includeTerminal) {
      query.where(
        (table) => table.status.isNotIn(const [
          'completed',
          'partiallyCompleted',
          'skipped',
          'cancelled',
        ]),
      );
    }
    return query.watch();
  }

  Future<List<OccurrenceEvent>> getOccurrenceHistory(String occurrenceId) {
    return (_db.select(_db.occurrenceEvents)
          ..where((table) => table.occurrenceId.equals(occurrenceId))
          ..orderBy([(table) => OrderingTerm(expression: table.occurredAtUtc)]))
        .get();
  }

  /// The lowest pending original ordinal is derived, never stored as a cursor.
  Future<ScheduledSessionOccurrence?> getNextRequiredOccurrence(
    String programVersionId,
  ) {
    return (_db.select(_db.scheduledSessionOccurrences)
          ..where(
            (table) =>
                table.programVersionId.equals(programVersionId) &
                table.repeatOrdinal.equals(0) &
                table.progressionDisposition.equals('pending'),
          )
          ..orderBy([
            (table) => OrderingTerm(expression: table.programWeekOrdinal),
            (table) => OrderingTerm(expression: table.sessionOrdinal),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<OccurrenceMutationResult> reschedule(
    RescheduleOccurrenceCommand command,
  ) => _dispatcher.dispatch(command);

  Future<OccurrenceMutationResult> skip(
    SkipOccurrenceCommand command,
  ) => _dispatcher.dispatch(command);

  Future<OccurrenceMutationResult> cancel(
    CancelOccurrenceCommand command,
  ) => _dispatcher.dispatch(command);

  Future<OccurrenceMutationResult> restore(
    RestoreOccurrenceCommand command,
  ) => _dispatcher.dispatch(command);

  Future<RepeatOccurrenceResult> repeat(
    RepeatOccurrenceCommand command,
  ) => _dispatcher.dispatch(command);

  Future<OccurrenceMutationResult> start(
    StartOccurrenceCommand command,
  ) => _dispatcher.dispatch(command);

  Future<OccurrenceMutationResult> discardStarted(
    DiscardStartedOccurrenceCommand command,
  ) => _dispatcher.dispatch(command);

  Future<OccurrenceMutationResult> completeWithPersistedSession(
    CompleteOccurrenceCommand command,
  ) => _dispatcher.dispatch(command);

  /// Completes an occurrence inside a transaction owned by the execution
  /// bridge. B01-09 uses this after inserting the linked session and sets and
  /// before deleting the draft last. Callers must already be in a Drift
  /// transaction; this method never persists a session or draft itself.
  Future<OccurrenceMutationResult> completeWithPersistedSessionInTransaction(
    CompleteOccurrenceCommand command,
  ) => _completeOccurrenceHandler.handleInTransaction(command);

  Future<OccurrenceMutationResult> idempotentResult(
    String occurrenceId,
    OccurrenceEvent event, {
    required String expectedEventType,
  }) async {
    if (event.eventType != expectedEventType) {
      throw const InvalidOccurrenceTransitionException(
        'This command ID belongs to a different occurrence action.',
      );
    }
    final occurrence = await getOccurrence(occurrenceId);
    if (occurrence == null) {
      throw const InvalidOccurrenceTransitionException(
        'Occurrence is missing.',
      );
    }
    return OccurrenceMutationResult(
      occurrence: occurrence,
      event: event,
      wasIdempotent: true,
    );
  }

  Future<OccurrenceEvent?> existingEvent(
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

  Future<ScheduledSessionOccurrence> requireCommandSource(
    OccurrenceCommand command,
  ) async {
    final occurrence = await getOccurrence(command.occurrenceId);
    if (occurrence == null) {
      throw const InvalidOccurrenceTransitionException(
        'Occurrence was not found.',
      );
    }
    if (occurrence.status != command.expectedStatus.dbValue) {
      validator.throwStale();
    }
    return occurrence;
  }

  Future<void> requireActivePlan(ScheduledSessionOccurrence occurrence) async {
    final settings = await (_db.select(
      _db.trainingPlanSettings,
    )..where((table) => table.id.equals(1))).getSingleOrNull();
    if (settings?.activeProgramVersionId != occurrence.programVersionId) {
      throw const InvalidOccurrenceTransitionException(
        'This workout is no longer part of the current training plan.',
      );
    }
  }

  Future<void> rejectStartedDependents(
    ScheduledSessionOccurrence occurrence,
  ) async {
    final repeated =
        await (_db.select(_db.scheduledSessionOccurrences)..where(
              (table) =>
                  table.repeatedFromOccurrenceId.equals(occurrence.id) &
                  table.status.isIn(const [
                    'inProgress',
                    'completed',
                    'partiallyCompleted',
                  ]),
            ))
            .get();
    if (repeated.isNotEmpty) {
      throw const InvalidOccurrenceTransitionException(
        'A started repeat prevents restoring its source occurrence.',
      );
    }
    if (occurrence.status == 'skipped' && occurrence.skipMode == 'advance') {
      final later =
          await (_db.select(_db.scheduledSessionOccurrences)..where(
                (table) =>
                    table.programVersionId.equals(occurrence.programVersionId) &
                    table.repeatOrdinal.equals(0) &
                    table.status.isIn(const [
                      'inProgress',
                      'completed',
                      'partiallyCompleted',
                    ]),
              ))
              .get();
      final hasStartedLaterOrdinal = later.any(
        (row) =>
            row.programWeekOrdinal > occurrence.programWeekOrdinal ||
            (row.programWeekOrdinal == occurrence.programWeekOrdinal &&
                row.sessionOrdinal > occurrence.sessionOrdinal),
      );
      if (hasStartedLaterOrdinal) {
        throw const InvalidOccurrenceTransitionException(
          'A later ordinal has started, so skip-and-advance cannot be restored.',
        );
      }
    }
  }

  Future<String> snapshotForStart(
    ScheduledSessionOccurrence occurrence, {
    Map<String, dynamic>? executionContext,
  }) async {
    // A customization is a prepared launch snapshot on the existing
    // occurrence row. Starting promotes it to the immutable execution
    // snapshot; it never rebuilds from the published template afterward.
    final stored = occurrence.executionSnapshotJson?.trim();
    if (stored == null || stored.isEmpty) {
      return buildExecutionSnapshot(
        occurrence,
        executionContext: executionContext,
      );
    }
    final snapshot =
        validator.decodeAndValidateOccurrenceSnapshot(stored, occurrence);
    if (executionContext != null) {
      snapshot['personalExerciseContext'] = executionContext;
      return jsonEncode(snapshot);
    }
    return stored;
  }

  Future<String> buildExecutionSnapshot(
    ScheduledSessionOccurrence occurrence, {
    Map<String, dynamic>? executionContext,
  }) async {
    final template =
        await (_db.select(_db.sessionTemplates)
              ..where((table) => table.id.equals(occurrence.sessionTemplateId)))
            .getSingleOrNull();
    final version =
        await (_db.select(_db.programVersions)
              ..where((table) => table.id.equals(occurrence.programVersionId)))
            .getSingleOrNull();
    if (template == null || version == null) {
      throw const InvalidOccurrenceTransitionException(
        'Occurrence template/version ancestry is missing.',
      );
    }
    final week =
        await (_db.select(_db.programWeeks)
              ..where((table) => table.id.equals(template.programWeekId)))
            .getSingleOrNull();
    if (week == null) {
      throw const InvalidOccurrenceTransitionException(
        'Occurrence program-week ancestry is missing.',
      );
    }
    final block =
        await (_db.select(_db.programBlocks)
              ..where((table) => table.id.equals(week.programBlockId)))
            .getSingleOrNull();
    if (block == null) {
      throw const InvalidOccurrenceTransitionException(
        'Occurrence program-block ancestry is missing.',
      );
    }
    final program = await (_db.select(
      _db.programs,
    )..where((table) => table.id.equals(version.programId))).getSingleOrNull();
    if (program == null) {
      throw const InvalidOccurrenceTransitionException(
        'Occurrence program ancestry is missing.',
      );
    }
    final prescriptions =
        await (_db.select(_db.exercisePrescriptions)
              ..where((table) => table.sessionTemplateId.equals(template.id))
              ..orderBy([(table) => OrderingTerm(expression: table.ordinal)]))
            .get();
    final groups =
        await (_db.select(_db.exerciseGroups)
              ..where((table) => table.sessionTemplateId.equals(template.id))
              ..orderBy([(table) => OrderingTerm(expression: table.ordinal)]))
            .get();
    final groupIds = groups.map((group) => group.id).toList();
    final groupMembers = groupIds.isEmpty
        ? <ExerciseGroupMember>[]
        : await (_db.select(_db.exerciseGroupMembers)
                ..where((table) => table.exerciseGroupId.isIn(groupIds))
                ..orderBy([(table) => OrderingTerm(expression: table.ordinal)]))
              .get();
    final strengthSetRows = prescriptions.isEmpty
        ? <StrengthSetPrescription>[]
        : await (_db.select(_db.strengthSetPrescriptions)
                ..where(
                  (table) => table.exercisePrescriptionId.isIn(
                    prescriptions.map((prescription) => prescription.id),
                  ),
                )
                ..orderBy([(table) => OrderingTerm(expression: table.ordinal)]))
              .get();
    final strengthSetsByPrescription =
        <String, List<StrengthSetPrescription>>{};
    for (final row in strengthSetRows) {
      (strengthSetsByPrescription[row.exercisePrescriptionId] ??= []).add(row);
    }
    final snapshot = <String, dynamic>{
      'version': 1,
      'occurrenceId': occurrence.id,
      'program': {
        'id': program.id,
        'name': program.name,
        'goal': program.goal,
        'notes': program.notes,
      },
      'programVersion': {
        'id': version.id,
        'versionNumber': version.versionNumber,
      },
      'block': {
        'ordinal': block.ordinal,
        'name': block.name,
        'description': block.description,
      },
      'week': {
        'ordinalInBlock': week.ordinalInBlock,
        'programWeekOrdinal': week.programWeekOrdinal,
        'name': week.name,
        'isDeload': week.isDeload,
      },
      'routineName': '${program.name} — ${template.name}',
      'template': {
        'id': template.id,
        'name': template.name,
        'plannedWeekday': template.plannedWeekday,
        'plannedStartMinute': template.plannedStartMinute,
        'notes': template.notes,
      },
      'prescriptions': prescriptions
          .map(
            (prescription) => {
              'id': prescription.id,
              'ordinal': prescription.ordinal,
              'exerciseId': prescription.exerciseId,
              'exerciseNameSnapshot': prescription.exerciseNameSnapshot,
              'plannedSets': prescription.plannedSets,
              'repsRange': prescription.repsRange,
              'strengthSetPrescriptions':
                  (strengthSetsByPrescription[prescription.id] ?? const [])
                      .map(
                        (set) => {
                          'id': set.id,
                          'exercisePrescriptionId': set.exercisePrescriptionId,
                          'ordinal': set.ordinal,
                          if (set.targetLoadKg != null)
                            'targetLoadKg': set.targetLoadKg,
                          if (set.loadBasis != null) 'loadBasis': set.loadBasis,
                          if (set.targetRepsMin != null)
                            'targetRepsMin': set.targetRepsMin,
                          if (set.targetRepsMax != null)
                            'targetRepsMax': set.targetRepsMax,
                          if (set.targetRpe != null) 'targetRpe': set.targetRpe,
                          if (set.restSeconds != null)
                            'restSeconds': set.restSeconds,
                          'technique': _snapshotTechnique(set),
                        },
                      )
                      .toList(),
            },
          )
          .toList(),
      'groups': groups
          .map(
            (group) => {
              'id': group.id,
              'ordinal': group.ordinal,
              'groupType': group.groupType,
              'roundCount': group.roundCount,
              'restAfterRoundSeconds': group.restAfterRoundSeconds,
              'label': group.label,
              'members': groupMembers
                  .where((member) => member.exerciseGroupId == group.id)
                  .map(
                    (member) => {
                      'id': member.id,
                      'exercisePrescriptionId': member.exercisePrescriptionId,
                      'ordinal': member.ordinal,
                      'transitionRestSeconds': member.transitionRestSeconds,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };
    if (executionContext != null) {
      snapshot['personalExerciseContext'] = executionContext;
    }
    return jsonEncode(snapshot);
  }

  Map<String, dynamic> _snapshotTechnique(StrengthSetPrescription row) {
    final payload = row.techniquePlanJson;
    if (payload != null && payload.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } on Object {
        // Fall through to the relational fields only when the payload is
        // absent. A present malformed payload must not be silently flattened.
        throw const InvalidOccurrenceTransitionException(
          'A strength prescription has invalid technique details.',
        );
      }
      throw const InvalidOccurrenceTransitionException(
        'A strength prescription has invalid technique details.',
      );
    }
    return {
      'effortMode': row.effortMode ?? 'standard',
      'endedAtFailure': false,
      'isDropSet': false,
      'isRestPause': false,
      if (row.tempoEccentricSeconds != null)
        'tempoEccentricSeconds': row.tempoEccentricSeconds,
      if (row.tempoBottomPauseSeconds != null)
        'tempoBottomPauseSeconds': row.tempoBottomPauseSeconds,
      if (row.tempoConcentricSeconds != null)
        'tempoConcentricSeconds': row.tempoConcentricSeconds,
      if (row.tempoLockoutPauseSeconds != null)
        'tempoLockoutPauseSeconds': row.tempoLockoutPauseSeconds,
      if (row.pausedRepPosition != null)
        'pausedRepPosition': row.pausedRepPosition,
      if (row.pausedRepSeconds != null)
        'pausedRepSeconds': row.pausedRepSeconds,
      if (row.assistanceMode != null) 'assistanceMode': row.assistanceMode,
      if (row.assistanceKg != null) 'assistanceKg': row.assistanceKg,
      'segments': const <dynamic>[],
    };
  }

  Future<OccurrenceEvent> insertEvent({
    required String occurrenceId,
    required String commandId,
    required String eventType,
    String? fromStatus,
    String? toStatus,
    String? beforeLocalDate,
    String? beforeTimezoneId,
    String? afterLocalDate,
    String? afterTimezoneId,
    String? reason,
    Map<String, dynamic>? metadata,
    DateTime? occurredAtUtc,
  }) async {
    final id = _uuid.v4();
    await _db
        .into(_db.occurrenceEvents)
        .insert(
          OccurrenceEventsCompanion.insert(
            id: id,
            occurrenceId: occurrenceId,
            commandId: commandId,
            eventType: eventType,
            fromStatus: Value(fromStatus),
            toStatus: Value(toStatus),
            beforeLocalDate: Value(beforeLocalDate),
            beforeTimezoneId: Value(beforeTimezoneId),
            afterLocalDate: Value(afterLocalDate),
            afterTimezoneId: Value(afterTimezoneId),
            reason: Value(_nullableTrim(reason)),
            metadataJson: Value(metadata == null ? null : jsonEncode(metadata)),
            occurredAtUtc: occurredAtUtc ?? _nowUtc().toUtc(),
          ),
        );
    return (await (_db.select(
      _db.occurrenceEvents,
    )..where((table) => table.id.equals(id))).getSingle());
  }

  bool isRepeatableTerminal(String status) =>
      validator.isTerminalStatus(status);

  static String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
