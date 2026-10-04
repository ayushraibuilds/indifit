import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_preferences_keys.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/streak_calculator.dart';
import 'nutrition_read_model_repository.dart';
import 'workout_repository.dart';

/// The single source of the activity streak: days with food still in effect
/// (legacy logs and canonical snapshots) or a completed workout, plus the
/// user's streak-freeze allowance. Computed on demand, never cached, so every
/// screen sees the same number.
class StreakRepository {
  StreakRepository({
    required Future<NutritionReadModelRepository> Function() nutrition,
    required WorkoutRepository workouts,
    required Future<SharedPreferences> Function() preferences,
    DateTime Function()? now,
  }) : _nutrition = nutrition,
       _workouts = workouts,
       _preferences = preferences,
       _now = now ?? DateTime.now;

  final Future<NutritionReadModelRepository> Function() _nutrition;
  final WorkoutRepository _workouts;
  final Future<SharedPreferences> Function() _preferences;
  final DateTime Function() _now;

  /// Every user starts with one freeze.
  static const defaultFreezes = 1;

  Future<int> freezeCount() async {
    final prefs = await _preferences();
    return prefs.getInt(AppPreferenceKeys.streakFreezesCount) ?? defaultFreezes;
  }

  Future<int> currentStreak() async {
    final activeDays = <String>{};
    try {
      final nutrition = await _nutrition();
      activeDays.addAll(
        await nutrition.activeLocalDates(userId: kLocalNutritionUserScopeId),
      );
    } on Object catch (error, stackTrace) {
      // Count workouts alone rather than failing the whole streak.
      AppLogger.error(
        'Streak: nutrition history unavailable',
        error,
        stackTrace,
      );
    }
    // Drift returns DateTimes in device-local time, so these are civil dates.
    for (final completedAt in await _workouts.getAllSessionDates()) {
      activeDays.add(_civilDate(completedAt));
    }

    return StreakCalculator.calculateStreak(
      activeDays,
      streakFreezeCount: await freezeCount(),
      referenceLocalDate: _civilDate(_now()),
    );
  }

  static String _civilDate(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
