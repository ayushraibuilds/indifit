import '../services/local_schedule_date_service.dart';

/// Where this week's goal comes from: the active plan's scheduled sessions,
/// or the number the user picked when there is no plan.
enum WeeklyTrainingGoalSource { plan, user }

/// One week of training against its goal, plus the run of weeks that met
/// their own goal. Derived on demand from saved workouts; never stored.
class WeeklyTrainingGoalStatus {
  const WeeklyTrainingGoalStatus({
    required this.weekStartLocalDate,
    required this.completed,
    required this.goal,
    required this.weeksInARow,
    required this.source,
    this.trainedLocalDates = const <String>{},
  });

  /// Monday of the current week, as a civil `YYYY-MM-DD` date.
  final String weekStartLocalDate;

  /// Saved workouts this week. Two workouts on one day count as two.
  final int completed;
  final int goal;

  /// Finished weeks in a row that met their goal, ending last week, plus
  /// this week once it is met.
  final int weeksInARow;
  final WeeklyTrainingGoalSource source;

  /// Civil dates this week with at least one saved workout.
  final Set<String> trainedLocalDates;

  bool get isMet => completed >= goal;
}

/// Pure weekly-goal maths. Weeks run Monday to Sunday on civil dates, so DST
/// changes never move a workout into another week.
abstract final class WeeklyTrainingGoalCalculator {
  static const defaultGoal = 3;
  static const minGoal = 1;
  static const maxGoal = 7;

  // Civil-date arithmetic only; the zone never shifts a calendar day.
  static const _civil = 'UTC';

  static int clampUserGoal(int goal) => goal.clamp(minGoal, maxGoal);

  static String weekStartOf(
    String localDate, {
    LocalScheduleDateService? dates,
  }) {
    final service = dates ?? LocalScheduleDateService();
    return service.addCalendarDays(
      localDate,
      _civil,
      DateTime.monday - service.weekday(localDate, _civil),
    );
  }

  /// The goal a week is judged by: its own history entry, else the latest
  /// earlier entry, else (before the first entry) the first entry's goal.
  /// Changing the goal therefore never rewrites a past week.
  static int goalForWeek(
    String weekStartLocalDate,
    Map<String, int> goalHistory, {
    required int fallback,
  }) {
    if (goalHistory.isEmpty) return _atLeastOne(fallback);
    final weeks = goalHistory.keys.toList()..sort();
    String? match;
    for (final week in weeks) {
      if (week.compareTo(weekStartLocalDate) > 0) break;
      match = week;
    }
    return _atLeastOne(goalHistory[match ?? weeks.first]!);
  }

  static WeeklyTrainingGoalStatus calculate({
    required Iterable<String> workoutLocalDates,
    required Map<String, int> goalHistory,
    required String referenceLocalDate,
    required int currentGoal,
    WeeklyTrainingGoalSource source = WeeklyTrainingGoalSource.user,
    LocalScheduleDateService? dates,
  }) {
    final service = dates ?? LocalScheduleDateService();
    final weekStart = weekStartOf(referenceLocalDate, dates: service);
    final weekEnd = service.addCalendarDays(weekStart, _civil, 6);
    final goal = _atLeastOne(currentGoal);

    final perWeek = <String, int>{};
    final trainedThisWeek = <String>{};
    for (final date in workoutLocalDates) {
      // Future-dated rows can't count toward a week that hasn't happened.
      if (service.compare(date, weekEnd) > 0) continue;
      final week = weekStartOf(date, dates: service);
      perWeek[week] = (perWeek[week] ?? 0) + 1;
      if (week == weekStart) trainedThisWeek.add(date);
    }

    final completed = perWeek[weekStart] ?? 0;
    var streak = 0;
    if (perWeek.isNotEmpty) {
      final earliest = (perWeek.keys.toList()..sort()).first;
      var cursor = service.addCalendarDays(weekStart, _civil, -7);
      // Every goal is at least one, so an empty week always ends the run.
      while (service.compare(cursor, earliest) >= 0) {
        final weekGoal = goalForWeek(cursor, goalHistory, fallback: goal);
        if ((perWeek[cursor] ?? 0) < weekGoal) break;
        streak++;
        cursor = service.addCalendarDays(cursor, _civil, -7);
      }
    }
    // The week in progress adds once met and never breaks the run.
    if (completed >= goal) streak++;

    return WeeklyTrainingGoalStatus(
      weekStartLocalDate: weekStart,
      completed: completed,
      goal: goal,
      weeksInARow: streak,
      source: source,
      trainedLocalDates: Set.unmodifiable(trainedThisWeek),
    );
  }

  static int _atLeastOne(int goal) => goal < minGoal ? minGoal : goal;
}

/// Plain copy for the weekly goal, shared by Training, Progress and the
/// workout summary (plan § 10: "2 of 3 workouts this week").
abstract final class WeeklyTrainingGoalCopy {
  static String progress(WeeklyTrainingGoalStatus status) =>
      '${status.completed} of ${status.goal}';

  static String thisWeek(WeeklyTrainingGoalStatus status) =>
      '${progress(status)} workouts this week';

  /// Null at zero: the run line is hidden until there is a run.
  static String? weeksInARow(WeeklyTrainingGoalStatus status) {
    final weeks = status.weeksInARow;
    if (weeks <= 0) return null;
    return '$weeks ${weeks == 1 ? 'week' : 'weeks'} in a row';
  }

  /// The summary line. "Week goal done" only when this workout met it.
  static String summary(WeeklyTrainingGoalStatus status) =>
      status.completed == status.goal
      ? 'Week goal done · ${thisWeek(status)}'
      : thisWeek(status);
}
