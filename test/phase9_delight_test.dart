import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/utils/streak_calculator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 9 Delight & Polish Unit and Widget Tests', () {
    test('StreakCalculator counts today after local midnight in IST', () {
      // 01:27 IST on 2 Oct is still 1 Oct in UTC. With only the UTC default,
      // today's log was ignored and the streak dropped by one.
      final dates = LocalScheduleDateService(
        nowUtc: () => DateTime.utc(2026, 10, 1, 19, 57),
      );
      final activeDays = {'2026-10-01', '2026-10-02'};

      expect(
        StreakCalculator.calculateStreak(
          activeDays,
          dates: dates,
          referenceLocalDate: '2026-10-02',
        ),
        2,
      );
      expect(StreakCalculator.calculateStreak(activeDays, dates: dates), 1);
    });

    test('StreakCalculator calculates active streak without freeze', () {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      final activeDays = {todayStr, yesterdayStr};
      final streak = StreakCalculator.calculateStreak(
        activeDays,
        referenceLocalDate: todayStr,
      );

      expect(streak, 2);
    });

    test('StreakCalculator protects 1 missed day using streak freeze token', () {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final twoDaysAgo = now.subtract(const Duration(days: 2));
      final twoDaysAgoStr =
          '${twoDaysAgo.year}-${twoDaysAgo.month.toString().padLeft(2, '0')}-${twoDaysAgo.day.toString().padLeft(2, '0')}';

      // yesterday missing, but 1 freeze token available
      final activeDays = {todayStr, twoDaysAgoStr};
      final streak = StreakCalculator.calculateStreak(
        activeDays,
        streakFreezeCount: 1,
        referenceLocalDate: todayStr,
      );

      expect(streak, 3);
    });
  });
}
