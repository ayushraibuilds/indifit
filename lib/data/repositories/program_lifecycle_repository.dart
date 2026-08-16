import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

/// The two explicit user-declared ways to stop using the current plan.
enum PlanEndOutcome {
  finished('finished'),
  left('left');

  const PlanEndOutcome(this.storageValue);

  final String storageValue;

  String get pastTenseLabel => this == finished ? 'finished' : 'left';
}

class EndActivePlanCommand {
  final PlanEndOutcome outcome;
  final String commandId;

  const EndActivePlanCommand({required this.outcome, required this.commandId});
}

class EndActivePlanResult {
  final String programVersionId;
  final PlanEndOutcome outcome;
  final List<String> cancelledOccurrenceIds;
  final bool wasIdempotent;

  const EndActivePlanResult({
    required this.programVersionId,
    required this.outcome,
    required this.cancelledOccurrenceIds,
    required this.wasIdempotent,
  });
}

class ProgramLifecycleException implements Exception {
  final String code;
  final String message;

  const ProgramLifecycleException(this.code, this.message);

  @override
  String toString() => 'ProgramLifecycleException($code): $message';
}

class NoActivePlanException extends ProgramLifecycleException {
  const NoActivePlanException()
    : super('no_active_plan', 'There is no active training plan.');
}

class PlanEndBlockedException extends ProgramLifecycleException {
  const PlanEndBlockedException(String message) : super('blocked', message);
}

class PlanEndCommandConflictException extends ProgramLifecycleException {
  const PlanEndCommandConflictException()
    : super(
        'command_conflict',
        'That plan action was already used for a different outcome.',
      );
}

/// Owns the B01 plan-end transaction. Activation remains owned by
/// [ProgramActivationCoordinator]; occurrence execution remains owned by
/// [CalendarRepository].
class ProgramLifecycleRepository {
  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;

  ProgramLifecycleRepository(
    this._db, {
    Uuid? uuid,
    DateTime Function()? nowUtc,
  }) : _uuid = uuid ?? const Uuid(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  Future<EndActivePlanResult> endActivePlan(
    EndActivePlanCommand command,
  ) async {
    _requireCommandId(command.commandId);

    return _db.transaction(() async {
      final settings = await (_db.select(
        _db.trainingPlanSettings,
      )..where((table) => table.id.equals(1))).getSingleOrNull();
      if (settings == null) {
        throw const ProgramLifecycleException(
          'missing_settings',
          'Training plan settings are missing.',
        );
      }

      if (settings.lastEndedCommandId == command.commandId) {
        if (settings.lastEndedOutcome != command.outcome.storageValue ||
            settings.lastEndedProgramVersionId == null) {
          throw const PlanEndCommandConflictException();
        }
        final endedVersionId = settings.lastEndedProgramVersionId!;
        final events =
            await (_db.select(_db.occurrenceEvents)..where(
                  (table) =>
                      table.commandId.equals(command.commandId) &
                      table.eventType.equals(_eventType(command.outcome)),
                ))
                .get();
        return EndActivePlanResult(
          programVersionId: endedVersionId,
          outcome: command.outcome,
          cancelledOccurrenceIds: events
              .map((event) => event.occurrenceId)
              .toList(growable: false),
          wasIdempotent: true,
        );
      }

      final activeVersionId = settings.activeProgramVersionId;
      if (activeVersionId == null) throw const NoActivePlanException();
      final version = await (_db.select(
        _db.programVersions,
      )..where((table) => table.id.equals(activeVersionId))).getSingleOrNull();
      if (version == null || version.status != 'published') {
        throw const ProgramLifecycleException(
          'invalid_active_plan',
          'The active training plan is unavailable.',
        );
      }

      final occurrences =
          await (_db.select(_db.scheduledSessionOccurrences)..where(
                (table) => table.programVersionId.equals(activeVersionId),
              ))
              .get();
      final occurrenceIds = occurrences
          .map((occurrence) => occurrence.id)
          .toSet();
      final drafts = await _db.select(_db.workoutDrafts).get();
      final linkedDraft = drafts.where(
        (draft) =>
            draft.scheduledOccurrenceId != null &&
            occurrenceIds.contains(draft.scheduledOccurrenceId),
      );
      if (linkedDraft.isNotEmpty) {
        throw const PlanEndBlockedException(
          'Finish or discard the current workout before ending this plan.',
        );
      }

      if (occurrences.any((occurrence) => occurrence.status == 'inProgress')) {
        throw const PlanEndBlockedException(
          'Recover or finish the current workout before ending this plan.',
        );
      }

      final now = _nowUtc().toUtc();
      final cancelledOccurrenceIds = <String>[];
      for (final occurrence in occurrences) {
        if (occurrence.status != 'planned' &&
            occurrence.status != 'rescheduled') {
          continue;
        }
        await (_db.update(
          _db.scheduledSessionOccurrences,
        )..where((table) => table.id.equals(occurrence.id))).write(
          ScheduledSessionOccurrencesCompanion(
            status: const Value('cancelled'),
            progressionDisposition: const Value('pending'),
            terminalAtUtc: Value(now),
          ),
        );
        await _db
            .into(_db.occurrenceEvents)
            .insert(
              OccurrenceEventsCompanion.insert(
                id: _uuid.v4(),
                occurrenceId: occurrence.id,
                commandId: command.commandId,
                eventType: _eventType(command.outcome),
                fromStatus: Value(occurrence.status),
                toStatus: const Value('cancelled'),
                reason: Value(command.outcome.storageValue),
                metadataJson: Value(
                  jsonEncode({
                    'programVersionId': activeVersionId,
                    'planEndOutcome': command.outcome.storageValue,
                  }),
                ),
                occurredAtUtc: now,
              ),
            );
        cancelledOccurrenceIds.add(occurrence.id);
      }

      final changed =
          await (_db.update(
            _db.trainingPlanSettings,
          )..where((table) => table.id.equals(1))).write(
            TrainingPlanSettingsCompanion(
              activeProgramVersionId: const Value(null),
              activeSinceLocalDate: const Value(null),
              activeSinceTimezoneId: const Value(null),
              lastEndedProgramVersionId: Value(activeVersionId),
              lastEndedOutcome: Value(command.outcome.storageValue),
              lastEndedAtUtc: Value(now),
              lastEndedCommandId: Value(command.commandId),
              updatedAtUtc: Value(now),
            ),
          );
      if (changed != 1) {
        throw const ProgramLifecycleException(
          'missing_settings',
          'Training plan settings are missing.',
        );
      }

      return EndActivePlanResult(
        programVersionId: activeVersionId,
        outcome: command.outcome,
        cancelledOccurrenceIds: cancelledOccurrenceIds,
        wasIdempotent: false,
      );
    });
  }

  static String _eventType(PlanEndOutcome outcome) =>
      outcome == PlanEndOutcome.finished ? 'planFinished' : 'planLeft';

  static void _requireCommandId(String value) {
    if (value.trim().isEmpty) {
      throw const ProgramLifecycleException(
        'invalid_command_id',
        'A plan action needs a command ID.',
      );
    }
  }
}
