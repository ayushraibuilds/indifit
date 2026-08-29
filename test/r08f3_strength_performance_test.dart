import 'package:drift/drift.dart' hide isNull;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/models/progress_dashboard_models.dart';
import 'package:indifit/data/repositories/b02_exercise_performance_read_repository.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/features/exercise_library/exercise_history_screen.dart';
import 'package:indifit/features/progress/progress_screen.dart';
import 'package:indifit/features/progress/r08f3_strength_performance_presentation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;

  setUp(() {
    database = AppDatabase.memory();
  });

  tearDown(() => database.close());

  test(
    'presentation keeps exact session evidence and only compares matching facts',
    () {
      final summary = R08F3StrengthPerformancePresentation.summarize([
        _record(
          sessionId: 1,
          performedExerciseId: 'performed-1',
          completedAt: DateTime.utc(2026, 8, 1, 9),
          loadKg: 80,
          reps: 5,
        ),
        _record(
          sessionId: 2,
          performedExerciseId: 'performed-2',
          completedAt: DateTime.utc(2026, 8, 8, 9),
          loadKg: 90,
          reps: 5,
          completionKind: 'partial',
          expectedExerciseId: 'planned-bench',
          expectedExerciseName: 'Planned bench press',
        ),
      ]);

      expect(summary.sessionCount, 2);
      expect(summary.occurrenceCount, 2);
      expect(summary.canShowTrend, isTrue);
      expect(summary.trendPoints.map((point) => point.loadKg), [80, 90]);
      expect(summary.trendPoints.map((point) => point.reps), [5, 5]);
      expect(summary.comparisonText, '+10 kg at 5 reps vs previous session');
      expect(summary.heaviestRecordedSet!.actualLoadKg, 90);
      expect(summary.partialSessionCount, 1);
      expect(summary.latestRecord!.wasSubstituted, isTrue);
      expect(
        R08F3StrengthPerformancePresentation.formatActualSet(
          summary.latestRecordedSet!,
        ),
        'Set 2 · 90 kg × 5',
      );
    },
  );

  test('comparison finds the prior set with the same reps and load basis', () {
    final previous = _record(
      sessionId: 1,
      performedExerciseId: 'previous',
      completedAt: DateTime.utc(2026, 8, 1, 9),
      loadKg: 80,
      reps: 5,
      sets: [
        B02PerformedSet(
          id: 'previous-five',
          performedExerciseId: 'previous',
          ordinal: 0,
          role: B02SetRole.working,
          actualLoadKg: 80,
          actualLoadBasis: B02LoadBasis.totalExternal,
          actualReps: 5,
        ),
        B02PerformedSet(
          id: 'previous-one',
          performedExerciseId: 'previous',
          ordinal: 1,
          role: B02SetRole.working,
          actualLoadKg: 100,
          actualLoadBasis: B02LoadBasis.totalExternal,
          actualReps: 1,
        ),
      ],
    );
    final current = _record(
      sessionId: 2,
      performedExerciseId: 'current',
      completedAt: DateTime.utc(2026, 8, 8, 9),
      loadKg: 85,
      reps: 5,
    );

    final summary = R08F3StrengthPerformancePresentation.summarize([
      previous,
      current,
    ]);

    expect(summary.comparisonText, '+5 kg at 5 reps vs previous session');
  });

  testWidgets(
    'canonical history shows actual trend, partial state, and replacement provenance',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      final sourceRecords = await tester.runAsync(() async {
        await database
            .into(database.exercises)
            .insert(
              ExercisesCompanion.insert(
                stableId: const Value('actual-bench'),
                name: 'Bench press',
                muscleGroups: 'Chest',
                equipment: 'Barbell',
                difficulty: 'Intermediate',
                formCues: 'Brace',
                commonMistakes: 'Bounce',
              ),
            );
        await database
            .into(database.exercises)
            .insert(
              ExercisesCompanion.insert(
                stableId: const Value('planned-bench'),
                name: 'Planned bench press',
                muscleGroups: 'Chest',
                equipment: 'Barbell',
                difficulty: 'Intermediate',
                formCues: 'Brace',
                commonMistakes: 'Bounce',
              ),
            );
        await _insertCanonicalPerformance(
          database,
          sessionName: 'Push day',
          completedAt: DateTime.utc(2026, 8, 1, 9),
          performedExerciseId: 'performed-1',
          loadKg: 80,
          reps: 5,
        );
        await _insertCanonicalPerformance(
          database,
          sessionName: 'Push day · replacement',
          completedAt: DateTime.utc(2026, 8, 8, 9),
          performedExerciseId: 'performed-2',
          loadKg: 90,
          reps: 5,
          completionKind: 'partial',
          exerciseStatus: 'partial',
          expectedExerciseId: 'planned-bench',
          expectedExerciseName: 'Planned bench press',
        );
        return B02ExercisePerformanceReadRepository(
          database,
        ).read(stableExerciseId: 'actual-bench');
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            b02ExercisePerformanceReadRepositoryProvider.overrideWithValue(
              _FakePerformanceRepository(database, sourceRecords!),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const ExerciseHistoryScreen(
              exerciseName: 'Bench press',
              stableExerciseId: 'actual-bench',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Actual performance'), findsOneWidget);
      expect(find.text('Recorded load over sessions'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.single.spots.map((spot) => spot.y), [
        80,
        90,
      ]);
      expect(find.textContaining('Aug 1: 80 kg × 5 reps'), findsOneWidget);
      expect(
        find.textContaining('Aug 8: 90 kg × 5 reps (partial session)'),
        findsOneWidget,
      );
      expect(find.text('Partially complete'), findsOneWidget);
      expect(
        find.text('Performed instead of Planned bench press'),
        findsOneWidget,
      );
      expect(find.text('Set 1 · Warm-up · 60 kg × 5'), findsOneWidget);
      expect(find.text('Set 2 · 80 kg × 5'), findsOneWidget);
      expect(find.text('Set 1 · Warm-up · 70 kg × 5'), findsOneWidget);
      expect(find.text('Set 2 · 90 kg × 5'), findsWidgets);
      expect(find.textContaining('e1RM'), findsNothing);
      expect(find.textContaining('1RM'), findsNothing);
      expect(find.textContaining('PR'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('canonical history dates use the Progress snapshot timezone', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    final records = [
      _record(
        sessionId: 1,
        performedExerciseId: 'performed-1',
        completedAt: DateTime.utc(2026, 8, 1, 12, 30),
        loadKg: 80,
        reps: 5,
      ),
      _record(
        sessionId: 2,
        performedExerciseId: 'performed-2',
        completedAt: DateTime.utc(2026, 8, 8, 12, 30),
        loadKg: 82,
        reps: 5,
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          b02ExercisePerformanceReadRepositoryProvider.overrideWithValue(
            _FakePerformanceRepository(database, records),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ExerciseHistoryScreen(
            exerciseName: 'Bench press',
            stableExerciseId: 'actual-bench',
            timezoneId: 'Pacific/Kiritimati',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Aug 2: 80 kg × 5 reps'), findsOneWidget);
    expect(find.textContaining('Aug 9: 82 kg × 5 reps'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'stable canonical query does not fall back to name-based legacy history',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            workoutRepositoryProvider.overrideWithValue(
              _ThrowingWorkoutRepository(database),
            ),
            b02ExercisePerformanceReadRepositoryProvider.overrideWithValue(
              _FakePerformanceRepository(database, const []),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ExerciseHistoryScreen(
              exerciseName: 'Bench press',
              stableExerciseId: 'actual-bench',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('No performance logged yet'), findsOneWidget);
      expect(find.text('Earlier workout records'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Progress keeps multiple exact exercise choices available before history',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      final snapshot = ProgressDashboardSnapshot(
        nowUtc: DateTime.utc(2026, 8, 9, 12),
        timezoneId: 'Asia/Kolkata',
        todayLocalDate: '2026-08-09',
        measurements: const [],
        workouts: const [],
        strengthSets: [
          _progressSet('bench-set', 'bench', 'Bench press', 90, 5),
          _progressSet('row-set', 'row', 'Chest-supported row', 70, 8),
        ],
        muscleBalance: null,
        unavailableSections: const {},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ProgressScreen(preview: snapshot),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Saved actual sets from strength sessions.'),
        findsOneWidget,
      );
      expect(find.text('Bench press'), findsWidgets);
      expect(find.text('Chest-supported row'), findsWidgets);
      expect(find.textContaining('e1RM'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('history remains usable at narrow width and large text', (
    tester,
  ) async {
    _setViewport(tester, const Size(320, 568));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          b02ExercisePerformanceReadRepositoryProvider.overrideWithValue(
            _FakePerformanceRepository(database, [
              _record(
                sessionId: 1,
                performedExerciseId: 'performed-1',
                completedAt: DateTime.utc(2026, 8, 1, 9),
                loadKg: 20,
                reps: 10,
                basis: B02LoadBasis.perImplement,
              ),
              _record(
                sessionId: 2,
                performedExerciseId: 'performed-2',
                completedAt: DateTime.utc(2026, 8, 8, 9),
                loadKg: 22,
                reps: 8,
                basis: B02LoadBasis.perImplement,
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: const TextScaler.linear(1.8),
              disableAnimations: true,
            ),
            child: const ExerciseHistoryScreen(
              exerciseName: 'Dumbbell row',
              stableExerciseId: 'actual-row',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Recorded load over sessions'), findsOneWidget);
    expect(find.textContaining('per implement'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('repeated occurrences in one session are never charted as sessions', () {
    final completedAt = DateTime.utc(2026, 8, 8, 9);
    final summary = R08F3StrengthPerformancePresentation.summarize([
      _record(
        sessionId: 1,
        performedExerciseId: 'performed-1',
        completedAt: completedAt,
        loadKg: 80,
        reps: 5,
      ),
      _record(
        sessionId: 1,
        performedExerciseId: 'performed-2',
        completedAt: completedAt,
        loadKg: 75,
        reps: 8,
      ),
    ]);

    expect(summary.sessionCount, 1);
    expect(summary.occurrenceCount, 2);
    expect(summary.hasMultipleOccurrencesPerSession, isTrue);
    expect(summary.canShowTrend, isFalse);
  });
}

class _FakePerformanceRepository extends B02ExercisePerformanceReadRepository {
  _FakePerformanceRepository(super.database, this.records);

  final List<B02ExercisePerformanceRecord> records;

  @override
  Future<List<B02ExercisePerformanceRecord>> read({
    required String stableExerciseId,
  }) async => records;
}

class _ThrowingWorkoutRepository extends WorkoutRepository {
  _ThrowingWorkoutRepository(super.database);

  @override
  Future<List<Map<String, dynamic>>> getExerciseHistory(String exerciseName) =>
      throw StateError('Legacy name history must not be queried.');
}

B02ExercisePerformanceRecord _record({
  required int sessionId,
  required String performedExerciseId,
  required DateTime completedAt,
  required double loadKg,
  required int reps,
  B02LoadBasis basis = B02LoadBasis.totalExternal,
  String completionKind = 'full',
  String? expectedExerciseId,
  String? expectedExerciseName,
  List<B02PerformedSet>? sets,
}) => B02ExercisePerformanceRecord(
  sessionId: sessionId,
  performedExerciseId: performedExerciseId,
  sessionName: sessionId == 1 ? 'Push day' : 'Push day · replacement',
  completedAt: completedAt,
  completionKind: completionKind,
  actualExerciseId: 'actual-bench',
  expectedExerciseId: expectedExerciseId,
  expectedExerciseName: expectedExerciseName,
  exerciseStatus: completionKind == 'partial' ? 'partial' : 'completed',
  exerciseOrdinal: 0,
  sets:
      sets ??
      [
        B02PerformedSet(
          id: '$performedExerciseId-warmup',
          performedExerciseId: performedExerciseId,
          ordinal: 0,
          role: B02SetRole.warmup,
          actualLoadKg: loadKg - 20,
          actualLoadBasis: basis,
          actualReps: reps,
        ),
        B02PerformedSet(
          id: '$performedExerciseId-working',
          performedExerciseId: performedExerciseId,
          ordinal: 1,
          role: B02SetRole.working,
          actualLoadKg: loadKg,
          actualLoadBasis: basis,
          actualReps: reps,
        ),
      ],
);

ProgressStrengthSetRecord _progressSet(
  String id,
  String exerciseId,
  String exerciseName,
  double loadKg,
  int reps,
) => ProgressStrengthSetRecord(
  performedSetId: id,
  exerciseId: exerciseId,
  exerciseName: exerciseName,
  completedAtUtc: DateTime.utc(2026, 8, 8, 9),
  localDate: '2026-08-08',
  loadKg: loadKg,
  reps: reps,
  loadBasis: 'totalExternal',
);

Future<void> _insertCanonicalPerformance(
  AppDatabase database, {
  required String sessionName,
  required DateTime completedAt,
  required String performedExerciseId,
  required double loadKg,
  required int reps,
  String completionKind = 'full',
  String exerciseStatus = 'completed',
  String? expectedExerciseId,
  String? expectedExerciseName,
}) async {
  final sessionId = await database
      .into(database.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          name: sessionName,
          totalVolume: loadKg * reps,
          durationSeconds: 600,
          estimatedCalories: 0,
          completedAt: Value(completedAt),
          completionKind: Value(completionKind),
          activityType: const Value('strength'),
          activitySchemaVersion: const Value(1),
        ),
      );
  await database
      .into(database.performedExercises)
      .insert(
        PerformedExercisesCompanion.insert(
          id: performedExerciseId,
          sessionId: sessionId,
          ordinal: 0,
          expectedExerciseId: Value(expectedExerciseId),
          expectedExerciseNameSnapshot: Value(expectedExerciseName),
          actualExerciseId: 'actual-bench',
          actualExerciseNameSnapshot: 'Bench press',
          status: Value(exerciseStatus),
        ),
      );
  await database
      .into(database.performedSets)
      .insert(
        PerformedSetsCompanion.insert(
          id: '$performedExerciseId-warmup',
          performedExerciseId: performedExerciseId,
          ordinal: 0,
          role: B02SetRole.warmup.dbValue,
          actualLoadKg: Value(loadKg - 20),
          actualLoadBasis: const Value('totalExternal'),
          actualReps: Value(reps),
        ),
      );
  await database
      .into(database.performedSets)
      .insert(
        PerformedSetsCompanion.insert(
          id: '$performedExerciseId-working',
          performedExerciseId: performedExerciseId,
          ordinal: 1,
          role: B02SetRole.working.dbValue,
          actualLoadKg: Value(loadKg),
          actualLoadBasis: const Value('totalExternal'),
          actualReps: Value(reps),
        ),
      );
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
}
