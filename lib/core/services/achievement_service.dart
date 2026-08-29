import 'package:flutter/material.dart';
import '../../data/repositories/progress_statistics_repository.dart';
import '../theme/colors.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final double currentProgress;
  final double maxProgress;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.currentProgress,
    required this.maxProgress,
    required this.isUnlocked,
    this.unlockedAt,
  });

  double get progressPercentage =>
      (currentProgress / maxProgress).clamp(0.0, 1.0);
}

class AchievementService {
  static List<Achievement> evaluateFromLifetimeStats({
    required LifetimeAchievementStats stats,
    required int currentStreakDays,
  }) {
    return evaluateAchievements(
      completedWorkoutsCount: stats.totalWorkouts,
      currentStreakDays: currentStreakDays,
      totalVolumeKg: stats.totalVolumeKg,
      totalLoggedMealsCount: stats.totalMealsLogged,
      loggedThali: stats.thaliLoggedCount > 0,
      unlockedTimestamps: stats.unlockedAchievementIds,
    );
  }

  static List<Achievement> evaluateAchievements({
    required int completedWorkoutsCount,
    required int currentStreakDays,
    required double totalVolumeKg,
    required int totalLoggedMealsCount,
    bool loggedThali = false,
    Map<String, DateTime>? unlockedTimestamps,
  }) {
    final timestamps = unlockedTimestamps ?? {};

    Achievement buildItem({
      required String id,
      required String title,
      required String description,
      required IconData icon,
      required Color color,
      required double currentProgress,
      required double maxProgress,
      required bool thresholdMet,
    }) {
      final isUnlocked = thresholdMet || timestamps.containsKey(id);
      final unlockedAt =
          timestamps[id] ?? (thresholdMet ? DateTime.now() : null);

      return Achievement(
        id: id,
        title: title,
        description: description,
        icon: icon,
        color: color,
        currentProgress: currentProgress,
        maxProgress: maxProgress,
        isUnlocked: isUnlocked,
        unlockedAt: unlockedAt,
      );
    }

    return [
      buildItem(
        id: 'first_workout',
        title: 'First Sweat',
        description: 'Complete your 1st workout session.',
        icon: Icons.fitness_center_rounded,
        color: AppColors.achievementBronze,
        currentProgress: completedWorkoutsCount.toDouble(),
        maxProgress: 1.0,
        thresholdMet: completedWorkoutsCount >= 1,
      ),
      buildItem(
        id: 'streak_7',
        title: 'Consistency Master',
        description: 'Maintain a 7-day streak.',
        icon: Icons.local_fire_department_rounded,
        color: AppColors.streakOrange,
        currentProgress: currentStreakDays.toDouble(),
        maxProgress: 7.0,
        thresholdMet: currentStreakDays >= 7,
      ),
      buildItem(
        id: 'streak_30',
        title: 'Iron Discipline',
        description: 'Maintain an impressive 30-day streak.',
        icon: Icons.workspace_premium_rounded,
        color: AppColors.achievementGold,
        currentProgress: currentStreakDays.toDouble(),
        maxProgress: 30.0,
        thresholdMet: currentStreakDays >= 30,
      ),
      buildItem(
        id: 'volume_1000',
        title: 'Iron Lifter',
        description: 'Lift a cumulative total of 1,000 kg volume.',
        icon: Icons.military_tech_rounded,
        color: AppColors.achievementBronze,
        currentProgress: totalVolumeKg,
        maxProgress: 1000.0,
        thresholdMet: totalVolumeKg >= 1000.0,
      ),
      buildItem(
        id: 'volume_5000',
        title: 'Heavy Mover',
        description: 'Lift a cumulative total of 5,000 kg volume.',
        icon: Icons.shield_rounded,
        color: AppColors.achievementSilver,
        currentProgress: totalVolumeKg,
        maxProgress: 5000.0,
        thresholdMet: totalVolumeKg >= 5000.0,
      ),
      buildItem(
        id: 'volume_10000',
        title: 'Titan Legend',
        description: 'Lift an impressive 10,000 kg cumulative volume.',
        icon: Icons.stars_rounded,
        color: AppColors.achievementGold,
        currentProgress: totalVolumeKg,
        maxProgress: 10000.0,
        thresholdMet: totalVolumeKg >= 10000.0,
      ),
      buildItem(
        id: 'meals_10',
        title: 'Nutrition Tracker',
        description: 'Log 10 meals in your food diary.',
        icon: Icons.restaurant_rounded,
        color: AppColors.success,
        currentProgress: totalLoggedMealsCount.toDouble(),
        maxProgress: 10.0,
        thresholdMet: totalLoggedMealsCount >= 10,
      ),
      buildItem(
        id: 'meals_50',
        title: 'Macro Master',
        description: 'Log 50 meals in your food diary.',
        icon: Icons.lunch_dining_rounded,
        color: AppColors.fiberTeal,
        currentProgress: totalLoggedMealsCount.toDouble(),
        maxProgress: 50.0,
        thresholdMet: totalLoggedMealsCount >= 50,
      ),
      buildItem(
        id: 'first_thali',
        title: 'Thali Connoisseur',
        description: 'Compose and log a custom Indian Thali plate.',
        icon: Icons.rice_bowl_rounded,
        color: AppColors.streakOrange,
        currentProgress: loggedThali ? 1.0 : 0.0,
        maxProgress: 1.0,
        thresholdMet: loggedThali,
      ),
    ];
  }
}
