import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/app_logger.dart';

/// Abstract driver interface for iOS Live Activities, allowing mock injection
/// in tests and cross-platform safety.
abstract interface class IosLiveActivityDriver {
  Future<bool> areActivitiesEnabled();

  Future<bool> startLiveActivity({
    required String periodId,
    required String exerciseName,
    required int targetSeconds,
    required int expiryEpochMs,
  });

  Future<bool> updateLiveActivity({
    required String periodId,
    required String exerciseName,
    required int targetSeconds,
    required int expiryEpochMs,
    required bool isCompleted,
  });

  Future<bool> endLiveActivity({
    String? periodId,
    required bool immediate,
  });
}

/// Production driver communicating over MethodChannel with native Swift
/// ActivityKit lifecycle manager in Runner.
class MethodChannelIosLiveActivityDriver implements IosLiveActivityDriver {
  static const MethodChannel _channel = MethodChannel(
    'com.indifit.indifit/rest_live_activity',
  );

  const MethodChannelIosLiveActivityDriver();

  @override
  Future<bool> areActivitiesEnabled() async {
    final result = await _channel.invokeMethod<bool>('areActivitiesEnabled');
    return result ?? false;
  }

  @override
  Future<bool> startLiveActivity({
    required String periodId,
    required String exerciseName,
    required int targetSeconds,
    required int expiryEpochMs,
  }) async {
    final result = await _channel.invokeMethod<bool>('startLiveActivity', {
      'periodId': periodId,
      'exerciseName': exerciseName,
      'targetSeconds': targetSeconds,
      'expiryEpochMs': expiryEpochMs,
    });
    return result ?? false;
  }

  @override
  Future<bool> updateLiveActivity({
    required String periodId,
    required String exerciseName,
    required int targetSeconds,
    required int expiryEpochMs,
    required bool isCompleted,
  }) async {
    final result = await _channel.invokeMethod<bool>('updateLiveActivity', {
      'periodId': periodId,
      'exerciseName': exerciseName,
      'targetSeconds': targetSeconds,
      'expiryEpochMs': expiryEpochMs,
      'isCompleted': isCompleted,
    });
    return result ?? false;
  }

  @override
  Future<bool> endLiveActivity({
    String? periodId,
    required bool immediate,
  }) async {
    final payload = <String, dynamic>{'immediate': immediate};
    if (periodId != null) {
      payload['periodId'] = periodId;
    }
    final result = await _channel.invokeMethod<bool>('endLiveActivity', payload);
    return result ?? false;
  }
}

/// Service managing the lifecycle of the native iOS Live Activity & Dynamic Island
/// during workout rest periods.
///
/// Ensures zero-regression safety: gracefully no-ops on Android, web, desktop,
/// or iOS < 16.1 devices without crashing.
class IosLiveActivityService {
  static IosLiveActivityService? _instance;

  static IosLiveActivityService get instance =>
      _instance ??= IosLiveActivityService();

  @visibleForTesting
  static set instance(IosLiveActivityService? custom) {
    _instance = custom;
  }

  final IosLiveActivityDriver _driver;
  final bool Function() _isIosChecker;

  IosLiveActivityService({
    IosLiveActivityDriver? driver,
    bool Function()? isIosChecker,
  })  : _driver = driver ?? const MethodChannelIosLiveActivityDriver(),
        _isIosChecker = isIosChecker ?? _defaultIsIos;

  static bool _defaultIsIos() {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  bool get isIos => _isIosChecker();

  /// Returns whether Live Activities are supported and enabled on the current device.
  Future<bool> isAvailable() async {
    if (!isIos) return false;
    try {
      return await _driver.areActivitiesEnabled();
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      AppLogger.warning('Failed to query Live Activity availability: ${e.message}');
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Starts a Live Activity for a rest period with the given target end timestamp.
  Future<bool> startRestLiveActivity({
    required String periodId,
    required String exerciseName,
    required int targetSeconds,
    required DateTime expiryUtc,
  }) async {
    if (!isIos) return false;
    try {
      return await _driver.startLiveActivity(
        periodId: periodId,
        exerciseName: exerciseName,
        targetSeconds: targetSeconds,
        expiryEpochMs: expiryUtc.millisecondsSinceEpoch,
      );
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      AppLogger.warning('Failed to start Live Activity: ${e.message}');
      return false;
    } catch (e) {
      AppLogger.warning('Unexpected error starting Live Activity: $e');
      return false;
    }
  }

  /// Updates an active Live Activity with new target seconds or expiry timestamp
  /// (e.g. +30s added or timer resumed).
  Future<bool> updateRestLiveActivity({
    required String periodId,
    required String exerciseName,
    required int targetSeconds,
    required DateTime expiryUtc,
    bool isCompleted = false,
  }) async {
    if (!isIos) return false;
    try {
      return await _driver.updateLiveActivity(
        periodId: periodId,
        exerciseName: exerciseName,
        targetSeconds: targetSeconds,
        expiryEpochMs: expiryUtc.millisecondsSinceEpoch,
        isCompleted: isCompleted,
      );
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      AppLogger.warning('Failed to update Live Activity: ${e.message}');
      return false;
    } catch (e) {
      AppLogger.warning('Unexpected error updating Live Activity: $e');
      return false;
    }
  }

  /// Ends the active Live Activity.
  ///
  /// When [immediate] is false (e.g., normal rest expiry), the native manager transitions
  /// the Live Activity to the completed state ("Rest Complete 💪") and schedules graceful
  /// dismissal after a short window per Apple HIG.
  /// When [immediate] is true (e.g., skip, cancellation, workout finish), the Live Activity
  /// is dismissed immediately.
  Future<bool> endRestLiveActivity({
    String? periodId,
    bool immediate = false,
  }) async {
    if (!isIos) return false;
    try {
      return await _driver.endLiveActivity(
        periodId: periodId,
        immediate: immediate,
      );
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      AppLogger.warning('Failed to end Live Activity: ${e.message}');
      return false;
    } catch (e) {
      AppLogger.warning('Unexpected error ending Live Activity: $e');
      return false;
    }
  }
}
