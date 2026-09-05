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

  /// Factual, human-readable basis for the current state (never inferred).
  final String evidence;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.currentProgress,
    required this.maxProgress,
    required this.isUnlocked,
    required this.evidence,
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
      required String evidence,
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
        evidence: evidence,
        unlockedAt: unlockedAt,
      );
    }

    String countEvidence(int current, int max, String unit) =>
        '$current of $max $unit logged';
    String volumeEvidence(double current, double max) =>
        '${_formatAmount(current)} kg / ${_formatAmount(max)} kg volume recorded';

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
        evidence: countEvidence(completedWorkoutsCount, 1, 'workout'),
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
        evidence: countEvidence(currentStreakDays, 7, 'day streak'),
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
        evidence: countEvidence(currentStreakDays, 30, 'day streak'),
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
        evidence: volumeEvidence(totalVolumeKg, 1000.0),
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
        evidence: volumeEvidence(totalVolumeKg, 5000.0),
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
        evidence: volumeEvidence(totalVolumeKg, 10000.0),
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
        evidence: countEvidence(totalLoggedMealsCount, 10, 'meals'),
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
        evidence: countEvidence(totalLoggedMealsCount, 50, 'meals'),
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
        evidence: loggedThali ? 'Thali plate logged' : 'No thali plate logged yet',
      ),
    ];
  }

  /// Formats a measured amount for evidence strings: whole values get
  /// thousands grouping (`10450` → `10,450`), fractional values keep one
  /// decimal. Presentation only; thresholds always compare exact values.
  static String _formatAmount(double value) {
    final rounded1 = (value * 10).round() / 10;
    final text = rounded1 == rounded1.roundToDouble()
        ? rounded1.round().toString()
        : rounded1.toStringAsFixed(1);
    final parts = text.split('.');
    final grouped = StringBuffer();
    final digits = parts[0].split('').reversed.toList();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 3 == 0) grouped.write(',');
      grouped.write(digits[i]);
    }
    final head = grouped.toString().split('').reversed.join();
    return parts.length > 1 ? '$head.${parts[1]}' : head;
  }

  /// Evaluates thresholds against current lifetime stats and durably records
  /// every newly met unlock, then returns achievements populated with the
  /// STORED unlock timestamps (never freshly minted ones).
  ///
  /// Safe to call from workout finalization: recording is idempotent and
  /// this method never throws for missing data (empty stats simply leave
  /// everything locked). Partial and full completions are treated identically
  /// — a persisted session is a completed session.
  static Future<List<Achievement>> recordAndEvaluate({
    required ProgressStatisticsRepository statsRepository,
    required int currentStreakDays,
  }) async {
    final stats = await statsRepository.getLifetimeStats();
    final evaluated = evaluateFromLifetimeStats(
      stats: stats,
      currentStreakDays: currentStreakDays,
    );
    for (final achievement in evaluated) {
      if (achievement.isUnlocked &&
          !stats.unlockedAchievementIds.containsKey(achievement.id)) {
        await statsRepository.unlockAchievement(achievement.id);
      }
    }
    final stored = await statsRepository.getLifetimeStats();
    return evaluateFromLifetimeStats(
      stats: stored,
      currentStreakDays: currentStreakDays,
    );
  }
}
