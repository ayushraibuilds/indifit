import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_muscle_volume_models.dart';
import 'package:indifit/data/repositories/b02_muscle_volume_repository.dart';

const _benchId = '089ec703-a25e-5b12-a39a-78b17ee33742';
const _squatId = 'd3b5ab04-74f6-5155-9621-50238644eeda';
const _customId = 'legacy-custom-unresolved-001';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    await _ensureExercise(db, _benchId, 'Flat Barbell Bench Press');
    await _ensureExercise(db, _squatId, 'Barbell Squat');
    await _ensureExercise(
      db,
      _customId,
      'Unresolved Custom Movement',
      custom: true,
    );
    await B02MuscleCatalogRepository(db).seedReviewedCatalog();
  });

  tearDown(() => db.close());

  test(
    'reads canonical sets by civil date, excludes legacy/warmup/outside rows',
    () async {
      final inside = await _insertSession(
        db,
        completedAt: DateTime.utc(2026, 8, 1, 12),
        activityType: 'strength',
      );
      final insideBench = await _insertPerformedExercise(
        db,
        sessionId: inside,
        id: 'inside-bench',
        actualExerciseId: _benchId,
        ordinal: 0,
      );
      await _insertSet(
        db,
        id: 'inside-warmup',
        performedExerciseId: insideBench,
        ordinal: 0,
        role: 'warmup',
        reps: 12,
        targetRepsMin: 10,
      );
      await _insertSet(
        db,
        id: 'inside-working',
        performedExerciseId: insideBench,
        ordinal: 1,
        role: 'working',
        reps: 8,
        targetRepsMin: 10,
      );
      final insideCustom = await _insertPerformedExercise(
        db,
        sessionId: inside,
        id: 'inside-custom',
        actualExerciseId: _customId,
        ordinal: 1,
      );
      await _insertSet(
        db,
        id: 'inside-unknown',
        performedExerciseId: insideCustom,
        ordinal: 0,
        role: 'working',
        reps: 5,
        targetRepsMin: 10,
      );

      final legacy = await _insertSession(
        db,
        completedAt: DateTime.utc(2026, 8, 1, 13),
        activityType: 'legacy',
      );
      await db
          .into(db.workoutSets)
          .insert(
            WorkoutSetsCompanion.insert(
              sessionId: legacy,
              exerciseName: 'Legacy Name',
              weight: 20,
              reps: 10,
              setNumber: 1,
            ),
          );
      final outside = await _insertSession(
        db,
        // Exactly the exclusive end of 2026-08-01 in Asia/Kolkata.
        completedAt: DateTime.utc(2026, 8, 2, 18, 30),
        activityType: 'strength',
      );
      final outsideExercise = await _insertPerformedExercise(
        db,
        sessionId: outside,
        id: 'outside-bench',
        actualExerciseId: _benchId,
        ordinal: 0,
      );
      await _insertSet(
        db,
        id: 'outside-working',
        performedExerciseId: outsideExercise,
        ordinal: 0,
        role: 'working',
        reps: 10,
        targetRepsMin: 10,
      );

      final model = await B02MuscleVolumeRepository(db).read(
        const B02MuscleVolumeQuery(
          startLocalDate: '2026-08-01',
          endLocalDate: '2026-08-01',
          timezoneId: 'Asia/Kolkata',
        ),
      );
      expect(model.totalWorkingSetCount, 2);
      expect(model.mappedWorkingSetCount, 1);
      expect(model.unknown.workingSetCount, 1);
      expect(model.legacySetCount, 1);
      expect(model.hasLegacyCoverage, isTrue);
      expect(model.muscles, hasLength(4));
      expect(
        model.muscles
            .singleWhere((cell) => cell.muscleId == 'glute-maximus')
            .workingSetUnits,
        0,
      );
      expect(model.mappingCoverage, closeTo(0.5, 0.000001));
      expect(model.startUtc, DateTime.utc(2026, 7, 31, 18, 30));
      expect(model.endExclusiveUtc, DateTime.utc(2026, 8, 1, 18, 30));
    },
  );

  test(
    'seed preserves an existing unknown row and remains idempotent',
    () async {
      final existingMuscle = await (db.select(
        db.muscles,
      )..where((table) => table.id.equals('chest'))).getSingle();
      expect(existingMuscle.displayName, 'Chest');
      final existingMapping =
          await (db.select(db.exerciseMuscleMappings)..where(
                (table) =>
                    table.exerciseId.equals(_benchId) &
                    table.muscleId.equals('chest'),
              ))
              .getSingle();
      await (db.update(
        db.exerciseMuscleMappings,
      )..where((table) => table.id.equals(existingMapping.id))).write(
        const ExerciseMuscleMappingsCompanion(mappingStatus: Value('unknown')),
      );

      final result = await B02MuscleCatalogRepository(db).seedReviewedCatalog();
      expect(result.preservedMappings, greaterThanOrEqualTo(1));
      final row = await (db.select(
        db.exerciseMuscleMappings,
      )..where((table) => table.id.equals(existingMapping.id))).getSingle();
      expect(row.mappingStatus, 'unknown');
      final second = await B02MuscleCatalogRepository(db).seedReviewedCatalog();
      expect(second.insertedMuscles, 0);
      expect(second.insertedMappings, 0);
    },
  );

  test('mapping lookup uses the exact stable exercise ID', () async {
    final repository = B02MuscleVolumeRepository(db);
    final mapping = await repository.readMappingForExercise(_benchId);
    expect(mapping != null, isTrue);
    expect(mapping!.isReviewed, isTrue);
    expect(
      await repository.readMappingForExercise('Flat Barbell Bench Press'),
      isNull,
    );
  });

  test('seed validates before mutation and rolls back conflicts', () async {
    final conflictDb = AppDatabase.memory();
    addTearDown(conflictDb.close);
    final originalMuscleCount =
        (await conflictDb.select(conflictDb.muscles).get()).length;
    final originalMappingCount =
        (await conflictDb.select(conflictDb.exerciseMuscleMappings).get())
            .length;
    await (conflictDb.update(conflictDb.muscles)
          ..where((table) => table.id.equals('chest')))
        .write(const MusclesCompanion(displayName: Value('Conflicting Chest')));
    await expectLater(
      B02MuscleCatalogRepository(conflictDb).seedReviewedCatalog(),
      throwsA(isA<B02MuscleVolumeValidationException>()),
    );
    expect(
      await conflictDb.select(conflictDb.exerciseMuscleMappings).get(),
      hasLength(originalMappingCount),
    );
    expect(
      await conflictDb.select(conflictDb.muscles).get(),
      hasLength(originalMuscleCount),
    );
  });

  test('rejects an invalid civil range and unknown timezone', () async {
    final repository = B02MuscleVolumeRepository(db);
    await expectLater(
      repository.read(
        const B02MuscleVolumeQuery(
          startLocalDate: '2026-08-02',
          endLocalDate: '2026-08-01',
          timezoneId: 'Asia/Kolkata',
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      repository.read(
        const B02MuscleVolumeQuery(
          startLocalDate: '2026-08-01',
          endLocalDate: '2026-08-01',
          timezoneId: 'Not/AZone',
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}

Future<void> _ensureExercise(
  AppDatabase db,
  String stableId,
  String name, {
  bool custom = false,
}) async {
  final existing = await (db.select(
    db.exercises,
  )..where((table) => table.stableId.equals(stableId))).getSingleOrNull();
  if (existing != null) return;
  await db
      .into(db.exercises)
      .insert(
        ExercisesCompanion.insert(
          stableId: Value(stableId),
          name: name,
          muscleGroups: 'ignored',
          equipment: 'Barbell',
          difficulty: 'Intermediate',
          formCues: 'cue',
          commonMistakes: 'mistake',
          isCustom: Value(custom),
        ),
      );
}

Future<int> _insertSession(
  AppDatabase db, {
  required DateTime completedAt,
  required String activityType,
}) => db
    .into(db.workoutSessions)
    .insert(
      WorkoutSessionsCompanion.insert(
        name: activityType,
        totalVolume: 0,
        durationSeconds: 600,
        estimatedCalories: 0,
        completedAt: Value(completedAt),
        activityType: Value(activityType),
      ),
    );

Future<String> _insertPerformedExercise(
  AppDatabase db, {
  required int sessionId,
  required String id,
  required String actualExerciseId,
  required int ordinal,
}) async {
  await db
      .into(db.performedExercises)
      .insert(
        PerformedExercisesCompanion.insert(
          id: id,
          sessionId: sessionId,
          ordinal: ordinal,
          actualExerciseId: actualExerciseId,
          actualExerciseNameSnapshot: actualExerciseId,
        ),
      );
  return id;
}

Future<void> _insertSet(
  AppDatabase db, {
  required String id,
  required String performedExerciseId,
  required int ordinal,
  required String role,
  required int reps,
  required int? targetRepsMin,
}) => db
    .into(db.performedSets)
    .insert(
      PerformedSetsCompanion.insert(
        id: id,
        performedExerciseId: performedExerciseId,
        ordinal: ordinal,
        role: role,
        actualReps: Value(reps),
        targetRepsMin: Value(targetRepsMin),
      ),
    );
