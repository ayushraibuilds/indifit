import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/utils/weekly_training_goal_calculator.dart';

void main() {
  group('WeeklyTrainingGoalCalculator week boundaries', () {
    test('weeks start on Monday', () {
      expect(
        WeeklyTrainingGoalCalculator.weekStartOf('2026-10-05'),
        '2026-10-05',
      );
      expect(
        WeeklyTrainingGoalCalculator.weekStartOf('2026-10-07'),
        '2026-10-05',
      );
      expect(
        WeeklyTrainingGoalCalculator.weekStartOf('2026-10-11'),
        '2026-10-05',
      );
      expect(
        WeeklyTrainingGoalCalculator.weekStartOf('2026-10-12'),
        '2026-10-12',
      );
    });

    test('weeks cross month and year ends on civil dates', () {
      expect(
        WeeklyTrainingGoalCalculator.weekStartOf('2026-10-01'),
        '2026-09-28',
      );
      expect(
        WeeklyTrainingGoalCalculator.weekStartOf('2027-01-01'),
        '2026-12-28',
      );
    });

    test('a DST weekend keeps Sunday and Monday in their own weeks', () {
      // Europe and the UK change clocks on Sunday 29 March 2026.
      final status = WeeklyTrainingGoalCalculator.calculate(
        workoutLocalDates: const ['2026-03-29', '2026-03-30'],
        goalHistory: const {},
        referenceLocalDate: '2026-03-30',
        currentGoal: 1,
      );
      expect(status.weekStartLocalDate, '2026-03-30');
      expect(status.completed, 1);
      expect(status.trainedLocalDates, {'2026-03-30'});
      // Last week (Sunday's workout) met a goal of 1, and so does this one.
      expect(status.weeksInARow, 2);
    });
  });

  group('WeeklyTrainingGoalCalculator goal-met counting', () {
    test('counts only this week, and two workouts on one day count as 2', () {
      final status = WeeklyTrainingGoalCalculator.calculate(
        workoutLocalDates: const [
          '2026-10-04', // last week's Sunday
          '2026-10-05',
          '2026-10-06',
          '2026-10-06',
        ],
        goalHistory: const {},
        referenceLocalDate: '2026-10-07',
        currentGoal: 3,
      );
      expect(status.completed, 3);
      expect(status.goal, 3);
      expect(status.isMet, isTrue);
      expect(status.trainedLocalDates, {'2026-10-05', '2026-10-06'});
    });

    test('below the goal is not met', () {
      final status = WeeklyTrainingGoalCalculator.calculate(
        workoutLocalDates: const ['2026-10-05', '2026-10-06'],
        goalHistory: const {},
        referenceLocalDate: '2026-10-07',
        currentGoal: 3,
      );
      expect(status.completed, 2);
      expect(status.isMet, isFalse);
      expect(
        WeeklyTrainingGoalCopy.thisWeek(status),
        '2 of 3 workouts this week',
      );
    });

    test('future-dated workouts never count', () {
      final status = WeeklyTrainingGoalCalculator.calculate(
        workoutLocalDates: const ['2026-10-12'],
        goalHistory: const {},
        referenceLocalDate: '2026-10-07',
        currentGoal: 1,
      );
      expect(status.completed, 0);
      expect(status.weeksInARow, 0);
    });
  });

  group('WeeklyTrainingGoalCalculator weekly streak', () {
    const lastThreeWeeksMet = [
      '2026-09-14', '2026-09-16', // week of 14 Sep
      '2026-09-21', '2026-09-23', // week of 21 Sep
      '2026-09-28', '2026-09-30', // week of 28 Sep
    ];

    test('continues across finished weeks that met their goal', () {
      final status = WeeklyTrainingGoalCalculator.calculate(
        workoutLocalDates: lastThreeWeeksMet,
        goalHistory: const {},
        referenceLocalDate: '2026-10-07',
        currentGoal: 2,
      );
      expect(status.completed, 0);
      expect(status.weeksInARow, 3);
    });

    test('the week in progress adds once met', () {
      final status = WeeklyTrainingGoalCalculator.calculate(
        workoutLocalDates: [...lastThreeWeeksMet, '2026-10-05', '2026-10-06'],
        goalHistory: const {},
        referenceLocalDate: '2026-10-07',
        currentGoal: 2,
      );
      expect(status.weeksInARow, 4);
      expect(WeeklyTrainingGoalCopy.weeksInARow(status), '4 weeks in a row');
    });

    test('the week in progress never breaks the streak', () {
      final status = WeeklyTrainingGoalCalculator.calculate(
        workoutLocalDates: [...lastThreeWeeksMet, '2026-10-05'],
        goalHistory: const {},
        referenceLocalDate: '2026-10-11', // Sunday, one short of the goal
        currentGoal: 2,
      );
      expect(status.isMet, isFalse);
      expect(status.weeksInARow, 3);
    });

    test('a missed week ends it', () {
      final status = WeeklyTrainingGoalCalculator.calculate(
        workoutLocalDates: const [
          '2026-09-14', '2026-09-16', // met
          '2026-09-21', // missed: 1 of 2
          '2026-09-28', '2026-09-30', // met
        ],
        goalHistory: const {},
        referenceLocalDate: '2026-10-07',
        currentGoal: 2,
      );
      expect(status.weeksInARow, 1);
    });

    test('an empty last week means no run, and the copy hides at zero', () {
      final status = WeeklyTrainingGoalCalculator.calculate(
        workoutLocalDates: const ['2026-09-21', '2026-09-23'],
        goalHistory: const {},
        referenceLocalDate: '2026-10-07',
        currentGoal: 2,
      );
      expect(status.weeksInARow, 0);
      expect(WeeklyTrainingGoalCopy.weeksInARow(status), isNull);
    });
  });

  group('WeeklyTrainingGoalCalculator goal history', () {
    test('a goal change mid-week does not rewrite past weeks', () {
      // Two weeks at a goal of 2, then the user raises it to 4 this week.
      final status = WeeklyTrainingGoalCalculator.calculate(
        workoutLocalDates: const [
          '2026-09-21',
          '2026-09-23',
          '2026-09-28',
          '2026-09-30',
          '2026-10-05',
        ],
        goalHistory: const {'2026-09-21': 2, '2026-09-28': 2, '2026-10-05': 4},
        referenceLocalDate: '2026-10-07',
        currentGoal: 4,
      );
      expect(status.goal, 4);
      expect(status.completed, 1);
      // Judged by today's goal of 4, both past weeks would have failed.
      expect(status.weeksInARow, 2);
    });

    test('a higher past goal is still judged by its own number', () {
      final status = WeeklyTrainingGoalCalculator.calculate(
        workoutLocalDates: const ['2026-09-28', '2026-09-30'],
        goalHistory: const {'2026-09-28': 3, '2026-10-05': 2},
        referenceLocalDate: '2026-10-07',
        currentGoal: 2,
      );
      expect(status.weeksInARow, 0);
    });

    test('weeks before the first entry use the first entry\'s goal', () {
      expect(
        WeeklyTrainingGoalCalculator.goalForWeek('2026-09-14', const {
          '2026-09-28': 4,
          '2026-10-05': 2,
        }, fallback: 3),
        4,
      );
    });

    test('a week with no entry carries the latest earlier goal forward', () {
      expect(
        WeeklyTrainingGoalCalculator.goalForWeek('2026-09-21', const {
          '2026-09-14': 2,
          '2026-10-05': 5,
        }, fallback: 3),
        2,
      );
      expect(
        WeeklyTrainingGoalCalculator.goalForWeek(
          '2026-10-05',
          const {},
          fallback: 3,
        ),
        3,
      );
    });

    test('user goals clamp to 1–7', () {
      expect(WeeklyTrainingGoalCalculator.clampUserGoal(0), 1);
      expect(WeeklyTrainingGoalCalculator.clampUserGoal(9), 7);
      expect(WeeklyTrainingGoalCalculator.clampUserGoal(4), 4);
    });
  });

  group('WeeklyTrainingGoalCopy', () {
    WeeklyTrainingGoalStatus status(int completed, int goal) =>
        WeeklyTrainingGoalStatus(
          weekStartLocalDate: '2026-10-05',
          completed: completed,
          goal: goal,
          weeksInARow: 1,
          source: WeeklyTrainingGoalSource.user,
        );

    test('the summary says "Week goal done" only when this workout met it', () {
      expect(
        WeeklyTrainingGoalCopy.summary(status(2, 3)),
        '2 of 3 workouts this week',
      );
      expect(
        WeeklyTrainingGoalCopy.summary(status(3, 3)),
        'Week goal done · 3 of 3 workouts this week',
      );
      expect(
        WeeklyTrainingGoalCopy.summary(status(4, 3)),
        '4 of 3 workouts this week',
      );
      expect(
        WeeklyTrainingGoalCopy.weeksInARow(status(3, 3)),
        '1 week in a row',
      );
    });
  });
}
