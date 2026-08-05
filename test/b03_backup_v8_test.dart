import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/b03_migration_backup_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('indifit-b03-v7-');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('B03-02 real Backup-v7 fixture baseline', () {
    test(
      'stage-aware restore failures rollback and retry at every boundary',
      () async {
        const stages = [
          B03FailureStage.backupRelationshipPrevalidation,
          B03FailureStage.backupDatabaseMutation,
          B03FailureStage.preferenceWrite,
          B03FailureStage.preferenceRestore,
          B03FailureStage.restoreFinalTransaction,
        ];
        final fixture = B03BackupV7Fixture.load();

        for (final stage in stages) {
          final target = AppDatabase.memory();
          addTearDown(target.close);
          SharedPreferences.setMockInitialValues({
            'water_logged': 99,
            'user_streak_count': 3,
            'pref_remind_workout': false,
            'prefQuietHoursEnabled': true,
          });
          final prefs = await SharedPreferences.getInstance();
          final beforePreferences =
              await B03RestoreFailureHarness.preferenceSnapshot(
                prefs,
                fixture.userPreferences.keys,
              );
          final before = await B03LogicalSnapshot.capture(target);
          final harness = B03StageAwareFailureHarness(stage);

          try {
            await harness.restore(fixture, target, prefs);
            fail('Expected restore failure at $stage.');
          } on B03InjectedFailure catch (error) {
            expect(error.stage, stage);
          }
          final afterFailure = await B03LogicalSnapshot.capture(target);
          before.assertLogicallyEquals(afterFailure);
          expect(harness.injected, isTrue);
          expect(harness.reachedStages, contains(stage));
          expect(
            await B03RestoreFailureHarness.preferenceSnapshot(
              prefs,
              fixture.userPreferences.keys,
            ),
            beforePreferences,
          );
          expect(
            await target.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );

          harness.disable();
          await harness.restore(fixture, target, prefs);
          expect(await target.select(target.foodLogs).get(), hasLength(3));
          for (final entry in fixture.userPreferences.entries) {
            expect(prefs.get(entry.key), entry.value);
          }
          expect(
            await target.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
        }
      },
    );

    test('validates the immutable v7 fixture without B03-only sections', () {
      final backup = B03BackupV7Fixture.load();
      final file = File(B03BackupV7Fixture.fixturePath);
      final rawPayload = jsonDecode(file.readAsStringSync()) as Map;

      expect(backup.version, 7);
      expect(backup.schemaVersion, 16);
      expect(B03BackupV7Fixture.fixtureId, 'b03-backup-v7-legacy-baseline-01');
      expect(
        B03BackupV7Fixture.checksum,
        isNot('__GENERATED_BACKUP_CHECKSUM__'),
      );
      expect(sha256Text(file.readAsStringSync()), B03BackupV7Fixture.checksum);
      expect(backup.customFoodItems, hasLength(1));
      expect(backup.foodLogs, hasLength(3));
      expect(backup.mealTemplates, hasLength(1));
      expect(backup.customExercises, hasLength(1));
      expect(backup.workoutSessions, hasLength(2));
      expect(backup.healthProvenances, hasLength(1));
      expect(backup.userPreferences['water_logged'], 4);
      expect(rawPayload['fixture_unknown_optional'], isA<Map>());

      final payload = backup.toJson();
      expect(
        payload.keys.where((key) => key.startsWith('nutrition_')),
        isEmpty,
      );
      expect(payload.keys.where((key) => key.contains('recipe')), isEmpty);
    });

    test(
      'restores food logs, custom identity, B02 data, and preferences',
      () async {
        final target = AppDatabase.memory();
        addTearDown(target.close);
        final fixture = B03BackupV7Fixture.load();

        await fixture.restoreToDatabase(target);

        final customFoods = (await target.select(target.foodItems).get())
            .where((row) => row.isCustom)
            .toList();
        expect(customFoods, hasLength(1));
        expect(customFoods.single.name, 'Fixture Custom Lentil Bowl');
        expect(customFoods.single.id, greaterThan(0));

        final logs = await target.select(target.foodLogs).get();
        expect(logs, hasLength(3));
        expect(
          logs.map((row) => row.mealType),
          containsAll(['breakfast', 'lunch', 'dinner']),
        );
        expect(
          logs
              .singleWhere((row) => row.uuid == 'fixture-food-log-custom-7001')
              .proteinG,
          21.5,
        );
        expect(
          logs
              .singleWhere(
                (row) => row.uuid == 'fixture-food-log-imported-7003',
              )
              .foodItemId,
          isNull,
        );
        expect(
          logs
              .singleWhere((row) => row.uuid == 'fixture-food-log-custom-7001')
              .foodItemId,
          customFoods.single.id,
        );

        expect(await target.select(target.workoutSessions).get(), hasLength(2));
        expect(await target.select(target.workoutSets).get(), hasLength(1));
        expect(
          await target.select(target.cardioSessionDetails).get(),
          hasLength(1),
        );
        expect(
          await target.select(target.healthProvenances).get(),
          hasLength(1),
        );
        expect(await target.select(target.mealTemplates).get(), hasLength(1));
        expect(
          await target.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        final fixtureFile = await B03V16Fixture.copyTo(
          tempDir,
          filename: 'v16-logical-golden.db',
        );
        final source = B03V16Fixture.open(fixtureFile);
        addTearDown(source.close);
        final golden = await B03LogicalSnapshot.capture(source);
        final restored = await B03LogicalSnapshot.capture(target);
        golden.assertLogicallyEquals(restored);
        expect(source.schemaVersion, 16);
      },
    );

    test('complete Backup-v7 graph restores with semantic equality', () async {
      final fixture = B03BackupV7Fixture.loadComplete();
      final fixtureFile = File(B03BackupV7Fixture.completeFixturePath);
      expect(
        sha256Text(fixtureFile.readAsStringSync()),
        B03BackupV7Fixture.completeChecksum,
      );
      expect(fixture.version, 7);
      expect(fixture.schemaVersion, 16);
      expect(fixture.programs, isNotEmpty);
      expect(fixture.scheduledSessionOccurrences, isNotEmpty);
      expect(fixture.exerciseGroups, isNotEmpty);
      expect(fixture.performedSets, isNotEmpty);
      expect(fixture.cardioIntervals, isNotEmpty);
      expect(fixture.mobilitySessionDetails, isNotEmpty);
      expect(fixture.exerciseTargetRecommendations, isNotEmpty);
      expect(fixture.achievementUnlocks, isNotEmpty);
      expect(fixture.dailyHydrations, isNotEmpty);

      final target = AppDatabase.memory();
      addTearDown(target.close);
      await fixture.restoreToDatabase(target);
      expect(
        await target.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );

      final sourceFile = await B03V16Fixture.copyCompleteTo(
        tempDir,
        filename: 'complete-v16-golden.db',
      );
      final source = B03V16Fixture.open(sourceFile);
      addTearDown(source.close);
      final golden = await B03LogicalSnapshot.capture(source);
      final restored = await B03LogicalSnapshot.capture(target);
      golden.assertLogicallyEquals(restored);
    });

    test(
      'unsupported newer versions fail before any target mutation',
      () async {
        final target = AppDatabase.memory();
        addTearDown(target.close);
        await target
            .into(target.userSettings)
            .insert(
              UserSettingsCompanion.insert(key: 'sentinel', value: 'unchanged'),
            );
        final payload =
            jsonDecode(jsonEncode(B03BackupV7Fixture.load().toJson()))
                as Map<String, dynamic>;
        payload['version'] = 8;

        expect(
          () => BackupData.fromJson(payload),
          throwsA(isA<FormatException>()),
        );
        expect(await target.select(target.userSettings).get(), hasLength(1));
        expect(
          (await target.select(target.userSettings).get()).single.value,
          'unchanged',
        );
      },
    );

    test(
      'invalid relationship prevalidation mutates neither database nor preferences',
      () async {
        final target = AppDatabase.memory();
        addTearDown(target.close);
        SharedPreferences.setMockInitialValues({'water_logged': 99});
        final prefs = await SharedPreferences.getInstance();
        final payload =
            jsonDecode(jsonEncode(B03BackupV7Fixture.load().toJson()))
                as Map<String, dynamic>;
        final sets = payload['workout_sets'] as List;
        (sets.single as Map<String, dynamic>)['session_id'] = 999999;
        final invalid = BackupData.fromJson(payload);

        expect(
          () => invalid.restoreToDatabase(target, prefs),
          throwsA(isA<FormatException>()),
        );
        expect(await target.select(target.foodLogs).get(), isEmpty);
        expect(prefs.getInt('water_logged'), 99);
      },
    );

    test(
      'injected restore failure rolls back database and preferences, then retries',
      () async {
        final target = AppDatabase.memory();
        addTearDown(target.close);
        SharedPreferences.setMockInitialValues({'water_logged': 99});
        final prefs = await SharedPreferences.getInstance();
        final fixture = B03BackupV7Fixture.load();

        await B03RestoreFailureHarness.installDatabaseFailure(target);
        await expectLater(
          fixture.restoreToDatabase(target, prefs),
          throwsA(isA<Exception>()),
        );
        expect(await target.select(target.foodLogs).get(), isEmpty);
        expect((await target.select(target.userProfiles).get()), isEmpty);
        expect(prefs.getInt('water_logged'), 99);

        await B03RestoreFailureHarness.removeDatabaseFailure(target);
        await fixture.restoreToDatabase(target, prefs);
        expect(await target.select(target.foodLogs).get(), hasLength(3));
        expect(prefs.getInt('water_logged'), 4);
        expect(
          await target.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      },
    );

    test(
      'fixture contains no Backup-v8 entities or production version changes',
      () {
        final payload = B03BackupV7Fixture.load().toJson();
        expect(payload['version'], 7);
        expect(payload['schema_version'], 16);
        expect(
          payload.keys.where(
            (key) => key.startsWith('nutrition_') || key.startsWith('v8_'),
          ),
          isEmpty,
        );
      },
    );
  });
}

String sha256Text(String value) {
  return sha256.convert(utf8.encode(value)).toString();
}
