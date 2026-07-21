import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:drift/drift.dart';
import '../../data/database/app_database.dart';

/// Non-annoying, engagement-optimized local notification service.
///
/// Schedule philosophy:
///   - Workout reminder: Once daily (morning warm-up window)
///   - Meal logging: Twice daily (post-lunch + post-dinner — skips breakfast to avoid morning spam)
///   - Water intake: Twice daily (mid-morning + mid-afternoon — not hourly)
///   - Evening nudge: Once daily (gentle "did you log today?" before bed)
///   - Weekly AI report: Once per week (Sunday morning)
///
/// Total: ~6 notifications/day max (vs 15+ if we did hourly water + every meal).
/// All configurable via SharedPreferences toggles in Settings screen.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Notification channel IDs
  static const String _workoutChannelId = 'indifit_workout';
  static const String _mealChannelId = 'indifit_meals';
  static const String _waterChannelId = 'indifit_water';
  static const String _nudgeChannelId = 'indifit_nudge';
  static const String _weeklyChannelId = 'indifit_weekly';

  // Notification IDs (unique per scheduled notification)
  static const int _idWorkout = 100;
  static const int _idMealLunch = 201;
  static const int _idMealDinner = 202;
  static const int _idWaterMorning = 301;
  static const int _idWaterAfternoon = 302;
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

  static Function(String payload)? onNotificationNavigate;

  /// Initialize the notification plugin, timezone data, and Android channels.
  static Future<void> initialize() async {
    tz_data.initializeTimeZones();
    _configureLocalTimeZone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    return (androidGranted ?? false) || (iosGranted ?? false);
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
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

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
    final waterEnabled = prefs.getBool(prefRemindWater) ?? false;
    final eveningEnabled = prefs.getBool(prefRemindEvening) ?? false;
    final weeklyEnabled = prefs.getBool(prefRemindWeekly) ?? false;

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

        final sessions = await (db.select(db.workoutSessions)
              ..where((tbl) => tbl.completedAt.isBetweenValues(startOfDay, endOfDay)))
            .get();
        hasWorkoutToday = sessions.isNotEmpty;

        final foodLogs = await (db.select(db.foodLogs)
              ..where((tbl) => tbl.loggedAt.isBetweenValues(startOfDay, endOfDay)))
            .get();

        hasAnyFoodToday = foodLogs.isNotEmpty;
        hasLunchToday = foodLogs.any((l) => l.mealType.toLowerCase() == 'lunch');
        hasDinnerToday = foodLogs.any((l) => l.mealType.toLowerCase() == 'dinner');
      } catch (_) {}
    }

    if (workoutEnabled && !hasWorkoutToday) {
      await _scheduleWorkoutReminder(quietHoursEnabled, quietHoursStart, quietHoursEnd);
    }
    if (mealsEnabled) {
      await _scheduleMealReminders(hasLunchToday, hasDinnerToday, quietHoursEnabled, quietHoursStart, quietHoursEnd);
    }
    if (waterEnabled) {
      await _scheduleWaterReminders(quietHoursEnabled, quietHoursStart, quietHoursEnd);
    }
    if (eveningEnabled && (!hasAnyFoodToday || !hasWorkoutToday)) {
      await _scheduleEveningNudge(quietHoursEnabled, quietHoursStart, quietHoursEnd);
    }
    if (weeklyEnabled) {
      await _scheduleWeeklyReport(quietHoursEnabled, quietHoursStart, quietHoursEnd);
    }

    debugPrint('All notification reminders rescheduled cleanly.');
  }

  // ────────────────────────────────────────
  // Individual schedulers
  // ────────────────────────────────────────

  /// 🏋️ Daily workout reminder at 7:30 AM
  static Future<void> _scheduleWorkoutReminder(bool quietHoursEnabled, int quietStart, int quietEnd) async {
    await _scheduleDailyNotification(
      id: _idWorkout,
      channelId: _workoutChannelId,
      channelName: 'Workout Reminders',
      hour: 7,
      minute: 30,
      title: '🏋️ Time to Train!',
      body: 'Your muscles are waiting. Open IndiFit and start your workout.',
      payload: 'workout',
      quietHoursEnabled: quietHoursEnabled,
      quietHoursStart: quietStart,
      quietHoursEnd: quietEnd,
    );
  }

  /// 🍱 Meal logging reminders — only post-lunch and post-dinner
  static Future<void> _scheduleMealReminders(bool hasLunchToday, bool hasDinnerToday, bool quietHoursEnabled, int quietStart, int quietEnd) async {
    if (!hasLunchToday) {
      await _scheduleDailyNotification(
        id: _idMealLunch,
        channelId: _mealChannelId,
        channelName: 'Meal Reminders',
        hour: 13,
        minute: 30,
        title: '🍱 Log your lunch',
        body: 'Ate something good? Snap a photo or search for it to track macros.',
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
        hour: 20,
        minute: 30,
        title: '🍽️ Log your dinner',
        body: 'Almost done for the day — log dinner to complete your macro tracker.',
        payload: 'meal_dinner',
        quietHoursEnabled: quietHoursEnabled,
        quietHoursStart: quietStart,
        quietHoursEnd: quietEnd,
      );
    }
  }

  /// 💧 Water intake — gentle twice-daily nudges
  static Future<void> _scheduleWaterReminders(bool quietHoursEnabled, int quietStart, int quietEnd) async {
    await _scheduleDailyNotification(
      id: _idWaterMorning,
      channelId: _waterChannelId,
      channelName: 'Water Reminders',
      hour: 11,
      minute: 0,
      title: '💧 Hydration check',
      body: 'Have you had enough water this morning? Tap to log glasses.',
      payload: 'water',
      quietHoursEnabled: quietHoursEnabled,
      quietHoursStart: quietStart,
      quietHoursEnd: quietEnd,
    );

    await _scheduleDailyNotification(
      id: _idWaterAfternoon,
      channelId: _waterChannelId,
      channelName: 'Water Reminders',
      hour: 16,
      minute: 0,
      title: '💧 Afternoon hydration',
      body: 'Staying hydrated boosts workout performance. Log your water intake.',
      payload: 'water',
      quietHoursEnabled: quietHoursEnabled,
      quietHoursStart: quietStart,
      quietHoursEnd: quietEnd,
    );
  }

  /// 🌙 Evening nudge at 9:15 PM
  static Future<void> _scheduleEveningNudge(bool quietHoursEnabled, int quietStart, int quietEnd) async {
    await _scheduleDailyNotification(
      id: _idEveningNudge,
      channelId: _nudgeChannelId,
      channelName: 'Daily Nudge',
      hour: 21,
      minute: 15,
      title: '🌙 Log your day',
      body: 'Take 30 seconds to log anything you missed — meals, water, or workouts. Keep your streak alive!',
      payload: 'evening_nudge',
      quietHoursEnabled: quietHoursEnabled,
      quietHoursStart: quietStart,
      quietHoursEnd: quietEnd,
    );
  }

  /// 📊 Weekly AI report — Sunday at 10:00 AM
  static Future<void> _scheduleWeeklyReport(bool quietHoursEnabled, int quietStart, int quietEnd) async {
    await _scheduleWeeklyNotification(
      id: _idWeeklyReport,
      channelId: _weeklyChannelId,
      channelName: 'Weekly AI Report',
      dayOfWeek: DateTime.sunday,
      hour: 10,
      minute: 0,
      title: '📊 Your Weekly AI Fitness Report',
      body: 'Your personalized weekly summary is ready. See calories, macros, workout volume trends, and AI coaching tips.',
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
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
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
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // Repeats weekly
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
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    if (quietHoursEnabled && isInQuietHours(scheduled.hour, scheduled.minute, quietHoursStart, quietHoursEnd)) {
      scheduled = tz.TZDateTime(tz.local, scheduled.year, scheduled.month, scheduled.day, quietHoursEnd, 0);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
    }

    return scheduled;
  }

  static bool isInQuietHours(int hour, int minute, int startHour, int endHour) {
    if (startHour > endHour) {
      return hour >= startHour || hour < endHour;
    } else {
      return hour >= startHour && hour < endHour;
    }
  }

  static tz.TZDateTime _nextInstanceOfDayAndTime(
    int dayOfWeek,
    int hour,
    int minute, {
    bool quietHoursEnabled = false,
    int quietHoursStart = 22,
    int quietHoursEnd = 7,
  }) {
    var scheduled = _nextInstanceOfTime(
      hour,
      minute,
      quietHoursEnabled: quietHoursEnabled,
      quietHoursStart: quietHoursStart,
      quietHoursEnd: quietHoursEnd,
    );
    while (scheduled.weekday != dayOfWeek) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }


  static void _configureLocalTimeZone() {
    final now = DateTime.now();
    final timeZoneName = now.timeZoneName;

    // Direct IANA location name lookup
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      return;
    } catch (_) {}

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
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }
}
