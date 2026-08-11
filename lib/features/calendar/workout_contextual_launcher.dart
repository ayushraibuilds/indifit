import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/widgets/indi_fit_feedback.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/b02_strength_execution_repository.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../../data/repositories/workout_execution_compatibility_adapter.dart';
import '../workout_player/b02_strength_execution_controller.dart';

/// Typed route data produced by the existing B01/B02 execution owners.
sealed class WorkoutOccurrenceLaunchTarget {
  const WorkoutOccurrenceLaunchTarget();
}

class B01WorkoutOccurrenceLaunchTarget extends WorkoutOccurrenceLaunchTarget {
  const B01WorkoutOccurrenceLaunchTarget(this.launch);

  final WorkoutPlayerLaunchData launch;
}

class B02WorkoutOccurrenceLaunchTarget extends WorkoutOccurrenceLaunchTarget {
  const B02WorkoutOccurrenceLaunchTarget(this.launch);

  final B02StrengthExecutionLaunch launch;
}

/// Bridges contextual controls to the existing B01/B02 start/resume commands.
/// It owns no occurrence state, player persistence, or playlist behavior.
abstract final class WorkoutContextualLauncher {
  static bool requiresDateConfirmation(
    WidgetRef ref,
    CalendarOccurrenceReadItem item,
  ) {
    final occurrence = item.occurrence;
    return ref
            .read(localScheduleDateServiceProvider)
            .todayIn(occurrence.effectiveTimezoneId) !=
        occurrence.effectiveLocalDate;
  }

  static Future<WorkoutOccurrenceLaunchTarget> prepare({
    required WidgetRef ref,
    required CalendarOccurrenceReadItem item,
    required bool confirmedOutsideEffectiveDate,
  }) async {
    final occurrence = item.occurrence;
    final activityType = B02ActivityType.parse(item.template.activityType);
    final commandId = const Uuid().v4();

    if (activityType == B02ActivityType.strength) {
      final coverage = await ref
          .read(strengthExecutionCompatibilityAdapterProvider)
          .checkScheduledCoverage(occurrence.id);
      if (coverage.supported) {
        final controller = ref.read(
          b02StrengthExecutionControllerProvider.notifier,
        );
        if (occurrence.status == 'inProgress') {
          await controller.resumeScheduled(occurrence.id);
        } else {
          await controller.startScheduled(
            occurrenceId: occurrence.id,
            commandId: commandId,
            confirmedOutsideEffectiveDate: confirmedOutsideEffectiveDate,
          );
        }
        final state = ref.read(b02StrengthExecutionControllerProvider);
        if (state.status == B02StrengthExecutionStatus.ready &&
            state.launch != null) {
          return B02WorkoutOccurrenceLaunchTarget(state.launch!);
        }
        // A retained B01 draft is a recovery state; it is never downgraded to
        // an invented B02 completion path.
        if (state.status != B02StrengthExecutionStatus.recovery) {
          throw StateError(
            state.errorMessage ?? 'B02 strength workout could not be started.',
          );
        }
      }
    } else if (activityType != B02ActivityType.legacy) {
      throw StateError(
        'Scheduled ${activityType.dbValue} activity uses its typed activity flow and cannot open the legacy strength player.',
      );
    }

    final adapter = ref.read(workoutExecutionCompatibilityAdapterProvider);
    final launch = occurrence.status == 'inProgress'
        ? await adapter.resumeScheduledOccurrence(occurrence.id)
        : await adapter.startScheduledOccurrence(
            occurrenceId: occurrence.id,
            commandId: commandId,
            confirmedOutsideEffectiveDate: confirmedOutsideEffectiveDate,
          );
    return B01WorkoutOccurrenceLaunchTarget(launch);
  }

  static Future<void> push(
    BuildContext context,
    WorkoutOccurrenceLaunchTarget target,
  ) {
    dismissIndiFitFeedback(context);
    return switch (target) {
      B02WorkoutOccurrenceLaunchTarget() => context.push(
        '/b02-strength-player',
        extra: {'launch': target.launch},
      ),
      B01WorkoutOccurrenceLaunchTarget() => context.push(
        '/workout-player',
        extra: {'scheduledLaunch': target.launch},
      ),
    };
  }
}
