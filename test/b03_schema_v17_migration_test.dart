import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';

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
      'complete graph fixture contains non-empty B01 and B02 relationships',
      () async {
        final file = await B03V16Fixture.copyCompleteTo(tempDir);
        expect(B03V16Fixture.readUserVersion(file), 16);
        expect(sha256File(file), B03V16Fixture.completeChecksum);

        final db = B03V16Fixture.open(file);
        try {
          final snapshot = await B03LogicalSnapshot.capture(db);
          const requiredNonEmptyTables = {
            'food_items',
            'food_logs',
            'programs',
            'program_versions',
            'program_blocks',
            'program_weeks',
            'session_templates',
            'exercise_prescriptions',
            'scheduled_session_occurrences',
            'occurrence_events',
            'training_plan_settings',
            'equipment_profiles',
            'equipment_profile_items',
            'travel_contexts',
            'travel_context_occurrences',
            'exercise_user_preferences',
            'exercise_setup_values',
            'exercise_personal_cues',
            'muscles',
            'exercise_muscle_mappings',
            'health_provenances',
            'workout_drafts',
            'legacy_routine_program_mappings',
            'exercise_groups',
            'exercise_group_members',
            'strength_set_prescriptions',
            'cardio_intervals',
            'mobility_session_details',
            'performed_exercise_groups',
            'performed_exercises',
            'exercise_target_recommendations',
            'performed_sets',
            'performed_set_segments',
            'performed_rest_periods',
            'workout_routines',
            'routine_days',
            'routine_exercises',
            'body_measurements',
            'daily_hydrations',
            'achievement_unlocks',
          };
          for (final table in requiredNonEmptyTables) {
            expect(
              snapshot.tables[table],
              isNotEmpty,
              reason: 'complete fixture must exercise $table',
            );
          }
          expect(
            await db.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
        } finally {
          await db.close();
        }
      },
    );

    test(
      'logical comparison ignores remapped local IDs but preserves relationships',
      () {
        final source = B03LogicalSnapshot({
          'workout_routines': [
            {'id': 11, 'name': 'Fixture Routine', 'goal': 'strength'},
          ],
          'routine_days': [
            {'id': 12, 'routine_id': 11, 'day_of_week': 1, 'name': 'Day 1'},
          ],
          'routine_exercises': [
            {'id': 13, 'day_id': 12, 'exercise_name': 'Press', 'sets': 3},
          ],
          'achievement_unlocks': [
            {'id': 14, 'achievement_id': 'fixture-achievement'},
          ],
          'daily_hydrations': [
            {'id': 15, 'date_string': '2026-01-15', 'total_ml': 1800},
          ],
          'training_plan_settings': [
            {'id': 1, 'active_program_version_id': 'version-1'},
          ],
        });
        final restored = B03LogicalSnapshot({
          'workout_routines': [
            {'id': 101, 'name': 'Fixture Routine', 'goal': 'strength'},
          ],
          'routine_days': [
            {'id': 102, 'routine_id': 101, 'day_of_week': 1, 'name': 'Day 1'},
          ],
          'routine_exercises': [
            {'id': 103, 'day_id': 102, 'exercise_name': 'Press', 'sets': 3},
          ],
          'achievement_unlocks': [
            {'id': 104, 'achievement_id': 'fixture-achievement'},
          ],
          'daily_hydrations': [
            {'id': 105, 'date_string': '2026-01-15', 'total_ml': 1800},
          ],
          'training_plan_settings': [
            {'id': 1, 'active_program_version_id': 'version-1'},
          ],
        });
        source.assertLogicallyEquals(restored);
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

  group('B03-06A schema-v17 boundary', () {
    test('upgrades the real complete v16 file transactionally', () async {
      final file = await B03V16Fixture.copyCompleteTo(
        tempDir,
        filename: 'migration.db',
      );
      final beforeDb = B03V16Fixture.open(file);
      final before = await B03LogicalSnapshot.capture(beforeDb);
      await beforeDb.close();

      final db = AppDatabase.executor(NativeDatabase(file));
      try {
        await db.customSelect('SELECT 1').get();
        expect(B03V16Fixture.readUserVersion(file), 17);
        expect(db.schemaVersion, 17);
        final after = await B03LogicalSnapshot.capture(db);
        before.assertLogicallyEquals(after);
        expect(await db.select(db.nutritionFoods).get(), hasLength(598));
        expect(await db.select(db.nutritionFoodAliases).get(), hasLength(15));
        final reviewedMapping = await (db.select(
          db.nutritionLegacyFoodMappings,
        )..where((row) => row.legacyFoodItemId.equals(1))).getSingle();
        expect(reviewedMapping.foodId, 'food-seed-0564');
        expect(
          await (db.select(
            db.nutritionLegacyFoodMappings,
          )..where((row) => row.legacyFoodItemId.equals(574))).get(),
          isEmpty,
          reason: 'custom legacy food identity must not map to catalogue food',
        );
        expect(
          await db.select(db.nutritionNutrientDefinitions).get(),
          hasLength(18),
        );
        expect(await db.select(db.nutritionFoodNutrientFacts).get(), isEmpty);
        expect(await db.select(db.nutritionRecipes).get(), isEmpty);
        expect(await db.select(db.nutritionRecipeVersions).get(), isEmpty);
        expect(await db.select(db.nutritionRecipeIngredients).get(), isEmpty);
        expect(
          await db.select(db.nutritionConsumptionSnapshots).get(),
          isEmpty,
        );
        expect(await db.select(db.nutritionSnapshotItems).get(), isEmpty);
        expect(await db.select(db.nutritionSnapshotNutrients).get(), isEmpty);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await db.close();
      }
    });

    test('fresh v17 creation exposes the complete approved graph', () async {
      final db = AppDatabase.memory();
      try {
        expect(db.schemaVersion, 17);
        final tables = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'nutrition_%' ORDER BY name",
            )
            .get();
        expect(tables, hasLength(25));
        expect(
          await db.select(db.nutritionNutrientDefinitions).get(),
          hasLength(18),
        );
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await db.close();
      }
    });

    test('each supported v17 migration stage rolls back and retries', () async {
      const stages = [
        B03FailureStage.migrationValidation,
        B03FailureStage.migrationDdlAndDataMutation,
        B03FailureStage.migrationFinalTransaction,
      ];

      for (final stage in stages) {
        final file = await B03V16Fixture.copyCompleteTo(
          tempDir,
          filename: 'failure-${stage.name}.db',
        );
        final harness = B03StageAwareFailureHarness(stage);
        final failing = harness.openNutritionMigrating(file);
        try {
          await failing.customSelect('SELECT 1').get();
          fail('Expected v17 migration failure at $stage.');
        } on B03InjectedFailure catch (error) {
          expect(error.stage, stage);
        }
        await failing.close();

        expect(harness.injected, isTrue);
        expect(harness.reachedStages, contains(stage));
        expect(B03V16Fixture.readUserVersion(file), 16);

        final legacy = B03V16Fixture.open(file);
        try {
          expect(await legacy.customSelect('SELECT 1').get(), isNotEmpty);
        } finally {
          await legacy.close();
        }

        harness.disable();
        final retry = harness.openNutritionMigrating(file);
        try {
          await retry.customSelect('SELECT 1').get();
          expect(B03V16Fixture.readUserVersion(file), 17);
          expect(
            await retry.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
        } finally {
          await retry.close();
        }
      }
    });

    test('v17 constraints reject invalid durable relationships', () async {
      final db = AppDatabase.memory();
      try {
        await db
            .into(db.nutritionFoods)
            .insert(
              NutritionFoodsCompanion.insert(
                id: 'nutrition-test-food',
                kind: 'canonical',
                displayName: 'Test food',
                locale: 'en-IN',
                sourceType: 'bundled_asset',
                lifecycle: 'active',
              ),
            );
        await expectLater(
          db
              .into(db.nutritionFoods)
              .insert(
                NutritionFoodsCompanion.insert(
                  id: 'invalid-food',
                  kind: 'not-a-kind',
                  displayName: 'Invalid',
                  locale: 'en-IN',
                  sourceType: 'bundled_asset',
                  lifecycle: 'active',
                ),
              ),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          db
              .into(db.nutritionFoodNutrientFacts)
              .insert(
                NutritionFoodNutrientFactsCompanion.insert(
                  id: 'invalid-fact',
                  foodId: 'nutrition-test-food',
                  nutrientId: 'protein',
                  status: 'known',
                  source: 'legacy',
                  factVersion: 1,
                  basis: 'per_100_grams',
                  basisQuantity: const Value(100),
                  basisUnit: const Value('gram'),
                  amount: const Value(-1),
                ),
              ),
          throwsA(isA<Exception>()),
        );
      } finally {
        await db.close();
      }
    });
  });
}

String sha256File(File file) =>
    sha256.convert(file.readAsBytesSync()).toString();
