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
  final bool allowOnlineNutrition;

  const PrivacyPolicy({
    required this.isOfflineOnly,
    required this.isTelemetryEnabled,
    this.connectedAiEnabled = AppConfig.connectedAiEnabled,
    this.allowOnlineNutrition = true,
  });

  /// Connected AI assistance is permitted when enabled in configuration and
  /// offline-only mode is not active.
  bool get isAiAllowed => connectedAiEnabled && !isOfflineOnly;

  /// Sending a photo to the AI tools (meal photo, nutrition label) is
  /// permitted when connected AI is allowed. IndiFit doesn't keep the photo;
  /// Google may keep it briefly for abuse monitoring (Gemini API terms).
  bool get isImageUploadAllowed => isAiAllowed;

  /// Third-party Open Food Facts lookups are permitted only when offline-only mode is disabled.
  bool get isOpenFoodFactsAllowed => !isOfflineOnly;

  /// Online nutrition search proxy and barcode lookups are permitted only when
  /// offline-only mode is disabled AND online nutrition preference is enabled.
  bool get isNutritionOnlineAllowed => !isOfflineOnly && allowOnlineNutrition;

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
          allowOnlineNutrition:
              initialPrefs?.getBool(prefOnlineNutritionAllowed) ?? true,
        ),
      ) {
    if (initialPrefs == null) {
      loadPolicy();
    }
  }

  static const String prefOfflineOnly = AppPreferenceKeys.offlineOnly;
  static const String prefCrashReportingEnabled =
      AppPreferenceKeys.crashReportingEnabled;
  static const String prefOnlineNutritionAllowed =
      AppPreferenceKeys.onlineNutritionAllowed;

  Future<void> loadPolicy() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final offline = prefs.getBool(prefOfflineOnly) ?? false;
    final telemetry =
        !offline && (prefs.getBool(prefCrashReportingEnabled) ?? false);
    final nutrition = prefs.getBool(prefOnlineNutritionAllowed) ?? true;

    state = PrivacyPolicy(
      isOfflineOnly: offline,
      isTelemetryEnabled: telemetry,
      allowOnlineNutrition: nutrition,
    );
  }

  Future<void> setOfflineOnly(bool offline) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setBool(prefOfflineOnly, offline);
    if (offline) {
      await prefs.setBool(prefCrashReportingEnabled, false);
      state = PrivacyPolicy(
        isOfflineOnly: true,
        isTelemetryEnabled: false,
        allowOnlineNutrition: state.allowOnlineNutrition,
      );
    } else {
      final telemetry = prefs.getBool(prefCrashReportingEnabled) ?? false;
      final nutrition = prefs.getBool(prefOnlineNutritionAllowed) ?? true;
      state = PrivacyPolicy(
        isOfflineOnly: false,
        isTelemetryEnabled: telemetry,
        allowOnlineNutrition: nutrition,
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
      allowOnlineNutrition: state.allowOnlineNutrition,
    );
  }

  Future<void> setOnlineNutritionAllowed(bool allowed) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setBool(prefOnlineNutritionAllowed, allowed);
    state = PrivacyPolicy(
      isOfflineOnly: state.isOfflineOnly,
      isTelemetryEnabled: state.isTelemetryEnabled,
      allowOnlineNutrition: allowed,
    );
  }
}

final privacyPolicyProvider =
    StateNotifierProvider<PrivacyPolicyNotifier, PrivacyPolicy>((ref) {
      SharedPreferences? prefs = sharedPreferencesOrNull(
        () => ref.watch(sharedPreferencesProvider),
      );
      return PrivacyPolicyNotifier(prefs);
    });
