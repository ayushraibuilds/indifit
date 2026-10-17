import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/presentation/product_failure_presentation.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_execution_compatibility_read_repository.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/features/workout_player/b02_strength_execution_controller.dart';
import 'package:indifit/features/workout_player/b02_strength_summary_screen.dart';
import 'package:indifit/features/workout_player/workout_execution_context.dart';
import 'support/indifit_test_harness.dart';

void main() {
  _saveLabelTests();
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    // Open the lazy Drift connection before widget tests enter the fake
    // async zone; direct database awaits in a widget test otherwise stall.
    await db.select(db.workoutSessions).get();
  });

  tearDown(() => db.close());

  test(
    'saved strength detail preserves exact IDs, groups, roles and facts',
    () async {
      final sessionId = await _insertSavedStrength(
        db,
        completionKind: CompletionKind.partial,
        totalVolume: 480,
      );

      final detail = await B02ExecutionCompatibilityReadRepository(
        db,
      ).readStrengthSession(sessionId);

      expect(detail, isNotNull);
      expect(detail!.isPartial, isTrue);
      expect(detail.durationSeconds, 1234);
      expect(detail.totalVolumeKg, 480);
      expect(detail.groups.single.id, 'performed-group-1');
      expect(detail.groups.single.completedRounds, 1);
      expect(detail.exercises.single.id, 'performed-exercise-1');
      expect(detail.exercises.single.actualExerciseId, 'replacement-exercise');
      expect(detail.exercises.single.expectedExerciseId, 'planned-exercise');
      expect(detail.exercises.single.wasSubstituted, isTrue);
      expect(detail.exercises.single.sets.single.id, 'performed-set-1');
      expect(detail.exercises.single.sets.single.role, B02SetRole.working);
      expect(detail.exercises.single.sets.single.actualRpe, 8);
      expect(
        detail.exercises.single.segmentsFor(
          detail.exercises.single.sets.single,
        ),
        hasLength(2),
      );
    },
  );

  test(
    'history detail fails closed for a missing or non-strength session',
    () async {
      final otherId = await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              name: 'Running',
              totalVolume: 0,
              durationSeconds: 60,
              estimatedCalories: 0,
              activityType: const Value('running'),
            ),
          );
      final repository = B02ExecutionCompatibilityReadRepository(db);
      expect(await repository.readStrengthSession(404), isNull);
      expect(await repository.readStrengthSession(otherId), isNull);
    },
  );

  test('malformed saved completion state fails closed', () async {
    final sessionId = await _insertSavedStrength(
      db,
      completionKind: CompletionKind.full,
      totalVolume: 0,
    );
    await (db.update(
      db.workoutSessions,
    )..where((table) => table.id.equals(sessionId))).write(
      const WorkoutSessionsCompanion(completionKind: Value('unknown')),
    );

    expect(
      B02ExecutionCompatibilityReadRepository(
        db,
      ).readStrengthSession(sessionId),
      throwsA(isA<B02ValidationException>()),
    );
  });

  testWidgets(
    'saved summary uses persisted duration, identity and partial state',
    tags: const ['golden'],
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final sessionId = (await tester.runAsync(
        () => _insertSavedStrength(
          db,
          completionKind: CompletionKind.partial,
          totalVolume: 480,
        ),
      ))!;
      final history = (await tester.runAsync(
        () => B02ExecutionCompatibilityReadRepository(
          db,
        ).readStrengthSession(sessionId),
      ))!;
      final launch = _launch(
        routineName: 'Stale draft name',
        actualName: 'Stale draft exercise',
        elapsedSeconds: 2,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            workoutSessionWakeLockCoordinatorProvider.overrideWithValue(
              createTestWorkoutWakeLockCoordinator(),
            ),
            b02StrengthHistoryDetailProvider(
              sessionId,
            ).overrideWith((ref) async => history),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: B02WorkoutCompletionSuccess(
                launch: launch,
                sessionId: sessionId,
                completionKind: CompletionKind.partial,
                onDone: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // Let the summary numbers finish counting up (TP-7).
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Workout partially completed'), findsOneWidget);
      expect(find.text('Workout complete'), findsNothing);
      expect(find.text('Persisted strength'), findsOneWidget);
      expect(find.text('Replacement strength'), findsOneWidget);
      expect(find.text('20:34'), findsOneWidget);
      // V6: the hero number and one stats row replace the one-line recap.
      expect(
        find.byKey(const ValueKey('workout_summary_stats_row')),
        findsOneWidget,
      );
      expect(find.text('480 kg'), findsOneWidget);
      expect(find.text('Stale draft exercise'), findsNothing);
      expect(find.textContaining('RPE 8'), findsOneWidget);
      expect(
        find.textContaining('Performed instead of Planned strength'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/r08b8_partial_saved_summary_dark.png'),
      );

      // The weekly goal line watches Drift streams on the real database.
      // Give their zero-duration cleanup timer one frame after disposal
      // instead of leaving a pending timer in the widget binding.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('full summary has one obvious action and no invented metrics', (
    tester,
  ) async {
    final launch = _launch(
      routineName: 'Quick evidence',
      actualName: 'Quick press',
      elapsedSeconds: 90,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: B02WorkoutCompletionSuccess(launch: launch, onDone: () {}),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Workout complete'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.textContaining('kcal'), findsNothing);
    expect(find.textContaining('e1RM'), findsNothing);
    expect(find.textContaining('personal best'), findsNothing);
    expect(find.textContaining('progress'), findsNothing);
    expect(find.textContaining('Target'), findsNothing);
  });

  testWidgets(
    'pre-completion review does not claim persistence early',
    tags: const ['golden'],
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final launch = _launch(
        routineName: 'Quick evidence',
        actualName: 'Quick press',
        elapsedSeconds: 90,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            workoutSessionWakeLockCoordinatorProvider.overrideWithValue(
              createTestWorkoutWakeLockCoordinator(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: B02StrengthSummaryScreen(launch: launch),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Review workout'), findsOneWidget);
      expect(
        find.text('These completed sets will be saved with this workout.'),
        findsOneWidget,
      );
      expect(
        find.text('Your completed sets are saved with this workout.'),
        findsNothing,
      );
      expect(find.text('Complete workout'), findsOneWidget);
      await expectLater(
        find.byType(B02StrengthSummaryScreen),
        matchesGoldenFile('goldens/r08b8_precompletion_review_light.png'),
      );
    },
  );

  test(
    'controller exposes the exact session returned by canonical finalization',
    () async {
      final repository = StrengthExecutionRepository(
        db: db,
        calendarRepo: CalendarRepository(db),
        nowUtc: () => DateTime.utc(2026, 8, 22, 10),
      );
      final adapter = StrengthExecutionCompatibilityAdapter(repository);
      final launch = await adapter.startUnscheduledDraft(
        routineName: 'Controller evidence',
        executionSnapshotJson: '{"version":1}',
      );
      final withExercise = await adapter.addUnscheduledExercise(
        launch: launch,
        exerciseId: 'controller-exercise',
        exerciseName: 'Controller exercise',
      );
      // Quick additions require a canonical exercise row for finalization
      // ancestry validation, so insert it before the actual set is recorded.
      await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              stableId: const Value('controller-exercise'),
              name: 'Controller exercise',
              muscleGroups: 'Chest',
              equipment: 'Barbell',
              difficulty: 'Intermediate',
              formCues: '',
              commonMistakes: '',
            ),
          );
      final exercise = B02PerformedExerciseDraft(
        id: 'performed:controller-exercise',
        ordinal: 0,
        expectedExerciseId: 'controller-exercise',
        expectedExerciseNameSnapshot: 'Controller exercise',
        actualExerciseId: 'controller-exercise',
        actualExerciseNameSnapshot: 'Controller exercise',
        status: 'completed',
        sets: [
          B02PerformedSet(
            id: 'set:controller-exercise:0',
            performedExerciseId: 'performed:controller-exercise',
            ordinal: 0,
            role: B02SetRole.working,
            actualReps: 5,
            actualLoadKg: 40,
            actualLoadBasis: B02LoadBasis.totalExternal,
          ),
        ],
      );
      final finalizedState = withExercise.state.copyWith(
        elapsedSeconds: 60,
        performedExercises: [exercise],
      );
      await adapter.saveDraft(
        draftId: withExercise.draftId,
        state: finalizedState,
      );
      // The adapter-level finalizer is the authority exercised by the player;
      // this test verifies its returned session ID can be read back exactly.
      final sessionId = await adapter.finalizeDraft(
        draftId: withExercise.draftId,
        commandId: 'b8-exact-session',
        state: finalizedState,
      );
      expect(sessionId, greaterThan(0));
      expect(
        (await B02ExecutionCompatibilityReadRepository(
          db,
        ).readStrengthSession(sessionId))!.sessionId,
        sessionId,
      );
    },
  );

  test(
    'ProductFailurePresentation maps incomplete slots and missing reps truthfully',
    () {
      final incomplete = ProductFailurePresentation.fromError(
        const B02StrengthExecutionFinalizationException(
          'Incomplete exercise slots require explicit partial completion.',
        ),
      );
      expect(
        incomplete.message,
        'Incomplete exercises require finishing as a partial workout.',
      );

      final noReps = ProductFailurePresentation.fromError(
        const B02StrengthExecutionFinalizationException(
          'A strength session requires at least one performed set with reps.',
        ),
      );
      expect(
        noReps.message,
        'Log at least one set with completed reps before saving.',
      );

      final noDuration = ProductFailurePresentation.fromError(
        const B02StrengthExecutionFinalizationException(
          'A strength session requires a positive duration.',
        ),
      );
      expect(noDuration.message, 'Workout duration must be at least 1 second.');
    },
  );

  testWidgets('failure screen offers finish as partial workout button', (
    tester,
  ) async {
    var partialTapped = false;
    final launch = _launch(
      routineName: 'Failed workout',
      actualName: 'Exercise 1',
      elapsedSeconds: 60,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: B02SummaryBody(
            launch: launch,
            executionContext: WorkoutExecutionContext.fromLaunch(launch),
            ui: const B02StrengthExecutionUiState(
              status: B02StrengthExecutionStatus.failure,
              errorMessage:
                  'Incomplete exercises require finishing as a partial workout.',
            ),
            onRetry: () {},
            onFull: () {},
            onPartial: () => partialTapped = true,
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Incomplete exercises require finishing as a partial workout.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Finish as partial workout'), findsOneWidget);

    await tester.tap(find.text('Finish as partial workout'));
    await tester.pump();
    expect(partialTapped, isTrue);
  });

  testWidgets('workout with 0 reps disables completion actions', (
    tester,
  ) async {
    final emptyExercise = B02PerformedExerciseDraft(
      id: 'empty-exercise',
      ordinal: 0,
      expectedExerciseId: 'quick-exercise',
      expectedExerciseNameSnapshot: 'Quick press',
      actualExerciseId: 'quick-exercise',
      actualExerciseNameSnapshot: 'Quick press',
      status: 'inProgress',
      sets: const [],
    );
    final emptyLaunch = B02StrengthExecutionLaunch(
      draftId: 92,
      occurrenceId: null,
      executionSnapshotJson: '{"version":1}',
      state: B02ExecutionDraftState(
        snapshotId: 'empty-snapshot',
        snapshotVersion: 1,
        activityType: B02ActivityType.strength,
        routineName: 'Empty workout',
        elapsedSeconds: 10,
        currentExerciseOrdinal: 0,
        currentSetOrdinal: 0,
        performedExercises: [emptyExercise],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          workoutSessionWakeLockCoordinatorProvider.overrideWithValue(
            createTestWorkoutWakeLockCoordinator(),
          ),
        ],
        child: MaterialApp(home: B02StrengthSummaryScreen(launch: emptyLaunch)),
      ),
    );
    await tester.pump();

    expect(find.text('No completed reps yet'), findsOneWidget);
    expect(
      find.text('Log at least one set with completed reps before saving.'),
      findsOneWidget,
    );
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save workout'),
    );
    expect(saveButton.onPressed, isNull);
    expect(find.text('Complete workout'), findsNothing);
  });

  testWidgets(
    'an incomplete workout offers one Save action and no second dialog',
    (tester) async {
      final partialExercise = B02PerformedExerciseDraft(
        id: 'partial-exercise',
        ordinal: 0,
        expectedExerciseId: 'quick-exercise',
        expectedExerciseNameSnapshot: 'Quick press',
        actualExerciseId: 'quick-exercise',
        actualExerciseNameSnapshot: 'Quick press',
        status: 'partial',
        sets: [
          B02PerformedSet(
            id: 'partial-set',
            performedExerciseId: 'partial-exercise',
            ordinal: 0,
            role: B02SetRole.working,
            actualReps: 5,
            actualLoadKg: 50,
            actualLoadBasis: B02LoadBasis.totalExternal,
          ),
        ],
      );
      final partialLaunch = B02StrengthExecutionLaunch(
        draftId: 93,
        occurrenceId: null,
        executionSnapshotJson: '{"version":1}',
        state: B02ExecutionDraftState(
          snapshotId: 'partial-snapshot',
          snapshotVersion: 1,
          activityType: B02ActivityType.strength,
          routineName: 'Partial workout',
          elapsedSeconds: 45,
          currentExerciseOrdinal: 0,
          currentSetOrdinal: 0,
          performedExercises: [partialExercise],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            workoutSessionWakeLockCoordinatorProvider.overrideWithValue(
              createTestWorkoutWakeLockCoordinator(),
            ),
          ],
          child: MaterialApp(
            home: B02StrengthSummaryScreen(launch: partialLaunch),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Complete workout'), findsNothing);
      expect(find.text('Finish partially…'), findsNothing);
      expect(find.text('Save workout'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Keep training'),
        findsOneWidget,
      );
      await tester.tap(find.text('Save workout'));
      await tester.pump();

      expect(find.text('Incomplete workout'), findsNothing);
      expect(find.text('Finish partially?'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}

void _saveLabelTests() {
  group('UR-21 save label', () {
    B02ExecutionDraftState state(List<B02PerformedExerciseDraft> performed) =>
        B02ExecutionDraftState(
          snapshotId: 'label-snapshot',
          snapshotVersion: 1,
          activityType: B02ActivityType.strength,
          routineName: 'Label workout',
          elapsedSeconds: 10,
          currentExerciseOrdinal: 0,
          currentSetOrdinal: 0,
          performedExercises: performed,
        );

    test('counts logged sets against planned ones', () {
      final slots = [_slot('a', 3), _slot('b', 4), _slot('c', 8)];
      final draft = state([
        _performed('a', 1, 'partial'),
        // Extra sets never count past the plan.
        _performed('b', 0, 'partial', ordinal: 1),
      ]);
      expect(b02HasIncompleteExercises(draft), isTrue);
      expect(b02SaveWorkoutLabel(draft, slots), 'Save workout (1 of 15 sets)');
      final over = state([
        _performed('a', 5, 'partial'),
        _performed('b', 1, 'partial', ordinal: 1),
      ]);
      expect(b02SaveWorkoutLabel(over, slots), 'Save workout (4 of 15 sets)');
    });

    test('a workout with nothing planned says Save workout', () {
      expect(
        b02SaveWorkoutLabel(state([_performed('a', 1, 'partial')]), const []),
        'Save workout',
      );
    });

    test('all completed exercises are complete', () {
      expect(
        b02HasIncompleteExercises(state([_performed('a', 3, 'completed')])),
        isFalse,
      );
    });
  });
}

B02StrengthExecutionLaunch _launch({
  required String routineName,
  required String actualName,
  required int elapsedSeconds,
}) {
  final exercise = B02PerformedExerciseDraft(
    id: 'draft-exercise',
    ordinal: 0,
    expectedExerciseId: 'quick-exercise',
    expectedExerciseNameSnapshot: actualName,
    actualExerciseId: 'quick-exercise',
    actualExerciseNameSnapshot: actualName,
    status: 'completed',
    sets: [
      B02PerformedSet(
        id: 'draft-set',
        performedExerciseId: 'draft-exercise',
        ordinal: 0,
        role: B02SetRole.working,
        actualReps: 8,
        actualLoadKg: 60,
        actualLoadBasis: B02LoadBasis.totalExternal,
      ),
    ],
  );
  return B02StrengthExecutionLaunch(
    draftId: 91,
    occurrenceId: null,
    executionSnapshotJson: '{"version":1}',
    state: B02ExecutionDraftState(
      snapshotId: 'b8-snapshot',
      snapshotVersion: 1,
      activityType: B02ActivityType.strength,
      routineName: routineName,
      elapsedSeconds: elapsedSeconds,
      currentExerciseOrdinal: 0,
      currentSetOrdinal: 0,
      performedExercises: [exercise],
    ),
  );
}

Future<int> _insertSavedStrength(
  AppDatabase db, {
  required CompletionKind completionKind,
  required double totalVolume,
}) async {
  await _insertExercise(db, 'planned-exercise', 'Planned strength');
  await _insertExercise(db, 'replacement-exercise', 'Replacement strength');
  final sessionId = await db
      .into(db.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          name: 'Persisted strength',
          totalVolume: totalVolume,
          durationSeconds: 1234,
          estimatedCalories: 0,
          completionKind: Value(completionKind.dbValue),
          activityType: const Value('strength'),
          activitySchemaVersion: const Value(1),
        ),
      );
  await db
      .into(db.performedExerciseGroups)
      .insert(
        PerformedExerciseGroupsCompanion.insert(
          id: 'performed-group-1',
          sessionId: sessionId,
          groupTypeSnapshot: 'superset',
          ordinal: 0,
          plannedRounds: 2,
          completedRounds: const Value(1),
          status: const Value('partial'),
        ),
      );
  await db
      .into(db.performedExercises)
      .insert(
        PerformedExercisesCompanion.insert(
          id: 'performed-exercise-1',
          sessionId: sessionId,
          performedExerciseGroupId: const Value('performed-group-1'),
          groupMemberOrdinal: const Value(0),
          groupRoundOrdinal: const Value(0),
          ordinal: 0,
          expectedExerciseId: const Value('planned-exercise'),
          expectedExerciseNameSnapshot: const Value('Planned strength'),
          actualExerciseId: 'replacement-exercise',
          actualExerciseNameSnapshot: 'Replacement strength',
          status: const Value('partial'),
          substitutionReason: const Value('Equipment unavailable'),
        ),
      );
  await db
      .into(db.performedSets)
      .insert(
        PerformedSetsCompanion.insert(
          id: 'performed-set-1',
          performedExerciseId: 'performed-exercise-1',
          ordinal: 0,
          role: B02SetRole.working.dbValue,
          actualLoadKg: const Value(80),
          actualLoadBasis: const Value('totalExternal'),
          actualReps: const Value(6),
          actualRpe: const Value(8),
          effortMode: const Value('toFailure'),
          endedAtFailure: const Value(true),
        ),
      );
  await db
      .into(db.performedSetSegments)
      .insert(
        PerformedSetSegmentsCompanion.insert(
          id: 'segment-1',
          performedSetId: 'performed-set-1',
          ordinal: 0,
          reps: 4,
          externalLoadKg: const Value(80),
        ),
      );
  await db
      .into(db.performedSetSegments)
      .insert(
        PerformedSetSegmentsCompanion.insert(
          id: 'segment-2',
          performedSetId: 'performed-set-1',
          ordinal: 1,
          reps: 2,
          externalLoadKg: const Value(60),
          restBeforeSeconds: const Value(20),
        ),
      );
  return sessionId;
}

Future<void> _insertExercise(AppDatabase db, String id, String name) => db
    .into(db.exercises)
    .insert(
      ExercisesCompanion.insert(
        stableId: Value(id),
        name: name,
        muscleGroups: 'Chest',
        equipment: 'Barbell',
        difficulty: 'Intermediate',
        formCues: '',
        commonMistakes: '',
      ),
    );

B02StrengthExecutionSlot _slot(String id, int plannedSets) =>
    B02StrengthExecutionSlot(
      id: id,
      groupId: null,
      groupType: null,
      groupLabel: null,
      groupOrdinal: null,
      roundOrdinal: null,
      memberOrdinal: null,
      prescriptionId: 'prescription-$id',
      exerciseId: 'exercise-$id',
      exerciseNameSnapshot: 'Exercise $id',
      plannedSets: plannedSets,
      targetRepsMin: 8,
      targetRepsMax: 10,
      targetRpe: null,
      targetLoadKg: null,
      targetLoadBasis: null,
    );

B02PerformedExerciseDraft _performed(
  String slotId,
  int sets,
  String status, {
  int ordinal = 0,
}) => B02PerformedExerciseDraft(
  id: 'performed:$slotId',
  ordinal: ordinal,
  actualExerciseId: 'exercise-$slotId',
  actualExerciseNameSnapshot: 'Exercise $slotId',
  status: status,
  sets: [
    for (var i = 0; i < sets; i++)
      B02PerformedSet(
        id: '$slotId-set-$i',
        performedExerciseId: 'performed:$slotId',
        ordinal: i,
        role: B02SetRole.working,
        actualReps: 8,
      ),
  ],
);
