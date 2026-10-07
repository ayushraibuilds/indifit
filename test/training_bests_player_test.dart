import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/indifit_haptics.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_previous_performance_repository.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/b07_exercise_context_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/features/workout_player/b02_strength_execution_controller.dart';
import 'package:indifit/features/workout_player/b02_strength_player_screen.dart';

import 'support/indifit_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late StrengthExecutionRepository executions;
  late List<IndiFitHapticType> haptics;

  setUp(() async {
    database = registerTestDatabaseScope().create();
    executions = StrengthExecutionRepository(
      db: database,
      calendarRepo: CalendarRepository(database),
      nowUtc: () => DateTime.utc(2026, 9, 22, 8),
    );
    haptics = [];
    IndiFitHaptics.debugHandler = haptics.add;
    addTearDown(() => IndiFitHaptics.debugHandler = null);
    await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('exercise-a'),
            name: 'Leg press',
            muscleGroups: 'Legs',
            equipment: 'Machine',
            difficulty: 'Beginner',
            formCues: '',
            commonMistakes: '',
          ),
        );
  });

  Future<void> pumpPlayer(WidgetTester tester) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    final launch = (await tester.runAsync(() async {
      await _insertSavedSession(database, loadKg: 60, reps: 8);
      return _launch(executions);
    }))!;
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = B02StrengthExecutionController(
      StrengthExecutionCompatibilityAdapter(executions),
      initialLaunch: launch,
      nowUtc: () => DateTime.utc(2026, 9, 22, 8),
    );
    await tester.runAsync(controller.loadSlots);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          b07ExerciseContextProvider.overrideWith(
            (ref, id) async => const B07ExerciseContextResult.unavailable(),
          ),
          b02StrengthExecutionScreenControllerProvider.overrideWith(
            (ref, _) => controller,
          ),
          b02PreviousPerformanceRepositoryProvider.overrideWithValue(
            B02PreviousPerformanceRepository(database),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: B02StrengthPlayerScreen(
            launch: launch,
            nowUtc: () => DateTime.utc(2026, 9, 22, 8),
          ),
        ),
      ),
    );
    await tester.pump();
    // Let the in-memory database answer the history reads.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
  }

  Future<void> logFirstSet(WidgetTester tester, {required String load}) async {
    final loadField = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('compact-load-'),
    );
    await tester.enterText(loadField, load);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Log set 1'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    'logging 62.5 kg × 8 after 60 kg × 8 shows New best and one success haptic',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpPlayer(tester);

      // The best to beat sits under the Sets title before anything is logged.
      expect(find.text('Best 60 kg × 8'), findsOneWidget);
      expect(find.text('New best'), findsNothing);

      await logFirstSet(tester, load: '62.5');

      expect(find.text('New best'), findsOneWidget);
      expect(find.bySemanticsLabel('New best, heaviest'), findsOneWidget);
      expect(haptics, [IndiFitHapticType.success]);
      expect(find.textContaining('PR'), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets('logging 60 kg × 8 again shows no best and a normal haptic', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpPlayer(tester);

    await logFirstSet(tester, load: '60');

    final saved = (await tester.runAsync(
      () => executions.readDraft(1),
    ))!.state.performedExercises.expand((exercise) => exercise.sets).single;
    expect(saved.actualLoadKg, 60);
    expect(saved.actualReps, 8);
    expect(find.text('New best'), findsNothing);
    expect(find.byKey(const ValueKey('compact-set-new-best')), findsNothing);
    expect(haptics, [IndiFitHapticType.confirmation]);
    semantics.dispose();
  });
}

Future<void> _insertSavedSession(
  AppDatabase database, {
  required double loadKg,
  required int reps,
}) async {
  final sessionId = await database
      .into(database.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          name: 'Legs',
          totalVolume: loadKg * reps,
          durationSeconds: 600,
          estimatedCalories: 0,
          completedAt: Value(DateTime.utc(2026, 9, 20, 8)),
          completionKind: const Value('full'),
          activityType: Value(B02ActivityType.strength.dbValue),
          activitySchemaVersion: const Value(1),
        ),
      );
  await database
      .into(database.performedExercises)
      .insert(
        PerformedExercisesCompanion.insert(
          id: 'history-performed',
          sessionId: sessionId,
          ordinal: 0,
          actualExerciseId: 'exercise-a',
          actualExerciseNameSnapshot: 'Leg press',
          status: const Value('completed'),
        ),
      );
  await database
      .into(database.performedSets)
      .insert(
        PerformedSetsCompanion.insert(
          id: 'history-set',
          performedExerciseId: 'history-performed',
          ordinal: 0,
          role: B02SetRole.working.dbValue,
          actualLoadKg: Value(loadKg),
          actualLoadBasis: Value(B02LoadBasis.totalExternal.dbValue),
          actualReps: Value(reps),
        ),
      );
}

Future<B02StrengthExecutionLaunch> _launch(
  StrengthExecutionRepository executions,
) async {
  final launch = await executions.startUnscheduledDraft(
    routineName: 'Quick workout',
    snapshotId: 'bests',
    executionSnapshotJson: jsonEncode({
      'version': 1,
      'routineName': 'Quick workout',
      'prescriptions': const <Map<String, dynamic>>[],
    }),
  );
  final withExercise = await executions.addUnscheduledExercise(
    launch: launch,
    exerciseId: 'exercise-a',
    exerciseName: 'Leg press',
    repsRange: '8-10',
  );
  final snapshot =
      jsonDecode(withExercise.executionSnapshotJson) as Map<String, dynamic>;
  final prescriptions = (snapshot['prescriptions'] as List)
      .map((raw) => Map<String, dynamic>.from(raw as Map))
      .toList();
  prescriptions.single['loadBasis'] = B02LoadBasis.totalExternal.dbValue;
  final updated = withExercise.copyWith(
    executionSnapshotJson: jsonEncode({
      ...snapshot,
      'prescriptions': prescriptions,
    }),
  );
  final prepared = await executions.prepareExecution(updated);
  return updated.copyWith(state: prepared.state);
}
