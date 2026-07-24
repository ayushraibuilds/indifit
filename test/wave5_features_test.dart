import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/health_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  group('Wave 5 — Schema v10 & UserSettings Tests', () {
    test('AppDatabase initializes with schema version 11 or higher', () {
      expect(db.schemaVersion, greaterThanOrEqualTo(11));
    });

    test('UserSettings table supports inserting and reading key-value settings', () async {
      await db.into(db.userSettings).insert(
        UserSettingsCompanion.insert(
          key: 'test_setting_key',
          value: 'test_setting_value',
        ),
      );

      final settings = await db.select(db.userSettings).get();
      expect(settings.length, equals(1));
      expect(settings.first.key, equals('test_setting_key'));
      expect(settings.first.value, equals('test_setting_value'));
    });
  });

  group('Wave 5 — HealthService Metadata Tests', () {
    test('setLastSyncTime persists ISO string in SharedPreferences', () async {
      final service = HealthService();
      final now = DateTime(2026, 7, 21, 15, 30, 0);

      await service.setLastSyncTime(now);
      final stored = await service.getLastSyncTime();

      expect(stored, isNotNull);
      expect(stored, equals(now.toIso8601String()));
    });
  });
}
