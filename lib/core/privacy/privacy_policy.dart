import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized Privacy & Network Policy model.
class PrivacyPolicy {
  final bool isOfflineOnly;
  final bool isTelemetryEnabled;

  const PrivacyPolicy({
    required this.isOfflineOnly,
    required this.isTelemetryEnabled,
  });

  /// Backend AI text generation is permitted only when offline-only mode is disabled.
  bool get isAiAllowed => !isOfflineOnly;

  /// Meal photo uploads to backend AI are permitted only when offline-only mode is disabled.
  bool get isImageUploadAllowed => !isOfflineOnly;

  /// Third-party Open Food Facts lookups are permitted only when offline-only mode is disabled.
  bool get isOpenFoodFactsAllowed => !isOfflineOnly;

  /// Crash reporting and telemetry are permitted only when offline-only mode is disabled
  /// AND affirmative user consent is given.
  bool get isTelemetryAllowed => !isOfflineOnly && isTelemetryEnabled;
}

class PrivacyPolicyNotifier extends StateNotifier<PrivacyPolicy> {
  PrivacyPolicyNotifier([SharedPreferences? initialPrefs])
    : super(
        PrivacyPolicy(
          isOfflineOnly: initialPrefs?.getBool(prefOfflineOnly) ?? false,
          isTelemetryEnabled:
              !(initialPrefs?.getBool(prefOfflineOnly) ?? false) &&
              (initialPrefs?.getBool(prefCrashReportingEnabled) ?? false),
        ),
      ) {
    if (initialPrefs == null) {
      loadPolicy();
    }
  }

  static const String prefOfflineOnly = 'offline_only';
  static const String prefCrashReportingEnabled =
      'pref_crash_reporting_enabled';

  Future<void> loadPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    final offline = prefs.getBool(prefOfflineOnly) ?? false;
    final telemetry =
        !offline && (prefs.getBool(prefCrashReportingEnabled) ?? false);

    state = PrivacyPolicy(
      isOfflineOnly: offline,
      isTelemetryEnabled: telemetry,
    );
  }

  Future<void> setOfflineOnly(bool offline) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefOfflineOnly, offline);
    if (offline) {
      await prefs.setBool(prefCrashReportingEnabled, false);
      state = const PrivacyPolicy(
        isOfflineOnly: true,
        isTelemetryEnabled: false,
      );
    } else {
      final telemetry = prefs.getBool(prefCrashReportingEnabled) ?? false;
      state = PrivacyPolicy(
        isOfflineOnly: false,
        isTelemetryEnabled: telemetry,
      );
    }
  }

  Future<void> setTelemetryEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final effectiveTelemetry = state.isOfflineOnly ? false : enabled;
    await prefs.setBool(prefCrashReportingEnabled, effectiveTelemetry);
    state = PrivacyPolicy(
      isOfflineOnly: state.isOfflineOnly,
      isTelemetryEnabled: effectiveTelemetry,
    );
  }
}

final privacyPolicyProvider =
    StateNotifierProvider<PrivacyPolicyNotifier, PrivacyPolicy>((ref) {
      return PrivacyPolicyNotifier();
    });
