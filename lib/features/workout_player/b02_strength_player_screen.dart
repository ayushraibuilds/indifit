import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/b02_strength_execution_repository.dart';
import 'b02_strength_execution_controller.dart';

/// B02's compact, offline-first player. All mutations go through the
/// successor controller; the widget only collects input and presents state.
class B02StrengthPlayerScreen extends ConsumerStatefulWidget {
  final B02StrengthExecutionLaunch launch;

  const B02StrengthPlayerScreen({super.key, required this.launch});

  @override
  ConsumerState<B02StrengthPlayerScreen> createState() =>
      _B02StrengthPlayerScreenState();
}

class _B02StrengthPlayerScreenState
    extends ConsumerState<B02StrengthPlayerScreen> {
  final _reps = <String, String>{};
  final _loads = <String, String>{};
  final _rpes = <String, String>{};
  String? _selectedSlotId;
  bool _warmup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(
              b02StrengthExecutionScreenControllerProvider(
                widget.launch,
              ).notifier,
            )
            .loadSlots();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = b02StrengthExecutionScreenControllerProvider(
      widget.launch,
    );
    final ui = ref.watch(provider);
    final launch = ui.launch ?? widget.launch;
    return Scaffold(
      appBar: AppBar(
        title: Text(launch.state.routineName),
        actions: [
          IconButton(
            tooltip: 'Discard draft',
            onPressed: ui.isBusy ? null : () => _discard(provider),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _buildBody(context, provider, ui, launch),
    );
  }

  Widget _buildBody(
    BuildContext context,
    dynamic provider,
    B02StrengthExecutionUiState ui,
    B02StrengthExecutionLaunch launch,
  ) {
    if (ui.status == B02StrengthExecutionStatus.loading && ui.launch == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (ui.status == B02StrengthExecutionStatus.failure ||
        ui.status == B02StrengthExecutionStatus.recovery) {
      return _ErrorState(
        message: ui.errorMessage ?? 'The draft needs recovery.',
        canRetry: ui.launch != null,
        onRetry: ui.launch == null
            ? null
            : () => ref.read(provider.notifier).loadSlots(),
        onClose: () => context.pop(),
      );
    }
    final slots = ui.slots;
    if (slots.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _OfflineBanner(),
          const SizedBox(height: 16),
          const Text('No exercise slots are available yet.'),
          const SizedBox(height: 8),
          const Text(
            'The frozen draft is safe. Recover it after the exercise catalog is available, or finish through the retained B01 route.',
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.pop(),
            child: const Text('Back'),
          ),
        ],
      );
    }
    final selected = slots.firstWhere(
      (slot) => slot.id == (_selectedSlotId ?? slots.first.id),
      orElse: () => slots.first,
    );
    _selectedSlotId ??= selected.id;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        const _OfflineBanner(),
        const SizedBox(height: 12),
        _GroupProgressCard(launch: launch, slots: slots),
        const SizedBox(height: 12),
        if (launch.state.warmupRecommendation != null)
          _WarmupCard(
            recommendation: launch.state.warmupRecommendation!,
            onAccept: ui.isBusy
                ? null
                : () => ref
                      .read(provider.notifier)
                      .chooseWarmup(B02WarmupDecision.accepted),
            onSkip: ui.isBusy
                ? null
                : () => ref
                      .read(provider.notifier)
                      .chooseWarmup(B02WarmupDecision.skipped),
            onEdit: ui.isBusy
                ? null
                : () =>
                      _editWarmup(provider, launch.state.warmupRecommendation!),
          ),
        if (launch.state.warmupRecommendation == null)
          const Card(
            child: ListTile(
              leading: Icon(Icons.whatshot_outlined),
              title: Text('Warm-up recommendation'),
              subtitle: Text(
                'No preference is stored. Choose a warm-up when a valid target is available.',
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text('Current slot', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: selected.id,
          decoration: const InputDecoration(labelText: 'Group member'),
          items: [
            for (final slot in slots)
              DropdownMenuItem(
                value: slot.id,
                child: Text(
                  '${slot.groupDescription} · round ${(slot.roundOrdinal ?? 0) + 1} · member ${(slot.memberOrdinal ?? 0) + 1} · ${slot.exerciseNameSnapshot}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: ui.isBusy
              ? null
              : (value) => setState(() => _selectedSlotId = value),
        ),
        const SizedBox(height: 12),
        _TargetCard(
          slot: selected,
          state: launch.state,
          onOverride: ui.isBusy
              ? null
              : () => _overrideTarget(provider, selected),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: ValueKey('load-${selected.id}'),
                initialValue: _loads[selected.id],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Actual load (kg)',
                ),
                onChanged: (value) => _loads[selected.id] = value,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                key: ValueKey('reps-${selected.id}'),
                initialValue: _reps[selected.id],
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Actual reps'),
                onChanged: (value) => _reps[selected.id] = value,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                key: ValueKey('rpe-${selected.id}'),
                initialValue: _rpes[selected.id],
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'RPE'),
                onChanged: (value) => _rpes[selected.id] = value,
              ),
            ),
          ],
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Log as warm-up'),
          value: _warmup,
          onChanged: ui.isBusy
              ? null
              : (value) => setState(() => _warmup = value),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Advanced technique details'),
          children: const [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Tempo, pauses, assistance, drop sets and rest-pause details are available here when you need them.',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _RestCard(
          slot: selected,
          state: launch.state,
          onBegin: () => ref.read(provider.notifier).beginRest(selected),
          onCustom: (seconds) => ref
              .read(provider.notifier)
              .beginRest(selected, selectedSeconds: seconds),
          onExtend: (periodId) =>
              ref.read(provider.notifier).extendRest(periodId),
          onSkip: (periodId) => ref.read(provider.notifier).skipRest(periodId),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: ui.isBusy
                    ? null
                    : () => ref.read(provider.notifier).skipSlot(selected),
                child: const Text('Skip slot'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: ui.isBusy || !selected.hasCanonicalExercise
                    ? null
                    : () => _record(provider, selected),
                child: Text(
                  ui.status == B02StrengthExecutionStatus.partial
                      ? 'Save set'
                      : 'Log set',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: ui.isBusy
              ? null
              : () => context.push(
                  '/b02-strength-summary',
                  extra: {'launch': ui.launch ?? launch},
                ),
          child: const Text('Review and finish'),
        ),
      ],
    );
  }

  Future<void> _record(dynamic provider, B02StrengthExecutionSlot slot) async {
    final reps = int.tryParse(_reps[slot.id] ?? '');
    if (reps == null || reps < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter positive actual repetitions.')),
      );
      return;
    }
    await ref
        .read(provider.notifier)
        .recordSet(
          slot: slot,
          reps: reps,
          loadKg: double.tryParse(_loads[slot.id] ?? ''),
          rpe: int.tryParse(_rpes[slot.id] ?? ''),
          role: _warmup ? B02SetRole.warmup : B02SetRole.working,
        );
  }

  Future<void> _overrideTarget(
    dynamic provider,
    B02StrengthExecutionSlot slot,
  ) async {
    final controller = TextEditingController(
      text: slot.targetLoadKg?.toString() ?? '',
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Override target load'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Load (kg)'),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => context.pop(double.tryParse(controller.text)),
            child: const Text('Use target'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value < 0 || !mounted) return;
    await ref.read(provider.notifier).overrideTarget(slot, loadKg: value);
  }

  Future<void> _editWarmup(
    dynamic provider,
    B02WarmupRecommendation recommendation,
  ) async {
    if (recommendation.proposals.isEmpty) {
      await ref.read(provider.notifier).chooseWarmup(B02WarmupDecision.skipped);
      return;
    }
    final first = recommendation.proposals.first;
    if (first.loadKg == null) {
      await ref.read(provider.notifier).editWarmup(recommendation.proposals);
      return;
    }
    final controller = TextEditingController(text: first.loadKg!.toString());
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit first warm-up load'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Load (kg)'),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => context.pop(double.tryParse(controller.text)),
            child: const Text('Save edit'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value <= 0 || !mounted) return;
    final edited = [
      for (var index = 0; index < recommendation.proposals.length; index++)
        index == 0
            ? B02WarmupSetProposal(
                ordinal: 0,
                percentageOfWorkingLoad:
                    recommendation.proposals.first.percentageOfWorkingLoad,
                loadKg: value,
                loadBasis: first.loadBasis,
                reps: first.reps,
              )
            : recommendation.proposals[index],
    ];
    await ref.read(provider.notifier).editWarmup(edited);
  }

  Future<void> _discard(dynamic provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard draft?'),
        content: const Text('This removes only the unfinished B02 draft.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(provider.notifier).discard();
      if (mounted) context.pop();
    }
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const ListTile(
      dense: true,
      leading: Icon(Icons.cloud_off_outlined),
      title: Text('Offline ready'),
      subtitle: Text('Every set is saved locally before you continue.'),
    ),
  );
}

class _GroupProgressCard extends StatelessWidget {
  final B02StrengthExecutionLaunch launch;
  final List<B02StrengthExecutionSlot> slots;

  const _GroupProgressCard({required this.launch, required this.slots});

  @override
  Widget build(BuildContext context) {
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
              'Group progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text('$completed of ${slots.length} slots complete'),
            const SizedBox(height: 10),
            for (final group in launch.state.groups)
              Text(
                '${group.label ?? 'Group ${group.ordinal + 1}'} · ${group.groupType.dbValue} · ${group.roundCount} round(s) · ${group.members.length} member(s)',
              ),
          ],
        ),
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  final B02StrengthExecutionSlot slot;
  final B02ExecutionDraftState state;
  final VoidCallback? onOverride;

  const _TargetCard({
    required this.slot,
    required this.state,
    required this.onOverride,
  });

  @override
  Widget build(BuildContext context) {
    final performed = state.performedExercises.where(
      (exercise) =>
          exercise.sourceExercisePrescriptionId == slot.prescriptionId &&
          exercise.groupRoundOrdinal == slot.roundOrdinal &&
          exercise.groupMemberOrdinal == slot.memberOrdinal,
    );
    final actual = performed
        .expand((exercise) => exercise.sets)
        .fold<int>(0, (sum, set) => sum + (set.actualReps ?? 0));
    final target = slot.targetRepsMin == null
        ? 'unknown'
        : slot.targetRepsMin == slot.targetRepsMax
        ? '${slot.targetRepsMin}'
        : '${slot.targetRepsMin}-${slot.targetRepsMax}';
    final recommendation = state.targetRecommendations[slot.id];
    final load = slot.targetLoadKg == null
        ? 'load unknown'
        : '${slot.targetLoadKg} kg ${slot.targetLoadBasis?.dbValue ?? ''}';
    final confidence = recommendation?.confidence.dbValue ?? 'unavailable';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.flag_outlined),
        title: Text('Target vs actual · $target reps · $load'),
        subtitle: Text(
          'Actual reps logged: $actual · ${recommendation == null ? 'no recommendation' : 'B02 ${recommendation.ruleVersion} · $confidence confidence'} · offered target stays separate from performed values.',
        ),
        trailing: recommendation == null
            ? null
            : TextButton(onPressed: onOverride, child: const Text('Override')),
      ),
    );
  }
}

class _WarmupCard extends StatelessWidget {
  final B02WarmupRecommendation recommendation;
  final VoidCallback? onAccept;
  final VoidCallback? onEdit;
  final VoidCallback? onSkip;

  const _WarmupCard({
    required this.recommendation,
    required this.onAccept,
    required this.onEdit,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.whatshot_outlined),
            title: Text('Warm-up guidance'),
            subtitle: Text(
              recommendation.proposals.isEmpty
                  ? 'No warm-up target is available; choose your own warm-up.'
                  : '${recommendation.proposals.length} proposed ramp set(s) · ${recommendation.selectedProposals.length} selected',
            ),
          ),
          if (recommendation.proposals.isNotEmpty)
            Text(
              recommendation.proposals
                  .map(
                    (proposal) =>
                        '${proposal.loadKg ?? 'bodyweight'} × ${proposal.reps}',
                  )
                  .join('  ·  '),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(onPressed: onAccept, child: const Text('Accept')),
              OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
              TextButton(onPressed: onSkip, child: const Text('Skip')),
            ],
          ),
        ],
      ),
    ),
  );
}

class _RestCard extends StatelessWidget {
  final B02StrengthExecutionSlot slot;
  final B02ExecutionDraftState state;
  final VoidCallback onBegin;
  final ValueChanged<int> onCustom;
  final ValueChanged<String> onExtend;
  final ValueChanged<String> onSkip;

  const _RestCard({
    required this.slot,
    required this.state,
    required this.onBegin,
    required this.onCustom,
    required this.onExtend,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final open = state.restPeriods
        .where(
          (period) =>
              period.endedAtUtc == null &&
              (period.performedExerciseGroupId == slot.groupId ||
                  period.id.startsWith('rest:${slot.id}:')),
        )
        .toList();
    final period = open.isEmpty ? null : open.last;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.timer_outlined),
        title: const Text('Rest timer'),
        subtitle: Text(
          slot.groupType == null
              ? 'Manual override · session-only · actual rest is recorded separately.'
              : 'Transition rest follows the ${slot.groupType!.dbValue} member order. Manual +30/skip is session-only.',
        ),
        trailing: period == null
            ? Wrap(
                spacing: 2,
                children: [
                  TextButton(onPressed: onBegin, child: const Text('Start')),
                  IconButton(
                    tooltip: 'Choose rest duration',
                    onPressed: () async {
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
                              onPressed: () =>
                                  context.pop(int.tryParse(controller.text)),
                              child: const Text('Start'),
                            ),
                          ],
                        ),
                      );
                      controller.dispose();
                      if (value != null && value >= 0) onCustom(value);
                    },
                    icon: const Icon(Icons.tune),
                  ),
                ],
              )
            : Wrap(
                spacing: 2,
                children: [
                  IconButton(
                    tooltip: 'Add 30 seconds',
                    onPressed: () => onExtend(period.id),
                    icon: const Icon(Icons.add_alarm_outlined),
                  ),
                  IconButton(
                    tooltip: 'Skip rest',
                    onPressed: () => onSkip(period.id),
                    icon: const Icon(Icons.skip_next_outlined),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final bool canRetry;
  final VoidCallback? onRetry;
  final VoidCallback onClose;

  const _ErrorState({
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
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry recovery'),
            ),
          TextButton(
            onPressed: onClose,
            child: const Text('Keep draft and go back'),
          ),
        ],
      ),
    ),
  );
}
