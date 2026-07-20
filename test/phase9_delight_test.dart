import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/utils/streak_calculator.dart';
import 'package:indifit/core/widgets/confetti_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 9 Delight & Polish Unit and Widget Tests', () {
    test('StreakCalculator calculates active streak without freeze', () {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      final activeDays = {todayStr, yesterdayStr};
      final streak = StreakCalculator.calculateStreak(activeDays);

      expect(streak, 2);
    });

    test('StreakCalculator protects 1 missed day using streak freeze token', () {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final twoDaysAgo = now.subtract(const Duration(days: 2));
      final twoDaysAgoStr = '${twoDaysAgo.year}-${twoDaysAgo.month.toString().padLeft(2, '0')}-${twoDaysAgo.day.toString().padLeft(2, '0')}';

      // yesterday missing, but 1 freeze token available
      final activeDays = {todayStr, twoDaysAgoStr};
      final streak = StreakCalculator.calculateStreak(activeDays, streakFreezeCount: 1);

      expect(streak, 3);
    });

    testWidgets('ConfettiOverlay renders child and responds to isPlaying', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConfettiOverlay(
              isPlaying: true,
              child: Text('PR Celebration!'),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('PR Celebration!'), findsOneWidget);
    });
  });
}
