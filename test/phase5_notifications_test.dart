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
  });
}
