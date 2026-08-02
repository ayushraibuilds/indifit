import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/b02_strength_execution_repository.dart';
import '../../data/repositories/calendar_repository.dart';
import 'b02_strength_execution_controller.dart';

/// Final review for B02 strength execution. Full and partial completion are
/// explicit actions; a failed finalization keeps the linked draft visible.
class B02StrengthSummaryScreen extends ConsumerWidget {
  final B02StrengthExecutionLaunch launch;

  const B02StrengthSummaryScreen({super.key, required this.launch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = b02StrengthExecutionScreenControllerProvider(launch);
    final ui = ref.watch(provider);
    final current = ui.launch ?? launch;
    return Scaffold(
      appBar: AppBar(title: const Text('Review workout')),
      body: _Body(
        launch: current,
        ui: ui,
        onRetry: ui.launch == null
            ? null
            : () => ref.read(provider.notifier).loadSlots(),
        onFull: ui.isBusy
            ? null
            : () => _complete(context, ref, provider, CompletionKind.full),
        onPartial: ui.isBusy
            ? null
            : () => _confirmPartial(context, ref, provider),
        onBack: () => context.pop(),
      ),
    );
  }

  Future<void> _confirmPartial(
    BuildContext context,
    WidgetRef ref,
    dynamic provider,
  ) async {
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
    await _complete(
      context,
      ref,
      provider,
      CompletionKind.partial,
      reason: reason,
    );
  }

  Future<void> _complete(
    BuildContext context,
    WidgetRef ref,
    dynamic provider,
    CompletionKind kind, {
    String? reason,
  }) async {
    await ref
        .read(provider.notifier)
        .finalize(
          commandId: const Uuid().v4(),
          completionKind: kind,
          reason: reason?.isEmpty == true ? null : reason,
        );
    if (!context.mounted) return;
    final next = ref.read(provider);
    if (next.status == B02StrengthExecutionStatus.ready &&
        next.launch == null) {
      context.go('/');
    }
  }
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
              const SizedBox(height: 16),
              if (onRetry != null)
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              TextButton(
                onPressed: onBack,
                child: const Text('Keep draft and go back'),
              ),
            ],
          ),
        ),
      );
    }
    final performed = launch.state.performedExercises;
    final totalActual = performed
        .expand((exercise) => exercise.sets)
        .fold<int>(0, (sum, set) => sum + (set.actualReps ?? 0));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        Text(
          launch.state.routineName,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text('${launch.state.elapsedSeconds}s · $totalActual actual reps'),
        const SizedBox(height: 16),
        for (final group in launch.state.groups)
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_tree_outlined),
              title: Text(
                '${group.label ?? 'Group ${group.ordinal + 1}'} · ${group.groupType.dbValue}',
              ),
              subtitle: Text(
                '${group.roundCount} round(s) · ${group.members.length} member(s) · explicit status retained',
              ),
            ),
          ),
        if (performed.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('No performed sets yet'),
              subtitle: Text(
                'Log at least one canonical set before finishing.',
              ),
            ),
          ),
        for (final exercise in performed) _PerformedCard(exercise: exercise),
        const SizedBox(height: 8),
        const Text(
          'Actual values are immutable history inputs. Targets and recommendations remain separate and are never silently changed.',
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
}

class _PerformedCard extends StatelessWidget {
  final B02PerformedExerciseDraft exercise;
  const _PerformedCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final actual = exercise.sets
        .map(
          (set) => '${set.actualLoadKg ?? '—'} kg × ${set.actualReps ?? '—'}',
        )
        .join(', ');
    final target = exercise.sets
        .map(
          (set) => set.targetRepsMin == null
              ? 'target unknown'
              : '${set.targetRepsMin}-${set.targetRepsMax} target reps',
        )
        .join(', ');
    return Card(
      child: ListTile(
        title: Text(exercise.actualExerciseNameSnapshot),
        subtitle: Text('$actual\n$target\nStatus: ${exercise.status}'),
        isThreeLine: true,
      ),
    );
  }
}
