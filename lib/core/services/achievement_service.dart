import 'package:flutter/material.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final double currentProgress;
  final double maxProgress;
  final bool isUnlocked;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.currentProgress,
    required this.maxProgress,
    required this.isUnlocked,
  });

  double get progressPercentage => (currentProgress / maxProgress).clamp(0.0, 1.0);
}

class AchievementService {
  static List<Achievement> evaluateAchievements({
    required int completedWorkoutsCount,
    required int currentStreakDays,
    required double totalVolumeKg,
    required int totalLoggedMealsCount,
    int prCount = 0,
    bool loggedThali = false,
  }) {
    return [
      Achievement(
        id: 'first_workout',
        title: 'First Sweat',
        description: 'Complete your 1st workout session.',
        icon: Icons.fitness_center_rounded,
        color: Colors.orangeAccent,
        currentProgress: completedWorkoutsCount.toDouble(),
        maxProgress: 1.0,
        isUnlocked: completedWorkoutsCount >= 1,
      ),
      Achievement(
        id: 'streak_7',
        title: 'Consistency Master',
        description: 'Maintain a 7-day streak.',
        icon: Icons.local_fire_department_rounded,
        color: Colors.deepOrangeAccent,
        currentProgress: currentStreakDays.toDouble(),
        maxProgress: 7.0,
        isUnlocked: currentStreakDays >= 7,
      ),
      Achievement(
        id: 'streak_30',
        title: 'Iron Discipline',
        description: 'Maintain an impressive 30-day streak.',
        icon: Icons.workspace_premium_rounded,
        color: Colors.purpleAccent,
        currentProgress: currentStreakDays.toDouble(),
        maxProgress: 30.0,
        isUnlocked: currentStreakDays >= 30,
      ),
      Achievement(
        id: 'volume_1000',
        title: 'Iron Lifter',
        description: 'Lift a cumulative total of 1,000 kg volume.',
        icon: Icons.military_tech_rounded,
        color: Colors.amber,
        currentProgress: totalVolumeKg,
        maxProgress: 1000.0,
        isUnlocked: totalVolumeKg >= 1000.0,
      ),
      Achievement(
        id: 'volume_5000',
        title: 'Heavy Mover',
        description: 'Lift a cumulative total of 5,000 kg volume.',
        icon: Icons.shield_rounded,
        color: Colors.lightBlueAccent,
        currentProgress: totalVolumeKg,
        maxProgress: 5000.0,
        isUnlocked: totalVolumeKg >= 5000.0,
      ),
      Achievement(
        id: 'volume_10000',
        title: 'Titan Legend',
        description: 'Lift an impressive 10,000 kg cumulative volume.',
        icon: Icons.stars_rounded,
        color: Colors.amberAccent,
        currentProgress: totalVolumeKg,
        maxProgress: 10000.0,
        isUnlocked: totalVolumeKg >= 10000.0,
      ),
      Achievement(
        id: 'meals_10',
        title: 'Nutrition Tracker',
        description: 'Log 10 meals in your food diary.',
        icon: Icons.restaurant_rounded,
        color: Colors.greenAccent,
        currentProgress: totalLoggedMealsCount.toDouble(),
        maxProgress: 10.0,
        isUnlocked: totalLoggedMealsCount >= 10,
      ),
      Achievement(
        id: 'meals_50',
        title: 'Macro Master',
        description: 'Log 50 meals in your food diary.',
        icon: Icons.lunch_dining_rounded,
        color: Colors.tealAccent,
        currentProgress: totalLoggedMealsCount.toDouble(),
        maxProgress: 50.0,
        isUnlocked: totalLoggedMealsCount >= 50,
      ),
      Achievement(
        id: 'first_pr',
        title: 'PR Breaker',
        description: 'Hit your very first Personal Record (PR).',
        icon: Icons.emoji_events_rounded,
        color: Colors.yellowAccent,
        currentProgress: prCount.toDouble(),
        maxProgress: 1.0,
        isUnlocked: prCount >= 1,
      ),
      Achievement(
        id: 'first_thali',
        title: 'Thali Connoisseur',
        description: 'Compose and log a custom Indian Thali plate.',
        icon: Icons.rice_bowl_rounded,
        color: Colors.orange,
        currentProgress: loggedThali ? 1.0 : 0.0,
        maxProgress: 1.0,
        isUnlocked: loggedThali,
      ),
    ];
  }
}
