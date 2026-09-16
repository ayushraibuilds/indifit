import '../services/local_schedule_date_service.dart';

class StreakCalculator {
  /// Calculates current active day streak supporting streak freeze protection tokens.
  /// Uses civil calendar dates to avoid DST duration drift.
  static int calculateStreak(
    Set<String> activeDays, {
    int streakFreezeCount = 0,
    String? referenceLocalDate,
    LocalScheduleDateService? dates,
    String timezoneId = 'UTC',
  }) {
    if (activeDays.isEmpty) return 0;

    final dateService = dates ?? LocalScheduleDateService();
    final todayStr = referenceLocalDate ?? dateService.todayIn(timezoneId);

    int streak = 0;
    int freezesRemaining = streakFreezeCount;

    String dateStr = todayStr;

    // If reference day is not active, step back to yesterday
    if (!activeDays.contains(dateStr)) {
      dateStr = dateService.addCalendarDays(dateStr, timezoneId, -1);
    }

    while (activeDays.contains(dateStr) || freezesRemaining > 0) {
      if (activeDays.contains(dateStr)) {
        streak++;
      } else if (freezesRemaining > 0) {
        // Streak freeze protects 1 missed day
        freezesRemaining--;
        streak++;
      }
      dateStr = dateService.addCalendarDays(dateStr, timezoneId, -1);
    }

    return streak;
  }
}
