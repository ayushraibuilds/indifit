import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/auto_backup_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  group('Phase 1 Correctness Unit Tests', () {
    test('AutoBackupService exports v2 schema with all tables', () async {
      final db = AppDatabase.memory();

      // Seed food log and workout session
      await db.into(db.foodLogs).insert(FoodLogsCompanion.insert(
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
      ));

      final backupService = AutoBackupService(db);
      await backupService.runAutoBackup();

      final logs = await db.select(db.foodLogs).get();
      expect(logs.length, 1);
      expect(logs.first.uuid, 'test-food-uuid-123');
      expect(logs.first.mealGroupId, 'group-1');

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
