import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/ios_live_activity_service.dart';

class MockIosLiveActivityDriver implements IosLiveActivityDriver {
  bool areActivitiesEnabledResult = true;
  final List<Map<String, dynamic>> startCalls = [];
  final List<Map<String, dynamic>> updateCalls = [];
  final List<Map<String, dynamic>> endCalls = [];

  bool throwPlatformException = false;
  bool throwMissingPluginException = false;

  void _maybeThrow() {
    if (throwPlatformException) {
      throw PlatformException(code: 'ERROR', message: 'Simulated platform error');
    }
    if (throwMissingPluginException) {
      throw MissingPluginException();
    }
  }

  @override
  Future<bool> areActivitiesEnabled() async {
    _maybeThrow();
    return areActivitiesEnabledResult;
  }

  @override
  Future<bool> startLiveActivity({
    required String periodId,
    required String exerciseName,
    required int targetSeconds,
    required int expiryEpochMs,
  }) async {
    _maybeThrow();
    startCalls.add({
      'periodId': periodId,
      'exerciseName': exerciseName,
      'targetSeconds': targetSeconds,
      'expiryEpochMs': expiryEpochMs,
    });
    return true;
  }

  @override
  Future<bool> updateLiveActivity({
    required String periodId,
    required String exerciseName,
    required int targetSeconds,
    required int expiryEpochMs,
    required bool isCompleted,
  }) async {
    _maybeThrow();
    updateCalls.add({
      'periodId': periodId,
      'exerciseName': exerciseName,
      'targetSeconds': targetSeconds,
      'expiryEpochMs': expiryEpochMs,
      'isCompleted': isCompleted,
    });
    return true;
  }

  @override
  Future<bool> endLiveActivity({
    String? periodId,
    required bool immediate,
  }) async {
    _maybeThrow();
    endCalls.add({
      'periodId': periodId,
      'immediate': immediate,
    });
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IosLiveActivityService platform checks & availability', () {
    late MockIosLiveActivityDriver mockDriver;

    setUp(() {
      mockDriver = MockIosLiveActivityDriver();
    });

    test('isAvailable returns false on non-iOS platforms without invoking driver', () async {
      final service = IosLiveActivityService(
        driver: mockDriver,
        isIosChecker: () => false,
      );

      final available = await service.isAvailable();
      expect(available, false);
    });

    test('isAvailable delegates to driver on iOS when supported', () async {
      final service = IosLiveActivityService(
        driver: mockDriver,
        isIosChecker: () => true,
      );

      mockDriver.areActivitiesEnabledResult = true;
      expect(await service.isAvailable(), true);

      mockDriver.areActivitiesEnabledResult = false;
      expect(await service.isAvailable(), false);
    });

    test('isAvailable catches PlatformException safely and returns false', () async {
      final service = IosLiveActivityService(
        driver: mockDriver,
        isIosChecker: () => true,
      );

      mockDriver.throwPlatformException = true;
      expect(await service.isAvailable(), false);
    });

    test('isAvailable catches MissingPluginException safely and returns false', () async {
      final service = IosLiveActivityService(
        driver: mockDriver,
        isIosChecker: () => true,
      );

      mockDriver.throwMissingPluginException = true;
      expect(await service.isAvailable(), false);
    });
  });

  group('IosLiveActivityService method payloads & platform safety', () {
    late MockIosLiveActivityDriver mockDriver;
    late IosLiveActivityService service;
    final expiry = DateTime.utc(2026, 9, 15, 12, 0, 0);

    setUp(() {
      mockDriver = MockIosLiveActivityDriver();
      service = IosLiveActivityService(
        driver: mockDriver,
        isIosChecker: () => true,
      );
    });

    test('startRestLiveActivity packages payload accurately', () async {
      final result = await service.startRestLiveActivity(
        periodId: 'rest-1',
        exerciseName: 'Incline Dumbbell Press',
        targetSeconds: 90,
        expiryUtc: expiry,
      );

      expect(result, true);
      expect(mockDriver.startCalls, hasLength(1));
      final call = mockDriver.startCalls.first;
      expect(call['periodId'], 'rest-1');
      expect(call['exerciseName'], 'Incline Dumbbell Press');
      expect(call['targetSeconds'], 90);
      expect(call['expiryEpochMs'], expiry.millisecondsSinceEpoch);
    });

    test('updateRestLiveActivity packages payload accurately with completion flag', () async {
      final result = await service.updateRestLiveActivity(
        periodId: 'rest-1',
        exerciseName: 'Incline Dumbbell Press',
        targetSeconds: 120,
        expiryUtc: expiry.add(const Duration(seconds: 30)),
        isCompleted: false,
      );

      expect(result, true);
      expect(mockDriver.updateCalls, hasLength(1));
      final call = mockDriver.updateCalls.first;
      expect(call['periodId'], 'rest-1');
      expect(call['exerciseName'], 'Incline Dumbbell Press');
      expect(call['targetSeconds'], 120);
      expect(call['expiryEpochMs'], expiry.add(const Duration(seconds: 30)).millisecondsSinceEpoch);
      expect(call['isCompleted'], false);
    });

    test('endRestLiveActivity passes periodId and immediate flag', () async {
      final normalEnd = await service.endRestLiveActivity(
        periodId: 'rest-1',
        immediate: false,
      );
      expect(normalEnd, true);
      expect(mockDriver.endCalls, hasLength(1));
      expect(mockDriver.endCalls.first['periodId'], 'rest-1');
      expect(mockDriver.endCalls.first['immediate'], false);

      final immediateEnd = await service.endRestLiveActivity(
        periodId: 'rest-1',
        immediate: true,
      );
      expect(immediateEnd, true);
      expect(mockDriver.endCalls, hasLength(2));
      expect(mockDriver.endCalls.last['periodId'], 'rest-1');
      expect(mockDriver.endCalls.last['immediate'], true);
    });

    test('non-iOS platforms no-op safely without invoking driver', () async {
      final nonIosService = IosLiveActivityService(
        driver: mockDriver,
        isIosChecker: () => false,
      );

      final start = await nonIosService.startRestLiveActivity(
        periodId: 'rest-2',
        exerciseName: 'Squat',
        targetSeconds: 60,
        expiryUtc: expiry,
      );
      expect(start, false);
      expect(mockDriver.startCalls, isEmpty);

      final update = await nonIosService.updateRestLiveActivity(
        periodId: 'rest-2',
        exerciseName: 'Squat',
        targetSeconds: 90,
        expiryUtc: expiry,
      );
      expect(update, false);
      expect(mockDriver.updateCalls, isEmpty);

      final end = await nonIosService.endRestLiveActivity(
        periodId: 'rest-2',
        immediate: true,
      );
      expect(end, false);
      expect(mockDriver.endCalls, isEmpty);
    });

    test('driver exceptions do not bubble up or crash execution', () async {
      mockDriver.throwPlatformException = true;

      final start = await service.startRestLiveActivity(
        periodId: 'p1',
        exerciseName: 'Deadlift',
        targetSeconds: 60,
        expiryUtc: expiry,
      );
      expect(start, false);

      final update = await service.updateRestLiveActivity(
        periodId: 'p1',
        exerciseName: 'Deadlift',
        targetSeconds: 90,
        expiryUtc: expiry,
      );
      expect(update, false);

      final end = await service.endRestLiveActivity(
        periodId: 'p1',
        immediate: true,
      );
      expect(end, false);
    });
  });
}
