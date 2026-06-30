import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

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

  /// Initialize the notification plugin, timezone data, and Android channels.
  static Future<void> initialize() async {
    tz_data.initializeTimeZones();
    // Default to IST for Indian fitness app
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request Android 13+ notification permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    debugPrint('NotificationService initialized.');
  }

  static void _onNotificationTapped(NotificationResponse response) {
    // Can be extended to deep-link into specific screens
    debugPrint('Notification tapped: ${response.payload}');
  }

  // ────────────────────────────────────────
  // Schedule orchestrator
  // ────────────────────────────────────────

  /// Re-schedules all enabled reminders. Call after any preference change.
  static Future<void> scheduleAllReminders() async {
    // Cancel everything first to prevent duplicates on re-schedule
    await _plugin.cancelAll();

    final prefs = await SharedPreferences.getInstance();

    final workoutEnabled = prefs.getBool(prefRemindWorkout) ?? true;
    final mealsEnabled = prefs.getBool(prefRemindMeals) ?? true;
    final waterEnabled = prefs.getBool(prefRemindWater) ?? true;
    final eveningEnabled = prefs.getBool(prefRemindEvening) ?? true;
    final weeklyEnabled = prefs.getBool(prefRemindWeekly) ?? true;

    if (workoutEnabled) await _scheduleWorkoutReminder();
    if (mealsEnabled) await _scheduleMealReminders();
    if (waterEnabled) await _scheduleWaterReminders();
    if (eveningEnabled) await _scheduleEveningNudge();
    if (weeklyEnabled) await _scheduleWeeklyReport();

    debugPrint('All notification reminders rescheduled.');
  }

  // ────────────────────────────────────────
  // Individual schedulers
  // ────────────────────────────────────────

  /// 🏋️ Daily workout reminder at 7:30 AM
  static Future<void> _scheduleWorkoutReminder() async {
    await _scheduleDailyNotification(
      id: _idWorkout,
      channelId: _workoutChannelId,
      channelName: 'Workout Reminders',
      hour: 7,
      minute: 30,
      title: '🏋️ Time to Train!',
      body: 'Your muscles are waiting. Open IndiFit and start your workout.',
      payload: 'workout',
    );
  }

  /// 🍱 Meal logging reminders — only post-lunch and post-dinner
  /// (Skipping breakfast avoids annoying early-morning buzzes)
  static Future<void> _scheduleMealReminders() async {
    // Post-lunch: 1:30 PM
    await _scheduleDailyNotification(
      id: _idMealLunch,
      channelId: _mealChannelId,
      channelName: 'Meal Reminders',
      hour: 13,
      minute: 30,
      title: '🍱 Log your lunch',
      body: 'Ate something good? Snap a photo or search for it to track macros.',
      payload: 'meal_lunch',
    );

    // Post-dinner: 8:30 PM
    await _scheduleDailyNotification(
      id: _idMealDinner,
      channelId: _mealChannelId,
      channelName: 'Meal Reminders',
      hour: 20,
      minute: 30,
      title: '🍽️ Log your dinner',
      body: 'Almost done for the day — log dinner to complete your macro tracker.',
      payload: 'meal_dinner',
    );
  }

  /// 💧 Water intake — gentle twice-daily nudges (not hourly!)
  static Future<void> _scheduleWaterReminders() async {
    // Mid-morning: 11:00 AM
    await _scheduleDailyNotification(
      id: _idWaterMorning,
      channelId: _waterChannelId,
      channelName: 'Water Reminders',
      hour: 11,
      minute: 0,
      title: '💧 Hydration check',
      body: 'Have you had enough water this morning? Tap to log glasses.',
      payload: 'water',
    );

    // Mid-afternoon: 4:00 PM
    await _scheduleDailyNotification(
      id: _idWaterAfternoon,
      channelId: _waterChannelId,
      channelName: 'Water Reminders',
      hour: 16,
      minute: 0,
      title: '💧 Afternoon hydration',
      body: 'Staying hydrated boosts workout performance. Log your water intake.',
      payload: 'water',
    );
  }

  /// 🌙 Evening nudge at 9:15 PM — "Did you log today?"
  static Future<void> _scheduleEveningNudge() async {
    await _scheduleDailyNotification(
      id: _idEveningNudge,
      channelId: _nudgeChannelId,
      channelName: 'Daily Nudge',
      hour: 21,
      minute: 15,
      title: '🌙 Log your day',
      body: 'Take 30 seconds to log anything you missed — meals, water, or workouts. Keep your streak alive!',
      payload: 'evening_nudge',
    );
  }

  /// 📊 Weekly AI report — Sunday at 10:00 AM
  static Future<void> _scheduleWeeklyReport() async {
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
  }) async {
    final scheduledTime = _nextInstanceOfTime(hour, minute);

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
  }) async {
    final scheduledTime = _nextInstanceOfDayAndTime(dayOfWeek, hour, minute);

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

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static tz.TZDateTime _nextInstanceOfDayAndTime(int dayOfWeek, int hour, int minute) {
    var scheduled = _nextInstanceOfTime(hour, minute);
    while (scheduled.weekday != dayOfWeek) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
