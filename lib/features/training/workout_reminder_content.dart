import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/local_schedule_date_service.dart';
import '../../core/services/local_timezone_service.dart';
import '../../core/services/notification_service.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/b02_exercise_performance_read_repository.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../../data/repositories/training_next_action_resolver.dart';
import '../../data/repositories/weekly_training_goal_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../progress/training_bests.dart';
import '../progress/training_bests_providers.dart';
import '../progress/training_vs_last_time.dart';
import 'weekly_training_goal_providers.dart';

/// What a workout reminder can say truthfully (TP-12): the plan's next
/// session, last time's top set, and this week's goal.
class WorkoutReminderFacts {
  const WorkoutReminderFacts({
    this.nextSessionName,
    this.lastTopSet,
    this.weekGoal,
    this.todayWeekday,
  });

  /// The plan's current or next session ("Full Body B"); null without a plan.
  final String? nextSessionName;

  /// The top set of the most recent session of the first exercise that has
  /// one: the next session's exercises first, else the last workout's.
  final TrainingBestsSetFact? lastTopSet;
  final WeeklyTrainingGoalStatus? weekGoal;

  /// Today's ISO weekday (Monday = 1), for the week-goal nudge.
  final int? todayWeekday;
}

/// Plain copy for the reminders. Numbers come only from logged sets.
abstract final class WorkoutReminderCopy {
  static const fallbackBody =
      'Open IndiFit when you are ready to start your workout.';

  /// "Next up: Full Body B. Last time: Leg Press 60 kg × 8."
  ///
  /// "Next up" rather than "today": the reminder repeats weekly, and the
  /// next session only changes when a workout is saved or skipped in the
  /// app, which reschedules every reminder.
  static String body(WorkoutReminderFacts facts) {
    final parts = <String>[
      if (facts.nextSessionName case final name? when name.trim().isNotEmpty)
        'Next up: ${name.trim()}.',
      if (facts.lastTopSet case final top?)
        'Last time: ${top.exerciseName} ${_set(top)}.',
    ];
    return parts.isEmpty ? fallbackBody : parts.join(' ');
  }

  /// "1 more workout to hit this week's goal.", or null when the goal is met,
  /// can't be reached at one workout a day, or today already has a workout.
  static String? weekGoalNudge(
    WorkoutReminderFacts facts, {
    required bool trainedToday,
  }) {
    final goal = facts.weekGoal;
    final weekday = facts.todayWeekday;
    if (goal == null || weekday == null || trainedToday) return null;
    final remaining = goal.goal - goal.completed;
    // Days left in the week, today included (weeks run Monday to Sunday).
    final daysLeft = DateTime.sunday - weekday + 1;
    if (remaining < 1 || remaining > daysLeft) return null;
    return remaining == 1
        ? '1 more workout to hit this week\'s goal.'
        : '$remaining more workouts to hit this week\'s goal.';
  }

  /// "60 kg × 8", "bodyweight × 12", "BW + 10 kg × 6".
  static String _set(TrainingBestsSetFact top) =>
      '${TrainingBestsCopy.load(top)} × ${top.reps}';
}

/// Reads [WorkoutReminderFacts] from the database for the reminder
/// scheduler. Any failure leaves that fact out, so the reminder falls back
/// to the plain text instead of saying something unchecked.
abstract final class WorkoutReminderFactsReader {
  static Future<WorkoutReminderFacts> read(
    AppDatabase db,
    SharedPreferences prefs, {
    LocalTimezoneService? timezones,
    LocalScheduleDateService? dates,
  }) async {
    final dateService = dates ?? LocalScheduleDateService();
    final timezoneId = await (timezones ?? LocalTimezoneService())
        .currentTimezoneId();
    final today = dateService.todayIn(timezoneId);
    final weekStart = WeeklyTrainingGoalCalculator.weekStartOf(
      today,
      dates: dateService,
    );
    final weekEnd = dateService.addCalendarDays(weekStart, timezoneId, 6);
    final horizon = dateService.addCalendarDays(today, timezoneId, 14);

    final calendar = await CalendarReadRepository(db, dates: dateService)
        .readSnapshot(
          startLocalDate: weekStart,
          endLocalDate: dateService.compare(horizon, weekEnd) >= 0
              ? horizon
              : weekEnd,
          timezoneId: timezoneId,
        );
    final next = resolveTrainingNextAction(
      snapshot: calendar,
      localDate: today,
    ).dominantScheduledOccurrence;

    final performance = B02ExercisePerformanceReadRepository(db);
    final exerciseIds = next != null
        ? [
            for (final prescription in [
              ...next.prescriptions,
            ]..sort((a, b) => a.ordinal.compareTo(b.ordinal)))
              ?prescription.exerciseId,
          ]
        : await _lastWorkoutExerciseIds(db, performance);
    TrainingBestsSetFact? lastTopSet;
    for (final exerciseId in exerciseIds) {
      final records = await performance.read(stableExerciseId: exerciseId);
      lastTopSet = TrainingVsLastTime.latestTopSet(
        records.map((record) => record.toTrainingBestsEntry()),
      );
      if (lastTopSet != null) break;
    }

    final weekOccurrences = calendar.rangeOccurrences.where(
      (item) =>
          item.occurrence.programVersionId == calendar.activeProgramVersionId &&
          dateService.compare(item.occurrence.effectiveLocalDate, weekStart) >=
              0 &&
          dateService.compare(item.occurrence.effectiveLocalDate, weekEnd) <= 0,
    );
    final weekGoal =
        await WeeklyTrainingGoalRepository(
          sessionTimes: WorkoutRepository(db).getAllSessionDates,
          preferences: () async => prefs,
          dates: dateService,
        ).status(
          timezoneId: timezoneId,
          planGoal: calendar.activeProgramVersionId == null
              ? null
              : trainingPlanWeekGoal(weekOccurrences),
        );

    return WorkoutReminderFacts(
      nextSessionName: next?.template.name,
      lastTopSet: lastTopSet,
      weekGoal: weekGoal,
      todayWeekday: dateService.weekday(today, timezoneId),
    );
  }

  /// The exercises of the most recently saved workout, in workout order.
  static Future<List<String>> _lastWorkoutExerciseIds(
    AppDatabase db,
    B02ExercisePerformanceReadRepository performance,
  ) async {
    final latest =
        await (db.select(db.workoutSessions)
              ..orderBy([
                (row) => OrderingTerm.desc(row.completedAt),
                (row) => OrderingTerm.desc(row.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (latest == null) return const [];
    return performance.readSessionExerciseIds(latest.id);
  }

  /// The source [NotificationService] calls when it reschedules.
  static Future<WorkoutReminderText?> reminderText(
    AppDatabase db,
    SharedPreferences prefs, {
    required bool trainedToday,
  }) async {
    final facts = await read(db, prefs);
    return WorkoutReminderText(
      body: WorkoutReminderCopy.body(facts),
      weekGoalNudge: WorkoutReminderCopy.weekGoalNudge(
        facts,
        trainedToday: trainedToday,
      ),
    );
  }
}
