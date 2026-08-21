import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/models/b02_previous_performance_models.dart';
import 'package:indifit/data/repositories/b02_previous_performance_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final asOf = DateTime.utc(2026, 8, 20, 12);
  late AppDatabase database;
  late B02PreviousPerformanceRepository repository;

  setUp(() {
    database = AppDatabase.memory();
    repository = B02PreviousPerformanceRepository(database);
  });

  tearDown(() => database.close());

  B02PreviousPerformanceQuery query({
    String? canonicalExerciseId = 'bench',
    B02SetRole role = B02SetRole.working,
    B02LoadBasis loadBasis = B02LoadBasis.totalExternal,
    B02ActivityType activityType = B02ActivityType.strength,
    int? excludeSessionId,
    bool hasTechniqueSegments = false,
  }) => B02PreviousPerformanceQuery(
    canonicalExerciseId: canonicalExerciseId,
    activityType: activityType,
    setContext: B02PreviousPerformanceSetContext(
      role: role,
      loadBasis: loadBasis,
      hasTechniqueSegments: hasTechniqueSegments,
    ),
    asOfUtc: asOf,
    excludeSessionId: excludeSessionId,
  );

  test(
    'returns exact-ID completed performance and preserves actual facts',
    () async {
      await _insertExercise(database, 'bench', 'Bench press');
      await _insertExercise(database, 'bench-variant', 'Bench press');
      final sessionId = await _insertSession(
        database,
        completedAt: DateTime.utc(2026, 8, 19, 9),
      );
      final performedId = await _insertPerformedExercise(
        database,
        sessionId: sessionId,
        actualExerciseId: 'bench',
        actualName: 'Renamed barbell press',
      );
      await _insertSet(
        database,
        performedExerciseId: performedId,
        setId: 'bench-warmup',
        ordinal: 0,
        role: B02SetRole.warmup,
        loadKg: 40,
        reps: 10,
      );
      await _insertSet(
        database,
        performedExerciseId: performedId,
        setId: 'bench-working',
        ordinal: 1,
        role: B02SetRole.working,
        loadKg: 80,
        reps: 8,
      );
      final otherSession = await _insertSession(
        database,
        completedAt: DateTime.utc(2026, 8, 19, 10),
      );
      final otherPerformedId = await _insertPerformedExercise(
        database,
        sessionId: otherSession,
        actualExerciseId: 'bench-variant',
        actualName: 'Bench press',
      );
      await _insertSet(
        database,
        performedExerciseId: otherPerformedId,
        setId: 'variant-working',
        loadKg: 120,
        reps: 5,
      );

      final result = await repository.resolve(query());

      expect(result.status, B02PreviousPerformanceStatus.available);
      expect(result.sessionId, sessionId);
      expect(result.occurrences.single.actualExerciseId, 'bench');
      expect(
        result.occurrences.single.actualExerciseNameSnapshot,
        'Renamed barbell press',
      );
      expect(result.occurrences.single.sets.single.actualLoadKg, 80);
      expect(result.occurrences.single.sets.single.actualReps, 8);
      expect(result.safePrefill!.loadKg, 80);
      expect(result.safePrefill!.reps, 8);
    },
  );

  test(
    'selects the most recent comparable session with deterministic ties',
    () async {
      await _insertExercise(database, 'bench', 'Bench press');
      final older = await _insertSession(
        database,
        completedAt: DateTime.utc(2026, 8, 18, 9),
      );
      final olderPerformed = await _insertPerformedExercise(
        database,
        sessionId: older,
        actualExerciseId: 'bench',
        actualName: 'Bench press',
      );
      await _insertSet(
        database,
        performedExerciseId: olderPerformed,
        setId: 'older-set',
        ordinal: 0,
        loadKg: 70,
        reps: 8,
      );
      final tiedEarlier = await _insertSession(
        database,
        completedAt: DateTime.utc(2026, 8, 19, 9),
      );
      final tiedEarlierPerformed = await _insertPerformedExercise(
        database,
        sessionId: tiedEarlier,
        actualExerciseId: 'bench',
        actualName: 'Bench press',
      );
      await _insertSet(
        database,
        performedExerciseId: tiedEarlierPerformed,
        setId: 'tied-earlier-set',
        ordinal: 0,
        loadKg: 75,
        reps: 8,
      );
      final tiedLater = await _insertSession(
        database,
        completedAt: DateTime.utc(2026, 8, 19, 9),
      );
      final tiedLaterPerformed = await _insertPerformedExercise(
        database,
        sessionId: tiedLater,
        actualExerciseId: 'bench',
        actualName: 'Bench press',
      );
      final tiedSetId = await _insertSet(
        database,
        performedExerciseId: tiedLaterPerformed,
        setId: 'tied-later-set',
        ordinal: 1,
        loadKg: 80,
        reps: 8,
      );
      await _insertSet(
        database,
        performedExerciseId: tiedLaterPerformed,
        setId: 'tied-first-set',
        ordinal: 0,
        loadKg: 77.5,
        reps: 8,
      );

      final result = await repository.resolve(query());

      expect(result.sessionId, tiedLater);
      expect(result.sessionId, greaterThan(tiedEarlier));
      expect(result.occurrences.single.sets.map((set) => set.performedSetId), [
        'tied-first-set',
        tiedSetId,
      ]);
      expect(result.safePrefill, isNull);
    },
  );

  test('returns normal no-history for a first-use exact ID', () async {
    await _insertExercise(database, 'bench', 'Bench press');

    final result = await repository.resolve(query());

    expect(result.status, B02PreviousPerformanceStatus.noHistory);
    expect(result.reasonCode, 'no_history');
    expect(result.safePrefill, isNull);
  });

  test('excludes the current session from historical evidence', () async {
    await _insertExercise(database, 'bench', 'Bench press');
    final previousSession = await _insertSession(
      database,
      completedAt: DateTime.utc(2026, 8, 18, 9),
    );
    final previousPerformed = await _insertPerformedExercise(
      database,
      sessionId: previousSession,
      actualExerciseId: 'bench',
      actualName: 'Bench press',
    );
    await _insertSet(
      database,
      performedExerciseId: previousPerformed,
      setId: 'previous-set',
      loadKg: 70,
      reps: 8,
    );
    final currentSession = await _insertSession(
      database,
      completedAt: DateTime.utc(2026, 8, 20, 11),
    );
    final currentPerformed = await _insertPerformedExercise(
      database,
      sessionId: currentSession,
      actualExerciseId: 'bench',
      actualName: 'Bench press',
    );
    await _insertSet(
      database,
      performedExerciseId: currentPerformed,
      setId: 'current-set',
      loadKg: 90,
      reps: 6,
    );

    final result = await repository.resolve(
      query(excludeSessionId: currentSession),
    );

    expect(result.sessionId, previousSession);
    expect(result.safePrefill!.loadKg, 70);
  });

  test(
    'excludes incomplete or non-authoritative rows and fails closed',
    () async {
      await _insertExercise(database, 'bench', 'Bench press');
      final validSession = await _insertSession(
        database,
        completedAt: DateTime.utc(2026, 8, 18, 9),
      );
      final validPerformed = await _insertPerformedExercise(
        database,
        sessionId: validSession,
        actualExerciseId: 'bench',
        actualName: 'Bench press',
        status: 'completed',
      );
      await _insertSet(
        database,
        performedExerciseId: validPerformed,
        setId: 'valid-set',
        loadKg: 70,
        reps: 8,
      );
      final incompleteSession = await _insertSession(
        database,
        completedAt: DateTime.utc(2026, 8, 19, 9),
        completionKind: 'inProgress',
      );
      final incompletePerformed = await _insertPerformedExercise(
        database,
        sessionId: incompleteSession,
        actualExerciseId: 'bench',
        actualName: 'Bench press',
        status: 'inProgress',
      );
      await _insertSet(
        database,
        performedExerciseId: incompletePerformed,
        setId: 'incomplete-set',
        loadKg: 100,
        reps: 10,
      );

      final result = await repository.resolve(query());

      expect(result.status, B02PreviousPerformanceStatus.available);
      expect(result.sessionId, validSession);
      expect(result.safePrefill!.loadKg, 70);

      await database.customStatement(
        "UPDATE performed_exercises SET status = 'inProgress'",
      );
      final onlyIncomplete = await repository.resolve(query());
      expect(onlyIncomplete.status, B02PreviousPerformanceStatus.incompatible);
    },
  );

  test('requires an explicit canonical completion kind', () async {
    await _insertExercise(database, 'bench', 'Bench press');
    final session = await _insertSession(
      database,
      completedAt: DateTime.utc(2026, 8, 19, 9),
      completionKind: null,
    );
    final performed = await _insertPerformedExercise(
      database,
      sessionId: session,
      actualExerciseId: 'bench',
      actualName: 'Bench press',
    );
    await _insertSet(
      database,
      performedExerciseId: performed,
      setId: 'null-completion-set',
      loadKg: 80,
      reps: 8,
    );

    final result = await repository.resolve(query());

    expect(result.status, B02PreviousPerformanceStatus.incompatible);
    expect(result.reasonCode, 'no_compatible_evidence');
  });

  test(
    'never uses names, fuzzy matching, or a different exercise ID',
    () async {
      await _insertExercise(database, 'bench', 'Bench press');
      await _insertExercise(database, 'bench-variant', 'Bench press');
      final session = await _insertSession(
        database,
        completedAt: DateTime.utc(2026, 8, 19, 9),
      );
      final performed = await _insertPerformedExercise(
        database,
        sessionId: session,
        actualExerciseId: 'bench-variant',
        actualName: 'Bench press',
      );
      await _insertSet(
        database,
        performedExerciseId: performed,
        setId: 'variant-set',
        loadKg: 100,
        reps: 5,
      );

      final exactMiss = await repository.resolve(query());
      final nameAsId = await repository.resolve(
        query(canonicalExerciseId: 'Bench press'),
      );

      expect(exactMiss.status, B02PreviousPerformanceStatus.noHistory);
      expect(nameAsId.status, B02PreviousPerformanceStatus.noHistory);
    },
  );

  test(
    'attributes substituted history to the actual performed exercise',
    () async {
      await _insertExercise(database, 'planned-bench', 'Bench press');
      await _insertExercise(database, 'actual-cable', 'Cable press');
      final session = await _insertSession(
        database,
        completedAt: DateTime.utc(2026, 8, 19, 9),
      );
      final performed = await _insertPerformedExercise(
        database,
        sessionId: session,
        actualExerciseId: 'actual-cable',
        actualName: 'Cable press',
        expectedExerciseId: 'planned-bench',
        substitutionReason: 'Shoulder-friendly handle',
      );
      await _insertSet(
        database,
        performedExerciseId: performed,
        setId: 'substituted-set',
        loadKg: 55,
        reps: 10,
      );

      final actual = await repository.resolve(
        query(canonicalExerciseId: 'actual-cable'),
      );
      final planned = await repository.resolve(
        query(canonicalExerciseId: 'planned-bench'),
      );

      expect(actual.status, B02PreviousPerformanceStatus.available);
      expect(actual.occurrences.single.wasSubstituted, isTrue);
      expect(actual.safePrefill!.loadKg, 55);
      expect(planned.status, B02PreviousPerformanceStatus.noHistory);
    },
  );

  test(
    'rejects incompatible activity modality without cross-modality facts',
    () async {
      await _insertExercise(database, 'bench', 'Bench press');
      final session = await _insertSession(
        database,
        completedAt: DateTime.utc(2026, 8, 19, 9),
        activityType: B02ActivityType.running,
      );
      final performed = await _insertPerformedExercise(
        database,
        sessionId: session,
        actualExerciseId: 'bench',
        actualName: 'Bench press',
      );
      await _insertSet(
        database,
        performedExerciseId: performed,
        setId: 'wrong-modality-set',
        loadKg: 100,
        reps: 5,
      );

      final strength = await repository.resolve(query());
      final running = await repository.resolve(
        query(activityType: B02ActivityType.running),
      );

      expect(strength.status, B02PreviousPerformanceStatus.incompatible);
      expect(running.status, B02PreviousPerformanceStatus.incompatible);
      expect(running.reasonCode, 'unsupported_modality');
    },
  );

  test('rejects incompatible load basis rather than converting it', () async {
    await _insertExercise(database, 'bench', 'Bench press');
    final session = await _insertSession(
      database,
      completedAt: DateTime.utc(2026, 8, 19, 9),
    );
    final performed = await _insertPerformedExercise(
      database,
      sessionId: session,
      actualExerciseId: 'bench',
      actualName: 'Bench press',
    );
    await _insertSet(
      database,
      performedExerciseId: performed,
      setId: 'per-side-set',
      loadBasis: B02LoadBasis.perSide,
      loadKg: 20,
      reps: 10,
    );

    final result = await repository.resolve(query());

    expect(result.status, B02PreviousPerformanceStatus.incompatible);
    expect(result.safePrefill, isNull);
  });

  test(
    'bodyweight evidence preserves reps without inventing an external load',
    () async {
      await _insertExercise(database, 'push-ups', 'Push-Ups');
      final session = await _insertSession(
        database,
        completedAt: DateTime.utc(2026, 8, 19, 9),
      );
      final performed = await _insertPerformedExercise(
        database,
        sessionId: session,
        actualExerciseId: 'push-ups',
        actualName: 'Push-Ups',
      );
      await _insertSet(
        database,
        performedExerciseId: performed,
        setId: 'bodyweight-set',
        loadBasis: B02LoadBasis.bodyweight,
        loadKg: null,
        reps: 12,
      );

      final result = await repository.resolve(
        query(
          canonicalExerciseId: 'push-ups',
          loadBasis: B02LoadBasis.bodyweight,
        ),
      );

      expect(result.status, B02PreviousPerformanceStatus.available);
      expect(result.safePrefill!.loadKg, isNull);
      expect(result.safePrefill!.reps, 12);
    },
  );

  test('warm-up evidence never seeds a working-set query', () async {
    await _insertExercise(database, 'bench', 'Bench press');
    final session = await _insertSession(
      database,
      completedAt: DateTime.utc(2026, 8, 19, 9),
    );
    final performed = await _insertPerformedExercise(
      database,
      sessionId: session,
      actualExerciseId: 'bench',
      actualName: 'Bench press',
    );
    await _insertSet(
      database,
      performedExerciseId: performed,
      setId: 'warmup-set',
      role: B02SetRole.warmup,
      loadKg: 40,
      reps: 10,
    );

    final working = await repository.resolve(query());
    final warmup = await repository.resolve(query(role: B02SetRole.warmup));

    expect(working.status, B02PreviousPerformanceStatus.incompatible);
    expect(warmup.status, B02PreviousPerformanceStatus.available);
    expect(warmup.safePrefill!.role, B02SetRole.warmup);
    expect(warmup.safePrefill!.loadKg, 40);
  });

  test('missing RPE remains missing and no zero is synthesized', () async {
    await _insertExercise(database, 'bench', 'Bench press');
    final session = await _insertSession(
      database,
      completedAt: DateTime.utc(2026, 8, 19, 9),
    );
    final performed = await _insertPerformedExercise(
      database,
      sessionId: session,
      actualExerciseId: 'bench',
      actualName: 'Bench press',
    );
    await _insertSet(
      database,
      performedExerciseId: performed,
      setId: 'missing-rpe',
      loadKg: 80,
      reps: 8,
      rpe: null,
    );

    final result = await repository.resolve(query());

    expect(result.safePrefill!.loadKg, 80);
    expect(result.safePrefill!.rpe, isNull);
    expect(result.occurrences.single.sets.single.actualLoadKg, 80);
  });

  test(
    'multiple previous sets are exposed as a sequence without row guessing',
    () async {
      await _insertExercise(database, 'bench', 'Bench press');
      final session = await _insertSession(
        database,
        completedAt: DateTime.utc(2026, 8, 19, 9),
      );
      final performed = await _insertPerformedExercise(
        database,
        sessionId: session,
        actualExerciseId: 'bench',
        actualName: 'Bench press',
      );
      await _insertSet(
        database,
        performedExerciseId: performed,
        setId: 'set-0',
        ordinal: 0,
        loadKg: 80,
        reps: 8,
      );
      await _insertSet(
        database,
        performedExerciseId: performed,
        setId: 'set-1',
        ordinal: 1,
        loadKg: 80,
        reps: 7,
      );

      final result = await repository.resolve(query());

      expect(result.occurrences.single.sets.map((set) => set.performedSetId), [
        'set-0',
        'set-1',
      ]);
      expect(result.safePrefill, isNull);
    },
  );

  test(
    'advanced technique mismatch is not presented as a plain-set default',
    () async {
      await _insertExercise(database, 'bench', 'Bench press');
      final session = await _insertSession(
        database,
        completedAt: DateTime.utc(2026, 8, 19, 9),
      );
      final performed = await _insertPerformedExercise(
        database,
        sessionId: session,
        actualExerciseId: 'bench',
        actualName: 'Bench press',
      );
      await _insertSet(
        database,
        performedExerciseId: performed,
        setId: 'amrap-set',
        loadKg: 80,
        reps: 15,
        effortMode: B02EffortMode.amrap,
      );

      final result = await repository.resolve(query());

      expect(result.status, B02PreviousPerformanceStatus.incompatible);
      expect(result.safePrefill, isNull);
    },
  );

  test(
    'segmented history fails closed until exact technique semantics exist',
    () async {
      await _insertExercise(database, 'bench', 'Bench press');
      final session = await _insertSession(
        database,
        completedAt: DateTime.utc(2026, 8, 19, 9),
      );
      final performed = await _insertPerformedExercise(
        database,
        sessionId: session,
        actualExerciseId: 'bench',
        actualName: 'Bench press',
      );
      await _insertSet(
        database,
        performedExerciseId: performed,
        setId: 'segmented-set',
        loadKg: 80,
        reps: 8,
      );
      await database
          .into(database.performedSetSegments)
          .insert(
            PerformedSetSegmentsCompanion.insert(
              id: 'malformed-segment',
              performedSetId: 'segmented-set',
              ordinal: 0,
              reps: 4,
              externalLoadKg: const Value(80),
              loadBasis: Value(B02LoadBasis.totalExternal.dbValue),
            ),
          );

      final plain = await repository.resolve(query());
      final segmented = await repository.resolve(
        query(hasTechniqueSegments: true),
      );

      expect(plain.status, B02PreviousPerformanceStatus.incompatible);
      expect(segmented.status, B02PreviousPerformanceStatus.incompatible);
      expect(segmented.reasonCode, 'technique_segments_unsupported');
    },
  );

  test('malformed historical values fail closed', () async {
    await _insertExercise(database, 'bench', 'Bench press');
    final session = await _insertSession(
      database,
      completedAt: DateTime.utc(2026, 8, 19, 9),
    );
    final performed = await _insertPerformedExercise(
      database,
      sessionId: session,
      actualExerciseId: 'bench',
      actualName: 'Bench press',
    );
    await _insertSet(
      database,
      performedExerciseId: performed,
      setId: 'malformed-set',
      loadKg: 80,
      reps: 8,
    );
    await database.customStatement('PRAGMA ignore_check_constraints = ON');
    await database.customStatement(
      "UPDATE performed_sets SET actual_load_basis = 'not-a-basis'",
    );

    final result = await repository.resolve(query());

    expect(result.status, B02PreviousPerformanceStatus.incompatible);
    expect(result.reasonCode, 'no_compatible_evidence');
  });

  test('database failure is distinct from normal no-history', () async {
    await _insertExercise(database, 'bench', 'Bench press');
    await database.close();

    final result = await repository.resolve(query());

    expect(result.status, B02PreviousPerformanceStatus.queryFailure);
    expect(result.reasonCode, 'database_query_failed');
  });

  test(
    'previous values remain facts and never become progression or e1RM output',
    () async {
      await _insertExercise(database, 'bench', 'Bench press');
      final session = await _insertSession(
        database,
        completedAt: DateTime.utc(2026, 8, 19, 9),
      );
      final performed = await _insertPerformedExercise(
        database,
        sessionId: session,
        actualExerciseId: 'bench',
        actualName: 'Bench press',
      );
      await _insertSet(
        database,
        performedExerciseId: performed,
        setId: 'factual-set',
        loadKg: 100,
        reps: 8,
      );

      final result = await repository.resolve(query());

      expect(result.safePrefill!.loadKg, 100);
      expect(result.safePrefill!.reps, 8);
      expect(result.safePrefill!.loadKg, isNot(102.5));
    },
  );

  test(
    'invalid identity is typed and does not query by display name',
    () async {
      final result = await repository.resolve(
        query(canonicalExerciseId: '   '),
      );

      expect(result.status, B02PreviousPerformanceStatus.invalidQuery);
      expect(result.reasonCode, 'canonical_exercise_id_required');
    },
  );
}

Future<void> _insertExercise(
  AppDatabase database,
  String stableId,
  String name,
) async {
  await database
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
}

Future<int> _insertSession(
  AppDatabase database, {
  required DateTime completedAt,
  B02ActivityType activityType = B02ActivityType.strength,
  String? completionKind = 'full',
}) => database
    .into(database.workoutSessions)
    .insert(
      WorkoutSessionsCompanion.insert(
        name: 'Recorded workout',
        totalVolume: 0,
        durationSeconds: 600,
        estimatedCalories: 0,
        completedAt: Value(completedAt),
        activityType: Value(activityType.dbValue),
        completionKind: Value(completionKind),
        activitySchemaVersion: const Value(1),
      ),
    );

Future<String> _insertPerformedExercise(
  AppDatabase database, {
  required int sessionId,
  required String actualExerciseId,
  required String actualName,
  String? expectedExerciseId,
  String? substitutionReason,
  String status = 'completed',
  int ordinal = 0,
}) async {
  final id = 'performed-$sessionId-$ordinal-$actualExerciseId';
  await database
      .into(database.performedExercises)
      .insert(
        PerformedExercisesCompanion.insert(
          id: id,
          sessionId: sessionId,
          ordinal: ordinal,
          expectedExerciseId: Value(expectedExerciseId),
          actualExerciseId: actualExerciseId,
          actualExerciseNameSnapshot: actualName,
          status: Value(status),
          substitutionReason: Value(substitutionReason),
        ),
      );
  return id;
}

Future<String> _insertSet(
  AppDatabase database, {
  required String performedExerciseId,
  required String setId,
  int ordinal = 0,
  B02SetRole role = B02SetRole.working,
  B02LoadBasis? loadBasis = B02LoadBasis.totalExternal,
  double? loadKg,
  int? reps,
  int? rpe,
  B02EffortMode? effortMode = B02EffortMode.standard,
  bool endedAtFailure = false,
}) async {
  await database
      .into(database.performedSets)
      .insert(
        PerformedSetsCompanion.insert(
          id: setId,
          performedExerciseId: performedExerciseId,
          ordinal: ordinal,
          role: role.dbValue,
          actualLoadKg: Value(loadKg),
          actualLoadBasis: Value(loadBasis?.dbValue),
          actualReps: Value(reps),
          actualRpe: Value(rpe),
          effortMode: Value(effortMode?.dbValue),
          endedAtFailure: Value(endedAtFailure),
        ),
      );
  return setId;
}
