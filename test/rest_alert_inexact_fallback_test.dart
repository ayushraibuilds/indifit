import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/rest_presence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PR-D: the rest-done alert when Android exact alarms are off (audit R-03).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R-03 rest alert without exact alarms', () {
    late List<MethodCall> calls;
    late bool canExact;

    setUp(() {
      calls = [];
      canExact = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async {
              calls.add(call);
              if (call.method == 'canScheduleExactNotifications') {
                return canExact;
              }
              return null;
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            null,
          );
    });

    Future<bool> schedule() =>
        LocalNotificationRestPresenceDriver().scheduleExactExpiryAlarm(
          id: RestPresenceService.expiredNotificationId,
          expiryUtc: DateTime.now().toUtc().add(const Duration(seconds: 90)),
          exerciseName: 'Bench press',
          channelId: RestPresenceService.channelId,
          channelName: RestPresenceService.channelName,
        );

    String? scheduleMode() {
      final scheduled = calls.where((call) => call.method == 'zonedSchedule');
      if (scheduled.isEmpty) return null;
      final arguments = scheduled.single.arguments as Map;
      final platform = arguments['platformSpecifics'] as Map;
      return platform['scheduleMode'] as String?;
    }

    test('schedules an inexact alert when exact alarms are off', () async {
      final exact = await schedule();

      expect(scheduleMode(), 'inexactAllowWhileIdle');
      // Not an on-time anchor, so the app still posts the alert itself.
      expect(exact, isFalse);
    });

    test('keeps the exact alarm when it is allowed', () async {
      canExact = true;
      final exact = await schedule();

      expect(scheduleMode(), 'exactAllowWhileIdle');
      expect(exact, isTrue);
    });

    test('the app-posted alert drops the pending inexact one first', () async {
      SharedPreferences.setMockInitialValues({});
      final driver = _RecordingDriver();
      var now = DateTime.utc(2026, 10, 7, 10);
      final service = RestPresenceService(driver: driver, nowUtc: () => now);
      await service.startRest(
        periodId: 'p1',
        exerciseName: 'Bench press',
        targetSeconds: 60,
        startedAtUtc: now,
      );
      now = now.add(const Duration(seconds: 61));
      await service.onRestElapsed(periodId: 'p1');

      final cancelAt = driver.events.lastIndexOf(
        'cancel:${RestPresenceService.expiredNotificationId}',
      );
      final postAt = driver.events.indexOf('expired');
      expect(cancelAt, isNonNegative);
      expect(cancelAt, lessThan(postAt));
      await service.cleanup();
    });
  });
}

class _RecordingDriver implements RestPresenceDriver {
  final events = <String>[];

  @override
  Future<bool> scheduleExactExpiryAlarm({
    required int id,
    required DateTime expiryUtc,
    required String exerciseName,
    required String channelId,
    required String channelName,
  }) async {
    events.add('schedule');
    return false;
  }

  @override
  Future<void> showOngoingRestNotification({
    required int id,
    required String exerciseName,
    required int remainingSeconds,
    required int totalSeconds,
    required String channelId,
    required String channelName,
    DateTime? expiryUtc,
  }) async {}

  @override
  Future<void> showRestExpiredNotification({
    required int id,
    required String exerciseName,
    required String channelId,
    required String channelName,
  }) async => events.add('expired');

  @override
  Future<void> cancelNotification(int id) async => events.add('cancel:$id');

  @override
  Future<void> triggerHapticFeedback() async {}
}
