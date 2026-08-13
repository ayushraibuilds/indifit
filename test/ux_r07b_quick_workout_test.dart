import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/repositories/program_repository.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/data/services/b02_rest_recommendation_service.dart';
import 'package:indifit/data/services/b02_strength_execution_draft_service.dart';
import 'package:indifit/features/workout_player/b02_strength_execution_controller.dart';
import 'package:indifit/features/workout_player/b02_strength_player_screen.dart';
import 'package:indifit/features/workout_player/b02_strength_summary_screen.dart';
import 'package:indifit/features/workout_player/quick_workout_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late AppDatabase db;
  late StrengthExecutionRepository executions;

  setUp(() async {
    db = AppDatabase.memory();
    executions = StrengthExecutionRepository(
      db: db,
      calendarRepo: CalendarRepository(db),
      nowUtc: () => DateTime.utc(2026, 8, 10, 8),
    );
    for (final exercise in [
      ('quick-bench', 'Bench press'),
      ('quick-row', 'Seated row'),
    ]) {
      await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              stableId: Value(exercise.$1),
              name: exercise.$2,
              muscleGroups: 'Back,Chest',
              equipment: 'Barbell',
              difficulty: 'Intermediate',
              formCues: 'Brace',
              commonMistakes: 'Rushing',
            ),
          );
    }
  });

  tearDown(() => unawaited(db.close()));

  Future<B02StrengthExecutionLaunch> activeQuickLaunch() async {
    final launch = await executions.startUnscheduledDraft(
      routineName: 'Quick workout',
      executionSnapshotJson: quickWorkoutSnapshotJson('Quick workout'),
    );
    return executions.addUnscheduledExercise(
      launch: launch,
      exerciseId: 'quick-bench',
      exerciseName: 'Bench press',
    );
  }

  Future<B02StrengthExecutionController> preparedController(
    B02StrengthExecutionLaunch launch,
  ) async {
    final controller = B02StrengthExecutionController(
      StrengthExecutionCompatibilityAdapter(executions),
      initialLaunch: launch,
    );
    await controller.loadSlots();
    return controller;
  }

  test('Quick Workout adds and removes canonical exercise slots', () async {
    final launch = await executions.startUnscheduledDraft(
      routineName: 'Quick workout',
      executionSnapshotJson: quickWorkoutSnapshotJson('Quick workout'),
      snapshotId: 'quick-draft-1',
    );
    var withExercises = launch;
    for (final exercise in [
      ('quick-bench', 'Bench press'),
      ('quick-row', 'Seated row'),
      ('quick-bench', 'Bench press'),
      ('quick-row', 'Seated row'),
      ('quick-bench', 'Bench press'),
    ]) {
      withExercises = await executions.addUnscheduledExercise(
        launch: withExercises,
        exerciseId: exercise.$1,
        exerciseName: exercise.$2,
      );
    }

    final added = await executions.readExecutionSlots(withExercises);
    expect(added, hasLength(5));
    expect(
      added.where((slot) => slot.exerciseId == 'quick-bench'),
      hasLength(3),
    );
    final removed = await executions.removeUnscheduledExercise(
      launch: withExercises,
      prescriptionId:
          (jsonDecode(withExercises.executionSnapshotJson)
                  as Map<String, dynamic>)['prescriptions'][0]['id']
              as String,
    );
    final slots = await executions.readExecutionSlots(removed);
    expect(slots, hasLength(4));
    expect(removed.occurrenceId, isNull);
  });

  test(
    'Quick Workout persists unlimited sets and multiple sessions per day',
    () async {
      final service = const B02StrengthExecutionDraftService();

      Future<int> finish(String draftId, String commandId) async {
        final launch = await executions.startUnscheduledDraft(
          routineName: 'Quick workout',
          executionSnapshotJson: jsonEncode({
            'version': 1,
            'routineName': 'Quick workout',
            'prescriptions': [
              {
                'id': 'quick:$draftId',
                'exerciseId': 'quick-bench',
                'exerciseNameSnapshot': 'Bench press',
                'plannedSets': 1,
                'repsRange': '6-12',
              },
            ],
          }),
          snapshotId: draftId,
        );
        final prepared = await executions.prepareExecution(launch);
        final slot = prepared.slots.single;
        var state = prepared.state;
        for (var ordinal = 0; ordinal < 6; ordinal++) {
          state = service.recordSet(
            state: state,
            slot: slot,
            reps: 8 - (ordinal % 2),
            loadKg: 60,
            useSlotPrescription: false,
          );
        }
        expect(state.performedExercises.single.sets, hasLength(6));
        expect(state.performedExercises.single.status, 'completed');
        await executions.saveDraft(draftId: launch.draftId, state: state);
        return executions.finalizeDraft(
          draftId: launch.draftId,
          commandId: commandId,
          state: state,
          completedAtUtc: DateTime.utc(2026, 8, 10, 8),
        );
      }

      final first = await finish('quick-draft-a', 'quick-finish-a');
      final second = await finish('quick-draft-b', 'quick-finish-b');

      expect(first, isNot(second));
      final sessions = await db.select(db.workoutSessions).get();
      expect(sessions, hasLength(2));
      expect(
        sessions.every((session) => session.scheduledOccurrenceId == null),
        isTrue,
      );
      expect(sessions.map((session) => session.id).toSet(), hasLength(2));
      expect(
        sessions.fold<double>(0, (sum, session) => sum + session.totalVolume),
        greaterThan(0),
      );
      expect(await WorkoutRepository(db).getSessions(), hasLength(2));
      expect(await db.select(db.performedSets).get(), hasLength(12));
    },
  );

  test(
    'active training program without a draft does not block Quick',
    () async {
      final programs = ProgramRepository(db);
      final programId = await programs.createProgram(
        name: 'Active strength plan',
        blocks: const [],
      );
      final version = (await programs.getVersionsForProgram(programId)).single;
      await (db.update(db.programVersions)
            ..where((row) => row.id.equals(version.id)))
          .write(const ProgramVersionsCompanion(status: Value('published')));
      await (db.update(
        db.trainingPlanSettings,
      )..where((row) => row.id.equals(1))).write(
        TrainingPlanSettingsCompanion(
          activeProgramVersionId: Value(version.id),
          updatedAtUtc: Value(DateTime.utc(2026, 8, 10, 8)),
        ),
      );

      final launch = await executions.startUnscheduledDraft(
        routineName: 'Quick workout',
        executionSnapshotJson: quickWorkoutSnapshotJson('Quick workout'),
        snapshotId: 'program-does-not-block-quick',
      );

      expect(launch.occurrenceId, isNull);
      expect(await db.select(db.workoutDrafts).get(), hasLength(1));
    },
  );

  test('discard followed by Quick start leaves exactly one draft', () async {
    final existing = await executions.startUnscheduledDraft(
      routineName: 'Quick workout',
      executionSnapshotJson: quickWorkoutSnapshotJson('Quick workout'),
      snapshotId: 'discarded-quick',
    );
    await executions.discardDraft(draftId: existing.draftId);

    final replacement = await executions.startUnscheduledDraft(
      routineName: 'Quick workout',
      executionSnapshotJson: quickWorkoutSnapshotJson('Quick workout'),
      snapshotId: 'replacement-quick',
    );

    final drafts = await db.select(db.workoutDrafts).get();
    expect(drafts, hasLength(1));
    expect(drafts.single.id, replacement.draftId);
    await expectLater(
      executions.startUnscheduledDraft(
        routineName: 'Quick workout',
        executionSnapshotJson: quickWorkoutSnapshotJson('Quick workout'),
        snapshotId: 'duplicate-replacement',
      ),
      throwsA(isA<B02StrengthExecutionException>()),
    );
  });

  testWidgets('Quick Workout is a first-class empty entry surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quickWorkoutActiveDraftProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const QuickWorkoutScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quick workout'), findsOneWidget);
    expect(find.text('Start anywhere'), findsOneWidget);
    expect(find.text('Add exercise'), findsOneWidget);
    expect(find.textContaining('No plan or schedule'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(QuickWorkoutScreen),
      matchesGoldenFile('goldens/ux_r07b_quick_workout_empty_light.png'),
    );
  });

  for (final planned in [false, true]) {
    testWidgets(
      '${planned ? 'planned' : 'Quick'} draft presents consumer recovery actions',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final draft = _conflictingDraft(planned: planned);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              quickWorkoutActiveDraftProvider.overrideWith(
                (ref) async => draft,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const QuickWorkoutScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            planned ? 'You have a workout in progress' : 'Workout in progress',
          ),
          findsOneWidget,
        );
        expect(
          find.text(planned ? 'Resume planned workout' : 'Resume workout'),
          findsOneWidget,
        );
        expect(
          find.text(
            planned
                ? 'Discard draft and start Quick Workout'
                : 'Discard and start new',
          ),
          findsOneWidget,
        );
        expect(find.text('Cancel'), findsOneWidget);
        expect(
          find.textContaining('B02StrengthExecutionException'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Quick draft recovery has a compact dark golden', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: QuickWorkoutConflictSurface(
                draft: _conflictingDraft(planned: false),
                isBusy: false,
                onResume: () {},
                onDiscard: () {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(QuickWorkoutConflictSurface),
      matchesGoldenFile(
        'goldens/ux_r07b_quick_workout_conflict_compact_dark.png',
      ),
    );
  });

  testWidgets('active Quick set stays usable in the compact text matrix', (
    tester,
  ) async {
    final launch = (await tester.runAsync(activeQuickLaunch))!;
    for (final matrix in [
      (const Size(320, 568), 1.0),
      (const Size(390, 844), 1.5),
      (const Size(430, 900), 2.0),
    ]) {
      final controller = (await tester.runAsync(
        () => preparedController(launch),
      ))!;
      tester.view.physicalSize = matrix.$1;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            b02StrengthExecutionScreenControllerProvider.overrideWith(
              (ref, _) => controller,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(matrix.$2)),
              child: B02StrengthPlayerScreen(launch: launch),
            ),
          ),
        ),
      );
      for (var pump = 0; pump < 8; pump++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text('Weight (kg)'), findsOneWidget);
      expect(find.text('RPE'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Log set'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Log set'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    addTearDown(tester.view.reset);
  });

  testWidgets('active Quick set has a compact representative golden', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final launch = (await tester.runAsync(activeQuickLaunch))!;
    final controller = (await tester.runAsync(
      () => preparedController(launch),
    ))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          b02StrengthExecutionScreenControllerProvider.overrideWith(
            (ref, _) => controller,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: B02StrengthPlayerScreen(launch: launch),
        ),
      ),
    );
    for (var pump = 0; pump < 8; pump++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await expectLater(
      find.byType(B02StrengthPlayerScreen),
      matchesGoldenFile('goldens/ux_r07b_quick_workout_active_compact.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('rest controls remain visible at 320 width and 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final recovered = (await tester.runAsync(() async {
      final launch = await activeQuickLaunch();
      final prepared = await executions.prepareExecution(launch);
      final slot = prepared.slots.single;
      final logged = const B02StrengthExecutionDraftService().recordSet(
        state: prepared.state,
        slot: slot,
        reps: 8,
        loadKg: 60,
        useSlotPrescription: false,
      );
      final resting = const B02RestDraftCoordinator().begin(
        logged,
        B02RestPeriod(
          id: 'rest:${slot.id}:0',
          performedSetId: logged.performedExercises.single.sets.single.id,
          scope: B02RestScope.exerciseSet,
          recommendedSeconds: 120,
          selectedSeconds: 120,
          source: B02RestSource.automatic,
          startedAtUtc: DateTime.now().toUtc(),
        ),
      );
      await executions.saveDraft(draftId: launch.draftId, state: resting);
      return executions.readDraft(launch.draftId);
    }))!;
    final controller = (await tester.runAsync(
      () => preparedController(recovered),
    ))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          b02StrengthExecutionScreenControllerProvider.overrideWith(
            (ref, _) => controller,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: B02StrengthPlayerScreen(launch: recovered),
          ),
        ),
      ),
    );
    for (var pump = 0; pump < 5; pump++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.scrollUntilVisible(
      find.text('−15 sec'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('−15 sec'), findsOneWidget);
    expect(find.text('+15 sec'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('completion is readable at compact width and 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final launch = (await tester.runAsync(activeQuickLaunch))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: B02WorkoutCompletionSuccess(launch: launch, onDone: _noop),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(B02WorkoutCompletionSuccess),
      matchesGoldenFile('goldens/ux_r07b_completion_compact_2x_dark.png'),
    );
  });
}

void _noop() {}

WorkoutDraft _conflictingDraft({required bool planned}) => WorkoutDraft(
  id: planned ? 42 : 41,
  routineName: planned ? 'Day 3: Legs & Lower Body' : 'Quick workout',
  currentExerciseIndex: 0,
  currentSetIndex: 0,
  elapsedSeconds: 75,
  loggedSetsJson: '{}',
  updatedAt: DateTime.utc(2026, 8, 12),
  scheduledOccurrenceId: planned ? 'planned-occurrence' : null,
  executionSnapshotJson: '{"version":1}',
  draftSchemaVersion: B02ExecutionDraftState.schemaVersion,
  activityType: B02ActivityType.strength.dbValue,
  executionStateJson: '{}',
);
