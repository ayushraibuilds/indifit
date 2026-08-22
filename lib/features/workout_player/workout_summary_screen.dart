import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/services/workout_session_wake_lock_coordinator.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/repositories/workout_execution_compatibility_adapter.dart';
import '../../data/repositories/workout_repository.dart';

class WorkoutSummaryScreen extends ConsumerStatefulWidget {
  final String routineName;
  final int elapsedSeconds;
  final List<WorkoutSetsCompanion> loggedSets;
  final String? scheduledOccurrenceId;
  final String? completionCommandId;
  final CompletionKind completionKind;

  const WorkoutSummaryScreen({
    super.key,
    required this.routineName,
    required this.elapsedSeconds,
    required this.loggedSets,
    this.scheduledOccurrenceId,
    this.completionCommandId,
    this.completionKind = CompletionKind.full,
  });

  @override
  ConsumerState<WorkoutSummaryScreen> createState() =>
      _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends ConsumerState<WorkoutSummaryScreen> {
  bool _isSaving = false;

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double _calculateTotalVolume() {
    double total = 0;
    for (final set in widget.loggedSets) {
      final double weight = set.weight.value;
      final int reps = set.reps.value;
      total += weight * reps;
    }
    return total;
  }

  // R07F-0: calorie burn is intentionally NOT calculated or shown. There is
  // no accepted canonical estimation authority for workout energy expenditure,
  // so presenting a number here would fabricate data. `estimatedCalories` is
  // persisted as 0 ("not estimated") for new records only; historical rows
  // are never rewritten.

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      if (widget.scheduledOccurrenceId case final occurrenceId?) {
        final commandId = widget.completionCommandId;
        if (commandId == null || commandId.trim().isEmpty) {
          throw const ScheduledWorkoutFinalizationException(
            'This workout is missing a required detail. Reopen it and try again.',
          );
        }
        await ref
            .read(workoutExecutionCompatibilityAdapterProvider)
            .finalizeScheduledWorkoutSession(
              occurrenceId: occurrenceId,
              commandId: commandId,
              name: widget.routineName,
              volume: _calculateTotalVolume(),
              durationSeconds: widget.elapsedSeconds,
              // No canonical calorie authority: record "not estimated" (0).
              calories: 0,
              sets: widget.loggedSets,
              completionKind: widget.completionKind,
            );
      } else {
        final repo = ref.read(workoutRepositoryProvider);
        await repo.logSession(
          name: widget.routineName,
          volume: _calculateTotalVolume(),
          durationSeconds: widget.elapsedSeconds,
          // No canonical calorie authority: record "not estimated" (0).
          calories: 0,
          sets: widget.loggedSets,
        );

        // Legacy/unscheduled behavior intentionally stays unchanged.
        await repo.deleteActiveDraft();
      }

      // The durable save/finalization above is authoritative. Screen-awake
      // cleanup is best effort and cannot turn a successful workout into a
      // failure state.
      unawaited(
        ref
            .read(workoutSessionWakeLockCoordinatorProvider)
            .clearActiveSession(
              legacyWorkoutSessionWakeLockKey(widget.scheduledOccurrenceId),
            ),
      );

      if (mounted && Navigator.of(context).canPop()) {
        Navigator.pop(context); // Exit summary and return to split view
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ProductFailurePresentation.fromError(
                error,
                title: 'Workout could not be saved',
                code: 'workout_save_failed',
              ).message,
            ),
            backgroundColor: context.b05Colors.danger.indicator,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double totalVolume = _calculateTotalVolume();
    final String durationText = _formatDuration(widget.elapsedSeconds);

    // Group sets by exercise name for summary listing
    final Map<String, List<WorkoutSetsCompanion>> grouped = {};
    for (final set in widget.loggedSets) {
      final name = set.exerciseName.value;
      if (!grouped.containsKey(name)) {
        grouped[name] = [];
      }
      grouped[name]!.add(set);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Summary'),
        automaticallyImplyLeading: false, // Don't allow backing out to player
      ),
      body: Padding(
        padding: const EdgeInsets.all(B05Layout.space20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Center(
                      child: Text('🏆', style: TextStyle(fontSize: 56)),
                    ),
                    const SizedBox(height: B05Layout.space12),
                    Text(
                      'Workout complete',
                      style: B05Typography.pageTitle(context),
                    ),
                    const SizedBox(height: B05Layout.space4),
                    Text(
                      widget.routineName,
                      textAlign: TextAlign.center,
                      style: B05Typography.label(context).copyWith(
                        color: context.b05Colors.action,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: B05Layout.space24),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact =
                            constraints.maxWidth <
                                B05Layout.compactBreakpoint ||
                            MediaQuery.textScalerOf(context).scale(1) > 1.3;
                        final metrics = [
                          _buildMetricCard(
                            context,
                            'Total volume',
                            '${totalVolume.round()} kg',
                            Icons.fitness_center_rounded,
                          ),
                          _buildMetricCard(
                            context,
                            'Duration',
                            durationText,
                            Icons.timer_outlined,
                          ),
                        ];
                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (
                                var index = 0;
                                index < metrics.length;
                                index++
                              ) ...[
                                metrics[index],
                                if (index < metrics.length - 1)
                                  const SizedBox(height: B05Layout.space8),
                              ],
                            ],
                          );
                        }
                        return Row(
                          children: [
                            for (
                              var index = 0;
                              index < metrics.length;
                              index++
                            ) ...[
                              Expanded(child: metrics[index]),
                              if (index < metrics.length - 1)
                                const SizedBox(width: B05Layout.space8),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: B05Layout.space24),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Exercises completed',
                        style: B05Typography.caption(
                          context,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: B05Layout.space12),

                    // Exercises sets summary rows
                    ...grouped.entries.map((entry) {
                      final exName = entry.key;
                      final sets = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: B05Layout.space8,
                        ),
                        child: B05Surface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(exName, style: B05Typography.label(context)),
                              const SizedBox(height: B05Layout.space8),
                              Wrap(
                                spacing: B05Layout.space8,
                                runSpacing: B05Layout.space4,
                                children: sets.map((s) {
                                  return B05Surface(
                                    tone: B05SurfaceTone.inset,
                                    radius: B05SurfaceRadius.small,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: B05Layout.space8,
                                      vertical: B05Layout.space4,
                                    ),
                                    child: Text(
                                      'Set ${s.setNumber.value}: ${s.weight.value} kg × ${s.reps.value}',
                                      style: B05Typography.caption(context),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Secondary sharing and the one clear completion action.
            SizedBox(
              width: double.infinity,
              child: B05ActionButton(
                label: 'Share workout report',
                icon: Icons.share_rounded,
                emphasis: B05ActionEmphasis.secondary,
                onPressed: _isSaving
                    ? null
                    : () {
                        final text =
                            'Crushed my workout today! 🏋️\n'
                            'Routine: ${widget.routineName}\n'
                            'Volume Lifted: ${totalVolume.round()} kg\n'
                            'Duration: $durationText\n'
                            'Logged with IndiFit App ⚡';
                        Share.share(text);
                      },
              ),
            ),
            const SizedBox(height: B05Layout.space8),
            SizedBox(
              width: double.infinity,
              child: B05ActionButton(
                label: 'Save workout',
                icon: Icons.check_rounded,
                onPressed: _isSaving ? null : _handleSave,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return B05Surface(
      tone: B05SurfaceTone.inset,
      radius: B05SurfaceRadius.small,
      padding: const EdgeInsets.all(B05Layout.space12),
      child: Row(
        children: [
          Icon(
            icon,
            color: context.b05Colors.action,
            size: B05Layout.iconMedium,
          ),
          const SizedBox(width: B05Layout.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: B05Typography.label(context)),
                const SizedBox(height: B05Layout.space4),
                Text(label, style: B05Typography.caption(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
