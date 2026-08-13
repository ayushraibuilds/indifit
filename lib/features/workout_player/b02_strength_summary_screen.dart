import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/b02_strength_execution_repository.dart';
import '../../data/repositories/calendar_repository.dart';
import 'b02_strength_execution_controller.dart';
import 'widgets/r07c_workout_presentation.dart';

/// Final review for B02 strength execution. Full and partial completion are
/// explicit actions; a failed finalization keeps the linked draft visible.
class B02StrengthSummaryScreen extends ConsumerStatefulWidget {
  final B02StrengthExecutionLaunch launch;

  const B02StrengthSummaryScreen({super.key, required this.launch});

  @override
  ConsumerState<B02StrengthSummaryScreen> createState() =>
      _B02StrengthSummaryScreenState();
}

class _B02StrengthSummaryScreenState
    extends ConsumerState<B02StrengthSummaryScreen> {
  late final String _completionCommandId;
  var _isFinalizing = false;
  B02StrengthExecutionLaunch? _completionLaunch;
  CompletionKind? _pendingCompletionKind;
  String? _pendingCompletionReason;

  @override
  void initState() {
    super.initState();
    _completionCommandId = const Uuid().v4();
  }

  @override
  Widget build(BuildContext context) {
    final provider = b02StrengthExecutionScreenControllerProvider(
      widget.launch,
    );
    final ui = ref.watch(provider);
    final current = ui.launch ?? widget.launch;
    final completed =
        ui.status == B02StrengthExecutionStatus.ready && ui.launch == null;
    if (completed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout complete')),
        body: B02WorkoutCompletionSuccess(
          launch: _completionLaunch ?? widget.launch,
          onDone: () => context.go('/training'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Review workout')),
      body: _Body(
        launch: current,
        ui: ui,
        onRetry: ui.launch == null || _pendingCompletionKind == null
            ? null
            : () => _complete(
                context,
                provider,
                _pendingCompletionKind!,
                reason: _pendingCompletionReason,
              ),
        onFull: ui.isBusy || _isFinalizing
            ? null
            : () => _complete(context, provider, CompletionKind.full),
        onPartial: ui.isBusy || _isFinalizing
            ? null
            : () => _confirmPartial(context, provider),
        onBack: () => context.pop(),
      ),
    );
  }

  Future<void> _confirmPartial(BuildContext context, dynamic provider) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Finish partially?'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'For example: time or equipment limit',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Keep training'),
            ),
            FilledButton(
              onPressed: () => context.pop(controller.text.trim()),
              child: const Text('Confirm partial finish'),
            ),
          ],
        );
      },
    );
    if (reason == null || !context.mounted) return;
    await _complete(context, provider, CompletionKind.partial, reason: reason);
  }

  Future<void> _complete(
    BuildContext context,
    dynamic provider,
    CompletionKind kind, {
    String? reason,
  }) async {
    if (_isFinalizing) return;
    setState(() {
      _isFinalizing = true;
      _pendingCompletionKind = kind;
      _pendingCompletionReason = reason?.isEmpty == true ? null : reason;
    });
    final controller = ref.read(provider.notifier);
    try {
      await controller.pauseElapsed();
      if (!mounted) return;
      _completionLaunch = ref.read(provider).launch ?? widget.launch;
      await controller.finalize(
        commandId: _completionCommandId,
        completionKind: kind,
        reason: _pendingCompletionReason,
      );
    } finally {
      if (mounted) setState(() => _isFinalizing = false);
    }
  }
}

/// Consumer-facing confirmation shown only after canonical B02 finalization
/// succeeds. The durable summary remains the source of truth; this surface
/// simply makes the successful handoff back to Training unmistakable.
class B02WorkoutCompletionSuccess extends StatelessWidget {
  const B02WorkoutCompletionSuccess({
    super.key,
    required this.launch,
    required this.onDone,
  });

  final B02StrengthExecutionLaunch launch;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final exercises = launch.state.performedExercises;
    final setCount = exercises.fold<int>(
      0,
      (count, exercise) => count + exercise.sets.length,
    );
    final knownReps = exercises
        .expand((exercise) => exercise.sets)
        .where((set) => set.actualReps != null)
        .fold<int>(0, (sum, set) => sum + set.actualReps!);
    final volume = exercises
        .expand((exercise) => exercise.sets)
        .where(
          (set) =>
              set.actualLoadKg != null &&
              set.actualReps != null &&
              set.actualLoadBasis != B02LoadBasis.bodyweight,
        )
        .fold<double>(
          0,
          (sum, set) => sum + set.actualLoadKg! * set.actualReps!,
        );
    final hasVolume = exercises
        .expand((exercise) => exercise.sets)
        .any(
          (set) =>
              set.actualLoadKg != null &&
              set.actualReps != null &&
              set.actualLoadBasis != B02LoadBasis.bodyweight,
        );
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    'Workout complete',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    launch.state.routineName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your workout is saved to history.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final metrics = <Widget>[
                        if (launch.state.elapsedSeconds > 0)
                          R07CMetricTile(
                            label: 'Duration',
                            value: formatB02WorkoutDuration(
                              launch.state.elapsedSeconds,
                            ),
                          ),
                        R07CMetricTile(
                          label: 'Exercises',
                          value: '${exercises.length}',
                        ),
                        R07CMetricTile(
                          label: 'Sets',
                          value: '$setCount',
                        ),
                        if (knownReps > 0)
                          R07CMetricTile(
                            label: 'Reps',
                            value: '$knownReps',
                          ),
                        if (hasVolume)
                          R07CMetricTile(
                            label: 'External volume',
                            value: '${r07cFormatNumber(volume)} kg',
                          ),
                      ];
                      final width = (constraints.maxWidth - 8) / 2;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final metric in metrics)
                            SizedBox(width: width, child: metric),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onDone,
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String formatB02WorkoutDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  if (minutes == 0) return '$remainingSeconds sec';
  if (remainingSeconds == 0) return '$minutes min';
  return '$minutes min $remainingSeconds sec';
}

class _Body extends StatelessWidget {
  final B02StrengthExecutionLaunch launch;
  final B02StrengthExecutionUiState ui;
  final VoidCallback? onRetry;
  final VoidCallback? onFull;
  final VoidCallback? onPartial;
  final VoidCallback onBack;

  const _Body({
    required this.launch,
    required this.ui,
    required this.onRetry,
    required this.onFull,
    required this.onPartial,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    if (ui.status == B02StrengthExecutionStatus.failure ||
        ui.status == B02StrengthExecutionStatus.recovery) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44),
              const SizedBox(height: 12),
              Text(
                ui.errorMessage ?? 'Finalization needs recovery.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your workout is still saved as a draft. Try finishing again or return to the workout.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (onRetry != null)
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              TextButton(
                onPressed: onBack,
                child: const Text('Return to workout'),
              ),
            ],
          ),
        ),
      );
    }
    final performed = launch.state.performedExercises;
    final totalActual = performed
        .expand((exercise) => exercise.sets)
        .where((set) => set.actualReps != null)
        .fold<int>(0, (sum, set) => sum + set.actualReps!);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        B05Surface(
          tone: B05SurfaceTone.selected,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                launch.state.routineName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                launch.state.elapsedSeconds > 0
                    ? formatB02WorkoutDuration(launch.state.elapsedSeconds)
                    : 'Duration unavailable',
              ),
              if (totalActual > 0) ...[
                const SizedBox(height: 4),
                Text('$totalActual reps completed'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final group in launch.state.groups)
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_tree_outlined),
              title: Text(_groupLabel(group)),
              subtitle: Text(
                '${group.roundCount} ${group.roundCount == 1 ? 'round' : 'rounds'} · ${group.members.length} ${group.members.length == 1 ? 'exercise' : 'exercises'}',
              ),
            ),
          ),
        if (performed.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('No performed sets yet'),
              subtitle: Text('Log at least one set before finishing.'),
            ),
          ),
        for (final exercise in performed) _PerformedCard(exercise: exercise),
        const SizedBox(height: 8),
        const Text(
          'Your completed sets and any targets you chose are saved with this workout.',
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onFull, child: const Text('Complete workout')),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: onPartial,
          child: const Text('Finish partially…'),
        ),
      ],
    );
  }

  static String _groupLabel(B02ExerciseGroup group) {
    final type = switch (group.groupType) {
      B02GroupType.superset => 'Superset',
      B02GroupType.circuit => 'Circuit',
      B02GroupType.giantSet => 'Giant set',
    };
    return group.label?.trim().isNotEmpty == true ? group.label!.trim() : type;
  }
}

class _PerformedCard extends StatelessWidget {
  final B02PerformedExerciseDraft exercise;
  const _PerformedCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return B05Surface(
      tone: B05SurfaceTone.section,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  exercise.actualExerciseNameSnapshot,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(exercise.status),
            ],
          ),
          const SizedBox(height: 8),
          R07CPerformedSetList(sets: exercise.sets),
          const SizedBox(height: 6),
          Text(
            _targetSummary(exercise.sets),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _targetSummary(List<B02PerformedSet> sets) {
    final targets = sets
        .map(
          (set) => r07cFormatTarget(
            loadKg: set.targetLoadKg,
            loadBasis: set.targetLoadBasis,
            minReps: set.targetRepsMin,
            maxReps: set.targetRepsMax,
            rpe: set.targetRpe,
          ),
        )
        .whereType<String>()
        .toList(growable: false);
    return targets.isEmpty
        ? 'Target not recorded'
        : 'target reps: ${targets.join(' · ')}';
  }
}
