import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/repositories/program_activation_coordinator.dart';
import 'package:indifit/data/repositories/program_repository.dart';
import 'package:indifit/data/repositories/training_next_action_resolver.dart';
import 'package:indifit/data/services/b02_occurrence_snapshot_customizer.dart';
import 'package:indifit/data/services/b02_strength_execution_draft_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R08C.2 occurrence customization authority', () {
    late AppDatabase db;
    late CalendarRepository calendar;
    late CalendarReadRepository reader;
    late ProgramRepository programs;
    late LocalScheduleDateService dates;
    late String occurrenceId;
    late String versionId;
    late String benchPrescriptionId;

    setUp(() async {
      db = AppDatabase.memory();
      final now = DateTime.utc(2026, 8, 21, 8);
      dates = LocalScheduleDateService(nowUtc: () => now);
      await db.batch(
        (batch) => batch.insertAll(db.exercises, [
          _exercise('bench-press', 'Bench Press', 'Barbell'),
          _exercise('cable-row', 'Cable Row', 'Cable'),
          _exercise('dumbbell-press', 'Dumbbell Press', 'Dumbbell'),
        ]),
      );
      programs = ProgramRepository(db);
      final programId = await programs.createProgram(
        name: 'Customization Plan',
        blocks: [
          ProgramBlockInput(
            name: 'Base block',
            ordinal: 0,
            weeks: [
              ProgramWeekInput(
                name: 'Week 1',
                ordinalInBlock: 0,
                programWeekOrdinal: 0,
                templates: [
                  SessionTemplateInput(
                    name: 'Friday strength',
                    ordinal: 0,
                    plannedWeekday: DateTime.friday,
                    prescriptions: const [
                      ExercisePrescriptionInput(
                        id: 'prescription-bench',
                        exerciseId: 'bench-press',
                        exerciseNameSnapshot: 'Bench Press',
                        plannedSets: 3,
                        repsRange: '8–10',
                        ordinal: 0,
                      ),
                      ExercisePrescriptionInput(
                        id: 'prescription-row',
                        exerciseId: 'cable-row',
                        exerciseNameSnapshot: 'Cable Row',
                        plannedSets: 3,
                        repsRange: '10–12',
                        ordinal: 1,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      versionId = (await programs.getVersionsForProgram(programId)).single.id;
      await ProgramActivationCoordinator(
        db,
        dates: dates,
        nowUtc: () => now,
      ).activate(
        ActivateProgramVersionCommand(
          programVersionId: versionId,
          commandId: 'activate::$versionId',
          activationLocalDate: '2026-08-21',
          timezoneId: 'UTC',
        ),
      );
      reader = CalendarReadRepository(db, dates: dates);
      final snapshot = await reader.readSnapshot(
        startLocalDate: '2026-08-21',
        endLocalDate: '2026-08-21',
        timezoneId: 'UTC',
      );
      final occurrence = snapshot.rangeOccurrences.single;
      occurrenceId = occurrence.occurrence.id;
      benchPrescriptionId = occurrence.prescriptions
          .firstWhere((item) => item.ordinal == 0)
          .id;
      calendar = CalendarRepository(db, dates: dates, nowUtc: () => now);
    });

    tearDown(() => db.close());

    test(
      'customizes one resolved occurrence, persists on reopen, and feeds B02',
      () async {
        final base = await calendar.readWorkoutPreviewSnapshot(occurrenceId);
        final result = await calendar.customize(
          CustomizeOccurrenceCommand(
            occurrenceId: occurrenceId,
            commandId: 'customize::one',
            expectedStatus: OccurrenceStatus.planned,
            baseSnapshotJson: base,
            changes: [
              OccurrenceExerciseCustomization(
                prescriptionId: benchPrescriptionId,
                replacementExerciseId: 'dumbbell-press',
                plannedSets: 4,
                repsRange: '6–8',
              ),
            ],
          ),
        );

        expect(result.occurrence.status, OccurrenceStatus.planned.dbValue);
        expect(result.occurrence.effectiveLocalDate, '2026-08-21');
        expect(result.event.eventType, 'customized');
        final reopened = CalendarRepository(db, dates: dates);
        final customized =
            jsonDecode(await reopened.readWorkoutPreviewSnapshot(occurrenceId))
                as Map<String, dynamic>;
        // The awaited repository read above is intentionally repeated through
        // a new owner to exercise reopen/persistence semantics.
        expect(customized['occurrenceId'], occurrenceId);
        final prescription = (customized['prescriptions'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((item) => item['id'] == benchPrescriptionId);
        expect(prescription['exerciseId'], 'dumbbell-press');
        expect(prescription['exerciseNameSnapshot'], 'Dumbbell Press');
        expect(prescription['expectedExerciseId'], 'bench-press');
        expect(prescription['expectedExerciseNameSnapshot'], 'Bench Press');
        expect(prescription['substitutionReason'], 'User-selected replacement');
        expect(prescription['plannedSets'], 4);
        expect(prescription['repsRange'], '6–8');

        final detail = await programs.getProgramVersionDetail(versionId);
        final original = detail!.exercisePrescriptions.firstWhere(
          (item) => item.id == benchPrescriptionId,
        );
        expect(original.exerciseId, 'bench-press');
        expect(original.exerciseNameSnapshot, 'Bench Press');
        expect(original.plannedSets, 3);
        expect(original.repsRange, '8–10');

        final read = await reader.readSnapshot(
          startLocalDate: '2026-08-21',
          endLocalDate: '2026-08-21',
          timezoneId: 'UTC',
        );
        final resolution = resolveTrainingNextAction(
          snapshot: read,
          localDate: '2026-08-21',
        );
        expect(resolution.currentOrNextOccurrenceId, occurrenceId);
        expect(resolution.todayOccurrence?.occurrence.status, 'planned');

        final execution = StrengthExecutionRepository(
          db: db,
          calendarRepo: calendar,
        );
        final launch = await execution.startScheduledOccurrence(
          occurrenceId: occurrenceId,
          commandId: 'start::customized',
        );
        final slot = (await execution.readExecutionSlots(
          launch,
        )).firstWhere((item) => item.prescriptionId == benchPrescriptionId);
        expect(slot.exerciseId, 'dumbbell-press');
        expect(slot.exerciseNameSnapshot, 'Dumbbell Press');
        expect(slot.expectedExerciseId, 'bench-press');
        expect(slot.expectedExerciseNameSnapshot, 'Bench Press');
        expect(slot.substitutionReason, 'User-selected replacement');
        expect(slot.plannedSets, 4);
        expect(slot.targetRepsMin, 6);
        expect(slot.targetRepsMax, 8);
        final recorded = const B02StrengthExecutionDraftService().recordSet(
          state: launch.state,
          slot: slot,
          reps: 6,
          loadKg: 20,
        );
        final performed = recorded.performedExercises.single;
        expect(performed.expectedExerciseId, 'bench-press');
        expect(performed.expectedExerciseNameSnapshot, 'Bench Press');
        expect(performed.actualExerciseId, 'dumbbell-press');
        expect(performed.actualExerciseNameSnapshot, 'Dumbbell Press');
        expect(performed.substitutionReason, 'User-selected replacement');
      },
    );

    test(
      'failed replacement leaves the saved occurrence snapshot unchanged',
      () async {
        final base = await calendar.readWorkoutPreviewSnapshot(occurrenceId);
        await expectLater(
          calendar.customize(
            CustomizeOccurrenceCommand(
              occurrenceId: occurrenceId,
              commandId: 'customize::invalid',
              expectedStatus: OccurrenceStatus.planned,
              baseSnapshotJson: base,
              changes: [
                OccurrenceExerciseCustomization(
                  prescriptionId: benchPrescriptionId,
                  replacementExerciseId: 'missing-exercise',
                ),
              ],
            ),
          ),
          throwsA(isA<B02ValidationException>()),
        );
        expect(await calendar.readWorkoutPreviewSnapshot(occurrenceId), base);
        expect(await calendar.getOccurrence(occurrenceId), isNotNull);
        expect(
          (await calendar.getOccurrence(occurrenceId))!.status,
          OccurrenceStatus.planned.dbValue,
        );
      },
    );

    test(
      'discarding an unlogged start preserves the prepared workout',
      () async {
        final base = await calendar.readWorkoutPreviewSnapshot(occurrenceId);
        await calendar.customize(
          CustomizeOccurrenceCommand(
            occurrenceId: occurrenceId,
            commandId: 'customize::discard',
            expectedStatus: OccurrenceStatus.planned,
            baseSnapshotJson: base,
            changes: [
              OccurrenceExerciseCustomization(
                prescriptionId: benchPrescriptionId,
                plannedSets: 5,
              ),
            ],
          ),
        );
        await calendar.start(
          StartOccurrenceCommand(
            occurrenceId: occurrenceId,
            commandId: 'start::discard',
            expectedStatus: OccurrenceStatus.planned,
            executionContext: const {'source': 'start-only-context'},
          ),
        );
        await calendar.discardStarted(
          DiscardStartedOccurrenceCommand(
            occurrenceId: occurrenceId,
            commandId: 'discard::prepared',
            expectedStatus: OccurrenceStatus.inProgress,
          ),
        );
        final snapshot =
            jsonDecode(await calendar.readWorkoutPreviewSnapshot(occurrenceId))
                as Map<String, dynamic>;
        final prescription = (snapshot['prescriptions'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((item) => item['id'] == benchPrescriptionId);
        expect(prescription['plannedSets'], 5);
        expect(snapshot, isNot(contains('personalExerciseContext')));
        expect((await calendar.getOccurrence(occurrenceId))!.status, 'planned');
      },
    );

    test(
      'future customization leaves an active draft untouched and terminal states fail closed',
      () async {
        final base = await calendar.readWorkoutPreviewSnapshot(occurrenceId);
        await db
            .into(db.workoutDrafts)
            .insert(
              WorkoutDraftsCompanion.insert(
                routineName: 'Another workout',
                currentExerciseIndex: 0,
                currentSetIndex: 0,
                elapsedSeconds: 0,
                loggedSetsJson: '[]',
              ),
            );
        await calendar.customize(
          CustomizeOccurrenceCommand(
            occurrenceId: occurrenceId,
            commandId: 'customize::with-active-draft',
            expectedStatus: OccurrenceStatus.planned,
            baseSnapshotJson: base,
            changes: [
              OccurrenceExerciseCustomization(
                prescriptionId: benchPrescriptionId,
                plannedSets: 5,
              ),
            ],
          ),
        );
        final activeDraft = await db.select(db.workoutDrafts).getSingle();
        expect(activeDraft.routineName, 'Another workout');
        final customized = await calendar.readWorkoutPreviewSnapshot(
          occurrenceId,
        );
        expect(customized, isNot(base));
        await (db.delete(db.workoutDrafts)).go();

        await (db.update(
          db.scheduledSessionOccurrences,
        )..where((row) => row.id.equals(occurrenceId))).write(
          const ScheduledSessionOccurrencesCompanion(
            status: Value('completed'),
          ),
        );
        await expectLater(
          calendar.customize(
            CustomizeOccurrenceCommand(
              occurrenceId: occurrenceId,
              commandId: 'customize::completed',
              expectedStatus: OccurrenceStatus.completed,
              baseSnapshotJson: customized,
              changes: [
                OccurrenceExerciseCustomization(
                  prescriptionId: benchPrescriptionId,
                  plannedSets: 5,
                ),
              ],
            ),
          ),
          throwsA(isA<InvalidOccurrenceTransitionException>()),
        );
        final terminal = await calendar.getOccurrence(occurrenceId);
        expect(terminal!.status, OccurrenceStatus.completed.dbValue);
        expect(terminal.executionSnapshotJson, customized);
      },
    );

    test('malformed prepared ancestry fails closed before start', () async {
      final base =
          jsonDecode(await calendar.readWorkoutPreviewSnapshot(occurrenceId))
              as Map<String, dynamic>;
      base.remove('programVersion');
      await (db.update(
        db.scheduledSessionOccurrences,
      )..where((row) => row.id.equals(occurrenceId))).write(
        ScheduledSessionOccurrencesCompanion(
          executionSnapshotJson: Value(jsonEncode(base)),
        ),
      );

      await expectLater(
        calendar.start(
          StartOccurrenceCommand(
            occurrenceId: occurrenceId,
            commandId: 'start::malformed-customization',
            expectedStatus: OccurrenceStatus.planned,
          ),
        ),
        throwsA(isA<InvalidOccurrenceTransitionException>()),
      );
      expect((await calendar.getOccurrence(occurrenceId))!.status, 'planned');
      expect(await db.select(db.workoutDrafts).get(), isEmpty);
    });
  });

  test('snapshot customizer rejects group set-count edits', () {
    final snapshot = jsonEncode({
      'occurrenceId': 'occurrence-1',
      'prescriptions': [
        {
          'id': 'prescription-1',
          'ordinal': 0,
          'exerciseId': 'bench-press',
          'exerciseNameSnapshot': 'Bench Press',
          'plannedSets': 3,
          'repsRange': '8–10',
        },
      ],
      'groups': [
        {
          'id': 'group-1',
          'members': [
            {'exercisePrescriptionId': 'prescription-1'},
          ],
        },
      ],
    });

    expect(
      () => const B02OccurrenceSnapshotCustomizer().apply(
        snapshotJson: snapshot,
        occurrenceId: 'occurrence-1',
        changes: [
          OccurrenceExerciseCustomization(
            prescriptionId: 'prescription-1',
            plannedSets: 4,
          ),
        ],
        canonicalExercises: {'bench-press': 'Bench Press'},
      ),
      throwsA(isA<B02ValidationException>()),
    );
  });

  test(
    'snapshot replacement preserves planned identity and clears planned load',
    () {
      final snapshot = jsonEncode({
        'occurrenceId': 'occurrence-1',
        'prescriptions': [
          {
            'id': 'prescription-1',
            'ordinal': 0,
            'exerciseId': 'bench-press',
            'exerciseNameSnapshot': 'Bench Press',
            'plannedSets': 3,
            'repsRange': '8–10',
            'targetLoadKg': 80.0,
            'loadBasis': 'totalExternal',
            'strengthSetPrescriptions': [
              {
                'id': 'set-1',
                'ordinal': 0,
                'targetLoadKg': 80.0,
                'loadBasis': 'totalExternal',
              },
            ],
          },
        ],
        'groups': [],
      });

      final customized =
          jsonDecode(
                const B02OccurrenceSnapshotCustomizer().apply(
                  snapshotJson: snapshot,
                  occurrenceId: 'occurrence-1',
                  changes: const [
                    OccurrenceExerciseCustomization(
                      prescriptionId: 'prescription-1',
                      replacementExerciseId: 'dumbbell-press',
                    ),
                  ],
                  canonicalExercises: const {
                    'bench-press': 'Bench Press',
                    'dumbbell-press': 'Dumbbell Press',
                  },
                ),
              )
              as Map<String, dynamic>;
      final prescription =
          (customized['prescriptions'] as List).single as Map<String, dynamic>;
      expect(prescription['expectedExerciseId'], 'bench-press');
      expect(prescription['exerciseId'], 'dumbbell-press');
      expect(prescription['targetLoadClearedForReplacement'], isTrue);
      expect(prescription, isNot(contains('targetLoadKg')));
      final set =
          (prescription['strengthSetPrescriptions'] as List).single
              as Map<String, dynamic>;
      expect(set, isNot(contains('targetLoadKg')));
    },
  );
}

ExercisesCompanion _exercise(String id, String name, String equipment) {
  return ExercisesCompanion.insert(
    stableId: Value(id),
    name: name,
    muscleGroups: 'Chest',
    equipment: equipment,
    difficulty: 'Intermediate',
    formCues: 'Keep the movement controlled.',
    commonMistakes: 'Do not rush the movement.',
  );
}
