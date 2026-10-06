import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/config/app_preferences_keys.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/models/progress_dashboard_models.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/weekly_training_goal_repository.dart';
import 'package:indifit/features/dashboard/widgets/today_module_widgets.dart';
import 'package:indifit/features/progress/widgets/progress_sections.dart';
import 'package:indifit/features/training/training_screen.dart';
import 'package:indifit/features/training/weekly_training_goal_providers.dart';
import 'package:indifit/features/workout_player/b02_strength_summary_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/indifit_test_harness.dart';

/// PR-M (TP-5): the weekly goal on Training, Progress and the summary. No
/// daily streak on training surfaces.
void main() {
  initializeIndiFitTestHarness();

  setUp(setIndiFitTestPreferences);

  WeeklyTrainingGoalStatus status({
    int completed = 2,
    int goal = 3,
    int weeksInARow = 4,
    WeeklyTrainingGoalSource source = WeeklyTrainingGoalSource.user,
  }) => WeeklyTrainingGoalStatus(
    weekStartLocalDate: '2026-10-05',
    completed: completed,
    goal: goal,
    weeksInARow: weeksInARow,
    source: source,
    trainedLocalDates: {'2026-10-05', '2026-10-06'},
  );

  TrainingLandingSnapshot snapshot(WeeklyTrainingGoalStatus? goal) =>
      TrainingLandingSnapshot(
        localDate: '2026-10-07',
        timezoneId: 'Asia/Kolkata',
        todayWorkout: null,
        upcoming: const [],
        recentSessions: const [],
        activeProgramName: null,
        weeklyGoal: goal,
      );

  Future<void> pumpTraining(
    WidgetTester tester,
    WeeklyTrainingGoalStatus goal, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingLandingSnapshotProvider.overrideWith(
            (ref) async => snapshot(goal),
          ),
          ...overrides,
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const TrainingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectNoDailyStreak() {
    expect(find.byType(StreakChip), findsNothing);
    expect(find.textContaining(RegExp('streak|days logged')), findsNothing);
  }

  group('Training week card', () {
    testWidgets('shows "2 of 3" and "4 weeks in a row" with no daily streak', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpTraining(tester, status());

      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.text('2 of 3'), findsOneWidget);
      expect(find.text('workouts this week'), findsOneWidget);
      expect(find.text('4 weeks in a row'), findsOneWidget);
      expect(find.byKey(const ValueKey('training_week_goal_ring')), findsOne);
      expect(
        find.bySemanticsLabel('2 of 3 workouts this week. 4 weeks in a row'),
        findsOneWidget,
      );
      // Trained days get a filled tick and say so.
      expect(
        find.bySemanticsLabel(RegExp(r'^Monday, 5: workout saved')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
      expectNoDailyStreak();
      semantics.dispose();
    });

    testWidgets('hides the run line at 0', (tester) async {
      await pumpTraining(tester, status(completed: 0, weeksInARow: 0));

      expect(find.text('0 of 3'), findsOneWidget);
      expect(find.textContaining('in a row'), findsNothing);
    });

    testWidgets('a plan goal has no goal sheet', (tester) async {
      await pumpTraining(tester, status(source: WeeklyTrainingGoalSource.plan));

      expect(find.text('2 of 3'), findsOneWidget);
      expect(find.byTooltip('Change weekly goal'), findsNothing);
    });

    testWidgets('the goal sheet saves a goal from 1 to 7', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final repository = WeeklyTrainingGoalRepository(
        sessionTimes: () async => const [],
        preferences: () async => prefs,
        dates: LocalScheduleDateService(
          nowUtc: () => DateTime.utc(2026, 10, 7, 6),
        ),
      );
      await pumpTraining(
        tester,
        status(),
        overrides: [
          weeklyTrainingGoalRepositoryProvider.overrideWithValue(repository),
        ],
      );

      await tester.tap(find.byTooltip('Change weekly goal').first);
      await tester.pumpAndSettle();
      expect(find.text('Weekly goal'), findsOneWidget);
      for (var goal = 1; goal <= 7; goal++) {
        expect(
          find.byKey(ValueKey('training_week_goal_option_$goal')),
          findsOneWidget,
        );
      }
      await tester.tap(
        find.byKey(const ValueKey('training_week_goal_option_5')),
      );
      await tester.pump();
      await tester.tap(find.text('Save goal'));
      await tester.pumpAndSettle();

      expect(prefs.getInt(AppPreferenceKeys.trainingWeekGoal), 5);
      expect(find.text('Weekly goal'), findsNothing);
    });
  });

  testWidgets('Progress training consistency leads with the week goal', (
    tester,
  ) async {
    final progress = ProgressDashboardSnapshot(
      nowUtc: DateTime.utc(2026, 10, 7, 6),
      timezoneId: 'Asia/Kolkata',
      todayLocalDate: '2026-10-07',
      measurements: const [],
      workouts: [
        for (final (id, date) in [(1, '2026-10-05'), (2, '2026-10-06')])
          ProgressWorkoutRecord(
            id: id,
            name: 'Full body',
            completedAtUtc: DateTime.parse('${date}T06:00:00Z'),
            localDate: date,
            activityType: 'strength',
            totalVolumeKg: 1000,
            workingSetsCount: 6,
          ),
      ],
      strengthSets: const [],
      muscleBalance: null,
      unavailableSections: const {},
    );
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TrainingConsistencySection(
              snapshot: progress,
              onViewHistory: () {},
              weeklyGoal: status(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.text('workouts this week · 4 weeks in a row'), findsOneWidget);
    expect(
      find.bySemanticsLabel('2 of 3 workouts this week. 4 weeks in a row.'),
      findsOneWidget,
    );
    expect(find.textContaining('completed this week'), findsNothing);
    expectNoDailyStreak();
    semantics.dispose();
  });

  group('Workout summary', () {
    Future<void> pumpSummary(
      WidgetTester tester,
      WeeklyTrainingGoalStatus goal,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            b02StrengthHistoryDetailProvider(
              7,
            ).overrideWith((ref) async => null),
            weeklyTrainingGoalStatusProvider.overrideWith((ref) async => goal),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: B02WorkoutCompletionSuccess(
                launch: _launch(),
                sessionId: 7,
                onDone: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows "2 of 3 workouts this week" and no daily streak', (
      tester,
    ) async {
      await pumpSummary(tester, status());

      expect(find.text('2 of 3 workouts this week'), findsOneWidget);
      expect(find.textContaining('Week goal done'), findsNothing);
      expectNoDailyStreak();
    });

    testWidgets('says "Week goal done" when this workout meets the goal', (
      tester,
    ) async {
      await pumpSummary(tester, status(completed: 3));

      expect(
        find.text('Week goal done · 3 of 3 workouts this week'),
        findsOneWidget,
      );
    });
  });
}

B02StrengthExecutionLaunch _launch() => B02StrengthExecutionLaunch(
  draftId: 1,
  occurrenceId: null,
  executionSnapshotJson: '{"version":1}',
  state: B02ExecutionDraftState(
    snapshotId: 'pr-m-snapshot',
    snapshotVersion: 1,
    activityType: B02ActivityType.strength,
    routineName: 'Full body',
    elapsedSeconds: 600,
    currentExerciseOrdinal: 0,
    currentSetOrdinal: 0,
    performedExercises: const [],
  ),
);
