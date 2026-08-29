import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/fixtures/workout_draft_codec.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../database/app_database.dart';
import '../services/b02_occurrence_snapshot_customizer.dart';

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

  CalendarRepository(
    this._db, {
    LocalScheduleDateService? dates,
    Uuid? uuid,
    DateTime Function()? nowUtc,
  }) : _dates = dates ?? LocalScheduleDateService(nowUtc: nowUtc),
       _uuid = uuid ?? const Uuid(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

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
      _decodeAndValidateOccurrenceSnapshot(existing, occurrence);
      if (occurrence.status == OccurrenceStatus.planned.dbValue ||
          occurrence.status == OccurrenceStatus.rescheduled.dbValue) {
        await _requireActivePlan(occurrence);
      }
      return existing;
    }
    await _requireActivePlan(occurrence);
    return _buildExecutionSnapshot(occurrence);
  }

  /// Saves a per-occurrence launch snapshot without changing the published
  /// program or the occurrence's schedule/status. This is the only mutation
  /// path for the Training customization surface; it is intentionally
  /// unavailable after start or for terminal history.
  Future<OccurrenceMutationResult> customize(
    CustomizeOccurrenceCommand command,
  ) async {
    _validateCommand(command);
    if (command.expectedStatus != OccurrenceStatus.planned &&
        command.expectedStatus != OccurrenceStatus.rescheduled) {
      throw const InvalidOccurrenceTransitionException(
        'Only an unstarted workout can be customized.',
      );
    }
    if (command.baseSnapshotJson.trim().isEmpty || command.changes.isEmpty) {
      throw const InvalidOccurrenceTransitionException(
        'Choose a workout change before saving.',
      );
    }
    return _db.transaction(() async {
      final existing = await _existingEvent(
        command.occurrenceId,
        command.commandId,
      );
      if (existing != null) {
        return _idempotentResult(
          command.occurrenceId,
          existing,
          expectedEventType: 'customized',
        );
      }
      final occurrence = await _requireCommandSource(command);
      await _requireActivePlan(occurrence);
      _requireUnstarted(occurrence, 'customize');

      final currentSnapshot = occurrence.executionSnapshotJson?.trim();
      final baseSnapshot = currentSnapshot == null || currentSnapshot.isEmpty
          ? await _buildExecutionSnapshot(occurrence)
          : currentSnapshot;
      if (baseSnapshot != command.baseSnapshotJson) _throwStale();
      _decodeAndValidateOccurrenceSnapshot(baseSnapshot, occurrence);

      final canonicalExercises = await (_db.select(_db.exercises)).get();
      final canonicalById = <String, String>{
        for (final exercise in canonicalExercises)
          if (exercise.stableId?.trim().isNotEmpty == true &&
              exercise.name.trim().isNotEmpty)
            exercise.stableId!.trim(): exercise.name.trim(),
      };
      final customizedSnapshot = const B02OccurrenceSnapshotCustomizer().apply(
        snapshotJson: baseSnapshot,
        occurrenceId: occurrence.id,
        changes: command.changes,
        canonicalExercises: canonicalById,
      );
      final changed =
          await (_db.update(_db.scheduledSessionOccurrences)..where(
                (table) =>
                    table.id.equals(occurrence.id) &
                    table.status.equals(command.expectedStatus.dbValue),
              ))
              .write(
                ScheduledSessionOccurrencesCompanion(
                  executionSnapshotJson: Value(customizedSnapshot),
                ),
              );
      if (changed != 1) _throwStale();
      final event = await _insertEvent(
        occurrenceId: occurrence.id,
        commandId: command.commandId,
        eventType: 'customized',
        fromStatus: occurrence.status,
        toStatus: occurrence.status,
        beforeLocalDate: occurrence.effectiveLocalDate,
        beforeTimezoneId: occurrence.effectiveTimezoneId,
        afterLocalDate: occurrence.effectiveLocalDate,
        afterTimezoneId: occurrence.effectiveTimezoneId,
        metadata: {
          'snapshotVersion': 1,
          'prescriptionIds': [
            for (final change in command.changes) change.prescriptionId,
          ],
        },
        occurredAtUtc: _nowUtc().toUtc(),
      );
      return OccurrenceMutationResult(
        occurrence: (await getOccurrence(occurrence.id))!,
        event: event,
        wasIdempotent: false,
      );
    });
  }

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
  ) async {
    _validateCommand(command);
    final newDate = _dates.normalizeLocalDate(command.effectiveLocalDate);
    _dates.validateTimezone(command.effectiveTimezoneId);
    if (!command.confirmed) {
      throw const InvalidOccurrenceTransitionException(
        'Rescheduling requires an explicit confirmation.',
      );
    }
    return _db.transaction(() async {
      final existing = await _existingEvent(
        command.occurrenceId,
        command.commandId,
      );
      if (existing != null) {
        return _idempotentResult(
          command.occurrenceId,
          existing,
          expectedEventType: 'rescheduled',
        );
      }
      final occurrence = await _requireCommandSource(command);
      await _requireActivePlan(occurrence);
      _requireUnstarted(occurrence, 'reschedule');
      final targetStatus =
          occurrence.originalLocalDate == newDate &&
              occurrence.originalTimezoneId == command.effectiveTimezoneId
          ? OccurrenceStatus.planned
          : OccurrenceStatus.rescheduled;
      final changed =
          await (_db.update(_db.scheduledSessionOccurrences)..where(
                (table) =>
                    table.id.equals(occurrence.id) &
                    table.status.equals(command.expectedStatus.dbValue) &
                    table.effectiveLocalDate.equals(
                      occurrence.effectiveLocalDate,
                    ) &
                    table.effectiveTimezoneId.equals(
                      occurrence.effectiveTimezoneId,
                    ),
              ))
              .write(
                ScheduledSessionOccurrencesCompanion(
                  status: Value(targetStatus.dbValue),
                  effectiveLocalDate: Value(newDate),
                  effectiveTimezoneId: Value(command.effectiveTimezoneId),
                ),
              );
      if (changed != 1) _throwStale();
      final event = await _insertEvent(
        occurrenceId: occurrence.id,
        commandId: command.commandId,
        eventType: 'rescheduled',
        fromStatus: occurrence.status,
        toStatus: targetStatus.dbValue,
        beforeLocalDate: occurrence.effectiveLocalDate,
        beforeTimezoneId: occurrence.effectiveTimezoneId,
        afterLocalDate: newDate,
        afterTimezoneId: command.effectiveTimezoneId,
        reason: command.reason,
      );
      return OccurrenceMutationResult(
        occurrence: (await getOccurrence(occurrence.id))!,
        event: event,
        wasIdempotent: false,
      );
    });
  }

  Future<OccurrenceMutationResult> skip(SkipOccurrenceCommand command) async {
    _validateCommand(command);
    return _db.transaction(() async {
      final existing = await _existingEvent(
        command.occurrenceId,
        command.commandId,
      );
      if (existing != null) {
        return _idempotentResult(
          command.occurrenceId,
          existing,
          expectedEventType: 'skipped',
        );
      }
      final occurrence = await _requireCommandSource(command);
      await _requireActivePlan(occurrence);
      _requireUnstarted(occurrence, 'skip');
      final changed =
          await (_db.update(_db.scheduledSessionOccurrences)..where(
                (table) =>
                    table.id.equals(occurrence.id) &
                    table.status.equals(command.expectedStatus.dbValue),
              ))
              .write(
                ScheduledSessionOccurrencesCompanion(
                  status: const Value('skipped'),
                  progressionDisposition: Value(
                    command.disposition.progressionDisposition,
                  ),
                  skipMode: Value(command.disposition.skipMode),
                  terminalAtUtc: Value(_nowUtc().toUtc()),
                ),
              );
      if (changed != 1) _throwStale();
      final event = await _insertEvent(
        occurrenceId: occurrence.id,
        commandId: command.commandId,
        eventType: 'skipped',
        fromStatus: occurrence.status,
        toStatus: OccurrenceStatus.skipped.dbValue,
        beforeLocalDate: occurrence.effectiveLocalDate,
        beforeTimezoneId: occurrence.effectiveTimezoneId,
        afterLocalDate: occurrence.effectiveLocalDate,
        afterTimezoneId: occurrence.effectiveTimezoneId,
        reason: command.reason,
        metadata: {'skipMode': command.disposition.skipMode},
      );
      return OccurrenceMutationResult(
        occurrence: (await getOccurrence(occurrence.id))!,
        event: event,
        wasIdempotent: false,
      );
    });
  }

  Future<OccurrenceMutationResult> cancel(
    CancelOccurrenceCommand command,
  ) async {
    _validateCommand(command);
    return _db.transaction(() async {
      final existing = await _existingEvent(
        command.occurrenceId,
        command.commandId,
      );
      if (existing != null) {
        return _idempotentResult(
          command.occurrenceId,
          existing,
          expectedEventType: 'cancelled',
        );
      }
      final occurrence = await _requireCommandSource(command);
      await _requireActivePlan(occurrence);
      _requireUnstarted(occurrence, 'cancel');
      final changed =
          await (_db.update(_db.scheduledSessionOccurrences)..where(
                (table) =>
                    table.id.equals(occurrence.id) &
                    table.status.equals(command.expectedStatus.dbValue),
              ))
              .write(
                ScheduledSessionOccurrencesCompanion(
                  status: const Value('cancelled'),
                  progressionDisposition: const Value('pending'),
                  terminalAtUtc: Value(_nowUtc().toUtc()),
                ),
              );
      if (changed != 1) _throwStale();
      final event = await _insertEvent(
        occurrenceId: occurrence.id,
        commandId: command.commandId,
        eventType: 'cancelled',
        fromStatus: occurrence.status,
        toStatus: OccurrenceStatus.cancelled.dbValue,
        beforeLocalDate: occurrence.effectiveLocalDate,
        beforeTimezoneId: occurrence.effectiveTimezoneId,
        afterLocalDate: occurrence.effectiveLocalDate,
        afterTimezoneId: occurrence.effectiveTimezoneId,
        reason: command.reason,
      );
      return OccurrenceMutationResult(
        occurrence: (await getOccurrence(occurrence.id))!,
        event: event,
        wasIdempotent: false,
      );
    });
  }

  Future<OccurrenceMutationResult> restore(
    RestoreOccurrenceCommand command,
  ) async {
    _validateCommand(command);
    if (command.expectedStatus != OccurrenceStatus.skipped &&
        command.expectedStatus != OccurrenceStatus.cancelled) {
      throw const InvalidOccurrenceTransitionException(
        'Only skipped and cancelled occurrences can be restored.',
      );
    }
    return _db.transaction(() async {
      final existing = await _existingEvent(
        command.occurrenceId,
        command.commandId,
      );
      if (existing != null) {
        return _idempotentResult(
          command.occurrenceId,
          existing,
          expectedEventType: 'restored',
        );
      }
      final occurrence = await _requireCommandSource(command);
      await _requireActivePlan(occurrence);
      await _rejectStartedDependents(occurrence);
      final restoredStatus =
          occurrence.originalLocalDate == occurrence.effectiveLocalDate &&
              occurrence.originalTimezoneId == occurrence.effectiveTimezoneId
          ? OccurrenceStatus.planned
          : OccurrenceStatus.rescheduled;
      final changed =
          await (_db.update(_db.scheduledSessionOccurrences)..where(
                (table) =>
                    table.id.equals(occurrence.id) &
                    table.status.equals(command.expectedStatus.dbValue),
              ))
              .write(
                ScheduledSessionOccurrencesCompanion(
                  status: Value(restoredStatus.dbValue),
                  progressionDisposition: const Value('pending'),
                  skipMode: const Value(null),
                  terminalAtUtc: const Value(null),
                ),
              );
      if (changed != 1) _throwStale();
      final event = await _insertEvent(
        occurrenceId: occurrence.id,
        commandId: command.commandId,
        eventType: 'restored',
        fromStatus: occurrence.status,
        toStatus: restoredStatus.dbValue,
        beforeLocalDate: occurrence.effectiveLocalDate,
        beforeTimezoneId: occurrence.effectiveTimezoneId,
        afterLocalDate: occurrence.effectiveLocalDate,
        afterTimezoneId: occurrence.effectiveTimezoneId,
      );
      return OccurrenceMutationResult(
        occurrence: (await getOccurrence(occurrence.id))!,
        event: event,
        wasIdempotent: false,
      );
    });
  }

  Future<RepeatOccurrenceResult> repeat(RepeatOccurrenceCommand command) async {
    _validateCommand(command);
    final date = _dates.normalizeLocalDate(command.localDate);
    _dates.validateTimezone(command.timezoneId);
    return _db.transaction(() async {
      final existing = await _existingEvent(
        command.occurrenceId,
        command.commandId,
      );
      if (existing != null) {
        if (existing.eventType != 'repeatCreated' ||
            existing.metadataJson == null) {
          throw const InvalidOccurrenceTransitionException(
            'This command ID belongs to a different occurrence action.',
          );
        }
        final metadata =
            jsonDecode(existing.metadataJson!) as Map<String, dynamic>;
        final repeatedId = metadata['repeatedOccurrenceId'];
        if (repeatedId is! String) {
          throw const InvalidOccurrenceTransitionException(
            'Repeat event metadata is invalid.',
          );
        }
        final source = (await getOccurrence(command.occurrenceId))!;
        final repeated = await getOccurrence(repeatedId);
        if (repeated == null) {
          throw const InvalidOccurrenceTransitionException(
            'Repeated occurrence is missing.',
          );
        }
        return RepeatOccurrenceResult(
          source: source,
          repeatedOccurrence: repeated,
          event: existing,
          wasIdempotent: true,
        );
      }
      final source = await _requireCommandSource(command);
      await _requireActivePlan(source);
      if (!_isRepeatableTerminal(source.status)) {
        throw const InvalidOccurrenceTransitionException(
          'Only terminal occurrences can be repeated.',
        );
      }
      _validateRepeatPurpose(source, command.purpose);
      final related =
          await (_db.select(_db.scheduledSessionOccurrences)..where(
                (table) =>
                    table.programVersionId.equals(source.programVersionId) &
                    table.programWeekOrdinal.equals(source.programWeekOrdinal) &
                    table.sessionTemplateId.equals(source.sessionTemplateId),
              ))
              .get();
      final repeatOrdinal =
          related.fold<int>(
            0,
            (max, row) => row.repeatOrdinal > max ? row.repeatOrdinal : max,
          ) +
          1;
      final repeatedId = _uuid.v4();
      final now = _nowUtc().toUtc();
      await _db
          .into(_db.scheduledSessionOccurrences)
          .insert(
            ScheduledSessionOccurrencesCompanion.insert(
              id: repeatedId,
              programVersionId: source.programVersionId,
              sessionTemplateId: source.sessionTemplateId,
              programBlockOrdinal: source.programBlockOrdinal,
              programWeekOrdinal: source.programWeekOrdinal,
              sessionOrdinal: source.sessionOrdinal,
              repeatOrdinal: Value(repeatOrdinal),
              originalLocalDate: date,
              originalTimezoneId: command.timezoneId,
              effectiveLocalDate: date,
              effectiveTimezoneId: command.timezoneId,
              repeatedFromOccurrenceId: Value(source.id),
              repeatPurpose: Value(command.purpose.dbValue),
              createdAtUtc: now,
            ),
          );
      final sourceEvent = await _insertEvent(
        occurrenceId: source.id,
        commandId: command.commandId,
        eventType: 'repeatCreated',
        fromStatus: source.status,
        toStatus: source.status,
        beforeLocalDate: source.effectiveLocalDate,
        beforeTimezoneId: source.effectiveTimezoneId,
        afterLocalDate: source.effectiveLocalDate,
        afterTimezoneId: source.effectiveTimezoneId,
        metadata: {
          'repeatedOccurrenceId': repeatedId,
          'purpose': command.purpose.dbValue,
        },
        occurredAtUtc: now,
      );
      await _insertEvent(
        occurrenceId: repeatedId,
        commandId: command.commandId,
        eventType: 'repeatPlanned',
        toStatus: OccurrenceStatus.planned.dbValue,
        afterLocalDate: date,
        afterTimezoneId: command.timezoneId,
        metadata: {'sourceOccurrenceId': source.id},
        occurredAtUtc: now,
      );
      return RepeatOccurrenceResult(
        source: source,
        repeatedOccurrence: (await getOccurrence(repeatedId))!,
        event: sourceEvent,
        wasIdempotent: false,
      );
    });
  }

  Future<OccurrenceMutationResult> start(StartOccurrenceCommand command) async {
    _validateCommand(command);
    return _db.transaction(() async {
      final existing = await _existingEvent(
        command.occurrenceId,
        command.commandId,
      );
      if (existing != null) {
        return _idempotentResult(
          command.occurrenceId,
          existing,
          expectedEventType: 'started',
        );
      }
      final occurrence = await _requireCommandSource(command);
      await _requireActivePlan(occurrence);
      _requireUnstarted(occurrence, 'start');
      final today = _dates.todayIn(occurrence.effectiveTimezoneId);
      if (today != occurrence.effectiveLocalDate &&
          !command.confirmedOutsideEffectiveDate) {
        throw const InvalidOccurrenceTransitionException(
          'Starting a past or future occurrence requires explicit confirmation.',
        );
      }
      final activeDrafts = await _db.select(_db.workoutDrafts).get();
      if (activeDrafts.isNotEmpty) {
        throw const InvalidOccurrenceTransitionException(
          'Another active workout draft must be resumed or discarded first.',
        );
      }
      final inProgress = await (_db.select(
        _db.scheduledSessionOccurrences,
      )..where((table) => table.status.equals('inProgress'))).get();
      if (inProgress.isNotEmpty) {
        throw const InvalidOccurrenceTransitionException(
          'Another occurrence is already in progress and requires recovery.',
        );
      }
      final snapshot = await _snapshotForStart(
        occurrence,
        executionContext: command.executionContext,
      );
      final now = _nowUtc().toUtc();
      final changed =
          await (_db.update(_db.scheduledSessionOccurrences)..where(
                (table) =>
                    table.id.equals(occurrence.id) &
                    table.status.equals(command.expectedStatus.dbValue),
              ))
              .write(
                ScheduledSessionOccurrencesCompanion(
                  status: const Value('inProgress'),
                  executionSnapshotJson: Value(snapshot),
                  startedAtUtc: Value(now),
                ),
              );
      if (changed != 1) _throwStale();
      final decoded = jsonDecode(snapshot) as Map<String, dynamic>;
      final routineName = decoded['routineName'] as String;
      await _db
          .into(_db.workoutDrafts)
          .insert(
            WorkoutDraftsCompanion.insert(
              routineName: routineName,
              currentExerciseIndex: 0,
              currentSetIndex: 0,
              elapsedSeconds: 0,
              loggedSetsJson: WorkoutDraftCodec.encode(
                routineName: routineName,
                currentExerciseIndex: 0,
                currentSetIndex: 0,
                elapsedSeconds: 0,
                loggedSets: const [],
              ),
              scheduledOccurrenceId: Value(occurrence.id),
              executionSnapshotJson: Value(snapshot),
            ),
          );
      final event = await _insertEvent(
        occurrenceId: occurrence.id,
        commandId: command.commandId,
        eventType: 'started',
        fromStatus: occurrence.status,
        toStatus: OccurrenceStatus.inProgress.dbValue,
        beforeLocalDate: occurrence.effectiveLocalDate,
        beforeTimezoneId: occurrence.effectiveTimezoneId,
        afterLocalDate: occurrence.effectiveLocalDate,
        afterTimezoneId: occurrence.effectiveTimezoneId,
        metadata: {
          'snapshotVersion': 1,
          'usedPreparedSnapshot':
              occurrence.executionSnapshotJson?.trim().isNotEmpty == true,
        },
        occurredAtUtc: now,
      );
      return OccurrenceMutationResult(
        occurrence: (await getOccurrence(occurrence.id))!,
        event: event,
        wasIdempotent: false,
      );
    });
  }

  Future<OccurrenceMutationResult> discardStarted(
    DiscardStartedOccurrenceCommand command,
  ) async {
    _validateCommand(command);
    if (command.expectedStatus != OccurrenceStatus.inProgress) {
      throw const InvalidOccurrenceTransitionException(
        'Only an in-progress occurrence can be discarded.',
      );
    }
    return _db.transaction(() async {
      final existing = await _existingEvent(
        command.occurrenceId,
        command.commandId,
      );
      if (existing != null) {
        return _idempotentResult(
          command.occurrenceId,
          existing,
          expectedEventType: 'startDiscarded',
        );
      }
      final occurrence = await _requireCommandSource(command);
      final session =
          await (_db.select(_db.workoutSessions)..where(
                (table) => table.scheduledOccurrenceId.equals(occurrence.id),
              ))
              .getSingleOrNull();
      if (session != null) {
        throw const InvalidOccurrenceTransitionException(
          'A started occurrence with a saved session cannot be discarded.',
        );
      }
      final restoredStatus =
          occurrence.originalLocalDate == occurrence.effectiveLocalDate &&
              occurrence.originalTimezoneId == occurrence.effectiveTimezoneId
          ? OccurrenceStatus.planned
          : OccurrenceStatus.rescheduled;
      final customizationEvents =
          await (_db.select(_db.occurrenceEvents)..where(
                (table) =>
                    table.occurrenceId.equals(occurrence.id) &
                    table.eventType.equals('customized'),
              ))
              .get();
      String? preparedSnapshot;
      if (customizationEvents.isNotEmpty) {
        final frozen = occurrence.executionSnapshotJson;
        if (frozen == null || frozen.trim().isEmpty) {
          throw const InvalidOccurrenceTransitionException(
            'This customized workout snapshot is unavailable right now.',
          );
        }
        final prepared = _decodeAndValidateOccurrenceSnapshot(
          frozen,
          occurrence,
        )..remove('personalExerciseContext');
        preparedSnapshot = jsonEncode(prepared);
      }
      await (_db.delete(_db.workoutDrafts)..where(
            (table) => table.scheduledOccurrenceId.equals(occurrence.id),
          ))
          .go();
      final changed =
          await (_db.update(_db.scheduledSessionOccurrences)..where(
                (table) =>
                    table.id.equals(occurrence.id) &
                    table.status.equals(OccurrenceStatus.inProgress.dbValue),
              ))
              .write(
                ScheduledSessionOccurrencesCompanion(
                  status: Value(restoredStatus.dbValue),
                  executionSnapshotJson: Value(preparedSnapshot),
                  startedAtUtc: const Value(null),
                ),
              );
      if (changed != 1) _throwStale();
      final event = await _insertEvent(
        occurrenceId: occurrence.id,
        commandId: command.commandId,
        eventType: 'startDiscarded',
        fromStatus: occurrence.status,
        toStatus: restoredStatus.dbValue,
        beforeLocalDate: occurrence.effectiveLocalDate,
        beforeTimezoneId: occurrence.effectiveTimezoneId,
        afterLocalDate: occurrence.effectiveLocalDate,
        afterTimezoneId: occurrence.effectiveTimezoneId,
      );
      return OccurrenceMutationResult(
        occurrence: (await getOccurrence(occurrence.id))!,
        event: event,
        wasIdempotent: false,
      );
    });
  }

  Future<OccurrenceMutationResult> completeWithPersistedSession(
    CompleteOccurrenceCommand command,
  ) async {
    _validateCommand(command);
    if (command.expectedStatus != OccurrenceStatus.inProgress) {
      throw const InvalidOccurrenceTransitionException(
        'Only an in-progress occurrence can complete.',
      );
    }
    return _db.transaction(
      () => completeWithPersistedSessionInTransaction(command),
    );
  }

  /// Completes an occurrence inside a transaction owned by the execution
  /// bridge. B01-09 uses this after inserting the linked session and sets and
  /// before deleting the draft last. Callers must already be in a Drift
  /// transaction; this method never persists a session or draft itself.
  Future<OccurrenceMutationResult> completeWithPersistedSessionInTransaction(
    CompleteOccurrenceCommand command,
  ) async {
    _validateCommand(command);
    if (command.expectedStatus != OccurrenceStatus.inProgress) {
      throw const InvalidOccurrenceTransitionException(
        'Only an in-progress occurrence can complete.',
      );
    }
    {
      final existing = await _existingEvent(
        command.occurrenceId,
        command.commandId,
      );
      if (existing != null) {
        return _idempotentResult(
          command.occurrenceId,
          existing,
          expectedEventType: command.completionKind == CompletionKind.full
              ? 'completed'
              : 'partiallyCompleted',
        );
      }
      final occurrence = await _requireCommandSource(command);
      final session =
          await (_db.select(_db.workoutSessions)..where(
                (table) =>
                    table.id.equals(command.workoutSessionId) &
                    table.scheduledOccurrenceId.equals(occurrence.id),
              ))
              .getSingleOrNull();
      if (session == null) {
        throw const InvalidOccurrenceTransitionException(
          'Completion requires a persisted session linked to this occurrence.',
        );
      }
      final targetStatus = command.completionKind == CompletionKind.full
          ? OccurrenceStatus.completed
          : OccurrenceStatus.partiallyCompleted;
      final targetProgression = command.completionKind == CompletionKind.full
          ? 'satisfied'
          : 'pending';
      final now = _nowUtc().toUtc();
      final changed =
          await (_db.update(_db.scheduledSessionOccurrences)..where(
                (table) =>
                    table.id.equals(occurrence.id) &
                    table.status.equals(OccurrenceStatus.inProgress.dbValue),
              ))
              .write(
                ScheduledSessionOccurrencesCompanion(
                  status: Value(targetStatus.dbValue),
                  progressionDisposition: Value(targetProgression),
                  terminalAtUtc: Value(now),
                ),
              );
      if (changed != 1) _throwStale();
      if (command.completionKind == CompletionKind.full &&
          occurrence.repeatPurpose == RepeatPurpose.makeUp.dbValue &&
          occurrence.repeatedFromOccurrenceId != null) {
        await (_db.update(_db.scheduledSessionOccurrences)..where(
              (table) => table.id.equals(occurrence.repeatedFromOccurrenceId!),
            ))
            .write(
              const ScheduledSessionOccurrencesCompanion(
                progressionDisposition: Value('satisfied'),
              ),
            );
      }
      final event = await _insertEvent(
        occurrenceId: occurrence.id,
        commandId: command.commandId,
        eventType: command.completionKind == CompletionKind.full
            ? 'completed'
            : 'partiallyCompleted',
        fromStatus: occurrence.status,
        toStatus: targetStatus.dbValue,
        beforeLocalDate: occurrence.effectiveLocalDate,
        beforeTimezoneId: occurrence.effectiveTimezoneId,
        afterLocalDate: occurrence.effectiveLocalDate,
        afterTimezoneId: occurrence.effectiveTimezoneId,
        reason: command.reason,
        metadata: {
          'workoutSessionId': command.workoutSessionId,
          'completionKind': command.completionKind.dbValue,
        },
        occurredAtUtc: now,
      );
      return OccurrenceMutationResult(
        occurrence: (await getOccurrence(occurrence.id))!,
        event: event,
        wasIdempotent: false,
      );
    }
  }

  Future<OccurrenceMutationResult> _idempotentResult(
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

  Future<ScheduledSessionOccurrence> _requireCommandSource(
    OccurrenceCommand command,
  ) async {
    final occurrence = await getOccurrence(command.occurrenceId);
    if (occurrence == null) {
      throw const InvalidOccurrenceTransitionException(
        'Occurrence was not found.',
      );
    }
    if (occurrence.status != command.expectedStatus.dbValue) {
      _throwStale();
    }
    return occurrence;
  }

  Future<void> _requireActivePlan(ScheduledSessionOccurrence occurrence) async {
    final settings = await (_db.select(
      _db.trainingPlanSettings,
    )..where((table) => table.id.equals(1))).getSingleOrNull();
    if (settings?.activeProgramVersionId != occurrence.programVersionId) {
      throw const InvalidOccurrenceTransitionException(
        'This workout is no longer part of the current training plan.',
      );
    }
  }

  Future<void> _rejectStartedDependents(
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

  Future<String> _snapshotForStart(
    ScheduledSessionOccurrence occurrence, {
    Map<String, dynamic>? executionContext,
  }) async {
    // A customization is a prepared launch snapshot on the existing
    // occurrence row. Starting promotes it to the immutable execution
    // snapshot; it never rebuilds from the published template afterward.
    final stored = occurrence.executionSnapshotJson?.trim();
    if (stored == null || stored.isEmpty) {
      return _buildExecutionSnapshot(
        occurrence,
        executionContext: executionContext,
      );
    }
    final snapshot = _decodeAndValidateOccurrenceSnapshot(stored, occurrence);
    if (executionContext != null) {
      snapshot['personalExerciseContext'] = executionContext;
      return jsonEncode(snapshot);
    }
    return stored;
  }

  Map<String, dynamic> _decodeAndValidateOccurrenceSnapshot(
    String snapshotJson,
    ScheduledSessionOccurrence occurrence,
  ) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(snapshotJson);
    } on Object {
      throw const InvalidOccurrenceTransitionException(
        'This workout snapshot is unavailable right now.',
      );
    }
    if (decoded is! Map) {
      throw const InvalidOccurrenceTransitionException(
        'This workout snapshot is unavailable right now.',
      );
    }
    final snapshot = Map<String, dynamic>.from(decoded);
    if (snapshot['occurrenceId'] != occurrence.id) {
      throw const InvalidOccurrenceTransitionException(
        'This workout snapshot belongs to another scheduled workout.',
      );
    }
    final template = snapshot['template'];
    if (template is! Map || template['id'] != occurrence.sessionTemplateId) {
      throw const InvalidOccurrenceTransitionException(
        'This workout snapshot no longer matches its scheduled workout.',
      );
    }
    final version = snapshot['programVersion'];
    if (version is! Map || version['id'] != occurrence.programVersionId) {
      throw const InvalidOccurrenceTransitionException(
        'This workout snapshot no longer matches its training plan.',
      );
    }
    if (snapshot['routineName'] is! String ||
        (snapshot['routineName'] as String).trim().isEmpty ||
        snapshot['prescriptions'] is! List) {
      throw const InvalidOccurrenceTransitionException(
        'This workout snapshot is unavailable right now.',
      );
    }
    return snapshot;
  }

  Future<String> _buildExecutionSnapshot(
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

  Future<OccurrenceEvent> _insertEvent({
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

  static bool _isRepeatableTerminal(String status) {
    return status == OccurrenceStatus.completed.dbValue ||
        status == OccurrenceStatus.partiallyCompleted.dbValue ||
        status == OccurrenceStatus.skipped.dbValue ||
        status == OccurrenceStatus.cancelled.dbValue;
  }

  static void _validateRepeatPurpose(
    ScheduledSessionOccurrence source,
    RepeatPurpose purpose,
  ) {
    if (source.status == OccurrenceStatus.completed.dbValue &&
        purpose != RepeatPurpose.extra) {
      throw const InvalidOccurrenceTransitionException(
        'Repeating completed work is always extra.',
      );
    }
    if (source.status == OccurrenceStatus.skipped.dbValue &&
        source.skipMode == 'advance' &&
        purpose != RepeatPurpose.extra) {
      throw const InvalidOccurrenceTransitionException(
        'A skip-and-advance occurrence can repeat only as extra work.',
      );
    }
  }

  static void _requireUnstarted(
    ScheduledSessionOccurrence occurrence,
    String action,
  ) {
    if (occurrence.status != OccurrenceStatus.planned.dbValue &&
        occurrence.status != OccurrenceStatus.rescheduled.dbValue) {
      throw InvalidOccurrenceTransitionException(
        'Cannot $action an occurrence in status ${occurrence.status}.',
      );
    }
  }

  static void _validateCommand(OccurrenceCommand command) {
    if (command.occurrenceId.trim().isEmpty ||
        command.commandId.trim().isEmpty) {
      throw ArgumentError('Occurrence and command IDs must not be blank.');
    }
  }

  static String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Never _throwStale() {
    throw const InvalidOccurrenceTransitionException(
      'The occurrence changed before this command could be applied.',
    );
  }
}
