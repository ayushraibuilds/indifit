import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/achievement_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/progress_statistics_repository.dart';

import 'support/indifit_test_harness.dart';

Future<void> _seedSession(
  AppDatabase db, {
  required String name,
  required double totalVolumeKg,
}) {
  return db
      .into(db.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          name: name,
          totalVolume: totalVolumeKg,
          durationSeconds: 1800,
          estimatedCalories: 0,
        ),
      )
      .then((_) {});
}

Future<void> _seedMeals(AppDatabase db, int count) async {
  for (var i = 0; i < count; i++) {
    await db.into(db.foodLogs).insert(
          FoodLogsCompanion.insert(
            name: 'Meal $i',
            calories: 400,
            proteinG: 20.0,
            carbsG: 40.0,
            fatG: 10.0,
            servingLogged: 1.0,
            servingUnit: 'bowl',
            mealType: 'lunch',
          ),
        );
  }
}

void main() {
  initializeIndiFitTestHarness();

  group('PV1-PROD-03A: Achievement event identity', () {
    late AppDatabase db;
    late ProgressStatisticsRepository statsRepo;

    setUp(() {
      db = registerTestDatabaseScope().create();
      statsRepo = ProgressStatisticsRepository(db);
    });

    test('Empty history leaves every milestone locked', () async {
      final achievements = await AchievementService.recordAndEvaluate(
        statsRepository: statsRepo,
        currentStreakDays: 0,
      );

      expect(achievements, isNotEmpty);
      expect(achievements.every((a) => !a.isUnlocked), isTrue);
      expect(achievements.every((a) => a.unlockedAt == null), isTrue);
      // A 30-day streak alone must not unlock workout-count milestones,
      // and workout counts must not unlock streak milestones.
      final streakOnly = await AchievementService.recordAndEvaluate(
        statsRepository: statsRepo,
        currentStreakDays: 30,
      );
      expect(
        streakOnly.firstWhere((a) => a.id == 'first_workout').isUnlocked,
        isFalse,
      );
      expect(
        streakOnly.firstWhere((a) => a.id == 'streak_30').isUnlocked,
        isTrue,
      );
      // Nothing is recorded for still-locked milestones.
      final rows = await db.select(db.achievementUnlocks).get();
      expect(
        rows.map((r) => r.achievementId),
        unorderedEquals(['streak_7', 'streak_30']),
      );
    });

    test('First workout unlocks once with a durable timestamp', () async {
      await _seedSession(db, name: 'Push Day', totalVolumeKg: 2500.0);

      final first = await AchievementService.recordAndEvaluate(
        statsRepository: statsRepo,
        currentStreakDays: 1,
      );
      final badge = first.firstWhere((a) => a.id == 'first_workout');
      expect(badge.isUnlocked, isTrue);
      expect(badge.unlockedAt, isNotNull);
      expect(badge.evidence, contains('1 of 1 workout logged'));

      // Re-evaluation is idempotent: same row, same timestamp.
      final second = await AchievementService.recordAndEvaluate(
        statsRepository: statsRepo,
        currentStreakDays: 1,
      );
      final again = second.firstWhere((a) => a.id == 'first_workout');
      expect(again.unlockedAt, badge.unlockedAt);
      final rows = await db.select(db.achievementUnlocks).get();
      expect(
        rows.where((r) => r.achievementId == 'first_workout'),
        hasLength(1),
      );
    });

    test('Stored timestamps win over freshly minted ones', () async {
      // Simulate a restore carrying an older unlock event.
      final fixed = DateTime.utc(2025, 12, 25, 10, 0);
      await db.into(db.achievementUnlocks).insert(
            AchievementUnlocksCompanion.insert(
              achievementId: 'meals_10',
              unlockedAt: Value(fixed),
            ),
          );
      await _seedMeals(db, 12);

      final achievements = await AchievementService.recordAndEvaluate(
        statsRepository: statsRepo,
        currentStreakDays: 0,
      );
      final badge = achievements.firstWhere((a) => a.id == 'meals_10');
      expect(badge.isUnlocked, isTrue);
      // Same instant: the store round-trips through the local-zone column.
      expect(badge.unlockedAt?.toUtc(), fixed);
    });

    test('Volume evidence reports factual measured amounts', () async {
      await _seedSession(db, name: 'Leg Day', totalVolumeKg: 10450.0);

      final achievements = await AchievementService.recordAndEvaluate(
        statsRepository: statsRepo,
        currentStreakDays: 0,
      );
      final titan = achievements.firstWhere((a) => a.id == 'volume_10000');
      expect(titan.isUnlocked, isTrue);
      expect(titan.evidence, contains('10,450 kg / 10,000 kg'));
      final iron = achievements.firstWhere((a) => a.id == 'volume_1000');
      expect(iron.evidence, contains('10,450 kg / 1,000 kg'));
    });

    test('Direct insert relies on the unique constraint, not a pre-read', () async {
      expect(await statsRepo.unlockAchievement('first_thali'), isTrue);
      expect(await statsRepo.unlockAchievement('first_thali'), isFalse);
      final rows = await db.select(db.achievementUnlocks).get();
      expect(
        rows.where((r) => r.achievementId == 'first_thali'),
        hasLength(1),
      );
    });
  });
}
