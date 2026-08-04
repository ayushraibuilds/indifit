import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('legacy backup timestamp policy', () {
    test('offset-less values are interpreted as UTC', () {
      final parsed = parseLegacyBackupTimestamp('2026-01-15T14:00:00.000');

      expect(parsed, DateTime.utc(2026, 1, 15, 14));
      expect(parsed.isUtc, isTrue);
    });

    test('explicit Z values remain the same UTC instant', () {
      final parsed = parseLegacyBackupTimestamp('2026-01-15T14:00:00.000Z');

      expect(parsed, DateTime.utc(2026, 1, 15, 14));
    });

    test('numeric offsets are converted to UTC', () {
      final parsed = parseLegacyBackupTimestamp(
        '2026-01-15T14:00:00.000+05:30',
      );

      expect(parsed, DateTime.utc(2026, 1, 15, 8, 30));
    });
  });

  test('new backup exports serialize timestamps with explicit UTC', () async {
    final database = AppDatabase.memory();
    addTearDown(database.close);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final backup = await BackupData.createFromDatabase(database, preferences);
    final json = backup.toJson();

    expect(backup.timestamp, endsWith('Z'));
    expect(json['timestamp'], endsWith('Z'));
  });

  test('legacy restore followed by export is deterministic', () {
    final legacy = <String, dynamic>{
      'version': 5,
      'schema_version': 13,
      'timestamp': '2026-01-15T14:00:00.000',
      'user_preferences': <String, dynamic>{},
    };

    final firstExport = BackupData.fromJson(legacy).toJson();
    final secondExport = BackupData.fromJson(firstExport).toJson();

    expect(jsonEncode(secondExport), jsonEncode(firstExport));
    expect(firstExport['timestamp'], '2026-01-15T14:00:00.000Z');
  });
}
