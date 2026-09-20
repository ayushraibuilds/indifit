import 'package:drift/drift.dart';

import '../../../database/app_database.dart';
import '../../../services/b02_occurrence_snapshot_customizer.dart';
import '../../calendar_repository.dart';
import 'occurrence_command_handler.dart';

class CustomizeOccurrenceHandler
    implements
        OccurrenceCommandHandler<CustomizeOccurrenceCommand,
            OccurrenceMutationResult> {
  final CalendarRepository repo;

  const CustomizeOccurrenceHandler(this.repo);

  @override
  Future<OccurrenceMutationResult> handle(
      CustomizeOccurrenceCommand command) async {
    repo.validator.validateCommand(command);
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
    return repo.db.transaction(() async {
      final existing = await repo.existingEvent(
        command.occurrenceId,
        command.commandId,
      );
      if (existing != null) {
        return repo.idempotentResult(
          command.occurrenceId,
          existing,
          expectedEventType: 'customized',
        );
      }
      final occurrence = await repo.requireCommandSource(command);
      await repo.requireActivePlan(occurrence);
      repo.validator.requireUnstarted(occurrence, 'customize');

      final currentSnapshot = occurrence.executionSnapshotJson?.trim();
      final baseSnapshot = currentSnapshot == null || currentSnapshot.isEmpty
          ? await repo.buildExecutionSnapshot(occurrence)
          : currentSnapshot;
      if (baseSnapshot != command.baseSnapshotJson) repo.validator.throwStale();
      repo.validator.decodeAndValidateOccurrenceSnapshot(
        baseSnapshot,
        occurrence,
      );

      final canonicalExercises =
          await (repo.db.select(repo.db.exercises)).get();
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
          await (repo.db.update(repo.db.scheduledSessionOccurrences)
                ..where(
                  (table) =>
                      table.id.equals(occurrence.id) &
                      table.status.equals(command.expectedStatus.dbValue),
                ))
              .write(
                ScheduledSessionOccurrencesCompanion(
                  executionSnapshotJson: Value(customizedSnapshot),
                ),
              );
      if (changed != 1) repo.validator.throwStale();
      final event = await repo.insertEvent(
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
        occurredAtUtc: repo.nowUtc().toUtc(),
      );
      return OccurrenceMutationResult(
        occurrence: (await repo.getOccurrence(occurrence.id))!,
        event: event,
        wasIdempotent: false,
      );
    });
  }
}

class CustomizeFutureOccurrencesHandler
    implements
        OccurrenceCommandHandler<CustomizeFutureOccurrencesCommand,
            FutureCustomizationResult> {
  final CalendarRepository repo;

  const CustomizeFutureOccurrencesHandler(this.repo);

  @override
  Future<FutureCustomizationResult> handle(
      CustomizeFutureOccurrencesCommand command) async {
    repo.validator.validateCommand(command);
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
    return repo.db.transaction(() async {
      final existing = await repo.existingEvent(
        command.occurrenceId,
        command.commandId,
      );
      if (existing != null) {
        return FutureCustomizationResult(
          affectedCount: 1,
          sourceResult: await repo.idempotentResult(
            command.occurrenceId,
            existing,
            expectedEventType: 'customized',
          ),
        );
      }
      final occurrence = await repo.requireCommandSource(command);
      await repo.requireActivePlan(occurrence);
      repo.validator.requireUnstarted(occurrence, 'customize');

      final currentSnapshot = occurrence.executionSnapshotJson?.trim();
      final baseSnapshot = currentSnapshot == null || currentSnapshot.isEmpty
          ? await repo.buildExecutionSnapshot(occurrence)
          : currentSnapshot;
      if (baseSnapshot != command.baseSnapshotJson) repo.validator.throwStale();
      repo.validator.decodeAndValidateOccurrenceSnapshot(
        baseSnapshot,
        occurrence,
      );

      final futureOccurrences =
          await (repo.db.select(repo.db.scheduledSessionOccurrences)
                ..where((table) =>
                    table.programVersionId
                        .equals(occurrence.programVersionId) &
                    table.sessionTemplateId
                        .equals(occurrence.sessionTemplateId) &
                    table.status.isIn([
                      OccurrenceStatus.planned.dbValue,
                      OccurrenceStatus.rescheduled.dbValue,
                    ]) &
                    table.effectiveLocalDate
                        .isBiggerOrEqualValue(occurrence.effectiveLocalDate))
                ..orderBy([
                  (table) =>
                      OrderingTerm(expression: table.effectiveLocalDate),
                ]))
              .get();

      if (futureOccurrences.isEmpty ||
          !futureOccurrences.any((item) => item.id == occurrence.id)) {
        repo.validator.throwStale();
      }

      final canonicalExercises =
          await (repo.db.select(repo.db.exercises)).get();
      final canonicalById = <String, String>{
        for (final exercise in canonicalExercises)
          if (exercise.stableId?.trim().isNotEmpty == true &&
              exercise.name.trim().isNotEmpty)
            exercise.stableId!.trim(): exercise.name.trim(),
      };

      OccurrenceEvent? sourceEvent;

      for (final target in futureOccurrences) {
        final targetPristineSnapshot =
            await repo.buildExecutionSnapshot(target);
        final customizedSnapshot =
            const B02OccurrenceSnapshotCustomizer().apply(
          snapshotJson: targetPristineSnapshot,
          occurrenceId: target.id,
          changes: command.changes,
          canonicalExercises: canonicalById,
        );

        final changed =
            await (repo.db.update(repo.db.scheduledSessionOccurrences)
                  ..where((table) =>
                      table.id.equals(target.id) &
                      table.status.isIn([
                        OccurrenceStatus.planned.dbValue,
                        OccurrenceStatus.rescheduled.dbValue,
                      ])))
                .write(
                  ScheduledSessionOccurrencesCompanion(
                    executionSnapshotJson: Value(customizedSnapshot),
                  ),
                );
        if (changed != 1) repo.validator.throwStale();

        final isSource = target.id == occurrence.id;
        final targetCommandId = isSource
            ? command.commandId
            : '${command.commandId}::${target.id}';
        final event = await repo.insertEvent(
          occurrenceId: target.id,
          commandId: targetCommandId,
          eventType: 'customized',
          fromStatus: target.status,
          toStatus: target.status,
          beforeLocalDate: target.effectiveLocalDate,
          beforeTimezoneId: target.effectiveTimezoneId,
          afterLocalDate: target.effectiveLocalDate,
          afterTimezoneId: target.effectiveTimezoneId,
          metadata: {
            'snapshotVersion': 1,
            'cascade': true,
            'sourceOccurrenceId': occurrence.id,
            'targetCount': futureOccurrences.length,
            'prescriptionIds': [
              for (final change in command.changes) change.prescriptionId,
            ],
          },
          occurredAtUtc: repo.nowUtc().toUtc(),
        );

        if (isSource) {
          sourceEvent = event;
        }
      }

      return FutureCustomizationResult(
        affectedCount: futureOccurrences.length,
        sourceResult: OccurrenceMutationResult(
          occurrence: (await repo.getOccurrence(occurrence.id))!,
          event: sourceEvent!,
          wasIdempotent: false,
        ),
      );
    });
  }
}

class ResetOccurrenceCustomizationHandler
    implements
        OccurrenceCommandHandler<ResetOccurrenceCustomizationCommand,
            FutureCustomizationResult> {
  final CalendarRepository repo;

  const ResetOccurrenceCustomizationHandler(this.repo);

  @override
  Future<FutureCustomizationResult> handle(
      ResetOccurrenceCustomizationCommand command) async {
    repo.validator.validateCommand(command);
    if (command.expectedStatus != OccurrenceStatus.planned &&
        command.expectedStatus != OccurrenceStatus.rescheduled) {
      throw const InvalidOccurrenceTransitionException(
        'Only an unstarted workout can be reset.',
      );
    }
    return repo.db.transaction(() async {
      final existing = await repo.existingEvent(
        command.occurrenceId,
        command.commandId,
      );
      if (existing != null) {
        return FutureCustomizationResult(
          affectedCount: 1,
          sourceResult: await repo.idempotentResult(
            command.occurrenceId,
            existing,
            expectedEventType: 'customizationReset',
          ),
        );
      }
      final occurrence = await repo.requireCommandSource(command);
      await repo.requireActivePlan(occurrence);
      repo.validator.requireUnstarted(occurrence, 'reset');

      final targets = command.allFuture
          ? await (repo.db.select(repo.db.scheduledSessionOccurrences)
                ..where((table) =>
                    table.programVersionId
                        .equals(occurrence.programVersionId) &
                    table.sessionTemplateId
                        .equals(occurrence.sessionTemplateId) &
                    table.status.isIn([
                      OccurrenceStatus.planned.dbValue,
                      OccurrenceStatus.rescheduled.dbValue,
                    ]) &
                    table.effectiveLocalDate
                        .isBiggerOrEqualValue(occurrence.effectiveLocalDate))
                ..orderBy([
                  (table) =>
                      OrderingTerm(expression: table.effectiveLocalDate),
                ]))
              .get()
          : [occurrence];

      if (targets.isEmpty || !targets.any((item) => item.id == occurrence.id)) {
        repo.validator.throwStale();
      }

      OccurrenceEvent? sourceEvent;

      for (final target in targets) {
        final changed =
            await (repo.db.update(repo.db.scheduledSessionOccurrences)
                  ..where((table) =>
                      table.id.equals(target.id) &
                      table.status.isIn([
                        OccurrenceStatus.planned.dbValue,
                        OccurrenceStatus.rescheduled.dbValue,
                      ])))
                .write(
                  const ScheduledSessionOccurrencesCompanion(
                    executionSnapshotJson: Value(null),
                  ),
                );
        if (changed != 1) repo.validator.throwStale();

        final isSource = target.id == occurrence.id;
        final targetCommandId = isSource
            ? command.commandId
            : '${command.commandId}::${target.id}';
        final event = await repo.insertEvent(
          occurrenceId: target.id,
          commandId: targetCommandId,
          eventType: 'customizationReset',
          fromStatus: target.status,
          toStatus: target.status,
          beforeLocalDate: target.effectiveLocalDate,
          beforeTimezoneId: target.effectiveTimezoneId,
          afterLocalDate: target.effectiveLocalDate,
          afterTimezoneId: target.effectiveTimezoneId,
          metadata: {
            'resetAllFuture': command.allFuture,
            'sourceOccurrenceId': occurrence.id,
            'targetCount': targets.length,
          },
          occurredAtUtc: repo.nowUtc().toUtc(),
        );

        if (isSource) {
          sourceEvent = event;
        }
      }

      return FutureCustomizationResult(
        affectedCount: targets.length,
        sourceResult: OccurrenceMutationResult(
          occurrence: (await repo.getOccurrence(occurrence.id))!,
          event: sourceEvent!,
          wasIdempotent: false,
        ),
      );
    });
  }
}
