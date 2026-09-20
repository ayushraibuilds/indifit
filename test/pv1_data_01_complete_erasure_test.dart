import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/capabilities/account_capability.dart';
import 'package:indifit/core/capabilities/cloud_backup_capability.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/router/app_router.dart';
import 'package:indifit/core/services/auto_backup_secret_store.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/health_service.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/indifit_test_harness.dart';

void main() {
  initializeIndiFitTestHarness();

  late Directory tempTestDir;
  late Directory tempDocDir;
  late Directory tempExportDir;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (_) async => true,
        );

    tempTestDir = await Directory.systemTemp.createTemp('indifit_erasure_test_');
    tempDocDir = Directory('${tempTestDir.path}/documents');
    await tempDocDir.create(recursive: true);
    tempExportDir = Directory('${tempTestDir.path}/temporary');
    await tempExportDir.create(recursive: true);

    setIndiFitTestPreferences({
      'onboarding_completed': true,
      'water_goal': 12,
      'water_glass_size': 300,
      'health_last_sync_time': '2026-09-08T10:00:00Z',
      'cloud_backup_last_success_utc': '2026-09-08T12:00:00Z',
      'cloud_backup_last_fingerprint_v1': 'test-fingerprint',
      'offline_only': true,
      'crash_reporting_enabled': false,
    });
  });

  tearDown(() async {
    if (await tempTestDir.exists()) {
      await tempTestDir.delete(recursive: true);
    }
  });

  group('PV1-DATA-01 Complete Data Erasure Orchestrator Tests', () {
    test(
      'erases all user records, custom items, preferences, secrets, files, and verifies zero residue',
      () async {
        final databases = registerTestDatabaseScope();
        final db = databases.create();

        await _populateExtensiveUserData(db);

        // Populate local backup files in docDir/backups
        final backupDir = Directory('${tempDocDir.path}/backups');
        await backupDir.create(recursive: true);
        final backupFile1 = File('${backupDir.path}/indifit_auto_backup_1.json');
        await backupFile1.writeAsString('{"format_identifier":"INDIFIT_BACKUP_ENVELOPE"}');
        final backupFile2 = File('${backupDir.path}/indifit_auto_backup_2.json');
        await backupFile2.writeAsString('{"format_identifier":"INDIFIT_BACKUP_ENVELOPE"}');

        // Populate temp export file
        final tempExport = File('${tempExportDir.path}/indifit_backup_2026-09-09.indifit-backup');
        await tempExport.writeAsString('encrypted-backup-content');

        final secretStore = _TestAutoBackupSecretStore('device-secret-12345');
        final cloudBackup = _TestCloudBackupCapability();
        final account = _TestAccountCapability();
        final health = _TestHealthService();

        final service = DataErasureService(
          db: db,
          secretStore: secretStore,
          cloudBackup: cloudBackup,
          account: account,
          healthService: health,
          documentsDirectoryProvider: () async => tempDocDir,
          temporaryDirectoryProvider: () async => tempExportDir,
        );

        // Pre-condition checks
        final preCustomFoods = await (db.select(db.foodItems)
              ..where((f) => f.isCustom.equals(true)))
            .get();
        expect(preCustomFoods, isNotEmpty);
        final preWorkouts = await db.select(db.workoutSessions).get();
        expect(preWorkouts, isNotEmpty);
        final preProfiles = await db.select(db.userProfiles).get();
        expect(preProfiles, isNotEmpty);

        // Execute complete erasure
        final report = await service.eraseAllData();

        // Verification assertions
        expect(report.isSuccess, isTrue, reason: 'Report failed: ${report.failureReason}');
        expect(report.failureReason, isNull);
        expect(report.foreignKeyCheckPassed, isTrue);
        expect(report.preferencesCleared, isTrue);
        expect(report.secureStorageCleared, isTrue);
        expect(report.localFilesCleared, isTrue);
        expect(report.notificationsCancelled, isTrue);
        expect(report.cloudBackupsPurged, isTrue);
        expect(report.accountDeleted, isTrue);
        expect(report.healthDisconnected, isTrue);

        // 1. All user table counts in report must be 0
        for (final entry in report.remainingUserTableCounts.entries) {
          expect(
            entry.value,
            0,
            reason: 'Table ${entry.key} still contains ${entry.value} rows!',
          );
        }

        // 2. Custom foods and exercises must be 0
        expect(report.remainingCustomFoodsCount, 0);
        expect(report.remainingCustomExercisesCount, 0);

        // 3. Static catalogs must still exist
        final stdFoods = await (db.select(db.foodItems)
              ..where((f) => f.isCustom.equals(false)))
            .get();
        expect(stdFoods, isNotEmpty, reason: 'Standard food catalog must be retained');
        final stdExercises = await (db.select(db.exercises)
              ..where((f) => f.isCustom.equals(false)))
            .get();
        expect(stdExercises, isNotEmpty, reason: 'Standard exercise catalog must be retained');
        final nutrients = await db.select(db.nutritionNutrientDefinitions).get();
        expect(nutrients, isNotEmpty, reason: 'Nutrient registry catalog must be retained');
        final muscles = await db.select(db.muscles).get();
        expect(muscles, isNotEmpty, reason: 'Muscle anatomy catalog must be retained');

        // 4. SharedPreferences wiped & onboarding flag false
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('onboarding_completed'), isFalse);
        expect(prefs.getInt('water_goal'), isNull);
        expect(prefs.getString('health_last_sync_time'), isNull);

        // 5. Secure storage cleared
        expect(await secretStore.read(), isNull);
        expect(secretStore.clearCalls, 1);

        // 6. Local files wiped
        expect(await backupDir.exists(), isFalse);
        expect(await tempExport.exists(), isFalse);

        // 7. Remote services notified
        expect(cloudBackup.deleteAllCalls, 1);
        expect(account.deletionCalls, 1);
        expect(health.disconnectCalls, 1);

        // 8. Disclosures present
        expect(
          report.disclosures.any((d) => d.contains('Apple Health') || d.contains('Health Connect')),
          isTrue,
        );
        expect(
          report.disclosures.any((d) => d.contains('Static food and exercise reference catalogs')),
          isTrue,
        );
      },
    );

    test('FK-check is green post-wipe and foreign keys remain active', () async {
      final databases = registerTestDatabaseScope();
      final db = databases.create();

      await _populateExtensiveUserData(db);

      final service = DataErasureService(
        db: db,
        secretStore: _TestAutoBackupSecretStore(),
        cloudBackup: _TestCloudBackupCapability(),
        account: _TestAccountCapability(),
        healthService: _TestHealthService(),
        documentsDirectoryProvider: () async => tempDocDir,
        temporaryDirectoryProvider: () async => tempExportDir,
      );

      final report = await service.eraseAllData();
      expect(report.isSuccess, isTrue);

      // Explicit assertion on database PRAGMA foreign_key_check
      final violations = await db.customSelect('PRAGMA foreign_key_check;').get();
      expect(violations, isEmpty, reason: 'No dangling foreign key references may exist');

      // Explicit assertion that foreign_keys pragma is enabled (1)
      final fkStatus = await db.customSelect('PRAGMA foreign_keys;').getSingle();
      expect(fkStatus.data['foreign_keys'], 1);
    });

    test('idempotency: executing erasure back-to-back succeeds cleanly without errors', () async {
      final databases = registerTestDatabaseScope();
      final db = databases.create();

      final service = DataErasureService(
        db: db,
        secretStore: _TestAutoBackupSecretStore(),
        cloudBackup: _TestCloudBackupCapability(),
        account: _TestAccountCapability(),
        healthService: _TestHealthService(),
        documentsDirectoryProvider: () async => tempDocDir,
        temporaryDirectoryProvider: () async => tempExportDir,
      );

      // Run once on empty DB
      final report1 = await service.eraseAllData();
      expect(report1.isSuccess, isTrue);

      // Run a second time immediately
      final report2 = await service.eraseAllData();
      expect(report2.isSuccess, isTrue);
      expect(report2.failureReason, isNull);
    });

    test(
      'remote failure (offline) still completely erases local storage and notes failure in report',
      () async {
        final databases = registerTestDatabaseScope();
        final db = databases.create();

        await _populateExtensiveUserData(db);

        final secretStore = _TestAutoBackupSecretStore('device-secret-123');
        final failingCloud = _TestCloudBackupCapability(shouldThrow: true);
        final failingAccount = _TestAccountCapability(shouldThrow: true);
        final health = _TestHealthService();

        final service = DataErasureService(
          db: db,
          secretStore: secretStore,
          cloudBackup: failingCloud,
          account: failingAccount,
          healthService: health,
          documentsDirectoryProvider: () async => tempDocDir,
          temporaryDirectoryProvider: () async => tempExportDir,
        );

        final report = await service.eraseAllData();

        // Local wipe succeeds
        expect(report.isSuccess, isTrue);
        expect(report.cloudBackupsPurged, isFalse);
        expect(report.accountDeleted, isFalse);

        // Disclosures inform user about offline remote state
        expect(
          report.disclosures.any((d) => d.contains('Remote cloud backup snapshots could not be reached')),
          isTrue,
        );
        expect(
          report.disclosures.any((d) => d.contains('Remote account deletion could not be reached')),
          isTrue,
        );

        // Local secrets and data are still completely purged
        expect(await secretStore.read(), isNull);
        final remainingProfiles = await db.select(db.userProfiles).get();
        expect(remainingProfiles, isEmpty);
      },
    );

    test('resetIndiFitContainerUserState restores in-memory providers to initial defaults', () async {
      final databases = registerTestDatabaseScope();
      final db = databases.create();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          onboardingCompletedProvider.overrideWith((ref) => true),
        ],
      );

      // Seed container state
      expect(container.read(onboardingCompletedProvider), isTrue);
      container.read(todayNutritionRevisionProvider.notifier).state = 42;
      container.read(todayHydrationRevisionProvider.notifier).state = 10;
      expect(container.read(todayNutritionRevisionProvider), 42);
      expect(container.read(todayHydrationRevisionProvider), 10);

      // Perform state reset
      resetIndiFitContainerUserState(container);

      // Verify states reset
      expect(container.read(onboardingCompletedProvider), isFalse);
      expect(container.read(todayNutritionRevisionProvider), 0);
      expect(container.read(todayHydrationRevisionProvider), 0);
      expect(container.read(userProfileProvider).hasProfile, isFalse);

      await pumpEventQueue();
      container.dispose();
    });
  });
}

class _TestAutoBackupSecretStore implements AutoBackupSecretStore {
  String? _secret;
  int clearCalls = 0;

  _TestAutoBackupSecretStore([this._secret = 'test-secret']);

  @override
  Future<String?> read() async => _secret;

  @override
  Future<String> readOrCreate() async => _secret ??= 'new-secret';

  @override
  Future<void> clear() async {
    clearCalls++;
    _secret = null;
  }
}

class _TestCloudBackupCapability extends DisabledCloudBackupCapability {
  final bool shouldThrow;
  int deleteAllCalls = 0;

  _TestCloudBackupCapability({this.shouldThrow = false});

  @override
  Future<void> deleteAllRemoteSnapshots() async {
    deleteAllCalls++;
    if (shouldThrow) {
      throw const SocketException('Network unreachable');
    }
  }
}

class _TestAccountCapability extends NoOpAccountCapability {
  final bool shouldThrow;
  int deletionCalls = 0;

  _TestAccountCapability({this.shouldThrow = false});

  @override
  Future<void> requestAccountDeletion() async {
    deletionCalls++;
    if (shouldThrow) {
      throw Exception('Account service unreachable');
    }
  }
}

class _TestHealthService extends HealthService {
  int disconnectCalls = 0;

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }
}

Future<void> _populateExtensiveUserData(AppDatabase db) async {
  final now = DateTime.now().toUtc();

  // 1. User profile
  await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          name: const Value('Alex Runner'),
          age: const Value(28),
          height: const Value(178.0),
          weight: const Value(75.0),
          sex: const Value('male'),
          activityLevel: const Value('moderate'),
          goal: const Value('hypertrophy'),
          calorieGoal: const Value(2400),
          proteinGoal: const Value(160),
          carbsGoal: const Value(250),
          fatGoal: const Value(70),
          updatedAt: Value(now),
        ),
      );

  // 2. Body measurement
  await db.into(db.bodyMeasurements).insert(
        BodyMeasurementsCompanion.insert(
          weight: const Value(75.2),
          recordedAt: Value(now),
        ),
      );

  // 3. Hydration
  await db.into(db.dailyHydrations).insert(
        DailyHydrationsCompanion.insert(
          dateString: '2026-09-08',
          totalMl: 2500,
          goalMl: 3000,
          updatedAt: Value(now),
        ),
      );

  // 4. Custom food item
  final customFoodId = await db.into(db.foodItems).insert(
        FoodItemsCompanion.insert(
          name: 'Homemade Roti Special',
          calories: 120,
          proteinG: 4.0,
          carbsG: 22.0,
          fatG: 2.0,
          servingSize: 1.0,
          servingUnit: 'piece',
          category: 'roti',
          isCustom: const Value(true),
        ),
      );

  // 5. Custom exercise
  await db.into(db.exercises).insert(
        ExercisesCompanion.insert(
          name: 'Ring Muscle Up Special',
          muscleGroups: 'Back,Triceps',
          equipment: 'Bodyweight',
          difficulty: 'Advanced',
          formCues: 'Pull hard',
          commonMistakes: 'Kipping',
          isCustom: const Value(true),
        ),
      );

  // 6. Food log
  await db.into(db.foodLogs).insert(
        FoodLogsCompanion.insert(
          foodItemId: Value(customFoodId),
          name: 'Homemade Roti Special',
          calories: 240,
          proteinG: 8.0,
          carbsG: 44.0,
          fatG: 4.0,
          servingLogged: 2.0,
          servingUnit: 'piece',
          mealType: 'lunch',
          loggedAt: Value(now),
        ),
      );

  // 7. Workout routine
  await db.into(db.workoutRoutines).insert(
        WorkoutRoutinesCompanion.insert(
          name: 'Upper Hypertrophy A',
          goal: 'hypertrophy',
          createdAt: Value(now),
        ),
      );

  // 8. Workout session & sets
  final sessionId = await db.into(db.workoutSessions).insert(
        WorkoutSessionsCompanion.insert(
          name: 'Chest & Shoulders',
          totalVolume: 1200.0,
          durationSeconds: 3600,
          estimatedCalories: 0,
          completedAt: Value(now),
        ),
      );

  await db.into(db.workoutSets).insert(
        WorkoutSetsCompanion.insert(
          sessionId: sessionId,
          exerciseName: 'Ring Muscle Up Special',
          weight: 0.0,
          reps: 5,
          setNumber: 1,
        ),
      );

  // 9. Sync tables
  await db.into(db.outboxEntries).insert(
        OutboxEntriesCompanion.insert(
          operationId: 'op-123',
          idempotencyKey: 'idem-123',
          domain: 'workout',
          action: 'create',
          entityId: 'sess-1',
          payloadJson: '{"id":"sess-1"}',
          createdAtUtc: now,
          scheduledAtUtc: now,
          state: 'pending',
        ),
      );

  await db.into(db.tombstoneEntries).insert(
        TombstoneEntriesCompanion.insert(
          entityId: 'food-log-99',
          domain: 'food_log',
          hlcMillis: now.millisecondsSinceEpoch,
          hlcNodeId: 'node-1',
          deletedAtUtc: Value(now),
        ),
      );

  await db.into(db.cachedRemoteFoods).insert(
        CachedRemoteFoodsCompanion.insert(
          candidateId: 'food-cand-1',
          candidateJson: '{"name":"Apple"}',
          fetchedAtUtc: Value(now),
        ),
      );
}
