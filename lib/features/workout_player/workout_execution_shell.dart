import 'package:flutter/material.dart';

import 'workout_execution_context.dart';

/// Shared execution chrome for Planned and Quick workouts.
///
/// The shell owns only presentation composition: title/context, navigation
/// chrome, stable slots, safe scrolling, and action hierarchy. It does not
/// own draft state, elapsed time, set mutations, rest timing, or completion.
/// Those remain supplied by the canonical execution controller/repository.
class WorkoutExecutionShell extends StatelessWidget {
  const WorkoutExecutionShell({
    required this.execution,
    super.key,
    this.workoutContextSlot,
    this.exerciseProgressSlot,
    this.currentExerciseSlot,
    this.setLoggingSlot,
    this.primaryActionSlot,
    this.nextExerciseSlot,
    this.restSlot,
    this.completionSlot,
    this.contentOverride,
    this.onClose,
    this.onReview,
    this.onDiscard,
    this.isBusy = false,
    this.primaryActionGap = 10,
    this.nextExerciseGap = 12,
  });

  final WorkoutExecutionContext execution;

  /// Common execution slots reserved for the B.2–B.8 packages.
  final Widget? workoutContextSlot;
  final Widget? exerciseProgressSlot;
  final Widget? currentExerciseSlot;
  final Widget? setLoggingSlot;
  final Widget? primaryActionSlot;
  final Widget? nextExerciseSlot;
  final Widget? restSlot;
  final Widget? completionSlot;

  /// Used for loading, unavailable, and empty states while retaining the
  /// shared route/app-bar boundary.
  final Widget? contentOverride;

  final VoidCallback? onClose;
  final VoidCallback? onReview;
  final VoidCallback? onDiscard;
  final bool isBusy;
  final double primaryActionGap;
  final double nextExerciseGap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close workout',
          onPressed: isBusy ? null : onClose,
        ),
        title: Text(execution.workoutTitle),
        actions: [
          if (onReview != null || onDiscard != null)
            PopupMenuButton<String>(
              tooltip: 'Workout options',
              enabled: !isBusy,
              onSelected: (value) {
                switch (value) {
                  case 'review':
                    onReview?.call();
                  case 'discard':
                    onDiscard?.call();
                }
              },
              itemBuilder: (context) => [
                if (onReview != null)
                  const PopupMenuItem(
                    value: 'review',
                    child: Text('Review workout'),
                  ),
                if (onDiscard != null)
                  const PopupMenuItem(
                    value: 'discard',
                    child: Text('Discard workout'),
                  ),
              ],
            ),
        ],
      ),
      body: contentOverride ?? _buildSlots(context),
    );
  }

  Widget _buildSlots(BuildContext context) {
    final slots = <_WorkoutExecutionSlot>[
      if (workoutContextSlot != null)
        _WorkoutExecutionSlot(
          workoutContextSlot!,
          label: '${execution.modeLabel} context',
        ),
      if (exerciseProgressSlot != null)
        _WorkoutExecutionSlot(
          exerciseProgressSlot!,
          label: 'Exercise progress',
        ),
      if (currentExerciseSlot != null)
        _WorkoutExecutionSlot(currentExerciseSlot!, label: 'Current exercise'),
      if (restSlot != null) _WorkoutExecutionSlot(restSlot!, label: 'Rest'),
      if (primaryActionSlot != null)
        _WorkoutExecutionSlot(
          primaryActionSlot!,
          label: 'Primary workout action',
          gapBefore: primaryActionGap,
        ),
      if (setLoggingSlot != null)
        _WorkoutExecutionSlot(setLoggingSlot!, label: 'Set logging'),
      if (nextExerciseSlot != null)
        _WorkoutExecutionSlot(
          nextExerciseSlot!,
          label: 'Next exercise',
          gapBefore: nextExerciseGap,
        ),
      if (completionSlot != null)
        _WorkoutExecutionSlot(
          completionSlot!,
          label: 'Workout review and completion',
        ),
    ];

    return SafeArea(
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          for (var index = 0; index < slots.length; index++) ...[
            if (index > 0) SizedBox(height: slots[index].gapBefore ?? 12),
            _slot(slots[index].child, label: slots[index].label),
          ],
        ],
      ),
    );
  }

  Widget _slot(Widget child, {required String label}) {
    return Semantics(container: true, label: label, child: child);
  }
}

class _WorkoutExecutionSlot {
  const _WorkoutExecutionSlot(
    this.child, {
    required this.label,
    this.gapBefore,
  });

  final Widget child;
  final String label;
  final double? gapBefore;
}
