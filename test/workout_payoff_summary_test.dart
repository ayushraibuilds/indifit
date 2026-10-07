import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/core_providers.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/indifit_haptics.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/core/widgets/confetti_overlay.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/features/training/weekly_training_goal_providers.dart';
import 'package:indifit/features/workout_player/widgets/b02_summary_widgets.dart';
import 'package:indifit/features/workout_player/widgets/workout_payoff_widgets.dart';
import 'package:indifit/features/workout_player/workout_celebration_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TP-6 (summary as the payoff) and the summary half of TP-7 (count-up,
/// reduce motion).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final haptics = <IndiFitHapticType>[];

  setUp(() {
    haptics.clear();
    IndiFitHaptics.debugHandler = haptics.add;
  });

  tearDown(() => IndiFitHaptics.debugHandler = null);

  group('headline', () {
    Future<void> pumpDraft(
      WidgetTester tester,
      List<B02PerformedSet> sets, {
      int elapsedSeconds = 2700,
      CompletionKind kind = CompletionKind.full,
      bool reduceMotion = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: Scaffold(
              body: CompletionEvidence(
                launch: _launch(sets, elapsedSeconds: elapsedSeconds),
                completionKind: kind,
                onDone: () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('one line of numbers: kg lifted, sets, duration', (
      tester,
    ) async {
      await pumpDraft(tester, [_set('a', 80, 8), _set('b', 80, 8, ordinal: 1)]);
      await tester.pumpAndSettle();

      expect(find.text('Workout complete'), findsOneWidget);
      expect(find.text('1,280 kg lifted · 2 sets · 45 min'), findsOneWidget);
    });

    testWidgets('partial, one set and no duration', (tester) async {
      await pumpDraft(
        tester,
        [_set('a', 60, 8)],
        elapsedSeconds: 0,
        kind: CompletionKind.partial,
      );
      await tester.pumpAndSettle();

      expect(find.text('Workout partially completed'), findsOneWidget);
      expect(find.text('480 kg lifted · 1 set'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('bodyweight only: no kg lifted and no Total lifted tile', (
      tester,
    ) async {
      await pumpDraft(tester, [
        _set('a', null, 12, basis: B02LoadBasis.bodyweight),
        _set('b', null, 10, basis: B02LoadBasis.bodyweight, ordinal: 1),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('2 sets · 45 min'), findsOneWidget);
      expect(find.textContaining('kg lifted'), findsNothing);
      expect(find.text('Total lifted'), findsNothing);
    });

    testWidgets('the check uses the brand colour', (tester) async {
      await pumpDraft(tester, [_set('a', 60, 8)]);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(CompletionEvidence));
      final icon = tester.widget<Icon>(
        find.byKey(const ValueKey('workout_summary_check')),
      );
      expect(icon.icon, Icons.check_circle_rounded);
      expect(icon.color, context.b05Colors.action);
    });

    testWidgets('numbers count up once with normal motion', (tester) async {
      await pumpDraft(tester, [_set('a', 80, 8), _set('b', 80, 8, ordinal: 1)]);

      expect(find.text('0 kg'), findsOneWidget);
      expect(find.text('0 kg lifted · 2 sets · 45 min'), findsOneWidget);
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('1,280 kg'), findsOneWidget);
      expect(find.text('1,280 kg lifted · 2 sets · 45 min'), findsOneWidget);
    });

    testWidgets('reduce motion shows the final numbers on the first frame', (
      tester,
    ) async {
      await pumpDraft(tester, [
        _set('a', 80, 8),
        _set('b', 80, 8, ordinal: 1),
      ], reduceMotion: true);

      expect(find.text('1,280 kg'), findsOneWidget);
      expect(find.text('1,280 kg lifted · 2 sets · 45 min'), findsOneWidget);
      expect(find.text('0 kg'), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('Total lifted', () {
    test('groups thousands and keeps decimals', () {
      expect(formatKgLifted(0), '0 kg');
      expect(formatKgLifted(62.5), '62.5 kg');
      expect(formatKgLifted(1440), '1,440 kg');
      expect(formatKgLifted(1234567.25), '1,234,567.25 kg');
    });

    testWidgets('counts working sets only; drop sets by segment', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompletionEvidence(
              launch: _launch([
                _set('a', 100, 5), // 500
                _set('w', 40, 10, role: B02SetRole.warmup, ordinal: 1),
                _set(
                  'd',
                  50,
                  14,
                  ordinal: 2,
                  technique: B02TechniqueFields(
                    isDropSet: true,
                    segments: [
                      B02SetSegment(ordinal: 0, reps: 8, externalLoadKg: 50),
                      B02SetSegment(ordinal: 1, reps: 6, externalLoadKg: 40),
                    ],
                  ),
                ), // 400 + 240
                _set(
                  'b',
                  null,
                  12,
                  ordinal: 3,
                  basis: B02LoadBasis.bodyweight,
                ), // no external load
              ]),
              onDone: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total lifted'), findsOneWidget);
      expect(find.text('1,140 kg'), findsOneWidget);
      expect(find.text('External volume'), findsNothing);
    });
  });

  group('saved summary', () {
    late AppDatabase database;
    late SharedPreferences prefs;

    setUp(() async {
      database = AppDatabase.memory();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() => database.close());

    /// Saves "Legs" twice: 60 × 8, then [today]. Returns today's session.
    Future<int> seed(WidgetTester tester, List<(double, int)> today) async =>
        (await tester.runAsync(() async {
          await _insertSession(database, 1, DateTime.utc(2026, 10, 5, 9), [
            (60, 8),
          ]);
          return _insertSession(
            database,
            2,
            DateTime.utc(2026, 10, 7, 9),
            today,
          );
        }))!;

    Future<void> pumpSummary(
      WidgetTester tester,
      int sessionId, {
      required WeeklyTrainingGoalStatus goal,
      bool? sheetWillOpen = false,
      bool reduceMotion = false,
    }) async {
      tester.view.physicalSize = const Size(390, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            sharedPreferencesProvider.overrideWithValue(prefs),
            weeklyTrainingGoalStatusProvider.overrideWith((ref) async => goal),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduceMotion),
              child: Scaffold(
                body: B02WorkoutCompletionSuccess(
                  launch: _launch(const []),
                  sessionId: sessionId,
                  onDone: () {},
                  allowCelebration: true,
                  achievementSheetWillOpen: sheetWillOpen,
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    testWidgets('blocks follow the plan order', (tester) async {
      final session = await seed(tester, const [(62.5, 8)]);
      await pumpSummary(tester, session, goal: _goal(completed: 2));
      await tester.pumpAndSettle();

      double top(Finder finder) => tester.getTopLeft(finder).dy;
      final order = [
        find.text('Workout complete'),
        find.byKey(const ValueKey('workout_summary_headline_stats')),
        find.byKey(const ValueKey('workout_summary_new_bests')),
        find.byKey(const ValueKey('workout_summary_vs_last_time')),
        find.byKey(const Key('workout_summary_week_goal')),
        find.text('Total lifted'),
        find.text('What you logged'),
      ];
      for (final finder in order) {
        expect(finder, findsOneWidget);
      }
      for (var i = 1; i < order.length; i++) {
        expect(top(order[i]), greaterThan(top(order[i - 1])));
      }
      expect(find.text('Leg press: +2.5 kg on top set'), findsOneWidget);
      expect(find.text('2 of 3 workouts this week'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a new best is celebrated once, and not again on reopen', (
      tester,
    ) async {
      final session = await seed(tester, const [(62.5, 8)]);
      await pumpSummary(tester, session, goal: _goal(completed: 2));

      expect(
        find.byKey(const ValueKey('workout_summary_celebration')),
        findsOneWidget,
      );
      expect(find.byType(ConfettiOverlay), findsOneWidget);
      expect(haptics, [IndiFitHapticType.success]);
      expect(WorkoutCelebrationStore.hasCelebrated(prefs, session), isTrue);
      await tester.pumpAndSettle();
      await unmount(tester);

      await pumpSummary(tester, session, goal: _goal(completed: 2));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('workout_summary_new_bests')),
        findsOneWidget,
      );
      expect(find.byType(ConfettiOverlay), findsNothing);
      expect(haptics, [IndiFitHapticType.success]);
      await unmount(tester);
    });

    testWidgets('a best and the week goal together are one celebration', (
      tester,
    ) async {
      final session = await seed(tester, const [(62.5, 8)]);
      await pumpSummary(tester, session, goal: _goal(completed: 3));
      await tester.pump();

      expect(find.byType(ConfettiOverlay), findsOneWidget);
      expect(haptics, [IndiFitHapticType.success]);
      // The bests are the moment; the week goal stays a plain line.
      expect(
        find.byKey(const ValueKey('workout_summary_week_goal_moment')),
        findsNothing,
      );
      expect(
        find.text('Week goal done · 3 of 3 workouts this week'),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      await unmount(tester);
    });

    testWidgets('without a best, meeting the week goal is the moment', (
      tester,
    ) async {
      final session = await seed(tester, const [(60, 8)]);
      await pumpSummary(tester, session, goal: _goal(completed: 3));

      expect(
        find.byKey(const ValueKey('workout_summary_new_bests')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('workout_summary_week_goal_moment')),
        findsOneWidget,
      );
      expect(
        find.text('Week goal done · 3 of 3 workouts this week'),
        findsOneWidget,
      );
      expect(find.byType(ConfettiOverlay), findsOneWidget);
      expect(haptics, [IndiFitHapticType.success]);
      expect(find.text('Leg press: same as last time'), findsOneWidget);
      await tester.pumpAndSettle();
      await unmount(tester);
    });

    testWidgets('no best and no week goal: nothing to celebrate', (
      tester,
    ) async {
      final session = await seed(tester, const [(57.5, 8)]);
      await pumpSummary(tester, session, goal: _goal(completed: 2));
      await tester.pumpAndSettle();

      expect(find.byType(ConfettiOverlay), findsNothing);
      expect(haptics, isEmpty);
      expect(WorkoutCelebrationStore.hasCelebrated(prefs, session), isFalse);
      expect(find.text('Leg press: -2.5 kg on top set'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('an achievement sheet takes the burst; the block stays still', (
      tester,
    ) async {
      final session = await seed(tester, const [(62.5, 8)]);
      await pumpSummary(
        tester,
        session,
        goal: _goal(completed: 2),
        sheetWillOpen: true,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('workout_summary_new_bests')),
        findsOneWidget,
      );
      expect(find.byType(ConfettiOverlay), findsNothing);
      expect(WorkoutCelebrationStore.hasCelebrated(prefs, session), isTrue);
      await unmount(tester);
    });

    testWidgets('waits while it is unknown whether a sheet will open', (
      tester,
    ) async {
      final session = await seed(tester, const [(62.5, 8)]);
      await pumpSummary(
        tester,
        session,
        goal: _goal(completed: 2),
        sheetWillOpen: null,
      );
      await tester.pumpAndSettle();

      expect(find.byType(ConfettiOverlay), findsNothing);
      expect(haptics, isEmpty);
      expect(WorkoutCelebrationStore.hasCelebrated(prefs, session), isFalse);
      await unmount(tester);
    });

    testWidgets('reduce motion: celebrated without animation, numbers final', (
      tester,
    ) async {
      final session = await seed(tester, const [(62.5, 8)]);
      await pumpSummary(
        tester,
        session,
        goal: _goal(completed: 2),
        reduceMotion: true,
      );

      expect(find.byType(ConfettiOverlay), findsNothing);
      expect(haptics, [IndiFitHapticType.success]);
      expect(WorkoutCelebrationStore.hasCelebrated(prefs, session), isTrue);
      expect(find.text('500 kg'), findsOneWidget);
      expect(find.text('500 kg lifted · 1 set · 10 min'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      await unmount(tester);
    });
  });

  test('the celebrated list keeps the newest 200 sessions', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    for (var id = 1; id <= 205; id++) {
      await WorkoutCelebrationStore.markCelebrated(prefs, id);
    }

    expect(prefs.getStringList(WorkoutCelebrationStore.key), hasLength(200));
    expect(WorkoutCelebrationStore.hasCelebrated(prefs, 5), isFalse);
    expect(WorkoutCelebrationStore.hasCelebrated(prefs, 6), isTrue);
    expect(WorkoutCelebrationStore.hasCelebrated(prefs, 205), isTrue);
  });
}

WeeklyTrainingGoalStatus _goal({required int completed}) =>
    WeeklyTrainingGoalStatus(
      weekStartLocalDate: '2026-10-05',
      completed: completed,
      goal: 3,
      weeksInARow: 0,
      source: WeeklyTrainingGoalSource.user,
      trainedLocalDates: const {'2026-10-05', '2026-10-07'},
    );

B02StrengthExecutionLaunch _launch(
  List<B02PerformedSet> sets, {
  int elapsedSeconds = 2700,
}) => B02StrengthExecutionLaunch(
  draftId: 1,
  occurrenceId: null,
  executionSnapshotJson: '{"version":1}',
  state: B02ExecutionDraftState(
    snapshotId: 'payoff-snapshot',
    snapshotVersion: 1,
    activityType: B02ActivityType.strength,
    routineName: 'Legs',
    elapsedSeconds: elapsedSeconds,
    currentExerciseOrdinal: 0,
    currentSetOrdinal: 0,
    performedExercises: [
      if (sets.isNotEmpty)
        B02PerformedExerciseDraft(
          id: 'pe-1',
          ordinal: 0,
          actualExerciseId: 'leg-press',
          actualExerciseNameSnapshot: 'Leg press',
          status: 'completed',
          sets: sets,
        ),
    ],
  ),
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
  performedExerciseId: 'pe-1',
  ordinal: ordinal,
  role: role,
  actualLoadKg: loadKg,
  actualLoadBasis: basis,
  actualReps: reps,
  technique: technique,
);

Future<int> _insertSession(
  AppDatabase database,
  int index,
  DateTime completedAt,
  List<(double, int)> sets,
) async {
  if (index == 1) {
    await database
        .into(database.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('leg-press'),
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
          name: 'Legs',
          totalVolume: sets.fold<double>(
            0,
            (sum, set) => sum + set.$1 * set.$2,
          ),
          durationSeconds: 600,
          estimatedCalories: 0,
          completedAt: Value(completedAt),
          completionKind: const Value('full'),
          activityType: Value(B02ActivityType.strength.dbValue),
          activitySchemaVersion: const Value(1),
        ),
      );
  await database
      .into(database.performedExercises)
      .insert(
        PerformedExercisesCompanion.insert(
          id: 'performed-$index',
          sessionId: sessionId,
          ordinal: 0,
          actualExerciseId: 'leg-press',
          actualExerciseNameSnapshot: 'Leg press',
          status: const Value('completed'),
        ),
      );
  for (var i = 0; i < sets.length; i++) {
    await database
        .into(database.performedSets)
        .insert(
          PerformedSetsCompanion.insert(
            id: 'set-$index-$i',
            performedExerciseId: 'performed-$index',
            ordinal: i,
            role: B02SetRole.working.dbValue,
            actualLoadKg: Value(sets[i].$1),
            actualLoadBasis: Value(B02LoadBasis.totalExternal.dbValue),
            actualReps: Value(sets[i].$2),
          ),
        );
  }
  return sessionId;
}
