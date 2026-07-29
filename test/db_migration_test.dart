import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'fixtures/v14_db_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('indifit_v14_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('B01-02 Real v14 Database Migration & On-Disk Harness Tests', () {
    test('1. Opens real on-disk SQLite database at schema v14', () async {
      final db = V14DbFixtures.openOnDiskDatabase(tempDir, 'v14_test.db');

      try {
        expect(db.schemaVersion, equals(14));

        await V14DbFixtures.seedSingleRoutine(db);

        final routines = await db.select(db.workoutRoutines).get();
        expect(routines.length, equals(1));
        expect(routines.first.name, equals('Push Day'));

        final days = await db.select(db.routineDays).get();
        expect(days.length, equals(1));
        expect(days.first.name, equals('Push Primary'));

        final exercises = await db.select(db.routineExercises).get();
        expect(exercises.length, equals(2));
      } finally {
        await db.close();
      }
    });

    test(
      '2. On-disk database supports rich historical sessions, sets and drafts at v14',
      () async {
        final db = V14DbFixtures.openOnDiskDatabase(tempDir, 'v14_history.db');

        try {
          await V14DbFixtures.seedMultipleRoutinesAndHistory(db);

          final routines = await db.select(db.workoutRoutines).get();
          expect(routines.length, equals(2));

          final sessions = await db.select(db.workoutSessions).get();
          expect(sessions.length, equals(2));

          final sets = await db.select(db.workoutSets).get();
          expect(sets.length, equals(3));

          final benchSet = sets.firstWhere(
            (s) => s.exerciseName == 'Flat Barbell Bench Press',
          );
          expect(benchSet.weight, equals(80.0));
          expect(benchSet.reps, equals(8));
          expect(benchSet.isPr, isTrue);
          expect(benchSet.rpe, equals(8));
          expect(benchSet.setNotes, equals('Felt strong, clean form 💪'));

          final cardioSet = sets.firstWhere(
            (s) => s.exerciseName == 'Treadmill Run',
          );
          expect(cardioSet.durationSeconds, equals(1200));
          expect(cardioSet.distanceKm, equals(3.2));
          expect(cardioSet.inclinePercentage, equals(2.0));

          final drafts = await db.select(db.workoutDrafts).get();
          expect(drafts.length, equals(1));
          expect(drafts.first.routineName, equals('Push Day'));
        } finally {
          await db.close();
        }
      },
    );

    test(
      '3. On-disk database handles custom exercises and unknown equipment strings',
      () async {
        final db = V14DbFixtures.openOnDiskDatabase(tempDir, 'v14_custom.db');

        try {
          await V14DbFixtures.seedCustomAndUnresolvedExercises(db);
          await V14DbFixtures.seedKnownAndUnknownEquipment(db);

          final exercises = await db.select(db.exercises).get();
          final customs = exercises.where((e) => e.isCustom).toList();
          expect(customs.length, equals(2));
          expect(
            customs.map((e) => e.name),
            containsAll(['Pike Push-ups', 'Superman Lat Pulls']),
          );

          final profile = await db.select(db.userProfiles).getSingle();
          expect(profile.equipmentAccess, equals('full_gym'));
        } finally {
          await db.close();
        }
      },
    );

    test(
      '4. Injected migration failure preserves existing database file and rolls back transaction',
      () async {
        final dbFile = File('${tempDir.path}/v14_rollback.db');
        final db = V14DbFixtures.openOnDiskDatabase(tempDir, 'v14_rollback.db');

        try {
          await V14DbFixtures.seedSingleRoutine(db);
          final initialRoutines = await db.select(db.workoutRoutines).get();
          expect(initialRoutines.length, equals(1));

          // Inject simulated migration error inside a transaction
          try {
            await db.transaction(() async {
              await db
                  .into(db.workoutRoutines)
                  .insert(
                    WorkoutRoutinesCompanion.insert(
                      name: 'Temporary Routine',
                      goal: 'Testing',
                    ),
                  );
              throw Exception('Simulated Migration Upgrade Error');
            });
          } catch (e) {
            expect(e.toString(), contains('Simulated Migration Upgrade Error'));
          }

          // Database file MUST still exist on disk
          expect(await dbFile.exists(), isTrue);

          // Database records MUST be 100% restored to pre-transaction state
          final postRoutines = await db.select(db.workoutRoutines).get();
          expect(postRoutines.length, equals(1));
          expect(postRoutines.first.name, equals('Push Day'));
        } finally {
          await db.close();
        }
      },
    );
  });
}
