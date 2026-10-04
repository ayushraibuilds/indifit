import 'dart:async';

import '../utils/app_logger.dart';

/// Keeps the Remote Config values that steer AI (the `ai_enabled` kill
/// switch, model and caps) current, so switching AI off reaches apps that
/// are already running.
///
/// Values used to be fetched once per process without waiting, so a new
/// launch made its first call on the previous values and an app left open
/// never saw a change. Now:
/// - the first AI call waits briefly for a fetch;
/// - real-time updates are activated as soon as they arrive;
/// - any call after [maxAge] waits briefly for a fresh fetch, in case
///   real-time updates can't get through.
///
/// A fetch that is slow or fails never blocks AI: the call goes ahead on the
/// last activated values (or the defaults).
class AiRemoteConfigRefresher {
  AiRemoteConfigRefresher({
    required Future<bool> Function() fetchAndActivate,
    required Future<bool> Function() activate,
    required Stream<Object?> updates,
    required DateTime Function() lastFetchTime,
    DateTime Function()? now,
    this.fetchWait = const Duration(seconds: 3),
    this.maxAge = const Duration(minutes: 15),
  }) : _fetchAndActivate = fetchAndActivate,
       _activate = activate,
       _updates = updates,
       _lastFetchTime = lastFetchTime,
       _now = now ?? DateTime.now;

  final Future<bool> Function() _fetchAndActivate;
  final Future<bool> Function() _activate;
  final Stream<Object?> _updates;
  final DateTime Function() _lastFetchTime;
  final DateTime Function() _now;

  /// How long an AI call waits for a fetch before using the values it has.
  final Duration fetchWait;

  /// How old fetched values may get before a call fetches again. Remote
  /// Config's `minimumFetchInterval` must not be longer, or the fetch is
  /// served from cache.
  final Duration maxAge;

  StreamSubscription<Object?>? _subscription;
  Future<void>? _inFlight;
  DateTime? _lastAttempt;

  /// Listens for real-time updates and waits briefly for a first fetch.
  Future<void> start() async {
    _subscription ??= _updates.listen(
      (_) => unawaited(_activateUpdate()),
      onError: (Object error) {
        // The SDK reconnects on its own; ensureFresh covers the gap.
        AppLogger.warning('Remote Config real-time updates failed: $error');
      },
    );
    await _fetch();
  }

  /// Fetches again when neither the last successful fetch nor the last
  /// attempt is within [maxAge]. Counting attempts means a slow or failing
  /// fetch costs one wait per [maxAge], not one per call.
  Future<void> ensureFresh() async {
    final lastFetch = _lastFetchTime();
    final attempt = _lastAttempt;
    final latest = attempt != null && attempt.isAfter(lastFetch)
        ? attempt
        : lastFetch;
    if (_now().difference(latest) <= maxAge) return;
    await _fetch();
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _activateUpdate() async {
    try {
      await _activate();
    } on Object catch (error) {
      AppLogger.error('Remote Config activate failed', error);
    }
  }

  /// One fetch at a time; callers share it and stop waiting after
  /// [fetchWait] while the fetch carries on and activates when it lands.
  Future<void> _fetch() {
    if (_inFlight == null) _lastAttempt = _now();
    final fetch = _inFlight ??= _fetchAndActivate()
        .then<void>((_) {})
        .catchError((Object error) {
          AppLogger.error('Remote Config fetch failed', error);
        })
        .whenComplete(() => _inFlight = null);
    return fetch.timeout(fetchWait, onTimeout: () {});
  }
}
