import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/utils/weekly_training_goal_calculator.dart';
import 'package:indifit/features/workout_player/widgets/b02_summary_widgets.dart';
import 'package:indifit/features/workout_player/widgets/workout_payoff_widgets.dart';

/// V6 (PREMIUM_REDESIGN_PLAN § 8.3): the summary hero and the story share
/// image.
void main() {
  WorkoutCompletionRecap recap({double volume = 1440, int reps = 24}) =>
      WorkoutCompletionRecap(
        workoutTitle: 'Full Body C',
        completedAt: DateTime(2026, 10, 8, 18),
        durationSeconds: 82,
        isPartial: false,
        totalVolumeKg: volume,
        completedSetsCount: 3,
        completedExercisesCount: 1,
        totalRepsCount: reps,
        exercises: const [],
      );

  group('hero number', () {
    test('kilograms when any load was lifted, else reps, else nothing', () {
      final kg = workoutSummaryHeroNumber(totalLiftedKg: 1440, repCount: 24)!;
      expect(kg.format(kg.value), '1,440 kg');
      expect(kg.label, 'Total lifted');
      expect(kg.isReps, isFalse);

      final reps = workoutSummaryHeroNumber(totalLiftedKg: 0, repCount: 24)!;
      expect(reps.format(reps.value), '24');
      expect(reps.label, 'Reps');
      expect(reps.isReps, isTrue);

      expect(workoutSummaryHeroNumber(totalLiftedKg: 0, repCount: 0), isNull);
    });

    test('the story card uses a stopwatch duration', () {
      expect(formatStoryDuration(82), '1:22');
      expect(formatStoryDuration(2700), '45:00');
      expect(formatStoryDuration(3909), '1:05:09');
    });

    test('stats leave out what is unknown and use singulars', () {
      expect(
        workoutSummaryStats(setCount: 1, repCount: 0, durationLabel: null),
        [(value: '1', label: 'Set')],
      );
      expect(
        workoutSummaryStats(setCount: 3, repCount: 24, durationLabel: '1 min'),
        [
          (value: '3', label: 'Sets'),
          (value: '24', label: 'Reps'),
          (value: '1 min', label: 'Duration'),
        ],
      );
    });
  });

  group('summary hero', () {
    Future<void> pumpHero(WidgetTester tester, {double textScale = 1}) =>
        tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(390, 844),
                textScaler: TextScaler.linear(textScale),
              ),
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: WorkoutSummaryHero(
                    isPartial: false,
                    routineName: 'Full Body C',
                    savedLine: 'Your workout is saved to history.',
                    totalLiftedKg: 1440,
                    setCount: 3,
                    repCount: 24,
                    durationLabel: '1 min 22 sec',
                  ),
                ),
              ),
            ),
          ),
        );

    testWidgets('stats sit in one row and are read as one phrase each', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpHero(tester);
      await tester.pumpAndSettle();

      final row = find.byKey(const ValueKey('workout_summary_stats_row'));
      final sets = tester.getCenter(find.text('3'));
      final duration = tester.getCenter(find.text('1 min 22 sec'));
      expect(sets.dy, closeTo(duration.dy, 0.5));
      expect(
        find.descendant(of: row, matching: find.byType(VerticalDivider)),
        findsNWidgets(2),
      );
      expect(find.bySemanticsLabel('24 reps'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('large text stacks the stats without overflow', (tester) async {
      await pumpHero(tester, textScale: 2);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final sets = tester.getCenter(find.text('3'));
      final duration = tester.getCenter(find.text('1 min 22 sec'));
      expect(duration.dy, greaterThan(sets.dy));
    });
  });

  testWidgets('a met week goal pill gets a tick', (tester) async {
    Future<void> pumpPill(int completed) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: WorkoutWeekGoalPill(
            goal: WeeklyTrainingGoalStatus(
              weekStartLocalDate: '2026-10-05',
              completed: completed,
              goal: 3,
              weeksInARow: 0,
              source: WeeklyTrainingGoalSource.user,
            ),
          ),
        ),
      ),
    );

    await pumpPill(2);
    expect(find.text('2 of 3 workouts this week'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    await pumpPill(3);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  group('story image', () {
    Future<void> pumpCard(WidgetTester tester, WorkoutCompletionRecap r) =>
        tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SingleChildScrollView(child: WorkoutShareCard(recap: r)),
            ),
          ),
        );

    testWidgets('renders a 1080 × 1920 PNG', (tester) async {
      await pumpCard(tester, recap());
      await tester.pumpAndSettle();

      final boundary = find.descendant(
        of: find.byType(WorkoutShareCard),
        matching: find.byType(RepaintBoundary),
      );
      final key =
          tester
                  .widgetList<RepaintBoundary>(boundary)
                  .firstWhere((widget) => widget.key is GlobalKey)
                  .key!
              as GlobalKey;
      final png = await tester.runAsync(() => renderWorkoutStoryPng(key));

      expect(png, isNotNull);
      final header = ByteData.sublistView(png!);
      // PNG IHDR: width and height are big-endian at bytes 16 and 20.
      expect(header.getUint32(16), 1080);
      expect(header.getUint32(20), 1920);
    });

    testWidgets('shows the workout only, in a fixed text size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Center(
              child: FittedBox(
                child: WorkoutStoryCard(recap: recap(), includeWeights: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final texts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(WorkoutStoryCard),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data)
          .toList();
      expect(texts, [
        'IndiFit',
        'Workout complete · Thu 8 Oct',
        'Full Body C',
        '1,440 kg',
        'total lifted',
        '3',
        'sets',
        '24',
        'reps',
        '1:22',
        'duration',
        'Tracked with IndiFit',
      ]);
      expect(
        tester.getSize(find.byType(WorkoutStoryCard)),
        WorkoutStoryCard.size,
      );
    });

    testWidgets('without weights there are no kilograms', (tester) async {
      await pumpCard(tester, recap());
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.textContaining('kg'), findsNothing);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('reps'), findsOneWidget);
    });
  });
}
