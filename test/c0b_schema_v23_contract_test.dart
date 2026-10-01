import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';

import 'support/schema_version.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Schema v23 Contract & Migration (A2)', () {
    test(
      'genuine v22 database upgrades to v23, creates food_search_cache, and preserves existing rows',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'indifit-schema-v23-contract-',
        );
        final file = File('${directory.path}/v22.db');
        addTearDown(() async {
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        });

        // 1. Build a genuine v22 database state:
        // Open with AppDatabase, seed initial data, drop food_search_cache and stamp user_version = 22.
        final legacy = AppDatabase.executor(NativeDatabase(file));
        try {
          await legacy.customSelect('SELECT 1').get();

          // Insert test rows across multiple prior tables
          await legacy.into(legacy.foodLogs).insert(
            FoodLogsCompanion.insert(
              id: const Value(9001),
              name: 'Apple',
              calories: 95,
              proteinG: 0.5,
              carbsG: 25.0,
              fatG: 0.3,
              servingLogged: 1.0,
              servingUnit: 'medium',
              mealType: 'snack',
              loggedAt: Value(DateTime.utc(2026, 10, 1, 10)),
            ),
          );

          await legacy.into(legacy.bodyMeasurements).insert(
            BodyMeasurementsCompanion.insert(
              id: const Value(9001),
              weight: const Value(75.5),
              recordedAt: Value(DateTime.utc(2026, 10, 1, 8)),
            ),
          );

          // Drop food_search_cache to simulate authentic v22 state before v23 migration
          await legacy.customStatement('DROP TABLE IF EXISTS food_search_cache');
          await legacy.customStatement('PRAGMA user_version = 22');

          // Verify v22 precondition
          final v22Version =
              await legacy.customSelect('PRAGMA user_version').getSingle();
          expect(v22Version.read<int>('user_version'), 22);

          final v22Tables = await legacy
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'food_search_cache'",
              )
              .get();
          expect(v22Tables, isEmpty);
        } finally {
          await legacy.close();
        }

        // 2. Open with current AppDatabase (triggers onUpgrade from 22 to 23)
        final migrated = AppDatabase.executor(NativeDatabase(file));
        try {
          await migrated.customSelect('SELECT 1').get();

          // Assert user_version reached current schema version (23)
          final v23Version =
              await migrated.customSelect('PRAGMA user_version').getSingle();
          expect(v23Version.read<int>('user_version'), kCurrentSchemaVersion);

          // Assert food_search_cache exists
          final cacheTables = await migrated
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'food_search_cache'",
              )
              .get();
          expect(cacheTables, hasLength(1));

          // Assert expected columns on food_search_cache
          final tableInfo = await migrated
              .customSelect("PRAGMA table_info('food_search_cache')")
              .get();
          final columnNames =
              tableInfo.map((row) => row.read<String>('name')).toSet();
          expect(
            columnNames,
            containsAll(const [
              'query_hash',
              'query_text',
              'response_json',
              'cached_at',
              'ttl_seconds',
            ]),
          );

          // Assert primary key is query_hash
          final pkCol = tableInfo.firstWhere(
            (row) => row.read<String>('name') == 'query_hash',
          );
          expect(pkCol.read<int>('pk'), 1);

          // Assert row counts of all prior tables are unchanged
          final foodLogRow = await migrated
              .customSelect('SELECT COUNT(*) as cnt FROM food_logs WHERE id = 9001')
              .getSingle();
          expect(foodLogRow.read<int>('cnt'), 1);

          final weightRow = await migrated
              .customSelect(
                'SELECT COUNT(*) as cnt FROM body_measurements WHERE id = 9001',
              )
              .getSingle();
          expect(weightRow.read<int>('cnt'), 1);

          // Assert food_search_cache is functional: insert and retrieve
          await migrated.customStatement('''
            INSERT INTO food_search_cache (
              query_hash, query_text, response_json, cached_at, ttl_seconds
            ) VALUES (
              'hash123', 'roti', '{"items":[]}', 1727770000, 604800
            )
          ''');

          final cachedRow = await migrated
              .customSelect(
                "SELECT * FROM food_search_cache WHERE query_hash = 'hash123'",
              )
              .getSingle();
          expect(cachedRow.read<String>('query_text'), 'roti');
          expect(cachedRow.read<String>('response_json'), '{"items":[]}');

          // Foreign keys check
          final fkCheck =
              await migrated.customSelect('PRAGMA foreign_key_check').get();
          expect(fkCheck, isEmpty);
        } finally {
          await migrated.close();
        }

        // 3. Reopening preserves data and does not re-migrate
        final reopened = AppDatabase.executor(NativeDatabase(file));
        try {
          await reopened.customSelect('SELECT 1').get();
          final reopenedVersion =
              await reopened.customSelect('PRAGMA user_version').getSingle();
          expect(reopenedVersion.read<int>('user_version'), kCurrentSchemaVersion);

          final cachedRow = await reopened
              .customSelect(
                "SELECT * FROM food_search_cache WHERE query_hash = 'hash123'",
              )
              .getSingle();
          expect(cachedRow.read<String>('query_text'), 'roti');

          final reopenedFoodLog = await reopened
              .customSelect('SELECT COUNT(*) as cnt FROM food_logs WHERE id = 9001')
              .getSingle();
          expect(reopenedFoodLog.read<int>('cnt'), 1);

          final reopenedWeight = await reopened
              .customSelect(
                'SELECT COUNT(*) as cnt FROM body_measurements WHERE id = 9001',
              )
              .getSingle();
          expect(reopenedWeight.read<int>('cnt'), 1);
        } finally {
          await reopened.close();
        }
      },
    );
  });
}
