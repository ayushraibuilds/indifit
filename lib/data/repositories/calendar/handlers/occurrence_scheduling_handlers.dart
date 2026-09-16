import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../database/app_database.dart';
import '../../calendar_repository.dart';
import 'occurrence_command_handler.dart';

class RescheduleOccurrenceHandler
    implements OccurrenceCommandHandler<RescheduleOccurrenceCommand, OccurrenceMutationResult> {
  final CalendarRepository repo;

  const RescheduleOccurrenceHandler(this.repo);

  @override
  Future<OccurrenceMutationResult> handle(RescheduleOccurrenceCommand command) async {
    repo.validator.validateCommand(command);
    final newDate = repo.dates.normalizeLocalDate(command.effectiveLocalDate);
    repo.dates.validateTimezone(command.effectiveTimezoneId);
    repo.validator.validateRescheduleConfirmation(command.confirmed);

    return repo.db.transaction(() async {
      final existing = await repo.existingEvent(
        command.occurrenceId,
        command.commandId,
      );
      if (existing != null) {
        return repo.idempotentResult(
          command.occurrenceId,
          existing,
          expectedEventType: 'rescheduled',
        );
      }
      final occurrence = await repo.requireCommandSource(command);
      await repo.requireActivePlan(occurrence);
      repo.validator.requireUnstarted(occurrence, 'reschedule');
      final targetStatus =
          occurrence.originalLocalDate == newDate &&
              occurrence.originalTimezoneId == command.effectiveTimezoneId
          ? OccurrenceStatus.planned
          : OccurrenceStatus.rescheduled;
      final changed =
          await (repo.db.update(repo.db.scheduledSessionOccurrences)..where(
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
      if (changed != 1) repo.validator.throwStale();
      final event = await repo.insertEvent(
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
        occurrence: (await repo.getOccurrence(occurrence.id))!,
        event: event,
        wasIdempotent: false,
      );
    });
  }
}

class SkipOccurrenceHandler
    implements OccurrenceCommandHandler<SkipOccurrenceCommand, OccurrenceMutationResult> {
  final CalendarRepository repo;

  const SkipOccurrenceHandler(this.repo);

  @override
  Future<OccurrenceMutationResult> handle(SkipOccurrenceCommand command) async {
    repo.validator.validateCommand(command);
    return repo.db.transaction(() async {
      final existing = await repo.existingEvent(
        command.occurrenceId,
        command.commandId,
      );
      if (existing != null) {
        return repo.idempotentResult(
          command.occurrenceId,
          existing,
          expectedEventType: 'skipped',
        );
      }
      final occurrence = await repo.requireCommandSource(command);
      await repo.requireActivePlan(occurrence);
      repo.validator.requireUnstarted(occurrence, 'skip');
      final changed =
          await (repo.db.update(repo.db.scheduledSessionOccurrences)..where(
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
                  terminalAtUtc: Value(repo.nowUtc().toUtc()),
                ),
              );
      if (changed != 1) repo.validator.throwStale();
      final event = await repo.insertEvent(
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
        occurrence: (await repo.getOccurrence(occurrence.id))!,
        event: event,
        wasIdempotent: false,
      );
    });
  }
}

class CancelOccurrenceHandler
    implements OccurrenceCommandHandler<CancelOccurrenceCommand, OccurrenceMutationResult> {
  final CalendarRepository repo;

  const CancelOccurrenceHandler(this.repo);

  @override
  Future<OccurrenceMutationResult> handle(CancelOccurrenceCommand command) async {
    repo.validator.validateCommand(command);
    return repo.db.transaction(() async {
      final existing = await repo.existingEvent(
        command.occurrenceId,
        command.commandId,
      );
      if (existing != null) {
        return repo.idempotentResult(
          command.occurrenceId,
          existing,
          expectedEventType: 'cancelled',
        );
      }
      final occurrence = await repo.requireCommandSource(command);
      await repo.requireActivePlan(occurrence);
      repo.validator.requireUnstarted(occurrence, 'cancel');
      final changed =
          await (repo.db.update(repo.db.scheduledSessionOccurrences)..where(
                (table) =>
                    table.id.equals(occurrence.id) &
                    table.status.equals(command.expectedStatus.dbValue),
              ))
              .write(
                ScheduledSessionOccurrencesCompanion(
                  status: const Value('cancelled'),
                  progressionDisposition: const Value('pending'),
                  terminalAtUtc: Value(repo.nowUtc().toUtc()),
                ),
              );
      if (changed != 1) repo.validator.throwStale();
      final event = await repo.insertEvent(
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
        occurrence: (await repo.getOccurrence(occurrence.id))!,
        event: event,
        wasIdempotent: false,
      );
    });
  }
}

class RestoreOccurrenceHandler
    implements OccurrenceCommandHandler<RestoreOccurrenceCommand, OccurrenceMutationResult> {
  final CalendarRepository repo;

  const RestoreOccurrenceHandler(this.repo);

  @override
  Future<OccurrenceMutationResult> handle(RestoreOccurrenceCommand command) async {
    repo.validator.validateCommand(command);
    if (command.expectedStatus != OccurrenceStatus.skipped &&
        command.expectedStatus != OccurrenceStatus.cancelled) {
      throw const InvalidOccurrenceTransitionException(
        'Only skipped and cancelled occurrences can be restored.',
      );
    }
    return repo.db.transaction(() async {
      final existing = await repo.existingEvent(
        command.occurrenceId,
        command.commandId,
      );
      if (existing != null) {
        return repo.idempotentResult(
          command.occurrenceId,
          existing,
          expectedEventType: 'restored',
        );
      }
      final occurrence = await repo.requireCommandSource(command);
      await repo.requireActivePlan(occurrence);
      await repo.rejectStartedDependents(occurrence);
      final restoredStatus =
          occurrence.originalLocalDate == occurrence.effectiveLocalDate &&
              occurrence.originalTimezoneId == occurrence.effectiveTimezoneId
          ? OccurrenceStatus.planned
          : OccurrenceStatus.rescheduled;
      final changed =
          await (repo.db.update(repo.db.scheduledSessionOccurrences)..where(
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
      if (changed != 1) repo.validator.throwStale();
      final event = await repo.insertEvent(
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
        occurrence: (await repo.getOccurrence(occurrence.id))!,
        event: event,
        wasIdempotent: false,
      );
    });
  }
}

class RepeatOccurrenceHandler
    implements OccurrenceCommandHandler<RepeatOccurrenceCommand, RepeatOccurrenceResult> {
  final CalendarRepository repo;

  const RepeatOccurrenceHandler(this.repo);

  @override
  Future<RepeatOccurrenceResult> handle(RepeatOccurrenceCommand command) async {
    repo.validator.validateCommand(command);
    final date = repo.dates.normalizeLocalDate(command.localDate);
    repo.dates.validateTimezone(command.timezoneId);
    return repo.db.transaction(() async {
      final existing = await repo.existingEvent(
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
        final source = (await repo.getOccurrence(command.occurrenceId))!;
        final repeated = await repo.getOccurrence(repeatedId);
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
      final source = await repo.requireCommandSource(command);
      await repo.requireActivePlan(source);
      if (!repo.isRepeatableTerminal(source.status)) {
        throw const InvalidOccurrenceTransitionException(
          'Only terminal occurrences can be repeated.',
        );
      }
      repo.validator.validateRepeatPurpose(source, command.purpose);
      final related =
          await (repo.db.select(repo.db.scheduledSessionOccurrences)..where(
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
      final repeatedId = repo.uuid.v4();
      final now = repo.nowUtc().toUtc();
      await repo.db
          .into(repo.db.scheduledSessionOccurrences)
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
      final sourceEvent = await repo.insertEvent(
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
      await repo.insertEvent(
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
        repeatedOccurrence: (await repo.getOccurrence(repeatedId))!,
        event: sourceEvent,
        wasIdempotent: false,
      );
    });
  }
}
