import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/database/app_database.dart';
import '../utils/app_logger.dart';
import 'crash_reporting_service.dart';

/// Non-annoying, engagement-optimized local notification service.
///
/// Schedule philosophy:
///   - Workout reminder: On the user's selected weekdays
///   - Meal logging: Twice daily (post-lunch + post-dinner — skips breakfast)
///   - Daily logging reminder: Once daily when food or training is missing
///   - Weekly report: Once per week
///
/// Total: up to five notifications on a day with the weekly report.
/// All configurable via SharedPreferences toggles in Settings screen.
enum NotificationPermissionStatus { granted, denied, unavailable }

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Notification channel IDs
  static const String _workoutChannelId = 'indifit_workout';
  static const String _mealChannelId = 'indifit_meals';
  static const String _nudgeChannelId = 'indifit_nudge';
  static const String _weeklyChannelId = 'indifit_weekly';

  // Notification IDs (unique per scheduled notification)
  static const int _idWorkout = 100;
  static const int _idMealLunch = 201;
  static const int _idMealDinner = 202;
  static const int _idEveningNudge = 400;
  static const int _idWeeklyReport = 500;

  // SharedPreferences keys
  static const String prefRemindWorkout = 'pref_remind_workout';
  static const String prefRemindMeals = 'pref_remind_meals';
  static const String prefRemindWater = 'pref_remind_water';
  static const String prefRemindEvening = 'pref_remind_evening';
  static const String prefRemindWeekly = 'pref_remind_weekly';
  static const String prefQuietHoursEnabled = 'pref_quiet_hours_enabled';
  static const String prefQuietHoursStart = 'pref_quiet_hours_start';
  static const String prefQuietHoursEnd = 'pref_quiet_hours_end';
  static const String prefWorkoutReminderDays = 'pref_workout_reminder_days';
  static const String prefWorkoutReminderHour = 'pref_workout_reminder_hour';
  static const String prefWorkoutReminderMinute =
      'pref_workout_reminder_minute';
  static const String prefLunchReminderHour = 'pref_lunch_reminder_hour';
  static const String prefLunchReminderMinute = 'pref_lunch_reminder_minute';
  static const String prefDinnerReminderHour = 'pref_dinner_reminder_hour';
  static const String prefDinnerReminderMinute = 'pref_dinner_reminder_minute';
  static const String prefDailyLoggingReminderHour =
      'pref_daily_logging_reminder_hour';
  static const String prefDailyLoggingReminderMinute =
      'pref_daily_logging_reminder_minute';
  static const String prefWeeklyProgressDay = 'pref_weekly_progress_day';
  static const String prefWeeklyProgressHour = 'pref_weekly_progress_hour';
  static const String prefWeeklyProgressMinute = 'pref_weekly_progress_minute';

  static const List<int> defaultWorkoutReminderDays = [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];
  static const int defaultWorkoutReminderHour = 7;
  static const int defaultWorkoutReminderMinute = 30;
  static const int defaultLunchReminderHour = 13;
  static const int defaultLunchReminderMinute = 30;
  static const int defaultDinnerReminderHour = 20;
  static const int defaultDinnerReminderMinute = 30;
  static const int defaultDailyLoggingReminderHour = 21;
  static const int defaultDailyLoggingReminderMinute = 15;
  static const int defaultWeeklyProgressDay = DateTime.sunday;
  static const int defaultWeeklyProgressHour = 10;
  static const int defaultWeeklyProgressMinute = 0;

  static Function(String payload)? onNotificationNavigate;

  /// Resolves notification payloads only to currently supported destinations.
  /// The weekly reminder opens factual Progress instead of the retired AI
  /// report surface.
  static String? destinationForPayload(String payload) {
    if (payload == 'workout') return '/training';
    if (payload.startsWith('meal_')) {
      final mealType = payload.replaceFirst('meal_', '');
      return mealType.isEmpty ? '/food' : '/food?mealType=$mealType';
    }
    if (payload == 'weekly_report') return '/progress';
    return null;
  }

  /// Initialize the notification plugin, timezone data, and Android channels.
  static Future<void> initialize() async {
    tz_data.initializeTimeZones();
    await _configureLocalTimeZone();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    debugPrint('NotificationService initialized (just-in-time mode).');
  }

  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    debugPrint('Notification tapped: $payload');
    if (payload != null && onNotificationNavigate != null) {
      onNotificationNavigate!(payload);
    }
  }

  /// Explicitly request notification permissions (just-in-time)
  static Future<bool> requestPermissions() async {
    final androidGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    return (androidGranted ?? false) || (iosGranted ?? false);
  }

  /// Reads the OS notification permission without changing the app's reminder
  /// preferences. Unsupported platforms return [NotificationPermissionStatus
  /// .unavailable] rather than implying that notifications are allowed.
  static Future<NotificationPermissionStatus> checkPermissionStatus() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final enabled = await android.areNotificationsEnabled();
        if (enabled == null) {
          return NotificationPermissionStatus.unavailable;
        }
        return enabled
            ? NotificationPermissionStatus.granted
            : NotificationPermissionStatus.denied;
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final permissions = await ios.checkPermissions();
        if (permissions == null) {
          return NotificationPermissionStatus.unavailable;
        }
        return permissions.isEnabled
            ? NotificationPermissionStatus.granted
            : NotificationPermissionStatus.denied;
      }
    } catch (e, st) {
      AppLogger.warning('notification permission status unavailable: $e');
      CrashReportingService.recordCrash(
        e,
        st,
        reason: 'notification permission status check failed',
      );
    }

    return NotificationPermissionStatus.unavailable;
  }

  /// Show a local push notification when workout rest timer expires
  static Future<void> showRestTimerFinishedNotification() async {
    const androidDetails = AndroidNotificationDetails(
      _workoutChannelId,
      'Workout Reminders',
      channelDescription: 'Workout rest timer & session alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      999,
      'Rest Time Completed! 💪',
      'Time to hit your next set. You got this!',
      details,
      payload: 'workout',
    );
  }

  // ────────────────────────────────────────
  // Schedule orchestrator
  // ────────────────────────────────────────

  /// Re-schedules all enabled reminders. Call after any preference change.
  static Future<void> scheduleAllReminders([AppDatabase? db]) async {
    // Cancel everything first to prevent duplicates on re-schedule
    await _plugin.cancelAll();

    final prefs = await SharedPreferences.getInstance();

    final workoutEnabled = prefs.getBool(prefRemindWorkout) ?? false;
    final mealsEnabled = prefs.getBool(prefRemindMeals) ?? false;
    final eveningEnabled = prefs.getBool(prefRemindEvening) ?? false;
    final weeklyEnabled = prefs.getBool(prefRemindWeekly) ?? false;

    final workoutDays = workoutReminderDaysFromPreferences(prefs);
    final workoutHour = _validHourOrDefault(
      prefs.getInt(prefWorkoutReminderHour),
      defaultWorkoutReminderHour,
    );
    final workoutMinute = _validMinuteOrDefault(
      prefs.getInt(prefWorkoutReminderMinute),
      defaultWorkoutReminderMinute,
    );
    final lunchHour = _validHourOrDefault(
      prefs.getInt(prefLunchReminderHour),
      defaultLunchReminderHour,
    );
    final lunchMinute = _validMinuteOrDefault(
      prefs.getInt(prefLunchReminderMinute),
      defaultLunchReminderMinute,
    );
    final dinnerHour = _validHourOrDefault(
      prefs.getInt(prefDinnerReminderHour),
      defaultDinnerReminderHour,
    );
    final dinnerMinute = _validMinuteOrDefault(
      prefs.getInt(prefDinnerReminderMinute),
      defaultDinnerReminderMinute,
    );
    final dailyLoggingHour = _validHourOrDefault(
      prefs.getInt(prefDailyLoggingReminderHour),
      defaultDailyLoggingReminderHour,
    );
    final dailyLoggingMinute = _validMinuteOrDefault(
      prefs.getInt(prefDailyLoggingReminderMinute),
      defaultDailyLoggingReminderMinute,
    );
    final weeklyDay = _validWeekdayOrDefault(
      prefs.getInt(prefWeeklyProgressDay),
      defaultWeeklyProgressDay,
    );
    final weeklyHour = _validHourOrDefault(
      prefs.getInt(prefWeeklyProgressHour),
      defaultWeeklyProgressHour,
    );
    final weeklyMinute = _validMinuteOrDefault(
      prefs.getInt(prefWeeklyProgressMinute),
      defaultWeeklyProgressMinute,
    );

    final quietHoursEnabled = prefs.getBool(prefQuietHoursEnabled) ?? true;
    final quietHoursStart = prefs.getInt(prefQuietHoursStart) ?? 22; // 10 PM
    final quietHoursEnd = prefs.getInt(prefQuietHoursEnd) ?? 7; // 7 AM

    bool hasWorkoutToday = false;
    bool hasLunchToday = false;
    bool hasDinnerToday = false;
    bool hasAnyFoodToday = false;

    if (db != null) {
      try {
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

        final sessions =
            await (db.select(db.workoutSessions)..where(
                  (tbl) =>
                      tbl.completedAt.isBetweenValues(startOfDay, endOfDay),
                ))
                .get();
        hasWorkoutToday = sessions.isNotEmpty;

        final foodLogs =
            await (db.select(db.foodLogs)..where(
                  (tbl) => tbl.loggedAt.isBetweenValues(startOfDay, endOfDay),
                ))
                .get();

        hasAnyFoodToday = foodLogs.isNotEmpty;
        hasLunchToday = foodLogs.any(
          (l) => l.mealType.toLowerCase() == 'lunch',
        );
        hasDinnerToday = foodLogs.any(
          (l) => l.mealType.toLowerCase() == 'dinner',
        );
      } catch (e, st) {
        AppLogger.warning('syncDailyNotifications db check failed: $e');
        CrashReportingService.recordCrash(
          e,
          st,
          reason: 'notification_service sync error',
        );
      }
    }

    if (workoutEnabled && !hasWorkoutToday) {
      await _scheduleWorkoutReminder(
        workoutDays,
        workoutHour,
        workoutMinute,
        quietHoursEnabled,
        quietHoursStart,
        quietHoursEnd,
      );
    }
    if (mealsEnabled) {
      await _scheduleMealReminders(
        hasLunchToday,
        hasDinnerToday,
        lunchHour,
        lunchMinute,
        dinnerHour,
        dinnerMinute,
        quietHoursEnabled,
        quietHoursStart,
        quietHoursEnd,
      );
    }
    if (eveningEnabled && (!hasAnyFoodToday || !hasWorkoutToday)) {
      await _scheduleEveningNudge(
        dailyLoggingHour,
        dailyLoggingMinute,
        quietHoursEnabled,
        quietHoursStart,
        quietHoursEnd,
      );
    }
    if (weeklyEnabled) {
      await _scheduleWeeklyReport(
        weeklyDay,
        weeklyHour,
        weeklyMinute,
        quietHoursEnabled,
        quietHoursStart,
        quietHoursEnd,
      );
    }

    debugPrint('All notification reminders rescheduled cleanly.');
  }

  // ────────────────────────────────────────
  // Individual schedulers
  // ────────────────────────────────────────

  /// Workout reminders on the selected local weekdays and time.
  static Future<void> _scheduleWorkoutReminder(
    List<int> days,
    int hour,
    int minute,
    bool quietHoursEnabled,
    int quietStart,
    int quietEnd,
  ) async {
    for (final day in days) {
      await _scheduleWeeklyNotification(
        id: _idWorkout + day,
        channelId: _workoutChannelId,
        channelName: 'Workout Reminders',
        dayOfWeek: day,
        hour: hour,
        minute: minute,
        title: '🏋️ Time to Train!',
        body: 'Open IndiFit when you are ready to start your workout.',
        payload: 'workout',
        quietHoursEnabled: quietHoursEnabled,
        quietHoursStart: quietStart,
        quietHoursEnd: quietEnd,
      );
    }
  }

  /// 🍱 Meal logging reminders — only post-lunch and post-dinner
  static Future<void> _scheduleMealReminders(
    bool hasLunchToday,
    bool hasDinnerToday,
    int lunchHour,
    int lunchMinute,
    int dinnerHour,
    int dinnerMinute,
    bool quietHoursEnabled,
    int quietStart,
    int quietEnd,
  ) async {
    if (!hasLunchToday) {
      await _scheduleDailyNotification(
        id: _idMealLunch,
        channelId: _mealChannelId,
        channelName: 'Meal Reminders',
        hour: lunchHour,
        minute: lunchMinute,
        title: '🍱 Log your lunch',
        body: 'Open IndiFit to search and log your lunch.',
        payload: 'meal_lunch',
        quietHoursEnabled: quietHoursEnabled,
        quietHoursStart: quietStart,
        quietHoursEnd: quietEnd,
      );
    }

    if (!hasDinnerToday) {
      await _scheduleDailyNotification(
        id: _idMealDinner,
        channelId: _mealChannelId,
        channelName: 'Meal Reminders',
        hour: dinnerHour,
        minute: dinnerMinute,
        title: '🍽️ Log your dinner',
        body: 'Open IndiFit to search and log your dinner.',
        payload: 'meal_dinner',
        quietHoursEnabled: quietHoursEnabled,
        quietHoursStart: quietStart,
        quietHoursEnd: quietEnd,
      );
    }
  }

  /// Daily logging reminder when food or workout evidence is still missing.
  static Future<void> _scheduleEveningNudge(
    int hour,
    int minute,
    bool quietHoursEnabled,
    int quietStart,
    int quietEnd,
  ) async {
    await _scheduleDailyNotification(
      id: _idEveningNudge,
      channelId: _nudgeChannelId,
      channelName: 'Daily Logging Reminders',
      hour: hour,
      minute: minute,
      title: '🌙 Review today’s logs',
      body: 'Review anything you haven’t logged today—meals or workouts.',
      payload: 'evening_nudge',
      quietHoursEnabled: quietHoursEnabled,
      quietHoursStart: quietStart,
      quietHoursEnd: quietEnd,
    );
  }

  /// Weekly factual Progress reminder at the selected local day and time.
  static Future<void> _scheduleWeeklyReport(
    int dayOfWeek,
    int hour,
    int minute,
    bool quietHoursEnabled,
    int quietStart,
    int quietEnd,
  ) async {
    await _scheduleWeeklyNotification(
      id: _idWeeklyReport,
      channelId: _weeklyChannelId,
      channelName: 'Weekly Reports',
      dayOfWeek: dayOfWeek,
      hour: hour,
      minute: minute,
      title: '📊 Your Weekly Report',
      body:
          'Your weekly summary is ready. Review calories, macros, and workout volume.',
      payload: 'weekly_report',
      quietHoursEnabled: quietHoursEnabled,
      quietHoursStart: quietStart,
      quietHoursEnd: quietEnd,
    );
  }

  // ────────────────────────────────────────
  // Core scheduling helpers
  // ────────────────────────────────────────

  static Future<void> _scheduleDailyNotification({
    required int id,
    required String channelId,
    required String channelName,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
    bool quietHoursEnabled = false,
    int quietHoursStart = 22,
    int quietHoursEnd = 7,
  }) async {
    final scheduledTime = _nextInstanceOfTime(
      hour,
      minute,
      quietHoursEnabled: quietHoursEnabled,
      quietHoursStart: quietHoursStart,
      quietHoursEnd: quietHoursEnd,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          styleInformation: const BigTextStyleInformation(''),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeats daily
      payload: payload,
    );
  }

  static Future<void> _scheduleWeeklyNotification({
    required int id,
    required String channelId,
    required String channelName,
    required int dayOfWeek,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
    bool quietHoursEnabled = false,
    int quietHoursStart = 22,
    int quietHoursEnd = 7,
  }) async {
    final scheduledTime = _nextInstanceOfDayAndTime(
      dayOfWeek,
      hour,
      minute,
      quietHoursEnabled: quietHoursEnabled,
      quietHoursStart: quietHoursStart,
      quietHoursEnd: quietHoursEnd,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          styleInformation: const BigTextStyleInformation(''),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          DateTimeComponents.dayOfWeekAndTime, // Repeats weekly
      payload: payload,
    );
  }

  // ────────────────────────────────────────
  // Timezone-aware time calculators
  // ────────────────────────────────────────

  static tz.TZDateTime _nextInstanceOfTime(
    int hour,
    int minute, {
    bool quietHoursEnabled = false,
    int quietHoursStart = 22,
    int quietHoursEnd = 7,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    scheduled = _deferUntilQuietHoursEnd(
      scheduled,
      enabled: quietHoursEnabled,
      startHour: quietHoursStart,
      endHour: quietHoursEnd,
    );

    return scheduled;
  }

  static bool isInQuietHours(int hour, int minute, int startHour, int endHour) {
    if (startHour > endHour) {
      return hour >= startHour || hour < endHour;
    } else {
      return hour >= startHour && hour < endHour;
    }
  }

  static List<int> workoutReminderDaysFromPreferences(SharedPreferences prefs) {
    final stored = prefs.getStringList(prefWorkoutReminderDays);
    if (stored == null) return defaultWorkoutReminderDays;
    final days =
        stored
            .map(int.tryParse)
            .whereType<int>()
            .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
            .toSet()
            .toList()
          ..sort();
    return days.isEmpty ? defaultWorkoutReminderDays : days;
  }

  static int _validHourOrDefault(int? value, int fallback) =>
      value != null && value >= 0 && value <= 23 ? value : fallback;

  static int _validMinuteOrDefault(int? value, int fallback) =>
      value != null && value >= 0 && value <= 59 ? value : fallback;

  static int _validWeekdayOrDefault(int? value, int fallback) =>
      value != null && value >= DateTime.monday && value <= DateTime.sunday
      ? value
      : fallback;

  static tz.TZDateTime _nextInstanceOfDayAndTime(
    int dayOfWeek,
    int hour,
    int minute, {
    bool quietHoursEnabled = false,
    int quietHoursStart = 22,
    int quietHoursEnd = 7,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    while (scheduled.weekday != dayOfWeek) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return _deferUntilQuietHoursEnd(
      scheduled,
      enabled: quietHoursEnabled,
      startHour: quietHoursStart,
      endHour: quietHoursEnd,
    );
  }

  static tz.TZDateTime _deferUntilQuietHoursEnd(
    tz.TZDateTime scheduled, {
    required bool enabled,
    required int startHour,
    required int endHour,
  }) {
    if (!enabled ||
        !isInQuietHours(scheduled.hour, scheduled.minute, startHour, endHour)) {
      return scheduled;
    }

    final endsNextDay = startHour > endHour && scheduled.hour >= startHour;
    final endDate = endsNextDay
        ? scheduled.add(const Duration(days: 1))
        : scheduled;
    return tz.TZDateTime(
      tz.local,
      endDate.year,
      endDate.month,
      endDate.day,
      endHour,
    );
  }

  static const String prefLastScheduledTimezoneId =
      'last_scheduled_timezone_id';
  static const String prefLastUtcOffsetMinutes = 'last_utc_offset_minutes';

  /// Detects if device timezone or UTC offset changed (e.g. travel or DST change),
  /// updates persisted timezone metadata, and reschedules notifications.
  static Future<bool> checkAndUpdateTimezoneAndReschedule([
    AppDatabase? db,
  ]) async {
    await _configureLocalTimeZone();
    final prefs = await SharedPreferences.getInstance();

    final currentTzId = tz.local.name;
    final currentOffsetMinutes = DateTime.now().timeZoneOffset.inMinutes;

    final lastTzId = prefs.getString(prefLastScheduledTimezoneId);
    final lastOffsetMinutes = prefs.getInt(prefLastUtcOffsetMinutes);

    if (lastTzId != currentTzId || lastOffsetMinutes != currentOffsetMinutes) {
      AppLogger.info(
        'Timezone or UTC offset change detected ($lastTzId -> $currentTzId, offset: $currentOffsetMinutes). Rescheduling reminders...',
        'NotificationService',
      );
      await prefs.setString(prefLastScheduledTimezoneId, currentTzId);
      await prefs.setInt(prefLastUtcOffsetMinutes, currentOffsetMinutes);
      await scheduleAllReminders(db);
      return true;
    }
    return false;
  }

  static Future<void> _configureLocalTimeZone() async {
    // Platform APIs return an IANA identifier (for example Europe/London),
    // unlike DateTime.timeZoneName which is commonly an ambiguous abbreviation
    // such as IST or PST. This is essential for travel and DST correctness.
    try {
      final nativeTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(nativeTimeZone.identifier));
      return;
    } catch (e) {
      AppLogger.warning('Native timezone lookup failed: $e');
    }

    final now = DateTime.now();
    final timeZoneName = now.timeZoneName;

    // Direct IANA location name lookup
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      return;
    } catch (e) {
      AppLogger.warning('Direct timezone lookup failed for $timeZoneName: $e');
    }

    // Fallback based on UTC offset mapping
    final offsetHours = now.timeZoneOffset.inHours;
    final offsetMinutes = now.timeZoneOffset.inMinutes.remainder(60).abs();

    String fallbackLocation = 'Asia/Kolkata';
    if (offsetHours == 5 && offsetMinutes == 30) {
      fallbackLocation = 'Asia/Kolkata';
    } else if (offsetHours == 0) {
      fallbackLocation = 'UTC';
    } else if (offsetHours == -5) {
      fallbackLocation = 'America/New_York';
    } else if (offsetHours == -8) {
      fallbackLocation = 'America/Los_Angeles';
    } else if (offsetHours == 1) {
      fallbackLocation = 'Europe/London';
    } else if (offsetHours == 2) {
      fallbackLocation = 'Europe/Paris';
    } else if (offsetHours == 8) {
      fallbackLocation = 'Asia/Singapore';
    } else if (offsetHours == 9) {
      fallbackLocation = 'Asia/Tokyo';
    }

    try {
      tz.setLocalLocation(tz.getLocation(fallbackLocation));
    } catch (e, st) {
      AppLogger.warning(
        'Fallback timezone lookup failed for $fallbackLocation: $e',
      );
      CrashReportingService.recordCrash(
        e,
        st,
        reason: 'timezone configuration fallback error',
      );
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }
}
