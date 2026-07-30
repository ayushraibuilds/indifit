import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'fixtures/v14_db_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('indifit_b01_v15_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('B01-03 v14 to v15 migration', () {
    test(
      'imports retained routines as immutable inactive legacy snapshots',
      () async {
        final file = V14DbFixtures.createSourceDatabase(
          tempDir,
          'legacy-routine.db',
          scenario: V14FixtureScenario.singleRoutine,
        );
        final db = V14DbFixtures.openCurrentDatabase(file);
        try {
          await db.customSelect('SELECT 1').get();

          final programs = await db.select(db.programs).get();
          final versions = await db.select(db.programVersions).get();
          final blocks = await db.select(db.programBlocks).get();
          final weeks = await db.select(db.programWeeks).get();
          final templates = await db.select(db.sessionTemplates).get();
          final prescriptions = await db.select(db.exercisePrescriptions).get();
          final mappings = await db
              .select(db.legacyRoutineProgramMappings)
              .get();
          final settings = await db.select(db.trainingPlanSettings).getSingle();

          expect(programs.single.name, 'Push Day');
          expect(versions.single.status, 'published');
          expect(versions.single.origin, 'legacyImport');
          expect(versions.single.publishedAtUtc, isNotNull);
          expect(blocks.single.ordinal, 1);
          expect(weeks.single.programWeekOrdinal, 1);
          expect(templates.single.plannedWeekday, 1);
          expect(prescriptions.map((item) => item.exerciseNameSnapshot), [
            'Flat Barbell Bench Press',
            'Seated Dumbbell Shoulder Press',
          ]);
          expect(
            prescriptions.every((item) => item.exerciseId == null),
            isTrue,
          );
          expect(mappings.single.legacyRoutineId, 1);

          // D02: migration keeps legacy selection behavior until an explicit B01
          // activation. It must not invent an activation date or occurrences.
          expect(settings.activeProgramVersionId, isNull);
          expect(settings.activeSinceLocalDate, isNull);
          expect(settings.activeSinceTimezoneId, isNull);
          expect(
            await db.select(db.scheduledSessionOccurrences).get(),
            isEmpty,
          );
          expect(await db.select(db.workoutRoutines).get(), hasLength(1));
          expect(await db.select(db.routineDays).get(), hasLength(1));
          expect(await db.select(db.routineExercises).get(), hasLength(2));
        } finally {
          await db.close();
        }
      },
    );

    test(
      'uses only exact or approved aliases for stable-ID backfill',
      () async {
        final file = V14DbFixtures.createSourceDatabase(
          tempDir,
          'identity.db',
          scenario: V14FixtureScenario.canonicalIdentity,
        );
        final db = V14DbFixtures.openCurrentDatabase(file);
        try {
          await db.customSelect('SELECT 1').get();
          final exercises = await db.select(db.exercises).get();
          final sets = await db.select(db.workoutSets).get();
          final prescriptions = await db.select(db.exercisePrescriptions).get();

          const benchId = '089ec703-a25e-5b12-a39a-78b17ee33742';
          const shoulderPressId = '37088aa5-6989-5241-8ad9-23f1687a9435';
          final pikeStableId = exercises
              .singleWhere((item) => item.name == 'Pike Push-ups')
              .stableId;

          expect(
            exercises
                .singleWhere((item) => item.name == 'Flat Barbell Bench Press')
                .stableId,
            benchId,
          );
          expect(pikeStableId, matches(RegExp(r'^[0-9a-f-]{36}$')));

          expect(
            sets
                .singleWhere((item) => item.exerciseName.contains('flat'))
                .exerciseId,
            benchId,
          );
          expect(
            sets
                .singleWhere(
                  (item) => item.exerciseName == 'seated dumbbell press',
                )
                .exerciseId,
            shoulderPressId,
          );
          expect(
            sets
                .singleWhere((item) => item.exerciseName == 'dumbbell curls')
                .exerciseId,
            isNull,
          );
          expect(
            sets
                .singleWhere((item) => item.exerciseName == 'Pike Push-ups')
                .exerciseId,
            pikeStableId,
          );

          expect(prescriptions.map((item) => item.exerciseId), [
            benchId,
            shoulderPressId,
            null,
            pikeStableId,
          ]);
          expect(prescriptions.map((item) => item.exerciseNameSnapshot), [
            'flat barbell bench press',
            'seated dumbbell press',
            'dumbbell curls',
            'Pike Push-ups',
          ]);
        } finally {
          await db.close();
        }
      },
    );

    test(
      'preserves duplicate legacy catalogue rows without assigning one identity',
      () async {
        final file = V14DbFixtures.createSourceDatabase(
          tempDir,
          'duplicate-identity.db',
          scenario: V14FixtureScenario.duplicateCanonicalIdentity,
        );
        final db = V14DbFixtures.openCurrentDatabase(file);
        try {
          await db.customSelect('SELECT 1').get();
          final exercises = await db.select(db.exercises).get();
          final set = await db.select(db.workoutSets).getSingle();

          expect(exercises, hasLength(2));
          expect(exercises.map((item) => item.stableId).toSet(), hasLength(2));
          expect(
            exercises.any(
              (item) => item.stableId == '089ec703-a25e-5b12-a39a-78b17ee33742',
            ),
            isFalse,
          );
          expect(set.exerciseId, isNull);
        } finally {
          await db.close();
        }
      },
    );

    test(
      'creates one default profile without simplifying unknown equipment',
      () async {
        final knownFile = V14DbFixtures.createSourceDatabase(
          tempDir,
          'known-equipment.db',
          scenario: V14FixtureScenario.knownEquipment,
        );
        final knownDb = V14DbFixtures.openCurrentDatabase(knownFile);
        try {
          await knownDb.customSelect('SELECT 1').get();
          final profile = await knownDb
              .select(knownDb.equipmentProfiles)
              .getSingle();
          final items = await knownDb
              .select(knownDb.equipmentProfileItems)
              .get();
          final settings = await knownDb
              .select(knownDb.trainingPlanSettings)
              .getSingle();
          expect(profile.name, 'Default Gym');
          expect(profile.legacyAccessCode, 'full_gym');
          expect(settings.defaultEquipmentProfileId, profile.id);
          expect(
            items.map((item) => item.equipmentCode).toSet(),
            containsAll(<String>{
              'barbell',
              'dumbbell',
              'cable',
              'machine',
              'bodyweight',
              'bench',
              'rack',
            }),
          );
        } finally {
          await knownDb.close();
        }

        final unknownFile = V14DbFixtures.createSourceDatabase(
          tempDir,
          'unknown-equipment.db',
          scenario: V14FixtureScenario.unknownEquipment,
        );
        final unknownDb = V14DbFixtures.openCurrentDatabase(unknownFile);
        try {
          await unknownDb.customSelect('SELECT 1').get();
          final profile = await unknownDb
              .select(unknownDb.equipmentProfiles)
              .getSingle();
          expect(profile.legacyAccessCode, 'mystery_space_station_gym');
          expect(
            await unknownDb.select(unknownDb.equipmentProfileItems).get(),
            isEmpty,
          );
        } finally {
          await unknownDb.close();
        }
      },
    );

    test(
      'fresh v15 creates singleton settings, stable seeded IDs, and indexes',
      () async {
        final db = AppDatabase.memory();
        try {
          await db.customSelect('SELECT 1').get();
          final settings = await db.select(db.trainingPlanSettings).getSingle();
          final exercises = await db.select(db.exercises).get();
          final bench = exercises.singleWhere(
            (exercise) => exercise.name == 'Flat Barbell Bench Press',
          );
          expect(settings.id, 1);
          expect(settings.activeProgramVersionId, isNull);
          expect(bench.stableId, '089ec703-a25e-5b12-a39a-78b17ee33742');

          await db
              .into(db.exercises)
              .insert(
                ExercisesCompanion.insert(
                  name: 'Personal Cable Fly Variant',
                  muscleGroups: 'Chest',
                  equipment: 'Cable',
                  difficulty: 'Beginner',
                  formCues: 'Keep shoulders down',
                  commonMistakes: 'Shrugging',
                  isCustom: const Value(true),
                ),
              );
          final custom =
              await (db.select(db.exercises)..where(
                    (table) => table.name.equals('Personal Cable Fly Variant'),
                  ))
                  .getSingle();
          expect(custom.stableId, matches(RegExp(r'^[0-9a-f-]{36}$')));

          final indexRows = await db
              .customSelect("PRAGMA index_list('exercises')")
              .get();
          expect(
            indexRows.any(
              (row) => row.read<String>('name') == 'idx_exercises_stable_id',
            ),
            isTrue,
          );
        } finally {
          await db.close();
        }
      },
    );

    test(
      'accepts the linked v15 graph and rejects invalid lifecycle data',
      () async {
        final db = AppDatabase.memory();
        final createdAt = DateTime.utc(2026, 7, 29, 9);
        try {
          await db.customSelect('SELECT 1').get();
          final bench =
              await (db.select(db.exercises)..where(
                    (table) => table.name.equals('Flat Barbell Bench Press'),
                  ))
                  .getSingle();
          await db
              .into(db.programs)
              .insert(
                ProgramsCompanion.insert(
                  id: 'program-1',
                  name: 'Fixture program',
                  createdAtUtc: createdAt,
                ),
              );
          await db
              .into(db.programVersions)
              .insert(
                ProgramVersionsCompanion.insert(
                  id: 'version-1',
                  programId: 'program-1',
                  versionNumber: 1,
                  status: 'published',
                  createdAtUtc: createdAt,
                  publishedAtUtc: Value(createdAt),
                ),
              );
          await db
              .into(db.programBlocks)
              .insert(
                ProgramBlocksCompanion.insert(
                  id: 'block-1',
                  programVersionId: 'version-1',
                  ordinal: 1,
                  name: 'Base',
                ),
              );
          await db
              .into(db.programWeeks)
              .insert(
                ProgramWeeksCompanion.insert(
                  id: 'week-1',
                  programVersionId: 'version-1',
                  programBlockId: 'block-1',
                  ordinalInBlock: 1,
                  programWeekOrdinal: 1,
                ),
              );
          await db
              .into(db.sessionTemplates)
              .insert(
                SessionTemplatesCompanion.insert(
                  id: 'template-1',
                  programWeekId: 'week-1',
                  ordinal: 1,
                  name: 'Push',
                  plannedWeekday: 1,
                ),
              );
          await db
              .into(db.exercisePrescriptions)
              .insert(
                ExercisePrescriptionsCompanion.insert(
                  id: 'prescription-1',
                  sessionTemplateId: 'template-1',
                  ordinal: 1,
                  exerciseId: Value(bench.stableId),
                  exerciseNameSnapshot: bench.name,
                  plannedSets: 3,
                  repsRange: '8-12',
                ),
              );
          await db
              .into(db.scheduledSessionOccurrences)
              .insert(
                ScheduledSessionOccurrencesCompanion.insert(
                  id: 'occurrence-1',
                  programVersionId: 'version-1',
                  sessionTemplateId: 'template-1',
                  programBlockOrdinal: 1,
                  programWeekOrdinal: 1,
                  sessionOrdinal: 1,
                  originalLocalDate: '2026-08-03',
                  originalTimezoneId: 'Asia/Kolkata',
                  effectiveLocalDate: '2026-08-03',
                  effectiveTimezoneId: 'Asia/Kolkata',
                  createdAtUtc: createdAt,
                ),
              );
          await db
              .into(db.occurrenceEvents)
              .insert(
                OccurrenceEventsCompanion.insert(
                  id: 'event-1',
                  occurrenceId: 'occurrence-1',
                  commandId: 'command-1',
                  eventType: 'materialized',
                  occurredAtUtc: createdAt,
                ),
              );
          expect(
            await db.select(db.scheduledSessionOccurrences).get(),
            hasLength(1),
          );

          await expectLater(
            db
                .into(db.programVersions)
                .insert(
                  ProgramVersionsCompanion.insert(
                    id: 'invalid-version',
                    programId: 'program-1',
                    versionNumber: 2,
                    status: 'active',
                    createdAtUtc: createdAt,
                  ),
                ),
            throwsA(isA<Exception>()),
          );
          await expectLater(
            db
                .into(db.occurrenceEvents)
                .insert(
                  OccurrenceEventsCompanion.insert(
                    id: 'event-duplicate-command',
                    occurrenceId: 'occurrence-1',
                    commandId: 'command-1',
                    eventType: 'materialized',
                    occurredAtUtc: createdAt,
                  ),
                ),
            throwsA(isA<Exception>()),
          );
        } finally {
          await db.close();
        }
      },
    );

    test('injected migration failure rolls back DDL and source data', () async {
      final file = V14DbFixtures.createSourceDatabase(
        tempDir,
        'rollback-v15.db',
        scenario: V14FixtureScenario.singleRoutine,
      );
      final db = V14DbFixtures.openCurrentDatabase(
        file,
        v15MigrationFailureInjector: () async {
          throw StateError('injected B01-v15 migration failure');
        },
      );
      try {
        await expectLater(
          db.customSelect('SELECT 1').get(),
          throwsA(isA<StateError>()),
        );
      } finally {
        await db.close();
      }

      expect(V14DbFixtures.readUserVersion(file), V14DbFixtures.schemaVersion);
      final source = sqlite.sqlite3.open(
        file.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        final programTable = source.select(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'programs'",
        );
        final routines = source.select('SELECT name FROM workout_routines');
        expect(programTable, isEmpty);
        expect(routines.single['name'], 'Push Day');
      } finally {
        source.dispose();
      }
    });
  });
}
