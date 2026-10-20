import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/features/training/training_week_strip.dart';

/// TF-3 (UR-26): Training's week strip uses Today's day cell, pages back
/// through past weeks, and shows a ring and muscle groups per day.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('paging limit', () {
    test('no workouts: this week only', () {
      expect(
        trainingWeekStripWeeksBack(
          currentWeekStart: '2026-10-12',
          firstWeekStart: null,
        ),
        0,
      );
    });
    test('stops at the first week with data', () {
      expect(
        trainingWeekStripWeeksBack(
          currentWeekStart: '2026-10-12',
          firstWeekStart: '2026-09-21',
        ),
        3,
      );
    });
    test('or 12 weeks back, whichever comes first', () {
      expect(
        trainingWeekStripWeeksBack(
          currentWeekStart: '2026-10-12',
          firstWeekStart: '2026-01-05',
        ),
        12,
      );
    });
  });

  group('ring values', () {
    test('done against planned, capped at full', () {
      expect(
        const TrainingStripDay(
          localDate: '2026-10-12',
          plannedSets: 12,
          doneSets: 6,
        ).progress,
        0.5,
      );
      expect(
        const TrainingStripDay(
          localDate: '2026-10-12',
          plannedSets: 6,
          doneSets: 9,
        ).progress,
        1.0,
      );
      const planned = TrainingStripDay(localDate: '2026-10-12', plannedSets: 6);
      expect(planned.progress, 0.0);
      expect(planned.doneMark, isFalse);
    });
    test('nothing planned: a done mark, no ring', () {
      const day = TrainingStripDay(
        localDate: '2026-10-12',
        doneSets: 4,
        workouts: [
          TrainingDayWorkout(sessionId: 1, name: 'Legs', sets: 4, topSet: null),
        ],
      );
      expect(day.progress, isNull);
      expect(day.doneMark, isTrue);
      const rest = TrainingStripDay(localDate: '2026-10-13');
      expect(rest.doneMark, isFalse);
      expect(rest.progress, isNull);
    });
  });

  test('muscle-group labels: the top two groups by sets', () {
    expect(
      trainingMuscleGroupLabel({
        'legs': 3,
        'glutes': 1.5,
        'chest': 2,
        'triceps': 1,
        'shoulders': 1,
      }),
      'Legs · Push',
    );
    expect(trainingMuscleGroupLabel({'back': 3, 'biceps': 1.5}), 'Pull');
    expect(trainingMuscleGroupLabel({}), isNull);
  });

  group('the strip, from saved workouts', () {
    late AppDatabase db;
    var index = 0;

    Future<void> insertExercise(String id, String name, String muscles) => db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: Value(id),
            name: name,
            muscleGroups: muscles,
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: '',
            commonMistakes: '',
          ),
        );

    Future<void> logWorkout(
      String name,
      DateTime completedAtUtc,
      String exerciseId,
      String exerciseName,
      List<(double, int)> sets,
    ) async {
      index++;
      final sessionId = await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              name: name,
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
              id: 'tf3-pe-$index',
              sessionId: sessionId,
              ordinal: 0,
              actualExerciseId: exerciseId,
              actualExerciseNameSnapshot: exerciseName,
              status: const Value('completed'),
            ),
          );
      for (var i = 0; i < sets.length; i++) {
        await db
            .into(db.performedSets)
            .insert(
              PerformedSetsCompanion.insert(
                id: 'tf3-set-$index-$i',
                performedExerciseId: 'tf3-pe-$index',
                ordinal: i,
                role: B02SetRole.working.dbValue,
                actualLoadKg: Value(sets[i].$1),
                actualLoadBasis: Value(B02LoadBasis.totalExternal.dbValue),
                actualReps: Value(sets[i].$2),
              ),
            );
      }
    }

    setUp(() async {
      db = AppDatabase.memory();
      await insertExercise('tf3-squat', 'Back Squat', 'Legs,Glutes');
      await insertExercise(
        'tf3-bench',
        'Bench Press',
        'Chest,Triceps,Shoulders',
      );
    });
    tearDown(() => db.close());

    // Wednesday 14 Oct 2026, 10:00 IST; this week is 12–18 Oct.
    final now = DateTime.utc(2026, 10, 14, 4, 30);

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            localScheduleDateServiceProvider.overrideWithValue(
              LocalScheduleDateService(nowUtc: () => now),
            ),
            localTimezoneServiceProvider.overrideWithValue(
              LocalTimezoneService(read: () async => 'Asia/Kolkata'),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: TrainingWeekStrip(
                  currentWeekStartLocalDate: '2026-10-12',
                  localDate: '2026-10-14',
                  timezoneId: 'Asia/Kolkata',
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('two workouts on Monday, a rest day, and the day sheet', (
      tester,
    ) async {
      await tester.runAsync(() async {
        // Monday 12 Oct, morning and evening IST.
        await logWorkout(
          'Legs',
          DateTime.utc(2026, 10, 12, 2),
          'tf3-squat',
          'Back Squat',
          [(80, 5), (100, 5), (100, 3)],
        );
        await logWorkout(
          'Push',
          DateTime.utc(2026, 10, 12, 13),
          'tf3-bench',
          'Bench Press',
          [(60, 8), (60, 8)],
        );
      });
      await pump(tester);

      final monday = find.byKey(const ValueKey('training-week-day-2026-10-12'));
      expect(
        find.descendant(of: monday, matching: find.text('Legs · Push')),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(monday),
        isSemantics(value: '5 sets done, Legs · Push'),
      );
      final tuesday = find.byKey(
        const ValueKey('training-week-day-2026-10-13'),
      );
      expect(tester.getSemantics(tuesday), isSemantics(value: 'no workout'));

      await tester.tap(monday);
      await settle(tester);
      expect(find.text('Monday 12 October'), findsOneWidget);
      expect(find.text('Legs'), findsOneWidget);
      expect(find.text('Push'), findsOneWidget);
      expect(
        find.text('3 working sets · Top set Back Squat · 100 kg × 5'),
        findsOneWidget,
      );
      expect(
        find.text('2 working sets · Top set Bench Press · 60 kg × 8'),
        findsOneWidget,
      );
      expect(find.text('Open workout'), findsNWidgets(2));
      // Muscles as text chips; no body map in the day sheet.
      expect(find.widgetWithText(Chip, 'Legs 3'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Chest 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('muscles_this_week')), findsNothing);

      Navigator.of(tester.element(find.text('Monday 12 October'))).pop();
      await settle(tester);
      await tester.tap(tuesday);
      await settle(tester);
      expect(find.text('Tuesday 13 October'), findsOneWidget);
      expect(find.text('No workout logged.'), findsOneWidget);
      expect(find.text('Open workout'), findsNothing);
    });

    testWidgets('swipes back to the first week with data, and no further', (
      tester,
    ) async {
      await tester.runAsync(
        () => logWorkout(
          'Legs',
          DateTime.utc(2026, 9, 29, 4),
          'tf3-squat',
          'Back Squat',
          [(80, 5)],
        ),
      );
      await pump(tester);
      Text title() => tester.widget<Text>(
        find.byKey(const ValueKey('training-week-title')),
      );
      final row = find.byKey(const ValueKey('training-week-day-2026-10-14'));
      expect(title().data, '12 Oct – 18 Oct');

      await tester.fling(row, const Offset(300, 0), 1000);
      await settle(tester);
      expect(title().data, '5 Oct – 11 Oct');

      await tester.fling(
        find.byKey(const ValueKey('training-week-day-2026-10-07')),
        const Offset(300, 0),
        1000,
      );
      await settle(tester);
      expect(title().data, '28 Sep – 4 Oct');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('training-week-day-2026-09-29')),
          matching: find.text('Legs'),
        ),
        findsOneWidget,
      );
      // The first week with data: no further back.
      final older = tester.widget<IconButton>(
        find.byKey(const ValueKey('training-week-older')),
      );
      expect(older.onPressed, isNull);
      await tester.fling(
        find.byKey(const ValueKey('training-week-day-2026-09-30')),
        const Offset(300, 0),
        1000,
      );
      await settle(tester);
      expect(title().data, '28 Sep – 4 Oct');

      await tester.tap(find.byKey(const ValueKey('training-week-newer')));
      await settle(tester);
      expect(title().data, '5 Oct – 11 Oct');
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}
