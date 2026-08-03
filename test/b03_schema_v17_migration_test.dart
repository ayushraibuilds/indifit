import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/b03_migration_backup_harness.dart';
import 'fixtures/v15_db_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('indifit-b03-v16-');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('B03-02 real schema-v16 fixture baseline', () {
    test(
      'stage-aware migration failures rollback and retry at every boundary',
      () async {
        const stages = [
          B03FailureStage.migrationValidation,
          B03FailureStage.migrationDdlAndDataMutation,
          B03FailureStage.migrationFinalTransaction,
        ];

        for (final stage in stages) {
          final source = await V15DbFixtures.createSourceDatabase(
            tempDir,
            'v15-${stage.name}.db',
          );
          final harness = B03StageAwareFailureHarness(stage);
          final failing = harness.openMigrating(source);
          try {
            await failing.customSelect('SELECT 1').get();
            fail('Expected migration failure at $stage.');
          } on B03InjectedFailure catch (error) {
            expect(error.stage, stage);
          }
          await failing.close();

          expect(harness.injected, isTrue);
          expect(harness.reachedStages, contains(stage));
          expect(
            V15DbFixtures.readUserVersion(source),
            15,
            reason: 'failed $stage must leave the original v15 file readable',
          );

          harness.disable();
          final retry = harness.openMigrating(source);
          try {
            await retry.customSelect('SELECT 1').get();
            expect(V15DbFixtures.readUserVersion(source), 16);
            expect(
              await retry.customSelect('PRAGMA foreign_key_check').get(),
              isEmpty,
            );
          } finally {
            await retry.close();
          }
        }
      },
    );

    test(
      'opens an immutable on-disk v16 fixture with golden identity',
      () async {
        final file = await B03V16Fixture.copyTo(tempDir);

        expect(B03V16Fixture.readUserVersion(file), 16);
        expect(
          B03V16Fixture.readUserVersion(file),
          B03V16Fixture.schemaVersion,
        );
        expect(B03V16Fixture.fixtureId, 'b03-v16-legacy-baseline-01');
        expect(B03V16Fixture.checksum, isNot('__GENERATED_DB_CHECKSUM__'));
        expect(sha256File(file), B03V16Fixture.checksum);

        final db = B03V16Fixture.open(file);
        try {
          expect(db.schemaVersion, 16);
          expect(
            await db.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
          final customFood = await (db.select(
            db.foodItems,
          )..where((row) => row.id.equals(574))).getSingle();
          expect(customFood.isCustom, isTrue);
          expect(customFood.name, 'Fixture Custom Lentil Bowl');
          expect(customFood.fiberG, isNull);
          final customExercise =
              await (db.select(db.exercises)..where(
                    (row) => row.stableId.equals('fixture-custom-exercise-v16'),
                  ))
                  .getSingle();
          expect(customExercise.id, 9002);
          expect(customExercise.isCustom, isTrue);

          final logs = await db.select(db.foodLogs).get();
          expect(logs.map((row) => row.id), containsAll([7001, 7002, 7003]));
          expect(
            logs.map((row) => row.mealType),
            containsAll(['breakfast', 'lunch', 'dinner']),
          );
          expect(logs.singleWhere((row) => row.id == 7001).servingLogged, 1);
          expect(
            logs.singleWhere((row) => row.id == 7001).loggedAt.toUtc(),
            B03V16Fixture.timestamp,
          );
          expect(logs.singleWhere((row) => row.id == 7003).foodItemId, isNull);
          expect(logs.singleWhere((row) => row.id == 7001).proteinG, 21.5);

          final sessions = await db.select(db.workoutSessions).get();
          expect(sessions.map((row) => row.id), containsAll([4101, 4102]));
          expect(
            sessions.singleWhere((row) => row.id == 4102).activityType,
            'running',
          );
          expect(await db.select(db.cardioSessionDetails).get(), hasLength(1));
          final provenance = await db.select(db.healthProvenances).getSingle();
          expect(provenance.id, 4301);
          expect(provenance.provider, 'health_connect');

          final tables = await db.customSelect('''
          SELECT name FROM sqlite_master WHERE type = 'table'
        ''').get();
          final tableNames = tables.map((row) => row.data['name'] as String);
          expect(
            tableNames.where(
              (name) =>
                  name.startsWith('nutrition_') ||
                  name.contains('food_identity') ||
                  name.contains('recipe'),
            ),
            isEmpty,
          );
        } finally {
          await db.close();
        }
      },
    );

    test(
      'logical snapshot and file checksum are stable across opens',
      () async {
        final firstFile = await B03V16Fixture.copyTo(
          tempDir,
          filename: 'first.db',
        );
        final secondFile = await B03V16Fixture.copyTo(
          tempDir,
          filename: 'second.db',
        );
        final first = B03V16Fixture.open(firstFile);
        final firstSnapshot = await B03LogicalSnapshot.capture(first);
        await first.close();
        final second = B03V16Fixture.open(secondFile);
        final secondSnapshot = await B03LogicalSnapshot.capture(second);
        await second.close();

        expect(firstSnapshot.canonicalJson, secondSnapshot.canonicalJson);
        expect(firstSnapshot.checksum, secondSnapshot.checksum);
        expect(
          firstSnapshot.tables.keys,
          containsAll(B03LogicalSnapshot.v16TableNames),
        );
        expect(
          firstSnapshot.tables,
          hasLength(B03LogicalSnapshot.v16TableNames.length),
        );
        expect(firstSnapshot.logicalChecksum, secondSnapshot.logicalChecksum);
        final reordered = B03LogicalSnapshot({
          for (final entry in firstSnapshot.tables.entries)
            entry.key: entry.value.reversed.toList(),
        });
        expect(reordered.logicalChecksum, firstSnapshot.logicalChecksum);
      },
    );

    test(
      'B02 migration failure injector leaves the original file readable',
      () async {
        final source = await V15DbFixtures.createSourceDatabase(
          tempDir,
          'v15-source.db',
        );
        final failing = V15DbFixtures.openCurrentDatabase(
          source,
          v16MigrationFailureInjector: () async {
            throw StateError('B03 migration failure injection');
          },
        );
        await expectLater(
          failing.customSelect('SELECT 1').get(),
          throwsA(isA<StateError>()),
        );
        await failing.close();
        expect(V15DbFixtures.readUserVersion(source), 15);

        final retry = V15DbFixtures.openCurrentDatabase(source);
        try {
          await retry.customSelect('SELECT 1').get();
          expect(V15DbFixtures.readUserVersion(source), 16);
          expect(
            await retry.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
        } finally {
          await retry.close();
        }
      },
    );
  });
}

String sha256File(File file) =>
    sha256.convert(file.readAsBytesSync()).toString();
