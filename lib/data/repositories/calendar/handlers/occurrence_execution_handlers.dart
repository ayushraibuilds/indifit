import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/fixtures/workout_draft_codec.dart';
import '../../../../core/services/training_day_schedule.dart';
import '../../../database/app_database.dart';
import '../../calendar_repository.dart';
import '../../plan_schedule_reader.dart';
import 'occurrence_command_handler.dart';

class StartOccurrenceHandler
    implements
        OccurrenceCommandHandler<
          StartOccurrenceCommand,
          OccurrenceMutationResult
        > {
  final CalendarRepository repo;

  const StartOccurrenceHandler(this.repo);

  @override
  Future<OccurrenceMutationResult> handle(
    StartOccurrenceCommand command,
  ) async {
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
          expectedEventType: 'started',
        );
      }
      final occurrence = await repo.requireCommandSource(command);
      await repo.requireActivePlan(occurrence);
      repo.validator.requireUnstarted(occurrence, 'start');
      final today = repo.dates.todayIn(occurrence.effectiveTimezoneId);
      repo.validator.validateStartConfirmation(
        todayLocalDate: today,
        effectiveLocalDate: occurrence.effectiveLocalDate,
        confirmedOutsideEffectiveDate: command.confirmedOutsideEffectiveDate,
      );
      final activeDrafts = await repo.db.select(repo.db.workoutDrafts).get();
      if (activeDrafts.isNotEmpty) {
        throw const InvalidOccurrenceTransitionException(
          'Another active workout draft must be resumed or discarded first.',
        );
      }
      final inProgress = await (repo.db.select(
        repo.db.scheduledSessionOccurrences,
      )..where((table) => table.status.equals('inProgress'))).get();
      if (inProgress.isNotEmpty) {
        throw const InvalidOccurrenceTransitionException(
          'Another occurrence is already in progress and requires recovery.',
        );
      }
      final snapshot = await repo.snapshotForStart(
        occurrence,
        executionContext: command.executionContext,
      );
      final now = repo.nowUtc().toUtc();
      // An early start does today's training: the workout moves to today and
      // the plan's later workouts shift up (see [_shiftLaterWorkouts]).
      final startsEarly =
          repo.dates.compare(occurrence.effectiveLocalDate, today) > 0;
      final startedOn = startsEarly ? today : occurrence.effectiveLocalDate;
      final changed =
          await (repo.db.update(repo.db.scheduledSessionOccurrences)..where(
                (table) =>
                    table.id.equals(occurrence.id) &
                    table.status.equals(command.expectedStatus.dbValue),
              ))
              .write(
                ScheduledSessionOccurrencesCompanion(
                  status: const Value('inProgress'),
                  executionSnapshotJson: Value(snapshot),
                  startedAtUtc: Value(now),
                  effectiveLocalDate: Value(startedOn),
                ),
              );
      if (changed != 1) repo.validator.throwStale();
      final decoded = jsonDecode(snapshot) as Map<String, dynamic>;
      final routineName = decoded['routineName'] as String;
      await repo.db
          .into(repo.db.workoutDrafts)
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
      final event = await repo.insertEvent(
        occurrenceId: occurrence.id,
        commandId: command.commandId,
        eventType: 'started',
        fromStatus: occurrence.status,
        toStatus: OccurrenceStatus.inProgress.dbValue,
        beforeLocalDate: occurrence.effectiveLocalDate,
        beforeTimezoneId: occurrence.effectiveTimezoneId,
        afterLocalDate: startedOn,
        afterTimezoneId: occurrence.effectiveTimezoneId,
        metadata: {
          'snapshotVersion': 1,
          if (startsEarly) 'startedEarly': true,
          'usedPreparedSnapshot':
              occurrence.executionSnapshotJson?.trim().isNotEmpty == true,
        },
        occurredAtUtc: now,
      );
      if (startsEarly) {
        await _shiftLaterWorkouts(
          started: occurrence,
          today: today,
          commandId: command.commandId,
          occurredAtUtc: now,
        );
      }
      return OccurrenceMutationResult(
        occurrence: (await repo.getOccurrence(occurrence.id))!,
        event: event,
        wasIdempotent: false,
      );
    });
  }

  /// Re-lays the plan's unstarted workouts dated after [today] onto the
  /// user's training days, in their current order, starting with the first
  /// training day after today. Workouts that share a date stay together.
  /// Started, finished and skipped workouts never move, and running it again
  /// on the same day changes nothing.
  Future<void> _shiftLaterWorkouts({
    required ScheduledSessionOccurrence started,
    required String today,
    required String commandId,
    required DateTime occurredAtUtc,
  }) async {
    final shape = await PlanScheduleReader(
      repo.db,
      repo.dates,
    ).read(started.programVersionId);
    if (shape == null || shape.trainingWeekdays.isEmpty) return;
    final later =
        await (repo.db.select(repo.db.scheduledSessionOccurrences)
              ..where(
                (table) =>
                    table.programVersionId.equals(started.programVersionId) &
                    table.id.equals(started.id).not() &
                    table.status.isIn(const ['planned', 'rescheduled']) &
                    table.effectiveLocalDate.isBiggerThanValue(today),
              )
              ..orderBy([
                (table) => OrderingTerm(expression: table.effectiveLocalDate),
                (table) => OrderingTerm(expression: table.programWeekOrdinal),
                (table) => OrderingTerm(expression: table.sessionOrdinal),
                (table) => OrderingTerm(expression: table.repeatOrdinal),
              ]))
            .get();
    if (later.isEmpty) return;
    final days = <String>[];
    for (final occurrence in later) {
      if (days.isEmpty || days.last != occurrence.effectiveLocalDate) {
        days.add(occurrence.effectiveLocalDate);
      }
    }
    final laid = TrainingDaySchedule.layDates(
      dates: repo.dates,
      timezoneId: started.effectiveTimezoneId,
      startLocalDate: today,
      weekdays: shape.trainingWeekdays,
      count: days.length,
      startsOnStartDate: false,
    );
    final moveTo = {for (var i = 0; i < days.length; i++) days[i]: laid[i]};
    for (final occurrence in later) {
      final target = moveTo[occurrence.effectiveLocalDate]!;
      if (target == occurrence.effectiveLocalDate) continue;
      final status =
          occurrence.originalLocalDate == target &&
              occurrence.originalTimezoneId == started.effectiveTimezoneId
          ? OccurrenceStatus.planned
          : OccurrenceStatus.rescheduled;
      await (repo.db.update(
        repo.db.scheduledSessionOccurrences,
      )..where((table) => table.id.equals(occurrence.id))).write(
        ScheduledSessionOccurrencesCompanion(
          status: Value(status.dbValue),
          effectiveLocalDate: Value(target),
          effectiveTimezoneId: Value(started.effectiveTimezoneId),
        ),
      );
      await repo.insertEvent(
        occurrenceId: occurrence.id,
        commandId: commandId,
        eventType: 'rescheduled',
        fromStatus: occurrence.status,
        toStatus: status.dbValue,
        beforeLocalDate: occurrence.effectiveLocalDate,
        beforeTimezoneId: occurrence.effectiveTimezoneId,
        afterLocalDate: target,
        afterTimezoneId: started.effectiveTimezoneId,
        reason: 'Plan shifted after an early start',
        metadata: {'shiftedAfterEarlyStartOf': started.id},
        occurredAtUtc: occurredAtUtc,
      );
    }
  }
}

class DiscardStartedOccurrenceHandler
    implements
        OccurrenceCommandHandler<
          DiscardStartedOccurrenceCommand,
          OccurrenceMutationResult
        > {
  final CalendarRepository repo;

  const DiscardStartedOccurrenceHandler(this.repo);

  @override
  Future<OccurrenceMutationResult> handle(
    DiscardStartedOccurrenceCommand command,
  ) async {
    repo.validator.validateCommand(command);
    if (command.expectedStatus != OccurrenceStatus.inProgress) {
      throw const InvalidOccurrenceTransitionException(
        'Only an in-progress occurrence can be discarded.',
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
          expectedEventType: 'startDiscarded',
        );
      }
      final occurrence = await repo.requireCommandSource(command);
      final session =
          await (repo.db.select(repo.db.workoutSessions)..where(
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
      final latestCustomizationEvent =
          await (repo.db.select(repo.db.occurrenceEvents)
                ..where(
                  (table) =>
                      table.occurrenceId.equals(occurrence.id) &
                      table.eventType.isIn([
                        'customized',
                        'customizationReset',
                      ]),
                )
                ..orderBy([
                  (table) => OrderingTerm(
                    expression: table.occurredAtUtc,
                    mode: OrderingMode.desc,
                  ),
                ])
                ..limit(1))
              .getSingleOrNull();
      String? preparedSnapshot;
      if (latestCustomizationEvent != null &&
          latestCustomizationEvent.eventType == 'customized') {
        final frozen = occurrence.executionSnapshotJson;
        if (frozen == null || frozen.trim().isEmpty) {
          throw const InvalidOccurrenceTransitionException(
            'This customized workout snapshot is unavailable right now.',
          );
        }
        final prepared = repo.validator.decodeAndValidateOccurrenceSnapshot(
          frozen,
          occurrence,
        )..remove('personalExerciseContext');
        preparedSnapshot = jsonEncode(prepared);
      }
      await (repo.db.delete(repo.db.workoutDrafts)..where(
            (table) => table.scheduledOccurrenceId.equals(occurrence.id),
          ))
          .go();
      final changed =
          await (repo.db.update(repo.db.scheduledSessionOccurrences)..where(
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
      if (changed != 1) repo.validator.throwStale();
      final event = await repo.insertEvent(
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
        occurrence: (await repo.getOccurrence(occurrence.id))!,
        event: event,
        wasIdempotent: false,
      );
    });
  }
}

class CompleteOccurrenceHandler
    implements
        OccurrenceCommandHandler<
          CompleteOccurrenceCommand,
          OccurrenceMutationResult
        > {
  final CalendarRepository repo;

  const CompleteOccurrenceHandler(this.repo);

  @override
  Future<OccurrenceMutationResult> handle(
    CompleteOccurrenceCommand command,
  ) async {
    repo.validator.validateCommand(command);
    if (command.expectedStatus != OccurrenceStatus.inProgress) {
      throw const InvalidOccurrenceTransitionException(
        'Only an in-progress occurrence can complete.',
      );
    }
    return repo.db.transaction(() => handleInTransaction(command));
  }

  Future<OccurrenceMutationResult> handleInTransaction(
    CompleteOccurrenceCommand command,
  ) async {
    repo.validator.validateCommand(command);
    if (command.expectedStatus != OccurrenceStatus.inProgress) {
      throw const InvalidOccurrenceTransitionException(
        'Only an in-progress occurrence can complete.',
      );
    }
    final existing = await repo.existingEvent(
      command.occurrenceId,
      command.commandId,
    );
    if (existing != null) {
      return repo.idempotentResult(
        command.occurrenceId,
        existing,
        expectedEventType: command.completionKind == CompletionKind.full
            ? 'completed'
            : 'partiallyCompleted',
      );
    }
    final occurrence = await repo.requireCommandSource(command);
    final session =
        await (repo.db.select(repo.db.workoutSessions)..where(
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
    final now = repo.nowUtc().toUtc();
    final changed =
        await (repo.db.update(repo.db.scheduledSessionOccurrences)..where(
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
    if (changed != 1) repo.validator.throwStale();
    if (command.completionKind == CompletionKind.full &&
        occurrence.repeatPurpose == RepeatPurpose.makeUp.dbValue &&
        occurrence.repeatedFromOccurrenceId != null) {
      await (repo.db.update(repo.db.scheduledSessionOccurrences)..where(
            (table) => table.id.equals(occurrence.repeatedFromOccurrenceId!),
          ))
          .write(
            const ScheduledSessionOccurrencesCompanion(
              progressionDisposition: Value('satisfied'),
            ),
          );
    }
    final event = await repo.insertEvent(
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
      occurrence: (await repo.getOccurrence(occurrence.id))!,
      event: event,
      wasIdempotent: false,
    );
  }
}
