import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/fixtures/b02_execution_draft_codec.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/services/b02_workout_preparation_orchestrator.dart';
import 'package:indifit/features/workout_player/b02_strength_execution_controller.dart';
import 'package:indifit/features/workout_player/b02_strength_player_screen.dart';
import 'package:indifit/features/workout_player/b02_workout_elapsed.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late StrengthExecutionRepository repository;
  late B02StrengthExecutionController controller;
  late DateTime now;

  B02ExecutionDraftState stateWithTiming({
    required int elapsedSeconds,
    DateTime? activeSegmentStartedAtUtc,
  }) {
    return B02ExecutionDraftState(
      snapshotId: 'timing-snapshot',
      snapshotVersion: 1,
      activityType: B02ActivityType.strength,
      routineName: 'Timing test',
      elapsedSeconds: elapsedSeconds,
      activeSegmentStartedAtUtc: activeSegmentStartedAtUtc,
      currentExerciseOrdinal: 0,
      currentSetOrdinal: 0,
    );
  }

  B02StrengthExecutionController makeController() {
    return B02StrengthExecutionController(
      StrengthExecutionCompatibilityAdapter(repository),
      nowUtc: () => now,
    );
  }

  Future<B02StrengthExecutionSlot> startQuickWithExercise({
    required String stableId,
    required String exerciseName,
    required String routineName,
  }) async {
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: Value(stableId),
            name: exerciseName,
            muscleGroups: 'Chest',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Brace',
            commonMistakes: 'Bounce',
          ),
        );
    await controller.startUnscheduled(
      routineName: routineName,
      executionSnapshotJson: '{"version":1,"routineName":"$routineName"}',
    );
    await controller.addUnscheduledExercise(
      exerciseId: stableId,
      exerciseName: exerciseName,
    );
    return controller.state.slots.single;
  }

  setUp(() {
    db = AppDatabase.memory();
    now = DateTime.utc(2026, 8, 21, 10);
    repository = StrengthExecutionRepository(
      db: db,
      calendarRepo: CalendarRepository(db),
      nowUtc: () => now,
    );
    controller = makeController();
  });

  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  test('elapsed authority derives from persisted segment timing', () {
    final start = DateTime.utc(2026, 8, 21, 10);
    final active = stateWithTiming(
      elapsedSeconds: 120,
      activeSegmentStartedAtUtc: start,
    );
    final paused = stateWithTiming(elapsedSeconds: 120);

    expect(
      b02ElapsedSecondsAt(active, start.add(const Duration(seconds: 65))),
      185,
    );
    expect(
      b02ElapsedSecondsAt(active, start.subtract(const Duration(seconds: 5))),
      120,
    );
    expect(
      b02ElapsedSecondsAt(paused, start.add(const Duration(hours: 2))),
      120,
    );

    final decoded = B02ExecutionDraftState.fromJson(active.toJson());
    expect(decoded.activeSegmentStartedAtUtc, start);

    final legacyV2 = Map<String, dynamic>.from(paused.toJson())
      ..remove('activeSegmentStartedAtUtc');
    expect(
      B02ExecutionDraftState.fromJson(legacyV2).activeSegmentStartedAtUtc,
      isNull,
    );
  });

  test(
    'restore preserves the active segment instead of restarting it',
    () async {
      await controller.startUnscheduled(
        routineName: 'Restore timing',
        executionSnapshotJson: '{"version":1,"routineName":"Restore timing"}',
      );
      final draftId = controller.state.launch!.draftId;

      now = now.add(const Duration(seconds: 60));
      await controller.saveDraft(controller.state.launch!.state);
      final persistedActiveStart =
          controller.state.launch!.state.activeSegmentStartedAtUtc;
      expect(persistedActiveStart, now);

      controller.dispose();
      controller = makeController();
      now = now.add(const Duration(seconds: 10));
      await controller.recover(draftId);

      expect(controller.state.launch!.state.elapsedSeconds, 60);
      expect(
        controller.state.launch!.state.activeSegmentStartedAtUtc,
        persistedActiveStart,
      );
      expect(b02ElapsedSecondsAt(controller.state.launch!.state, now), 70);

      await controller.pauseElapsed();
      expect(controller.state.launch!.state.elapsedSeconds, 70);
      expect(controller.state.launch!.state.activeSegmentStartedAtUtc, isNull);
    },
  );

  test('loadSlots re-entry resumes a paused durable draft', () async {
    await controller.startUnscheduled(
      routineName: 'Re-entry timing',
      executionSnapshotJson: '{"version":1,"routineName":"Re-entry timing"}',
    );

    now = now.add(const Duration(seconds: 60));
    await controller.pauseElapsed();
    final pausedLaunch = controller.state.launch!;
    expect(pausedLaunch.state.activeSegmentStartedAtUtc, isNull);

    controller.dispose();
    now = now.add(const Duration(seconds: 30));
    controller = B02StrengthExecutionController(
      StrengthExecutionCompatibilityAdapter(repository),
      initialLaunch: pausedLaunch,
      nowUtc: () => now,
    );
    await controller.loadSlots();

    expect(controller.state.launch!.state.elapsedSeconds, 60);
    expect(controller.state.launch!.state.activeSegmentStartedAtUtc, now);
  });

  test(
    'materializing elapsed seconds preserves the fractional remainder',
    () async {
      final startedAt = now;
      await controller.startUnscheduled(
        routineName: 'Fractional timing',
        executionSnapshotJson:
            '{"version":1,"routineName":"Fractional timing"}',
      );

      now = now.add(const Duration(milliseconds: 1500));
      expect(
        await controller.saveDraft(controller.state.launch!.state),
        isTrue,
      );
      expect(controller.state.launch!.state.elapsedSeconds, 1);
      expect(
        controller.state.launch!.state.activeSegmentStartedAtUtc,
        startedAt.add(const Duration(seconds: 1)),
      );

      now = now.add(const Duration(milliseconds: 1500));
      expect(
        await controller.saveDraft(controller.state.launch!.state),
        isTrue,
      );
      expect(controller.state.launch!.state.elapsedSeconds, 3);
      expect(
        controller.state.launch!.state.activeSegmentStartedAtUtc,
        startedAt.add(const Duration(seconds: 3)),
      );
    },
  );

  test(
    'background interval is excluded and rapid lifecycle writes converge',
    () async {
      await controller.startUnscheduled(
        routineName: 'Lifecycle timing',
        executionSnapshotJson: '{"version":1,"routineName":"Lifecycle timing"}',
      );

      now = now.add(const Duration(seconds: 60));
      final pause = controller.pauseElapsed();
      now = now.add(const Duration(seconds: 10));
      final resume = controller.resumeElapsed();
      expect(await Future.wait([pause, resume]), [true, true]);

      final state = controller.state.launch!.state;
      expect(state.elapsedSeconds, 60);
      expect(state.activeSegmentStartedAtUtc, now);

      now = now.add(const Duration(seconds: 10));
      await controller.pauseElapsed();
      expect(controller.state.launch!.state.elapsedSeconds, 70);
      expect(controller.state.launch!.state.activeSegmentStartedAtUtc, isNull);

      final draft =
          await (db.select(db.workoutDrafts)..where(
                (table) => table.id.equals(controller.state.launch!.draftId),
              ))
              .getSingle();
      final persisted = B02ExecutionDraftCodec.decode(
        draft.executionStateJson!,
      ).state!;
      expect(persisted.elapsedSeconds, 70);
      expect(persisted.activeSegmentStartedAtUtc, isNull);
    },
  );

  test(
    'failed pause stays paused in memory and resume retries persistence',
    () async {
      await controller.startUnscheduled(
        routineName: 'Pause retry',
        executionSnapshotJson: '{"version":1,"routineName":"Pause retry"}',
      );
      final draftId = controller.state.launch!.draftId;
      now = now.add(const Duration(seconds: 60));
      await db.customStatement('''
      CREATE TRIGGER r08a3_fail_pause_update
      BEFORE UPDATE ON workout_drafts
      BEGIN
        SELECT RAISE(ABORT, 'r08a3 injected pause failure');
      END;
    ''');

      expect(await controller.pauseElapsed(), isFalse);
      expect(controller.state.launch!.state.elapsedSeconds, 60);
      expect(controller.state.launch!.state.activeSegmentStartedAtUtc, isNull);

      await db.customStatement('DROP TRIGGER r08a3_fail_pause_update');
      now = now.add(const Duration(seconds: 30));
      expect(await controller.resumeElapsed(), isTrue);
      expect(controller.state.launch!.state.elapsedSeconds, 60);
      expect(controller.state.launch!.state.activeSegmentStartedAtUtc, now);

      final persisted = B02ExecutionDraftCodec.decode(
        (await (db.select(
              db.workoutDrafts,
            )..where((table) => table.id.equals(draftId))).getSingle())
            .executionStateJson!,
      ).state!;
      expect(persisted.elapsedSeconds, 60);
      expect(persisted.activeSegmentStartedAtUtc, now);
    },
  );

  test('completion drains an immediately preceding set write', () async {
    final slot = await startQuickWithExercise(
      stableId: 'queued-finish-bench',
      exerciseName: 'Queued finish bench',
      routineName: 'Queued finish',
    );
    now = now.add(const Duration(seconds: 60));

    final recording = controller.recordSet(
      slot: slot,
      reps: 8,
      loadKg: 60,
      actualLoadBasis: B02LoadBasis.totalExternal,
    );
    final finishing = controller.finalize(commandId: 'queued-finish');

    await recording;
    expect(await finishing, isTrue);
    expect(await db.select(db.workoutSessions).get(), hasLength(1));
    expect(await db.select(db.performedSets).get(), hasLength(1));
    expect(await db.select(db.workoutDrafts).get(), isEmpty);
  });

  test('controller coalesces overlapping completion requests', () async {
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('controller-bench'),
            name: 'Controller bench',
            muscleGroups: 'Chest',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Brace',
            commonMistakes: 'Bounce',
          ),
        );
    await controller.startUnscheduled(
      routineName: 'Controller finish',
      executionSnapshotJson: '{"version":1,"routineName":"Controller finish"}',
    );
    await controller.addUnscheduledExercise(
      exerciseId: 'controller-bench',
      exerciseName: 'Controller bench',
    );
    final slot = controller.state.slots.single;
    now = now.add(const Duration(seconds: 60));
    await controller.recordSet(
      slot: slot,
      reps: 8,
      loadKg: 60,
      actualLoadBasis: B02LoadBasis.totalExternal,
    );

    final first = controller.finalize(commandId: 'controller-finish-a');
    final second = controller.finalize(commandId: 'controller-finish-b');
    expect(identical(first, second), isTrue);
    expect(await Future.wait([first, second]), [true, true]);
    expect(await db.select(db.workoutSessions).get(), hasLength(1));
    expect(await db.select(db.performedSets).get(), hasLength(1));
    expect(await db.select(db.workoutDrafts).get(), isEmpty);
  });

  test(
    'controller rejects a conflicting overlapping completion payload',
    () async {
      final slot = await startQuickWithExercise(
        stableId: 'conflicting-finish-bench',
        exerciseName: 'Conflicting finish bench',
        routineName: 'Conflicting finish',
      );
      now = now.add(const Duration(seconds: 60));
      await controller.recordSet(
        slot: slot,
        reps: 8,
        loadKg: 60,
        actualLoadBasis: B02LoadBasis.totalExternal,
      );

      final full = controller.finalize(commandId: 'conflicting-full');
      final partial = controller.finalize(
        commandId: 'conflicting-partial',
        completionKind: CompletionKind.partial,
        reason: 'Competing request',
      );

      expect(identical(full, partial), isFalse);
      expect(await partial, isFalse);
      expect(await full, isTrue);
      final sessions = await db.select(db.workoutSessions).get();
      expect(sessions, hasLength(1));
      expect(sessions.single.completionKind, CompletionKind.full.dbValue);
      expect(await db.select(db.workoutDrafts).get(), isEmpty);
    },
  );

  test(
    'failed finalization retains the durable final state for retry',
    () async {
      await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              stableId: const Value('controller-retry-bench'),
              name: 'Controller retry bench',
              muscleGroups: 'Chest',
              equipment: 'Barbell',
              difficulty: 'Intermediate',
              formCues: 'Brace',
              commonMistakes: 'Bounce',
            ),
          );
      await controller.startUnscheduled(
        routineName: 'Controller retry',
        executionSnapshotJson: '{"version":1,"routineName":"Controller retry"}',
      );
      await controller.addUnscheduledExercise(
        exerciseId: 'controller-retry-bench',
        exerciseName: 'Controller retry bench',
      );
      final slot = controller.state.slots.single;
      now = now.add(const Duration(seconds: 60));
      await controller.recordSet(
        slot: slot,
        reps: 8,
        loadKg: 60,
        actualLoadBasis: B02LoadBasis.totalExternal,
      );

      await db.customStatement('''
      CREATE TRIGGER r08a3_fail_finalization
      BEFORE INSERT ON performed_sets
      BEGIN
        SELECT RAISE(ABORT, 'r08a3 injected finalization failure');
      END;
    ''');

      expect(
        await controller.finalize(commandId: 'controller-retry-first'),
        isFalse,
      );
      final failedState = controller.state.launch!.state;
      expect(failedState.activeSegmentStartedAtUtc, isNull);
      final persisted = B02ExecutionDraftCodec.decode(
        (await (db.select(db.workoutDrafts)..where(
                  (table) => table.id.equals(controller.state.launch!.draftId),
                ))
                .getSingle())
            .executionStateJson!,
      ).state!;
      expect(persisted.toJson(), failedState.toJson());

      await db.customStatement('DROP TRIGGER r08a3_fail_finalization');
      expect(
        await controller.finalize(commandId: 'controller-retry-second'),
        isTrue,
      );
      expect(await db.select(db.workoutSessions).get(), hasLength(1));
      expect(await db.select(db.performedSets).get(), hasLength(1));
      expect(await db.select(db.workoutDrafts).get(), isEmpty);
    },
  );

  testWidgets('live elapsed text repaints without writing draft state', (
    tester,
  ) async {
    var viewNow = DateTime.utc(2026, 8, 21, 10);
    final start = viewNow;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: B02LiveElapsedText(
            accumulatedSeconds: 60,
            activeSegmentStartedAtUtc: start,
            nowUtc: () => viewNow,
            tickInterval: const Duration(seconds: 1),
          ),
        ),
      ),
    );
    expect(find.text('1:00'), findsOneWidget);

    viewNow = viewNow.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1:02'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: B02LiveElapsedText(
            accumulatedSeconds: 62,
            activeSegmentStartedAtUtc: null,
            nowUtc: () => viewNow,
          ),
        ),
      ),
    );
    viewNow = viewNow.add(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('1:02'), findsOneWidget);
  });

  test(
    'failed pause persistence is retried before allowing close',
    () async {
      now = DateTime.utc(2026, 8, 21, 10);
      final launch = B02StrengthExecutionLaunch(
        draftId: 2,
        occurrenceId: null,
        executionSnapshotJson:
            '{"version":1,"routineName":"Pause retry"}',
        state: B02ExecutionDraftState(
          snapshotId: 'pause-retry-test',
          snapshotVersion: 1,
          activityType: B02ActivityType.strength,
          routineName: 'Pause retry',
          elapsedSeconds: 0,
          activeSegmentStartedAtUtc: now,
          currentExerciseOrdinal: 0,
          currentSetOrdinal: 0,
        ),
      );
      final adapter = _RouteTestAdapter(repository)
        ..saveFailuresRemaining = 1;
      final retryController = B02StrengthExecutionController(
        adapter,
        initialLaunch: launch,
        nowUtc: () => now,
      );
      addTearDown(retryController.dispose);

      expect(await retryController.pauseElapsed(), isFalse);
      expect(adapter.lastSavedState, isNull);
      expect(
        retryController.state.launch!.state.activeSegmentStartedAtUtc,
        isNull,
      );

      expect(await retryController.pauseElapsed(), isTrue);
      expect(adapter.lastSavedState?.activeSegmentStartedAtUtc, isNull);
    },
  );

  testWidgets('close flow pauses the durable segment before route exit', (
    tester,
  ) async {
    now = DateTime.utc(2026, 8, 21, 10);
    final launch = B02StrengthExecutionLaunch(
      draftId: 1,
      occurrenceId: null,
      executionSnapshotJson:
          '{"version":1,"routineName":"Back-safe workout"}',
      state: B02ExecutionDraftState(
        snapshotId: 'route-test',
        snapshotVersion: 1,
        activityType: B02ActivityType.strength,
        routineName: 'Back-safe workout',
        elapsedSeconds: 0,
        activeSegmentStartedAtUtc: now,
        currentExerciseOrdinal: 0,
        currentSetOrdinal: 0,
      ),
    );
    final adapter = _RouteTestAdapter(repository);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/workout'),
              child: const Text('Open workout'),
            ),
          ),
        ),
        GoRoute(
          path: '/workout',
          builder: (context, state) => B02StrengthPlayerScreen(
            launch: launch,
            nowUtc: () => now,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          strengthExecutionCompatibilityAdapterProvider.overrideWithValue(
            adapter,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.tap(find.text('Open workout'));
    // The player owns a one-second repaint timer while mounted, so an
    // unbounded pumpAndSettle would wait forever. Advance only through the
    // route transition and the initial controller frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    await tester.tap(find.byTooltip('Close workout'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Save and close workout?'), findsOneWidget);

    await tester.tap(find.text('Save and close'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Open workout'), findsOneWidget);
    expect(adapter.lastSavedState?.activeSegmentStartedAtUtc, isNull);
  });
}

class _RouteTestAdapter extends StrengthExecutionCompatibilityAdapter {
  _RouteTestAdapter(super.repository);

  B02ExecutionDraftState? lastSavedState;
  int saveFailuresRemaining = 0;

  @override
  Future<B02WorkoutPreparationResult> prepareExecution(
    B02StrengthExecutionLaunch launch,
  ) async => B02WorkoutPreparationResult(
    state: launch.state,
    slots: const [],
    changed: false,
  );

  @override
  Future<void> saveDraft({
    required int draftId,
    required B02ExecutionDraftState state,
  }) async {
    if (saveFailuresRemaining > 0) {
      saveFailuresRemaining -= 1;
      throw StateError('synthetic pause persistence failure');
    }
    lastSavedState = state;
  }
}
