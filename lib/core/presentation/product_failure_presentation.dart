import 'dart:async';

import '../../data/repositories/b02_strength_execution_repository.dart';
import '../../data/repositories/program_activation_coordinator.dart';
import '../../data/repositories/program_lifecycle_repository.dart';
import '../../data/repositories/workout_execution_compatibility_adapter.dart';
import '../errors/app_failure.dart';

/// Safe, consumer-facing failure copy.
///
/// Domain and infrastructure exceptions may contain identifiers, SQL, stack
/// details, or implementation vocabulary. Widgets receive this value instead
/// of interpolating an exception directly.
class ProductFailurePresentation {
  final String title;
  final String message;
  final bool canRetry;
  final String? supportReference;

  const ProductFailurePresentation({
    required this.title,
    required this.message,
    this.canRetry = false,
    this.supportReference,
  });

  factory ProductFailurePresentation.fromCode(
    String? code, {
    String title = 'Something went wrong',
    bool canRetry = true,
    String? supportReference,
  }) {
    return ProductFailurePresentation(
      title: title,
      message: _messageForCode(code),
      canRetry: canRetry && _isRetryableCode(code),
      supportReference: _opaqueReference(supportReference),
    );
  }

  /// Maps only known, deliberately safe typed failures. Unknown exceptions
  /// use a generic message; their details belong in logs/debug tooling.
  factory ProductFailurePresentation.fromError(
    Object error, {
    String title = 'Something went wrong',
    bool canRetry = true,
    String? code,
    String? supportReference,
  }) {
    final typedCode = code ?? _knownCode(error);
    return ProductFailurePresentation.fromCode(
      typedCode,
      title: title,
      canRetry: canRetry,
      supportReference: supportReference,
    );
  }

  /// Converts the legacy failure envelope at the rendering boundary. Its
  /// message is caller-provided, so it must not be treated as safe display
  /// copy. Keep that value for diagnostics and choose wording from the typed
  /// failure category instead.
  factory ProductFailurePresentation.fromAppFailure(AppFailure failure) {
    return switch (failure.type) {
      AppFailureType.offlinePolicyBlocked ||
      AppFailureType.network => const ProductFailurePresentation(
        title: 'Connection unavailable',
        message: 'Check your connection and try again.',
        canRetry: true,
      ),
      AppFailureType.permissionDenied => const ProductFailurePresentation(
        title: 'Permission needed',
        message: 'Allow this permission in Settings to continue.',
      ),
      AppFailureType.validation => ProductFailurePresentation.fromCode(
        'invalid_input',
        canRetry: false,
      ),
      AppFailureType.unsupportedPlatform => const ProductFailurePresentation(
        title: 'Not available on this device',
        message: 'This feature is not available on this device.',
      ),
      AppFailureType.corruptedBackup => const ProductFailurePresentation(
        title: 'Backup unavailable',
        message:
            'This backup can’t be used. Choose another backup and try again.',
      ),
      AppFailureType.server ||
      AppFailureType.unknown => const ProductFailurePresentation(
        title: 'Something went wrong',
        message: 'We couldn’t load this right now. Try again.',
        canRetry: true,
      ),
    };
  }

  static String? _knownCode(Object error) {
    // Do not call error.toString(): a future exception may expose sensitive
    // implementation details. The small set below is intentionally typed.
    if (error is ScheduledWorkoutFinalizationException ||
        error is B02StrengthExecutionFinalizationException) {
      return 'workout_save_failed';
    }
    if (error is ScheduledWorkoutRecoveryException ||
        error is B02StrengthExecutionRecoveryException) {
      return 'workout_recovery_needed';
    }
    if (error is ActivationRejectedException) {
      final reason = error.message.toLowerCase();
      if (reason.contains('existing workout draft') ||
          reason.contains('active workout draft')) {
        return 'workout_in_progress_conflict';
      }
      if (reason.contains('published version cannot be activated')) {
        return 'published_plan';
      }
      return 'plan_activation_rejected';
    }
    if (error is NoActivePlanException) return 'no_active_plan';
    if (error is PlanEndBlockedException) return 'plan_end_blocked';
    if (error is PlanEndCommandConflictException) {
      return 'plan_command_conflict';
    }
    if (error is ProgramLifecycleException) {
      return switch (error.code) {
        'no_active_plan' => 'no_active_plan',
        'blocked' => 'plan_end_blocked',
        'command_conflict' => 'plan_command_conflict',
        _ => 'plan_lifecycle_blocked',
      };
    }
    return switch (error) {
      FormatException() => 'invalid_input',
      TimeoutException() => 'timeout',
      _ => null,
    };
  }

  static String _messageForCode(String? code) => switch (code) {
    'timeout' => 'This is taking longer than expected. Try again.',
    'offline' =>
      'You appear to be offline. Check your connection and try again.',
    'invalid_input' =>
      'That information could not be used. Check it and try again.',
    'profile_unavailable' =>
      'Your profile is not ready yet. Try again after setup finishes.',
    'constraint_operation_failed' =>
      'Your dietary preferences could not be saved. Try again.',
    'food_log_unavailable' => 'We couldn’t load your logged food. Try again.',
    'partial_confirmation_required' =>
      'Review the estimate before saving this meal.',
    'stale_recipe_version' => 'This recipe changed. Reload it and try again.',
    'invalid_amount' => 'Enter a valid amount and try again.',
    'recipe_not_found' => 'This recipe is no longer available.',
    'workout_save_failed' => 'Your workout could not be saved. Try again.',
    'workout_recovery_needed' =>
      'This workout needs to be reopened before you can continue.',
    'workout_already_completed' => 'This workout has already been saved.',
    'workout_in_progress_conflict' =>
      'Finish or discard your active workout before starting another.',
    'no_active_plan' => 'No workout plan is currently active.',
    'plan_activation_rejected' =>
      'The plan could not be activated. Review your plan and try again.',
    'published_plan' =>
      'This plan is already published. Create a new draft to make changes.',
    'plan_end_blocked' =>
      'Resolve your active workout before ending this plan.',
    'plan_command_conflict' =>
      'That plan action is no longer available. Refresh and try again.',
    'plan_lifecycle_blocked' =>
      'That plan action is no longer available. Try again.',
    'b04_settings_load_failed' =>
      'Coaching settings could not be loaded. Try again.',
    'playlist_unavailable' => 'Music playlists are not available right now.',
    'backup_export_failed' => 'Your backup could not be exported. Try again.',
    'csv_export_failed' =>
      'Your food and workout summary could not be copied. Try again.',
    'backup_inspection_failed' =>
      'This backup could not be inspected. Choose another file or try again.',
    _ => 'We couldn’t load this right now. Try again.',
  };

  static bool _isRetryableCode(String? code) => switch (code) {
    'invalid_input' ||
    'partial_confirmation_required' ||
    'invalid_amount' ||
    'recipe_not_found' ||
    'workout_already_completed' ||
    'workout_in_progress_conflict' ||
    'no_active_plan' ||
    'plan_activation_rejected' ||
    'published_plan' ||
    'plan_end_blocked' ||
    'plan_command_conflict' ||
    'plan_lifecycle_blocked' => false,
    _ => true,
  };

  static String? _opaqueReference(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    // Support references are deliberately opaque and bounded. Never accept
    // an exception string or a UUID-shaped value as a display reference.
    if (!RegExp(r'^[A-Za-z0-9_-]{4,32}$').hasMatch(trimmed)) return null;
    return trimmed;
  }
}
