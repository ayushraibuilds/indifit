import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/ai/ai_remote_config_refresher.dart';

/// Stands in for FirebaseRemoteConfig: a fetched value only takes effect
/// once activated, like the real SDK.
class _FakeRemoteConfig {
  _FakeRemoteConfig(this.now);

  final DateTime Function() now;
  final updates = StreamController<Object?>.broadcast();

  bool serverEnabled = true;
  bool activeEnabled = true;
  DateTime lastFetchTime = DateTime.fromMillisecondsSinceEpoch(0);
  int fetches = 0;
  int activations = 0;
  Duration fetchDelay = Duration.zero;
  bool failFetch = false;

  Future<bool> fetchAndActivate() async {
    fetches++;
    await Future<void>.delayed(fetchDelay);
    if (failFetch) throw StateError('network down');
    lastFetchTime = now();
    activeEnabled = serverEnabled;
    return true;
  }

  Future<bool> activate() async {
    activations++;
    activeEnabled = serverEnabled;
    return true;
  }

  /// The console change, pushed to the device as a real-time update.
  void publish({required bool enabled}) {
    serverEnabled = enabled;
    updates.add(Object());
  }
}

void main() {
  late DateTime clock;
  late _FakeRemoteConfig config;
  late AiRemoteConfigRefresher refresher;

  void setUpRefresher() {
    clock = DateTime(2026, 10, 4, 12);
    config = _FakeRemoteConfig(() => clock);
    refresher = AiRemoteConfigRefresher(
      fetchAndActivate: config.fetchAndActivate,
      activate: config.activate,
      updates: config.updates.stream,
      lastFetchTime: () => config.lastFetchTime,
      now: () => clock,
    );
  }

  test('the first AI call waits for the current kill switch', () {
    fakeAsync((async) {
      setUpRefresher();
      config
        ..serverEnabled = false
        ..fetchDelay = const Duration(seconds: 1);

      var started = false;
      refresher.start().then((_) => started = true);
      async.elapse(const Duration(milliseconds: 999));
      expect(started, isFalse, reason: 'must wait for the fetch');
      async.elapse(const Duration(milliseconds: 1));

      expect(started, isTrue);
      expect(config.activeEnabled, isFalse);
    });
  });

  test('a slow first fetch stops blocking after fetchWait', () {
    fakeAsync((async) {
      setUpRefresher();
      config
        ..serverEnabled = false
        ..fetchDelay = const Duration(seconds: 10);

      var started = false;
      refresher.start().then((_) => started = true);
      async.elapse(const Duration(seconds: 3));
      expect(started, isTrue);
      expect(config.activeEnabled, isTrue, reason: 'still on old values');

      // The fetch carries on and lands for the next call.
      async.elapse(const Duration(seconds: 7));
      expect(config.activeEnabled, isFalse);
    });
  });

  test('a failed fetch never blocks AI', () {
    fakeAsync((async) {
      setUpRefresher();
      config.failFetch = true;

      var started = false;
      refresher.start().then((_) => started = true);
      async.elapse(Duration.zero);
      expect(started, isTrue);
      expect(config.activeEnabled, isTrue);
    });
  });

  test('a real-time update switches AI off in an app that stays open', () {
    fakeAsync((async) {
      setUpRefresher();
      refresher.start();
      async.elapse(Duration.zero);
      expect(config.activeEnabled, isTrue);

      config.publish(enabled: false);
      async.elapse(Duration.zero);

      expect(config.activations, 1);
      expect(config.activeEnabled, isFalse);
    });
  });

  test('stale values are fetched again before a call', () {
    fakeAsync((async) {
      setUpRefresher();
      refresher.start();
      async.elapse(Duration.zero);
      expect(config.fetches, 1);

      // Real-time updates didn't get through; the console flipped the switch.
      config.serverEnabled = false;
      clock = clock.add(const Duration(minutes: 10));
      refresher.ensureFresh();
      async.elapse(Duration.zero);
      expect(config.fetches, 1, reason: 'still fresh');

      clock = clock.add(const Duration(minutes: 6));
      refresher.ensureFresh();
      async.elapse(Duration.zero);
      expect(config.fetches, 2);
      expect(config.activeEnabled, isFalse);
    });
  });

  test('a failing fetch is retried once per maxAge, not on every call', () {
    fakeAsync((async) {
      setUpRefresher();
      config.failFetch = true;
      refresher.start();
      async.elapse(Duration.zero);

      for (var i = 0; i < 5; i++) {
        refresher.ensureFresh();
        async.elapse(Duration.zero);
      }
      expect(config.fetches, 1);

      clock = clock.add(const Duration(minutes: 16));
      refresher.ensureFresh();
      async.elapse(Duration.zero);
      expect(config.fetches, 2);
    });
  });

  test('concurrent calls share one fetch', () {
    fakeAsync((async) {
      setUpRefresher();
      config.fetchDelay = const Duration(seconds: 1);
      refresher.start();
      refresher.ensureFresh();
      refresher.ensureFresh();
      async.elapse(const Duration(seconds: 1));
      expect(config.fetches, 1);
    });
  });
}
