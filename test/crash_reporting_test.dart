import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/config/app_preferences_keys.dart';
import 'package:indifit/core/services/crash_reporting_service.dart';
import 'package:indifit/core/utils/app_logger.dart';
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

  test(
    'Sentry is configured for crash reports only, without tracing',
    () async {
      SharedPreferences.setMockInitialValues({
        CrashReportingService.prefCrashReportingEnabled: true,
      });
      CrashReportingService.debugDsnOverride =
          'https://key@o0.ingest.sentry.io/1';
      FutureOr<void> Function(SentryFlutterOptions)? configure;
      CrashReportingService.sentryInitRunner = (c, {appRunner}) async {
        configure = c;
        await appRunner?.call();
      };

      await CrashReportingService.initialize(() {});
      final options = SentryFlutterOptions();
      await configure!(options);

      expect(options.tracesSampleRate, isNull);
      expect(options.tracesSampler, isNull);
      expect(options.enableAutoPerformanceTracing, isFalse);
      expect(options.sendDefaultPii, isFalse);
    },
  );

  group('log breadcrumbs (R-5)', () {
    final crumbs = <Breadcrumb>[];

    setUp(() {
      crumbs.clear();
      CrashReportingService.breadcrumbSink = crumbs.add;
    });

    Future<void> enable({required bool optIn, required bool started}) async {
      SharedPreferences.setMockInitialValues({
        CrashReportingService.prefCrashReportingEnabled: optIn,
      });
      await CrashReportingService.initialize(() {});
      CrashReportingService.debugReset();
      if (started) CrashReportingService.debugMarkStarted();
    }

    test('nothing is added while opted out or without a DSN', () async {
      await enable(optIn: false, started: true);
      AppLogger.error('Failed to save meal');
      AppLogger.warning('Slow query');

      await enable(optIn: true, started: false); // placeholder DSN
      AppLogger.error('Failed to save meal');

      expect(crumbs, isEmpty);
    });

    test(
      'error and warning add the category, level and error type only',
      () async {
        await enable(optIn: true, started: true);
        AppLogger.error(
          'Failed to log Paneer Tikka 250g for food-seed-123',
          StateError('boom'),
          null,
          'FoodLog',
        );
        AppLogger.error('Save failed: "masala dosa"', null, null, 'FoodLog');
        AppLogger.warning('Search slow: "masala dosa" took 812 ms', 'Search');
        AppLogger.info('not a breadcrumb');

        expect(crumbs, hasLength(3));
        expect(crumbs[0].category, 'FoodLog');
        expect(crumbs[0].level, SentryLevel.error);
        expect(crumbs[0].message, 'StateError');
        expect(crumbs[0].data, isNull);
        expect(crumbs[1].message, isNull);
        expect(crumbs[2].category, 'Search');
        expect(crumbs[2].level, SentryLevel.warning);
        expect(crumbs[2].message, isNull);
        for (final crumb in crumbs) {
          expect('${crumb.message}', isNot(contains('dosa')));
          expect('${crumb.message}', isNot(contains('Paneer')));
        }
      },
    );

    test('an odd tag falls back to a generic category', () async {
      await enable(optIn: true, started: true);
      AppLogger.warning('Retrying', 'user_42::id');
      expect(crumbs.single.category, 'log');
    });
  });
}
