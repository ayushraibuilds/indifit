import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../utils/app_logger.dart';

/// The narrow platform boundary used by the active-workout wake-lock owner.
///
/// Keeping the plugin behind this interface makes the lifecycle policy
/// deterministic to test and keeps plugin availability out of workout
/// persistence and completion decisions.
abstract interface class WorkoutWakeLockDriver {
  Future<void> enable();

  Future<void> disable();
}

class WakelockPlusWorkoutWakeLockDriver implements WorkoutWakeLockDriver {
  const WakelockPlusWorkoutWakeLockDriver();

  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}

/// Owns the desired screen-awake state for the single active workout session.
///
/// Rest, widgets, and routes only reconcile the active-session intent through
/// this coordinator. Leaving a player route therefore cannot release the
/// lock while its canonical draft is still active. Plugin failures are
/// diagnostics and are deliberately swallowed so they cannot affect workout
/// writes or completion.
class WorkoutSessionWakeLockCoordinator with WidgetsBindingObserver {
  final WorkoutWakeLockDriver _driver;
  Future<void> _operationTail = Future<void>.value();
  String? _activeSessionKey;
  bool _desiredEnabled = false;
  bool? _appliedEnabled;
  bool _observingLifecycle = false;
  bool _disposed = false;

  WorkoutSessionWakeLockCoordinator({WorkoutWakeLockDriver? driver})
    : _driver = driver ?? const WakelockPlusWorkoutWakeLockDriver();

  String? get activeSessionKey => _activeSessionKey;

  bool get desiredEnabled => _desiredEnabled;

  /// Uses the app lifecycle only as a reconciliation signal. Going to the
  /// background does not release the lock because session ownership remains
  /// canonical while the workout is active.
  void attachToAppLifecycle() {
    if (_disposed || _observingLifecycle) return;
    WidgetsBinding.instance.addObserver(this);
    _observingLifecycle = true;
  }

  Future<void> setActiveSession(String sessionKey) {
    final normalized = sessionKey.trim();
    if (normalized.isEmpty || _disposed) return Future<void>.value();
    _activeSessionKey = normalized;
    _desiredEnabled = true;
    return _enqueueReconciliation();
  }

  /// Reconciles a route/controller binding without creating a second owner.
  /// Callers without an active session must use [ensureOff] only after a
  /// canonical no-session or terminal decision, never from route disposal.
  Future<void> reconcileForActiveSession(String sessionKey) {
    final normalized = sessionKey.trim();
    if (normalized.isEmpty) return Future<void>.value();
    return setActiveSession(normalized);
  }

  /// Clears only the session that requested the lock. A stale route cannot
  /// turn off a newer active session after it has been rebound.
  Future<void> clearActiveSession(String sessionKey) {
    final normalized = sessionKey.trim();
    if (_disposed ||
        normalized.isEmpty ||
        _activeSessionKey == null ||
        _activeSessionKey != normalized) {
      return Future<void>.value();
    }
    _activeSessionKey = null;
    _desiredEnabled = false;
    return _enqueueReconciliation();
  }

  Future<void> ensureOff() {
    if (_disposed) return Future<void>.value();
    _activeSessionKey = null;
    _desiredEnabled = false;
    return _enqueueReconciliation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_disposed) {
      // The platform may have reset its flag while the app was backgrounded;
      // foreground is an explicit ensure signal, not merely a rebuild.
      _appliedEnabled = null;
      unawaited(_enqueueReconciliation());
    }
  }

  Future<void> _enqueueReconciliation() {
    final operation = _operationTail.then<void>((_) => _reconcile());
    // A failed plugin operation is handled inside _reconcile. Keep the tail
    // healthy even if an unexpected driver implementation throws outside the
    // guarded call so later lifecycle signals can still retry.
    _operationTail = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return operation;
  }

  Future<void> _reconcile() async {
    if (_disposed) return;
    final desired = _desiredEnabled;
    if (_appliedEnabled == desired) return;

    try {
      if (desired) {
        await _driver.enable();
      } else {
        await _driver.disable();
      }
      _appliedEnabled = desired;
    } catch (error, stackTrace) {
      // Leave the applied state unknown so a later resume/rebind retries the
      // best-effort platform operation. The workout remains authoritative.
      _appliedEnabled = null;
      AppLogger.warning(
        'Screen-awake preference could not be reconciled: ${error.runtimeType}',
        'WorkoutWakeLock',
      );
      AppLogger.error(
        'Screen-awake platform operation failed',
        error,
        stackTrace,
        'WorkoutWakeLock',
      );
    }
  }

  void dispose() {
    if (_disposed) return;
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
    _disposed = true;
  }
}

String b02WorkoutSessionWakeLockKey(int draftId) => 'b02-draft:$draftId';

String legacyWorkoutSessionWakeLockKey(String? scheduledOccurrenceId) =>
    scheduledOccurrenceId == null
    ? 'legacy-active-draft'
    : 'legacy-occurrence:$scheduledOccurrenceId';
