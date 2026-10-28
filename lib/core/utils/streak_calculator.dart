import '../services/local_schedule_date_service.dart';

class StreakCalculator {
  /// Counts the current run of active days, ending today (or yesterday, when
  /// today has no activity yet). Uses civil calendar dates to avoid DST drift.
  ///
  /// A streak freeze covers one missed day, but only to bridge a gap that has
  /// active days on both sides: unused freezes never add days, and a gap
  /// longer than the freezes left ends the run. Bridged days count toward the
  /// streak. Freezes are an allowance re-applied on every calculation, not
  /// consumed.
  ///
  /// [excusedDays] (vrat / festival days, UF-9) are skipped: they neither
  /// break the run nor add to it, and need no freeze. An excused day that
  /// was also active counts as active. A run of excused days with no active
  /// day before it is still no streak.
  static int calculateStreak(
    Set<String> activeDays, {
    Set<String> excusedDays = const {},
    int streakFreezeCount = 0,
    String? referenceLocalDate,
    LocalScheduleDateService? dates,
    String timezoneId = 'UTC',
  }) {
    if (activeDays.isEmpty) return 0;

    final dateService = dates ?? LocalScheduleDateService();
    String previous(String day) =>
        dateService.addCalendarDays(day, timezoneId, -1);

    final today = referenceLocalDate ?? dateService.todayIn(timezoneId);
    var cursor = activeDays.contains(today) ? today : previous(today);
    var freezesLeft = streakFreezeCount;
    var streak = 0;
    bool excused(String day) =>
        excusedDays.contains(day) && !activeDays.contains(day);

    while (true) {
      if (activeDays.contains(cursor)) {
        streak++;
        cursor = previous(cursor);
        continue;
      }
      if (excused(cursor)) {
        cursor = previous(cursor);
        continue;
      }
      // Measure the gap (missed days only; excused days inside it are
      // skipped); give up as soon as it is longer than the freezes left.
      var gap = 0;
      var probe = cursor;
      while (!activeDays.contains(probe) && gap <= freezesLeft) {
        if (!excused(probe)) gap++;
        probe = previous(probe);
      }
      if (gap > freezesLeft) break;
      freezesLeft -= gap;
      streak += gap;
      cursor = probe;
    }

    return streak;
  }
}
