import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/config/app_preferences_keys.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/utils/weekly_training_goal_calculator.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/repositories/weekly_training_goal_repository.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/indifit_test_harness.dart';

void main() {
  initializeIndiFitTestHarness();

  late DateTime nowUtc;
  late List<DateTime> sessions;

  WeeklyTrainingGoalRepository repository() => WeeklyTrainingGoalRepository(
    sessionTimes: () async => sessions,
    preferences: SharedPreferences.getInstance,
    dates: LocalScheduleDateService(nowUtc: () => nowUtc),
  );

  setUp(() {
    setIndiFitTestPreferences();
    // Wednesday 7 October 2026, midday in India.
    nowUtc = DateTime.utc(2026, 10, 7, 6, 30);
    sessions = [];
  });

  test('no plan uses the default goal of 3', () async {
    final status = await repository().status(timezoneId: 'Asia/Kolkata');
    expect(status.goal, 3);
    expect(status.source, WeeklyTrainingGoalSource.user);
  });

  test('an active plan sets the goal from its scheduled sessions', () async {
    final repo = repository();
    await repo.setUserGoal(5);

    final fromPlan = await repo.status(timezoneId: 'Asia/Kolkata', planGoal: 3);
    expect(fromPlan.goal, 3);
    expect(fromPlan.source, WeeklyTrainingGoalSource.plan);

    // A plan with nothing scheduled this week falls back to the user's goal.
    final empty = await repo.status(timezoneId: 'Asia/Kolkata', planGoal: 0);
    expect(empty.goal, 5);
    expect(empty.source, WeeklyTrainingGoalSource.user);
  });

  test('the user goal saves 1–7 and clamps outside it', () async {
    final repo = repository();
    for (var goal = 1; goal <= 7; goal++) {
      await repo.setUserGoal(goal);
      expect(await repo.userGoal(), goal);
    }
    await repo.setUserGoal(12);
    expect(await repo.userGoal(), 7);
  });

  test(
    'a goal change mid-week keeps last week judged by its own goal',
    () async {
      final repo = repository();
      // Last week: three workouts against the default goal of 3.
      nowUtc = DateTime.utc(2026, 9, 30, 6, 30);
      sessions = [
        DateTime.utc(2026, 9, 28, 6),
        DateTime.utc(2026, 9, 29, 6),
        DateTime.utc(2026, 10, 1, 6),
      ];
      final lastWeek = await repo.status(timezoneId: 'Asia/Kolkata');
      expect(lastWeek.isMet, isTrue);

      // This week the user raises the goal to 5.
      nowUtc = DateTime.utc(2026, 10, 7, 6, 30);
      await repo.setUserGoal(5);
      final thisWeek = await repo.status(timezoneId: 'Asia/Kolkata');

      expect(thisWeek.goal, 5);
      expect(thisWeek.completed, 0);
      expect(thisWeek.weeksInARow, 1);
      expect(await repo.goalHistory(), {'2026-09-28': 3, '2026-10-05': 5});

      // Changing it again mid-week only moves the current week's entry.
      await repo.setUserGoal(2);
      await repo.status(timezoneId: 'Asia/Kolkata');
      expect(await repo.goalHistory(), {'2026-09-28': 3, '2026-10-05': 2});
    },
  );

  test('the week starts at 00:00 local on Monday', () async {
    sessions = [
      // Sunday 23:59 and Monday 00:00 in India (UTC+5:30).
      DateTime.utc(2026, 10, 4, 18, 29),
      DateTime.utc(2026, 10, 4, 18, 30),
    ];
    final status = await repository().status(timezoneId: 'Asia/Kolkata');
    expect(status.weekStartLocalDate, '2026-10-05');
    expect(status.completed, 1);
    expect(status.trainedLocalDates, {'2026-10-05'});
  });

  test('a DST change does not move a workout across the week line', () async {
    // The UK moves to BST at 01:00 on Sunday 29 March 2026.
    nowUtc = DateTime.utc(2026, 3, 31, 12);
    sessions = [
      DateTime.utc(2026, 3, 29, 22, 30), // Sunday 23:30 BST
      DateTime.utc(2026, 3, 29, 23, 0, 30), // Monday 00:00:30 BST
    ];
    final status = await repository().status(timezoneId: 'Europe/London');
    expect(status.weekStartLocalDate, '2026-03-30');
    expect(status.completed, 1);
  });

  test('a damaged goal history is ignored, not fatal', () async {
    setIndiFitTestPreferences({AppPreferenceKeys.trainingWeekGoals: '{oops'});
    final status = await repository().status(timezoneId: 'Asia/Kolkata');
    expect(status.goal, 3);
    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString(AppPreferenceKeys.trainingWeekGoals)!), {
      '2026-10-05': 3,
    });
  });

  test('session dates include full and partial saved workouts only', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    Future<void> insert(String name, String? kind) => db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            name: name,
            totalVolume: 0,
            durationSeconds: 60,
            estimatedCalories: 0,
            completionKind: Value(kind),
            completedAt: Value(DateTime.utc(2026, 10, 6, 6)),
          ),
        );
    await insert('Full', CompletionKind.full.dbValue);
    await insert('Partial', CompletionKind.partial.dbValue);
    // An unfinished workout lives in drafts and must not count.
    await db
        .into(db.workoutDrafts)
        .insert(
          WorkoutDraftsCompanion.insert(
            routineName: 'Unfinished',
            currentExerciseIndex: 0,
            currentSetIndex: 0,
            elapsedSeconds: 30,
            loggedSetsJson: '[]',
          ),
        );

    sessions = await WorkoutRepository(db).getAllSessionDates();
    final status = await repository().status(timezoneId: 'Asia/Kolkata');
    expect(sessions, hasLength(2));
    expect(status.completed, 2);
  });
}
