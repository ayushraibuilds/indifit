import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'indifit_haptics.dart';

/// Lifecycle states for background rest-timer presence.
enum RestPresenceState { idle, active, expired, cancelled }

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

  static RestPresenceService? _instance;

  /// Process-wide default used by the production Riverpod providers.
  /// Tests inject fakes through the constructor instead; exactly one root
  /// should own the notification IDs in production.
  static RestPresenceService get instance =>
      _instance ??= RestPresenceService();

  final RestPresenceDriver _driver;
  final DateTime Function() _nowUtc;

  RestPresenceState _state = RestPresenceState.idle;
  String? _currentPeriodId;
  String? _currentExerciseName;
  DateTime? _startedAtUtc;
  int? _targetDurationSeconds;
  Timer? _ticker;

  RestPresenceService({
    RestPresenceDriver? driver,
    DateTime Function()? nowUtc,
  })  : _driver = driver ?? LocalNotificationRestPresenceDriver(),
        _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  RestPresenceState get state => _state;
  bool get isActive => _state == RestPresenceState.active;
  String? get currentPeriodId => _currentPeriodId;
  String? get currentExerciseName => _currentExerciseName;
  DateTime? get startedAtUtc => _startedAtUtc;
  int? get targetDurationSeconds => _targetDurationSeconds;

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

  /// Start background presence for a rest period.
  Future<void> startRest({
    required String periodId,
    required String exerciseName,
    required int targetSeconds,
    DateTime? startedAtUtc,
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
    if (remaining <= 0) {
      await onRestElapsed(periodId: periodId);
      return;
    }

    await _driver.showOngoingRestNotification(
      id: ongoingNotificationId,
      exerciseName: _currentExerciseName ?? '',
      remainingSeconds: remaining,
      totalSeconds: _targetDurationSeconds!,
      channelId: channelId,
      channelName: channelName,
      expiryUtc:
          _startedAtUtc?.add(Duration(seconds: _targetDurationSeconds!)),
    );

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
          expiryUtc:
              _startedAtUtc?.add(Duration(seconds: _targetDurationSeconds!)),
        );
      }
    });
  }

  /// Called when the rest period reaches 0 or is completed due to timer elapsing.
  Future<void> onRestElapsed({required String periodId}) async {
    if (_state != RestPresenceState.active || _currentPeriodId != periodId) {
      // If already expired or not matching current, still ensure ongoing notification is removed
      await _driver.cancelNotification(ongoingNotificationId);
      return;
    }

    _ticker?.cancel();
    _ticker = null;
    _state = RestPresenceState.expired;

    // Dismiss ongoing progress notification
    await _driver.cancelNotification(ongoingNotificationId);

    // Fire expiry notification and haptic confirmation
    await _driver.showRestExpiredNotification(
      id: expiredNotificationId,
      exerciseName: _currentExerciseName ?? '',
      channelId: channelId,
      channelName: channelName,
    );
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

    await _driver.cancelNotification(ongoingNotificationId);
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

    await _driver.cancelNotification(ongoingNotificationId);
    await _driver.cancelNotification(expiredNotificationId);
  }

  /// Clean up stale rest notifications at app startup or when entering foreground.
  static Future<void> cleanupStaleNotifications([RestPresenceDriver? driver]) async {
    final d = driver ?? LocalNotificationRestPresenceDriver();
    await d.cancelNotification(ongoingNotificationId);
  }
}
