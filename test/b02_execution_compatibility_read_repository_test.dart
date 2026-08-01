import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_execution_compatibility_read_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'distinguishes legacy history from canonical activity without names',
    () async {
      final legacyId = await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              name: 'Outdoor Run Label',
              totalVolume: 0,
              durationSeconds: 900,
              estimatedCalories: 100,
            ),
          );
      await db
          .into(db.workoutSets)
          .insert(
            WorkoutSetsCompanion.insert(
              sessionId: legacyId,
              exerciseName: 'Legacy Exercise',
              weight: 0,
              reps: 0,
              setNumber: 1,
            ),
          );
      final canonicalId = await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              name: 'Legacy-looking Run Name',
              totalVolume: 0,
              durationSeconds: 1200,
              estimatedCalories: 150,
              activityType: const Value('running'),
              activitySchemaVersion: const Value(1),
            ),
          );

      final repository = B02ExecutionCompatibilityReadRepository(db);
      final legacy = await repository.readSession(legacyId);
      final canonical = await repository.readSession(canonicalId);

      expect(legacy!.isLegacy, isTrue);
      expect(legacy.activityType, B02ActivityType.legacy);
      expect(legacy.legacySetCount, 1);
      expect(legacy.hasCardioDetail, isFalse);
      expect(canonical!.isCanonical, isTrue);
      expect(canonical.activityType, B02ActivityType.running);
      expect(canonical.legacySetCount, 0);
    },
  );

  test(
    'filters by typed activity and rejects unknown activity values',
    () async {
      final runningId = await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              name: 'Running',
              totalVolume: 0,
              durationSeconds: 1,
              estimatedCalories: 1,
              activityType: const Value('running'),
              activitySchemaVersion: const Value(1),
            ),
          );
      final cyclingId = await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              name: 'Cycling',
              totalVolume: 0,
              durationSeconds: 1,
              estimatedCalories: 1,
              activityType: const Value('cycling'),
              activitySchemaVersion: const Value(1),
            ),
          );

      final repository = B02ExecutionCompatibilityReadRepository(db);
      final running = await repository.readHistory(
        activityType: B02ActivityType.running,
      );
      expect(running.map((item) => item.sessionId), contains(runningId));
      expect(running.map((item) => item.sessionId), isNot(contains(cyclingId)));

      expect(
        () => B02ActivityType.parse('run'),
        throwsA(isA<B02ValidationException>()),
      );
    },
  );
}
