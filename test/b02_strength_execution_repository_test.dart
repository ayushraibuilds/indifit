import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_execution_compatibility_read_repository.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/repositories/program_activation_coordinator.dart';
import 'package:indifit/data/repositories/program_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProgramRepository programs;
  late CalendarRepository calendar;
  late StrengthExecutionRepository executions;

  setUp(() async {
    db = AppDatabase.memory();
    programs = ProgramRepository(db);
    calendar = CalendarRepository(db);
    executions = StrengthExecutionRepository(
      db: db,
      calendarRepo: calendar,
      nowUtc: () => DateTime.utc(2026, 8, 3, 7),
    );
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('bench-stable'),
            name: 'Flat Barbell Bench Press',
            muscleGroups: 'Chest,Triceps',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Brace',
            commonMistakes: 'Elbows',
          ),
        );
  });

  tearDown(() => db.close());

  Future<String> makeOccurrence({
    bool grouped = false,
    String? exerciseId = 'bench-stable',
    bool allowUnresolvedExerciseFallback = false,
  }) async {
    final programId = await programs.createProgram(
      name: 'B02 Strength',
      blocks: [
        ProgramBlockInput(
          name: 'Base',
          ordinal: 0,
          weeks: [
            ProgramWeekInput(
              ordinalInBlock: 0,
              programWeekOrdinal: 0,
              templates: [
                SessionTemplateInput(
                  name: 'Press',
                  ordinal: 0,
                  plannedWeekday: 1,
                  prescriptions: [
                    ExercisePrescriptionInput(
                      id: 'prescription-bench',
                      exerciseId: exerciseId,
                      exerciseNameSnapshot: 'Flat Barbell Bench Press',
                      plannedSets: 1,
                      repsRange: '8-10',
                      ordinal: 0,
                      allowUnresolvedExerciseFallback:
                          allowUnresolvedExerciseFallback,
                    ),
                    if (grouped)
                      const ExercisePrescriptionInput(
                        id: 'prescription-bench-2',
                        exerciseId: 'bench-stable',
                        exerciseNameSnapshot: 'Flat Barbell Bench Press',
                        plannedSets: 1,
                        repsRange: '8-10',
                        ordinal: 1,
                      ),
                  ],
                  groups: grouped
                      ? const [
                          ExerciseGroupInput(
                            id: 'group-bench',
                            ordinal: 0,
                            groupType: B02GroupType.superset,
                            roundCount: 1,
                            members: [
                              ExerciseGroupMemberInput(
                                id: 'member-bench-1',
                                exercisePrescriptionId: 'prescription-bench',
                                ordinal: 0,
                              ),
                              ExerciseGroupMemberInput(
                                id: 'member-bench-2',
                                exercisePrescriptionId: 'prescription-bench-2',
                                ordinal: 1,
                              ),
                            ],
                          ),
                        ]
                      : const [],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    final version = (await programs.getVersionsForProgram(programId)).single;
    final activated = await ProgramActivationCoordinator(db).activate(
      ActivateProgramVersionCommand(
        programVersionId: version.id,
        activationLocalDate: '2026-08-03',
        timezoneId: 'UTC',
        commandId: 'activate-b02',
      ),
    );
    return activated.occurrences.single.id;
  }

  B02ExecutionDraftState performedState(
    B02StrengthExecutionLaunch launch, {
    bool complete = true,
    bool substitute = false,
  }) {
    final group = launch.state.groups.isEmpty
        ? null
        : launch.state.groups.single;
    final member = group?.members.first;
    final performedId = substitute ? 'performed-substitution' : 'performed-1';
    final set = B02PerformedSet(
      id: 'set-1',
      performedExerciseId: performedId,
      ordinal: 0,
      role: B02SetRole.working,
      targetLoadKg: 80,
      targetLoadBasis: B02LoadBasis.totalExternal,
      targetRepsMin: 8,
      targetRepsMax: 10,
      actualLoadKg: 82.5,
      actualLoadBasis: B02LoadBasis.totalExternal,
      actualReps: 8,
      actualRpe: 8,
      technique: B02TechniqueFields(
        effortMode: B02EffortMode.standard,
        tempoEccentricSeconds: 3,
        tempoBottomPauseSeconds: 1,
        tempoConcentricSeconds: 1,
        tempoLockoutPauseSeconds: 0,
      ),
    );
    final exercise = B02PerformedExerciseDraft(
      id: performedId,
      performedExerciseGroupId: group?.id,
      sourceExercisePrescriptionId: member?.exercisePrescriptionId,
      groupMemberOrdinal: member?.ordinal,
      groupRoundOrdinal: group == null ? null : 0,
      ordinal: 0,
      expectedExerciseId: 'bench-stable',
      expectedExerciseNameSnapshot: 'Flat Barbell Bench Press',
      actualExerciseId: 'bench-stable',
      actualExerciseNameSnapshot: 'Flat Barbell Bench Press',
      status: complete ? 'completed' : 'partial',
      substitutionReason: substitute ? 'Shoulder-friendly handle' : null,
      sets: [set],
      targetRecommendation: B02TargetRecommendation(
        id: 'recommendation-1',
        performedExerciseId: performedId,
        ruleVersion: 'target-v1',
        confidence: B02Confidence.medium,
        completeness: const {'recovery': 'unknown'},
        recommendedLoadKg: 80,
        loadBasis: B02LoadBasis.totalExternal,
        targetRepsMin: 8,
        targetRepsMax: 10,
        incrementKg: 2.5,
        rationaleCodes: const ['recent-comparable'],
      ),
    );
    final rest = group == null
        ? const <B02RestPeriod>[]
        : [
            B02RestPeriod(
              id: 'rest-1',
              performedExerciseGroupId: group.id,
              scope: B02RestScope.groupRound,
              recommendedSeconds: 90,
              selectedSeconds: 90,
              actualSeconds: 92,
              source: B02RestSource.prescription,
              startedAtUtc: DateTime.utc(2026, 8, 3, 7),
              endedAtUtc: DateTime.utc(2026, 8, 3, 7, 1, 32),
              endReason: B02RestEndReason.elapsed,
            ),
          ];
    return launch.state.copyWith(
      elapsedSeconds: 180,
      performedExercises: [exercise],
      restPeriods: rest,
    );
  }

  test(
    'persists canonical performed graph, substitution and history projection',
    () async {
      final snapshot = jsonEncode({
        'version': 1,
        'routineName': 'Manual press',
      });
      final launch = await executions.startUnscheduledDraft(
        routineName: 'Manual press',
        executionSnapshotJson: snapshot,
      );
      final state = performedState(launch, substitute: true);
      await executions.saveDraft(draftId: launch.draftId, state: state);

      final sessionId = await executions.finalizeDraft(
        draftId: launch.draftId,
        commandId: 'finish-manual-1',
        state: state,
      );
      expect(
        await executions.finalizeDraft(
          draftId: launch.draftId,
          commandId: 'finish-manual-1',
          state: state,
        ),
        sessionId,
      );
      expect(
        () => executions.finalizeDraft(
          draftId: launch.draftId,
          commandId: 'finish-manual-1',
          state: state.copyWith(elapsedSeconds: 181),
        ),
        throwsA(isA<B02StrengthExecutionFinalizationException>()),
      );
      final session = await (db.select(
        db.workoutSessions,
      )..where((table) => table.id.equals(sessionId))).getSingle();
      expect(session.activityType, 'strength');
      expect(session.durationSeconds, 180);
      expect(await db.select(db.workoutSets).get(), isEmpty);
      final exercise = (await db.select(db.performedExercises).get()).single;
      expect(exercise.expectedExerciseId, 'bench-stable');
      expect(exercise.actualExerciseId, 'bench-stable');
      expect(exercise.substitutionReason, 'Shoulder-friendly handle');
      expect(await db.select(db.performedSets).get(), hasLength(1));
      expect(
        await db.select(db.exerciseTargetRecommendations).get(),
        hasLength(1),
      );
      expect(await db.select(db.workoutDrafts).get(), isEmpty);

      final history = await B02ExecutionCompatibilityReadRepository(
        db,
      ).readSession(sessionId);
      expect(history!.isCanonical, isTrue);
      expect(history.performedExerciseCount, 1);
      expect(history.legacySetCount, 0);
    },
  );

  test(
    'reports canonical template coverage without mutating the occurrence',
    () async {
      final occurrenceId = await makeOccurrence();
      final coverage = await executions.checkScheduledCoverage(occurrenceId);

      expect(coverage.supported, isTrue);
      expect(coverage.reason, isNull);
      expect((await calendar.getOccurrence(occurrenceId))!.status, 'planned');
      expect(await db.select(db.workoutDrafts).get(), isEmpty);
    },
  );

  test(
    'reports unresolved template coverage without mutating the occurrence',
    () async {
      final occurrenceId = await makeOccurrence(
        exerciseId: null,
        allowUnresolvedExerciseFallback: true,
      );
      final coverage = await executions.checkScheduledCoverage(occurrenceId);

      expect(coverage.supported, isFalse);
      expect(coverage.reason, contains('canonical exercise ID'));
      expect((await calendar.getOccurrence(occurrenceId))!.status, 'planned');
      expect(await db.select(db.workoutDrafts).get(), isEmpty);
    },
  );

  test(
    'scheduled completion owns occurrence transition and retries idempotently',
    () async {
      final occurrenceId = await makeOccurrence();
      final launch = await executions.startScheduledOccurrence(
        occurrenceId: occurrenceId,
        commandId: 'start-b02-1',
        confirmedOutsideEffectiveDate: true,
      );
      final state = performedState(launch);
      await executions.saveDraft(draftId: launch.draftId, state: state);
      final first = await executions.finalizeDraft(
        draftId: launch.draftId,
        commandId: 'finish-b02-1',
        state: state,
      );
      final retry = await executions.finalizeDraft(
        draftId: launch.draftId,
        commandId: 'finish-b02-1',
        state: state,
      );
      expect(retry, first);
      expect((await calendar.getOccurrence(occurrenceId))!.status, 'completed');
      expect(await db.select(db.workoutSessions).get(), hasLength(1));
      expect(await db.select(db.workoutDrafts).get(), isEmpty);
    },
  );

  test(
    'draft-scoped completion marker converges concurrent and fresh retries',
    () async {
      final launch = await executions.startUnscheduledDraft(
        routineName: 'Concurrent finish',
        executionSnapshotJson:
            '{"version":1,"routineName":"Concurrent finish"}',
      );
      final state = performedState(launch);
      await executions.saveDraft(draftId: launch.draftId, state: state);

      final results = await Future.wait([
        executions.finalizeDraft(
          draftId: launch.draftId,
          commandId: 'finish-concurrent-a',
          state: state,
        ),
        executions.finalizeDraft(
          draftId: launch.draftId,
          commandId: 'finish-concurrent-b',
          state: state,
        ),
      ]);

      expect(results[0], results[1]);
      expect(
        await executions.finalizeDraft(
          draftId: launch.draftId,
          commandId: 'finish-concurrent-reconstructed',
          state: state,
        ),
        results[0],
      );
      expect(await db.select(db.workoutSessions).get(), hasLength(1));
      expect(await db.select(db.performedExercises).get(), hasLength(1));
      expect(await db.select(db.performedSets).get(), hasLength(1));
      expect(await db.select(db.workoutDrafts).get(), isEmpty);
    },
  );

  test(
    'partial completion is explicit and rollback leaves no session or detail',
    () async {
      final occurrenceId = await makeOccurrence(grouped: true);
      final launch = await executions.startScheduledOccurrence(
        occurrenceId: occurrenceId,
        commandId: 'start-b02-partial',
        confirmedOutsideEffectiveDate: true,
      );
      final state = performedState(launch, complete: false);
      await executions.saveDraft(draftId: launch.draftId, state: state);
      expect(
        () => executions.finalizeDraft(
          draftId: launch.draftId,
          commandId: 'finish-b02-full-invalid',
          state: state,
        ),
        throwsA(isA<B02StrengthExecutionFinalizationException>()),
      );
      expect(await db.select(db.workoutSessions).get(), isEmpty);
      expect(await db.select(db.performedExercises).get(), isEmpty);
      expect(
        (await calendar.getOccurrence(occurrenceId))!.status,
        'inProgress',
      );

      final sessionId = await executions.finalizeDraft(
        draftId: launch.draftId,
        commandId: 'finish-b02-partial',
        state: state,
        completionKind: CompletionKind.partial,
        reason: 'Stopped after first member',
      );
      expect(sessionId, greaterThan(0));
      expect(
        (await calendar.getOccurrence(occurrenceId))!.status,
        'partiallyCompleted',
      );
      expect(
        (await db.select(db.performedExerciseGroups).get()).single.status,
        'partial',
      );
    },
  );

  test(
    'v1 draft is recoverable only through the retained legacy bridge',
    () async {
      final draftId = await db
          .into(db.workoutDrafts)
          .insert(
            WorkoutDraftsCompanion.insert(
              routineName: 'Legacy',
              currentExerciseIndex: 0,
              currentSetIndex: 0,
              elapsedSeconds: 0,
              loggedSetsJson: '{}',
            ),
          );
      expect(
        () => executions.readDraft(draftId),
        throwsA(isA<B02StrengthExecutionRecoveryException>()),
      );
    },
  );
}
