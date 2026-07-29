import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'fixtures/v14_db_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('indifit_v14_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('B01-02 real v14 source database harness', () {
    test(
      'preserves the zero-routine and zero-session source fixture',
      () async {
        final file = V14DbFixtures.createSourceDatabase(
          tempDir,
          'empty.db',
          scenario: V14FixtureScenario.empty,
        );
        final db = V14DbFixtures.openCurrentDatabase(file);
        try {
          await db.customSelect('SELECT 1').get();
          expect(await db.select(db.workoutRoutines).get(), isEmpty);
          expect(await db.select(db.workoutSessions).get(), isEmpty);
        } finally {
          await db.close();
        }
      },
    );

    test(
      'creates a deterministic raw v14 source before AppDatabase opens it',
      () async {
        final file = V14DbFixtures.createSourceDatabase(
          tempDir,
          'single_routine.db',
          scenario: V14FixtureScenario.singleRoutine,
        );

        expect(
          V14DbFixtures.readUserVersion(file),
          V14DbFixtures.schemaVersion,
        );

        final db = V14DbFixtures.openCurrentDatabase(file);
        try {
          await db.customSelect('SELECT 1').get();
          final routines = await db.select(db.workoutRoutines).get();
          final days = await db.select(db.routineDays).get();
          final prescriptions = await db.select(db.routineExercises).get();

          expect(routines.single.name, 'Push Day');
          expect(days.single.name, 'Push Primary');
          expect(prescriptions.map((item) => item.exerciseName), [
            'Flat Barbell Bench Press',
            'Seated Dumbbell Shoulder Press',
          ]);
        } finally {
          await db.close();
        }
      },
    );

    test(
      'preserves historical sessions, sets, and active legacy draft',
      () async {
        final file = V14DbFixtures.createSourceDatabase(
          tempDir,
          'rich_history.db',
          scenario: V14FixtureScenario.richHistory,
        );
        final db = V14DbFixtures.openCurrentDatabase(file);

        try {
          await db.customSelect('SELECT 1').get();
          final routines = await db.select(db.workoutRoutines).get();
          final sessions = await db.select(db.workoutSessions).get();
          final sets = await db.select(db.workoutSets).get();
          final drafts = await db.select(db.workoutDrafts).get();

          expect(routines, hasLength(2));
          expect(sessions, hasLength(2));
          expect(sets, hasLength(3));
          expect(drafts.single.routineName, 'Push Day');
          expect(drafts.single.elapsedSeconds, 900);

          final benchSet = sets.firstWhere(
            (item) => item.exerciseName == 'Flat Barbell Bench Press',
          );
          expect(benchSet.rpe, 8);
          expect(benchSet.setNotes, 'Felt strong, clean form 💪');

          final cardioSet = sets.firstWhere(
            (item) => item.exerciseName == 'Treadmill Run',
          );
          expect(cardioSet.durationSeconds, 1200);
          expect(cardioSet.distanceKm, 3.2);
          expect(cardioSet.inclinePercentage, 2.0);
        } finally {
          await db.close();
        }
      },
    );

    test(
      'preserves custom, unresolved, and unknown equipment source values',
      () async {
        final customFile = V14DbFixtures.createSourceDatabase(
          tempDir,
          'custom.db',
          scenario: V14FixtureScenario.customAndUnresolved,
        );
        final customDb = V14DbFixtures.openCurrentDatabase(customFile);
        try {
          await customDb.customSelect('SELECT 1').get();
          final customExercises = await customDb
              .select(customDb.exercises)
              .get();
          final routineExercises = await customDb
              .select(customDb.routineExercises)
              .get();
          expect(customExercises.map((item) => item.name), [
            'Pike Push-ups',
            'Superman Lat Pulls',
          ]);
          expect(
            routineExercises.single.exerciseName,
            'Anti-gravity Chamber Press',
          );
        } finally {
          await customDb.close();
        }

        final knownEquipmentFile = V14DbFixtures.createSourceDatabase(
          tempDir,
          'known_equipment.db',
          scenario: V14FixtureScenario.knownEquipment,
        );
        final knownEquipmentDb = V14DbFixtures.openCurrentDatabase(
          knownEquipmentFile,
        );
        try {
          await knownEquipmentDb.customSelect('SELECT 1').get();
          final profile = await knownEquipmentDb
              .select(knownEquipmentDb.userProfiles)
              .getSingle();
          expect(profile.equipmentAccess, 'full_gym');
        } finally {
          await knownEquipmentDb.close();
        }

        final unknownEquipmentFile = V14DbFixtures.createSourceDatabase(
          tempDir,
          'unknown_equipment.db',
          scenario: V14FixtureScenario.unknownEquipment,
        );
        final equipmentDb = V14DbFixtures.openCurrentDatabase(
          unknownEquipmentFile,
        );
        try {
          await equipmentDb.customSelect('SELECT 1').get();
          final profile = await equipmentDb
              .select(equipmentDb.userProfiles)
              .getSingle();
          expect(profile.equipmentAccess, 'mystery_space_station_gym');
        } finally {
          await equipmentDb.close();
        }
      },
    );

    test(
      'preserves malformed source relationships for migration rejection tests',
      () async {
        final file = V14DbFixtures.createSourceDatabase(
          tempDir,
          'orphaned_set.db',
          scenario: V14FixtureScenario.malformedRelationship,
        );
        final db = V14DbFixtures.openCurrentDatabase(file);
        try {
          await db.customSelect('SELECT 1').get();
          final sets = await db.select(db.workoutSets).get();
          expect(sets.single.sessionId, 999);
          expect(sets.single.exerciseName, 'Orphaned Bench Press');
        } finally {
          await db.close();
        }
      },
    );

    test(
      'injected future-upgrade failure rolls back source writes on disk',
      () async {
        final file = V14DbFixtures.createSourceDatabase(
          tempDir,
          'rollback.db',
          scenario: V14FixtureScenario.singleRoutine,
        );
        final db = V14DbFixtures.openCurrentDatabase(file);
        try {
          await db.customSelect('SELECT 1').get();
          await expectLater(
            db.transaction(() async {
              await db.customStatement('''
              INSERT INTO workout_routines (name, goal, created_at)
              VALUES ('Temporary Routine', 'Testing', 1704067200000);
            ''');
              throw StateError('simulated migration upgrade failure');
            }),
            throwsA(isA<StateError>()),
          );

          expect(await file.exists(), isTrue);
          final routines = await db.select(db.workoutRoutines).get();
          expect(routines.map((item) => item.name), ['Push Day']);
        } finally {
          await db.close();
        }
      },
    );
  });
}
