import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/repositories/program_activation_coordinator.dart';
import 'package:indifit/data/repositories/program_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 3, 2, 8);
  late AppDatabase db;
  late ProgramRepository programs;
  late ProgramActivationCoordinator activation;
  late CalendarRepository calendar;

  setUp(() async {
    db = AppDatabase.memory();
    final dates = LocalScheduleDateService(nowUtc: () => now);
    programs = ProgramRepository(db);
    activation = ProgramActivationCoordinator(
      db,
      dates: dates,
      nowUtc: () => now,
    );
    calendar = CalendarRepository(db, dates: dates, nowUtc: () => now);
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('exercise-bench-v1'),
            name: 'Flat Barbell Bench Press',
            muscleGroups: 'Chest',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Brace',
            commonMistakes: 'Bounce',
          ),
        );
  });

  tearDown(() => db.close());

  Future<String> createDraftProgram() async {
    final programId = await programs.createProgram(
      name: 'State Machine',
      blocks: [
        for (var ordinal = 0; ordinal < 3; ordinal++)
          ProgramBlockInput(
            name: 'Block ${ordinal + 1}',
            ordinal: ordinal,
            weeks: [
              ProgramWeekInput(
                name: 'Week ${ordinal + 1}',
                ordinalInBlock: 0,
                programWeekOrdinal: ordinal,
                templates: [
                  SessionTemplateInput(
                    name: 'Session ${ordinal + 1}',
                    ordinal: 0,
                    plannedWeekday: DateTime.monday,
                    prescriptions: const [
                      ExercisePrescriptionInput(
                        exerciseId: 'exercise-bench-v1',
                        exerciseNameSnapshot: 'Flat Barbell Bench Press',
                        plannedSets: 3,
                        repsRange: '8-10',
                        ordinal: 0,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
      ],
    );
    return (await programs.getVersionsForProgram(programId)).single.id;
  }

  Future<List<ScheduledSessionOccurrence>> activateDraft(
    String versionId,
  ) async {
    return (await activation.activate(
      ActivateProgramVersionCommand(
        programVersionId: versionId,
        commandId: 'activate-$versionId',
        activationLocalDate: '2026-03-02',
        timezoneId: 'Asia/Kolkata',
      ),
    )).occurrences;
  }

  Future<int> insertSession(String occurrenceId) {
    return db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            name: 'Scheduled session',
            totalVolume: 100,
            durationSeconds: 60,
            estimatedCalories: 10,
            completedAt: Value(now),
            scheduledOccurrenceId: Value(occurrenceId),
          ),
        );
  }

  group('B01-06 activation', () {
    test(
      'publishes, materializes home-zone civil dates, and is idempotent',
      () async {
        final versionId = await createDraftProgram();
        final first = await activation.activate(
          ActivateProgramVersionCommand(
            programVersionId: versionId,
            commandId: 'activate-1',
            activationLocalDate: '2026-03-02',
            timezoneId: 'Asia/Kolkata',
          ),
        );
        final retry = await activation.activate(
          ActivateProgramVersionCommand(
            programVersionId: versionId,
            commandId: 'activate-1',
            activationLocalDate: '2026-03-02',
            timezoneId: 'Asia/Kolkata',
          ),
        );

        expect(first.occurrences.map((row) => row.originalLocalDate), [
          '2026-03-02',
          '2026-03-09',
          '2026-03-16',
        ]);
        expect(retry.wasIdempotent, isTrue);
        expect(retry.occurrences, hasLength(3));
        expect(
          (await db.select(db.programVersions).getSingle()).status,
          'published',
        );
        expect(
          (await db.select(db.trainingPlanSettings).getSingle())
              .activeProgramVersionId,
          versionId,
        );
        expect(await db.select(db.occurrenceEvents).get(), hasLength(3));
      },
    );

    test(
      'retains old occurrences and only cancels explicitly selected ones',
      () async {
        final v1 = await createDraftProgram();
        final oldOccurrences = await activateDraft(v1);
        final v2 = await programs.copyToNewDraftVersion(v1);

        final result = await activation.activate(
          ActivateProgramVersionCommand(
            programVersionId: v2,
            commandId: 'activate-v2',
            activationLocalDate: '2026-04-06',
            timezoneId: 'Asia/Kolkata',
            cancelPriorOccurrenceIds: {oldOccurrences.first.id},
          ),
        );

        expect(result.occurrences, hasLength(3));
        expect(
          (await calendar.getOccurrence(oldOccurrences.first.id))!.status,
          'cancelled',
        );
        expect(
          (await calendar.getOccurrence(oldOccurrences[1].id))!.status,
          'planned',
        );
        expect(
          (await db.select(db.trainingPlanSettings).getSingle())
              .activeProgramVersionId,
          v2,
        );
      },
    );

    test(
      'rejects an invalid draft without publishing or creating occurrences',
      () async {
        final programId = await programs.createProgram(name: 'Empty draft');
        final version = (await programs.getVersionsForProgram(
          programId,
        )).single;

        await expectLater(
          activation.activate(
            ActivateProgramVersionCommand(
              programVersionId: version.id,
              commandId: 'empty',
              activationLocalDate: '2026-03-02',
              timezoneId: 'Asia/Kolkata',
            ),
          ),
          throwsA(isA<ActivationRejectedException>()),
        );
        expect(
          (await programs.getVersionsForProgram(programId)).single.status,
          'draft',
        );
        expect(await db.select(db.scheduledSessionOccurrences).get(), isEmpty);
      },
    );
  });

  group('B01-06 occurrence state machine', () {
    test(
      'cancellation remains pending and can be restored before execution',
      () async {
        final source = (await activateDraft(await createDraftProgram())).first;
        final cancelled = await calendar.cancel(
          CancelOccurrenceCommand(
            occurrenceId: source.id,
            commandId: 'cancel-1',
            expectedStatus: OccurrenceStatus.planned,
          ),
        );

        expect(cancelled.occurrence.status, 'cancelled');
        expect(cancelled.occurrence.progressionDisposition, 'pending');
        expect(
          (await calendar.getNextRequiredOccurrence(
            source.programVersionId,
          ))!.id,
          source.id,
        );

        final restored = await calendar.restore(
          RestoreOccurrenceCommand(
            occurrenceId: source.id,
            commandId: 'restore-cancelled',
            expectedStatus: OccurrenceStatus.cancelled,
          ),
        );
        expect(restored.occurrence.status, 'planned');
      },
    );

    test(
      'reschedule preserves ordinals, emits one event, and rejects stale commands',
      () async {
        final occurrence = (await activateDraft(
          await createDraftProgram(),
        )).first;
        final moved = await calendar.reschedule(
          RescheduleOccurrenceCommand(
            occurrenceId: occurrence.id,
            commandId: 'move-1',
            expectedStatus: OccurrenceStatus.planned,
            effectiveLocalDate: '2026-03-17',
            effectiveTimezoneId: 'America/New_York',
            confirmed: true,
          ),
        );
        final retry = await calendar.reschedule(
          RescheduleOccurrenceCommand(
            occurrenceId: occurrence.id,
            commandId: 'move-1',
            expectedStatus: OccurrenceStatus.planned,
            effectiveLocalDate: '2026-03-17',
            effectiveTimezoneId: 'America/New_York',
            confirmed: true,
          ),
        );

        expect(moved.occurrence.status, 'rescheduled');
        expect(
          moved.occurrence.programBlockOrdinal,
          occurrence.programBlockOrdinal,
        );
        expect(
          moved.occurrence.programWeekOrdinal,
          occurrence.programWeekOrdinal,
        );
        expect(
          moved.occurrence.originalLocalDate,
          occurrence.originalLocalDate,
        );
        expect(
          moved.occurrence.originalTimezoneId,
          occurrence.originalTimezoneId,
        );
        expect(moved.occurrence.effectiveTimezoneId, 'America/New_York');
        expect(retry.wasIdempotent, isTrue);
        await expectLater(
          calendar.reschedule(
            RescheduleOccurrenceCommand(
              occurrenceId: occurrence.id,
              commandId: 'move-stale',
              expectedStatus: OccurrenceStatus.planned,
              effectiveLocalDate: '2026-03-18',
              effectiveTimezoneId: 'America/New_York',
              confirmed: true,
            ),
          ),
          throwsA(isA<InvalidOccurrenceTransitionException>()),
        );
        await expectLater(
          calendar.skip(
            SkipOccurrenceCommand(
              occurrenceId: occurrence.id,
              commandId: 'move-1',
              expectedStatus: OccurrenceStatus.rescheduled,
              disposition: SkipDisposition.keepPending,
            ),
          ),
          throwsA(isA<InvalidOccurrenceTransitionException>()),
        );
        expect(
          (await calendar.getOccurrence(occurrence.id))!.status,
          'rescheduled',
        );
        expect(
          await calendar.getOccurrenceHistory(occurrence.id),
          hasLength(2),
        );
      },
    );

    test('starting a past occurrence requires confirmation', () async {
      final occurrence = (await activateDraft(
        await createDraftProgram(),
      )).first;
      await calendar.reschedule(
        RescheduleOccurrenceCommand(
          occurrenceId: occurrence.id,
          commandId: 'move-past',
          expectedStatus: OccurrenceStatus.planned,
          effectiveLocalDate: '2026-03-01',
          effectiveTimezoneId: 'Asia/Kolkata',
          confirmed: true,
        ),
      );

      await expectLater(
        calendar.start(
          StartOccurrenceCommand(
            occurrenceId: occurrence.id,
            commandId: 'start-past',
            expectedStatus: OccurrenceStatus.rescheduled,
          ),
        ),
        throwsA(isA<InvalidOccurrenceTransitionException>()),
      );
      final started = await calendar.start(
        StartOccurrenceCommand(
          occurrenceId: occurrence.id,
          commandId: 'start-past-confirmed',
          expectedStatus: OccurrenceStatus.rescheduled,
          confirmedOutsideEffectiveDate: true,
        ),
      );
      expect(started.occurrence.status, 'inProgress');
    });

    test(
      'requires explicit skip disposition and derives progression from roots',
      () async {
        final occurrences = await activateDraft(await createDraftProgram());
        final held = await calendar.skip(
          SkipOccurrenceCommand(
            occurrenceId: occurrences.first.id,
            commandId: 'skip-hold',
            expectedStatus: OccurrenceStatus.planned,
            disposition: SkipDisposition.keepPending,
          ),
        );
        final advanced = await calendar.skip(
          SkipOccurrenceCommand(
            occurrenceId: occurrences[1].id,
            commandId: 'skip-advance',
            expectedStatus: OccurrenceStatus.planned,
            disposition: SkipDisposition.advance,
          ),
        );

        expect(held.occurrence.status, 'skipped');
        expect(held.occurrence.progressionDisposition, 'pending');
        expect(advanced.occurrence.progressionDisposition, 'bypassed');
        expect(
          (await calendar.getNextRequiredOccurrence(
            occurrences.first.programVersionId,
          ))!.id,
          occurrences.first.id,
        );
        await expectLater(
          calendar.repeat(
            RepeatOccurrenceCommand(
              occurrenceId: advanced.occurrence.id,
              commandId: 'bad-makeup',
              expectedStatus: OccurrenceStatus.skipped,
              localDate: '2026-03-20',
              timezoneId: 'Asia/Kolkata',
              purpose: RepeatPurpose.makeUp,
            ),
          ),
          throwsA(isA<InvalidOccurrenceTransitionException>()),
        );
        final restored = await calendar.restore(
          RestoreOccurrenceCommand(
            occurrenceId: held.occurrence.id,
            commandId: 'restore-hold',
            expectedStatus: OccurrenceStatus.skipped,
          ),
        );
        expect(restored.occurrence.status, 'planned');
        expect(restored.occurrence.progressionDisposition, 'pending');
      },
    );

    test(
      'start, discard, full completion, and extra repeat are guarded',
      () async {
        final source = (await activateDraft(await createDraftProgram()))[1];
        await expectLater(
          calendar.start(
            StartOccurrenceCommand(
              occurrenceId: source.id,
              commandId: 'start-future',
              expectedStatus: OccurrenceStatus.planned,
            ),
          ),
          throwsA(isA<InvalidOccurrenceTransitionException>()),
        );
        final started = await calendar.start(
          StartOccurrenceCommand(
            occurrenceId: source.id,
            commandId: 'start-1',
            expectedStatus: OccurrenceStatus.planned,
            confirmedOutsideEffectiveDate: true,
          ),
        );
        expect(started.occurrence.status, 'inProgress');
        final snapshot =
            jsonDecode(started.occurrence.executionSnapshotJson!)
                as Map<String, dynamic>;
        expect(snapshot['programVersion']['id'], source.programVersionId);
        expect(snapshot['template']['name'], 'Session 2');
        expect(snapshot['prescriptions'], hasLength(1));
        expect(await db.select(db.workoutDrafts).get(), hasLength(1));
        final recoveredCalendar = CalendarRepository(
          db,
          dates: LocalScheduleDateService(nowUtc: () => now),
          nowUtc: () => now,
        );
        expect(
          (await recoveredCalendar.getOccurrence(source.id))!.status,
          'inProgress',
        );

        final discarded = await calendar.discardStarted(
          DiscardStartedOccurrenceCommand(
            occurrenceId: source.id,
            commandId: 'discard-1',
            expectedStatus: OccurrenceStatus.inProgress,
          ),
        );
        expect(discarded.occurrence.status, 'planned');
        expect(await db.select(db.workoutDrafts).get(), isEmpty);

        await calendar.start(
          StartOccurrenceCommand(
            occurrenceId: source.id,
            commandId: 'start-2',
            expectedStatus: OccurrenceStatus.planned,
            confirmedOutsideEffectiveDate: true,
          ),
        );
        final sessionId = await insertSession(source.id);
        final completed = await calendar.completeWithPersistedSession(
          CompleteOccurrenceCommand(
            occurrenceId: source.id,
            commandId: 'complete-1',
            expectedStatus: OccurrenceStatus.inProgress,
            workoutSessionId: sessionId,
            completionKind: CompletionKind.full,
          ),
        );
        await (db.delete(
          db.workoutDrafts,
        )..where((row) => row.scheduledOccurrenceId.equals(source.id))).go();
        expect(completed.occurrence.status, 'completed');
        expect(completed.occurrence.progressionDisposition, 'satisfied');
        final completionRetry = await calendar.completeWithPersistedSession(
          CompleteOccurrenceCommand(
            occurrenceId: source.id,
            commandId: 'complete-1',
            expectedStatus: OccurrenceStatus.inProgress,
            workoutSessionId: sessionId,
            completionKind: CompletionKind.full,
          ),
        );
        expect(completionRetry.wasIdempotent, isTrue);
        await expectLater(
          calendar.completeWithPersistedSession(
            CompleteOccurrenceCommand(
              occurrenceId: source.id,
              commandId: 'complete-competing',
              expectedStatus: OccurrenceStatus.inProgress,
              workoutSessionId: sessionId,
              completionKind: CompletionKind.full,
            ),
          ),
          throwsA(isA<InvalidOccurrenceTransitionException>()),
        );
        await expectLater(
          calendar.repeat(
            RepeatOccurrenceCommand(
              occurrenceId: source.id,
              commandId: 'complete-makeup',
              expectedStatus: OccurrenceStatus.completed,
              localDate: '2026-03-20',
              timezoneId: 'Asia/Kolkata',
              purpose: RepeatPurpose.makeUp,
            ),
          ),
          throwsA(isA<InvalidOccurrenceTransitionException>()),
        );
        final extra = await calendar.repeat(
          RepeatOccurrenceCommand(
            occurrenceId: source.id,
            commandId: 'complete-extra',
            expectedStatus: OccurrenceStatus.completed,
            localDate: '2026-03-20',
            timezoneId: 'Asia/Kolkata',
            purpose: RepeatPurpose.extra,
          ),
        );
        expect(extra.repeatedOccurrence.repeatOrdinal, 1);
        expect(extra.repeatedOccurrence.repeatedFromOccurrenceId, source.id);
        expect(extra.source.status, 'completed');
      },
    );

    test(
      'a full make-up repeat satisfies a partial source without reopening it',
      () async {
        final source = (await activateDraft(await createDraftProgram())).first;
        await calendar.start(
          StartOccurrenceCommand(
            occurrenceId: source.id,
            commandId: 'start-partial',
            expectedStatus: OccurrenceStatus.planned,
            confirmedOutsideEffectiveDate: true,
          ),
        );
        final partialSession = await insertSession(source.id);
        await calendar.completeWithPersistedSession(
          CompleteOccurrenceCommand(
            occurrenceId: source.id,
            commandId: 'complete-partial',
            expectedStatus: OccurrenceStatus.inProgress,
            workoutSessionId: partialSession,
            completionKind: CompletionKind.partial,
          ),
        );
        final partialSource = await calendar.getOccurrence(source.id);
        expect(partialSource!.progressionDisposition, 'pending');
        await (db.delete(
          db.workoutDrafts,
        )..where((row) => row.scheduledOccurrenceId.equals(source.id))).go();
        final makeUp = await calendar.repeat(
          RepeatOccurrenceCommand(
            occurrenceId: source.id,
            commandId: 'repeat-makeup',
            expectedStatus: OccurrenceStatus.partiallyCompleted,
            localDate: '2026-03-20',
            timezoneId: 'Asia/Kolkata',
            purpose: RepeatPurpose.makeUp,
          ),
        );
        await calendar.start(
          StartOccurrenceCommand(
            occurrenceId: makeUp.repeatedOccurrence.id,
            commandId: 'start-makeup',
            expectedStatus: OccurrenceStatus.planned,
            confirmedOutsideEffectiveDate: true,
          ),
        );
        final makeupSession = await insertSession(makeUp.repeatedOccurrence.id);
        await calendar.completeWithPersistedSession(
          CompleteOccurrenceCommand(
            occurrenceId: makeUp.repeatedOccurrence.id,
            commandId: 'complete-makeup',
            expectedStatus: OccurrenceStatus.inProgress,
            workoutSessionId: makeupSession,
            completionKind: CompletionKind.full,
          ),
        );

        final originalAfter = await calendar.getOccurrence(source.id);
        expect(originalAfter!.status, 'partiallyCompleted');
        expect(originalAfter.progressionDisposition, 'satisfied');
      },
    );

    test(
      'multiple independently keyed occurrences may share one local date',
      () async {
        final programId = await programs.createProgram(
          name: 'Same-day sessions',
          blocks: [
            ProgramBlockInput(
              name: 'One block',
              ordinal: 0,
              weeks: [
                ProgramWeekInput(
                  name: 'Week 1',
                  ordinalInBlock: 0,
                  programWeekOrdinal: 0,
                  templates: [
                    SessionTemplateInput(
                      name: 'Morning',
                      ordinal: 0,
                      plannedWeekday: DateTime.monday,
                      prescriptions: const [
                        ExercisePrescriptionInput(
                          exerciseId: 'exercise-bench-v1',
                          exerciseNameSnapshot: 'Flat Barbell Bench Press',
                          plannedSets: 3,
                          repsRange: '8-10',
                          ordinal: 0,
                        ),
                      ],
                    ),
                    SessionTemplateInput(
                      name: 'Evening',
                      ordinal: 1,
                      plannedWeekday: DateTime.monday,
                      prescriptions: const [
                        ExercisePrescriptionInput(
                          exerciseId: 'exercise-bench-v1',
                          exerciseNameSnapshot: 'Flat Barbell Bench Press',
                          plannedSets: 3,
                          repsRange: '8-10',
                          ordinal: 0,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
        final version = (await programs.getVersionsForProgram(
          programId,
        )).single;

        final result = await activation.activate(
          ActivateProgramVersionCommand(
            programVersionId: version.id,
            commandId: 'same-day',
            activationLocalDate: '2026-03-02',
            timezoneId: 'Asia/Kolkata',
          ),
        );

        expect(result.occurrences, hasLength(2));
        expect(
          result.occurrences.map((occurrence) => occurrence.effectiveLocalDate),
          everyElement('2026-03-02'),
        );
        expect(
          result.occurrences.map((occurrence) => occurrence.sessionOrdinal),
          [0, 1],
        );
      },
    );
  });
}
