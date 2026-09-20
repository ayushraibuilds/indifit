import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_v10.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/achievement_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/progress_statistics_repository.dart';
import 'package:indifit/features/dashboard/dashboard_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProgressStatisticsRepository statsRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
    statsRepo = ProgressStatisticsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('PV1-PROD-03B: Domain & Reconciliation Tests', () {
    test('1. Catalog partition: 9 badges, disjoint and exhaustive', () {
      final allCatalog = AchievementService.evaluateAchievements(
        completedWorkoutsCount: 0,
        currentStreakDays: 0,
        totalVolumeKg: 0,
        totalLoggedMealsCount: 0,
      );
      final allIds = allCatalog.map((a) => a.id).toSet();

      expect(allIds.length, equals(9));
      expect(
        allIds,
        equals({
          'first_workout',
          'streak_7',
          'streak_30',
          'volume_1000',
          'volume_5000',
          'volume_10000',
          'meals_10',
          'meals_50',
          'first_thali',
        }),
      );

      final workoutIds = AchievementService.workoutAchievementIds;
      final nonWorkoutIds = AchievementService.nonWorkoutAchievementIds;

      // Disjoint
      expect(workoutIds.intersection(nonWorkoutIds), isEmpty);

      // Exhaustive
      expect(workoutIds.union(nonWorkoutIds), equals(allIds));
    });

    test('2. recordAndEvaluateDelta returns exact session unlocks and is idempotent', () async {
      // Seed a session with 1200kg volume -> meets first_workout and volume_1000
      final sessionId = await db.into(db.workoutSessions).insert(
        WorkoutSessionsCompanion.insert(
          name: 'Heavy Push',
          totalVolume: 1200.0,
          durationSeconds: 3000,
          estimatedCalories: 350,
          completedAt: Value(DateTime.now()),
        ),
      );
      await db.into(db.workoutSets).insert(
        WorkoutSetsCompanion.insert(
          sessionId: sessionId,
          exerciseName: 'Bench Press',
          weight: 100.0,
          reps: 12,
          setNumber: 1,
        ),
      );

      final result1 = await AchievementService.recordAndEvaluateDelta(
        statsRepository: statsRepo,
        currentStreakDays: 1,
      );

      final sessionUnlockedIds = result1.sessionUnlocked.map((a) => a.id).toSet();
      expect(sessionUnlockedIds, equals({'first_workout', 'volume_1000'}));

      // All contains both unlocked with stored timestamps
      final unlockedInAll = result1.all.where((a) => a.isUnlocked).map((a) => a.id).toSet();
      expect(unlockedInAll, equals({'first_workout', 'volume_1000'}));
      for (final a in result1.sessionUnlocked) {
        expect(a.unlockedAt, isNotNull);
      }

      // Re-running without new milestones yields empty sessionUnlocked
      final result2 = await AchievementService.recordAndEvaluateDelta(
        statsRepository: statsRepo,
        currentStreakDays: 1,
      );
      expect(result2.sessionUnlocked, isEmpty);
      expect(result2.all.where((a) => a.isUnlocked).length, equals(2));
    });

    test('3. Absence-only baselining seeds cold start without swallowing killed first unlock', () async {
      final prefs = await SharedPreferences.getInstance();

      // Case A: Fresh install with 0 unlocks -> seeds empty list
      expect(prefs.containsKey(AchievementService.prefCelebratedAchievementIds), isFalse);
      await AchievementService.ensureBaselined(prefs, []);
      expect(prefs.containsKey(AchievementService.prefCelebratedAchievementIds), isTrue);
      expect(prefs.getStringList(AchievementService.prefCelebratedAchievementIds), isEmpty);

      // Case B: Key exists (even empty) -> does NOT overwrite
      await prefs.setStringList(AchievementService.prefCelebratedAchievementIds, ['first_workout']);
      await AchievementService.ensureBaselined(prefs, ['first_workout', 'volume_1000']);
      // Still only 'first_workout' because key already existed
      expect(
        prefs.getStringList(AchievementService.prefCelebratedAchievementIds),
        equals(['first_workout']),
      );

      // Case C: Fresh user with 1 unlock whose app died before baseline
      // Reset prefs
      await prefs.clear();
      expect(prefs.containsKey(AchievementService.prefCelebratedAchievementIds), isFalse);
      // SQLite already has 'first_workout'
      await AchievementService.ensureBaselined(prefs, ['first_workout']);
      expect(
        prefs.getStringList(AchievementService.prefCelebratedAchievementIds),
        equals(['first_workout']),
      );
    });

    test('4. rebaseCelebratedOnRestore leaves restored accounts completely silent', () async {
      final prefs = await SharedPreferences.getInstance();

      // Seed SQLite with 3 achievements
      final fixedDate = DateTime.utc(2026, 6, 15, 10, 30);
      await db.into(db.achievementUnlocks).insert(
        AchievementUnlocksCompanion.insert(
          achievementId: 'first_workout',
          unlockedAt: Value(fixedDate),
        ),
      );
      await db.into(db.achievementUnlocks).insert(
        AchievementUnlocksCompanion.insert(
          achievementId: 'volume_1000',
          unlockedAt: Value(fixedDate),
        ),
      );
      await db.into(db.achievementUnlocks).insert(
        AchievementUnlocksCompanion.insert(
          achievementId: 'meals_10',
          unlockedAt: Value(fixedDate),
        ),
      );

      // Prefs initially empty or missing
      await prefs.clear();

      await AchievementService.rebaseCelebratedOnRestore(db, prefs);

      final celebrated = prefs.getStringList(AchievementService.prefCelebratedAchievementIds);
      expect(celebrated, isNotNull);
      expect(celebrated!.toSet(), equals({'first_workout', 'volume_1000', 'meals_10'}));

      // Querying uncelebrated non-workout unlocks must be empty!
      final uncelebrated = await AchievementService.getUncelebratedNonWorkoutUnlocks(
        statsRepository: statsRepo,
        prefs: prefs,
      );
      expect(uncelebrated, isEmpty);
    });

    test('5. Backup restore round-trip preserves SQLite achievement_unlocks and rebase silences announcements', () async {
      final prefs = await SharedPreferences.getInstance();

      // Seed source database with achievement unlocks
      final unlockTime = DateTime.utc(2026, 5, 20, 14, 0);
      await db.into(db.achievementUnlocks).insert(
        AchievementUnlocksCompanion.insert(
          achievementId: 'first_workout',
          unlockedAt: Value(unlockTime),
        ),
      );
      await db.into(db.achievementUnlocks).insert(
        AchievementUnlocksCompanion.insert(
          achievementId: 'meals_10',
          unlockedAt: Value(unlockTime),
        ),
      );

      // Export to backup json
      final backup = await BackupV10Data.createFromDatabase(db, prefs);
      final jsonMap = backup.toJson();
      final jsonString = jsonEncode(jsonMap);

      // Create target clean database and prefs
      final targetDb = AppDatabase.memory();
      final targetStatsRepo = ProgressStatisticsRepository(targetDb);
      addTearDown(targetDb.close);
      await prefs.clear();

      // Perform restore using SettingsController logic
      final restoredData = jsonDecode(jsonString) as Map<String, dynamic>;
      await BackupV10Data.fromJson(restoredData).restoreToDatabase(targetDb, prefs);
      await AchievementService.rebaseCelebratedOnRestore(targetDb, prefs);

      // Assert SQLite rows restored byte-for-byte with timestamps
      final restoredUnlocks = await targetDb.select(targetDb.achievementUnlocks).get();
      expect(restoredUnlocks.length, equals(2));
      final byId = {for (final u in restoredUnlocks) u.achievementId: u};
      expect(byId.containsKey('first_workout'), isTrue);
      expect(byId['first_workout']!.unlockedAt.isAtSameMomentAs(unlockTime), isTrue);
      expect(byId.containsKey('meals_10'), isTrue);
      expect(byId['meals_10']!.unlockedAt.isAtSameMomentAs(unlockTime), isTrue);

      // Assert celebrated IDs in prefs were rebased
      final targetCelebrated = prefs.getStringList(AchievementService.prefCelebratedAchievementIds);
      expect(targetCelebrated?.toSet(), equals({'first_workout', 'meals_10'}));

      // Restored account is completely silent: no pending non-workout announcements
      final pendingNonWorkout = await AchievementService.getUncelebratedNonWorkoutUnlocks(
        statsRepository: targetStatsRepo,
        prefs: prefs,
      );
      expect(pendingNonWorkout, isEmpty);
    });

    test('6. DashboardController reconciles non-workout unlocks and isolates workout unlocks', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final controller = container.read(dashboardControllerProvider.notifier);
      await controller.loadStateData();

      // Workout session logging does NOT trigger Dashboard newlyUnlockedAchievementIds
      await db.into(db.workoutSessions).insert(
        WorkoutSessionsCompanion.insert(
          name: 'Session',
          totalVolume: 500.0,
          durationSeconds: 1800,
          estimatedCalories: 200,
          completedAt: Value(DateTime.now()),
        ),
      );

      await controller.loadStateData();
      expect(container.read(dashboardControllerProvider).newlyUnlockedAchievementIds, isEmpty);

      // Food log with Thali DOES trigger Dashboard newlyUnlockedAchievementIds
      await db.into(db.foodLogs).insert(
        FoodLogsCompanion.insert(
          name: 'Deluxe Thali',
          calories: 700,
          proteinG: 22.0,
          carbsG: 90.0,
          fatG: 25.0,
          servingLogged: 1.0,
          servingUnit: 'plate',
          mealType: 'dinner',
          loggedAt: Value(DateTime.now()),
        ),
      );

      await controller.loadStateData();
      final state = container.read(dashboardControllerProvider);
      expect(state.newlyUnlockedAchievementIds, equals(['first_thali']));
      expect(state.newlyUnlockedAchievementTitles, equals(['Thali Connoisseur']));

      // Mark celebrated (as DashboardScreen does upon showing SnackBar)
      final prefs = await SharedPreferences.getInstance();
      await AchievementService.markCelebrated(prefs, ['first_thali']);

      // Refreshing dashboard now sees it marked celebrated -> state clears
      await controller.loadStateData();
      expect(container.read(dashboardControllerProvider).newlyUnlockedAchievementIds, isEmpty);
    });

    test('7. getRecentlyUnlocked correctly sorts unlocked achievements descending by unlockedAt', () {
      final t1 = DateTime.utc(2026, 1, 1);
      final t2 = DateTime.utc(2026, 3, 15);
      final t3 = DateTime.utc(2026, 2, 10);

      final rawAchievements = [
        AchievementService.evaluateAchievements(
          completedWorkoutsCount: 0,
          currentStreakDays: 0,
          totalVolumeKg: 0,
          totalLoggedMealsCount: 0,
          unlockedTimestamps: {
            'first_workout': t1,
            'volume_1000': t2,
            'meals_10': t3,
          },
        ),
      ].expand((x) => x).toList();

      final recent = AchievementService.getRecentlyUnlocked(rawAchievements);
      expect(recent.map((a) => a.id).toList(), equals(['volume_1000', 'meals_10', 'first_workout']));
    });
  });
}
