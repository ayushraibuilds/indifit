import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/progress_statistics_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1: Shared Data Foundation Unit & Integration Tests', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.memory();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      '1. Schema v18 initializes with retained user profile columns',
      () async {
        expect(db.schemaVersion, equals(18));

        // Test UserProfiles extended columns
        await db
            .into(db.userProfiles)
            .insert(
              UserProfilesCompanion.insert(
                name: const Value('Ayush Rai'),
                equipmentAccess: const Value('Dumbbell, Barbell'),
                injuriesLimitations: const Value('Lower back pain'),
                calorieGoal: const Value(2200),
                proteinGoal: const Value(150.0),
              ),
            );

        final profiles = await db.select(db.userProfiles).get();
        expect(profiles.length, equals(1));
        expect(profiles.first.name, equals('Ayush Rai'));
        expect(profiles.first.equipmentAccess, equals('Dumbbell, Barbell'));
        expect(profiles.first.injuriesLimitations, equals('Lower back pain'));

        // Test DailyHydrations table CRUD
        await db
            .into(db.dailyHydrations)
            .insert(
              DailyHydrationsCompanion.insert(
                dateString: '2026-07-28',
                totalMl: 2500,
                goalMl: 3000,
              ),
            );

        final hydrations = await db.select(db.dailyHydrations).get();
        expect(hydrations.length, equals(1));
        expect(hydrations.first.dateString, equals('2026-07-28'));
        expect(hydrations.first.totalMl, equals(2500));

        // Test HealthProvenances table CRUD
        final sessionId = await db
            .into(db.workoutSessions)
            .insert(
              WorkoutSessionsCompanion.insert(
                name: 'Morning Run',
                totalVolume: 0.0,
                durationSeconds: 1800,
                estimatedCalories: 250,
              ),
            );

        await db
            .into(db.healthProvenances)
            .insert(
              HealthProvenancesCompanion.insert(
                provider: 'health_connect',
                externalId: const Value('ext_session_123'),
                sourceName: 'Google Fit',
                localSessionId: Value(sessionId),
                fingerprint: 'fp_run_123456',
              ),
            );

        final provenances = await db.select(db.healthProvenances).get();
        expect(provenances.length, equals(1));
        expect(provenances.first.externalId, equals('ext_session_123'));
        expect(provenances.first.localSessionId, equals(sessionId));

        // Test AchievementUnlocks table CRUD
        await db
            .into(db.achievementUnlocks)
            .insert(
              AchievementUnlocksCompanion.insert(
                achievementId: 'first_workout',
              ),
            );

        final unlocks = await db.select(db.achievementUnlocks).get();
        expect(unlocks.length, equals(1));
        expect(unlocks.first.achievementId, equals('first_workout'));
      },
    );

    test(
      '2. BackupData Version 7 round-trips all new tables and extended profile data',
      () async {
        // Seed user profile
        await db
            .into(db.userProfiles)
            .insert(
              UserProfilesCompanion.insert(
                name: const Value('Jane Doe'),
                equipmentAccess: const Value('Full Gym'),
                injuriesLimitations: const Value('None'),
                calorieGoal: const Value(2400),
              ),
            );

        // Seed hydration
        await db
            .into(db.dailyHydrations)
            .insert(
              DailyHydrationsCompanion.insert(
                dateString: '2026-07-28',
                totalMl: 2250,
                goalMl: 2500,
              ),
            );

        // Seed achievement unlock
        await db
            .into(db.achievementUnlocks)
            .insert(
              AchievementUnlocksCompanion.insert(achievementId: 'century_club'),
            );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', 'Jane Doe');

        final backup = await BackupData.createFromDatabase(db, prefs);
        expect(backup.version, equals(BackupData.currentVersion));
        expect(backup.userProfile?.name, equals('Jane Doe'));
        expect(backup.dailyHydrations.length, equals(1));
        expect(backup.achievementUnlocks.length, equals(1));

        final json = backup.toJson();
        final parsed = BackupData.fromJson(json);

        expect(parsed.version, equals(BackupData.currentVersion));
        expect(parsed.userProfile?.name, equals('Jane Doe'));
        expect(parsed.dailyHydrations.first.totalMl, equals(2250));
        expect(
          parsed.achievementUnlocks.first.achievementId,
          equals('century_club'),
        );

        // Perform atomic restore to a fresh database
        final freshDb = AppDatabase.memory();
        await parsed.restoreToDatabase(freshDb);

        final restoredProfiles = await freshDb
            .select(freshDb.userProfiles)
            .get();
        final restoredHydrations = await freshDb
            .select(freshDb.dailyHydrations)
            .get();
        final restoredUnlocks = await freshDb
            .select(freshDb.achievementUnlocks)
            .get();

        expect(restoredProfiles.first.name, equals('Jane Doe'));
        expect(restoredHydrations.first.totalMl, equals(2250));
        expect(restoredUnlocks.first.achievementId, equals('century_club'));

        await freshDb.close();
      },
    );

    test(
      '3. BackupData parses legacy Version 4 backups with default fallbacks',
      () async {
        final legacyV4Json = {
          'version': 4,
          'timestamp': DateTime.now().toIso8601String(),
          'schema_version': 13,
          'user_profile': {
            'id': 1,
            'age': 30,
            'height': 175.0,
            'weight': 75.0,
            'sex': 'male',
            'activity_level': 'active',
            'goal': 'build_muscle',
            'diet_preference': 'high_protein',
            'calorie_goal': 2500,
            'protein_goal': 160.0,
            'carbs_goal': 250.0,
            'fat_goal': 70.0,
            'updated_at': DateTime.now().toIso8601String(),
          },
          'user_settings': [],
          'user_preferences': {},
          'food_items': [],
          'food_logs': [],
          'meal_templates': [],
          'meal_template_items': [],
          'custom_exercises': [],
          'workout_sessions': [],
          'workout_sets': [],
          'workout_routines': [],
          'routine_days': [],
          'routine_exercises': [],
          'workout_drafts': [],
          'body_measurements': [],
        };

        final parsed = BackupData.fromJson(legacyV4Json);
        expect(parsed.version, equals(4));
        expect(parsed.userProfile?.name, equals(''));
        expect(parsed.userProfile?.equipmentAccess, equals('full_gym'));
        expect(parsed.dailyHydrations, isEmpty);
        expect(parsed.healthProvenances, isEmpty);
        expect(parsed.achievementUnlocks, isEmpty);
      },
    );

    test(
      '4. ProgressStatisticsRepository calculates 7-day metrics with clock injection',
      () async {
        final mockNow = DateTime(2026, 7, 28, 14, 30);
        final repo = ProgressStatisticsRepository(db, clock: () => mockNow);

        // Seed food logs within the 7-day window (July 22 to July 28)
        await db
            .into(db.foodLogs)
            .insert(
              FoodLogsCompanion.insert(
                name: 'Chicken Rice',
                calories: 600,
                proteinG: 45.0,
                carbsG: 60.0,
                fatG: 12.0,
                servingLogged: 1.0,
                servingUnit: 'plate',
                mealType: 'lunch',
                loggedAt: Value(DateTime(2026, 7, 28, 13, 0)),
              ),
            );

        await db
            .into(db.dailyHydrations)
            .insert(
              DailyHydrationsCompanion.insert(
                dateString: '2026-07-28',
                totalMl: 3000,
                goalMl: 2500,
              ),
            );

        await db
            .into(db.workoutSessions)
            .insert(
              WorkoutSessionsCompanion.insert(
                name: 'Leg Day',
                totalVolume: 5000.0,
                durationSeconds: 3600,
                estimatedCalories: 400,
                completedAt: Value(DateTime(2026, 7, 27, 10, 0)),
              ),
            );

        final metrics = await repo.getWeeklyMetrics();
        expect(metrics.startDate, equals(DateTime(2026, 7, 22)));
        expect(metrics.endDate, equals(DateTime(2026, 7, 28)));
        expect(metrics.totalCaloriesLogged, equals(600));
        expect(metrics.totalProteinG, equals(45.0));
        expect(metrics.hydrationDaysAtGoal, equals(1));
        expect(metrics.completedWorkoutsCount, equals(1));
        expect(metrics.totalVolumeKg, equals(5000.0));
        expect(metrics.overallAdherenceScore, greaterThan(0.0));
      },
    );

    test(
      '5. AdherenceBreakdown dynamically reweights applicable metrics',
      () async {
        final mockNow = DateTime(2026, 7, 28);
        final repo = ProgressStatisticsRepository(db, clock: () => mockNow);

        // Empty database => valid scores are empty => overallScore is 0.0 without throwing divide-by-zero
        final metrics = await repo.getWeeklyMetrics();
        expect(metrics.overallAdherenceScore, equals(0.0));
        expect(metrics.adherenceBreakdown.calorieScore, isNull);
        expect(metrics.adherenceBreakdown.proteinScore, isNull);
        expect(metrics.adherenceBreakdown.hydrationScore, isNull);
      },
    );

    test(
      '6. Water logging persists daily hydration for seven-day reporting',
      () async {
        final notifier = WaterNotifier(db);
        await notifier.loadState();

        await notifier.logWater(3);

        final today = DateTime.now().toIso8601String().split('T').first;
        final hydration = await (db.select(
          db.dailyHydrations,
        )..where((tbl) => tbl.dateString.equals(today))).getSingle();

        expect(hydration.totalMl, equals(3 * notifier.state.glassSize));
        expect(
          hydration.goalMl,
          equals(notifier.state.waterGoal * notifier.state.glassSize),
        );

        final metrics = await ProgressStatisticsRepository(
          db,
        ).getWeeklyMetrics();
        expect(metrics.totalHydrationMl, equals(hydration.totalMl));
        expect(metrics.totalHydrationGoalMl, equals(hydration.goalMl));
      },
    );
  });
}
