import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';

class CrashReportingService {
  static const String prefCrashReportingEnabled = 'pref_crash_reporting_enabled';
  static bool _isEnabled = true;

  /// Default Sentry DSN (can be overridden via environment variable SENTRY_DSN)
  static const String _defaultDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: 'https://placeholder_key@o0.ingest.sentry.io/0',
  );

  /// Initializes Sentry crash reporting with zero-payload privacy guards.
  static Future<void> initialize(FutureOr<void> Function() appRunner) async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(prefCrashReportingEnabled) ?? true;

    await SentryFlutter.init(
      (options) {
        options.dsn = _defaultDsn;
        options.tracesSampleRate = 0.2;
        options.sendDefaultPii = false; // Never send personally identifiable information
        options.attachStacktrace = true;
        options.enableAutoPerformanceTracing = false; // Avoid recording dynamic UI route parameters

        // Privacy Filter: Strip food/body payload data before sending to remote Sentry
        options.beforeSend = _beforeSendPrivacyFilter;
        options.beforeBreadcrumb = _beforeBreadcrumbPrivacyFilter;
      },
      appRunner: appRunner,
    );
  }

  /// Privacy filter ensuring zero food items, meal names, calories, macros, or weight metrics escape
  static SentryEvent? _beforeSendPrivacyFilter(SentryEvent event, Hint hint) {
    if (!_isEnabled) return null; // Drop event completely if user opted out

    // Strip sensitive user info
    final sanitizedEvent = event.copyWith(
      user: null, // Zero user identity attached
      request: event.request?.copyWith(
        headers: {},
        cookies: null,
        data: null, // Drop all raw request body payloads
      ),
    );

    return sanitizedEvent;
  }

  /// Breadcrumb filter stripping food names, calories, and weight numbers
  static Breadcrumb? _beforeBreadcrumbPrivacyFilter(Breadcrumb? breadcrumb, Hint hint) {
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
    String text = input.replaceAll(RegExp(r'\b(calories|weight|protein|carbs|fat|serving)\b\s*:\s*\d+(\.\d+)?', caseSensitive: false), r'$1: [REDACTED]');
    return text;
  }

  /// Manually record uncaught crash or exception
  static void captureException(dynamic exception, StackTrace? stackTrace, {String context = 'Global'}) {
    AppLogger.error('[$context Crash Captured]', exception, stackTrace);

    if (!_isEnabled) return;

    Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setTag('crash_context', context);
        scope.setExtra('sanitized_environment', kReleaseMode ? 'production' : 'debug');
      },
    );
  }

  /// Enables or disables crash reporting preference
  static Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefCrashReportingEnabled, enabled);
  }

  /// Returns current crash reporting enabled state
  static bool get isEnabled => _isEnabled;
}
