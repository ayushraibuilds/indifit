import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_preferences_keys.dart';
import '../utils/app_logger.dart';
import 'notification_service.dart';

/// The two one-time asks the rest timer can make.
enum RestAlertPrompt {
  /// Explains rest alerts before the OS notification prompt (iOS, and
  /// Android 13+ `POST_NOTIFICATIONS`).
  notifications,

  /// Android 14+ only: exact alarms are off by default, so the rest alert can
  /// arrive a few minutes late. Offers the "Alarms & reminders" setting.
  preciseAlarms,
}

/// Shows the ask for [prompt] and returns true when the user chose to
/// continue, false for "Not now", and null when it went away unanswered (the
/// rest ended first). Registered by the workout player, which owns a context.
typedef RestAlertPromptPresenter =
    Future<bool?> Function(RestAlertPrompt prompt);

/// Asks for rest-alert permissions once, on the first rest, instead of only
/// from the Settings reminder toggles (audit R-02). An answer is stored so it
/// never repeats, whatever it was; an ask left unanswered comes back on a
/// later rest.
class RestAlertPermissionService {
  RestAlertPermissionService({
    Future<bool> Function()? requestNotifications,
    Future<bool> Function()? notificationsGranted,
    Future<bool?> Function()? canScheduleExactAlarms,
    Future<void> Function()? openExactAlarmSettings,
    Future<SharedPreferences> Function()? preferences,
  }) : _requestNotifications =
           requestNotifications ?? NotificationService.requestPermissions,
       _notificationsGranted =
           notificationsGranted ??
           (() async =>
               await NotificationService.checkPermissionStatus() ==
               NotificationPermissionStatus.granted),
       _canScheduleExactAlarms =
           canScheduleExactAlarms ?? NotificationService.canScheduleExactAlarms,
       _openExactAlarmSettings =
           openExactAlarmSettings ?? NotificationService.openExactAlarmSettings,
       _preferences = preferences ?? SharedPreferences.getInstance;

  static RestAlertPermissionService? _instance;

  /// Process-wide default used by the production workout providers.
  static RestAlertPermissionService get instance =>
      _instance ??= RestAlertPermissionService();

  /// Replaces [instance] in tests; null restores the default.
  @visibleForTesting
  static set debugInstance(RestAlertPermissionService? value) =>
      _instance = value;

  final Future<bool> Function() _requestNotifications;
  final Future<bool> Function() _notificationsGranted;
  final Future<bool?> Function() _canScheduleExactAlarms;
  final Future<void> Function() _openExactAlarmSettings;
  final Future<SharedPreferences> Function() _preferences;

  RestAlertPromptPresenter? _presenter;
  Object? _presenterOwner;
  Future<void>? _inFlight;

  void registerPresenter(RestAlertPromptPresenter presenter, {Object? owner}) {
    _presenter = presenter;
    _presenterOwner = owner;
  }

  /// Clears the presenter. With [owner], only when [owner] registered it.
  void unregisterPresenter({Object? owner}) {
    if (owner != null && !identical(_presenterOwner, owner)) return;
    _presenter = null;
    _presenterOwner = null;
  }

  /// Called after a rest starts. Makes at most one ask per rest: the
  /// notification ask first, then (on a later rest) the precise-alarm offer.
  /// Overlapping calls share one run so a sheet is never shown twice.
  Future<void> onRestStarted() {
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  Future<void> _run() async {
    final presenter = _presenter;
    // Without a screen to explain first, wait for a later rest.
    if (presenter == null) return;
    try {
      final prefs = await _preferences();
      if (prefs.getBool(AppPreferenceKeys.restAlertPermissionAsked) != true) {
        // Already allowed from Settings: nothing to ask.
        if (!await _notificationsGranted()) {
          final answer = await presenter(RestAlertPrompt.notifications);
          if (answer == null) return;
          await prefs.setBool(AppPreferenceKeys.restAlertPermissionAsked, true);
          if (answer) await _requestNotifications();
          return;
        }
        await prefs.setBool(AppPreferenceKeys.restAlertPermissionAsked, true);
      }

      if (prefs.getBool(AppPreferenceKeys.restAlertPreciseOffered) != true) {
        // Null means not Android, or the OS doesn't gate exact alarms.
        if (await _canScheduleExactAlarms() != false) return;
        final answer = await presenter(RestAlertPrompt.preciseAlarms);
        if (answer == null) return;
        await prefs.setBool(AppPreferenceKeys.restAlertPreciseOffered, true);
        if (answer) await _openExactAlarmSettings();
      }
    } catch (error) {
      AppLogger.warning(
        'Rest alert permission ask failed: $error',
        'RestAlerts',
      );
    }
  }
}
