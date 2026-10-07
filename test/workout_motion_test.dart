import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/utils/weekly_training_goal_calculator.dart';
import 'package:indifit/core/widgets/b05_accessibility_primitives.dart';
import 'package:indifit/features/training/training_week_goal_widgets.dart';
import 'package:indifit/features/workout_player/widgets/b02_compact_set_table.dart';

/// TP-7 motion: every animation takes its duration from B05MotionPolicy, so
/// reduce motion renders the final state on the first frame.
void main() {
  Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );

  double opacityOf(WidgetTester tester) => tester
      .widget<Opacity>(
        find.descendant(
          of: find.byType(B02LoggedSetTick),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;

  testWidgets('a logged set row fills in over the fast duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const B02LoggedSetTick(child: Text('60 kg × 8'))),
    );

    expect(opacityOf(tester), 0);
    expect(tester.hasRunningAnimations, isTrue);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.pump(B05MotionPolicy.fastDuration);
    expect(opacityOf(tester), 1);
  });

  testWidgets('with reduce motion the tick is there on the first frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const B02LoggedSetTick(child: Text('60 kg × 8')),
        reduceMotion: true,
      ),
    );

    expect(opacityOf(tester), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  group('week ring', () {
    WeeklyTrainingGoalStatus status(int completed) => WeeklyTrainingGoalStatus(
      weekStartLocalDate: '2026-10-05',
      completed: completed,
      goal: 4,
      weeksInARow: 0,
      source: WeeklyTrainingGoalSource.user,
      trainedLocalDates: const {},
    );

    double ringValue(WidgetTester tester) => tester
        .widget<CircularProgressIndicator>(
          find.byKey(const ValueKey('training_week_goal_ring')),
        )
        .value!;

    testWidgets('shows the value at once, then animates old to new', (
      tester,
    ) async {
      await tester.pumpWidget(host(TrainingWeekGoalSummary(status: status(1))));
      expect(ringValue(tester), 0.25);

      await tester.pumpWidget(host(TrainingWeekGoalSummary(status: status(2))));
      await tester.pump(B05MotionPolicy.standardDuration ~/ 2);
      expect(ringValue(tester), inExclusiveRange(0.25, 0.5));
      await tester.pump(B05MotionPolicy.standardDuration);
      expect(ringValue(tester), 0.5);
    });

    testWidgets('with reduce motion it jumps to the new value', (tester) async {
      await tester.pumpWidget(
        host(TrainingWeekGoalSummary(status: status(1)), reduceMotion: true),
      );
      await tester.pumpWidget(
        host(TrainingWeekGoalSummary(status: status(2)), reduceMotion: true),
      );

      expect(ringValue(tester), 0.5);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
