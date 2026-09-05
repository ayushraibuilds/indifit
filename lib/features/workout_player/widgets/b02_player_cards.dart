import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/consumer_copy.dart';
import '../../../core/services/indifit_haptics.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../data/models/b02_execution_models.dart';
import '../../../data/models/b02_previous_performance_models.dart';
import '../../../data/repositories/b02_strength_execution_repository.dart';
import '../../../data/services/b02_rest_recommendation_service.dart';
import '../b02_previous_performance_integration.dart';
import '../b02_workout_elapsed.dart';
import '../workout_execution_context.dart';
import 'b02_execution_semantics.dart';
import 'r07c_workout_presentation.dart';

/// B02 player cards (PV1-ENG-05C first pass).
///
/// Extracted verbatim from `b02_strength_player_screen.dart`; unchanged.

class GroupProgressCard extends StatelessWidget {
  final B02StrengthExecutionLaunch launch;
  final List<B02StrengthExecutionSlot> slots;
  final B02StrengthExecutionSlot selected;

  const GroupProgressCard({super.key, 
    required this.launch,
    required this.slots,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    if (launch.state.groups.isEmpty && selected.groupId == null) {
      final completed = launch.state.performedExercises
          .where((exercise) => exercise.status == 'completed')
          .length;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workout progress',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text('$completed of ${slots.length} exercises complete'),
              const SizedBox(height: 10),
            ],
          ),
        ),
      );
    }
    final cursorIntegrity = B02GroupExecutionIntegrity.checkCurrentPosition(
      state: launch.state,
      slots: slots,
    );
    final completed = launch.state.performedExercises
        .where((exercise) => exercise.status == 'completed')
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workout progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text('$completed of ${slots.length} exercises complete'),
            if (!cursorIntegrity.isValid)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline_rounded),
                title: Text('Exercise details unavailable'),
                subtitle: Text(ConsumerCopy.groupDetailsUnavailable),
              ),
            if (selected.groupId != null &&
                !launch.state.groups.any(
                  (group) => group.id == selected.groupId,
                ))
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline_rounded),
                title: Text('Exercise details unavailable'),
                subtitle: Text(ConsumerCopy.groupDetailsUnavailable),
              ),
            for (final group in launch.state.groups) ...[
              const SizedBox(height: 10),
              _buildGroup(context, group),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroup(BuildContext context, B02ExerciseGroup group) {
    final integrity = B02GroupExecutionIntegrity.check(
      group: group,
      slots: slots,
    );
    if (!integrity.isValid) {
      return Semantics(
        container: true,
        label: 'Exercise details unavailable',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text('Exercise details unavailable'),
          subtitle: Text(integrity.consumerMessage!),
        ),
      );
    }
    final name = group.label?.trim().isNotEmpty == true
        ? group.label!.trim()
        : b02ExecutionGroupTypeLabel(group.groupType);
    final groupSlots = slots.where((slot) => slot.groupId == group.id);
    final completeCount = launch.state.performedExercises
        .where(
          (exercise) =>
              exercise.performedExerciseGroupId == group.id &&
              exercise.status == 'completed',
        )
        .length;
    final expected = group.roundCount * group.members.length;
    final current = _canonicalCurrentSlot(group);
    final next = current == null ? null : _nextSlot(group, groupSlots, current);
    return Semantics(
      container: true,
      label:
          '$name, $completeCount of $expected exercise slots complete'
          '${current == null ? '' : ', current ${current.exerciseNameSnapshot}'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$name · ${group.roundCount} ${group.roundCount == 1 ? 'round' : 'rounds'}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text('$completeCount of $expected exercise slots complete'),
          if (current != null) ...[
            const SizedBox(height: 4),
            Text(
              'Current: ${current.exerciseNameSnapshot} · Round ${(current.roundOrdinal ?? 0) + 1}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (next != null) ...[
            const SizedBox(height: 2),
            Text(
              'Next: ${next.exerciseNameSnapshot}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  B02StrengthExecutionSlot? _canonicalCurrentSlot(B02ExerciseGroup group) {
    final state = launch.state;
    if (state.currentGroupId != group.id ||
        state.currentRoundOrdinal == null ||
        state.currentMemberOrdinal == null) {
      return null;
    }
    for (final slot in slots) {
      if (slot.groupId == group.id &&
          slot.roundOrdinal == state.currentRoundOrdinal &&
          slot.memberOrdinal == state.currentMemberOrdinal) {
        return slot;
      }
    }
    return null;
  }

  B02StrengthExecutionSlot? _nextSlot(
    B02ExerciseGroup group,
    Iterable<B02StrengthExecutionSlot> groupSlots,
    B02StrengthExecutionSlot current,
  ) {
    final roundSlots = b02GroupRoundSlots(
      slots: groupSlots,
      groupId: group.id,
      roundOrdinal: current.roundOrdinal ?? 0,
    );
    final currentIndex = roundSlots.indexWhere(
      (slot) => slot.memberOrdinal == current.memberOrdinal,
    );
    if (currentIndex >= 0 && currentIndex + 1 < roundSlots.length) {
      return roundSlots[currentIndex + 1];
    }
    final nextRound = (current.roundOrdinal ?? 0) + 1;
    if (nextRound >= group.roundCount) return null;
    final nextRoundSlots = b02GroupRoundSlots(
      slots: groupSlots,
      groupId: group.id,
      roundOrdinal: nextRound,
    );
    return nextRoundSlots.isEmpty ? null : nextRoundSlots.first;
  }
}

class PrescribedWorkCompleteCard extends StatelessWidget {
  const PrescribedWorkCompleteCard({super.key, 
    required this.plannedSets,
    required this.workingSets,
  });

  final int plannedSets;
  final int workingSets;

  @override
  Widget build(BuildContext context) {
    final success = context.b05Colors.success;
    return Semantics(
      container: true,
      label: 'Planned sets complete',
      child: B05Surface(
        tone: B05SurfaceTone.selected,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_outline_rounded, color: success.foreground),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Planned sets complete',
                    style: B05Typography.title(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$workingSets of $plannedSets working sets logged. All planned sets are logged.',
                    style: B05Typography.body(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class R07CExecutionHeader extends StatelessWidget {
  const R07CExecutionHeader({super.key, 
    required this.executionContext,
    required this.exerciseIndex,
    required this.exerciseCount,
    required this.currentSet,
    required this.plannedSets,
    required this.exerciseComplete,
    required this.groupContext,
    required this.exerciseName,
    required this.elapsedState,
    required this.nowUtc,
    required this.onActions,
  });

  final WorkoutExecutionContext executionContext;
  final int exerciseIndex;
  final int exerciseCount;
  final int currentSet;
  final int plannedSets;
  final bool exerciseComplete;
  final String? groupContext;
  final String exerciseName;
  final B02ExecutionDraftState elapsedState;
  final DateTime Function()? nowUtc;
  final VoidCallback? onActions;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final exercisePosition = 'Exercise ${exerciseIndex + 1} of $exerciseCount';
    final position = exercisePosition;
    final status =
        groupContext ??
        (exerciseComplete
            ? 'Exercise complete'
            : 'Set $currentSet${executionContext is QuickWorkoutExecutionContext ? '' : ' of $plannedSets'}');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Semantics(
                      label: '${executionContext.modeLabel}, $exercisePosition',
                      child: Text(
                        position.toUpperCase(),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.action,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  B02LiveElapsedText(
                    accumulatedSeconds: elapsedState.elapsedSeconds,
                    activeSegmentStartedAtUtc:
                        elapsedState.activeSegmentStartedAtUtc,
                    nowUtc: nowUtc ?? _systemNowUtc,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Semantics(
                header: true,
                child: Text(
                  exerciseName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 4),
              Text(status),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Exercise actions',
          onPressed: onActions,
          icon: const Icon(Icons.more_horiz_rounded),
        ),
      ],
    );
  }

  static DateTime _systemNowUtc() => DateTime.now().toUtc();
}

class R07CExerciseStrip extends StatelessWidget {
  const R07CExerciseStrip({super.key, 
    required this.slots,
    required this.state,
    required this.selectedId,
    required this.onSelected,
  });

  final List<B02StrengthExecutionSlot> slots;
  final B02ExecutionDraftState state;
  final String selectedId;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < slots.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            _exerciseChip(slots[index], index),
          ],
        ],
      ),
    );
  }

  Widget _exerciseChip(B02StrengthExecutionSlot slot, int index) {
    final selected = slot.id == selectedId;
    final complete = state.performedExercises.any(
      (exercise) =>
          (exercise.id == 'performed:${slot.id}' ||
              (exercise.sourceExercisePrescriptionId == slot.prescriptionId &&
                  exercise.performedExerciseGroupId == slot.groupId &&
                  exercise.groupRoundOrdinal == slot.roundOrdinal &&
                  exercise.groupMemberOrdinal == slot.memberOrdinal)) &&
          exercise.status == 'completed',
    );
    final name = slot.exerciseNameSnapshot.trim().isEmpty
        ? 'Exercise'
        : slot.exerciseNameSnapshot;
    return Tooltip(
      message: name,
      child: Semantics(
        button: true,
        selected: selected,
        label:
            '${complete ? 'Completed ' : ''}$name, exercise ${index + 1} of ${slots.length}',
        onTap: onSelected == null ? null : () => onSelected!(slot.id),
        child: ChoiceChip(
          selected: selected,
          onSelected: onSelected == null ? null : (_) => onSelected!(slot.id),
          avatar: complete ? const Icon(Icons.check_rounded, size: 16) : null,
          label: Text('${index + 1}'),
        ),
      ),
    );
  }
}

class R07CTargetContext extends StatelessWidget {
  final B02StrengthExecutionSlot slot;
  final B02ExecutionDraftState state;
  final B02PreviousExercisePerformance? previousPerformance;
  final VoidCallback? onApply;
  final VoidCallback? onChange;

  const R07CTargetContext({super.key, 
    required this.slot,
    required this.state,
    required this.previousPerformance,
    required this.onApply,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final recommendation = state.targetRecommendations[slot.id];
    final override = state.targetOverrides[slot.id];
    final load =
        override?.loadKg ??
        recommendation?.recommendedLoadKg ??
        slot.targetLoadKg;
    final loadBasis =
        override?.loadBasis ??
        recommendation?.loadBasis ??
        slot.targetLoadBasis;
    final minReps =
        override?.targetRepsMin ??
        recommendation?.targetRepsMin ??
        slot.targetRepsMin;
    final maxReps =
        override?.targetRepsMax ??
        recommendation?.targetRepsMax ??
        slot.targetRepsMax;
    final rpe =
        override?.targetRpe ?? recommendation?.targetRpe ?? slot.targetRpe;
    final hasTarget = r07cHasUsefulTarget(
      loadKg: load,
      loadBasis: loadBasis,
      minReps: minReps,
      maxReps: maxReps,
      rpe: rpe,
    );
    final target = hasTarget
        ? r07cFormatTarget(
            loadKg: load,
            loadBasis: loadBasis,
            minReps: minReps,
            maxReps: maxReps,
            rpe: rpe,
          )
        : null;
    final last = B02PreviousPerformancePresentation.lastTime(
      previousPerformance,
    );
    if (last == null && target == null) return const SizedBox.shrink();
    return B05Surface(
      tone: B05SurfaceTone.inset,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.insights_outlined, color: context.b05Colors.action),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (last != null) ...[
                      Text('Last time', style: B05Typography.label(context)),
                      const SizedBox(height: 2),
                      Text(last),
                    ],
                    if (target != null) ...[
                      if (last != null) const SizedBox(height: 8),
                      Text(
                        recommendation == null ? 'Today’s target' : 'Suggested',
                        style: B05Typography.label(context),
                      ),
                      const SizedBox(height: 2),
                      Text(target),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (recommendation != null)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 2,
                children: [
                  if (target != null)
                    TextButton(onPressed: onApply, child: const Text('Apply')),
                  TextButton(onPressed: onChange, child: const Text('Change')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class WarmupCard extends StatelessWidget {
  final B02WarmupRecommendation recommendation;
  final VoidCallback? onAccept;
  final VoidCallback? onEdit;
  final VoidCallback? onSkip;

  const WarmupCard({super.key, 
    required this.recommendation,
    required this.onAccept,
    required this.onEdit,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    if (recommendation.proposals.isEmpty &&
        recommendation.selectedProposals.isEmpty) {
      return const SizedBox.shrink();
    }
    final offered = recommendation.decision == B02WarmupDecision.offered;
    final skipped = recommendation.decision == B02WarmupDecision.skipped;
    final proposals = offered
        ? recommendation.proposals
        : recommendation.selectedProposals;
    final title = switch (recommendation.decision) {
      B02WarmupDecision.offered => 'Warm-up suggestion',
      B02WarmupDecision.accepted => 'Warm-up accepted',
      B02WarmupDecision.edited => 'Warm-up adjusted',
      B02WarmupDecision.skipped => 'Warm-up skipped',
    };
    final subtitle = skipped
        ? 'You can use the suggested ramp sets at any time.'
        : offered
        ? 'Prepare with a few lighter sets before you begin.'
        : 'Your selected ramp sets are saved with this workout.';
    return B05Surface(
      tone: B05SurfaceTone.inset,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.whatshot_outlined),
            title: Text(title),
            subtitle: Text(subtitle),
          ),
          if (proposals.isNotEmpty)
            Text(
              proposals
                  .map(r07cFormatWarmupProposal)
                  .whereType<String>()
                  .join('  ·  '),
            ),
          if (recommendation.proposals.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (offered || skipped)
                  OutlinedButton(
                    onPressed: onAccept,
                    child: Text(offered ? 'Accept' : 'Use suggestion'),
                  ),
                OutlinedButton(
                  onPressed: onEdit,
                  child: Text(offered ? 'Edit' : 'Change'),
                ),
                if (offered || !skipped)
                  TextButton(onPressed: onSkip, child: const Text('Skip')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

@visibleForTesting
bool b02RestPeriodBelongsToSlot(
  B02RestPeriod period,
  B02StrengthExecutionSlot slot,
) {
  final groupId = slot.groupId;
  return (groupId != null && period.performedExerciseGroupId == groupId) ||
      period.id.startsWith('rest:${slot.id}:');
}

class RestCard extends StatefulWidget {
  final B02StrengthExecutionSlot slot;
  final B02ExecutionDraftState state;
  final VoidCallback? onBegin;
  final ValueChanged<int>? onCustom;
  final ValueChanged<String>? onExtend;
  final ValueChanged<String>? onDecrease;
  final ValueChanged<String>? onSkip;
  final Future<bool> Function(String) onElapsed;

  const RestCard({super.key, 
    required this.slot,
    required this.state,
    required this.onBegin,
    required this.onCustom,
    required this.onExtend,
    required this.onDecrease,
    required this.onSkip,
    required this.onElapsed,
  });

  @override
  State<RestCard> createState() => _RestCardState();
}

class _RestCardState extends State<RestCard> {
  late DateTime _now;
  Timer? _ticker;
  var _finishingElapsedRest = false;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now().toUtc();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant RestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuilds and restored route instances repaint from the durable start
    // timestamp immediately; they never carry a decremented local counter.
    _now = DateTime.now().toUtc();
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final period = _openPeriod(widget);
    final remaining = period == null ? null : _remainingLabel(period);
    final remainingSeconds = period == null
        ? null
        : b02RestRemainingSeconds(period, _now);
    return Semantics(
      container: true,
      label: period == null ? 'Rest controls' : 'Rest in progress',
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.timer_outlined, color: context.b05Colors.action),
                  const SizedBox(width: 8),
                  Text('REST', style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
              const SizedBox(height: 8),
              if (period == null) ...[
                Text(
                  'Ready when you are',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.slot.groupType == null
                      ? 'Take a breather before your next set.'
                      : 'Rest before the next exercise in this group.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: widget.onBegin,
                      child: const Text('Start rest'),
                    ),
                    OutlinedButton(
                      onPressed: widget.onCustom == null
                          ? null
                          : () async {
                              final controller = TextEditingController();
                              final value = await showDialog<int>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Custom rest'),
                                  content: TextField(
                                    controller: controller,
                                    autofocus: true,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Seconds',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => context.pop(),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => context.pop(
                                        int.tryParse(controller.text),
                                      ),
                                      child: const Text('Start'),
                                    ),
                                  ],
                                ),
                              );
                              controller.dispose();
                              if (value != null && value >= 0) {
                                widget.onCustom?.call(value);
                              }
                            },
                      child: const Text('Custom'),
                    ),
                  ],
                ),
              ] else ...[
                Center(
                  child: SizedBox.square(
                    dimension: 92,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value:
                              period.selectedSeconds == null ||
                                  period.selectedSeconds == 0
                              ? 0
                              : (remainingSeconds! / period.selectedSeconds!)
                                    .clamp(0.0, 1.0),
                          strokeWidth: 5,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                        ),
                        Semantics(
                          label: 'Rest remaining $remaining',
                          liveRegion: false,
                          child: ExcludeSemantics(
                            child: Text(
                              remaining!,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (_hasUsefulTarget(widget.slot))
                  Center(
                    child: Text(
                      'Next set: ${widget.slot.targetRepsMin ?? '—'}${widget.slot.targetRepsMax == null || widget.slot.targetRepsMax == widget.slot.targetRepsMin ? '' : '–${widget.slot.targetRepsMax}'} reps',
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Decrease rest by 15 seconds',
                      child: OutlinedButton(
                        onPressed: widget.onDecrease == null
                            ? null
                            : () {
                                unawaited(IndiFitHaptics.selection());
                                widget.onDecrease?.call(period.id);
                              },
                        child: const Text('−15 sec'),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Increase rest by 15 seconds',
                      child: OutlinedButton(
                        onPressed: widget.onExtend == null
                            ? null
                            : () {
                                unawaited(IndiFitHaptics.selection());
                                widget.onExtend?.call(period.id);
                              },
                        child: const Text('+15 sec'),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Skip rest',
                      child: TextButton(
                        onPressed: widget.onSkip == null
                            ? null
                            : () {
                                unawaited(IndiFitHaptics.selection());
                                widget.onSkip?.call(period.id);
                              },
                        // Keep the compact visible action label stable for the
                        // existing player surface; the surrounding Semantics
                        // label retains the clearer "Skip rest" announcement.
                        child: const Text('Skip'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _remainingLabel(B02RestPeriod period) {
    final remaining = b02RestRemainingSeconds(period, _now);
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  bool _hasUsefulTarget(B02StrengthExecutionSlot slot) {
    return r07cHasUsefulTarget(
      loadKg: slot.targetLoadKg,
      loadBasis: slot.targetLoadBasis,
      minReps: slot.targetRepsMin,
      maxReps: slot.targetRepsMax,
      rpe: slot.targetRpe,
    );
  }

  B02RestPeriod? _openPeriod(RestCard value) {
    final open = value.state.restPeriods
        .where((period) => period.endedAtUtc == null)
        .toList();
    return open.isEmpty ? null : open.last;
  }

  void _syncTicker() {
    final period = _openPeriod(widget);
    if (period != null && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final now = DateTime.now().toUtc();
        final open = _openPeriod(widget);
        if (open == null) {
          _syncTicker();
          return;
        }
        if (b02RestRemainingSeconds(open, now) == 0) {
          _ticker?.cancel();
          _ticker = null;
          setState(() => _now = now);
          if (!_finishingElapsedRest) {
            _finishingElapsedRest = true;
            unawaited(_completeElapsedRest(open.id));
          }
          return;
        }
        setState(() => _now = now);
      });
    } else if (period == null) {
      _ticker?.cancel();
      _ticker = null;
      _finishingElapsedRest = false;
    }
  }

  Future<void> _completeElapsedRest(String periodId) async {
    try {
      final completed = await widget.onElapsed(periodId);
      if (completed && mounted) {
        unawaited(IndiFitHaptics.confirmation());
      } else if (!completed && mounted) {
        _finishingElapsedRest = false;
        _now = DateTime.now().toUtc();
        _syncTicker();
      }
    } catch (_) {
      // A failed durable completion must not create tactile success feedback.
      if (mounted) {
        _finishingElapsedRest = false;
        _now = DateTime.now().toUtc();
        _syncTicker();
      }
    }
  }
}

@visibleForTesting
int b02RestRemainingSeconds(B02RestPeriod period, DateTime now) {
  return B02RestTimerSnapshot(period).remainingSeconds(now);
}

class ErrorState extends StatelessWidget {
  final String message;
  final bool canRetry;
  final VoidCallback? onRetry;
  final VoidCallback onClose;

  const ErrorState({super.key, 
    required this.message,
    required this.canRetry,
    required this.onRetry,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 44),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (canRetry)
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          TextButton(
            onPressed: onClose,
            child: const Text('Keep workout and go back'),
          ),
        ],
      ),
    ),
  );
}
