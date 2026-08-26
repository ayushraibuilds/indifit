import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/achievement_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/progress_statistics_repository.dart';
import 'package:indifit/data/repositories/weekly_report_service.dart';
import 'package:indifit/features/progress/achievements_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2: Trustworthy Reports & Achievements Unit Tests', () {
    late AppDatabase db;
    late ProgressStatisticsRepository statsRepo;
    late WeeklyReportService reportService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.memory();
      statsRepo = ProgressStatisticsRepository(db);
      reportService = WeeklyReportService();
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Fresh install shows 0 unlocked badges and zero metrics', () async {
      final stats = await statsRepo.getLifetimeStats();
      expect(stats.totalWorkouts, equals(0));
      expect(stats.totalVolumeKg, equals(0.0));
      expect(stats.totalMealsLogged, equals(0));
      expect(stats.totalPrs, equals(0));
      expect(stats.thaliLoggedCount, equals(0));
      expect(stats.unlockedAchievementIds, isEmpty);

      final achievements = AchievementService.evaluateFromLifetimeStats(
        stats: stats,
        currentStreakDays: 0,
      );

      final unlockedCount = achievements.where((a) => a.isUnlocked).length;
      expect(unlockedCount, equals(0));
    });

    test(
      '2. Logging 1 workout session unlocks "first_workout" and persists timestamp in SQLite',
      () async {
        final sessionId = await db
            .into(db.workoutSessions)
            .insert(
              WorkoutSessionsCompanion.insert(
                name: 'Upper Body A',
                totalVolume: 1200.0,
                durationSeconds: 2700,
                estimatedCalories: 300,
                completedAt: Value(DateTime.now()),
              ),
            );

        await db
            .into(db.workoutSets)
            .insert(
              WorkoutSetsCompanion.insert(
                sessionId: sessionId,
                exerciseName: 'Bench Press',
                weight: 80.0,
                reps: 5,
                setNumber: 1,
                isPr: const Value(true),
              ),
            );

        final stats = await statsRepo.getLifetimeStats();
        expect(stats.totalWorkouts, equals(1));
        expect(stats.totalVolumeKg, equals(1200.0));
        expect(stats.totalPrs, equals(1));

        final achievements = AchievementService.evaluateFromLifetimeStats(
          stats: stats,
          currentStreakDays: 1,
        );

        final firstWorkoutBadge = achievements.firstWhere(
          (a) => a.id == 'first_workout',
        );
        final firstPrBadge = achievements.firstWhere((a) => a.id == 'first_pr');
        final heavyMoverBadge = achievements.firstWhere(
          (a) => a.id == 'volume_5000',
        );

        expect(firstWorkoutBadge.isUnlocked, isTrue);
        expect(firstPrBadge.isUnlocked, isTrue);
        expect(heavyMoverBadge.isUnlocked, isFalse);

        // Record unlock transactionally
        final didUnlock = await statsRepo.unlockAchievement('first_workout');
        expect(didUnlock, isTrue);

        // Verify persistence in SQLite
        final reloadedStats = await statsRepo.getLifetimeStats();
        expect(
          reloadedStats.unlockedAchievementIds.containsKey('first_workout'),
          isTrue,
        );
        expect(
          reloadedStats.unlockedAchievementIds['first_workout'],
          isNotNull,
        );

        // Re-unlock attempt should return false (already recorded)
        final secondUnlock = await statsRepo.unlockAchievement('first_workout');
        expect(secondUnlock, isFalse);
      },
    );

    test(
      '3. Insufficient data (<2 logged days & 0 workouts) returns honest unlock state',
      () async {
        final metrics = await statsRepo.getWeeklyMetrics();
        expect(metrics.nutritionDaysLogged, equals(0));
        expect(metrics.completedWorkoutsCount, equals(0));

        final report = await reportService.generateReportFromMetrics(metrics);
        expect(report.isInsufficientData, isTrue);
        expect(report.isFallback, isTrue);
        expect(
          report.headline,
          equals('Log a few more days to unlock your report'),
        );
        expect(report.adherenceScore, equals(0.0));
      },
    );

    test(
      '4. Deleting all records cannot produce non-zero report metrics',
      () async {
        // Seed data
        await db
            .into(db.foodLogs)
            .insert(
              FoodLogsCompanion.insert(
                name: 'Oats',
                calories: 300,
                proteinG: 10.0,
                carbsG: 50.0,
                fatG: 5.0,
                servingLogged: 1.0,
                servingUnit: 'bowl',
                mealType: 'breakfast',
                loggedAt: Value(DateTime.now()),
              ),
            );

        // Clear all records
        await db.delete(db.foodLogs).go();
        await db.delete(db.workoutSessions).go();
        await db.delete(db.workoutSets).go();

        final metrics = await statsRepo.getWeeklyMetrics();
        expect(metrics.totalCaloriesLogged, equals(0));
        expect(metrics.completedWorkoutsCount, equals(0));
        expect(metrics.overallAdherenceScore, equals(0.0));

        final report = await reportService.generateReportFromMetrics(metrics);
        expect(report.isInsufficientData, isTrue);
        expect(report.adherenceScore, equals(0.0));
      },
    );

    test(
      '5. 7 days of real data produces structured metrics and offline report',
      () async {
        final mockNow = DateTime(2026, 7, 28, 12, 0);
        final clockedRepo = ProgressStatisticsRepository(
          db,
          clock: () => mockNow,
        );

        // Seed 3 days of food logs
        for (int i = 0; i < 3; i++) {
          await db
              .into(db.foodLogs)
              .insert(
                FoodLogsCompanion.insert(
                  name: 'Meal $i',
                  calories: 2000,
                  proteinG: 150.0,
                  carbsG: 200.0,
                  fatG: 60.0,
                  servingLogged: 1.0,
                  servingUnit: 'plate',
                  mealType: 'dinner',
                  loggedAt: Value(mockNow.subtract(Duration(days: i))),
                ),
              );
        }

        final metrics = await clockedRepo.getWeeklyMetrics();
        expect(metrics.nutritionDaysLogged, equals(3));
        expect(metrics.totalCaloriesLogged, equals(6000));

        final report = await reportService.generateReportFromMetrics(metrics);
        expect(report.isInsufficientData, isFalse);
        expect(report.summary, contains('3 days'));
        expect(report.summary, contains('6000 total kcal'));
      },
    );

    testWidgets('6. Achievements remains usable at 320 width and 2x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'user_streak_count': 0});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            progressStatisticsRepositoryProvider.overrideWithValue(
              _FakeAchievementRepository(db),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: MediaQueryData.fromView(tester.view).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: const AchievementsScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pump();
      expect(find.text('ALL BADGES'), findsOneWidget);
      expect(find.text('First Sweat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _FakeAchievementRepository extends ProgressStatisticsRepository {
  _FakeAchievementRepository(super.database);

  @override
  Future<LifetimeAchievementStats> getLifetimeStats() async =>
      const LifetimeAchievementStats(
        totalWorkouts: 0,
        totalVolumeKg: 0,
        totalMealsLogged: 0,
        totalPrs: 0,
        thaliLoggedCount: 0,
        unlockedAchievementIds: {},
      );

  @override
  Future<bool> unlockAchievement(String achievementId) async => false;
}
