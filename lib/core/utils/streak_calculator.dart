class StreakCalculator {
  /// Calculates current active day streak supporting streak freeze protection tokens.
  static int calculateStreak(Set<String> activeDays, {int streakFreezeCount = 0}) {
    if (activeDays.isEmpty) return 0;

    final now = DateTime.now();
    int streak = 0;
    int freezesRemaining = streakFreezeCount;

    DateTime checkDate = DateTime(now.year, now.month, now.day);
    String dateStr = _formatDate(checkDate);

    // If today is not active, step back to yesterday
    if (!activeDays.contains(dateStr)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
      dateStr = _formatDate(checkDate);
    }

    while (activeDays.contains(dateStr) || freezesRemaining > 0) {
      if (activeDays.contains(dateStr)) {
        streak++;
      } else if (freezesRemaining > 0) {
        // Streak freeze protects 1 missed day
        freezesRemaining--;
        streak++;
      }
      checkDate = checkDate.subtract(const Duration(days: 1));
      dateStr = _formatDate(checkDate);
    }

    return streak;
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
