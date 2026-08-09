import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/responsive_form_primitives.dart';
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
          const Text('No exercises are available yet.'),
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
    final workingSetCount = _workingSetCount(launch.state, selected);
    final hasLoggedSet = _hasLoggedSet(launch.state, selected);
    final hasOpenRest = _hasOpenRest(launch.state, selected);
    final exerciseComplete = workingSetCount >= selected.plannedSets;
    final currentSet = exerciseComplete
        ? selected.plannedSets
        : workingSetCount + 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        const _OfflineBanner(),
        const SizedBox(height: 12),
        Text(
          'Current exercise',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          selected.exerciseNameSnapshot,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (selected.groupType != null) ...[
          const SizedBox(height: 4),
          Text(_groupContext(selected)),
        ],
        const SizedBox(height: 4),
        Semantics(
          label: 'Current set',
          value: exerciseComplete
              ? 'Exercise complete'
              : 'Set $currentSet of ${selected.plannedSets}',
          child: Text(
            exerciseComplete
                ? 'Exercise complete'
                : 'Set $currentSet of ${selected.plannedSets}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: selected.id,
          decoration: const InputDecoration(labelText: 'Switch exercise'),
          items: [
            for (final slot in slots)
              DropdownMenuItem(
                value: slot.id,
                child: Text(
                  '${_groupContext(slot)} · ${slot.exerciseNameSnapshot}',
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
          currentSet: currentSet,
          exerciseComplete: exerciseComplete,
          onOverride: ui.isBusy
              ? null
              : () => _overrideTarget(provider, selected),
        ),
        const SizedBox(height: 12),
        IndiFitResponsiveFieldGroup(
          spacing: 10,
          children: [
            TextFormField(
              key: ValueKey('load-${selected.id}'),
              initialValue: _loads[selected.id],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Load (kg)'),
              onChanged: (value) => _loads[selected.id] = value,
            ),
            TextFormField(
              key: ValueKey('reps-${selected.id}'),
              initialValue: _reps[selected.id],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Reps'),
              onChanged: (value) => _reps[selected.id] = value,
            ),
            TextFormField(
              key: ValueKey('rpe-${selected.id}'),
              initialValue: _rpes[selected.id],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'RPE (optional)'),
              onChanged: (value) => _rpes[selected.id] = value,
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
              title: Text('Warm-up unavailable'),
              subtitle: Text(
                'A warm-up will appear when a valid working target is available.',
              ),
            ),
          ),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label: _warmup
              ? 'Log warm-up set'
              : exerciseComplete
              ? 'Exercise complete'
              : 'Complete set $currentSet of ${selected.plannedSets}',
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  ui.isBusy ||
                      !selected.hasCanonicalExercise ||
                      (!_warmup && exerciseComplete)
                  ? null
                  : () => _record(provider, selected),
              child: Text(
                _warmup
                    ? 'Log warm-up set'
                    : exerciseComplete
                    ? 'Exercise complete'
                    : 'Complete set',
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: ui.isBusy
                ? null
                : () => ref.read(provider.notifier).skipSlot(selected),
            icon: const Icon(Icons.skip_next_rounded),
            label: const Text('Skip exercise'),
          ),
        ),
        if (hasLoggedSet || hasOpenRest) ...[
          _RestCard(
            slot: selected,
            state: launch.state,
            onBegin: ui.isBusy
                ? null
                : () => ref.read(provider.notifier).beginRest(selected),
            onCustom: ui.isBusy
                ? null
                : (seconds) => ref
                      .read(provider.notifier)
                      .beginRest(selected, selectedSeconds: seconds),
            onExtend: ui.isBusy
                ? null
                : (periodId) =>
                      ref.read(provider.notifier).extendRest(periodId),
            onSkip: ui.isBusy
                ? null
                : (periodId) => ref.read(provider.notifier).skipRest(periodId),
            onElapsed: (periodId) =>
                ref.read(provider.notifier).completeRest(periodId),
          ),
          const SizedBox(height: 12),
        ],
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
        const SizedBox(height: 12),
        _GroupProgressCard(launch: launch, slots: slots),
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

  int _workingSetCount(
    B02ExecutionDraftState state,
    B02StrengthExecutionSlot slot,
  ) {
    return state.performedExercises
        .where(
          (exercise) =>
              exercise.sourceExercisePrescriptionId == slot.prescriptionId &&
              exercise.groupRoundOrdinal == slot.roundOrdinal &&
              exercise.groupMemberOrdinal == slot.memberOrdinal,
        )
        .expand((exercise) => exercise.sets)
        .where((set) => set.role == B02SetRole.working)
        .length;
  }

  bool _hasLoggedSet(
    B02ExecutionDraftState state,
    B02StrengthExecutionSlot slot,
  ) {
    return state.performedExercises.any(
      (exercise) =>
          exercise.sourceExercisePrescriptionId == slot.prescriptionId &&
          exercise.groupRoundOrdinal == slot.roundOrdinal &&
          exercise.groupMemberOrdinal == slot.memberOrdinal &&
          exercise.sets.isNotEmpty,
    );
  }

  bool _hasOpenRest(
    B02ExecutionDraftState state,
    B02StrengthExecutionSlot slot,
  ) {
    return state.restPeriods.any(
      (period) =>
          period.endedAtUtc == null && b02RestPeriodBelongsToSlot(period, slot),
    );
  }

  static String _groupContext(B02StrengthExecutionSlot slot) {
    if (slot.groupType == null) return 'Standalone exercise';
    final type = switch (slot.groupType!) {
      B02GroupType.superset => 'Superset',
      B02GroupType.circuit => 'Circuit',
      B02GroupType.giantSet => 'Giant set',
    };
    final name = slot.groupLabel?.trim().isNotEmpty == true
        ? slot.groupLabel!.trim()
        : type;
    return '$name · Round ${(slot.roundOrdinal ?? 0) + 1} · Exercise ${(slot.memberOrdinal ?? 0) + 1}';
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
              'Workout progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text('$completed of ${slots.length} exercises complete'),
            const SizedBox(height: 10),
            for (final group in launch.state.groups) Text(_groupLabel(group)),
          ],
        ),
      ),
    );
  }

  String _groupLabel(B02ExerciseGroup group) {
    final name =
        group.label ??
        switch (group.groupType) {
          B02GroupType.superset => 'Superset',
          B02GroupType.circuit => 'Circuit',
          B02GroupType.giantSet => 'Giant set',
        };
    return '$name · ${group.roundCount} ${group.roundCount == 1 ? 'round' : 'rounds'} · ${group.members.length} ${group.members.length == 1 ? 'exercise' : 'exercises'}';
  }
}

class _TargetCard extends StatelessWidget {
  final B02StrengthExecutionSlot slot;
  final B02ExecutionDraftState state;
  final int currentSet;
  final bool exerciseComplete;
  final VoidCallback? onOverride;

  const _TargetCard({
    required this.slot,
    required this.state,
    required this.currentSet,
    required this.exerciseComplete,
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
        ? 'No target yet'
        : slot.targetRepsMin == slot.targetRepsMax
        ? '${slot.targetRepsMin}'
        : '${slot.targetRepsMin}-${slot.targetRepsMax}';
    final recommendation = state.targetRecommendations[slot.id];
    final hasSuggestedTarget = recommendation?.recommendedLoadKg != null;
    final load = slot.targetLoadKg == null ? null : '${slot.targetLoadKg} kg';
    final targetLabel = load == null ? target : '$load × $target';
    final performedLabel = actual == 0
        ? 'Not logged yet'
        : '$actual ${actual == 1 ? 'rep' : 'reps'}';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.flag_outlined),
        title: Text(hasSuggestedTarget ? 'Suggested target' : 'Planned target'),
        subtitle: Text(
          '$targetLabel · ${exerciseComplete ? 'Exercise complete' : 'Set $currentSet of ${slot.plannedSets}'}\nPerformed: $performedLabel\n${hasSuggestedTarget ? 'Suggested from your recent working sets. Change it if today needs a different target.' : 'Log what you complete; a suggestion appears when enough history is available.'}',
        ),
        trailing: !hasSuggestedTarget
            ? null
            : TextButton(onPressed: onOverride, child: const Text('Change')),
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
  Widget build(BuildContext context) {
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
    final subtitle = recommendation.proposals.isEmpty
        ? 'No working target is available yet.'
        : skipped
        ? 'You can use the suggested ramp sets at any time.'
        : offered
        ? 'Prepare with a few lighter sets before you begin.'
        : 'Your selected ramp sets are saved with this workout.';
    return Card(
      child: Padding(
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
                    .map(
                      (proposal) =>
                          '${proposal.loadKg == null ? 'Bodyweight' : '${proposal.loadKg} kg'} × ${proposal.reps}',
                    )
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

class _RestCard extends StatefulWidget {
  final B02StrengthExecutionSlot slot;
  final B02ExecutionDraftState state;
  final VoidCallback? onBegin;
  final ValueChanged<int>? onCustom;
  final ValueChanged<String>? onExtend;
  final ValueChanged<String>? onSkip;
  final ValueChanged<String> onElapsed;

  const _RestCard({
    required this.slot,
    required this.state,
    required this.onBegin,
    required this.onCustom,
    required this.onExtend,
    required this.onSkip,
    required this.onElapsed,
  });

  @override
  State<_RestCard> createState() => _RestCardState();
}

class _RestCardState extends State<_RestCard> {
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
  void didUpdateWidget(covariant _RestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    return Card(
      child: ListTile(
        leading: const Icon(Icons.timer_outlined),
        title: Text(
          period == null ? 'Rest' : 'Rest · ${_remainingLabel(period)}',
        ),
        subtitle: Text(
          widget.slot.groupType == null
              ? 'Take a breather before your next set.'
              : 'Rest before the next exercise in this group.',
        ),
        trailing: period == null
            ? Wrap(
                spacing: 2,
                children: [
                  TextButton(
                    onPressed: widget.onBegin,
                    child: const Text('Start'),
                  ),
                  IconButton(
                    tooltip: 'Choose rest duration',
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
                    icon: const Icon(Icons.tune),
                  ),
                ],
              )
            : Wrap(
                spacing: 2,
                children: [
                  IconButton(
                    tooltip: 'Add 30 seconds',
                    onPressed: widget.onExtend == null
                        ? null
                        : () => widget.onExtend?.call(period.id),
                    icon: const Icon(Icons.add_alarm_outlined),
                  ),
                  IconButton(
                    tooltip: 'Skip rest',
                    onPressed: widget.onSkip == null
                        ? null
                        : () => widget.onSkip?.call(period.id),
                    icon: const Icon(Icons.skip_next_outlined),
                  ),
                ],
              ),
      ),
    );
  }

  String _remainingLabel(B02RestPeriod period) {
    final remaining = _remainingSeconds(period, _now);
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  int _remainingSeconds(B02RestPeriod period, DateTime now) {
    final total = period.selectedSeconds ?? period.recommendedSeconds ?? 0;
    final elapsed = now.difference(period.startedAtUtc).inSeconds;
    return (total - elapsed).clamp(0, total);
  }

  B02RestPeriod? _openPeriod(_RestCard value) {
    final open = value.state.restPeriods
        .where(
          (period) =>
              period.endedAtUtc == null &&
              b02RestPeriodBelongsToSlot(period, value.slot),
        )
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
        if (_remainingSeconds(open, now) == 0) {
          _ticker?.cancel();
          _ticker = null;
          if (!_finishingElapsedRest) {
            _finishingElapsedRest = true;
            widget.onElapsed(open.id);
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
