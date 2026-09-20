import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';

import 'support/indifit_test_harness.dart';

void main() {
  initializeIndiFitTestHarness();

  test('fresh schema v21 retains its complete SQLite contract', () async {
    final database = registerTestDatabaseScope().create();
    await database.customSelect('SELECT 1').get();

    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    final foreignKeys = await database
        .customSelect('PRAGMA foreign_keys')
        .getSingle();
    final objects = await database.customSelect('''
      SELECT type, name, tbl_name, sql
      FROM sqlite_master
      WHERE type IN ('table', 'index', 'trigger')
        AND name NOT LIKE 'sqlite_%'
      ORDER BY type, name
    ''').get();

    final contract = objects
        .map(
          (row) => <String, Object?>{
            'type': row.read<String>('type'),
            'name': row.read<String>('name'),
            'table': row.read<String>('tbl_name'),
            'sql': _normalizeSql(row.readNullable<String>('sql')),
          },
        )
        .toList(growable: false);
    final byType = <String, List<String>>{};
    for (final object in contract) {
      (byType[object['type']! as String] ??= <String>[]).add(
        object['name']! as String,
      );
    }
    final digest = sha256.convert(utf8.encode(jsonEncode(contract))).toString();

    expect(version.read<int>('user_version'), 22);
    expect(foreignKeys.read<int>('foreign_keys'), 1);
    expect(
      byType.map((key, value) => MapEntry(key, value.length)),
      <String, int>{'index': 85, 'table': 91, 'trigger': 73},
      reason: 'Names by type: ${jsonEncode(byType)}',
    );
    expect(
      digest,
      'bafc6f7bc1cc5611bb4dc145dd1f4cef572bdb09fe338d28baf41474f2428f67',
      reason: 'Names by type: ${jsonEncode(byType)}',
    );
  });

  test('real v19 file upgrades to v21 without changing existing state', () async {
    final directory = await Directory.systemTemp.createTemp(
      'indifit-c0b-v19-to-v21-',
    );
    final file = File('${directory.path}/v19.db');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final legacy = AppDatabase.executor(NativeDatabase(file));
    await legacy.customSelect('SELECT 1').get();
    await legacy.customStatement('''
      UPDATE training_plan_settings
      SET updated_at_utc = 1722470400
      WHERE id = 1
    ''');
    await legacy.customStatement('PRAGMA foreign_keys = OFF');
    await legacy.customStatement('''
      CREATE TABLE training_plan_settings_v19 (
        id INTEGER NOT NULL DEFAULT 1,
        active_program_version_id TEXT REFERENCES program_versions(id),
        active_since_local_date TEXT,
        active_since_timezone_id TEXT,
        default_equipment_profile_id TEXT REFERENCES equipment_profiles(id),
        updated_at_utc INTEGER NOT NULL,
        PRIMARY KEY (id),
        CHECK (id = 1)
      )
    ''');
    await legacy.customStatement('''
      INSERT INTO training_plan_settings_v19 (
        id,
        active_program_version_id,
        active_since_local_date,
        active_since_timezone_id,
        default_equipment_profile_id,
        updated_at_utc
      )
      SELECT
        id,
        active_program_version_id,
        active_since_local_date,
        active_since_timezone_id,
        default_equipment_profile_id,
        updated_at_utc
      FROM training_plan_settings
    ''');
    await legacy.customStatement('DROP TABLE training_plan_settings');
    await legacy.customStatement(
      'ALTER TABLE training_plan_settings_v19 RENAME TO training_plan_settings',
    );
    await legacy.customStatement('PRAGMA foreign_keys = ON');
    await legacy.customStatement('PRAGMA user_version = 19');
    await legacy.close();

    final migrated = AppDatabase.executor(NativeDatabase(file));
    addTearDown(migrated.close);
    final version = await migrated
        .customSelect('PRAGMA user_version')
        .getSingle();
    final columns = await migrated
        .customSelect("PRAGMA table_info('training_plan_settings')")
        .get();
    final settings = await migrated
        .select(migrated.trainingPlanSettings)
        .getSingle();

    expect(version.read<int>('user_version'), 22);
    expect(
      columns.map((row) => row.read<String>('name')).toSet(),
      containsAll(const <String>{
        'last_ended_program_version_id',
        'last_ended_outcome',
        'last_ended_at_utc',
        'last_ended_command_id',
      }),
    );
    expect(settings.updatedAtUtc.millisecondsSinceEpoch, 1722470400 * 1000);
    expect(settings.lastEndedProgramVersionId, isNull);
    expect(settings.lastEndedOutcome, isNull);
    expect(settings.lastEndedAtUtc, isNull);
    expect(settings.lastEndedCommandId, isNull);
  });
}

String? _normalizeSql(String? sql) =>
    sql?.replaceAll(RegExp(r'\s+'), ' ').trim();
