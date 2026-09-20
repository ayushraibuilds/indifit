import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/utils/streak_calculator.dart';

void main() {
  group('StreakCalculator', () {
    test('returns 0 for empty active days', () {
      final streak = StreakCalculator.calculateStreak({});
      expect(streak, 0);
    });

    test('calculates consecutive streak when reference date is active', () {
      final activeDays = {
        '2026-09-14',
        '2026-09-15',
        '2026-09-16',
      };
      final streak = StreakCalculator.calculateStreak(
        activeDays,
        referenceLocalDate: '2026-09-16',
      );
      expect(streak, 3);
    });

    test('steps back to yesterday if reference date is inactive', () {
      final activeDays = {
        '2026-09-14',
        '2026-09-15',
      };
      // Reference date is 2026-09-16 (not yet logged today)
      final streak = StreakCalculator.calculateStreak(
        activeDays,
        referenceLocalDate: '2026-09-16',
      );
      expect(streak, 2);
    });

    test('protects missed days with streak freezes', () {
      final activeDays = {
        '2026-09-12',
        // 2026-09-13 missed (freeze used)
        '2026-09-14',
        '2026-09-15',
      };
      final streak = StreakCalculator.calculateStreak(
        activeDays,
        streakFreezeCount: 1,
        referenceLocalDate: '2026-09-15',
      );
      // 15, 14, 13 (freeze), 12 = 4 days
      expect(streak, 4);
    });

    test('stops streak when freeze tokens are exhausted', () {
      final activeDays = {
        '2026-09-10',
        // 2026-09-11 missed
        // 2026-09-12 missed
        '2026-09-13',
      };
      final streak = StreakCalculator.calculateStreak(
        activeDays,
        streakFreezeCount: 1,
        referenceLocalDate: '2026-09-13',
      );
      // 13 is active (1), 12 uses freeze (2), 11 has no freeze -> stops
      expect(streak, 2);
    });

    test('correctly handles DST transition without dropping calendar days', () {
      // America/New_York falls back on 2026-11-01 (25-hour day)
      // A Duration(days: 1) subtraction can cause hour misalignment.
      // Civil calendar day subtraction must step exactly 2026-11-02 -> 2026-11-01 -> 2026-10-31.
      final dates = LocalScheduleDateService();
      const tzId = 'America/New_York';

      final activeDays = {
        '2026-10-30',
        '2026-10-31',
        '2026-11-01',
        '2026-11-02',
      };

      final streak = StreakCalculator.calculateStreak(
        activeDays,
        referenceLocalDate: '2026-11-02',
        dates: dates,
        timezoneId: tzId,
      );

      expect(streak, 4);
    });

    test('uses injected LocalScheduleDateService clock for today', () {
      final deterministicClock = DateTime.utc(2026, 5, 20, 10, 0);
      final dates = LocalScheduleDateService(
        nowUtc: () => deterministicClock,
      );

      final activeDays = {
        '2026-05-18',
        '2026-05-19',
        '2026-05-20',
      };

      final streak = StreakCalculator.calculateStreak(
        activeDays,
        dates: dates,
        timezoneId: 'UTC',
      );

      expect(streak, 3);
    });
  });
}
