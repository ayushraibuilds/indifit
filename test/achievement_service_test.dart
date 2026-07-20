import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/achievement_service.dart';

void main() {
  group('AchievementService Tests', () {
    test('evaluates achievements correctly when criteria are met', () {
      final achievements = AchievementService.evaluateAchievements(
        completedWorkoutsCount: 1,
        currentStreakDays: 7,
        totalVolumeKg: 1200.0,
        totalLoggedMealsCount: 15,
      );

      expect(achievements.every((a) => a.isUnlocked), isTrue);
    });

    test('evaluates locked state when criteria are not met', () {
      final achievements = AchievementService.evaluateAchievements(
        completedWorkoutsCount: 0,
        currentStreakDays: 2,
        totalVolumeKg: 500.0,
        totalLoggedMealsCount: 3,
      );

      final unlockedCount = achievements.where((a) => a.isUnlocked).length;
      expect(unlockedCount, equals(0));
    });
  });
}
