import 'dart:convert';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/exercise_identity_fixtures.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/database/b01_legacy_import_support.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_execution_compatibility_read_repository.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/repositories/legacy_program_compatibility_adapter.dart';
import 'package:indifit/data/repositories/program_activation_coordinator.dart';
import 'package:indifit/data/repositories/program_repository.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/data/services/b02_strength_execution_draft_service.dart';
import 'package:indifit/features/workout_player/b02_strength_execution_controller.dart';
import 'package:indifit/features/workout_player/b02_strength_summary_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CalendarRepository calendar;
  late StrengthExecutionRepository executions;
  late WorkoutRepository workouts;

  setUp(() async {
    db = AppDatabase.memory();
    calendar = CalendarRepository(db);
    executions = StrengthExecutionRepository(
      db: db,
      calendarRepo: calendar,
      nowUtc: () => DateTime.utc(2026, 8, 13, 8),
    );
    workouts = WorkoutRepository(db);
    await _insertExercise(db, 'Flat Barbell Bench Press');
    await _insertExercise(db, 'Seated Cable Row');
  });

  tearDown(() => db.close());

  group('R07C workout reliability', () {
    test(
      'physical Quick flow finalizes once, reaches history, and permits another same-day Quick',
      () async {
        final prepared = await _startPreparedQuick(
          executions,
          exerciseNames: const ['Flat Barbell Bench Press', 'Seated Cable Row'],
        );
        var state = prepared.launch.state;
        for (var index = 0; index < prepared.slots.length; index++) {
          state = const B02StrengthExecutionDraftService().recordSet(
            state: state,
            slot: prepared.slots[index],
            reps: index == 0 ? 8 : 10,
            loadKg: index == 0 ? 80 : 60,
            actualLoadBasis: B02LoadBasis.totalExternal,
            rpe: index == 0 ? 8 : 7,
            role: B02SetRole.working,
            useSlotPrescription: false,
          );
          await executions.saveDraft(
            draftId: prepared.launch.draftId,
            state: state,
          );
        }

        const commandId = 'r07c-finish-quick';
        final sessionId = await executions.finalizeDraft(
          draftId: prepared.launch.draftId,
          commandId: commandId,
          state: state,
          completedAtUtc: DateTime.utc(2026, 8, 13, 8, 30),
        );
        final retry = await executions.finalizeDraft(
          draftId: prepared.launch.draftId,
          commandId: commandId,
          state: state,
          completedAtUtc: DateTime.utc(2026, 8, 13, 8, 30),
        );

        expect(retry, sessionId);
        expect(await db.select(db.workoutSessions).get(), hasLength(1));
        expect(await db.select(db.performedExercises).get(), hasLength(2));
        expect(await db.select(db.performedSets).get(), hasLength(2));
        expect(
          (await db.select(db.performedExercises).get()).map(
            (row) => row.actualExerciseId,
          ),
          containsAll([
            _stableId('Flat Barbell Bench Press'),
            _stableId('Seated Cable Row'),
          ]),
        );
        expect(await workouts.getActiveDraft(), isNull);
        final history = await B02ExecutionCompatibilityReadRepository(
          db,
        ).readSession(sessionId);
        expect(history, isNotNull);
        expect(history!.performedExerciseCount, 2);

        final second = await executions.startUnscheduledDraft(
          routineName: 'Quick workout',
          executionSnapshotJson: _quickSnapshot(),
        );
        expect(second.occurrenceId, isNull);
        expect(second.draftId, isNot(prepared.launch.draftId));
        expect(await db.select(db.workoutDrafts).get(), hasLength(1));
      },
    );

    test(
      'mid-transaction failure rolls back and the same command retries',
      () async {
        final prepared = await _startPreparedQuick(
          executions,
          exerciseNames: const ['Flat Barbell Bench Press'],
        );
        final state = const B02StrengthExecutionDraftService().recordSet(
          state: prepared.launch.state,
          slot: prepared.slots.single,
          reps: 8,
          loadKg: 80,
          actualLoadBasis: B02LoadBasis.totalExternal,
          useSlotPrescription: false,
        );
        await executions.saveDraft(
          draftId: prepared.launch.draftId,
          state: state,
        );
        await db.customStatement('''
        CREATE TRIGGER r07c_fail_performed_set
        BEFORE INSERT ON performed_sets
        BEGIN
          SELECT RAISE(ABORT, 'r07c injected performed-set failure');
        END;
      ''');

        await expectLater(
          executions.finalizeDraft(
            draftId: prepared.launch.draftId,
            commandId: 'r07c-retry-command',
            state: state,
          ),
          throwsA(anything),
        );
        expect(await db.select(db.workoutSessions).get(), isEmpty);
        expect(await db.select(db.performedExercises).get(), isEmpty);
        expect(await db.select(db.performedSets).get(), isEmpty);
        expect(await workouts.getActiveDraft(), isNotNull);

        await db.customStatement('DROP TRIGGER r07c_fail_performed_set');
        final sessionId = await executions.finalizeDraft(
          draftId: prepared.launch.draftId,
          commandId: 'r07c-retry-command',
          state: state,
        );
        expect(sessionId, greaterThan(0));
        expect(await db.select(db.workoutSessions).get(), hasLength(1));
        expect(await db.select(db.performedSets).get(), hasLength(1));
        expect(await workouts.getActiveDraft(), isNull);
      },
    );

    test(
      'saved Quick reconstructs through the repository before finish',
      () async {
        final prepared = await _startPreparedQuick(
          executions,
          exerciseNames: const ['Flat Barbell Bench Press'],
        );
        final state = const B02StrengthExecutionDraftService().recordSet(
          state: prepared.launch.state,
          slot: prepared.slots.single,
          reps: 6,
          loadKg: 85,
          actualLoadBasis: B02LoadBasis.totalExternal,
          rpe: 9,
          useSlotPrescription: false,
        );
        await executions.saveDraft(
          draftId: prepared.launch.draftId,
          state: state,
        );

        final reconstructed = await StrengthExecutionRepository(
          db: db,
          calendarRepo: CalendarRepository(db),
          nowUtc: () => DateTime.utc(2026, 8, 13, 9),
        ).readDraft(prepared.launch.draftId);
        final sessionId = await executions.finalizeDraft(
          draftId: reconstructed.draftId,
          commandId: 'r07c-resumed-finish',
          state: reconstructed.state,
        );

        expect(sessionId, greaterThan(0));
        expect((await db.select(db.performedSets).get()).single.actualRpe, 9);
        expect(await workouts.getActiveDraft(), isNull);
      },
    );

    testWidgets(
      'summary Retry replays the same finish command and keeps the draft visible',
      (tester) async {
        final launch = B02StrengthExecutionLaunch(
          draftId: 77,
          occurrenceId: null,
          executionSnapshotJson: _quickSnapshot(),
          state: B02ExecutionDraftState(
            snapshotId: 'r07c-summary-retry',
            snapshotVersion: 1,
            activityType: B02ActivityType.strength,
            routineName: 'Quick workout',
            elapsedSeconds: 60,
            currentExerciseOrdinal: 0,
            currentSetOrdinal: 0,
            performedExercises: [
              B02PerformedExerciseDraft(
                id: 'performed:bench',
                ordinal: 0,
                expectedExerciseId: _stableId('Flat Barbell Bench Press'),
                expectedExerciseNameSnapshot: 'Flat Barbell Bench Press',
                actualExerciseId: _stableId('Flat Barbell Bench Press'),
                actualExerciseNameSnapshot: 'Flat Barbell Bench Press',
                status: 'completed',
                sets: [
                  B02PerformedSet(
                    id: 'set:bench:0',
                    performedExerciseId: 'performed:bench',
                    ordinal: 0,
                    role: B02SetRole.working,
                    actualReps: 8,
                    actualLoadKg: 80,
                  ),
                ],
              ),
            ],
          ),
        );
        final adapter = _FailOnceFinalizationAdapter(executions);
        final controller = B02StrengthExecutionController(
          adapter,
          initialLaunch: launch,
          nowUtc: () => DateTime.utc(2026, 8, 13, 8, 30),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              b02StrengthExecutionScreenControllerProvider.overrideWith(
                (ref, _) => controller,
              ),
            ],
            child: MaterialApp(home: B02StrengthSummaryScreen(launch: launch)),
          ),
        );
        await tester.tap(find.text('Complete workout'));
        for (var pump = 0; pump < 20; pump++) {
          await tester.pump(const Duration(milliseconds: 20));
        }

        expect(
          find.text('Your workout is still here. Nothing was lost.'),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('Return to workout'), findsOneWidget);
        expect(controller.state.launch, isNotNull);

        await tester.tap(find.text('Retry'));
        for (var pump = 0; pump < 20; pump++) {
          await tester.pump(const Duration(milliseconds: 20));
        }

        expect(find.text('Workout complete'), findsWidgets);
        expect(adapter.commandIds, hasLength(2));
        expect(adapter.commandIds.toSet(), hasLength(1));
        expect(controller.state.launch, isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    test(
      'planned finalization preserves occurrence and program ancestry',
      () async {
        final activation = await _saveAndActivateRoutine(
          db: db,
          workouts: workouts,
          name: 'R07C planned ancestry',
          commandId: 'r07c-planned-activation',
        );
        final occurrence = activation.occurrences.first;
        final launch = await executions.startScheduledOccurrence(
          occurrenceId: occurrence.id,
          commandId: 'r07c-planned-start',
          confirmedOutsideEffectiveDate: true,
        );
        final prepared = await executions.prepareExecution(launch);
        var state = prepared.state;
        for (final slot in prepared.slots) {
          for (var set = 0; set < slot.plannedSets; set++) {
            state = const B02StrengthExecutionDraftService().recordSet(
              state: state,
              slot: slot,
              reps: 8,
              loadKg: 80,
              actualLoadBasis: B02LoadBasis.totalExternal,
              useSlotPrescription: true,
              sourceExercisePrescriptionId: slot.prescriptionId,
            );
          }
        }
        await executions.saveDraft(draftId: launch.draftId, state: state);
        final sessionId = await executions.finalizeDraft(
          draftId: launch.draftId,
          commandId: 'r07c-planned-finish',
          state: state,
        );

        final session = await (db.select(
          db.workoutSessions,
        )..where((row) => row.id.equals(sessionId))).getSingle();
        final completedOccurrence = await calendar.getOccurrence(occurrence.id);
        expect(session.scheduledOccurrenceId, occurrence.id);
        expect(
          completedOccurrence!.programVersionId,
          activation.programVersionId,
        );
        expect(completedOccurrence.status, 'completed');
        expect(await workouts.getActiveDraft(), isNull);
      },
    );
  });

  group('R07C program activation reliability', () {
    test(
      'template-style routine activates and refreshes canonical reads',
      () async {
        final result = await _saveAndActivateRoutine(
          db: db,
          workouts: workouts,
          name: 'Push Pull template',
          commandId: 'r07c-template-activation',
        );

        expect(result.wasIdempotent, isFalse);
        expect(result.occurrences, hasLength(2));
        expect(
          (await db.select(db.trainingPlanSettings).get())
              .single
              .activeProgramVersionId,
          result.programVersionId,
        );
        expect(
          await ProgramRepository(
            db,
          ).getProgramVersionDetail(result.programVersionId),
          isNotNull,
        );
        final selection = await LegacyProgramCompatibilityAdapter(
          db,
        ).resolveActivePlanSelection();
        expect(selection.type, ActivePlanType.b01Program);
        expect(selection.programVersionId, result.programVersionId);
        expect(
          await calendar.getOccurrencesInLocalDateRange(
            startLocalDate: '2026-08-13',
            endLocalDate: '2026-08-20',
          ),
          hasLength(2),
        );
        expect(
          (await db.select(db.scheduledSessionOccurrences).get())
              .map((row) => row.id)
              .toSet(),
          hasLength(2),
        );
      },
    );

    test(
      'generated-style activation is idempotent and leaves no duplicates',
      () async {
        final result = await _saveAndActivateRoutine(
          db: db,
          workouts: workouts,
          name: 'Offline generated strength',
          commandId: 'r07c-generated-activation',
        );
        final replay = await ProgramActivationCoordinator(db).activate(
          ActivateProgramVersionCommand(
            programVersionId: result.programVersionId,
            commandId: 'r07c-generated-activation',
            activationLocalDate: '2026-08-13',
            timezoneId: 'Asia/Kolkata',
          ),
        );

        expect(replay.wasIdempotent, isTrue);
        expect(
          replay.occurrences.map((row) => row.id).toSet(),
          result.occurrences.map((row) => row.id).toSet(),
        );
        expect(await db.select(db.programVersions).get(), hasLength(1));
        expect(
          await db.select(db.scheduledSessionOccurrences).get(),
          hasLength(2),
        );
      },
    );

    test(
      'activation graph failure rolls back without a half-active plan',
      () async {
        final routineId = await workouts.saveRoutine(
          name: 'Rollback plan',
          goal: 'strength',
          days: _routineDays(),
        );
        final versionId = B01LegacyImportSupport.programVersionId(routineId);
        await db.customStatement('''
        CREATE TRIGGER r07c_fail_occurrence
        BEFORE INSERT ON scheduled_session_occurrences
        BEGIN
          SELECT RAISE(ABORT, 'r07c injected occurrence failure');
        END;
      ''');

        await expectLater(
          ProgramActivationCoordinator(db).activate(
            ActivateProgramVersionCommand(
              programVersionId: versionId,
              commandId: 'r07c-rollback-activation',
              activationLocalDate: '2026-08-13',
              timezoneId: 'Asia/Kolkata',
            ),
          ),
          throwsA(anything),
        );
        expect(await db.select(db.scheduledSessionOccurrences).get(), isEmpty);
        expect(await db.select(db.occurrenceEvents).get(), isEmpty);
        expect(
          (await db.select(db.programVersions).get()).single.status,
          'draft',
        );
        expect(
          (await db.select(db.trainingPlanSettings).get())
              .single
              .activeProgramVersionId,
          isNull,
        );
      },
    );

    test('replacement follows retain-old-occurrences product rules', () async {
      final first = await _saveAndActivateRoutine(
        db: db,
        workouts: workouts,
        name: 'First active plan',
        commandId: 'r07c-first-activation',
      );
      final replacement = await _saveAndActivateRoutine(
        db: db,
        workouts: workouts,
        name: 'Replacement active plan',
        commandId: 'r07c-replacement-activation',
      );

      expect(replacement.programVersionId, isNot(first.programVersionId));
      expect(
        (await db.select(db.trainingPlanSettings).get())
            .single
            .activeProgramVersionId,
        replacement.programVersionId,
      );
      final occurrences = await db.select(db.scheduledSessionOccurrences).get();
      expect(occurrences, hasLength(4));
      expect(
        occurrences.where(
          (row) => row.programVersionId == first.programVersionId,
        ),
        hasLength(2),
      );
      expect(occurrences.map((row) => row.id).toSet(), hasLength(4));
    });
  });
}

Future<
  ({B02StrengthExecutionLaunch launch, List<B02StrengthExecutionSlot> slots})
>
_startPreparedQuick(
  StrengthExecutionRepository repository, {
  required List<String> exerciseNames,
}) async {
  var launch = await repository.startUnscheduledDraft(
    routineName: 'Quick workout',
    executionSnapshotJson: _quickSnapshot(),
  );
  for (final name in exerciseNames) {
    launch = await repository.addUnscheduledExercise(
      launch: launch,
      exerciseId: _stableId(name),
      exerciseName: name,
    );
  }
  final prepared = await repository.prepareExecution(launch);
  return (
    launch: launch.copyWith(state: prepared.state),
    slots: prepared.slots,
  );
}

Future<ActivationResult> _saveAndActivateRoutine({
  required AppDatabase db,
  required WorkoutRepository workouts,
  required String name,
  required String commandId,
}) async {
  final routineId = await workouts.saveRoutine(
    name: name,
    goal: 'strength',
    days: _routineDays(),
  );
  return LegacyProgramCompatibilityAdapter(db).activateLegacyRoutineAsCanonical(
    legacyRoutineId: routineId,
    activationCoordinator: ProgramActivationCoordinator(db),
    dates: _FixedDates(),
    timezoneId: 'Asia/Kolkata',
    commandId: commandId,
  );
}

List<RoutineDayWithExercises> _routineDays() => [
  RoutineDayWithExercises(
    dayName: 'Push',
    dayOfWeek: DateTime.monday,
    isRestDay: false,
    exercises: [
      RoutineExerciseInput(
        name: 'Flat Barbell Bench Press',
        sets: 3,
        repsRange: '6-8',
      ),
    ],
  ),
  RoutineDayWithExercises(
    dayName: 'Pull',
    dayOfWeek: DateTime.thursday,
    isRestDay: false,
    exercises: [
      RoutineExerciseInput(
        name: 'Seated Cable Row',
        sets: 3,
        repsRange: '8-10',
      ),
    ],
  ),
];

String _quickSnapshot() => jsonEncode({
  'version': 1,
  'routineName': 'Quick workout',
  'prescriptions': const <Map<String, dynamic>>[],
});

String _stableId(String name) {
  final id = ExerciseCatalogManifest
      .goldenCatalogUuids[ExerciseIdentityNormalizer.normalize(name)];
  if (id == null) throw StateError('Missing fixture identity for $name.');
  return id;
}

Future<void> _insertExercise(AppDatabase db, String name) => db
    .into(db.exercises)
    .insert(
      ExercisesCompanion.insert(
        stableId: Value(_stableId(name)),
        name: name,
        muscleGroups: 'Chest,Back',
        equipment: 'Barbell,Cable',
        difficulty: 'Intermediate',
        formCues: 'Brace',
        commonMistakes: 'Rushing',
      ),
      mode: InsertMode.insertOrIgnore,
    );

class _FixedDates extends LocalScheduleDateService {
  _FixedDates() : super(nowUtc: () => DateTime.utc(2026, 8, 13, 8));
}

class _FailOnceFinalizationAdapter
    extends StrengthExecutionCompatibilityAdapter {
  _FailOnceFinalizationAdapter(super.repository);

  final List<String> commandIds = [];
  var _shouldFail = true;

  @override
  Future<void> saveDraft({
    required int draftId,
    required B02ExecutionDraftState state,
  }) async {}

  @override
  Future<int> finalizeDraft({
    required int draftId,
    required String commandId,
    required B02ExecutionDraftState state,
    CompletionKind completionKind = CompletionKind.full,
    String? reason,
    DateTime? completedAtUtc,
  }) {
    commandIds.add(commandId);
    if (_shouldFail) {
      _shouldFail = false;
      return Future<int>.error(
        StateError('r07c injected finalization failure'),
      );
    }
    return Future<int>.value(1);
  }
}
