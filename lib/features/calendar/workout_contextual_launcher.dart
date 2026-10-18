import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/consumer_date_label.dart';
import '../../core/widgets/indi_fit_feedback.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/b02_strength_execution_repository.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../../data/repositories/workout_execution_compatibility_adapter.dart';
import '../workout_player/b02_strength_execution_controller.dart';
import '../workout_player/workout_execution_route.dart';

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

  /// What starting off-date does. An early start moves this workout to
  /// today and the plan's later workouts up to the next training days; a
  /// late start leaves the rest of the plan where it is.
  static String outsideDateMessage(
    WidgetRef ref,
    CalendarOccurrenceReadItem item,
  ) {
    final occurrence = item.occurrence;
    final dates = ref.read(localScheduleDateServiceProvider);
    final today = dates.todayIn(occurrence.effectiveTimezoneId);
    final scheduled = ConsumerDateLabel.inSentence(
      occurrence.effectiveLocalDate,
      today: DateTime.parse(today),
    );
    if (dates.compare(occurrence.effectiveLocalDate, today) > 0) {
      return 'This workout is scheduled for $scheduled. Starting it now '
          'moves it to today, and your later plan workouts move up to your '
          'next training days.';
    }
    return 'This workout was scheduled for $scheduled. Starting it now '
        'leaves the rest of your plan where it is.';
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
        // A retained B02 draft in recovery is never downgraded to the legacy
        // adapter. That could start a second path or expose an unsafe Start
        // action after the canonical state has already claimed the workout.
        if (state.status == B02StrengthExecutionStatus.recovery) {
          throw const B02StrengthExecutionRecoveryException(
            'The saved workout requires recovery.',
          );
        }
        throw const B02StrengthExecutionException(
          'The workout could not be started.',
        );
      }
    } else if (activityType != B02ActivityType.legacy) {
      throw StateError(
        'This activity uses its own activity flow and cannot be opened here.',
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
        extra: WorkoutExecutionRouteData.fromLaunch(target.launch),
      ),
      B01WorkoutOccurrenceLaunchTarget() =>
        throw const B02StrengthExecutionException(
          'Workout could not be started. Try again.',
        ),
    };
  }
}
