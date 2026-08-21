import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/features/workout_player/workout_execution_context.dart';
import 'package:indifit/features/workout_player/workout_execution_route.dart';
import 'package:indifit/features/workout_player/workout_execution_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late StrengthExecutionRepository executions;

  setUp(() async {
    db = AppDatabase.memory();
    executions = StrengthExecutionRepository(
      db: db,
      calendarRepo: CalendarRepository(db),
      nowUtc: () => DateTime.utc(2026, 8, 21, 8),
    );
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('r08b1-bench'),
            name: 'Bench press',
            muscleGroups: 'Chest',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Brace',
            commonMistakes: 'Bounce',
          ),
        );
  });

  tearDown(() => db.close());

  test('typed context preserves Planned and Quick origin identity', () async {
    final quickLaunch = await _quickLaunch(executions);
    final plannedLaunch = B02StrengthExecutionLaunch(
      draftId: quickLaunch.draftId,
      occurrenceId: 'r08b1-occurrence-17',
      executionSnapshotJson: quickLaunch.executionSnapshotJson,
      state: quickLaunch.state,
    );

    final quick = WorkoutExecutionContext.fromLaunch(quickLaunch);
    final planned = WorkoutExecutionContext.fromLaunch(plannedLaunch);

    expect(quick, isA<QuickWorkoutExecutionContext>());
    expect(quick.scheduledOccurrenceId, isNull);
    expect(quick.draftId, quickLaunch.draftId);
    expect(planned, isA<PlannedWorkoutExecutionContext>());
    expect(
      (planned as PlannedWorkoutExecutionContext).occurrenceId,
      'r08b1-occurrence-17',
    );
    expect(planned.scheduledOccurrenceId, 'r08b1-occurrence-17');
    expect(planned.snapshotId, plannedLaunch.state.snapshotId);
  });

  test(
    'typed player route preserves origin and latest launch identity',
    () async {
      final launch = await _quickLaunch(executions);
      final plannedLaunch = B02StrengthExecutionLaunch(
        draftId: launch.draftId,
        occurrenceId: 'planned-identity',
        executionSnapshotJson: launch.executionSnapshotJson,
        state: launch.state,
      );
      final data = WorkoutExecutionRouteData.fromLaunch(plannedLaunch);

      expect(workoutExecutionRouteDataFromExtra(data), same(data));
      expect(
        workoutExecutionRouteDataFromExtra(data)!.execution,
        isA<PlannedWorkoutExecutionContext>(),
      );
      expect(
        workoutExecutionRouteDataFromExtra(
          plannedLaunch,
        )!.execution.scheduledOccurrenceId,
        'planned-identity',
      );
      expect(
        workoutExecutionRouteDataFromExtra(const <String, Object>{}),
        isNull,
      );
    },
  );

  test('typed variants reject contradictory origin identity', () {
    final quickLaunch = _bareLaunch();
    final plannedLaunch = _bareLaunch(occurrenceId: 'planned-17');

    expect(
      () => PlannedWorkoutExecutionContext(
        launch: quickLaunch,
        occurrenceId: 'planned-17',
      ),
      throwsArgumentError,
    );
    expect(
      () => PlannedWorkoutExecutionContext(
        launch: plannedLaunch,
        occurrenceId: 'different-occurrence',
      ),
      throwsArgumentError,
    );
    expect(
      () => QuickWorkoutExecutionContext(launch: plannedLaunch),
      throwsArgumentError,
    );
    expect(
      () =>
          WorkoutExecutionContext.fromLaunch(_bareLaunch(occurrenceId: '   ')),
      throwsArgumentError,
    );
  });

  test('rebind accepts only the same draft, snapshot, and origin', () {
    final launch = _bareLaunch(occurrenceId: 'planned-17');
    final execution = WorkoutExecutionContext.fromLaunch(launch);
    final updated = B02StrengthExecutionLaunch(
      draftId: launch.draftId,
      occurrenceId: launch.occurrenceId,
      executionSnapshotJson: launch.executionSnapshotJson,
      state: launch.state.copyWith(elapsedSeconds: 75),
    );

    final rebound = execution.rebind(updated);
    expect(rebound, isA<PlannedWorkoutExecutionContext>());
    expect(rebound.draftId, launch.draftId);
    expect(rebound.snapshotId, launch.state.snapshotId);
    expect(rebound.scheduledOccurrenceId, 'planned-17');
    expect(rebound.launch.state.elapsedSeconds, 75);

    expect(
      () =>
          execution.rebind(_bareLaunch(occurrenceId: 'planned-17', draftId: 9)),
      throwsArgumentError,
    );
    expect(
      () => execution.rebind(
        _bareLaunch(
          occurrenceId: 'planned-17',
          snapshotId: 'different-snapshot',
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => execution.rebind(_bareLaunch(occurrenceId: 'different-occurrence')),
      throwsArgumentError,
    );
  });

  test('compatibility payload parsing fails closed for malformed identity', () {
    final malformed = _bareLaunch(occurrenceId: '');

    expect(workoutExecutionRouteDataFromExtra(malformed), isNull);
    expect(
      workoutExecutionRouteDataFromExtra(<String, Object>{'launch': malformed}),
      isNull,
    );
    expect(
      workoutExecutionRouteDataFromExtra(<String, Object>{
        'launch': 'not a launch',
      }),
      isNull,
    );
  });

  test('Quick rebind cannot acquire scheduled identity', () {
    final launch = _bareLaunch();
    final execution = WorkoutExecutionContext.fromLaunch(launch);

    expect(
      () => execution.rebind(_bareLaunch(occurrenceId: 'scheduled')),
      throwsArgumentError,
    );
    expect(execution.scheduledOccurrenceId, isNull);
  });

  testWidgets('the shell exposes common slots and one primary action', (
    tester,
  ) async {
    final launch = _bareLaunch();
    final execution = WorkoutExecutionContext.fromLaunch(launch);

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutExecutionShell(
          execution: execution,
          workoutContextSlot: const Text('workout context'),
          exerciseProgressSlot: const Text('exercise 1 of 1'),
          currentExerciseSlot: const Text('current exercise'),
          setLoggingSlot: const Text('set logging'),
          primaryActionSlot: const FilledButton(
            onPressed: null,
            child: Text('Log set'),
          ),
          nextExerciseSlot: const Text('next exercise'),
          restSlot: const Text('rest slot'),
          completionSlot: const Text('review and completion'),
        ),
      ),
    );

    expect(find.byType(WorkoutExecutionShell), findsOneWidget);
    expect(find.text('workout context'), findsOneWidget);
    expect(find.text('exercise 1 of 1'), findsOneWidget);
    expect(find.text('current exercise'), findsOneWidget);
    expect(find.text('set logging'), findsOneWidget);
    expect(find.text('Log set'), findsOneWidget);
    expect(find.text('next exercise'), findsOneWidget);
    expect(find.text('rest slot'), findsOneWidget);
    expect(find.text('review and completion'), findsOneWidget);
    expect(find.bySemanticsLabel('Primary workout action'), findsOneWidget);
    expect(find.byTooltip('Close workout'), findsOneWidget);
  });

  testWidgets('Planned and Quick contexts both render through the shell', (
    tester,
  ) async {
    final quick = _bareLaunch();
    final planned = _bareLaunch(occurrenceId: 'planned-player-occurrence');

    for (final launch in [quick, planned]) {
      final execution = WorkoutExecutionContext.fromLaunch(launch);
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutExecutionShell(
            execution: execution,
            workoutContextSlot: const Text('execution context'),
            exerciseProgressSlot: const Text('Exercise 1 of 1'),
            currentExerciseSlot: const Text('Bench press'),
            primaryActionSlot: const Text('Log set'),
          ),
        ),
      );

      expect(find.byType(WorkoutExecutionShell), findsOneWidget);
      expect(find.text(execution.workoutTitle), findsOneWidget);
      expect(find.text('execution context'), findsOneWidget);
      expect(find.text('Exercise 1 of 1'), findsOneWidget);
      expect(find.text('Log set'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

B02StrengthExecutionLaunch _bareLaunch({
  String? occurrenceId,
  int draftId = 8,
  String snapshotId = 'r08b1-shell',
}) {
  return B02StrengthExecutionLaunch(
    draftId: draftId,
    occurrenceId: occurrenceId,
    executionSnapshotJson: '{"version":1}',
    state: B02ExecutionDraftState(
      snapshotId: snapshotId,
      snapshotVersion: 1,
      activityType: B02ActivityType.strength,
      routineName: occurrenceId == null ? 'Quick workout' : 'Planned workout',
      elapsedSeconds: 0,
      currentExerciseOrdinal: 0,
      currentSetOrdinal: 0,
    ),
  );
}

Future<B02StrengthExecutionLaunch> _quickLaunch(
  StrengthExecutionRepository executions,
) async {
  var launch = await executions.startUnscheduledDraft(
    routineName: 'Quick workout',
    executionSnapshotJson: jsonEncode({
      'version': 1,
      'routineName': 'Quick workout',
      'prescriptions': const [
        {
          'id': 'r08b1-prescription',
          'exerciseId': 'r08b1-bench',
          'exerciseNameSnapshot': 'Bench press',
          'plannedSets': 1,
          'repsRange': '8-10',
        },
      ],
    }),
    snapshotId: 'r08b1-quick-draft',
  );
  launch = await executions.addUnscheduledExercise(
    launch: launch,
    exerciseId: 'r08b1-bench',
    exerciseName: 'Bench press',
  );
  final prepared = await executions.prepareExecution(launch);
  return launch.copyWith(state: prepared.state);
}
