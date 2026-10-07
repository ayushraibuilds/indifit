import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_exercise_performance_read_repository.dart';
import 'package:indifit/features/progress/training_bests.dart';
import 'package:indifit/features/progress/training_bests_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrainingBests.evaluate', () {
    test('the first-ever session is a baseline and earns no bests', () {
      final result = TrainingBests.evaluate(
        history: const [],
        current: [
          _entry(null, 10, [_set('a', 60, 8), _set('b', 65, 8)]),
        ],
      );

      expect(result.bests, isEmpty);
      expect(result.baselineExerciseIds, {'leg-press'});
      expect(
        TrainingBestsCopy.baseline,
        'First time logged. This is your baseline.',
      );
    });

    test('a tie is not a best', () {
      final result = TrainingBests.evaluate(
        history: [
          _entry(1, 1, [_set('h', 60, 8)]),
        ],
        current: [
          _entry(null, 10, [_set('a', 60, 8)]),
        ],
      );

      expect(result.bests, isEmpty);
      expect(result.baselineExerciseIds, isEmpty);
    });

    test('60 kg × 10 then 62.5 kg × 8 is a Heaviest best', () {
      final result = TrainingBests.evaluate(
        history: [
          _entry(1, 1, [_set('h', 60, 10)]),
        ],
        current: [
          _entry(null, 10, [_set('a', 62.5, 8)]),
        ],
      );

      final best = result.bests.single;
      expect(best.kind, TrainingBestKind.heaviest);
      expect(best.setId, 'a');
      expect(best.previous.setId, 'h');
      expect(best.previous.performedAt, _day(1));
      expect(
        TrainingBestsCopy.line(best),
        'Heaviest: 62.5 kg × 8 (was 60 kg × 10)',
      );
      expect(TrainingBestsCopy.semanticsLabel(best.kind), 'New best, heaviest');
    });

    test('60 kg × 8 then 60 kg × 10 is a Most reps best', () {
      final result = TrainingBests.evaluate(
        history: [
          _entry(1, 1, [_set('h', 60, 8)]),
        ],
        current: [
          _entry(null, 10, [_set('a', 60, 10)]),
        ],
      );

      final best = result.bests.single;
      expect(best.kind, TrainingBestKind.mostReps);
      expect(TrainingBestsCopy.line(best), '10 reps at 60 kg (was 8)');
      expect(
        TrainingBestsCopy.semanticsLabel(best.kind),
        'New best, most reps',
      );
    });

    test('more reps at a lighter weight than ever logged is not a best', () {
      final result = TrainingBests.evaluate(
        history: [
          _entry(1, 1, [_set('h', 60, 8)]),
        ],
        current: [
          _entry(null, 10, [_set('a', 55, 10)]),
        ],
      );

      expect(result.bests, isEmpty);
    });

    test('most reps must beat heavier sets too ("this weight or more")', () {
      final result = TrainingBests.evaluate(
        history: [
          _entry(1, 1, [_set('h1', 60, 8), _set('h2', 62.5, 10)]),
        ],
        current: [
          _entry(null, 10, [_set('a', 60, 9)]),
        ],
      );

      expect(result.bests, isEmpty);
    });

    test('warm-ups never count, in history or today', () {
      final result = TrainingBests.evaluate(
        history: [
          _entry(1, 1, [
            _set('warm', 100, 5, role: B02SetRole.warmup),
            _set('h', 60, 8),
          ]),
        ],
        current: [
          _entry(null, 10, [
            _set('a', 120, 5, role: B02SetRole.warmup),
            _set('b', 62.5, 8),
          ]),
        ],
      );

      expect(result.bests.map((best) => best.setId), ['b']);
      expect(result.bests.single.previous.setId, 'h');
    });

    test('assisted, tempo, paused and drop sets are ignored', () {
      final history = [
        _entry(1, 1, [_set('h', 60, 8)]),
      ];
      final techniques = {
        'assisted': B02TechniqueFields(
          assistanceMode: B02AssistanceMode.values.first,
          assistanceKg: 20,
        ),
        'tempo': B02TechniqueFields(
          tempoEccentricSeconds: 3,
          tempoBottomPauseSeconds: 1,
          tempoConcentricSeconds: 1,
          tempoLockoutPauseSeconds: 0,
        ),
        'paused': B02TechniqueFields(
          pausedRepPosition: B02PausedRepPosition.bottom,
          pausedRepSeconds: 2,
        ),
        'drop': B02TechniqueFields(
          isDropSet: true,
          segments: [
            B02SetSegment(ordinal: 0, reps: 6, externalLoadKg: 80),
            B02SetSegment(ordinal: 1, reps: 4, externalLoadKg: 60),
          ],
        ),
      };
      for (final MapEntry(key: id, value: technique) in techniques.entries) {
        final result = TrainingBests.evaluate(
          history: history,
          current: [
            _entry(null, 10, [_set(id, 80, 10, technique: technique)]),
          ],
        );
        expect(result.bests, isEmpty, reason: id);
      }

      // Persisted segments are flagged by ID, since the rows can't say which
      // technique they were.
      final segmented = TrainingBests.evaluate(
        history: history,
        current: [
          _entry(null, 10, [_set('seg', 80, 10)], segmentedSetIds: {'seg'}),
        ],
      );
      expect(segmented.bests, isEmpty);

      // And an assisted set in history doesn't raise the bar either.
      final assistedHistory = TrainingBests.evaluate(
        history: [
          _entry(1, 1, [
            _set('h', 60, 8),
            _set('h-assisted', 90, 8, technique: techniques['assisted']),
          ]),
        ],
        current: [
          _entry(null, 10, [_set('a', 62.5, 8)]),
        ],
      );
      expect(assistedHistory.bests.single.previous.setId, 'h');
    });

    test('load bases are never compared with each other', () {
      final result = TrainingBests.evaluate(
        history: [
          _entry(1, 1, [_set('h', 60, 8)]),
        ],
        current: [
          _entry(null, 10, [
            _set('a', 40, 8, basis: B02LoadBasis.perSide),
            _set('b', 45, 8, basis: B02LoadBasis.perSide),
          ]),
        ],
      );

      // Per side is a first time: a baseline, even though 45 > 40.
      expect(result.bests, isEmpty);
      expect(result.baselineExerciseIds, {'leg-press'});
    });

    test('a substitution counts toward the exercise actually performed', () {
      final result = TrainingBests.evaluate(
        history: [
          _entry(1, 1, [_set('squat', 100, 5)], exerciseId: 'back-squat'),
          _entry(2, 2, [_set('h', 60, 8)]),
        ],
        current: [
          // Planned as back squat, performed as leg press.
          _entry(null, 10, [_set('a', 80, 8)]),
        ],
      );

      final best = result.bests.single;
      expect(best.exerciseId, 'leg-press');
      expect(best.previous.setId, 'h');
    });

    test('135 lb twice is not a best (lb → kg rounding tolerance)', () {
      final result = TrainingBests.evaluate(
        history: [
          _entry(1, 1, [_set('h', 61.2349, 8)]),
        ],
        current: [
          _entry(null, 10, [_set('a', 61.235, 8), _set('b', 61.3, 8)]),
        ],
      );

      expect(result.bests, isEmpty);
    });

    test('within a workout a set must also beat earlier sets today', () {
      final result = TrainingBests.evaluate(
        history: [
          _entry(1, 1, [_set('h', 60, 8)]),
        ],
        current: [
          _entry(null, 10, [
            _set('s1', 62.5, 8, ordinal: 0),
            _set('s2', 62.5, 8, ordinal: 1),
            _set('s3', 65, 8, ordinal: 2),
          ]),
        ],
      );

      expect(result.bests.map((best) => best.setId), ['s1', 's3']);
      expect(result.bests.last.previous.loadKg, 62.5);
      expect(result.bests.last.previous.setId, isIn(['s1', 's2']));
    });

    test('one badge per set: Heaviest wins over Most reps', () {
      final result = TrainingBests.evaluate(
        history: [
          _entry(1, 1, [_set('h', 60, 8)]),
        ],
        current: [
          _entry(null, 10, [_set('a', 65, 12)]),
        ],
      );

      expect(result.bests.single.kind, TrainingBestKind.heaviest);
    });

    test('deleting the session that held a best re-derives the old one', () {
      final older = _entry(1, 1, [_set('h1', 60, 8)]);
      final heldBest = _entry(2, 2, [_set('h2', 65, 8)]);
      final today = [
        _entry(null, 10, [_set('a', 62.5, 8)]),
      ];

      expect(
        TrainingBests.evaluate(
          history: [older, heldBest],
          current: today,
        ).bests,
        isEmpty,
      );
      final afterDelete = TrainingBests.evaluate(
        history: [older],
        current: today,
      );
      expect(afterDelete.bests.single.previous.setId, 'h1');
    });

    test('editing a logged set re-derives its badge', () {
      final history = [
        _entry(1, 1, [_set('h', 60, 8)]),
      ];
      expect(
        TrainingBests.evaluate(
          history: history,
          current: [
            _entry(null, 10, [_set('a', 62.5, 8)]),
          ],
        ).bests,
        hasLength(1),
      );
      expect(
        TrainingBests.evaluate(
          history: history,
          current: [
            _entry(null, 10, [_set('a', 60, 8)]),
          ],
        ).bests,
        isEmpty,
      );
    });

    test('bodyweight: more reps is a best; added load must be above 0', () {
      final history = [
        _entry(1, 1, [_set('h', null, 8, basis: B02LoadBasis.bodyweight)]),
      ];
      final reps = TrainingBests.evaluate(
        history: history,
        current: [
          _entry(null, 10, [
            _set('a', null, 10, basis: B02LoadBasis.bodyweight),
          ]),
        ],
      );
      expect(reps.bests.single.kind, TrainingBestKind.mostReps);
      expect(
        TrainingBestsCopy.line(reps.bests.single),
        '10 reps at bodyweight (was 8)',
      );

      final added = TrainingBests.evaluate(
        history: history,
        current: [
          _entry(null, 10, [_set('b', 10, 6, basis: B02LoadBasis.bodyweight)]),
        ],
      );
      expect(added.bests.single.kind, TrainingBestKind.heaviest);
      expect(
        TrainingBestsCopy.line(added.bests.single),
        'Heaviest: BW + 10 kg × 6 (was Bodyweight × 8)',
      );

      final zero = TrainingBests.evaluate(
        history: history,
        current: [
          _entry(null, 10, [_set('c', 0, 8, basis: B02LoadBasis.bodyweight)]),
        ],
      );
      expect(zero.bests, isEmpty);
    });

    test('300 sessions evaluate in under 50 ms', () {
      final history = [
        for (var session = 0; session < 300; session++)
          _entry(session, session % 28 + 1, [
            for (var set = 0; set < 4; set++)
              _set(
                's$session-$set',
                40 + (session % 50) * 0.5,
                6 + set,
                ordinal: set,
              ),
          ]),
      ];
      final today = [
        for (var exercise = 0; exercise < 5; exercise++)
          _entry(null, 28, [
            for (var set = 0; set < 4; set++)
              _set('t$exercise-$set', 66 + set * 2.5, 8, ordinal: set),
          ], exerciseOrdinal: exercise),
      ];
      // Warm the JIT once so the measurement is the algorithm, not compile.
      TrainingBests.evaluate(history: history, current: today);
      TrainingBests.bestEver(history);

      final stopwatch = Stopwatch()..start();
      final result = TrainingBests.evaluate(history: history, current: today);
      TrainingBests.bestEver(history);
      stopwatch.stop();

      expect(result.bests, isNotEmpty);
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });
  });

  group('TrainingBests.bestEver', () {
    test('heaviest, then most reps at lighter top weights, with dates', () {
      final records = TrainingBests.bestEver([
        _entry(1, 1, [_set('a', 60, 10), _set('b', 55, 12)]),
        _entry(2, 5, [_set('c', 62.5, 8), _set('d', 60, 9)]),
        _entry(3, 9, [_set('e', 62.5, 8), _set('f', 50, 11)]),
      ]);

      final record = records.single;
      expect(record.basis, B02LoadBasis.totalExternal);
      expect(record.heaviest.setId, 'c', reason: 'first time 62.5 × 8');
      expect(record.heaviest.performedAt, _day(5));
      expect(record.mostReps.map((fact) => fact.setId), ['a', 'b']);
      expect(TrainingBestsCopy.setLabel(record.mostReps.first), '60 kg × 10');
    });
  });

  group('TrainingBestsSessionRead', () {
    late AppDatabase database;
    late B02ExercisePerformanceReadRepository repository;

    setUp(() async {
      database = AppDatabase.memory();
      repository = B02ExercisePerformanceReadRepository(database);
    });

    tearDown(() => database.close());

    test('judges a saved session only against sessions before it; '
        'a partial session counts', () async {
      final first = await insertStrengthSession(
        database,
        name: 'Legs A',
        completedAt: _day(1),
        completionKind: 'partial',
        sets: const [(60.0, 10)],
      );
      final second = await insertStrengthSession(
        database,
        name: 'Legs B',
        completedAt: _day(3),
        sets: const [(62.5, 8), (60.0, 11)],
      );
      final third = await insertStrengthSession(
        database,
        name: 'Legs C',
        completedAt: _day(5),
        sets: const [(70.0, 5)],
      );

      final firstResult = await TrainingBestsSessionRead.read(
        repository,
        first,
      );
      expect(firstResult.bests, isEmpty);
      expect(firstResult.baselineExerciseIds, {'leg-press'});

      final secondResult = await TrainingBestsSessionRead.read(
        repository,
        second,
      );
      expect(secondResult.bests.map(TrainingBestsCopy.line), [
        'Heaviest: 62.5 kg × 8 (was 60 kg × 10)',
        '11 reps at 60 kg (was 10)',
      ]);
      expect(secondResult.bests.first.exerciseName, 'Leg press');

      // Session C exists, but never changes what session B earned.
      expect(
        (await TrainingBestsSessionRead.read(
          repository,
          third,
        )).bests.single.previous.loadKg,
        62.5,
      );
    });
  });
}

DateTime _day(int day) => DateTime.utc(2026, 9, day, 9);

TrainingBestsEntry _entry(
  int? sessionId,
  int day,
  List<B02PerformedSet> sets, {
  String exerciseId = 'leg-press',
  int exerciseOrdinal = 0,
  Set<String> segmentedSetIds = const {},
}) => TrainingBestsEntry(
  sessionId: sessionId,
  completedAt: _day(day),
  actualExerciseId: exerciseId,
  actualExerciseName: 'Leg press',
  exerciseOrdinal: exerciseOrdinal,
  sets: sets,
  segmentedSetIds: segmentedSetIds,
);

B02PerformedSet _set(
  String id,
  double? loadKg,
  int reps, {
  int ordinal = 0,
  B02SetRole role = B02SetRole.working,
  B02LoadBasis basis = B02LoadBasis.totalExternal,
  B02TechniqueFields? technique,
}) => B02PerformedSet(
  id: id,
  performedExerciseId: 'performed-$id',
  ordinal: ordinal,
  role: role,
  actualLoadKg: loadKg,
  actualLoadBasis: basis,
  actualReps: reps,
  technique: technique,
);

/// Inserts one saved strength session with Leg press working sets.
Future<int> insertStrengthSession(
  AppDatabase database, {
  required String name,
  required DateTime completedAt,
  required List<(double, int)> sets,
  String completionKind = 'full',
  String exerciseId = 'leg-press',
}) async {
  final exists = await (database.select(
    database.exercises,
  )..where((table) => table.stableId.equals(exerciseId))).get();
  if (exists.isEmpty) {
    await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: Value(exerciseId),
            name: 'Leg press',
            muscleGroups: 'Legs',
            equipment: 'Machine',
            difficulty: 'Beginner',
            formCues: '',
            commonMistakes: '',
          ),
        );
  }
  final sessionId = await database
      .into(database.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          name: name,
          totalVolume: 0,
          durationSeconds: 600,
          estimatedCalories: 0,
          completedAt: Value(completedAt),
          completionKind: Value(completionKind),
          activityType: Value(B02ActivityType.strength.dbValue),
          activitySchemaVersion: const Value(1),
        ),
      );
  final performedId = 'performed-$sessionId';
  await database
      .into(database.performedExercises)
      .insert(
        PerformedExercisesCompanion.insert(
          id: performedId,
          sessionId: sessionId,
          ordinal: 0,
          actualExerciseId: exerciseId,
          actualExerciseNameSnapshot: 'Leg press',
          status: const Value('completed'),
        ),
      );
  for (var index = 0; index < sets.length; index++) {
    final (load, reps) = sets[index];
    await database
        .into(database.performedSets)
        .insert(
          PerformedSetsCompanion.insert(
            id: '$performedId-set-$index',
            performedExerciseId: performedId,
            ordinal: index,
            role: B02SetRole.working.dbValue,
            actualLoadKg: Value(load),
            actualLoadBasis: Value(B02LoadBasis.totalExternal.dbValue),
            actualReps: Value(reps),
          ),
        );
  }
  return sessionId;
}
