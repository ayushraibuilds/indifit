import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../config/app_preferences_keys.dart';
import '../di/core_providers.dart';

/// Centralized Privacy & Network Policy model.
class PrivacyPolicy {
  final bool isOfflineOnly;
  final bool isTelemetryEnabled;
  final bool connectedAiEnabled;

  const PrivacyPolicy({
    required this.isOfflineOnly,
    required this.isTelemetryEnabled,
    this.connectedAiEnabled = AppConfig.connectedAiEnabled,
  });

  /// Connected AI assistance is permitted when enabled in configuration and
  /// offline-only mode is not active.
  bool get isAiAllowed => connectedAiEnabled && !isOfflineOnly;

  /// Ephemeral image processing (e.g. nutrition label OCR) is permitted when
  /// connected AI is allowed. Images are processed ephemerally and never retained.
  bool get isImageUploadAllowed => isAiAllowed;

  /// Third-party Open Food Facts lookups are permitted only when offline-only mode is disabled.
  bool get isOpenFoodFactsAllowed => !isOfflineOnly;

  /// Crash reporting and telemetry are permitted only when offline-only mode is disabled
  /// AND affirmative user consent is given.
  bool get isTelemetryAllowed => !isOfflineOnly && isTelemetryEnabled;
}

class PrivacyPolicyNotifier extends StateNotifier<PrivacyPolicy> {
  final SharedPreferences? _prefs;

  PrivacyPolicyNotifier([SharedPreferences? initialPrefs])
    : _prefs = initialPrefs,
      super(
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

  static const String prefOfflineOnly = AppPreferenceKeys.offlineOnly;
  static const String prefCrashReportingEnabled =
      AppPreferenceKeys.crashReportingEnabled;

  Future<void> loadPolicy() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final offline = prefs.getBool(prefOfflineOnly) ?? false;
    final telemetry =
        !offline && (prefs.getBool(prefCrashReportingEnabled) ?? false);

    state = PrivacyPolicy(
      isOfflineOnly: offline,
      isTelemetryEnabled: telemetry,
    );
  }

  Future<void> setOfflineOnly(bool offline) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
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
    final prefs = _prefs ?? await SharedPreferences.getInstance();
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
      SharedPreferences? prefs;
      try {
        prefs = ref.watch(sharedPreferencesProvider);
      } catch (_) {}
      return PrivacyPolicyNotifier(prefs);
    });
