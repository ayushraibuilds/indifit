import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/indifit_haptics.dart';
import 'package:indifit/core/services/rest_presence_service.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/features/workout_player/widgets/b02_player_cards.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TP-7: one `restEnd()` haptic per rest that runs out in the app, after the
/// rest's end is saved, and none for Skip.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final haptics = <IndiFitHapticType>[];

  setUp(() {
    haptics.clear();
    IndiFitHaptics.debugHandler = haptics.add;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => IndiFitHaptics.debugHandler = null);

  test('restEnd() is its own haptic type', () async {
    await IndiFitHaptics.restEnd();

    expect(haptics, [IndiFitHapticType.restEnd]);
  });

  test(
    'the production rest driver fires restEnd(), not confirmation()',
    () async {
      await LocalNotificationRestPresenceDriver().triggerHapticFeedback();

      expect(haptics, [IndiFitHapticType.restEnd]);
    },
  );

  group('RestPresenceService', () {
    late _CountingDriver driver;
    late DateTime now;
    late RestPresenceService service;

    setUp(() {
      driver = _CountingDriver();
      now = DateTime.utc(2026, 10, 7, 10);
      service = RestPresenceService(driver: driver, nowUtc: () => now);
    });

    /// Starts a 3 s rest and lets its own 1 s ticker run past the end.
    void runOutOnOwnClock(FakeAsync async) {
      service.startRest(
        periodId: 'rest-1',
        exerciseName: 'Leg press',
        targetSeconds: 3,
        startedAtUtc: now,
      );
      async.flushMicrotasks();
      for (var i = 0; i < 4; i++) {
        now = now.add(const Duration(seconds: 1));
        async.elapse(const Duration(seconds: 1));
      }
      expect(service.state, RestPresenceState.expired);
    }

    test('with a live workout, the haptic waits for the saved end, once', () {
      fakeAsync((async) {
        service.registerActionDelegate(
          onAdjust: (_, _) {},
          onSkip: (_) {},
          owner: Object(),
        );
        runOutOnOwnClock(async);
        expect(driver.hapticCalls, 0, reason: 'not before persistence');

        // The controller saved the end of the rest.
        service.onRestElapsed(periodId: 'rest-1');
        async.flushMicrotasks();
        expect(driver.hapticCalls, 1);

        service.onRestElapsed(periodId: 'rest-1');
        async.flushMicrotasks();
        expect(driver.hapticCalls, 1, reason: 'one haptic per rest');
      });
    });

    test('Skip after the countdown ran out gives no haptic', () {
      fakeAsync((async) {
        service.registerActionDelegate(
          onAdjust: (_, _) {},
          onSkip: (_) {},
          owner: Object(),
        );
        runOutOnOwnClock(async);

        service.cancelRest(periodId: 'rest-1');
        async.flushMicrotasks();
        service.onRestElapsed(periodId: 'rest-1');
        async.flushMicrotasks();

        expect(driver.hapticCalls, 0);
      });
    });

    test('Skip before the end gives no haptic', () {
      fakeAsync((async) {
        service.startRest(
          periodId: 'rest-1',
          exerciseName: 'Leg press',
          targetSeconds: 30,
          startedAtUtc: now,
        );
        async.flushMicrotasks();
        service.cancelRest(periodId: 'rest-1');
        async.flushMicrotasks();
        now = now.add(const Duration(seconds: 40));
        async.elapse(const Duration(seconds: 40));

        expect(driver.hapticCalls, 0);
      });
    });

    test('with no live workout, the service fires it when the rest ends', () {
      fakeAsync((async) {
        runOutOnOwnClock(async);

        expect(driver.hapticCalls, 1);
      });
    });

    test('the controller ending the rest first fires it once', () {
      fakeAsync((async) {
        service.registerActionDelegate(
          onAdjust: (_, _) {},
          onSkip: (_) {},
          owner: Object(),
        );
        service.startRest(
          periodId: 'rest-1',
          exerciseName: 'Leg press',
          targetSeconds: 3,
          startedAtUtc: now,
        );
        async.flushMicrotasks();
        now = now.add(const Duration(seconds: 3));
        service.onRestElapsed(periodId: 'rest-1');
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));

        expect(driver.hapticCalls, 1);
      });
    });
  });

  testWidgets('the sticky rest bar adds no haptic of its own at zero', (
    tester,
  ) async {
    var elapsedCalls = 0;
    final period = B02RestPeriod(
      id: 'rest-1',
      performedSetId: 'set-1',
      scope: B02RestScope.exerciseSet,
      source: B02RestSource.automatic,
      startedAtUtc: DateTime.now().toUtc().subtract(
        const Duration(seconds: 61),
      ),
      recommendedSeconds: 60,
      selectedSeconds: 60,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StickyRestBar(
            state: _state([period]),
            onDecrease: null,
            onExtend: null,
            onSkip: null,
            onElapsed: (_) async {
              elapsedCalls++;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(elapsedCalls, 1);
    // RestPresenceService fires restEnd() after the controller's save; the
    // bar used to add a second (confirmation) haptic here.
    expect(haptics, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

B02ExecutionDraftState _state(List<B02RestPeriod> rests) =>
    B02ExecutionDraftState(
      snapshotId: 'rest-end-snapshot',
      snapshotVersion: 1,
      activityType: B02ActivityType.strength,
      routineName: 'Legs',
      elapsedSeconds: 0,
      currentExerciseOrdinal: 0,
      currentSetOrdinal: 0,
      performedExercises: const [],
      restPeriods: rests,
    );

class _CountingDriver implements RestPresenceDriver {
  int hapticCalls = 0;

  @override
  Future<bool> scheduleExactExpiryAlarm({
    required int id,
    required DateTime expiryUtc,
    required String exerciseName,
    required String channelId,
    required String channelName,
  }) async => false;

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
  }) async {}

  @override
  Future<void> cancelNotification(int id) async {}

  @override
  Future<void> triggerHapticFeedback() async => hapticCalls++;
}
