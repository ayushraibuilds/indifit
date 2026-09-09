import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/models/b02_progress_read_models.dart';
import 'package:indifit/data/repositories/health_service.dart';
import 'package:indifit/features/dashboard/today_consumer_presentation.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:indifit/features/dashboard/widgets/today_module_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHealth implements Health {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  bool hasPermissionsResult = true;
  int? totalStepsResult = 5432;
  List<HealthDataPoint> dataPointsResult = [];
  HealthPlatformType platform = HealthPlatformType.appleHealth;

  @override
  HealthPlatformType get platformType => platform;

  @override
  Future<void> configure() async {}

  @override
  bool isDataTypeAvailable(HealthDataType dataType) => true;

  @override
  Future<bool?> hasPermissions(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async => hasPermissionsResult;

  @override
  Future<int?> getTotalStepsInInterval(
    DateTime startTime,
    DateTime endTime, {
    bool includeManualEntry = true,
  }) async => totalStepsResult;

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    required DateTime startTime,
    required DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter = const [],
  }) async => dataPointsResult;
}

HealthDataPoint _createDataPoint({
  required HealthDataType type,
  required HealthValue value,
  required DateTime from,
  required DateTime to,
  required String sourceName,
  required String sourceId,
}) {
  return HealthDataPoint(
    uuid:
        '${from.millisecondsSinceEpoch}_${to.millisecondsSinceEpoch}_${sourceId}_${type.name}',
    type: type,
    value: value,
    unit: HealthDataUnit.NO_UNIT,
    dateFrom: from,
    dateTo: to,
    sourcePlatform: HealthPlatformType.appleHealth,
    sourceDeviceId: 'device-1',
    sourceId: sourceId,
    sourceName: sourceName,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      HealthService.integrationEnabledPrefKey: true,
    });
  });

  group('PV1-HEALTH-01: HealthSourceSanitizer', () {
    test('sanitizes well-known Android packages to user-facing names', () {
      expect(
        HealthSourceSanitizer.sanitize('com.google.android.apps.fitness'),
        'Google Fit',
      );
      expect(
        HealthSourceSanitizer.sanitize('com.sec.android.app.shealth'),
        'Samsung Health',
      );
      expect(
        HealthSourceSanitizer.sanitize('com.garmin.android.apps.connectmobile'),
        'Garmin Connect',
      );
      expect(
        HealthSourceSanitizer.sanitize('com.fitbit.FitbitMobile'),
        'Fitbit',
      );
      expect(HealthSourceSanitizer.sanitize('com.ouraring.oura'), 'Oura');
      expect(HealthSourceSanitizer.sanitize('com.whoop.experience'), 'WHOOP');
      expect(HealthSourceSanitizer.sanitize('com.strava'), 'Strava');
      expect(HealthSourceSanitizer.sanitize('com.nike.plusgps'), 'Nike Run Club');
      expect(HealthSourceSanitizer.sanitize('com.huawei.health'), 'Huawei Health');
      expect(HealthSourceSanitizer.sanitize('com.polar.polarflow'), 'Polar Flow');
      expect(
        HealthSourceSanitizer.sanitize('com.google.android.apps.healthdata'),
        'Health Connect',
      );
    });

    test('sanitizes iOS bundle IDs and clean names', () {
      expect(HealthSourceSanitizer.sanitize('com.apple.Health'), 'Apple Health');
      expect(HealthSourceSanitizer.sanitize('com.apple.Fitness'), 'Apple Fitness');
      expect(HealthSourceSanitizer.sanitize('Apple Health'), 'Apple Health');
      expect(HealthSourceSanitizer.sanitize('Fitbit'), 'Fitbit');
      expect(HealthSourceSanitizer.sanitize('Apple Watch'), 'Apple Watch');
    });

    test('formats arbitrary reverse-DNS packages cleanly as fallback', () {
      expect(
        HealthSourceSanitizer.sanitize('com.somewearable.smartring'),
        'Smartring',
      );
      expect(
        HealthSourceSanitizer.sanitize('org.fitness.my_tracker'),
        'My Tracker',
      );
    });

    test('returns null for empty or whitespace-only inputs', () {
      expect(HealthSourceSanitizer.sanitize(null), isNull);
      expect(HealthSourceSanitizer.sanitize(''), isNull);
      expect(HealthSourceSanitizer.sanitize('   '), isNull);
    });
  });

  group('PV1-HEALTH-01: Sleep Window Clip-Then-Merge Interval Deduplication', () {
    final windowStart = DateTime(2026, 8, 8, 18, 0); // 18:00 yesterday
    final windowEnd = DateTime(2026, 8, 9, 14, 0); // 14:00 today

    test('returns empty for no intervals', () {
      final merged = HealthService.clipAndMergeIntervals(
        intervals: [],
        windowStart: windowStart,
        windowEnd: windowEnd,
      );
      expect(merged, isEmpty);
    });

    test('clips intervals straddling the start boundary', () {
      // 17:00 yesterday to 06:00 today (13h total, straddles 18:00 start)
      final raw = [
        (
          start: DateTime(2026, 8, 8, 17, 0),
          end: DateTime(2026, 8, 9, 6, 0),
        ),
      ];
      final merged = HealthService.clipAndMergeIntervals(
        intervals: raw,
        windowStart: windowStart,
        windowEnd: windowEnd,
      );
      expect(merged.length, 1);
      expect(merged.first.start, windowStart);
      expect(merged.first.end, DateTime(2026, 8, 9, 6, 0));
      expect(
        merged.first.end.difference(merged.first.start).inMinutes,
        12 * 60,
      ); // 18:00 to 06:00 = 12h
    });

    test('clips intervals straddling the end boundary', () {
      // 08:00 today to 16:00 today (straddles 14:00 end)
      final raw = [
        (
          start: DateTime(2026, 8, 9, 8, 0),
          end: DateTime(2026, 8, 9, 16, 0),
        ),
      ];
      final merged = HealthService.clipAndMergeIntervals(
        intervals: raw,
        windowStart: windowStart,
        windowEnd: windowEnd,
      );
      expect(merged.length, 1);
      expect(merged.first.start, DateTime(2026, 8, 9, 8, 0));
      expect(merged.first.end, windowEnd);
      expect(
        merged.first.end.difference(merged.first.start).inMinutes,
        6 * 60,
      ); // 08:00 to 14:00 = 6h
    });

    test('discards intervals entirely outside the civil window', () {
      // 12:00 to 16:00 yesterday (before 18:00)
      // 15:00 to 17:00 today (after 14:00)
      final raw = [
        (
          start: DateTime(2026, 8, 8, 12, 0),
          end: DateTime(2026, 8, 8, 16, 0),
        ),
        (
          start: DateTime(2026, 8, 9, 15, 0),
          end: DateTime(2026, 8, 9, 17, 0),
        ),
      ];
      final merged = HealthService.clipAndMergeIntervals(
        intervals: raw,
        windowStart: windowStart,
        windowEnd: windowEnd,
      );
      expect(merged, isEmpty);
    });

    test('merges overlapping sleep sessions without double-counting', () {
      // Session A: 22:00 to 06:00 (8h)
      // Session B: 23:00 to 07:00 (8h)
      // If summed naively: 16h. Correct merged span: 22:00 to 07:00 = 9h.
      final raw = [
        (
          start: DateTime(2026, 8, 8, 22, 0),
          end: DateTime(2026, 8, 9, 6, 0),
        ),
        (
          start: DateTime(2026, 8, 8, 23, 0),
          end: DateTime(2026, 8, 9, 7, 0),
        ),
      ];
      final merged = HealthService.clipAndMergeIntervals(
        intervals: raw,
        windowStart: windowStart,
        windowEnd: windowEnd,
      );
      expect(merged.length, 1);
      expect(merged.first.start, DateTime(2026, 8, 8, 22, 0));
      expect(merged.first.end, DateTime(2026, 8, 9, 7, 0));
      expect(
        merged.first.end.difference(merged.first.start).inMinutes,
        9 * 60,
      );
    });

    test('merges contiguous sleep sessions seamlessly', () {
      // Session 1: 23:00 to 03:00 (4h)
      // Session 2: 03:00 to 07:00 (4h)
      final raw = [
        (
          start: DateTime(2026, 8, 8, 23, 0),
          end: DateTime(2026, 8, 9, 3, 0),
        ),
        (
          start: DateTime(2026, 8, 9, 3, 0),
          end: DateTime(2026, 8, 9, 7, 0),
        ),
      ];
      final merged = HealthService.clipAndMergeIntervals(
        intervals: raw,
        windowStart: windowStart,
        windowEnd: windowEnd,
      );
      expect(merged.length, 1);
      expect(
        merged.first.end.difference(merged.first.start).inMinutes,
        8 * 60,
      );
    });

    test('preserves disjoint daytime naps alongside overnight sleep', () {
      // Overnight: 23:00 to 07:00 (8h)
      // Afternoon nap: 12:00 to 13:30 (1.5h)
      final raw = [
        (
          start: DateTime(2026, 8, 8, 23, 0),
          end: DateTime(2026, 8, 9, 7, 0),
        ),
        (
          start: DateTime(2026, 8, 9, 12, 0),
          end: DateTime(2026, 8, 9, 13, 30),
        ),
      ];
      final merged = HealthService.clipAndMergeIntervals(
        intervals: raw,
        windowStart: windowStart,
        windowEnd: windowEnd,
      );
      expect(merged.length, 2);
      final totalMinutes = merged.fold<int>(
        0,
        (sum, range) => sum + range.end.difference(range.start).inMinutes,
      );
      expect(totalMinutes, 8 * 60 + 90);
    });
  });

  group('PV1-HEALTH-01: Steps Provenance and 0-vs-Missing Truthfulness', () {
    test('explicit 0 steps is recorded as data, not missing', () {
      const summary = HealthDataSummary(
        steps: 0,
        stepsContext: HealthMetricContext<int>(
          value: 0,
          unit: 'count',
          sourceName: 'Apple Health (system total)',
          sourcePlatform: 'appleHealth',
        ),
        connectionStatus: HealthConnectionStatus.connected,
      );

      expect(summary.hasDataFor(HealthCategory.steps), isTrue);
      expect(summary.authoritativeSteps, 0);
      expect(summary.stepsContext?.sourceName, 'Apple Health (system total)');
    });

    test('unpermitted or absent steps is represented as missing (null context)', () {
      const summary = HealthDataSummary(
        steps: 0,
        stepsContext: null,
        connectionStatus: HealthConnectionStatus.connected,
      );

      expect(summary.hasDataFor(HealthCategory.steps), isFalse);
      expect(summary.stepsContext, isNull);
    });
  });

  group('PV1-HEALTH-01: Active Energy Deduplication, IndiFit Exclusion, Wearables', () {
    test('identifies wearable sources reliably', () {
      expect(HealthService.isWearableSource('Apple Watch', 'com.apple.health'), isTrue);
      expect(HealthService.isWearableSource('Garmin Forerunner', 'com.garmin'), isTrue);
      expect(HealthService.isWearableSource('Oura Ring', 'com.ouraring'), isTrue);
      expect(HealthService.isWearableSource('WHOOP 4.0', 'com.whoop'), isTrue);
      expect(HealthService.isWearableSource('Fitbit Charge', 'com.fitbit'), isTrue);
      expect(HealthService.isWearableSource('Galaxy Watch', 'com.sec.android.app.shealth'), isTrue);

      expect(HealthService.isWearableSource('iPhone', 'com.apple.Health'), isFalse);
      expect(HealthService.isWearableSource('Pixel 8', 'com.google.android.apps.fitness'), isFalse);
    });

    test('HealthService.fetchTodayHealthData filters IndiFit workouts and dedupes energy', () async {
      final fakeHealth = _FakeHealth();
      final morning = DateTime.utc(2026, 8, 9, 8, 0);
      final morningEnd = DateTime.utc(2026, 8, 9, 8, 45);

      fakeHealth.dataPointsResult = [
        // 1. Phone active energy sample
        _createDataPoint(
          type: HealthDataType.ACTIVE_ENERGY_BURNED,
          value: NumericHealthValue(numericValue: 150),
          from: morning,
          to: morningEnd,
          sourceName: 'iPhone',
          sourceId: 'com.apple.Health',
        ),
        // 2. Wearable active energy sample during same period (higher priority)
        _createDataPoint(
          type: HealthDataType.ACTIVE_ENERGY_BURNED,
          value: NumericHealthValue(numericValue: 220),
          from: morning,
          to: morningEnd,
          sourceName: 'Apple Watch',
          sourceId: 'com.apple.health.watch',
        ),
        // 3. IndiFit workout echo (MUST be excluded)
        _createDataPoint(
          type: HealthDataType.ACTIVE_ENERGY_BURNED,
          value: NumericHealthValue(numericValue: 300),
          from: morning,
          to: morningEnd,
          sourceName: 'IndiFit',
          sourceId: 'com.indifit.app',
        ),
      ];

      final service = HealthService(
        health: fakeHealth,
        dateService: LocalScheduleDateService(
          nowUtc: () => DateTime.utc(2026, 8, 9, 12, 0),
        ),
        timezoneService: LocalTimezoneService(
          read: () async => 'Asia/Kolkata',
        ),
        platformAvailabilityOverride: HealthPlatformAvailability.supported,
      );

      final summary = await service.fetchTodayHealthData();

      // The IndiFit point (300 kcal) MUST be dropped.
      // The Apple Watch point (220 kcal) takes priority over iPhone (150 kcal).
      expect(summary.hasDataFor(HealthCategory.activeEnergy), isTrue);
      expect(summary.authoritativeActiveEnergyKcal, 220.0);
      expect(summary.activeEnergyContext?.sourceName, 'Apple Watch');
      expect(
        HealthService.isWearableSource(
          summary.activeEnergyContext!.sourceName,
          summary.activeEnergyContext?.sourcePlatform,
        ),
        isTrue,
      );
    });
  });

  group('PV1-HEALTH-01: End-to-End Sleep Clip-Then-Merge via HealthService', () {
    test('queries 18:00 yesterday to 14:00 today and merges straddling sleep', () async {
      final fakeHealth = _FakeHealth();
      fakeHealth.totalStepsResult = 8200;

      // Overnight sleep session from 23:00 yesterday to 07:30 today (8.5h)
      // plus overlapping stage record from 00:00 to 02:00
      fakeHealth.dataPointsResult = [
        _createDataPoint(
          type: HealthDataType.SLEEP_SESSION,
          value: NumericHealthValue(numericValue: 510),
          from: DateTime.utc(2026, 8, 8, 17, 30), // 23:00 IST
          to: DateTime.utc(2026, 8, 9, 2, 0), // 07:30 IST
          sourceName: 'Oura Ring',
          sourceId: 'com.ouraring.oura',
        ),
        _createDataPoint(
          type: HealthDataType.SLEEP_DEEP,
          value: NumericHealthValue(numericValue: 120),
          from: DateTime.utc(2026, 8, 8, 18, 30), // 00:00 IST
          to: DateTime.utc(2026, 8, 8, 20, 30), // 02:00 IST
          sourceName: 'Oura Ring',
          sourceId: 'com.ouraring.oura',
        ),
      ];

      final service = HealthService(
        health: fakeHealth,
        dateService: LocalScheduleDateService(
          nowUtc: () => DateTime.utc(2026, 8, 9, 12, 0),
        ),
        timezoneService: LocalTimezoneService(
          read: () async => 'Asia/Kolkata',
        ),
        platformAvailabilityOverride: HealthPlatformAvailability.supported,
      );

      final summary = await service.fetchTodayHealthData();

      expect(summary.hasDataFor(HealthCategory.sleep), isTrue);
      // Overlap merged: exactly 8.5h (510 minutes), NOT 8.5 + 2 = 10.5h
      expect(summary.authoritativeSleepHours, closeTo(8.5, 0.05));
      expect(summary.sleepContext?.sourceName, 'Oura');
      expect(
        HealthService.isWearableSource(
          summary.sleepContext!.sourceName,
          summary.sleepContext?.sourcePlatform,
        ),
        isTrue,
      );
      expect(summary.authoritativeSteps, 8200);
      expect(summary.stepsContext?.sourceName, 'Apple Health (system total)');
      expect(summary.primarySource, 'Oura');
    });
  });

  group('PV1-HEALTH-01: Strict Non-Invention and Frozen B04 Seam', () {
    test('B04 readRecoveryMetrics signature and behavior remains frozen and read-only', () async {
      final service = HealthService(
        health: _FakeHealth(),
        dateService: LocalScheduleDateService(
          nowUtc: () => DateTime.utc(2026, 8, 9, 12, 0),
        ),
        timezoneService: LocalTimezoneService(
          read: () async => 'Asia/Kolkata',
        ),
      );

      final metrics = await service.readRecoveryMetrics(
        startUtc: DateTime.utc(2026, 8, 8, 12, 0),
        endUtc: DateTime.utc(2026, 8, 9, 12, 0),
      );
      expect(metrics, isA<List<HealthRecoveryMetricRead>>());
    });

    test('HealthDataSummary never contains readiness scores or synthetic calorie formulas', () {
      const summary = HealthDataSummary(
        steps: 10000,
        activeCalories: 500,
        sleepHours: 8,
      );

      expect(summary.authoritativeSteps, 10000);
      expect(summary.authoritativeActiveEnergyKcal, 500.0);
      expect(summary.authoritativeSleepHours, 8.0);
    });
  });

  group('PV1-HEALTH-01: Consumer Presentation Surface Formatting', () {
    test('formats combined daily movement facts truthfully', () {
      const summary = HealthDataSummary(
        steps: 8432,
        activeCalories: 380,
        sleepHours: 7.4,
        stepsContext: HealthMetricContext<int>(
          value: 8432,
          unit: 'count',
          sourceName: 'Apple Health (system total)',
          sourcePlatform: 'appleHealth',
        ),
        activeEnergyContext: HealthMetricContext<double>(
          value: 380.0,
          unit: 'kcal',
          sourceName: 'Apple Watch',
          sourcePlatform: 'appleHealth',
        ),
        sleepContext: HealthMetricContext<double>(
          value: 7.4,
          unit: 'hours',
          sourceName: 'Apple Watch',
          sourcePlatform: 'appleHealth',
        ),
        primarySource: 'Apple Watch',
      );

      final read = const TodayDomainRead<B02ProgressReadModel>.available(
        B02ProgressReadModel(
          query: B02ProgressQuery(
            startLocalDate: '2026-08-03',
            endLocalDate: '2026-08-09',
            timezoneId: 'Asia/Kolkata',
          ),
          activityHistory: [],
          groupHistory: null,
          targetEvidence: null,
          muscleVolume: null,
        ),
      );

      final presentation = TodayActivityPresentation.from(
        read,
        loading: false,
        healthSummary: summary,
      );

      expect(presentation.shouldRender, isTrue);
      expect(presentation.headline, 'Daily activity');
      expect(
        presentation.dailyMovementSummary,
        '8,432 steps · 380 kcal · 7.4h sleep',
      );
      expect(presentation.primarySource, 'Apple Watch');
    });

    test('formats partial movement facts honestly when only steps are available', () {
      const summary = HealthDataSummary(
        steps: 5200,
        stepsContext: HealthMetricContext<int>(
          value: 5200,
          unit: 'count',
          sourceName: 'Health Connect (system total)',
          sourcePlatform: 'googleHealthConnect',
        ),
        primarySource: 'Health Connect (system total)',
      );

      final presentation = TodayActivityPresentation.from(
        null,
        loading: false,
        healthSummary: summary,
      );

      expect(presentation.shouldRender, isTrue);
      expect(presentation.dailyMovementSummary, '5,200 steps');
      expect(presentation.primarySource, 'Health Connect (system total)');
    });

    testWidgets('TodayActivityModule renders movement facts without overflow at narrow width', (
      tester,
    ) async {
      const presentation = TodayActivityPresentation(
        state: TodayPresentationState.ready,
        headline: 'Daily activity',
        detail: '8,432 steps · 380 kcal · 7.4h sleep',
        dailyMovementSummary: '8,432 steps · 380 kcal · 7.4h sleep',
        primarySource: 'Apple Watch',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: TodayActivityModule(
                presentation: presentation,
                onRetry: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Daily activity'), findsOneWidget);
      expect(find.text('8,432 steps · 380 kcal · 7.4h sleep'), findsOneWidget);
      expect(find.text('Source: Apple Watch'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
