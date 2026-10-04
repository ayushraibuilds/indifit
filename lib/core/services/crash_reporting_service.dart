import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_preferences_keys.dart';
import '../utils/app_logger.dart';

class CrashReportingService {
  static const String prefCrashReportingEnabled =
      AppPreferenceKeys.crashReportingEnabled;
  static bool _isEnabled = false; // Default telemetry to OFF (opt-in)

  /// Default Sentry DSN (can be overridden via environment variable SENTRY_DSN)
  static const String _defaultDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: 'https://placeholder_key@o0.ingest.sentry.io/0',
  );

  /// Test hook to simulate non-placeholder DSNs in unit tests
  @visibleForTesting
  static String? debugDsnOverride;

  /// Test hook to intercept SentryFlutter.init in unit tests
  @visibleForTesting
  static Future<void> Function(
    FutureOr<void> Function(SentryFlutterOptions), {
    FutureOr<void> Function()? appRunner,
  })
  sentryInitRunner = SentryFlutter.init;

  /// Initializes Sentry crash reporting with zero-payload privacy guards.
  static Future<void> initialize(
    FutureOr<void> Function() appRunner, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final isOffline = p.getBool(AppPreferenceKeys.offlineOnly) ?? false;
    final userTelemetryOptIn = p.getBool(prefCrashReportingEnabled) ?? false;

    // Telemetry is allowed ONLY if not offline-only AND user explicitly opted in
    _isEnabled = !isOffline && userTelemetryOptIn;

    if (!_isEnabled || !_hasRealDsn) {
      AppLogger.info(
        'Sentry crash reporting disabled (opt-out or no DSN in this build).',
      );
      await appRunner();
      return;
    }

    _sentryStarted = true;
    await sentryInitRunner(_configure, appRunner: appRunner);
  }

  /// Whether Sentry is running in this process.
  static bool _sentryStarted = false;

  static String get _effectiveDsn => debugDsnOverride ?? _defaultDsn;

  /// Release builds pass SENTRY_DSN; without it (an empty define or the
  /// placeholder) reporting can't run, whatever the user chose.
  static bool get _hasRealDsn =>
      _effectiveDsn.trim().isNotEmpty &&
      !_effectiveDsn.contains('placeholder_key');

  static void _configure(SentryFlutterOptions options) {
    options.dsn = _effectiveDsn;
    options.tracesSampleRate = 0.2;
    options.sendDefaultPii =
        false; // Never send personally identifiable information
    options.attachStacktrace = true;
    options.enableAutoPerformanceTracing =
        false; // Avoid recording dynamic UI route parameters

    // Privacy Filter: Strip food/body payload data before sending to remote Sentry
    options.beforeSend = _beforeSendPrivacyFilter;
    options.beforeBreadcrumb = _beforeBreadcrumbPrivacyFilter;
  }

  /// Privacy filter ensuring zero food items, meal names, calories, macros, or weight metrics escape
  static SentryEvent? _beforeSendPrivacyFilter(SentryEvent event, Hint hint) {
    if (!_isEnabled) return null; // Drop event completely if user opted out

    // Strip sensitive user info. Messages and exception values can quote
    // user text (a food name in a FormatException), so they are replaced;
    // the exception type and stack trace are enough to triage.
    final sanitizedEvent = event.copyWith(
      user: null, // Zero user identity attached
      request: event.request?.copyWith(
        headers: {},
        cookies: null,
        data: null, // Drop all raw request body payloads
      ),
      message: event.message == null ? null : SentryMessage(_redacted),
      exceptions: event.exceptions
          ?.map((exception) => exception.copyWith(value: _redacted))
          .toList(),
    );

    return sanitizedEvent;
  }

  /// Breadcrumb filter stripping food names, calories, and weight numbers
  static Breadcrumb? _beforeBreadcrumbPrivacyFilter(
    Breadcrumb? breadcrumb,
    Hint hint,
  ) {
    if (!_isEnabled || breadcrumb == null) return null;

    final message = breadcrumb.message ?? '';
    final sanitizedMessage = _sanitizeText(message);

    return breadcrumb.copyWith(
      message: sanitizedMessage,
      data: null, // Strip extra data dictionary payloads
    );
  }

  /// Regex sanitizer to replace potential numeric metric patterns or food strings
  static String _sanitizeText(String input) {
    if (input.isEmpty) return input;
    // Replace numeric values following key terms like calories, weight, protein, etc.
    String text = input.replaceAll(
      RegExp(
        r'\b(calories|weight|protein|carbs|fat|serving)\b\s*:\s*\d+(\.\d+)?',
        caseSensitive: false,
      ),
      r'$1: [REDACTED]',
    );
    return text;
  }

  /// Manually record uncaught crash or exception
  static void captureException(
    dynamic exception,
    StackTrace? stackTrace, {
    String context = 'Global',
  }) {
    AppLogger.error('[$context Crash Captured]', exception, stackTrace);

    if (!_isEnabled) return;

    Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('crash_context', context);
        // ignore: deprecated_member_use
        scope.setExtra(
          'sanitized_environment',
          kReleaseMode ? 'production' : 'debug',
        );
      },
    );
  }

  /// Alias for captureException to support recordCrash calls
  static void recordCrash(
    dynamic exception,
    StackTrace? stackTrace, {
    String context = 'Global',
    String? reason,
  }) {
    captureException(exception, stackTrace, context: reason ?? context);
  }

  /// Enables or disables crash reporting preference
  static Future<void> setEnabled(
    bool enabled, [
    SharedPreferences? prefs,
  ]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final isOffline = p.getBool(AppPreferenceKeys.offlineOnly) ?? false;
    final effectiveEnabled = enabled && !isOffline;
    _isEnabled = effectiveEnabled;
    await p.setBool(prefCrashReportingEnabled, effectiveEnabled);

    // Take effect now, not on the next launch: start Sentry on opt-in (this
    // session's errors are caught; startup crashes from the next launch) and
    // stop it on opt-out so nothing queued is sent.
    if (effectiveEnabled && !_sentryStarted && _hasRealDsn) {
      _sentryStarted = true;
      await sentryInitRunner(_configure);
    } else if (!effectiveEnabled && _sentryStarted) {
      _sentryStarted = false;
      await sentryCloseRunner();
    }
  }

  /// Test hook to intercept Sentry.close in unit tests.
  @visibleForTesting
  static Future<void> Function() sentryCloseRunner = Sentry.close;

  /// Test hook: forget whether Sentry was started.
  @visibleForTesting
  static void debugReset() => _sentryStarted = false;

  static const _redacted = '<redacted>';

  /// Test hook for the privacy filter applied to every event.
  @visibleForTesting
  static SentryEvent? debugScrub(SentryEvent event) =>
      _beforeSendPrivacyFilter(event, Hint());

  /// Returns current crash reporting enabled state
  static bool get isEnabled => _isEnabled;

  /// Whether Settings offers the opt-in. A release build without a DSN can't
  /// report anything, so it doesn't show a toggle that would do nothing.
  /// Debug and profile builds keep it for development and tests.
  static bool get isOptInOffered => !kReleaseMode || _hasRealDsn;
}
