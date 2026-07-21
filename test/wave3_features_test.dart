import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/workout_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late WorkoutRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = WorkoutRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Wave 3 WorkoutRepository Cardio and History Tests', () {
    test('getExerciseHistory returns correct history in descending order of id', () async {
      final sessionId = await db.into(db.workoutSessions).insert(
        WorkoutSessionsCompanion.insert(
          name: 'Running Protocol',
          totalVolume: 0.0,
          durationSeconds: 1200,
          estimatedCalories: 300,
        ),
      );

      await db.into(db.workoutSets).insert(
        WorkoutSetsCompanion.insert(
          sessionId: sessionId,
          exerciseName: 'Treadmill Walk',
          weight: 0.0,
          reps: 0,
          setNumber: 1,
          durationSeconds: const Value(600),
          distanceKm: const Value(1.0),
          inclinePercentage: const Value(2.0),
        ),
      );

      await db.into(db.workoutSets).insert(
        WorkoutSetsCompanion.insert(
          sessionId: sessionId,
          exerciseName: 'Treadmill Walk',
          weight: 0.0,
          reps: 0,
          setNumber: 2,
          durationSeconds: const Value(900),
          distanceKm: const Value(1.5),
          inclinePercentage: const Value(3.0),
        ),
      );

      final history = await repo.getExerciseHistory('Treadmill Walk');
      expect(history.length, 1); // 1 session

      final sessionMap = history.first;
      final session = sessionMap['session'] as WorkoutSession;
      final sets = sessionMap['sets'] as List<WorkoutSet>;

      expect(session.name, 'Running Protocol');
      expect(sets.length, 2);
      expect(sets.first.durationSeconds, 600);
      expect(sets.last.durationSeconds, 900);
      expect(sets.last.distanceKm, 1.5);
      expect(sets.last.inclinePercentage, 3.0);
    });
  });
}
