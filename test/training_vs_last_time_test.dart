import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_exercise_performance_read_repository.dart';
import 'package:indifit/features/progress/training_bests.dart';
import 'package:indifit/features/progress/training_bests_providers.dart';
import 'package:indifit/features/progress/training_vs_last_time.dart';

import 'training_bests_test.dart' show insertStrengthSession;

/// TP-6 "vs last time": one factual line per exercise, comparing today's top
/// set with the last session's top set.
void main() {
  ExerciseVsLastTime? compare(
    List<TrainingBestsEntry> history,
    List<B02PerformedSet> today,
  ) => TrainingVsLastTime.compare(
    exerciseId: 'leg-press',
    exerciseName: 'Leg press',
    history: history,
    current: [_entry(null, 10, today)],
  );

  group('compare', () {
    test('a heavier top set is up, by the load difference', () {
      final line = compare(
        [
          _entry(1, 5, [_set('a', 60, 8), _set('b', 60, 7, ordinal: 1)]),
        ],
        [_set('c', 62.5, 8), _set('d', 50, 12, ordinal: 1)],
      )!;

      expect(line.kind, VsLastTimeKind.up);
      expect(line.loadDeltaKg, 2.5);
      expect(
        TrainingVsLastTimeCopy.line(line),
        'Leg press: +2.5 kg on top set',
      );
      expect(
        TrainingVsLastTimeCopy.detail(line),
        '62.5 kg × 8 (was 60 kg × 8)',
      );
    });

    test('more reps at the same top weight is up, by reps', () {
      final line = compare(
        [
          _entry(1, 5, [_set('a', 60, 8)]),
        ],
        [_set('b', 60, 10)],
      )!;

      expect(line.kind, VsLastTimeKind.up);
      expect(TrainingVsLastTimeCopy.change(line), '+2 reps on top set');
    });

    test('the same top set is "same as last time"', () {
      final line = compare(
        [
          _entry(1, 5, [_set('a', 60, 8)]),
        ],
        [_set('b', 60, 8)],
      )!;

      expect(line.kind, VsLastTimeKind.same);
      expect(TrainingVsLastTimeCopy.line(line), 'Leg press: same as last time');
    });

    test('135 lb twice (61.235 kg vs 61.2 kg) is the same, not up', () {
      final line = compare(
        [
          _entry(1, 5, [_set('a', 61.2, 5)]),
        ],
        [_set('b', 61.235, 5)],
      )!;

      expect(line.kind, VsLastTimeKind.same);
    });

    test('a lighter top set is down, by the load difference', () {
      final line = compare(
        [
          _entry(1, 5, [_set('a', 62.5, 8)]),
        ],
        [_set('b', 60, 10)],
      )!;

      expect(line.kind, VsLastTimeKind.down);
      expect(TrainingVsLastTimeCopy.change(line), '-2.5 kg on top set');
    });

    test('fewer reps at the same top weight is down, by reps', () {
      final line = compare(
        [
          _entry(1, 5, [_set('a', 60, 8)]),
        ],
        [_set('b', 60, 7)],
      )!;

      expect(line.kind, VsLastTimeKind.down);
      expect(TrainingVsLastTimeCopy.change(line), '-1 rep on top set');
    });

    test('no earlier session is the first time', () {
      final line = compare(const [], [_set('a', 60, 8)])!;

      expect(line.kind, VsLastTimeKind.firstTime);
      expect(line.previous, isNull);
      expect(TrainingVsLastTimeCopy.line(line), 'Leg press: first time logged');
    });

    test('"last time" is the most recent earlier session, not the best', () {
      final line = compare(
        [
          _entry(1, 2, [_set('a', 80, 8)]),
          _entry(2, 6, [_set('b', 60, 8)]),
          _entry(3, 4, [_set('c', 70, 8)]),
        ],
        [_set('d', 62.5, 8)],
      )!;

      expect(line.previous!.setId, 'b');
      expect(line.kind, VsLastTimeKind.up);
    });

    test('warm-ups, assisted sets and other load bases are not compared', () {
      final line = compare(
        [
          _entry(1, 5, [
            _set('a', 40, 10),
            _set('w', 100, 5, ordinal: 1, role: B02SetRole.warmup),
            _set('p', 100, 5, ordinal: 2, basis: B02LoadBasis.perSide),
          ]),
        ],
        [
          _set('b', 42.5, 10),
          _set(
            'x',
            120,
            5,
            ordinal: 1,
            technique: B02TechniqueFields(
              assistanceMode: B02AssistanceMode.machine,
              assistanceKg: 20,
            ),
          ),
        ],
      )!;

      expect(line.current!.setId, 'b');
      expect(line.previous!.setId, 'a');
      expect(TrainingVsLastTimeCopy.change(line), '+2.5 kg on top set');
    });

    test('earlier sessions with nothing comparable give no line', () {
      expect(
        compare(
          [
            _entry(1, 5, [_set('a', 60, 8, basis: B02LoadBasis.perSide)]),
          ],
          [_set('b', 60, 8)],
        ),
        isNull,
      );
    });

    test('per-side loads keep their basis in the copy', () {
      final line = compare(
        [
          _entry(1, 5, [_set('a', 20, 8, basis: B02LoadBasis.perSide)]),
        ],
        [_set('b', 22.5, 8, basis: B02LoadBasis.perSide)],
      )!;

      expect(
        TrainingVsLastTimeCopy.change(line),
        '+2.5 kg per side on top set',
      );
    });
  });

  group('session read', () {
    late AppDatabase database;
    late B02ExercisePerformanceReadRepository repository;

    setUp(() {
      database = AppDatabase.memory();
      repository = B02ExercisePerformanceReadRepository(database);
    });

    tearDown(() => database.close());

    test('compares each saved workout only with the one before it', () async {
      final first = await insertStrengthSession(
        database,
        name: 'Legs 1',
        completedAt: DateTime.utc(2026, 9, 20, 9),
        sets: const [(60, 8)],
      );
      final second = await insertStrengthSession(
        database,
        name: 'Legs 2',
        completedAt: DateTime.utc(2026, 9, 22, 9),
        sets: const [(62.5, 8), (60, 8)],
      );
      await insertStrengthSession(
        database,
        name: 'Legs 3',
        completedAt: DateTime.utc(2026, 9, 24, 9),
        sets: const [(70, 8)],
      );

      final firstLines = await TrainingVsLastTimeSessionRead.read(
        repository,
        first,
      );
      final secondLines = await TrainingVsLastTimeSessionRead.read(
        repository,
        second,
      );

      expect(firstLines.single.kind, VsLastTimeKind.firstTime);
      expect(
        TrainingVsLastTimeCopy.line(secondLines.single),
        'Leg press: +2.5 kg on top set',
      );
    });
  });
}

DateTime _day(int day) => DateTime.utc(2026, 9, day, 9);

TrainingBestsEntry _entry(
  int? sessionId,
  int day,
  List<B02PerformedSet> sets,
) => TrainingBestsEntry(
  sessionId: sessionId,
  completedAt: _day(day),
  actualExerciseId: 'leg-press',
  actualExerciseName: 'Leg press',
  sets: sets,
);

B02PerformedSet _set(
  String id,
  double loadKg,
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
