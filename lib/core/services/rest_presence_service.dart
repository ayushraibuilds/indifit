import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'indifit_haptics.dart';
import 'ios_live_activity_service.dart';

/// Lifecycle states for background rest-timer presence.
enum RestPresenceState { idle, active, expired, cancelled }

/// Canonical durable anchor record persisted in SharedPreferences to support
/// lock-screen re-posting and state preservation across process death.
class RestAnchorRecord {
  final String periodId;
  final String exerciseName;
  final DateTime startedAtUtc;
  final int baseTargetSeconds;
  final int accumulatedExtraSeconds;
  final bool hasExactAlarmAnchor;

  const RestAnchorRecord({
    required this.periodId,
    required this.exerciseName,
    required this.startedAtUtc,
    required this.baseTargetSeconds,
    this.accumulatedExtraSeconds = 0,
    this.hasExactAlarmAnchor = false,
  });

  int get totalTargetSeconds => baseTargetSeconds + accumulatedExtraSeconds;
  DateTime get expiryUtc =>
      startedAtUtc.add(Duration(seconds: totalTargetSeconds));

  Map<String, dynamic> toJson() => {
        'periodId': periodId,
        'exerciseName': exerciseName,
        'startedAtUtc': startedAtUtc.toIso8601String(),
        'baseTargetSeconds': baseTargetSeconds,
        'accumulatedExtraSeconds': accumulatedExtraSeconds,
        'hasExactAlarmAnchor': hasExactAlarmAnchor,
      };

  factory RestAnchorRecord.fromJson(Map<String, dynamic> json) =>
      RestAnchorRecord(
        periodId: json['periodId'] as String,
        exerciseName: json['exerciseName'] as String? ?? '',
        startedAtUtc: DateTime.parse(json['startedAtUtc'] as String),
        baseTargetSeconds: json['baseTargetSeconds'] as int,
        accumulatedExtraSeconds: json['accumulatedExtraSeconds'] as int? ?? 0,
        hasExactAlarmAnchor: json['hasExactAlarmAnchor'] as bool? ?? false,
      );

  RestAnchorRecord copyWith({
    int? accumulatedExtraSeconds,
    bool? hasExactAlarmAnchor,
  }) =>
      RestAnchorRecord(
        periodId: periodId,
        exerciseName: exerciseName,
        startedAtUtc: startedAtUtc,
        baseTargetSeconds: baseTargetSeconds,
        accumulatedExtraSeconds:
            accumulatedExtraSeconds ?? this.accumulatedExtraSeconds,
        hasExactAlarmAnchor: hasExactAlarmAnchor ?? this.hasExactAlarmAnchor,
      );
}

/// Structured intent written to SharedPreferences when notification actions are
/// tapped without an active foreground controller callback, reconciled on resume.
class RestPresenceIntent {
  final String action; // 'adjust_30s' or 'skip'
  final String periodId;
  final int? accumulatedExtraSeconds;
  final DateTime timestampUtc;

  const RestPresenceIntent({
    required this.action,
    required this.periodId,
    this.accumulatedExtraSeconds,
    required this.timestampUtc,
  });

  Map<String, dynamic> toJson() => {
        'action': action,
        'periodId': periodId,
        if (accumulatedExtraSeconds != null)
          'accumulatedExtraSeconds': accumulatedExtraSeconds,
        'timestampUtc': timestampUtc.toIso8601String(),
      };

  factory RestPresenceIntent.fromJson(Map<String, dynamic> json) =>
      RestPresenceIntent(
        action: json['action'] as String,
        periodId: json['periodId'] as String,
        accumulatedExtraSeconds: json['accumulatedExtraSeconds'] as int?,
        timestampUtc: DateTime.parse(json['timestampUtc'] as String),
      );
}

/// Narrow platform driver boundary for rest-timer notifications and haptics.
abstract interface class RestPresenceDriver {
  Future<void> showOngoingRestNotification({
    required int id,
    required String exerciseName,
    required int remainingSeconds,
    required int totalSeconds,
    required String channelId,
    required String channelName,

    /// Absolute expiry instant driving the native chronometer countdown.
    /// Null preserves the legacy text-only countdown.
    DateTime? expiryUtc,
  });

  Future<void> showRestExpiredNotification({
    required int id,
    required String exerciseName,
    required String channelId,
    required String channelName,
  });

  /// Schedules an exact alarm at expiryUtc if capability is available.
  /// Returns true if scheduled as an exact alarm, or false if unavailable/denied.
  Future<bool> scheduleExactExpiryAlarm({
    required int id,
    required DateTime expiryUtc,
    required String exerciseName,
    required String channelId,
    required String channelName,
  });

  Future<void> cancelNotification(int id);

  Future<void> triggerHapticFeedback();
}

/// Default production driver backed by flutter_local_notifications and IndiFitHaptics.
class LocalNotificationRestPresenceDriver implements RestPresenceDriver {
  final FlutterLocalNotificationsPlugin _plugin;

  LocalNotificationRestPresenceDriver([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  @override
  Future<void> showOngoingRestNotification({
    required int id,
    required String exerciseName,
    required int remainingSeconds,
    required int totalSeconds,
    required String channelId,
    required String channelName,
    DateTime? expiryUtc,
  }) async {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final timeStr = minutes > 0
        ? '$minutes:${seconds.toString().padLeft(2, '0')}'
        : '${seconds}s';

    final progress = (totalSeconds - remainingSeconds).clamp(0, totalSeconds);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Ongoing workout rest timer countdown',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: totalSeconds,
      progress: progress,
      // Native countdown toward expiry keeps ticking between re-posts and
      // survives ticker throttling; the 1s ticker remains for exact expiry.
      usesChronometer: expiryUtc != null,
      chronometerCountDown: expiryUtc != null,
      when: expiryUtc?.millisecondsSinceEpoch,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'rest_add_30s',
          '+30s',
          showsUserInterface: false,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'rest_skip',
          'Skip',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id,
      'Rest: $timeStr remaining',
      exerciseName.isNotEmpty ? 'Next: $exerciseName' : 'Resting between sets',
      details,
      payload: 'workout',
    );
  }

  @override
  Future<void> showRestExpiredNotification({
    required int id,
    required String exerciseName,
    required String channelId,
    required String channelName,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Workout rest timer alert',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final body = exerciseName.isNotEmpty
        ? 'Time to hit your next set of $exerciseName!'
        : 'Time to hit your next set. You got this!';

    await _plugin.show(
      id,
      'Rest Time Completed! 💪',
      body,
      details,
      payload: 'workout',
    );
  }

  @override
  Future<bool> scheduleExactExpiryAlarm({
    required int id,
    required DateTime expiryUtc,
    required String exerciseName,
    required String channelId,
    required String channelName,
  }) async {
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // Query capability per schedule call on Android 12+/14+
      final canExact =
          await androidPlugin?.canScheduleExactNotifications() ?? false;
      if (!canExact) {
        return false;
      }

      final body = exerciseName.isNotEmpty
          ? 'Time to hit your next set of $exerciseName!'
          : 'Time to hit your next set. You got this!';

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Workout rest timer alert',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: false,
        autoCancel: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      tz.TZDateTime tzExpiry;
      try {
        tzExpiry = tz.TZDateTime.from(expiryUtc, tz.local);
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
        tzExpiry = tz.TZDateTime.from(expiryUtc, tz.UTC);
      }

      await _plugin.zonedSchedule(
        id,
        'Rest Time Completed! 💪',
        body,
        tzExpiry,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'workout',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  @override
  Future<void> triggerHapticFeedback() async {
    await IndiFitHaptics.confirmation();
  }
}

/// Service managing the background rest-timer presence lifecycle across
/// foreground, background, expiry, cancellation, and completed workout cleanup.
///
/// Channels:
///   - Ongoing countdown: notification ID 998 on channel `indifit_rest_timer`
///   - Expiry alert: notification ID 999 on channel `indifit_rest_timer`
class RestPresenceService {
  static const String channelId = 'indifit_rest_timer';
  static const String channelName = 'Rest Timer';
  static const int ongoingNotificationId = 998;
  static const int expiredNotificationId = 999;

  static const String prefRestAnchorRecord = 'rest_presence_anchor_record';
  static const String prefPendingRestIntent = 'rest_presence_pending_intent';

  static RestPresenceService? _instance;

  /// Process-wide default used by the production Riverpod providers.
  /// Tests inject fakes through the constructor instead; exactly one root
  /// should own the notification IDs in production.
  static RestPresenceService get instance =>
      _instance ??= RestPresenceService();

  final RestPresenceDriver _driver;
  final DateTime Function() _nowUtc;
  final IosLiveActivityService? _liveActivity;

  RestPresenceState _state = RestPresenceState.idle;
  String? _currentPeriodId;
  String? _currentExerciseName;
  DateTime? _startedAtUtc;
  int? _targetDurationSeconds;
  bool _hasExactAlarmAnchor = false;
  Timer? _ticker;
  String? _liveActivityPeriodId;

  FutureOr<void> Function(String periodId, int deltaSeconds)?
      onAdjustRestRequested;
  FutureOr<void> Function(String periodId)? onSkipRestRequested;

  RestPresenceService({
    RestPresenceDriver? driver,
    DateTime Function()? nowUtc,
    IosLiveActivityService? liveActivity,
  })  : _driver = driver ?? LocalNotificationRestPresenceDriver(),
        _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
        _liveActivity = liveActivity ?? IosLiveActivityService.instance;

  RestPresenceState get state => _state;
  bool get isActive => _state == RestPresenceState.active;
  String? get currentPeriodId => _currentPeriodId;
  String? get currentExerciseName => _currentExerciseName;
  DateTime? get startedAtUtc => _startedAtUtc;
  int? get targetDurationSeconds => _targetDurationSeconds;
  bool get hasExactAlarmAnchor => _hasExactAlarmAnchor;
  RestPresenceDriver get driver => _driver;
  IosLiveActivityService? get liveActivity => _liveActivity;
  String? get liveActivityPeriodId => _liveActivityPeriodId;

  int get remainingSeconds {
    if (_state != RestPresenceState.active ||
        _startedAtUtc == null ||
        _targetDurationSeconds == null) {
      return 0;
    }
    final elapsed = _nowUtc().difference(_startedAtUtc!).inSeconds;
    final remaining = _targetDurationSeconds! - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  void registerActionDelegate({
    required FutureOr<void> Function(String periodId, int deltaSeconds) onAdjust,
    required FutureOr<void> Function(String periodId) onSkip,
  }) {
    onAdjustRestRequested = onAdjust;
    onSkipRestRequested = onSkip;
  }

  void unregisterActionDelegate() {
    onAdjustRestRequested = null;
    onSkipRestRequested = null;
  }

  /// Start background presence for a rest period.
  Future<void> startRest({
    required String periodId,
    required String exerciseName,
    required int targetSeconds,
    DateTime? startedAtUtc,
    int accumulatedExtraSeconds = 0,
  }) async {
    // Cancel any previous rest timer or ticker
    _ticker?.cancel();
    _ticker = null;

    _state = RestPresenceState.active;
    _currentPeriodId = periodId;
    _currentExerciseName = exerciseName;
    _targetDurationSeconds = targetSeconds;
    _startedAtUtc = startedAtUtc ?? _nowUtc();

    final remaining = remainingSeconds;
    final expiryUtc = _startedAtUtc!.add(Duration(seconds: targetSeconds));

    if (remaining <= 0) {
      _hasExactAlarmAnchor = false;
      await onRestElapsed(periodId: periodId);
      return;
    }

    // Invariant: (re)schedule exact alarm anchor whenever expiryUtc changes
    final scheduledExact = await _driver.scheduleExactExpiryAlarm(
      id: expiredNotificationId,
      expiryUtc: expiryUtc,
      exerciseName: exerciseName,
      channelId: channelId,
      channelName: channelName,
    );
    _hasExactAlarmAnchor = scheduledExact;

    // Persist canonical anchor record with single-writer flag
    await saveAnchorRecord(
      RestAnchorRecord(
        periodId: periodId,
        exerciseName: exerciseName,
        startedAtUtc: _startedAtUtc!,
        baseTargetSeconds: targetSeconds - accumulatedExtraSeconds,
        accumulatedExtraSeconds: accumulatedExtraSeconds,
        hasExactAlarmAnchor: _hasExactAlarmAnchor,
      ),
    );

    await _driver.showOngoingRestNotification(
      id: ongoingNotificationId,
      exerciseName: _currentExerciseName ?? '',
      remainingSeconds: remaining,
      totalSeconds: _targetDurationSeconds!,
      channelId: channelId,
      channelName: channelName,
      expiryUtc: expiryUtc,
    );

    // iOS Live Activity lifecycle: same periodId branches to update (avoids ActivityKit rate limiting and flicker)
    if (_liveActivityPeriodId == periodId) {
      await _liveActivity?.updateRestLiveActivity(
        periodId: periodId,
        exerciseName: _currentExerciseName ?? '',
        targetSeconds: _targetDurationSeconds!,
        expiryUtc: expiryUtc,
      );
    } else {
      if (_liveActivityPeriodId != null) {
        await _liveActivity?.endRestLiveActivity(
          periodId: _liveActivityPeriodId,
          immediate: true,
        );
      }
      _liveActivityPeriodId = periodId;
      await _liveActivity?.startRestLiveActivity(
        periodId: periodId,
        exerciseName: _currentExerciseName ?? '',
        targetSeconds: _targetDurationSeconds!,
        expiryUtc: expiryUtc,
      );
    }

    // Periodic tick to check expiry every 1s, but throttle notification re-posts to
    // every 5s. Native chronometer counts down continuously on Android; throttling
    // eliminates notification IPC churn and preserves battery during long rests.
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_state != RestPresenceState.active || _currentPeriodId != periodId) {
        timer.cancel();
        return;
      }
      final rem = remainingSeconds;
      if (rem <= 0) {
        timer.cancel();
        _ticker = null;
        await onRestElapsed(periodId: periodId);
      } else if (rem % 5 == 0) {
        await _driver.showOngoingRestNotification(
          id: ongoingNotificationId,
          exerciseName: _currentExerciseName ?? '',
          remainingSeconds: rem,
          totalSeconds: _targetDurationSeconds!,
          channelId: channelId,
          channelName: channelName,
          expiryUtc: expiryUtc,
        );
      }
    });
  }

  /// Called when the rest period reaches 0 or is completed due to timer elapsing.
  Future<void> onRestElapsed({
    required String periodId,
    bool? silentCompletion,
  }) async {
    if (_state != RestPresenceState.active || _currentPeriodId != periodId) {
      // If already expired or not matching current, still ensure ongoing notification is removed
      await _driver.cancelNotification(ongoingNotificationId);
      return;
    }

    _ticker?.cancel();
    _ticker = null;
    _state = RestPresenceState.expired;

    // Dismiss ongoing progress notification immediately
    final cancelOngoing = _driver.cancelNotification(ongoingNotificationId);

    // Transition Live Activity to completed state ("Rest Complete") with HIG dismissal delay
    if (_liveActivityPeriodId == periodId) {
      await _liveActivity?.endRestLiveActivity(
        periodId: periodId,
        immediate: false,
      );
      _liveActivityPeriodId = null;
    }

    await cancelOngoing;

    // Single-writer rule & Option-(a) foreground decision:
    // Exact alarms fire platform-wide at expiryUtc; a single heads-up banner is accepted
    // over race-prone cancel/re-anchor lifecycle dances around foreground transitions.
    // If exact alarm anchor was successfully scheduled, the platform alarm
    // already fired (or is firing) the audible notification ID 999.
    // In silentCompletion or when hasExactAlarmAnchor == true, suppress posting 999.
    // If exact alarm capability was denied/unavailable, Dart posts fallback 999.
    final isSilent = silentCompletion ?? _hasExactAlarmAnchor;
    if (!isSilent) {
      await _driver.showRestExpiredNotification(
        id: expiredNotificationId,
        exerciseName: _currentExerciseName ?? '',
        channelId: channelId,
        channelName: channelName,
      );
    }

    await clearAnchorRecord();
    await clearPendingIntent();
    await _driver.triggerHapticFeedback();
  }

  /// Cancel rest presence (e.g. user skips rest, advances to next set, or adjusts).
  Future<void> cancelRest({String? periodId}) async {
    if (periodId != null && _currentPeriodId != periodId) {
      return;
    }

    _ticker?.cancel();
    _ticker = null;
    _state = RestPresenceState.cancelled;
    _currentPeriodId = null;
    _currentExerciseName = null;
    _startedAtUtc = null;
    _targetDurationSeconds = null;
    _hasExactAlarmAnchor = false;

    final cancelOngoing = _driver.cancelNotification(ongoingNotificationId);
    final cancelExpired = _driver.cancelNotification(expiredNotificationId);
    final clearAnchor = clearAnchorRecord();
    final clearIntent = clearPendingIntent();

    if (_liveActivityPeriodId != null &&
        (periodId == null || _liveActivityPeriodId == periodId)) {
      await _liveActivity?.endRestLiveActivity(
        periodId: _liveActivityPeriodId,
        immediate: true,
      );
      _liveActivityPeriodId = null;
    }

    await cancelOngoing;
    await cancelExpired;
    await clearAnchor;
    await clearIntent;
  }

  /// Clean up all rest notifications and state (e.g. on workout finish, cancel, or app launch).
  Future<void> cleanup() async {
    _ticker?.cancel();
    _ticker = null;
    _state = RestPresenceState.idle;
    _currentPeriodId = null;
    _currentExerciseName = null;
    _startedAtUtc = null;
    _targetDurationSeconds = null;
    _hasExactAlarmAnchor = false;

    final cancelOngoing = _driver.cancelNotification(ongoingNotificationId);
    final cancelExpired = _driver.cancelNotification(expiredNotificationId);
    final clearAnchor = clearAnchorRecord();
    final clearIntent = clearPendingIntent();

    if (_liveActivityPeriodId != null) {
      await _liveActivity?.endRestLiveActivity(
        periodId: _liveActivityPeriodId,
        immediate: true,
      );
      _liveActivityPeriodId = null;
    } else {
      await _liveActivity?.endRestLiveActivity(immediate: true);
    }

    await cancelOngoing;
    await cancelExpired;
    await clearAnchor;
    await clearIntent;
  }

  /// Clean up stale rest notifications at app startup or when entering foreground.
  static Future<void> cleanupStaleNotifications([
    RestPresenceDriver? driver,
    IosLiveActivityService? liveActivity,
  ]) async {
    final d = driver ?? LocalNotificationRestPresenceDriver();
    final la = liveActivity ?? IosLiveActivityService.instance;
    await d.cancelNotification(ongoingNotificationId);
    await d.cancelNotification(expiredNotificationId);
    await clearAnchorRecord();
    await clearPendingIntent();
    await la.endRestLiveActivity(immediate: true);
  }

  /// Dispatch an interactive notification action.
  Future<void> handleAction(String actionId) async {
    final periodId = _currentPeriodId;
    if (actionId == 'rest_add_30s') {
      if (onAdjustRestRequested != null && periodId != null) {
        await onAdjustRestRequested!(periodId, 30);
      } else {
        // No callback registered -> write pending intent, leave mirror untouched
        final anchor = await loadAnchorRecord();
        if (anchor != null) {
          final updated = anchor.copyWith(
            accumulatedExtraSeconds: anchor.accumulatedExtraSeconds + 30,
          );
          await saveAnchorRecord(updated);
          await savePendingIntent(
            RestPresenceIntent(
              action: 'adjust_30s',
              periodId: anchor.periodId,
              accumulatedExtraSeconds: updated.accumulatedExtraSeconds,
              timestampUtc: _nowUtc(),
            ),
          );
        }
      }
    } else if (actionId == 'rest_skip') {
      if (onSkipRestRequested != null && periodId != null) {
        await onSkipRestRequested!(periodId);
      } else {
        // No callback registered -> write pending intent, leave mirror untouched
        final anchor = await loadAnchorRecord();
        if (anchor != null) {
          await savePendingIntent(
            RestPresenceIntent(
              action: 'skip',
              periodId: anchor.periodId,
              timestampUtc: _nowUtc(),
            ),
          );
          await cleanup();
        }
      }
    }
  }

  /// Headless isolate action handler executed when the app is backgrounded or killed.
  @pragma('vm:entry-point')
  static Future<void> handleBackgroundAction(
    NotificationResponse response,
  ) async {
    final actionId = response.actionId;
    if (actionId == null) return;

    final anchor = await loadAnchorRecord();
    if (anchor == null) return;

    final plugin = FlutterLocalNotificationsPlugin();
    final driver = LocalNotificationRestPresenceDriver(plugin);
    final now = DateTime.now().toUtc();

    if (actionId == 'rest_add_30s') {
      final updated = anchor.copyWith(
        accumulatedExtraSeconds: anchor.accumulatedExtraSeconds + 30,
      );
      await saveAnchorRecord(updated);
      await savePendingIntent(
        RestPresenceIntent(
          action: 'adjust_30s',
          periodId: anchor.periodId,
          accumulatedExtraSeconds: updated.accumulatedExtraSeconds,
          timestampUtc: now,
        ),
      );

      final newExpiryUtc = updated.expiryUtc;
      final remaining = newExpiryUtc.difference(now).inSeconds;
      final remainingSafe = remaining > 0 ? remaining : 0;

      // Re-post ongoing notification with updated chronometer
      await driver.showOngoingRestNotification(
        id: ongoingNotificationId,
        exerciseName: updated.exerciseName,
        remainingSeconds: remainingSafe,
        totalSeconds: updated.totalTargetSeconds,
        channelId: channelId,
        channelName: channelName,
        expiryUtc: newExpiryUtc,
      );

      // Invariant: reschedule exact alarm anchor ID 999 at newExpiryUtc
      final scheduledExact = await driver.scheduleExactExpiryAlarm(
        id: expiredNotificationId,
        expiryUtc: newExpiryUtc,
        exerciseName: updated.exerciseName,
        channelId: channelId,
        channelName: channelName,
      );
      if (scheduledExact != updated.hasExactAlarmAnchor) {
        await saveAnchorRecord(
          updated.copyWith(hasExactAlarmAnchor: scheduledExact),
        );
      }
    } else if (actionId == 'rest_skip') {
      await savePendingIntent(
        RestPresenceIntent(
          action: 'skip',
          periodId: anchor.periodId,
          timestampUtc: now,
        ),
      );
      await clearAnchorRecord();
      await driver.cancelNotification(ongoingNotificationId);
      await driver.cancelNotification(expiredNotificationId);
    }
  }

  // ────────────────────────────────────────
  // Anchor Record & Pending Intent Persistence
  // ────────────────────────────────────────

  static Future<void> saveAnchorRecord(
    RestAnchorRecord record, [
    SharedPreferences? preferences,
  ]) async {
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      await prefs.setString(prefRestAnchorRecord, jsonEncode(record.toJson()));
    } catch (_) {}
  }

  static Future<RestAnchorRecord?> loadAnchorRecord([
    SharedPreferences? preferences,
  ]) async {
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      final raw = prefs.getString(prefRestAnchorRecord);
      if (raw == null || raw.isEmpty) return null;
      return RestAnchorRecord.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearAnchorRecord([
    SharedPreferences? preferences,
  ]) async {
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      await prefs.remove(prefRestAnchorRecord);
    } catch (_) {}
  }

  static Future<void> savePendingIntent(
    RestPresenceIntent intent, [
    SharedPreferences? preferences,
  ]) async {
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      await prefs.setString(prefPendingRestIntent, jsonEncode(intent.toJson()));
    } catch (_) {}
  }

  static Future<RestPresenceIntent?> loadAndClearPendingIntent([
    SharedPreferences? preferences,
  ]) async {
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      final raw = prefs.getString(prefPendingRestIntent);
      if (raw == null || raw.isEmpty) return null;
      await prefs.remove(prefPendingRestIntent);
      return RestPresenceIntent.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearPendingIntent([
    SharedPreferences? preferences,
  ]) async {
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      await prefs.remove(prefPendingRestIntent);
    } catch (_) {}
  }
}
