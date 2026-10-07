import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/features/progress/training_bests.dart';
import 'package:indifit/features/progress/training_bests_providers.dart';
import 'package:indifit/features/workout_player/widgets/b02_summary_widgets.dart';
import 'package:indifit/features/workout_player/widgets/training_bests_summary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpBlock(WidgetTester tester, List<TrainingBest> bests) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingBestsForSessionProvider.overrideWith(
            (ref, sessionId) async => TrainingBestsResult(bests: bests),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: TrainingBestsSummaryBlock(sessionId: 7)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('summary "New bests" block', () {
    testWidgets('shows nothing without bests', (tester) async {
      await pumpBlock(tester, const []);

      expect(
        find.byKey(const ValueKey('workout_summary_new_bests')),
        findsNothing,
      );
      expect(find.textContaining('best'), findsNothing);
    });

    testWidgets('lists one best with numbers first', (tester) async {
      await pumpBlock(tester, [_best('Leg press', 62.5, 8, 60, 10)]);

      expect(find.text('New best'), findsOneWidget);
      expect(find.text('Leg press'), findsOneWidget);
      expect(
        find.text('Heaviest: 62.5 kg × 8 (was 60 kg × 10)'),
        findsOneWidget,
      );
      expect(find.textContaining('more'), findsNothing);
      expect(find.textContaining('PR'), findsNothing);
    });

    testWidgets('shows the top 3 of 4 bests, then "and 1 more"', (
      tester,
    ) async {
      await pumpBlock(tester, [
        _best('Leg press', 62.5, 8, 60, 10),
        _best('Bench press', 50, 5, 47.5, 5),
        _best('Row', 40, 10, 37.5, 10),
        _best('Curl', 15, 12, 12.5, 12),
      ]);

      expect(find.text('New bests'), findsOneWidget);
      expect(find.text('Row'), findsOneWidget);
      expect(find.text('Curl'), findsNothing);
      expect(find.text('and 1 more'), findsOneWidget);
    });
  });

  group('share card', () {
    final recap = WorkoutCompletionRecap(
      sessionId: 7,
      workoutTitle: 'Legs',
      completedAt: DateTime.utc(2026, 9, 22),
      durationSeconds: 1800,
      isPartial: false,
      totalVolumeKg: 500,
      completedSetsCount: 3,
      completedExercisesCount: 1,
      totalRepsCount: 24,
      exercises: const [],
    ).withBests([_best('Leg press', 62.5, 8, 60, 10)]);

    test('share text includes the bests, without loads when hidden', () {
      expect(
        recap.generateShareText(),
        contains('1 new best (PR): Leg press 62.5 kg × 8'),
      );
      final private = recap.generateShareText(includeWeights: false);
      expect(private, contains('1 new best (PR): Leg press'));
      expect(private, isNot(contains('62.5')));
    });

    testWidgets('card shows one bests line that follows the weights switch', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: WorkoutShareCard(recap: recap)),
          ),
        ),
      );

      expect(find.text('1 new best: Leg press 62.5 kg × 8'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(find.text('1 new best: Leg press'), findsOneWidget);
    });
  });

  testWidgets('saved workout details list the bests and share them', (
    tester,
  ) async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    final sessionId = (await tester.runAsync(() async {
      await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              stableId: const Value('leg-press'),
              name: 'Leg press',
              muscleGroups: 'Legs',
              equipment: 'Machine',
              difficulty: 'Beginner',
              formCues: '',
              commonMistakes: '',
            ),
          );
      await _insertSession(database, 1, DateTime.utc(2026, 9, 20), 60, 10);
      return _insertSession(database, 2, DateTime.utc(2026, 9, 22), 62.5, 8);
    }))!;
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: B02StrengthHistoryDetailScreen(sessionId: sessionId),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }

    expect(
      find.byKey(const ValueKey('workout_summary_new_bests')),
      findsOneWidget,
    );
    expect(find.text('Heaviest: 62.5 kg × 8 (was 60 kg × 10)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('workout_share_appbar_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('workout_share_bests_line')), findsOneWidget);
    expect(find.text('1 new best: Leg press 62.5 kg × 8'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

TrainingBest _best(
  String exercise,
  double load,
  int reps,
  double previousLoad,
  int previousReps,
) => TrainingBest(
  kind: TrainingBestKind.heaviest,
  set: TrainingBestsSetFact(
    setId: '$exercise-now',
    exerciseId: exercise,
    exerciseName: exercise,
    basis: B02LoadBasis.totalExternal,
    loadKg: load,
    reps: reps,
    performedAt: DateTime.utc(2026, 9, 22),
  ),
  previous: TrainingBestsSetFact(
    setId: '$exercise-before',
    exerciseId: exercise,
    exerciseName: exercise,
    basis: B02LoadBasis.totalExternal,
    loadKg: previousLoad,
    reps: previousReps,
    performedAt: DateTime.utc(2026, 9, 20),
  ),
);

Future<int> _insertSession(
  AppDatabase database,
  int index,
  DateTime completedAt,
  double loadKg,
  int reps,
) async {
  final sessionId = await database
      .into(database.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          name: 'Legs $index',
          totalVolume: loadKg * reps,
          durationSeconds: 1800,
          estimatedCalories: 0,
          completedAt: Value(completedAt),
          completionKind: const Value('full'),
          activityType: Value(B02ActivityType.strength.dbValue),
          activitySchemaVersion: const Value(1),
        ),
      );
  await database
      .into(database.performedExercises)
      .insert(
        PerformedExercisesCompanion.insert(
          id: 'performed-$index',
          sessionId: sessionId,
          ordinal: 0,
          actualExerciseId: 'leg-press',
          actualExerciseNameSnapshot: 'Leg press',
          status: const Value('completed'),
        ),
      );
  await database
      .into(database.performedSets)
      .insert(
        PerformedSetsCompanion.insert(
          id: 'set-$index',
          performedExerciseId: 'performed-$index',
          ordinal: 0,
          role: B02SetRole.working.dbValue,
          actualLoadKg: Value(loadKg),
          actualLoadBasis: Value(B02LoadBasis.totalExternal.dbValue),
          actualReps: Value(reps),
        ),
      );
  return sessionId;
}
