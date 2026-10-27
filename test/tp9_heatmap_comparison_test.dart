import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/plus/plus_gate.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/progress_period_comparison_repository.dart';
import 'package:indifit/features/progress/plus/muscle_heatmap.dart';
import 'package:indifit/features/progress/plus/progress_plus_section.dart';
import 'package:indifit/features/progress/plus/range_comparison.dart';
import 'package:indifit/features/training/muscles_this_week.dart';

class _Plus implements PlusEntitlement {
  const _Plus();

  @override
  bool get isActive => true;
}

/// TP-9 (Plus): 12-week muscle heatmap and month / custom comparison.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dates = LocalScheduleDateService();

  group('week bucketing', () {
    test('12 Mondays ending with this week, oldest first', () {
      // Wednesday 14 Oct 2026.
      final starts = MuscleHeatmapWeeks.starts(
        '2026-10-14',
        timezoneId: 'Asia/Kolkata',
        dates: dates,
      );
      expect(starts, hasLength(12));
      expect(starts.first, '2026-07-27');
      expect(starts.last, '2026-10-12');
      for (final start in starts) {
        expect(dates.weekday(start, 'Asia/Kolkata'), DateTime.monday);
      }
    });

    test('stays on Mondays across a DST change', () {
      // UK clocks go back on Sun 25 Oct 2026.
      final starts = MuscleHeatmapWeeks.starts(
        '2026-11-04',
        timezoneId: 'Europe/London',
        dates: dates,
      );
      expect(starts.sublist(9), ['2026-10-19', '2026-10-26', '2026-11-02']);
    });

    test('a Sunday belongs to the week that started on Monday', () {
      final starts = MuscleHeatmapWeeks.starts(
        '2026-10-18',
        timezoneId: 'Asia/Kolkata',
        dates: dates,
      );
      expect(starts.last, '2026-10-12');
    });

    test('empty weeks are zero columns; muscles ordered by total', () {
      final heatmap = MuscleHeatmap.fromWeeks(
        weekStarts: const ['2026-10-05', '2026-10-12'],
        weeks: const [
          MuscleSetCounts(
            startLocalDate: '2026-10-05',
            endLocalDate: '2026-10-11',
            sets: {},
            exercises: {},
          ),
          MuscleSetCounts(
            startLocalDate: '2026-10-12',
            endLocalDate: '2026-10-18',
            sets: {'chest': 3, 'back': 4.5},
            exercises: {},
          ),
        ],
        trainingDays: const [0, 2],
      );
      expect(heatmap.muscles, ['back', 'chest']);
      expect(heatmap.sets['chest'], [0, 3]);
      expect(heatmap.maxWeeklySets, 4.5);
      expect(heatmap.isEmpty, isFalse);
    });

    test('the legend uses the same rule wording as Muscles this week', () {
      expect(MuscleHeatmapWeeks.legend, contains(MuscleSetRule.ruleText));
      expect(MuscleSetRule.legend, contains(MuscleSetRule.ruleText));
    });
  });

  group('month periods', () {
    test('last month whole against this month so far', () {
      final request = RangeComparisonRequest.months(
        '2026-10-14',
        timezoneId: 'Asia/Kolkata',
        dates: dates,
      );
      expect(request.first, const CivilRange('2026-09-01', '2026-09-30'));
      expect(request.second, const CivilRange('2026-10-01', '2026-10-14'));
    });

    test('January compares with the previous December', () {
      final request = RangeComparisonRequest.months(
        '2027-01-03',
        timezoneId: 'Asia/Kolkata',
        dates: dates,
      );
      expect(request.first, const CivilRange('2026-12-01', '2026-12-31'));
    });
  });

  group('from saved data', () {
    late AppDatabase db;
    setUp(() async {
      db = AppDatabase.memory();
      await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              stableId: const Value('tp9-squat'),
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
              id: 'tp9-pe-$index',
              sessionId: sessionId,
              ordinal: 0,
              actualExerciseId: 'tp9-squat',
              actualExerciseNameSnapshot: 'Back Squat',
              status: const Value('completed'),
            ),
          );
      for (var i = 0; i < sets; i++) {
        await db
            .into(db.performedSets)
            .insert(
              PerformedSetsCompanion.insert(
                id: 'tp9-set-$index-$i',
                performedExerciseId: 'tp9-pe-$index',
                ordinal: i,
                role: B02SetRole.working.dbValue,
                actualLoadKg: const Value(60),
                actualLoadBasis: Value(B02LoadBasis.totalExternal.dbValue),
                actualReps: const Value(5),
              ),
            );
      }
    }

    Future<void> weighIn(DateTime atUtc, double kg) => db
        .into(db.bodyMeasurements)
        .insert(
          BodyMeasurementsCompanion.insert(
            weight: Value(kg),
            recordedAt: Value(atUtc),
          ),
        );

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

    test('heatmap buckets by Mon–Sun in local time', () async {
      // Sun 11 Oct 23:50 IST: the week of 5 Oct.
      await logSets(DateTime.utc(2026, 10, 11, 18, 20), 1);
      // Mon 12 Oct 00:10 IST: this week.
      await logSets(DateTime.utc(2026, 10, 11, 18, 40), 2);

      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);
      final keep = container.listen(muscleHeatmapProvider, (_, _) {});
      addTearDown(keep.close);
      final heatmap = await container.read(muscleHeatmapProvider.future);
      expect(heatmap.weekStarts.last, '2026-10-12');
      expect(heatmap.muscles, ['legs', 'glutes']);
      expect(heatmap.sets['legs']!.sublist(10), [1, 2]);
      expect(heatmap.sets['glutes']!.sublist(10), [0.5, 1]);
      expect(heatmap.sets['legs']!.sublist(0, 10), everyElement(0));
      expect(heatmap.trainingDays.sublist(10), [1, 1]);
      expect(heatmap.trainingDays.sublist(0, 10), everyElement(0));
    });

    test('nothing saved: an empty heatmap', () async {
      final container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);
      final keep = container.listen(muscleHeatmapProvider, (_, _) {});
      addTearDown(keep.close);
      final heatmap = await container.read(muscleHeatmapProvider.future);
      expect(heatmap.isEmpty, isTrue);
      expect(heatmap.trainingDays, List.filled(12, 0));
    });

    test('sparse periods give nulls, not zeros', () async {
      final repository = ProgressPeriodComparisonRepository(
        database: db,
        dates: dates,
      );
      // September: one weigh-in, no workouts.
      await weighIn(DateTime.utc(2026, 9, 10, 2), 80);
      // October so far: two weigh-ins, one workout.
      await weighIn(DateTime.utc(2026, 10, 2, 2), 79.6);
      await weighIn(DateTime.utc(2026, 10, 9, 2), 79.1);
      await logSets(DateTime.utc(2026, 10, 6, 12), 3);

      Future<PeriodRangeFacts> facts(String start, String end) async =>
          PeriodRangeFacts(
            summary: await repository.summarizeRange(
              startLocalDate: start,
              endLocalDate: end,
              nowUtc: now,
              timezoneId: 'Asia/Kolkata',
            ),
            muscles: const MuscleSetCounts(
              startLocalDate: '',
              endLocalDate: '',
              sets: {},
              exercises: {},
            ),
          );

      final september = await facts('2026-09-01', '2026-09-30');
      expect(september.summary.window.isComplete, isTrue);
      expect(september.summary.window.daysCount, 30);
      expect(september.workouts, 0);
      expect(september.volumeKg, isNull);
      expect(september.weighIns, 1);
      expect(september.weightChangeKg, isNull);
      // No nutrition repository given: unknown, not zero.
      expect(september.daysLogged, isNull);
      expect(september.averageProteinG, isNull);

      final october = await facts('2026-10-01', '2026-10-14');
      expect(october.summary.window.isInProgress, isTrue);
      expect(october.summary.window.inProgressDayIndex, 14);
      expect(october.workouts, 1);
      expect(october.workingSets, 3);
      expect(october.volumeKg, isNotNull);
      expect(october.weightChangeKg, closeTo(-0.5, 0.001));
    });
  });

  group('the Plus gate', () {
    final heatmap = MuscleHeatmap.fromWeeks(
      weekStarts: List.generate(12, (i) => '2026-10-12'),
      weeks: List.generate(
        12,
        (i) => MuscleSetCounts(
          startLocalDate: '2026-10-12',
          endLocalDate: '2026-10-18',
          sets: {'chest': i.toDouble()},
          exercises: const {},
        ),
      ),
      trainingDays: List.filled(12, 1),
    );

    Future<void> pump(WidgetTester tester, {required bool plus}) =>
        tester.pumpWidget(
          ProviderScope(
            overrides: [
              if (plus) ...[
                plusEntitlementProvider.overrideWithValue(const _Plus()),
                plusRemoteEnabledProvider.overrideWithValue(true),
              ],
              muscleHeatmapProvider.overrideWith((ref) async => heatmap),
              activeRangeComparisonProvider.overrideWith(
                (ref) => Completer<RangeComparison>().future,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: ProgressPlusSection(units: 'metric'),
                ),
              ),
            ),
          ),
        );

    testWidgets('hidden when the flag is off', (tester) async {
      await pump(tester, plus: false);
      await tester.pump();
      expect(find.text('Muscles, last 12 weeks'), findsNothing);
      expect(find.text('Compare periods'), findsNothing);
    });

    testWidgets('shown when Plus is on', (tester) async {
      await pump(tester, plus: true);
      await tester.pump();
      expect(find.text('Muscles, last 12 weeks'), findsOneWidget);
      expect(find.text(MuscleHeatmapWeeks.legend), findsOneWidget);
      expect(find.text('Chest'), findsOneWidget);
      expect(find.text('Compare periods'), findsOneWidget);
    });
  });
}
