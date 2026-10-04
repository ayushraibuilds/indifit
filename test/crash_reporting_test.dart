import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/config/app_preferences_keys.dart';
import 'package:indifit/core/services/crash_reporting_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var inits = 0;
  var closes = 0;

  setUp(() {
    inits = 0;
    closes = 0;
    CrashReportingService.debugReset();
    CrashReportingService.debugDsnOverride = null;
    CrashReportingService.sentryInitRunner = (configure, {appRunner}) async {
      inits++;
      await appRunner?.call();
    };
    CrashReportingService.sentryCloseRunner = () async => closes++;
  });

  tearDown(() => CrashReportingService.debugDsnOverride = null);

  group('CrashReportingService Privacy & Toggle Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        CrashReportingService.prefCrashReportingEnabled: true,
      });
      await CrashReportingService.initialize(() {});
    });

    test('CrashReportingService respects user preference toggle', () async {
      expect(CrashReportingService.isEnabled, isTrue);

      await CrashReportingService.setEnabled(false);
      expect(CrashReportingService.isEnabled, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(CrashReportingService.prefCrashReportingEnabled),
        isFalse,
      );
    });

    test('CrashReportingService captures exception without throwing error', () {
      expect(
        () => CrashReportingService.captureException(
          FormatException('Test crash exception'),
          StackTrace.current,
          context: 'UnitTestContext',
        ),
        returnsNormally,
      );
    });
  });

  group('takes effect without a restart', () {
    test('opting in mid-session starts Sentry once', () async {
      SharedPreferences.setMockInitialValues({});
      CrashReportingService.debugDsnOverride =
          'https://key@o1.ingest.sentry.io/1';
      await CrashReportingService.initialize(() {});
      expect(inits, 0); // opted out at launch

      await CrashReportingService.setEnabled(true);
      await CrashReportingService.setEnabled(true);

      expect(inits, 1);
      expect(CrashReportingService.isEnabled, isTrue);
    });

    test('opting out mid-session stops Sentry', () async {
      SharedPreferences.setMockInitialValues({
        CrashReportingService.prefCrashReportingEnabled: true,
      });
      CrashReportingService.debugDsnOverride =
          'https://key@o1.ingest.sentry.io/1';
      await CrashReportingService.initialize(() {});
      expect(inits, 1);

      await CrashReportingService.setEnabled(false);

      expect(closes, 1);
      expect(CrashReportingService.isEnabled, isFalse);
    });

    test('a build without a DSN never starts Sentry', () async {
      for (final dsn in ['', 'https://placeholder_key@o0.ingest.sentry.io/0']) {
        SharedPreferences.setMockInitialValues({});
        CrashReportingService.debugReset();
        CrashReportingService.debugDsnOverride = dsn;
        await CrashReportingService.setEnabled(true);
      }
      expect(inits, 0);
    });

    test('offline-only mode blocks opting in', () async {
      SharedPreferences.setMockInitialValues({
        AppPreferenceKeys.offlineOnly: true,
      });
      CrashReportingService.debugDsnOverride =
          'https://key@o1.ingest.sentry.io/1';
      await CrashReportingService.setEnabled(true);

      expect(inits, 0);
      expect(CrashReportingService.isEnabled, isFalse);
    });
  });

  test('events carry no user text', () async {
    SharedPreferences.setMockInitialValues({});
    await CrashReportingService.setEnabled(true);
    final event = SentryEvent(
      message: SentryMessage('Could not parse 2 aloo paratha'),
      exceptions: [
        SentryException(
          type: 'FormatException',
          value: 'FormatException: 2 aloo paratha',
        ),
      ],
    );

    final scrubbed = CrashReportingService.debugScrub(event)!;
    final json = jsonEncode(scrubbed.toJson());

    expect(json, isNot(contains('aloo')));
    expect(scrubbed.exceptions!.single.type, 'FormatException');
  });
}
