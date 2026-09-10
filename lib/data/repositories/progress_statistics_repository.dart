import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../core/nutrition_consumption_snapshots.dart'
    show NutritionConsumptionLineage;
import '../database/app_database.dart';
import 'legacy_program_compatibility_adapter.dart';

final progressStatisticsRepositoryProvider =
    Provider<ProgressStatisticsRepository>((ref) {
      final db = ref.watch(databaseProvider);
      return ProgressStatisticsRepository(db);
    });

class DailyNutritionMetrics {
  final DateTime date;
  final int caloriesLogged;
  final int calorieGoal;
  final double proteinG;
  final double proteinGoal;
  final double carbsG;
  final double carbsGoal;
  final double fatG;
  final double fatGoal;

  const DailyNutritionMetrics({
    required this.date,
    required this.caloriesLogged,
    required this.calorieGoal,
    required this.proteinG,
    required this.proteinGoal,
    required this.carbsG,
    required this.carbsGoal,
    required this.fatG,
    required this.fatGoal,
  });
}

class AdherenceBreakdown {
  final double? calorieScore;
  final double? proteinScore;
  final double? workoutScore;
  final double? hydrationScore;
  final double overallScore;

  const AdherenceBreakdown({
    this.calorieScore,
    this.proteinScore,
    this.workoutScore,
    this.hydrationScore,
    required this.overallScore,
  });
}

class WeeklyMetrics {
  final DateTime startDate;
  final DateTime endDate;
  final int totalCaloriesLogged;
  final int totalCaloriesGoal;
  final double calorieAdherenceScore;
  final double totalProteinG;
  final double totalProteinGoal;
  final double proteinAdherenceScore;
  final int nutritionDaysLogged;
  final int hydrationDaysAtGoal;
  final int totalHydrationMl;
  final int totalHydrationGoalMl;
  final int completedWorkoutsCount;
  final int plannedWorkoutsCount;
  final double workoutCompletionScore;
  final double totalVolumeKg;
  final int prsCount;
  final double overallAdherenceScore;
  final AdherenceBreakdown adherenceBreakdown;

  const WeeklyMetrics({
    required this.startDate,
    required this.endDate,
    required this.totalCaloriesLogged,
    required this.totalCaloriesGoal,
    required this.calorieAdherenceScore,
    required this.totalProteinG,
    required this.totalProteinGoal,
    required this.proteinAdherenceScore,
    required this.nutritionDaysLogged,
    required this.hydrationDaysAtGoal,
    required this.totalHydrationMl,
    required this.totalHydrationGoalMl,
    required this.completedWorkoutsCount,
    required this.plannedWorkoutsCount,
    required this.workoutCompletionScore,
    required this.totalVolumeKg,
    required this.prsCount,
    required this.overallAdherenceScore,
    required this.adherenceBreakdown,
  });
}

class LifetimeAchievementStats {
  final int totalWorkouts;
  final double totalVolumeKg;
  final int totalMealsLogged;
  final int totalPrs;
  final int thaliLoggedCount;
  final Map<String, DateTime> unlockedAchievementIds;

  const LifetimeAchievementStats({
    required this.totalWorkouts,
    required this.totalVolumeKg,
    required this.totalMealsLogged,
    required this.totalPrs,
    required this.thaliLoggedCount,
    required this.unlockedAchievementIds,
  });
}

class ProgressStatisticsRepository {
  /// Canonical consumption snapshot source types that represent genuine,
  /// user-consumed meals for achievement statistics.
  ///
  /// - `direct_food`: Individual or batch foods logged directly by the user.
  /// - `thali`: Composed Indian multi-item meals logged via Thali Builder.
  /// - `recipe`: Scaled or logged recipe portions.
  ///
  /// Non-consumption records (e.g. `estimate` AI suggestions, recommendation
  /// events, goal updates) are strictly excluded so they do not artificially
  /// advance meal-count achievement milestones.
  static const Set<String> _kMealWorthySourceTypes = {
    'direct_food',
    'thali',
    'recipe',
  };

  final AppDatabase _db;
  final DateTime Function() _getNow;

  ProgressStatisticsRepository(this._db, {DateTime Function()? clock})
    : _getNow = clock ?? DateTime.now;

  /// Returns 7-day metrics ending on [referenceDate] (inclusive).
  Future<WeeklyMetrics> getWeeklyMetrics({DateTime? referenceDate}) async {
    final now = referenceDate ?? _getNow();
    final todayStart = DateTime(now.year, now.month, now.day);
    final startDate = todayStart.subtract(const Duration(days: 6));
    final endDate = todayStart.add(
      const Duration(hours: 23, minutes: 59, seconds: 59, milliseconds: 999),
    );

    // Profile target goals
    final profiles = await _db.select(_db.userProfiles).get();
    final profile = profiles.isNotEmpty ? profiles.first : null;
    final dailyCalorieGoal = profile?.calorieGoal ?? 2000;
    final dailyProteinGoal = profile?.proteinGoal ?? 140.0;

    // 1. Food logs in window
    final allFoodLogs = await _db.select(_db.foodLogs).get();
    final windowFoodLogs = allFoodLogs.where((log) {
      return log.loggedAt.isAfter(
            startDate.subtract(const Duration(milliseconds: 1)),
          ) &&
          log.loggedAt.isBefore(endDate);
    }).toList();

    int totalCaloriesLogged = 0;
    double totalProteinG = 0.0;
    final loggedDaysSet = <String>{};

    for (final log in windowFoodLogs) {
      totalCaloriesLogged += log.calories;
      totalProteinG += log.proteinG;
      final dayKey =
          "${log.loggedAt.year}-${log.loggedAt.month.toString().padLeft(2, '0')}-${log.loggedAt.day.toString().padLeft(2, '0')}";
      loggedDaysSet.add(dayKey);
    }

    final nutritionDaysLogged = loggedDaysSet.length;
    final totalCaloriesGoal = dailyCalorieGoal * 7;
    final totalProteinGoal = dailyProteinGoal * 7;

    double? calorieScore;
    double? proteinScore;
    if (nutritionDaysLogged > 0) {
      final calRatio = totalCaloriesLogged / totalCaloriesGoal;
      // Ideal calorie adherence: 1.0 at 100% goal, penalize over/under
      calorieScore = (1.0 - (1.0 - calRatio).abs()).clamp(0.0, 1.0);
      proteinScore = (totalProteinG / totalProteinGoal).clamp(0.0, 1.0);
    }

    // 2. Hydration in window
    final allHydration = await _db.select(_db.dailyHydrations).get();
    final windowHydration = allHydration.where((h) {
      final parsed = DateTime.tryParse(h.dateString);
      if (parsed == null) return false;
      final d = DateTime(parsed.year, parsed.month, parsed.day);
      return (d.isAtSameMomentAs(startDate) || d.isAfter(startDate)) &&
          (d.isAtSameMomentAs(todayStart) || d.isBefore(todayStart));
    }).toList();

    int totalHydrationMl = 0;
    int totalHydrationGoalMl = 0;
    int hydrationDaysAtGoal = 0;

    for (final h in windowHydration) {
      totalHydrationMl += h.totalMl;
      totalHydrationGoalMl += h.goalMl;
      if (h.totalMl >= h.goalMl) {
        hydrationDaysAtGoal++;
      }
    }

    double? hydrationScore;
    if (windowHydration.isNotEmpty) {
      hydrationScore = (hydrationDaysAtGoal / 7.0).clamp(0.0, 1.0);
    }

    // 3. Workouts in window
    final allSessions = await _db.select(_db.workoutSessions).get();
    final windowSessions = allSessions.where((s) {
      return s.completedAt.isAfter(
            startDate.subtract(const Duration(milliseconds: 1)),
          ) &&
          s.completedAt.isBefore(endDate);
    }).toList();

    final completedWorkoutsCount = windowSessions.length;
    double totalVolumeKg = 0.0;
    for (final s in windowSessions) {
      totalVolumeKg += s.totalVolume;
    }

    // PR sets in window
    final allSets = await _db.select(_db.workoutSets).get();
    final sessionIds = windowSessions.map((s) => s.id).toSet();
    final prsCount = allSets
        .where((s) => sessionIds.contains(s.sessionId) && s.isPr)
        .length;

    // Legacy adherence preserves its historical greatest-ID fallback only when
    // no B01 version is active. B01 occurrence adherence remains owned by the
    // calendar read model; this statistics repository must not select a second
    // active plan or reinterpret civil schedule dates.
    int plannedWorkoutsCount = 0;
    final activePlan = await LegacyProgramCompatibilityAdapter(
      _db,
    ).resolveActivePlanSelection();
    if (activePlan.type == ActivePlanType.legacyRoutine) {
      final days =
          await (_db.select(_db.routineDays)..where(
                (tbl) => tbl.routineId.equals(activePlan.legacyRoutineId!),
              ))
              .get();
      plannedWorkoutsCount = days.where((d) => !d.isRestDay).length;
    }

    double? workoutScore;
    if (plannedWorkoutsCount > 0) {
      workoutScore = (completedWorkoutsCount / plannedWorkoutsCount).clamp(
        0.0,
        1.0,
      );
    } else if (completedWorkoutsCount > 0) {
      workoutScore = 1.0;
    }

    // Reweight adherence based on active non-null components
    final validScores = <double>[
      ?calorieScore,
      ?proteinScore,
      ?workoutScore,
      ?hydrationScore,
    ];

    final double overallScore = validScores.isNotEmpty
        ? validScores.reduce((a, b) => a + b) / validScores.length
        : 0.0;

    final breakdown = AdherenceBreakdown(
      calorieScore: calorieScore,
      proteinScore: proteinScore,
      workoutScore: workoutScore,
      hydrationScore: hydrationScore,
      overallScore: overallScore,
    );

    return WeeklyMetrics(
      startDate: startDate,
      endDate: todayStart,
      totalCaloriesLogged: totalCaloriesLogged,
      totalCaloriesGoal: totalCaloriesGoal,
      calorieAdherenceScore: calorieScore ?? 0.0,
      totalProteinG: totalProteinG,
      totalProteinGoal: totalProteinGoal,
      proteinAdherenceScore: proteinScore ?? 0.0,
      nutritionDaysLogged: nutritionDaysLogged,
      hydrationDaysAtGoal: hydrationDaysAtGoal,
      totalHydrationMl: totalHydrationMl,
      totalHydrationGoalMl: totalHydrationGoalMl,
      completedWorkoutsCount: completedWorkoutsCount,
      plannedWorkoutsCount: plannedWorkoutsCount,
      workoutCompletionScore: workoutScore ?? 0.0,
      totalVolumeKg: totalVolumeKg,
      prsCount: prsCount,
      overallAdherenceScore: overallScore,
      adherenceBreakdown: breakdown,
    );
  }

  /// Returns lifetime metrics for achievements.
  Future<LifetimeAchievementStats> getLifetimeStats() async {
    final sessions = await _db.select(_db.workoutSessions).get();
    final totalWorkouts = sessions.length;

    double totalVolumeKg = 0.0;
    for (final s in sessions) {
      totalVolumeKg += s.totalVolume;
    }

    final foodLogs = await _db.select(_db.foodLogs).get();
    final snapshots = await _db.select(_db.nutritionConsumptionSnapshots).get();

    // Identify all superseded snapshot IDs (predecessors of corrections or retractions).
    final supersededSnapshotIds = <String>{};
    for (final s in snapshots) {
      final raw = s.lineage;
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final supersedes = decoded['supersedes_snapshot_id'];
          if (supersedes is String && supersedes.trim().isNotEmpty) {
            supersededSnapshotIds.add(supersedes.trim());
          }
        }
      } catch (_) {}
    }

    // Filter active snapshots representing actual user meals:
    // 1. Meal-worthy Source Type: Must be a genuine user consumption event
    //    (`direct_food`, `thali`, `recipe`). Prospective estimates (`estimate`)
    //    and recommendation events are strictly excluded to prevent milestone inflation.
    // 2. Not Superseded: The snapshot must not be replaced by a subsequent edit or retraction.
    // 3. Not a Retraction: The snapshot must not be an append-only retraction marker itself.
    final activeMealSnapshots = <NutritionConsumptionSnapshot>[];
    for (final s in snapshots) {
      final normalizedSource = s.sourceType.trim().toLowerCase();
      if (!_kMealWorthySourceTypes.contains(normalizedSource)) {
        continue;
      }
      if (supersededSnapshotIds.contains(s.id)) {
        continue;
      }

      var isRetraction = false;
      final raw = s.lineage;
      if (raw != null && raw.trim().isNotEmpty) {
        try {
          final lineage = NutritionConsumptionLineage.fromJson(jsonDecode(raw));
          isRetraction = lineage.isRetraction;
        } catch (_) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map) {
              final evidence = decoded['evidence'];
              final marker = (evidence is Map && evidence['request_evidence'] is Map)
                  ? evidence['request_evidence']['retraction']
                  : (evidence is Map ? evidence['retraction'] : null);
              if (marker != null) isRetraction = true;
            }
          } catch (_) {}
        }
      }
      if (isRetraction) {
        continue;
      }

      activeMealSnapshots.add(s);
    }

    final totalMealsLogged = foodLogs.length + activeMealSnapshots.length;

    final sets = await _db.select(_db.workoutSets).get();
    final totalPrs = sets.where((s) => s.isPr).length;

    // Count thali meals (explicit thali marker or grouped meals with 3+ items):
    // - Legacy food logs with 'thali' in name or non-empty mealGroupId
    // - Active canonical meal snapshots with sourceType 'thali' or non-empty mealGroupId
    final legacyThaliCount = foodLogs
        .where(
          (f) =>
              f.name.toLowerCase().contains('thali') ||
              (f.mealGroupId != null && f.mealGroupId!.isNotEmpty),
        )
        .length;
    final canonicalThaliCount = activeMealSnapshots
        .where(
          (s) =>
              s.sourceType.toLowerCase().contains('thali') ||
              (s.mealGroupId != null && s.mealGroupId!.isNotEmpty),
        )
        .length;
    final thaliLoggedCount = legacyThaliCount + canonicalThaliCount;

    final unlocks = await _db.select(_db.achievementUnlocks).get();
    final unlockedMap = <String, DateTime>{
      for (final u in unlocks) u.achievementId: u.unlockedAt,
    };

    return LifetimeAchievementStats(
      totalWorkouts: totalWorkouts,
      totalVolumeKg: totalVolumeKg,
      totalMealsLogged: totalMealsLogged,
      totalPrs: totalPrs,
      thaliLoggedCount: thaliLoggedCount,
      unlockedAchievementIds: unlockedMap,
    );
  }

  /// Record an achievement unlock exactly once per [achievementId].
  ///
  /// Relies purely on the `achievementId` unique constraint: a single plain
  /// insert whose UNIQUE violation maps to `false`. No pre-read, so
  /// concurrent recorders cannot interleave a duplicate. Returns true only
  /// when this call inserted the row.
  Future<bool> unlockAchievement(String achievementId) async {
    try {
      await _db.into(_db.achievementUnlocks).insert(
            AchievementUnlocksCompanion.insert(
              achievementId: achievementId,
              unlockedAt: Value(_getNow()),
            ),
          );
      return true;
    } on SqliteException catch (e) {
      // SQLITE_CONSTRAINT_UNIQUE (2067): already recorded.
      if (e.extendedResultCode == 2067) return false;
      rethrow;
    }
  }
}
