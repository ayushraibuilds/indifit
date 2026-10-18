import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/fixtures/exercise_display_muscles.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_exercise_performance_read_repository.dart';
import 'package:indifit/features/media/indifit_muscle_map.dart';
import 'package:indifit/features/training/muscles_this_week.dart';
import 'package:indifit/features/training/muscles_this_week_card.dart';

/// TF-4: "Muscles this week" (free). Working sets only; primary 1,
/// secondary ½; the bests engine's technique sets left out; Mon–Sun local.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the counting rule', () {
    B02PerformedSet set(
      String id, {
      B02SetRole role = B02SetRole.working,
      int? reps = 8,
      B02TechniqueFields? technique,
    }) => B02PerformedSet(
      id: id,
      performedExerciseId: 'pe',
      ordinal: 0,
      role: role,
      actualReps: reps,
      actualLoadKg: 40,
      actualLoadBasis: B02LoadBasis.totalExternal,
      technique: technique,
    );

    B02ExercisePerformanceRecord record(
      String exerciseId,
      List<B02PerformedSet> sets, {
      Set<String> segmented = const {},
    }) => B02ExercisePerformanceRecord(
      sessionId: 1,
      performedExerciseId: 'pe-$exerciseId',
      sessionName: 'Push',
      completedAt: DateTime.utc(2026, 10, 13),
      actualExerciseId: exerciseId,
      actualExerciseName: exerciseId == 'bench' ? 'Bench Press' : 'Dips',
      exerciseStatus: 'completed',
      exerciseOrdinal: 0,
      sets: sets,
      segmentedSetIds: segmented,
    );

    final muscles = {
      'bench': ExerciseDisplayMuscles.fromMuscleGroups(
        'Chest,Triceps,Shoulders',
      ),
      'dips': ExerciseDisplayMuscles.fromMuscleGroups('Triceps,Chest'),
    };

    MuscleSetCounts count(List<B02ExercisePerformanceRecord> records) =>
        MuscleSetRule.count(
          startLocalDate: '2026-10-12',
          endLocalDate: '2026-10-18',
          records: records,
          musclesByExercise: muscles,
        );

    test('primary 1, secondary ½, summed across exercises', () {
      final counts = count([
        record('bench', [set('a'), set('b'), set('c')]),
        record('dips', [set('d'), set('e')]),
      ]);
      expect(counts.sets, {
        'chest': 3 + 1.0, // 3 primary + 2 × ½
        'triceps': 1.5 + 2, // 3 × ½ + 2 primary
        'shoulders': 1.5,
      });
      expect(counts.exercises['triceps'], ['Bench Press', 'Dips']);
      expect(counts.ranked.first.key, 'chest');
    });

    test('warm-ups, zero reps and technique sets are left out', () {
      final counts = count([
        record(
          'bench',
          [
            set('warm', role: B02SetRole.warmup),
            set('none', reps: 0),
            set(
              'assisted',
              technique: B02TechniqueFields(
                assistanceMode: B02AssistanceMode.machine,
                assistanceKg: 10,
              ),
            ),
            set(
              'tempo',
              technique: B02TechniqueFields(
                tempoEccentricSeconds: 3,
                tempoBottomPauseSeconds: 1,
                tempoConcentricSeconds: 1,
                tempoLockoutPauseSeconds: 0,
              ),
            ),
            set('drop'),
            set('counted'),
          ],
          segmented: {'drop'},
        ),
      ]);
      expect(counts.sets, {'chest': 1, 'triceps': 0.5, 'shoulders': 0.5});
    });

    test('the legend prints the rule', () {
      expect(
        MuscleSetRule.legend,
        'Shaded by working sets this week · primary 1, secondary ½',
      );
      expect(IndiFitMuscleMap.formatSets(4.5), '4½');
      expect(IndiFitMuscleMap.formatSets(0.5), '½');
      expect(
        [0.0, 0.5, 2.5, 3.0, 5.5, 6.0, 9.5, 10.0].map(IndiFitMuscleMap.setStep),
        [0, 1, 1, 2, 2, 3, 3, 4],
      );
    });
  });

  group('the week, from saved workouts', () {
    late AppDatabase db;
    setUp(() async {
      db = AppDatabase.memory();
      await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              stableId: const Value('tf4-squat'),
              name: 'Back Squat',
              muscleGroups: 'Legs,Glutes',
              equipment: 'Barbell',
              difficulty: 'Intermediate',
              formCues: '',
              commonMistakes: '',
            ),
          );
    });
    tearDown(() => db.close());

    var index = 0;
    Future<void> logSets(DateTime completedAtUtc, int sets) async {
      index++;
      final sessionId = await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              name: 'Legs $index',
              totalVolume: 0,
              durationSeconds: 1800,
              estimatedCalories: 0,
              completedAt: Value(completedAtUtc),
              completionKind: const Value('full'),
              activityType: Value(B02ActivityType.strength.dbValue),
              activitySchemaVersion: const Value(1),
            ),
          );
      await db
          .into(db.performedExercises)
          .insert(
            PerformedExercisesCompanion.insert(
              id: 'tf4-pe-$index',
              sessionId: sessionId,
              ordinal: 0,
              actualExerciseId: 'tf4-squat',
              actualExerciseNameSnapshot: 'Back Squat',
              status: const Value('completed'),
            ),
          );
      for (var i = 0; i < sets; i++) {
        await db
            .into(db.performedSets)
            .insert(
              PerformedSetsCompanion.insert(
                id: 'tf4-set-$index-$i',
                performedExerciseId: 'tf4-pe-$index',
                ordinal: i,
                role: B02SetRole.working.dbValue,
                actualLoadKg: const Value(60),
                actualLoadBasis: Value(B02LoadBasis.totalExternal.dbValue),
                actualReps: const Value(5),
              ),
            );
      }
    }

    // Wednesday 14 Oct 2026, 10:00 IST.
    final now = DateTime.utc(2026, 10, 14, 4, 30);
    List<Override> overrides() => [
      databaseProvider.overrideWithValue(db),
      localScheduleDateServiceProvider.overrideWithValue(
        LocalScheduleDateService(nowUtc: () => now),
      ),
      localTimezoneServiceProvider.overrideWithValue(
        LocalTimezoneService(read: () async => 'Asia/Kolkata'),
      ),
    ];

    test('Mon–Sun in local time: edges either side of midnight IST', () async {
      // Sun 11 Oct 23:50 IST: last week.
      await logSets(DateTime.utc(2026, 10, 11, 18, 20), 1);
      // Mon 12 Oct 00:10 IST: this week.
      await logSets(DateTime.utc(2026, 10, 11, 18, 40), 2);
      // Sun 18 Oct 23:50 IST: this week.
      await logSets(DateTime.utc(2026, 10, 18, 18, 20), 4);
      // Mon 19 Oct 00:10 IST: next week.
      await logSets(DateTime.utc(2026, 10, 18, 18, 40), 8);

      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);
      final keep = container.listen(musclesThisWeekProvider, (_, _) {});
      addTearDown(keep.close);
      final counts = await container.read(musclesThisWeekProvider.future);
      expect(counts.startLocalDate, '2026-10-12');
      expect(counts.endLocalDate, '2026-10-18');
      expect(counts.sets, {'legs': 6, 'glutes': 3});
    });

    testWidgets('fills in live after a logged set; empty week first', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: SingleChildScrollView(child: MusclesThisWeekCard()),
            ),
          ),
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await settle();
      expect(find.text('Muscles this week'), findsOneWidget);
      expect(find.text('Train this week to fill your map'), findsOneWidget);
      expect(find.byType(IndiFitMuscleMap), findsOneWidget);
      expect(find.text(MuscleSetRule.legend), findsNothing);

      await tester.runAsync(() => logSets(DateTime.utc(2026, 10, 13, 6), 3));
      await settle();

      expect(find.text('Train this week to fill your map'), findsNothing);
      expect(find.text(MuscleSetRule.legend), findsOneWidget);
      // Counts as a list, not only as shading.
      expect(find.text('Legs'), findsOneWidget);
      expect(find.text('3 sets'), findsOneWidget);
      expect(find.text('Glutes'), findsOneWidget);
      expect(find.text('1½ sets'), findsOneWidget);
      // Each shaded region names its muscle and count.
      expect(find.semantics.byLabel('Legs: 3 working sets'), findsAny);
      expect(find.semantics.byLabel('Glutes: 1½ working sets'), findsAny);

      // Tapping a muscle shows its count and the exercises that hit it.
      await tester.tap(find.byKey(const ValueKey('muscle_count_glutes')));
      await tester.pump();
      final detail = find.byKey(const ValueKey('muscle_detail'));
      expect(
        find.descendant(
          of: detail,
          matching: find.text('Glutes · 1½ working sets'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: detail, matching: find.text('Back Squat')),
        findsOneWidget,
      );

      // The map region does the same through its semantics action.
      expect(
        find.semantics.byLabel('Legs: 3 working sets').evaluate().first,
        isSemantics(hasTapAction: true),
      );
      semantics.dispose();
    });
  });
}
