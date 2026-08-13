import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_exercise_performance_read_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late B02ExercisePerformanceReadRepository repository;

  setUp(() {
    database = AppDatabase.memory();
    repository = B02ExercisePerformanceReadRepository(database);
  });

  tearDown(() => database.close());

  test(
    'reads canonical performance by exact stable ID despite display-name changes',
    () async {
      await _insertExercise(database, 'bench', 'Bench press');
      await _insertExercise(database, 'bench-variant', 'Bench press');

      final canonicalSession = await _insertSession(
        database,
        name: 'Push day',
        completedAt: DateTime.utc(2026, 8, 12, 9),
      );
      await _insertPerformedExercise(
        database,
        id: 'bench-canonical',
        sessionId: canonicalSession,
        actualExerciseId: 'bench',
        actualName: 'Barbell bench press',
      );
      await _insertPerformedSet(
        database,
        id: 'bench-warmup',
        performedExerciseId: 'bench-canonical',
        ordinal: 0,
        role: B02SetRole.warmup,
        loadKg: 40,
        reps: 10,
      );
      await _insertPerformedSet(
        database,
        id: 'bench-working',
        performedExerciseId: 'bench-canonical',
        ordinal: 1,
        role: B02SetRole.working,
        loadKg: 60,
        reps: 8,
        rpe: 8,
      );

      final similarlyNamedSession = await _insertSession(
        database,
        name: 'Variant day',
        completedAt: DateTime.utc(2026, 8, 13, 9),
      );
      await _insertPerformedExercise(
        database,
        id: 'variant',
        sessionId: similarlyNamedSession,
        actualExerciseId: 'bench-variant',
        actualName: 'Barbell bench press',
      );
      await _insertPerformedSet(
        database,
        id: 'variant-working',
        performedExerciseId: 'variant',
        ordinal: 0,
        role: B02SetRole.working,
        loadKg: 75,
        reps: 5,
      );

      final nonStrengthSession = await _insertSession(
        database,
        name: 'Legacy label',
        completedAt: DateTime.utc(2026, 8, 13, 10),
        activityType: B02ActivityType.legacy,
      );
      await _insertPerformedExercise(
        database,
        id: 'non-strength',
        sessionId: nonStrengthSession,
        actualExerciseId: 'bench',
        actualName: 'Bench press',
      );
      await _insertPerformedSet(
        database,
        id: 'non-strength-working',
        performedExerciseId: 'non-strength',
        ordinal: 0,
        role: B02SetRole.working,
        loadKg: 100,
        reps: 1,
      );

      final history = await repository.read(stableExerciseId: 'bench');

      expect(history, hasLength(1));
      expect(history.single.sessionName, 'Push day');
      expect(history.single.completedAt, DateTime.utc(2026, 8, 12, 9));
      expect(history.single.sets, hasLength(2));
      expect(history.single.sets.first.role, B02SetRole.warmup);
      expect(history.single.sets.last.role, B02SetRole.working);
      expect(history.single.sets.last.actualLoadKg, 60);
      expect(
        history.single.sets.last.actualLoadBasis,
        B02LoadBasis.totalExternal,
      );
      expect(history.single.sets.last.actualReps, 8);
      expect(history.single.sets.last.actualRpe, 8);
    },
  );

  test(
    'does not treat prescribed-only canonical sets as performance',
    () async {
      await _insertExercise(database, 'bench', 'Bench press');
      final sessionId = await _insertSession(
        database,
        name: 'Planned push',
        completedAt: DateTime.utc(2026, 8, 12, 9),
      );
      await _insertPerformedExercise(
        database,
        id: 'prescribed-only',
        sessionId: sessionId,
        actualExerciseId: 'bench',
        actualName: 'Bench press',
      );
      await database
          .into(database.performedSets)
          .insert(
            PerformedSetsCompanion.insert(
              id: 'prescribed-set',
              performedExerciseId: 'prescribed-only',
              ordinal: 0,
              role: B02SetRole.working.dbValue,
              targetLoadKg: const Value(60),
              targetLoadBasis: const Value('totalExternal'),
              targetRepsMin: const Value(8),
            ),
          );

      expect(await repository.read(stableExerciseId: 'bench'), isEmpty);
    },
  );
}

Future<void> _insertExercise(
  AppDatabase database,
  String stableId,
  String name,
) => database
    .into(database.exercises)
    .insert(
      ExercisesCompanion.insert(
        stableId: Value(stableId),
        name: name,
        muscleGroups: 'Chest',
        equipment: 'Barbell',
        difficulty: 'Intermediate',
        formCues: '',
        commonMistakes: '',
      ),
    );

Future<int> _insertSession(
  AppDatabase database, {
  required String name,
  required DateTime completedAt,
  B02ActivityType activityType = B02ActivityType.strength,
}) => database
    .into(database.workoutSessions)
    .insert(
      WorkoutSessionsCompanion.insert(
        name: name,
        totalVolume: 0,
        durationSeconds: 600,
        estimatedCalories: 0,
        completedAt: Value(completedAt),
        activityType: Value(activityType.dbValue),
        activitySchemaVersion: const Value(1),
      ),
    );

Future<void> _insertPerformedExercise(
  AppDatabase database, {
  required String id,
  required int sessionId,
  required String actualExerciseId,
  required String actualName,
}) => database
    .into(database.performedExercises)
    .insert(
      PerformedExercisesCompanion.insert(
        id: id,
        sessionId: sessionId,
        ordinal: 0,
        actualExerciseId: actualExerciseId,
        actualExerciseNameSnapshot: actualName,
        status: const Value('completed'),
      ),
    );

Future<void> _insertPerformedSet(
  AppDatabase database, {
  required String id,
  required String performedExerciseId,
  required int ordinal,
  required B02SetRole role,
  required double loadKg,
  required int reps,
  int? rpe,
}) => database
    .into(database.performedSets)
    .insert(
      PerformedSetsCompanion.insert(
        id: id,
        performedExerciseId: performedExerciseId,
        ordinal: ordinal,
        role: role.dbValue,
        actualLoadKg: Value(loadKg),
        actualLoadBasis: const Value('totalExternal'),
        actualReps: Value(reps),
        actualRpe: Value(rpe),
      ),
    );
