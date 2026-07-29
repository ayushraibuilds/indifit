import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import 'calendar_repository.dart';
import 'equipment_preference_repository.dart';
import 'workout_repository.dart';

/// Launch DTO for launching a workout player session from a calendar occurrence.
class WorkoutPlayerLaunchData {
  final String occurrenceId;
  final String routineName;
  final String executionSnapshotJson;

  const WorkoutPlayerLaunchData({
    required this.occurrenceId,
    required this.routineName,
    required this.executionSnapshotJson,
  });
}

/// Compatibility adapter bridging calendar scheduled occurrences to player execution and durable workout history.
class WorkoutExecutionCompatibilityAdapter {
  final AppDatabase db;
  final CalendarRepository calendarRepo;
  final WorkoutRepository workoutRepo;
  final ExercisePreferenceRepository preferenceRepo;
  final Uuid _uuid;

  WorkoutExecutionCompatibilityAdapter({
    required this.db,
    required this.calendarRepo,
    required this.workoutRepo,
    required this.preferenceRepo,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  /// Starts a scheduled occurrence, generates its frozen execution snapshot, creates an active draft, and returns launch data.
  Future<WorkoutPlayerLaunchData> startScheduledOccurrence({
    required String occurrenceId,
    String? commandId,
    bool confirmedOutsideEffectiveDate = false,
  }) async {
    final occurrence = await calendarRepo.getOccurrence(occurrenceId);
    if (occurrence == null) {
      throw StateError('Scheduled occurrence $occurrenceId not found.');
    }

    final currentStatus = OccurrenceStatus.values.firstWhere(
      (s) => s.dbValue == occurrence.status,
    );

    final startCmd = StartOccurrenceCommand(
      occurrenceId: occurrenceId,
      commandId: commandId ?? _uuid.v4(),
      expectedStatus: currentStatus,
      confirmedOutsideEffectiveDate: confirmedOutsideEffectiveDate,
    );

    final result = await calendarRepo.start(startCmd);
    final snapshotJson = result.occurrence.executionSnapshotJson!;
    final decoded = jsonDecode(snapshotJson) as Map<String, dynamic>;

    return WorkoutPlayerLaunchData(
      occurrenceId: occurrenceId,
      routineName: decoded['routineName'] as String? ?? 'Scheduled Workout',
      executionSnapshotJson: snapshotJson,
    );
  }

  /// Finalizes a scheduled occurrence and logs its session/sets in ONE single Drift database transaction.
  /// Guarantees idempotency via commandId checking.
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
    final occurrence = await calendarRepo.getOccurrence(occurrenceId);
    if (occurrence == null) {
      throw StateError('Occurrence $occurrenceId not found.');
    }

    return db.transaction(() async {
      // 1. Idempotency Check: Query OccurrenceEvents for existing completed commandId
      final existingEvents =
          await (db.select(db.occurrenceEvents)..where(
                (t) =>
                    t.occurrenceId.equals(occurrenceId) &
                    t.commandId.equals(commandId),
              ))
              .get();

      if (existingEvents.isNotEmpty) {
        final completedEvent = existingEvents.firstWhere(
          (e) => e.eventType == 'completed',
          orElse: () => existingEvents.first,
        );

        if (completedEvent.metadataJson != null) {
          final meta =
              jsonDecode(completedEvent.metadataJson!) as Map<String, dynamic>;
          final existingSessionId = meta['workoutSessionId'] as int?;
          if (existingSessionId != null) {
            return existingSessionId;
          }
        }

        // Fallback check in WorkoutSessions
        final existingSession =
            await (db.select(db.workoutSessions)
                  ..where((t) => t.scheduledOccurrenceId.equals(occurrenceId)))
                .getSingleOrNull();

        if (existingSession != null) {
          return existingSession.id;
        }
      }

      final now = DateTime.now().toUtc();
      final finalCompletedAt = completedAt ?? now;

      // 2. Insert WorkoutSession record with scheduledOccurrenceId link
      final sessionId = await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              name: name,
              totalVolume: volume,
              durationSeconds: durationSeconds,
              estimatedCalories: calories,
              completedAt: Value(finalCompletedAt),
              scheduledOccurrenceId: Value(occurrenceId),
            ),
          );

      // 3. Insert WorkoutSets records attached to sessionId
      for (final setCompanion in sets) {
        final updatedSet = setCompanion.copyWith(sessionId: Value(sessionId));
        await db.into(db.workoutSets).insert(updatedSet);
      }

      // 4. Update ScheduledSessionOccurrence state inside the transaction
      final targetStatus = completionKind == CompletionKind.full
          ? 'completed'
          : 'partiallyCompleted';
      final targetDisposition = completionKind == CompletionKind.full
          ? 'satisfied'
          : 'bypassed';

      await (db.update(
        db.scheduledSessionOccurrences,
      )..where((t) => t.id.equals(occurrenceId))).write(
        ScheduledSessionOccurrencesCompanion(
          status: Value(targetStatus),
          progressionDisposition: Value(targetDisposition),
          terminalAtUtc: Value(now),
        ),
      );

      // 5. Insert OccurrenceEvents completed log
      await db
          .into(db.occurrenceEvents)
          .insert(
            OccurrenceEventsCompanion.insert(
              id: _uuid.v4(),
              occurrenceId: occurrenceId,
              commandId: commandId,
              eventType: 'completed',
              fromStatus: Value(occurrence.status),
              toStatus: Value(targetStatus),
              beforeLocalDate: Value(occurrence.effectiveLocalDate),
              beforeTimezoneId: Value(occurrence.effectiveTimezoneId),
              afterLocalDate: Value(occurrence.effectiveLocalDate),
              afterTimezoneId: Value(occurrence.effectiveTimezoneId),
              reason: Value(reason),
              metadataJson: Value(
                jsonEncode({
                  'workoutSessionId': sessionId,
                  'completionKind': completionKind.dbValue,
                }),
              ),
              occurredAtUtc: now,
            ),
          );

      // 6. Delete Active WorkoutDraft as the VERY LAST operation inside the transaction
      await (db.delete(
        db.workoutDrafts,
      )..where((t) => t.scheduledOccurrenceId.equals(occurrenceId))).go();

      return sessionId;
    });
  }

  /// Discards a started scheduled occurrence and removes its active draft.
  Future<void> discardScheduledOccurrenceDraft({
    required String occurrenceId,
    String? commandId,
  }) async {
    final occurrence = await calendarRepo.getOccurrence(occurrenceId);
    if (occurrence == null) {
      throw StateError('Occurrence $occurrenceId not found.');
    }

    final currentStatus = OccurrenceStatus.values.firstWhere(
      (s) => s.dbValue == occurrence.status,
    );

    final discardCmd = DiscardStartedOccurrenceCommand(
      occurrenceId: occurrenceId,
      commandId: commandId ?? _uuid.v4(),
      expectedStatus: currentStatus,
    );

    return db.transaction(() async {
      await calendarRepo.discardStarted(discardCmd);
      await (db.delete(
        db.workoutDrafts,
      )..where((t) => t.scheduledOccurrenceId.equals(occurrenceId))).go();
    });
  }
}
