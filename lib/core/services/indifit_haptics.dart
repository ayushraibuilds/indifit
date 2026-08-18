import 'dart:async';
import 'package:flutter/services.dart';

/// Centralized, restrained haptic feedback service for IndiFit.
///
/// Haptic feedback is strictly presentation feedback: it reinforces verified
/// user actions and state transitions, and must never block async business logic
/// or fail execution when unavailable on the platform.
abstract final class IndiFitHaptics {
  /// Test-only callback hook for intercepting haptic feedback events.
  static void Function(IndiFitHapticType type)? debugHandler;

  /// Lightweight selection feedback for changing date/period selectors,
  /// adjusting rest seconds (+15s / -15s), or toggling food multi-select items.
  static Future<void> selection() =>
      _trigger(IndiFitHapticType.selection, HapticFeedback.selectionClick);

  /// Medium tactile confirmation feedback for verified completion actions:
  /// successful set completion, fast food logging, saved meal re-log,
  /// workout finish, plan finish, or rest timer expiration.
  ///
  /// Rule: Always fire after authoritative persistence succeeds, never on tap.
  static Future<void> confirmation() =>
      _trigger(IndiFitHapticType.confirmation, HapticFeedback.mediumImpact);

  /// Heavy / warning feedback for consequential confirmations:
  /// Leave Plan confirmed, Delete Saved Meal confirmed, Discard Workout.
  static Future<void> warning() =>
      _trigger(IndiFitHapticType.warning, HapticFeedback.heavyImpact);

  static Future<void> _trigger(
    IndiFitHapticType type,
    Future<void> Function() action,
  ) async {
    try {
      debugHandler?.call(type);
      await action();
    } catch (_) {
      // Haptics are optional tactile feedback; platform unavailability or
      // plugin/test-hook errors must be silently ignored.
    }
  }
}

/// Category of haptic feedback emitted by IndiFit.
enum IndiFitHapticType { selection, confirmation, warning }
