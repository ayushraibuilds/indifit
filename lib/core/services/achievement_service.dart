import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/progress_statistics_repository.dart';

class AchievementEvaluationResult {
  final List<Achievement> all;
  final List<Achievement> sessionUnlocked;

  const AchievementEvaluationResult({
    required this.all,
    required this.sessionUnlocked,
  });
}

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
    DateTime Function()? now,
  }) {
    return evaluateAchievements(
      completedWorkoutsCount: stats.totalWorkouts,
      currentStreakDays: currentStreakDays,
      totalVolumeKg: stats.totalVolumeKg,
      totalLoggedMealsCount: stats.totalMealsLogged,
      loggedThali: stats.thaliLoggedCount > 0,
      unlockedTimestamps: stats.unlockedAchievementIds,
      now: now,
    );
  }

  static List<Achievement> evaluateAchievements({
    required int completedWorkoutsCount,
    required int currentStreakDays,
    required double totalVolumeKg,
    required int totalLoggedMealsCount,
    bool loggedThali = false,
    Map<String, DateTime>? unlockedTimestamps,
    DateTime Function()? now,
  }) {
    final timestamps = unlockedTimestamps ?? {};
    final clock = now ?? DateTime.now;

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
          timestamps[id] ?? (thresholdMet ? clock() : null);

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
        '${formatAmount(current)} kg / ${formatAmount(max)} kg volume recorded';

    const bronze = Color(0xFFCD7F32);
    const streakOrange = Color(0xFFFF7A00);
    const gold = Color(0xFFFFD700);
    const silver = Color(0xFFC0C0C0);
    const successGreen = Color(0xFF10B981);
    const fiberTeal = Color(0xFF14B8A6);

    return [
      buildItem(
        id: 'first_workout',
        title: 'First Sweat',
        description: 'Complete your 1st workout session.',
        icon: Icons.fitness_center_rounded,
        color: bronze,
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
        color: streakOrange,
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
        color: gold,
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
        color: bronze,
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
        color: silver,
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
        color: gold,
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
        color: successGreen,
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
        color: fiberTeal,
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
        color: streakOrange,
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
  static String formatAmount(double value) {
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

  static const String prefCelebratedAchievementIds =
      'celebrated_achievement_ids';

  static const Set<String> workoutAchievementIds = {
    'first_workout',
    'streak_7',
    'streak_30',
    'volume_1000',
    'volume_5000',
    'volume_10000',
  };

  static const Set<String> nonWorkoutAchievementIds = {
    'meals_10',
    'meals_50',
    'first_thali',
  };

  /// Evaluates thresholds against current lifetime stats, durably records
  /// newly met unlocks, and returns both all achievements and the session-earned
  /// newly unlocked delta.
  static Future<AchievementEvaluationResult> recordAndEvaluateDelta({
    required ProgressStatisticsRepository statsRepository,
    required int currentStreakDays,
    DateTime Function()? now,
  }) async {
    final stats = await statsRepository.getLifetimeStats();
    final evaluated = evaluateFromLifetimeStats(
      stats: stats,
      currentStreakDays: currentStreakDays,
      now: now,
    );
    final newlyUnlockedIds = <String>[];
    for (final achievement in evaluated) {
      if (achievement.isUnlocked &&
          !stats.unlockedAchievementIds.containsKey(achievement.id)) {
        final inserted =
            await statsRepository.unlockAchievement(achievement.id);
        if (inserted) {
          newlyUnlockedIds.add(achievement.id);
        }
      }
    }
    final stored = await statsRepository.getLifetimeStats();
    final all = evaluateFromLifetimeStats(
      stats: stored,
      currentStreakDays: currentStreakDays,
      now: now,
    );
    final sessionUnlocked = all
        .where((a) => newlyUnlockedIds.contains(a.id))
        .toList();
    return AchievementEvaluationResult(
      all: all,
      sessionUnlocked: sessionUnlocked,
    );
  }

  /// Evaluates thresholds against current lifetime stats and durably records
  /// every newly met unlock, then returns achievements populated with the
  /// STORED unlock timestamps (never freshly minted ones).
  ///
  /// Backward-compatible delegator to [recordAndEvaluateDelta].
  static Future<List<Achievement>> recordAndEvaluate({
    required ProgressStatisticsRepository statsRepository,
    required int currentStreakDays,
    DateTime Function()? now,
  }) async {
    final result = await recordAndEvaluateDelta(
      statsRepository: statsRepository,
      currentStreakDays: currentStreakDays,
      now: now,
    );
    return result.all;
  }

  /// Ensure the celebrated store is baselined on cold start.
  /// Strict absence-only: if the key does not exist, seeds it with all currently
  /// unlocked IDs in SQLite so historic achievements are never re-announced.
  /// If the key exists (even as an empty list), does nothing.
  static Future<void> ensureBaselined(
    SharedPreferences prefs,
    Iterable<String> currentUnlockedIds,
  ) async {
    if (!prefs.containsKey(prefCelebratedAchievementIds)) {
      await prefs.setStringList(
        prefCelebratedAchievementIds,
        currentUnlockedIds.toList(),
      );
    }
  }

  /// Post-restore rebase hook: synchronizes celebrated state to all restored
  /// SQLite achievement unlocks so restored accounts never re-announce historic badges.
  static Future<void> rebaseCelebratedOnRestore(
    AppDatabase db,
    SharedPreferences prefs,
  ) async {
    final unlocks = await db.select(db.achievementUnlocks).get();
    final unlockedIds = unlocks.map((u) => u.achievementId).toList();
    await prefs.setStringList(prefCelebratedAchievementIds, unlockedIds);
  }

  /// Marks a set of achievement IDs as celebrated in preferences.
  static Future<void> markCelebrated(
    SharedPreferences prefs,
    Iterable<String> achievementIds,
  ) async {
    final existing =
        prefs.getStringList(prefCelebratedAchievementIds)?.toSet() ?? {};
    existing.addAll(achievementIds);
    await prefs.setStringList(prefCelebratedAchievementIds, existing.toList());
  }

  /// Returns uncelebrated non-workout achievements (e.g. meals/thali) that
  /// qualify from stored SQLite facts and have not yet been displayed.
  /// Newly qualifying unlocks are durably recorded to SQLite before returning.
  static Future<List<Achievement>> getUncelebratedNonWorkoutUnlocks({
    required ProgressStatisticsRepository statsRepository,
    required SharedPreferences prefs,
    DateTime Function()? now,
  }) async {
    final stats = await statsRepository.getLifetimeStats();
    await ensureBaselined(prefs, stats.unlockedAchievementIds.keys);

    final all = evaluateFromLifetimeStats(
      stats: stats,
      currentStreakDays: 0,
      now: now,
    );

    for (final a in all) {
      if (a.isUnlocked &&
          nonWorkoutAchievementIds.contains(a.id) &&
          !stats.unlockedAchievementIds.containsKey(a.id)) {
        await statsRepository.unlockAchievement(a.id);
      }
    }

    final reloadedStats = await statsRepository.getLifetimeStats();
    final reloadedAll = evaluateFromLifetimeStats(
      stats: reloadedStats,
      currentStreakDays: 0,
      now: now,
    );

    final celebrated =
        prefs.getStringList(prefCelebratedAchievementIds)?.toSet() ?? {};

    return reloadedAll.where((a) {
      return a.isUnlocked &&
          nonWorkoutAchievementIds.contains(a.id) &&
          !celebrated.contains(a.id);
    }).toList();
  }

  /// Returns uncelebrated workout achievements (e.g. volume, first_workout, streaks) that
  /// qualify from stored SQLite facts and have not yet been celebrated.
  /// Newly qualifying unlocks are durably recorded to SQLite before returning.
  static Future<List<Achievement>> getUncelebratedWorkoutUnlocks({
    required ProgressStatisticsRepository statsRepository,
    required SharedPreferences prefs,
    int currentStreakDays = 0,
    DateTime Function()? now,
  }) async {
    final stats = await statsRepository.getLifetimeStats();
    await ensureBaselined(prefs, stats.unlockedAchievementIds.keys);

    final all = evaluateFromLifetimeStats(
      stats: stats,
      currentStreakDays: currentStreakDays,
      now: now,
    );

    for (final a in all) {
      if (a.isUnlocked &&
          workoutAchievementIds.contains(a.id) &&
          !stats.unlockedAchievementIds.containsKey(a.id)) {
        await statsRepository.unlockAchievement(a.id);
      }
    }

    final reloadedStats = await statsRepository.getLifetimeStats();
    final reloadedAll = evaluateFromLifetimeStats(
      stats: reloadedStats,
      currentStreakDays: currentStreakDays,
      now: now,
    );

    final celebrated =
        prefs.getStringList(prefCelebratedAchievementIds)?.toSet() ?? {};

    return reloadedAll.where((a) {
      return a.isUnlocked &&
          workoutAchievementIds.contains(a.id) &&
          !celebrated.contains(a.id);
    }).toList();
  }

  /// Read model: returns unlocked achievements sorted by unlockedAt desc.
  static List<Achievement> getRecentlyUnlocked(List<Achievement> achievements) {
    final unlocked = achievements.where((a) => a.isUnlocked).toList();
    unlocked.sort((a, b) {
      final aDate = a.unlockedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.unlockedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return unlocked;
  }
}
