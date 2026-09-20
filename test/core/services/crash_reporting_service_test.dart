import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/config/app_preferences_keys.dart';
import 'package:indifit/core/services/crash_reporting_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CrashReportingService Startup Guard Tests (Sprint A1)', () {
    tearDown(() {
      CrashReportingService.debugDsnOverride = null;
      CrashReportingService.sentryInitRunner = SentryFlutter.init;
    });

    test('Bypasses Sentry initialization when user opted out of telemetry', () async {
      SharedPreferences.setMockInitialValues({
        AppPreferenceKeys.crashReportingEnabled: false,
        AppPreferenceKeys.offlineOnly: false,
      });

      var sentryInitCalled = false;
      var appRunnerCalled = false;

      CrashReportingService.sentryInitRunner = (
        FutureOr<void> Function(SentryFlutterOptions) optionsCallback, {
        FutureOr<void> Function()? appRunner,
      }) async {
        sentryInitCalled = true;
        if (appRunner != null) await appRunner();
      };

      await CrashReportingService.initialize(() {
        appRunnerCalled = true;
      });

      expect(sentryInitCalled, isFalse, reason: 'Sentry init must be bypassed when opted out');
      expect(appRunnerCalled, isTrue, reason: 'appRunner must still be invoked to launch the app');
      expect(CrashReportingService.isEnabled, isFalse);
    });

    test('Bypasses Sentry initialization when offlineOnly is true', () async {
      SharedPreferences.setMockInitialValues({
        AppPreferenceKeys.crashReportingEnabled: true,
        AppPreferenceKeys.offlineOnly: true,
      });

      var sentryInitCalled = false;
      var appRunnerCalled = false;

      CrashReportingService.sentryInitRunner = (
        FutureOr<void> Function(SentryFlutterOptions) optionsCallback, {
        FutureOr<void> Function()? appRunner,
      }) async {
        sentryInitCalled = true;
        if (appRunner != null) await appRunner();
      };

      await CrashReportingService.initialize(() {
        appRunnerCalled = true;
      });

      expect(sentryInitCalled, isFalse, reason: 'Sentry init must be bypassed when offline-only');
      expect(appRunnerCalled, isTrue, reason: 'appRunner must still be invoked');
      expect(CrashReportingService.isEnabled, isFalse);
    });

    test('Bypasses Sentry initialization when DSN is default placeholder', () async {
      SharedPreferences.setMockInitialValues({
        AppPreferenceKeys.crashReportingEnabled: true,
        AppPreferenceKeys.offlineOnly: false,
      });

      var sentryInitCalled = false;
      var appRunnerCalled = false;

      CrashReportingService.sentryInitRunner = (
        FutureOr<void> Function(SentryFlutterOptions) optionsCallback, {
        FutureOr<void> Function()? appRunner,
      }) async {
        sentryInitCalled = true;
        if (appRunner != null) await appRunner();
      };

      await CrashReportingService.initialize(() {
        appRunnerCalled = true;
      });

      expect(sentryInitCalled, isFalse, reason: 'Sentry init must be bypassed when DSN contains placeholder_key');
      expect(appRunnerCalled, isTrue, reason: 'appRunner must still be invoked');
      expect(CrashReportingService.isEnabled, isTrue);
    });

    test('Executes Sentry initialization when telemetry is enabled and DSN is valid', () async {
      SharedPreferences.setMockInitialValues({
        AppPreferenceKeys.crashReportingEnabled: true,
        AppPreferenceKeys.offlineOnly: false,
      });

      CrashReportingService.debugDsnOverride = 'https://prod_valid_key@o0.ingest.sentry.io/99999';

      var sentryInitCalled = false;
      var appRunnerCalled = false;
      String? configuredDsn;

      CrashReportingService.sentryInitRunner = (
        FutureOr<void> Function(SentryFlutterOptions) optionsCallback, {
        FutureOr<void> Function()? appRunner,
      }) async {
        sentryInitCalled = true;
        final options = SentryFlutterOptions();
        await optionsCallback(options);
        configuredDsn = options.dsn;
        if (appRunner != null) await appRunner();
      };

      await CrashReportingService.initialize(() {
        appRunnerCalled = true;
      });

      expect(sentryInitCalled, isTrue, reason: 'Sentry init must be executed with valid DSN');
      expect(appRunnerCalled, isTrue, reason: 'appRunner must be invoked');
      expect(configuredDsn, equals('https://prod_valid_key@o0.ingest.sentry.io/99999'));
      expect(CrashReportingService.isEnabled, isTrue);
    });
  });
}
