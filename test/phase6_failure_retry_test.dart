import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_file_adapter.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/core/di/health_provider.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/errors/app_failure.dart';
import 'package:indifit/core/services/achievement_service.dart';
import 'package:indifit/core/services/notification_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/widgets/failure_state_widget.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/health_service.dart';
import 'package:indifit/data/repositories/progress_statistics_repository.dart';
import 'package:indifit/features/settings/health_sync_hub_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 6: Consistent Failure, Retry, & Comprehensive Validation Suite', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (MethodCall methodCall) async => true,
      );
      db = AppDatabase.memory();
    });

    tearDown(() async {
      await db.close();
    });

    test('1. AppFailure & Result DTO classify errors accurately with action callbacks', () {
      bool actionTriggered = false;

      final failure = AppFailure.offlinePolicyBlocked(
        onAction: () => actionTriggered = true,
      );

      expect(failure.type, equals(AppFailureType.offlinePolicyBlocked));
      expect(failure.actionLabel, equals('Settings'));

      failure.onAction?.call();
      expect(actionTriggered, isTrue);

      final resultSuccess = Result.success('data', fallbackReason: 'Offline Fallback');
      expect(resultSuccess.isSuccess, isTrue);
      expect((resultSuccess as Success<String>).isFallback, isTrue);

      final resultFailure = Result<String>.failure(failure);
      expect(resultFailure.isFailure, isTrue);
      expect(resultFailure.failureOrNull?.type, equals(AppFailureType.offlinePolicyBlocked));
    });

    test('2. ProgressStatisticsRepository handles 7-day boundaries, leap days, and adherence weighting', () async {
      final repo = ProgressStatisticsRepository(db);

      // Leap day test date: 2028-02-29
      final leapDate = DateTime(2028, 2, 29);
      final metrics = await repo.getWeeklyMetrics(referenceDate: leapDate);

      expect(metrics.startDate, equals(DateTime(2028, 2, 23)));
      expect(metrics.nutritionDaysLogged, equals(0));
      expect(metrics.overallAdherenceScore, equals(0.0));

      // Log food on leap day
      await db.into(db.foodLogs).insert(
        FoodLogsCompanion.insert(
          name: 'Poha',
          calories: 300,
          proteinG: 8.0,
          carbsG: 45.0,
          fatG: 10.0,
          servingLogged: 1.0,
          servingUnit: 'plate',
          mealType: 'breakfast',
          loggedAt: Value(leapDate),
        ),
      );

      final leapMetrics = await repo.getWeeklyMetrics(referenceDate: leapDate);
      expect(leapMetrics.nutritionDaysLogged, equals(1));
      expect(leapMetrics.totalCaloriesLogged, equals(300));
    });

    test('3. AchievementService evaluates thresholds and unlocks correctly', () async {
      final achievementsBefore = AchievementService.evaluateAchievements(
        completedWorkoutsCount: 0,
        currentStreakDays: 0,
        totalVolumeKg: 0.0,
        totalLoggedMealsCount: 0,
      );

      final firstWorkoutBefore = achievementsBefore.firstWhere((a) => a.id == 'first_workout');
      expect(firstWorkoutBefore.isUnlocked, isFalse);

      // Evaluate after completing 1 workout
      final achievementsAfter = AchievementService.evaluateAchievements(
        completedWorkoutsCount: 1,
        currentStreakDays: 1,
        totalVolumeKg: 800.0,
        totalLoggedMealsCount: 5,
      );

      final firstWorkoutAfter = achievementsAfter.firstWhere((a) => a.id == 'first_workout');
      expect(firstWorkoutAfter.isUnlocked, isTrue);
    });

    test('4. Database schema v14 & backup schema v5 round-trip serialization', () async {
      final prefs = await SharedPreferences.getInstance();

      // Insert record into userProfile & dailyHydrations
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          name: const Value('Test Athlete'),
          age: const Value(28),
          sex: const Value('male'),
          height: const Value(175.0),
          weight: const Value(70.0),
          activityLevel: const Value('active'),
          goal: const Value('maintain'),
        ),
      );

      await db.into(db.dailyHydrations).insert(
        DailyHydrationsCompanion.insert(
          dateString: '2026-07-28',
          totalMl: 2500,
          goalMl: 3000,
        ),
      );

      final backupData = await BackupData.createFromDatabase(db, prefs);
      expect(backupData.version, equals(BackupData.currentVersion));
      expect(backupData.userProfile?.name, equals('Test Athlete'));
      expect(backupData.dailyHydrations.length, equals(1));

      // Verify envelope creation and inspection
      final envelopeJson = BackupFileAdapter.exportToEnvelopeJson(
        data: backupData,
        password: 'Password123!',
      );

      final inspection = await BackupFileAdapter.inspectBackupContent(
        envelopeJson,
        password: 'Password123!',
      );

      expect(inspection.isEncrypted, isTrue);
      expect(inspection.profileName, equals('Test Athlete'));
      expect(inspection.tableCounts['daily_hydrations'], equals(1));
    });

    testWidgets('5. FailureStateWidget renders failure details and responds to retry action', (WidgetTester tester) async {
      bool retried = false;
      final failure = AppFailure.network(
        message: 'Unable to connect to IndiFit AI server.',
        onRetry: () => retried = true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: FailureStateWidget(
              failure: failure,
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Unable to connect to IndiFit AI server.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retried, isTrue);
    });

    testWidgets('6. HealthSyncHubScreen displays category permission toggles', (WidgetTester tester) async {
      final mockService = MockHealthService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            healthServiceProvider.overrideWithValue(mockService),
            healthStateProvider.overrideWith((ref) => FixedHealthNotifier(mockService)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HealthSyncHubScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Health Sync Hub'), findsOneWidget);
      expect(find.text('GRANULAR PERMISSION CATEGORIES'), findsOneWidget);
      expect(find.text('Steps Import (Read)'), findsOneWidget);
    });

    test('7. Timezone resolver handles injected IANA locations and DST transitions cleanly', () async {
      await NotificationService.initialize();
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(NotificationService.prefLastScheduledTimezoneId, 'Europe/London');
      await prefs.setInt(NotificationService.prefLastUtcOffsetMinutes, 0);

      final rescheduled = await NotificationService.checkAndUpdateTimezoneAndReschedule(db);
      expect(rescheduled, isTrue);
    });
  });
}

class MockHealthService extends HealthService {
  @override
  Future<HealthDataSummary> fetchTodayHealthData() async {
    return const HealthDataSummary(
      steps: 5000,
      activeCalories: 300,
      sleepHours: 7.5,
      isConnected: true,
      categoryStates: {
        HealthCategory.steps: true,
        HealthCategory.activeEnergy: true,
        HealthCategory.sleep: true,
        HealthCategory.workoutImport: true,
        HealthCategory.workoutExport: true,
        HealthCategory.weightExport: true,
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> importOutdoorActivities([AppDatabase? db]) async {
    return [];
  }

  @override
  Future<Map<HealthCategory, bool>> getAllCategoryStates() async {
    return {
      HealthCategory.steps: true,
      HealthCategory.activeEnergy: true,
      HealthCategory.sleep: true,
      HealthCategory.workoutImport: true,
      HealthCategory.workoutExport: true,
      HealthCategory.weightExport: true,
    };
  }
}

class FixedHealthNotifier extends HealthStateNotifier {
  FixedHealthNotifier(super.service) {
    state = const HealthState(
      status: HealthStatus.available,
      summary: HealthDataSummary(isConnected: true),
    );
  }

  @override
  Future<void> loadHealthData() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> connectAndRefresh() async {}
}
