import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/notification_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/features/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5 Notifications & Deep Link Unit Tests', () {
    late AppDatabase database;
    late List<MethodCall> platformCalls;

    setUpAll(() {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      platformCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async {
              platformCalls.add(call);
              return true;
            },
          );
      database = AppDatabase.memory();
    });

    tearDown(() async => database.close());

    test(
      'NotificationService onNotificationNavigate callback handles payloads correctly',
      () {
        expect(
          NotificationService.destinationForPayload('workout'),
          '/training',
        );
        expect(
          NotificationService.destinationForPayload('meal_lunch'),
          '/food?mealType=lunch',
        );
        expect(
          NotificationService.destinationForPayload('weekly_report'),
          '/progress',
        );
        expect(NotificationService.destinationForPayload('evening_nudge'), '/');
        expect(NotificationService.destinationForPayload('unknown'), isNull);
      },
    );

    test('SharedPreferences preference keys match notification toggles', () {
      expect(NotificationService.prefRemindWorkout, 'pref_remind_workout');
      expect(NotificationService.prefRemindMeals, 'pref_remind_meals');
      expect(NotificationService.prefRemindWater, 'pref_remind_water');
      expect(NotificationService.prefRemindEvening, 'pref_remind_evening');
      expect(NotificationService.prefRemindWeekly, 'pref_remind_weekly');
    });

    test('editable reminder schedules persist and reload exactly', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);
      final controller = container.read(settingsControllerProvider.notifier);

      await controller.updateWorkoutReminderSchedule(
        days: const [DateTime.monday, DateTime.wednesday, DateTime.friday],
        hour: 6,
        minute: 45,
      );
      await controller.updateMealReminderSchedule(
        lunchHour: 12,
        lunchMinute: 15,
        dinnerHour: 19,
        dinnerMinute: 40,
      );
      await controller.updateDailyLoggingReminderSchedule(hour: 20, minute: 5);
      await controller.updateWeeklyProgressSchedule(
        day: DateTime.saturday,
        hour: 9,
        minute: 20,
      );

      final state = container.read(settingsControllerProvider);
      expect(state.workoutReminderDays, [1, 3, 5]);
      expect(state.workoutReminderHour, 6);
      expect(state.workoutReminderMinute, 45);
      expect(state.lunchReminderHour, 12);
      expect(state.lunchReminderMinute, 15);
      expect(state.dinnerReminderHour, 19);
      expect(state.dinnerReminderMinute, 40);
      expect(state.dailyLoggingReminderHour, 20);
      expect(state.dailyLoggingReminderMinute, 5);
      expect(state.weeklyProgressDay, DateTime.saturday);
      expect(state.weeklyProgressHour, 9);
      expect(state.weeklyProgressMinute, 20);

      final prefs = await SharedPreferences.getInstance();
      expect(NotificationService.workoutReminderDaysFromPreferences(prefs), [
        1,
        3,
        5,
      ]);
    });

    test(
      'invalid stored schedule values fail closed to established defaults',
      () async {
        SharedPreferences.setMockInitialValues({
          NotificationService.prefWorkoutReminderDays: ['0', '8', 'bad'],
          NotificationService.prefWorkoutReminderHour: 99,
          NotificationService.prefWeeklyProgressDay: 0,
        });
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(database)],
        );
        addTearDown(container.dispose);
        await container
            .read(settingsControllerProvider.notifier)
            .loadPreferences();

        final state = container.read(settingsControllerProvider);
        expect(
          state.workoutReminderDays,
          NotificationService.defaultWorkoutReminderDays,
        );
        expect(
          state.workoutReminderHour,
          NotificationService.defaultWorkoutReminderHour,
        );
        expect(
          state.weeklyProgressDay,
          NotificationService.defaultWeeklyProgressDay,
        );
      },
    );

    test(
      'runtime schedules one workout reminder per selected weekday',
      () async {
        SharedPreferences.setMockInitialValues({
          NotificationService.prefRemindWorkout: true,
          NotificationService.prefWorkoutReminderDays: ['1', '3', '5'],
          NotificationService.prefWorkoutReminderHour: 6,
          NotificationService.prefWorkoutReminderMinute: 45,
        });

        await NotificationService.scheduleAllReminders(database);

        expect(
          platformCalls.where((call) => call.method == 'zonedSchedule'),
          hasLength(3),
        );
      },
    );

    test(
      'today evidence skips only today while preserving every recurring series',
      () async {
        final now = DateTime.now();
        final localDate =
            '${now.year.toString().padLeft(4, '0')}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}';
        SharedPreferences.setMockInitialValues({
          NotificationService.prefRemindWorkout: true,
          NotificationService.prefWorkoutReminderDays: [now.weekday.toString()],
          NotificationService.prefWorkoutReminderHour: now.hour,
          NotificationService.prefWorkoutReminderMinute: now.minute,
          NotificationService.prefRemindMeals: true,
          NotificationService.prefLunchReminderHour: now.hour,
          NotificationService.prefLunchReminderMinute: now.minute,
          NotificationService.prefDinnerReminderHour: now.hour,
          NotificationService.prefDinnerReminderMinute: now.minute,
          NotificationService.prefRemindEvening: true,
          NotificationService.prefDailyLoggingReminderHour: now.hour,
          NotificationService.prefDailyLoggingReminderMinute: now.minute,
        });

        await database
            .into(database.workoutSessions)
            .insert(
              WorkoutSessionsCompanion.insert(
                name: 'Completed workout',
                totalVolume: 100,
                durationSeconds: 1800,
                estimatedCalories: 0,
                completedAt: Value(now.toUtc()),
              ),
            );
        for (final meal in const ['lunch', 'dinner']) {
          await database
              .into(database.nutritionConsumptionSnapshots)
              .insert(
                NutritionConsumptionSnapshotsCompanion.insert(
                  id: 'today-$meal',
                  userId: 'user',
                  loggedAt: now.toUtc(),
                  mealCategory: meal,
                  sourceType: 'food',
                  calculatorVersion: 'test',
                  completeness: 'complete',
                  estimateStatus: 'none',
                  localDate: Value(localDate),
                  timezoneId: const Value('Asia/Kolkata'),
                ),
              );
        }

        await NotificationService.scheduleAllReminders(database);

        final scheduledCalls = platformCalls
            .where((call) => call.method == 'zonedSchedule')
            .toList();
        expect(scheduledCalls, hasLength(4));
        for (final call in scheduledCalls) {
          final arguments = Map<String, Object?>.from(call.arguments as Map);
          final scheduled = DateTime.parse(
            arguments['scheduledDateTime']! as String,
          );
          expect((
            scheduled.year,
            scheduled.month,
            scheduled.day,
          ), isNot((now.year, now.month, now.day)));
        }
      },
    );

    test(
      'edited reminder times still use the established Quiet Hours rule',
      () {
        expect(NotificationService.isInQuietHours(23, 30, 22, 7), isTrue);
        expect(NotificationService.isInQuietHours(6, 45, 22, 7), isTrue);
        expect(NotificationService.isInQuietHours(7, 0, 22, 7), isFalse);
        expect(NotificationService.isInQuietHours(20, 5, 22, 7), isFalse);
      },
    );

    test(
      'weekly reminders inside overnight Quiet Hours defer to its end',
      () async {
        SharedPreferences.setMockInitialValues({
          NotificationService.prefRemindWeekly: true,
          NotificationService.prefWeeklyProgressDay: DateTime.sunday,
          NotificationService.prefWeeklyProgressHour: 23,
          NotificationService.prefWeeklyProgressMinute: 15,
          NotificationService.prefQuietHoursEnabled: true,
          NotificationService.prefQuietHoursStart: 22,
          NotificationService.prefQuietHoursEnd: 7,
        });

        await NotificationService.scheduleAllReminders(database);

        final call = platformCalls.singleWhere(
          (candidate) => candidate.method == 'zonedSchedule',
        );
        final arguments = Map<String, Object?>.from(call.arguments as Map);
        final scheduled = DateTime.parse(
          arguments['scheduledDateTime']! as String,
        );
        expect(scheduled.weekday, DateTime.monday);
        expect(scheduled.hour, 7);
        expect(scheduled.minute, 0);
      },
    );

    test(
      'scheduleAllReminders uses scoped cancellation and never calls cancelAll',
      () async {
        platformCalls.clear();
        await NotificationService.scheduleAllReminders(database);

        // Assert cancelAll was NEVER called (which would wipe active rest notifications 998/999)
        expect(
          platformCalls.any((call) => call.method == 'cancelAll'),
          isFalse,
          reason: 'cancelAll wipes active workout rest timer notifications',
        );

        // Assert scoped cancel was called for reminder IDs 101-107, 201, 202, 400, 500
        final cancelledIds = platformCalls
            .where((call) => call.method == 'cancel')
            .map((call) => (call.arguments as Map)['id'] as int)
            .toSet();

        for (int day = DateTime.monday; day <= DateTime.sunday; day++) {
          expect(cancelledIds, contains(100 + day));
        }
        expect(cancelledIds, contains(201));
        expect(cancelledIds, contains(202));
        expect(cancelledIds, contains(301));
        expect(cancelledIds, contains(400));
        expect(cancelledIds, contains(500));

        // Rest timer IDs 998 and 999 must NEVER be cancelled by reminder rescheduling
        expect(cancelledIds, isNot(contains(998)));
        expect(cancelledIds, isNot(contains(999)));
      },
    );
  });
}
