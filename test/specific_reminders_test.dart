import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/services/notification_service.dart';
import 'package:indifit/core/utils/weekly_training_goal_calculator.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/features/progress/training_bests.dart';
import 'package:indifit/features/training/workout_reminder_content.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// TP-12 (PR-Q): workout reminders name the next session and last time's
/// top set, and a one-off evening line says how far the week goal is.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TrainingBestsSetFact topSet(
    String exercise,
    double kg,
    int reps, {
    B02LoadBasis basis = B02LoadBasis.totalExternal,
  }) => TrainingBestsSetFact(
    setId: 'set',
    exerciseId: exercise.toLowerCase(),
    exerciseName: exercise,
    basis: basis,
    loadKg: kg,
    reps: reps,
    performedAt: DateTime.utc(2026, 10, 6),
  );

  WeeklyTrainingGoalStatus week(int completed, int goal) =>
      WeeklyTrainingGoalStatus(
        weekStartLocalDate: '2026-10-05',
        completed: completed,
        goal: goal,
        weeksInARow: 0,
        source: WeeklyTrainingGoalSource.user,
      );

  group('reminder copy', () {
    test('names the next session and last time\'s top set', () {
      expect(
        WorkoutReminderCopy.body(
          WorkoutReminderFacts(
            nextSessionName: 'Full Body B',
            lastTopSet: topSet('Leg Press', 60, 8),
          ),
        ),
        'Next up: Full Body B. Last time: Leg Press 60 kg × 8.',
      );
    });

    test('says only what it knows', () {
      expect(
        WorkoutReminderCopy.body(
          WorkoutReminderFacts(lastTopSet: topSet('Squat', 62.5, 5)),
        ),
        'Last time: Squat 62.5 kg × 5.',
      );
      expect(
        WorkoutReminderCopy.body(
          WorkoutReminderFacts(
            lastTopSet: topSet(
              'Pull-up',
              0,
              10,
              basis: B02LoadBasis.bodyweight,
            ),
          ),
        ),
        'Last time: Pull-up bodyweight × 10.',
      );
      expect(
        WorkoutReminderCopy.body(const WorkoutReminderFacts()),
        WorkoutReminderCopy.fallbackBody,
      );
    });

    test('the week-goal line only when the goal is still reachable', () {
      String? nudge(
        int completed,
        int goal,
        int weekday, {
        bool trained = false,
      }) => WorkoutReminderCopy.weekGoalNudge(
        WorkoutReminderFacts(
          weekGoal: week(completed, goal),
          todayWeekday: weekday,
        ),
        trainedToday: trained,
      );

      expect(
        nudge(2, 3, DateTime.friday),
        '1 more workout to hit this week\'s goal.',
      );
      expect(
        nudge(1, 3, DateTime.saturday),
        '2 more workouts to hit this week\'s goal.',
      );
      // Met: nothing to nag about.
      expect(nudge(3, 3, DateTime.friday), isNull);
      // Three left with one day to go, at one workout a day: not reachable.
      expect(nudge(0, 3, DateTime.sunday), isNull);
      // Already trained today.
      expect(nudge(2, 3, DateTime.friday, trained: true), isNull);
    });
  });

  group('reading the facts', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.memory());
    tearDown(() => db.close());

    test(
      'without a plan, last time is the latest workout\'s top set',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await _insertExercise(db);
        await _insertSession(db, 1, DateTime.utc(2026, 9, 20), 60, 10);
        await _insertSession(db, 2, DateTime.utc(2026, 9, 22), 62.5, 8);

        final facts = await WorkoutReminderFactsReader.read(
          db,
          prefs,
          timezones: LocalTimezoneService(read: () async => 'Asia/Kolkata'),
        );

        expect(facts.nextSessionName, isNull);
        expect(
          WorkoutReminderCopy.body(facts),
          'Last time: Leg press 62.5 kg × 8.',
        );
        expect(facts.weekGoal, isNotNull);
      },
    );
  });

  group('scheduling', () {
    late AppDatabase db;
    late List<MethodCall> calls;

    setUpAll(() {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    });

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async {
              calls.add(call);
              return true;
            },
          );
      db = AppDatabase.memory();
    });

    tearDown(() async {
      NotificationService.workoutReminderTextSource = null;
      await db.close();
    });

    List<Map<String, Object?>> scheduled() => [
      for (final call in calls)
        if (call.method == 'zonedSchedule')
          Map<String, Object?>.from(call.arguments as Map),
    ];

    test('the workout reminder carries the specific text', () async {
      SharedPreferences.setMockInitialValues({
        NotificationService.prefRemindWorkout: true,
        NotificationService.prefWorkoutReminderDays: ['1', '4'],
      });
      NotificationService.workoutReminderTextSource =
          (db, prefs, {required trainedToday}) async =>
              const WorkoutReminderText(
                body: 'Next up: Full Body B. Last time: Leg Press 60 kg × 8.',
              );

      await NotificationService.scheduleAllReminders(db);

      final workout = scheduled();
      expect(workout, hasLength(2));
      for (final args in workout) {
        expect(
          args['body'],
          'Next up: Full Body B. Last time: Leg Press 60 kg × 8.',
        );
      }
    });

    test('a failing source keeps the plain reminder', () async {
      SharedPreferences.setMockInitialValues({
        NotificationService.prefRemindWorkout: true,
        NotificationService.prefWorkoutReminderDays: ['2'],
      });
      NotificationService.workoutReminderTextSource =
          (db, prefs, {required trainedToday}) async =>
              throw StateError('calendar unavailable');

      await NotificationService.scheduleAllReminders(db);

      expect(scheduled().single['body'], WorkoutReminderCopy.fallbackBody);
    });

    test('the week-goal line is a one-off for this evening', () async {
      final now = tz.TZDateTime.now(tz.local);
      final later = now.add(const Duration(minutes: 5));
      // Needs a time still ahead today; skip in the last minutes of the day.
      if (later.day != now.day) return;
      SharedPreferences.setMockInitialValues({
        NotificationService.prefRemindWorkout: true,
        NotificationService.prefWorkoutReminderDays: ['3'],
        NotificationService.prefDailyLoggingReminderHour: later.hour,
        NotificationService.prefDailyLoggingReminderMinute: later.minute,
        NotificationService.prefQuietHoursEnabled: false,
      });
      NotificationService.workoutReminderTextSource =
          (db, prefs, {required trainedToday}) async =>
              const WorkoutReminderText(
                body: 'Next up: Full Body B.',
                weekGoalNudge: '1 more workout to hit this week\'s goal.',
              );

      await NotificationService.scheduleAllReminders(db);

      final nudge = scheduled().singleWhere(
        (args) => args['body'] == '1 more workout to hit this week\'s goal.',
      );
      expect(nudge['id'], 600);
      // No repeat: the count is only true today.
      expect(nudge['matchDateTimeComponents'], isNull);
      final at = DateTime.parse(nudge['scheduledDateTime']! as String);
      expect((at.year, at.month, at.day), (now.year, now.month, now.day));
    });
  });
}

Future<void> _insertExercise(AppDatabase database) => database
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

Future<int> _insertSession(
  AppDatabase database,
  int index,
  DateTime completedAt,
  double loadKg,
  int reps,
) async {
  final sessionId = await database
      .into(database.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          name: 'Legs $index',
          totalVolume: loadKg * reps,
          durationSeconds: 1800,
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
  await database
      .into(database.performedSets)
      .insert(
        PerformedSetsCompanion.insert(
          id: 'set-$index',
          performedExerciseId: 'performed-$index',
          ordinal: 0,
          role: B02SetRole.working.dbValue,
          actualLoadKg: Value(loadKg),
          actualLoadBasis: Value(B02LoadBasis.totalExternal.dbValue),
          actualReps: Value(reps),
        ),
      );
  return sessionId;
}
