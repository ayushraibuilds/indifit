import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_preferences_keys.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/weekly_training_goal_calculator.dart';

/// The weekly training goal: the user's own goal (used when no plan is
/// active), the per-week goal history, and the status derived from saved
/// workouts. Stored in SharedPreferences, so it needs no schema change.
class WeeklyTrainingGoalRepository {
  WeeklyTrainingGoalRepository({
    required Future<List<DateTime>> Function() sessionTimes,
    required Future<SharedPreferences> Function() preferences,
    LocalScheduleDateService? dates,
  }) : _sessionTimes = sessionTimes,
       _preferences = preferences,
       _dates = dates ?? LocalScheduleDateService();

  /// Completion instants of every saved workout session (full or partial).
  final Future<List<DateTime>> Function() _sessionTimes;
  final Future<SharedPreferences> Function() _preferences;
  final LocalScheduleDateService _dates;

  Future<int> userGoal() async {
    final prefs = await _preferences();
    final stored = prefs.getInt(AppPreferenceKeys.trainingWeekGoal);
    return stored == null
        ? WeeklyTrainingGoalCalculator.defaultGoal
        : WeeklyTrainingGoalCalculator.clampUserGoal(stored);
  }

  /// Saves the no-plan goal. The current week picks it up on the next
  /// [status] read; past weeks keep their recorded goal.
  Future<void> setUserGoal(int goal) async {
    final prefs = await _preferences();
    await prefs.setInt(
      AppPreferenceKeys.trainingWeekGoal,
      WeeklyTrainingGoalCalculator.clampUserGoal(goal),
    );
  }

  Future<Map<String, int>> goalHistory() async =>
      _decodeHistory(await _preferences());

  /// This week's status. [planGoal] is the active plan's scheduled sessions
  /// this week; null or zero means no plan, so the user's goal applies.
  ///
  /// Records this week's goal in the history. The week in progress follows
  /// the live goal; finished weeks are never rewritten.
  Future<WeeklyTrainingGoalStatus> status({
    required String timezoneId,
    int? planGoal,
  }) async {
    final prefs = await _preferences();
    final today = _dates.todayIn(timezoneId);
    final weekStart = WeeklyTrainingGoalCalculator.weekStartOf(
      today,
      dates: _dates,
    );
    final fromPlan = planGoal != null && planGoal > 0;
    final goal = fromPlan ? planGoal : await userGoal();

    final history = _decodeHistory(prefs);
    if (history[weekStart] != goal) {
      history[weekStart] = goal;
      await prefs.setString(
        AppPreferenceKeys.trainingWeekGoals,
        jsonEncode(history),
      );
    }

    final workoutDates = [
      for (final completedAt in await _sessionTimes())
        _dates.localDateFor(completedAt, timezoneId),
    ];
    return WeeklyTrainingGoalCalculator.calculate(
      workoutLocalDates: workoutDates,
      goalHistory: history,
      referenceLocalDate: today,
      currentGoal: goal,
      source: fromPlan
          ? WeeklyTrainingGoalSource.plan
          : WeeklyTrainingGoalSource.user,
      dates: _dates,
    );
  }

  static Map<String, int> _decodeHistory(SharedPreferences prefs) {
    final raw = prefs.getString(AppPreferenceKeys.trainingWeekGoals);
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, int>{};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is int)
            entry.key as String: entry.value as int,
      };
    } on FormatException catch (error) {
      // A damaged history only loses past goals; workouts are untouched.
      AppLogger.warning('Weekly goal history unreadable: $error');
      return <String, int>{};
    }
  }
}
