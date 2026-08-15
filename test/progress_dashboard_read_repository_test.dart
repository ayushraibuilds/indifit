import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/progress_dashboard_read_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late ProgressDashboardReadRepository repository;

  setUp(() {
    database = AppDatabase.memory();
    repository = ProgressDashboardReadRepository(
      database,
      dates: LocalScheduleDateService(
        nowUtc: () => DateTime.utc(2026, 8, 9, 12),
      ),
    );
  });

  tearDown(() => database.close());

  test(
    'preserves duplicate weight observations and excludes future facts',
    () async {
      await database
          .into(database.bodyMeasurements)
          .insert(
            BodyMeasurementsCompanion.insert(
              weight: const Value(82.0),
              recordedAt: Value(DateTime.utc(2026, 8, 8, 7)),
            ),
          );
      await database
          .into(database.bodyMeasurements)
          .insert(
            BodyMeasurementsCompanion.insert(
              weight: const Value(81.8),
              recordedAt: Value(DateTime.utc(2026, 8, 8, 20)),
            ),
          );
      await database
          .into(database.bodyMeasurements)
          .insert(
            BodyMeasurementsCompanion.insert(
              weight: const Value(79.0),
              recordedAt: Value(DateTime.utc(2026, 8, 10)),
            ),
          );
      await _insertSession(
        database,
        name: 'Completed session',
        completedAt: DateTime.utc(2026, 8, 8, 20),
      );
      await _insertSession(
        database,
        name: 'Future session',
        completedAt: DateTime.utc(2026, 8, 10),
      );

      final snapshot = await repository.read(
        nowUtc: DateTime.utc(2026, 8, 9, 12),
        timezoneId: 'Asia/Kolkata',
      );

      expect(snapshot.measurements, hasLength(2));
      expect(snapshot.measurements!.map((record) => record.weightKg), [
        81.8,
        82.0,
      ]);
      expect(
        snapshot.measurements!.first.localDate,
        '2026-08-09',
        reason:
            'Progress must label measurement history in its explicit civil timezone.',
      );
      expect(snapshot.workouts, hasLength(1));
      expect(snapshot.workouts!.single.name, 'Completed session');
      // The completed UTC instant belongs to Aug 9 in the Progress/Today civil
      // timezone; it is not rendered as the UTC calendar day.
      expect(snapshot.workouts!.single.localDate, '2026-08-09');
      expect(snapshot.weightGoal, isNull);
    },
  );

  test(
    'orders identical-time measurements deterministically by persisted id',
    () async {
      final instant = DateTime.utc(2026, 8, 8, 7);
      await database
          .into(database.bodyMeasurements)
          .insert(
            BodyMeasurementsCompanion.insert(
              weight: const Value(82.0),
              recordedAt: Value(instant),
            ),
          );
      await database
          .into(database.bodyMeasurements)
          .insert(
            BodyMeasurementsCompanion.insert(
              weight: const Value(81.8),
              recordedAt: Value(instant),
            ),
          );

      final snapshot = await repository.read(
        nowUtc: DateTime.utc(2026, 8, 9, 12),
        timezoneId: 'Asia/Kolkata',
      );

      expect(snapshot.measurements!.map((record) => record.weightKg), [
        81.8,
        82.0,
      ]);
      expect(
        snapshot.measurements!.first.id,
        greaterThan(snapshot.measurements!.last.id),
        reason:
            'A latest observation must not depend on incidental SQLite row order.',
      );
    },
  );

  test('strength is built only from B02 performed actual values', () async {
    await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('bench'),
            name: 'Bench Press',
            muscleGroups: 'Chest',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Brace',
            commonMistakes: 'Bounce',
          ),
        );
    final sessionId = await _insertSession(
      database,
      name: 'Bench day',
      completedAt: DateTime.utc(2026, 8, 8, 8),
      activityType: 'strength',
      volume: 4500,
    );
    await database
        .into(database.performedExercises)
        .insert(
          PerformedExercisesCompanion.insert(
            id: 'bench-performed',
            sessionId: sessionId,
            ordinal: 0,
            actualExerciseId: 'bench',
            actualExerciseNameSnapshot: 'Bench Press',
            status: const Value('completed'),
          ),
        );
    await database
        .into(database.performedSets)
        .insert(
          PerformedSetsCompanion.insert(
            id: 'prescribed-only',
            performedExerciseId: 'bench-performed',
            ordinal: 0,
            role: 'working',
            targetLoadKg: const Value(120),
            targetLoadBasis: const Value('totalExternal'),
            targetRepsMin: const Value(5),
          ),
        );
    await database
        .into(database.performedSets)
        .insert(
          PerformedSetsCompanion.insert(
            id: 'performed',
            performedExerciseId: 'bench-performed',
            ordinal: 1,
            role: 'working',
            targetLoadKg: const Value(120),
            actualLoadKg: const Value(90),
            actualLoadBasis: const Value('totalExternal'),
            actualReps: const Value(5),
          ),
        );

    final snapshot = await repository.read(
      nowUtc: DateTime.utc(2026, 8, 9, 12),
      timezoneId: 'Asia/Kolkata',
    );

    expect(snapshot.strengthSets, hasLength(1));
    expect(snapshot.strengthSets!.single.loadKg, 90);
    expect(snapshot.strengthSets!.single.reps, 5);
    expect(snapshot.strengthSets!.single.loadBasis, 'totalExternal');
    expect(snapshot.workouts!.single.totalVolumeKg, 450);
    expect(snapshot.workouts!.single.volumeIsTrustworthy, isTrue);
    expect(snapshot.strengthExercises, hasLength(1));
    final exerciseSummary = snapshot.strengthExercises!.single;
    expect(exerciseSummary.exerciseName, 'Bench Press');
    expect(exerciseSummary.latestSet.loadKg, 90);
    expect(exerciseSummary.bestSet.loadKg, 90);
  });

  test(
    'builds weekly trained dates and strength exercise comparisons',
    () async {
      await database
          .into(database.exercises)
          .insert(
            ExercisesCompanion.insert(
              stableId: const Value('squat'),
              name: 'Back Squat',
              muscleGroups: 'Legs',
              equipment: 'Barbell',
              difficulty: 'Advanced',
              formCues: 'Depth',
              commonMistakes: 'Knee cave',
            ),
          );

      // Session 1: Aug 4 (Tuesday)
      final session1 = await _insertSession(
        database,
        name: 'Leg Day 1',
        completedAt: DateTime.utc(2026, 8, 4, 10),
        activityType: 'strength',
        volume: 5000,
      );
      await database
          .into(database.performedExercises)
          .insert(
            PerformedExercisesCompanion.insert(
              id: 'squat-p1',
              sessionId: session1,
              ordinal: 0,
              actualExerciseId: 'squat',
              actualExerciseNameSnapshot: 'Back Squat',
              status: const Value('completed'),
            ),
          );
      await database
          .into(database.performedSets)
          .insert(
            PerformedSetsCompanion.insert(
              id: 'set-s1',
              performedExerciseId: 'squat-p1',
              ordinal: 0,
              role: 'working',
              actualLoadKg: const Value(100),
              actualLoadBasis: const Value('totalExternal'),
              actualReps: const Value(5),
            ),
          );

      // Session 2: Aug 7 (Friday)
      final session2 = await _insertSession(
        database,
        name: 'Leg Day 2',
        completedAt: DateTime.utc(2026, 8, 7, 10),
        activityType: 'strength',
        volume: 5250,
      );
      await database
          .into(database.performedExercises)
          .insert(
            PerformedExercisesCompanion.insert(
              id: 'squat-p2',
              sessionId: session2,
              ordinal: 0,
              actualExerciseId: 'squat',
              actualExerciseNameSnapshot: 'Back Squat',
              status: const Value('completed'),
            ),
          );
      await database
          .into(database.performedSets)
          .insert(
            PerformedSetsCompanion.insert(
              id: 'set-s2',
              performedExerciseId: 'squat-p2',
              ordinal: 0,
              role: 'working',
              actualLoadKg: const Value(105),
              actualLoadBasis: const Value('totalExternal'),
              actualReps: const Value(5),
            ),
          );

      final snapshot = await repository.read(
        nowUtc: DateTime.utc(2026, 8, 9, 12),
        timezoneId: 'UTC',
      );

      expect(
        snapshot.weeklyTrainedDates,
        containsAll(['2026-08-04', '2026-08-07']),
      );
      expect(snapshot.strengthExercises, hasLength(1));
      final squat = snapshot.strengthExercises!.single;
      expect(squat.sessionCount, 2);
      expect(squat.latestSet.loadKg, 105);
      expect(squat.bestSet.loadKg, 105);
      expect(squat.comparisonText, '+5 kg at 5 reps');
    },
  );

  test('hides canonical volume when load basis is not comparable', () async {
    await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('mixed'),
            name: 'Mixed Press',
            muscleGroups: 'Chest',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Brace',
            commonMistakes: 'Bounce',
          ),
        );
    final sessionId = await _insertSession(
      database,
      name: 'Mixed basis day',
      completedAt: DateTime.utc(2026, 8, 8, 10),
      activityType: 'strength',
      volume: 9999,
    );
    await database
        .into(database.performedExercises)
        .insert(
          PerformedExercisesCompanion.insert(
            id: 'mixed-exercise',
            sessionId: sessionId,
            ordinal: 0,
            actualExerciseId: 'mixed',
            actualExerciseNameSnapshot: 'Mixed Press',
            status: const Value('completed'),
          ),
        );
    await database
        .into(database.performedSets)
        .insert(
          PerformedSetsCompanion.insert(
            id: 'mixed-total',
            performedExerciseId: 'mixed-exercise',
            ordinal: 0,
            role: 'working',
            actualLoadKg: const Value(80),
            actualLoadBasis: const Value('totalExternal'),
            actualReps: const Value(5),
          ),
        );
    await database
        .into(database.performedSets)
        .insert(
          PerformedSetsCompanion.insert(
            id: 'mixed-side',
            performedExerciseId: 'mixed-exercise',
            ordinal: 1,
            role: 'working',
            actualLoadKg: const Value(20),
            actualLoadBasis: const Value('perSide'),
            actualReps: const Value(5),
          ),
        );

    final snapshot = await repository.read(
      nowUtc: DateTime.utc(2026, 8, 9, 12),
      timezoneId: 'UTC',
    );

    expect(snapshot.workouts!.single.totalVolumeKg, 0);
    expect(snapshot.workouts!.single.volumeIsTrustworthy, isFalse);
    expect(snapshot.strengthSets, hasLength(2));
  });
}

Future<int> _insertSession(
  AppDatabase database, {
  required String name,
  required DateTime completedAt,
  String activityType = 'legacy',
  double volume = 0,
}) => database
    .into(database.workoutSessions)
    .insert(
      WorkoutSessionsCompanion.insert(
        name: name,
        totalVolume: volume,
        durationSeconds: 600,
        estimatedCalories: 0,
        completedAt: Value(completedAt),
        activityType: Value(activityType),
        activitySchemaVersion: const Value(1),
      ),
    );
