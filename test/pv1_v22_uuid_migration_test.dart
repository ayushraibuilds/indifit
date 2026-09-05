import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';

import 'support/indifit_test_harness.dart';

/// Stream B / Agent A (schema v22): opaque sync-identity UUID on
/// body_measurements.
///
/// What each test proves:
/// - fresh v22 exposes the uuid column: a brand-new database is created at
///   user_version 22 with a nullable `uuid` column on body_measurements, and
///   inserts that omit it store NULL (identity is assigned by migration
///   backfill / future writers, never coerced from the autoincrement id).
/// - genuine v21 -> v22 upgrade backfills: an on-disk file built at v22,
///   downgraded to a true v21 shape (uuid column dropped, user_version
///   stamped 21), upgrades through the real onUpgrade path preserving every
///   row's id/weight/recordedAt while assigning fresh non-null UNIQUE uuids.
/// - backfill never overwrites: reopening the migrated database leaves every
///   uuid byte-identical (the v22 step is a no-op once the column is filled).
final _uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  initializeIndiFitTestHarness();

  group('PV1-V22: body_measurements uuid sync identity', () {
    test('fresh v22 exposes a nullable uuid column', () async {
      final db = registerTestDatabaseScope().create();

      final version = await db
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 22);

      final columns = await db
          .customSelect("PRAGMA table_info('body_measurements')")
          .get();
      final uuid = columns.where(
        (row) => row.read<String>('name') == 'uuid',
      );
      expect(uuid, hasLength(1));
      // Nullable: existing/future rows without an identity remain valid.
      expect(uuid.single.read<int>('notnull'), 0);

      final id = await db
          .into(db.bodyMeasurements)
          .insert(
            BodyMeasurementsCompanion.insert(
              weight: const Value(70.5),
              recordedAt: Value(DateTime.utc(2026, 1, 2, 3, 4, 5)),
            ),
          );
      final stored = await (db.select(
        db.bodyMeasurements,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(stored.uuid, isNull);
      expect(stored.weight, 70.5);
    });

    test('v21 file upgrades preserving rows with backfilled unique uuids',
        () async {
      final directory = await Directory.systemTemp.createTemp(
        'indifit-v21-to-v22-',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final file = File('${directory.path}/v21.db');

      // Build a genuine v21 on-disk file: fresh create, marker weight rows
      // with NULL uuid, then drop the v22 column and stamp version 21.
      final before = <({int id, double? weight, DateTime recordedAt})>[];
      final legacy = AppDatabase.executor(NativeDatabase(file));
      try {
        await legacy.customSelect('SELECT 1').get();
        for (final (weight, day) in [(70.5, 2), (71.0, 3), (null, 4)]) {
          final id = await legacy
              .into(legacy.bodyMeasurements)
              .insert(
                BodyMeasurementsCompanion.insert(
                  weight: Value(weight),
                  recordedAt: Value(DateTime.utc(2026, 1, day, 3, 4, 5)),
                ),
              );
          final row = await (legacy.select(
            legacy.bodyMeasurements,
          )..where((t) => t.id.equals(id))).getSingle();
          expect(row.uuid, isNull);
          before.add((
            id: row.id,
            weight: row.weight,
            recordedAt: row.recordedAt,
          ));
        }
        await legacy.customStatement(
          'ALTER TABLE body_measurements DROP COLUMN uuid',
        );
        final downgraded = await legacy
            .customSelect("PRAGMA table_info('body_measurements')")
            .get();
        expect(
          downgraded.map((row) => row.read<String>('name')),
          isNot(contains('uuid')),
        );
        await legacy.customStatement('PRAGMA user_version = 21');
      } finally {
        await legacy.close();
      }

      // Reopen: the real onUpgrade path must run the v22 step.
      final migrated = AppDatabase.executor(NativeDatabase(file));
      addTearDown(migrated.close);
      await migrated.customSelect('SELECT 1').get();

      final version = await migrated
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 22);

      final rows = await (migrated.select(
        migrated.bodyMeasurements,
      )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
      expect(rows, hasLength(3));

      // Existing identity-bearing state is untouched; every row gained a
      // fresh UUID v4 and no two rows share one.
      final uuids = <String>{};
      for (var i = 0; i < rows.length; i++) {
        expect(rows[i].id, before[i].id);
        expect(rows[i].weight, before[i].weight);
        expect(
          rows[i].recordedAt.toUtc(),
          before[i].recordedAt.toUtc(),
        );
        expect(rows[i].uuid, isNotNull);
        expect(rows[i].uuid!, matches(_uuidV4Pattern));
        expect(uuids.add(rows[i].uuid!), isTrue, reason: 'duplicate uuid');
      }
    });

    test('reopening a migrated database never rewrites uuids', () async {
      final directory = await Directory.systemTemp.createTemp(
        'indifit-v22-idempotent-',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final file = File('${directory.path}/v21.db');

      final seed = AppDatabase.executor(NativeDatabase(file));
      try {
        await seed.customSelect('SELECT 1').get();
        await seed
            .into(seed.bodyMeasurements)
            .insert(
              BodyMeasurementsCompanion.insert(
                weight: const Value(70.5),
                recordedAt: Value(DateTime.utc(2026, 1, 2, 3, 4, 5)),
              ),
            );
        await seed.customStatement(
          'ALTER TABLE body_measurements DROP COLUMN uuid',
        );
        await seed.customStatement('PRAGMA user_version = 21');
      } finally {
        await seed.close();
      }

      final first = AppDatabase.executor(NativeDatabase(file));
      String? migratedUuid;
      try {
        await first.customSelect('SELECT 1').get();
        final rows = await first.select(first.bodyMeasurements).get();
        expect(rows, hasLength(1));
        expect(rows.single.uuid, isNotNull);
        migratedUuid = rows.single.uuid;
      } finally {
        await first.close();
      }

      // Second open: user_version is already 22, so onUpgrade is a no-op and
      // the assigned identity must be byte-identical.
      final second = AppDatabase.executor(NativeDatabase(file));
      addTearDown(second.close);
      await second.customSelect('SELECT 1').get();
      final reopened = await second.select(second.bodyMeasurements).get();
      expect(reopened, hasLength(1));
      expect(reopened.single.uuid, migratedUuid);

      final version = await second
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 22);
    });
  });
}
