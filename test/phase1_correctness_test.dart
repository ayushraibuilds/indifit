import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/user_profile_provider.dart';
import 'package:indifit/core/services/auto_backup_secret_store.dart';
import 'package:indifit/core/services/auto_backup_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 1 Correctness Unit Tests', () {
    test(
      'AutoBackupService writes and restores encrypted recovery data',
      () async {
        final db = AppDatabase.memory();
        final tempDirectory = await Directory.systemTemp.createTemp(
          'indifit-auto-backup-test-',
        );
        addTearDown(() => tempDirectory.delete(recursive: true));

        // Seed food log and workout session
        await db
            .into(db.foodLogs)
            .insert(
              FoodLogsCompanion.insert(
                name: 'Oats Upma',
                calories: 350,
                proteinG: 12.0,
                carbsG: 50.0,
                fatG: 10.0,
                servingLogged: 1.0,
                servingUnit: 'bowl',
                mealType: 'breakfast',
                uuid: const Value('test-food-uuid-123'),
                mealGroupId: const Value('group-1'),
              ),
            );

        final secretStore = _FakeAutoBackupSecretStore('device-secret');
        final backupService = AutoBackupService(
          db,
          secretStore: secretStore,
          documentsDirectoryProvider: () async => tempDirectory,
        );
        await backupService.runAutoBackup();

        final backupFile = File(
          '${tempDirectory.path}/backups/indifit_auto_backup_1.json',
        );
        expect(await backupFile.exists(), isTrue);
        final envelope = jsonDecode(await backupFile.readAsString()) as Map;
        expect(envelope['format_identifier'], 'INDIFIT_BACKUP_ENVELOPE');
        expect(envelope['is_encrypted'], isTrue);

        await backupService.runAutoBackup();
        expect(
          await File(
            '${tempDirectory.path}/backups/indifit_auto_backup_2.json',
          ).exists(),
          isFalse,
          reason: 'unchanged launches must not churn the recovery rotation',
        );

        final restored = await AutoBackupService.getLatestSnapshotContent(
          secretStore: secretStore,
          documentsDirectoryProvider: () async => tempDirectory,
        );
        expect(restored, isNotNull);
        expect(jsonDecode(restored!)['version'], 10);

        final logs = await db.select(db.foodLogs).get();
        expect(logs.length, 1);
        expect(logs.first.uuid, 'test-food-uuid-123');
        expect(logs.first.mealGroupId, 'group-1');

        await db.close();
      },
    );

    test(
      'FoodRepository.logFoodEntry logs against specified loggedAt date',
      () async {
        final db = AppDatabase.memory();
        final repo = FoodRepository(db);

        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        await repo.logFoodEntry(
          name: 'Poha',
          calories: 250,
          proteinG: 6.0,
          carbsG: 45.0,
          fatG: 5.0,
          servingLogged: 1.0,
          servingUnit: 'plate',
          mealType: 'breakfast',
          loggedAt: yesterday,
        );

        final logs = await db.select(db.foodLogs).get();
        expect(logs.length, 1);
        expect(logs.first.name, 'Poha');
        expect(logs.first.loggedAt.year, yesterday.year);
        expect(logs.first.loggedAt.day, yesterday.day);

        await db.close();
      },
    );

    test('UserProfileNotifier updates custom nutrition goals', () async {
      final db = AppDatabase.memory();
      final notifier = UserProfileNotifier(db);
      await notifier.loadProfile();

      await notifier.updateGoals(
        calorieGoal: 2400,
        proteinGoal: 150.0,
        carbsGoal: 260.0,
        fatGoal: 70.0,
      );

      expect(notifier.state.calorieGoal, 2400);
      expect(notifier.state.proteinGoal, 150.0);
      expect(notifier.state.carbsGoal, 260.0);
      expect(notifier.state.fatGoal, 70.0);

      await db.close();
    });

    test('Timezone database loads valid locations', () {
      final kolkata = tz.getLocation('Asia/Kolkata');
      expect(kolkata.name, 'Asia/Kolkata');

      final utc = tz.getLocation('UTC');
      expect(utc.name, 'UTC');
    });
  });
}

class _FakeAutoBackupSecretStore implements AutoBackupSecretStore {
  final String value;

  const _FakeAutoBackupSecretStore(this.value);

  @override
  Future<String?> read() async => value;

  @override
  Future<String> readOrCreate() async => value;

  @override
  Future<void> clear() async {}
}
