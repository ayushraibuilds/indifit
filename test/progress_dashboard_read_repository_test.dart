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
    expect(snapshot.workouts!.single.totalVolumeKg, 4500);
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
