import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/indifit_haptics.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/indi_fit_feedback.dart';
import '../../core/widgets/responsive_form_primitives.dart';
import '../../data/database/app_database.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/b02_strength_execution_repository.dart';
import 'b02_strength_execution_controller.dart';
import 'b02_workout_elapsed.dart';
import 'quick_workout_screen.dart';
import 'widgets/r07c_workout_presentation.dart';

/// B02's compact, offline-first player. All mutations go through the
/// successor controller; the widget only collects input and presents state.
class B02StrengthPlayerScreen extends ConsumerStatefulWidget {
  final B02StrengthExecutionLaunch launch;
  final DateTime Function()? nowUtc;

  const B02StrengthPlayerScreen({super.key, required this.launch, this.nowUtc});

  @override
  ConsumerState<B02StrengthPlayerScreen> createState() =>
      _B02StrengthPlayerScreenState();
}

class _B02StrengthPlayerScreenState
    extends ConsumerState<B02StrengthPlayerScreen>
    with WidgetsBindingObserver {
  final _reps = <String, String>{};
  final _loads = <String, String>{};
  final _rpes = <String, String>{};
  String? _selectedSlotId;
  final _substitutionIds = <String, String?>{};
  final _substitutionNames = <String, String?>{};
  bool _warmup = false;
  var _isSubmittingSet = false;
  var _isClosing = false;
  var _allowPop = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = b02StrengthExecutionScreenControllerProvider(
          widget.launch,
        );
        if (ref.read(provider).slots.isEmpty) {
          ref.read(provider.notifier).loadSlots();
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(
      b02StrengthExecutionScreenControllerProvider(widget.launch).notifier,
    );
    if (state == AppLifecycleState.resumed) {
      unawaited(controller.resumeElapsed());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(controller.pauseElapsed());
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = b02StrengthExecutionScreenControllerProvider(
      widget.launch,
    );
    final ui = ref.watch(provider);
    final launch = ui.launch ?? widget.launch;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _isClosing) return;
        unawaited(_closeWorkout(provider));
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close workout',
            onPressed: ui.isBusy ? null : () => _closeWorkout(provider),
            icon: const Icon(Icons.close_rounded),
          ),
          title: Text(launch.state.routineName),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Workout options',
              enabled: !ui.isBusy,
              onSelected: (value) {
                switch (value) {
                  case 'review':
                    unawaited(_openSummary(provider));
                  case 'discard':
                    _discard(provider);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'review', child: Text('Review workout')),
                PopupMenuItem(value: 'discard', child: Text('Discard draft')),
              ],
            ),
          ],
        ),
        body: _buildBody(context, provider, ui, launch),
      ),
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
      final hasPerformedSets = launch.state.performedExercises.any(
        (exercise) => exercise.sets.isNotEmpty,
      );
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('No exercises in this workout yet.'),
          const SizedBox(height: 8),
          const Text('Add an exercise to keep this draft ready for logging.'),
          const SizedBox(height: 16),
          if (launch.occurrenceId == null)
            FilledButton.icon(
              onPressed: ui.isBusy ? null : () => _openExercisePicker(provider),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add exercise'),
            ),
          if (hasPerformedSets)
            FilledButton.tonal(
              onPressed: ui.isBusy ? null : () => _openSummary(provider),
              child: const Text('Review and finish saved sets'),
            ),
          TextButton(
            onPressed: ui.isBusy ? null : () => _closeWorkout(provider),
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
    final hasOpenRest = _hasOpenRest(launch.state, selected);
    final isQuick = launch.occurrenceId == null;
    final exerciseComplete =
        !isQuick && workingSetCount >= selected.plannedSets;
    final currentSet = workingSetCount + 1;
    final performedSets = _performedSets(launch.state, selected);
    _loads.putIfAbsent(
      selected.id,
      () => selected.targetLoadKg?.toString() ?? '',
    );
    _reps.putIfAbsent(
      selected.id,
      () => selected.targetRepsMin?.toString() ?? '',
    );
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _R07CExecutionHeader(
          isQuick: isQuick,
          exerciseIndex: slots.indexOf(selected),
          exerciseCount: slots.length,
          currentSet: currentSet,
          plannedSets: selected.plannedSets,
          exerciseComplete: exerciseComplete,
          groupContext: selected.groupType == null
              ? null
              : _groupContext(selected),
          exerciseName: _actualExerciseName(launch.state, selected),
          elapsedState: launch.state,
          nowUtc: widget.nowUtc,
          onActions: ui.isBusy
              ? null
              : () => _showExerciseActions(provider, selected),
        ),
        const SizedBox(height: 12),
        _R07CExerciseStrip(
          slots: slots,
          state: launch.state,
          selectedId: selected.id,
          onSelected: ui.isBusy
              ? null
              : (value) => setState(() => _selectedSlotId = value),
        ),
        const SizedBox(height: 12),
        _R07CTargetContext(
          slot: selected,
          state: launch.state,
          onApply: ui.isBusy
              ? null
              : () => _applySuggestedTarget(launch.state, selected),
          onChange: ui.isBusy
              ? null
              : () => _overrideTarget(provider, selected),
        ),
        if (_hasUsefulTargetContext(launch.state, selected))
          const SizedBox(height: 12),
        if (hasOpenRest) ...[
          _buildRestCard(provider, ui, launch, selected),
          const SizedBox(height: 12),
          Text(
            'The next set is ready when you are.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ] else ...[
          B05Surface(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Log set $currentSet',
                  style: B05Typography.title(context),
                ),
                const SizedBox(height: 10),
                IndiFitResponsiveFieldGroup(
                  spacing: 10,
                  breakpoint: 350,
                  children: [
                    TextFormField(
                      key: ValueKey('load-${selected.id}'),
                      initialValue: _loads[selected.id],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: _loadLabel(selected.targetLoadBasis),
                      ),
                      onChanged: (value) => _loads[selected.id] = value,
                    ),
                    TextFormField(
                      key: ValueKey('reps-${selected.id}'),
                      initialValue: _reps[selected.id],
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: 'Reps'),
                      onChanged: (value) => _reps[selected.id] = value,
                      onEditingComplete: () =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      const Expanded(child: Text('More for this set')),
                      Text(
                        'RPE',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                  subtitle: Text(
                    _rpes[selected.id]?.isNotEmpty == true
                        ? 'RPE ${_rpes[selected.id]}'
                        : _warmup
                        ? 'Warm-up set'
                        : 'RPE and set type',
                  ),
                  children: [
                    _RpeSelector(
                      value: int.tryParse(_rpes[selected.id] ?? ''),
                      onChanged: (value) => setState(
                        () => _rpes[selected.id] = value?.toString() ?? '',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _warmup ? 'warmup' : 'working',
                      decoration: const InputDecoration(labelText: 'Set type'),
                      items: const [
                        DropdownMenuItem(
                          value: 'working',
                          child: Text('Working'),
                        ),
                        DropdownMenuItem(
                          value: 'warmup',
                          child: Text('Warm-up'),
                        ),
                      ],
                      onChanged: ui.isBusy
                          ? null
                          : (value) =>
                                setState(() => _warmup = value == 'warmup'),
                    ),
                    if (launch.state.warmupRecommendation != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _WarmupCard(
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
                              : () => _editWarmup(
                                  provider,
                                  launch.state.warmupRecommendation!,
                                ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: B05ActionButton(
              label: _warmup
                  ? 'Log warm-up set'
                  : exerciseComplete
                  ? 'Exercise complete'
                  : 'Log set',
              hint: _warmup ? 'Save this warm-up set' : 'Save this set',
              onPressed:
                  ui.isBusy ||
                      _isSubmittingSet ||
                      !selected.hasCanonicalExercise ||
                      (!_warmup && exerciseComplete)
                  ? null
                  : () => _record(provider, selected),
            ),
          ),
          if (performedSets.isNotEmpty) ...[
            const SizedBox(height: 12),
            R07CPerformedSetList(title: 'Logged sets', sets: performedSets),
          ],
          if (isQuick) ...[
            const SizedBox(height: 10),
            B05ActionButton(
              label: 'Add set',
              icon: Icons.add_rounded,
              emphasis: B05ActionEmphasis.secondary,
              onPressed: ui.isBusy ? null : () => _prepareExtraSet(selected),
            ),
            const SizedBox(height: 4),
            B05ActionButton(
              label: 'Add exercise',
              icon: Icons.playlist_add_rounded,
              emphasis: B05ActionEmphasis.secondary,
              onPressed: ui.isBusy ? null : () => _openExercisePicker(provider),
            ),
          ] else
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
        ],
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Form cues'),
          children: const [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Open exercise details for setup and technique guidance.',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _GroupProgressCard(launch: launch, slots: slots),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: B05ActionButton(
            label: isQuick ? 'Finish workout' : 'Review and finish',
            emphasis: B05ActionEmphasis.secondary,
            onPressed: ui.isBusy ? null : () => _openSummary(provider),
          ),
        ),
      ],
    );
  }

  String _actualExerciseName(
    B02ExecutionDraftState state,
    B02StrengthExecutionSlot slot,
  ) {
    final performed = state.performedExercises.where(
      (exercise) => exercise.id == 'performed:${slot.id}',
    );
    return performed.isEmpty
        ? (_substitutionNames[slot.id] ?? slot.exerciseNameSnapshot)
        : performed.first.actualExerciseNameSnapshot;
  }

  String _loadLabel(B02LoadBasis? basis) => switch (basis) {
    B02LoadBasis.perSide => 'Weight per side (kg)',
    B02LoadBasis.perImplement => 'Weight per implement (kg)',
    _ => 'Weight (kg)',
  };

  int _workingSetCount(
    B02ExecutionDraftState state,
    B02StrengthExecutionSlot slot,
  ) {
    return state.performedExercises
        .where(
          (exercise) =>
              exercise.id == 'performed:${slot.id}' ||
              (exercise.sourceExercisePrescriptionId == slot.prescriptionId &&
                  exercise.groupRoundOrdinal == slot.roundOrdinal &&
                  exercise.groupMemberOrdinal == slot.memberOrdinal),
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
          (exercise.id == 'performed:${slot.id}' ||
              (exercise.sourceExercisePrescriptionId == slot.prescriptionId &&
                  exercise.groupRoundOrdinal == slot.roundOrdinal &&
                  exercise.groupMemberOrdinal == slot.memberOrdinal)) &&
          exercise.sets.isNotEmpty,
    );
  }

  List<B02PerformedSet> _performedSets(
    B02ExecutionDraftState state,
    B02StrengthExecutionSlot slot,
  ) {
    return state.performedExercises
        .where(
          (exercise) =>
              exercise.id == 'performed:${slot.id}' ||
              (exercise.sourceExercisePrescriptionId == slot.prescriptionId &&
                  exercise.groupRoundOrdinal == slot.roundOrdinal &&
                  exercise.groupMemberOrdinal == slot.memberOrdinal),
        )
        .expand((exercise) => exercise.sets)
        .toList(growable: false);
  }

  bool _hasUsefulTargetContext(
    B02ExecutionDraftState state,
    B02StrengthExecutionSlot slot,
  ) {
    final recommendation = state.targetRecommendations[slot.id];
    final override = state.targetOverrides[slot.id];
    final usefulTarget = r07cHasUsefulTarget(
      loadKg:
          override?.loadKg ??
          recommendation?.recommendedLoadKg ??
          slot.targetLoadKg,
      loadBasis:
          override?.loadBasis ??
          recommendation?.loadBasis ??
          slot.targetLoadBasis,
      minReps:
          override?.targetRepsMin ??
          recommendation?.targetRepsMin ??
          slot.targetRepsMin,
      maxReps:
          override?.targetRepsMax ??
          recommendation?.targetRepsMax ??
          slot.targetRepsMax,
      rpe: override?.targetRpe ?? recommendation?.targetRpe ?? slot.targetRpe,
    );
    final last = r07cFormatLastPerformance(
      loadKg: _asDouble(recommendation?.completeness['previousLoadKg']),
      loadBasis: recommendation?.loadBasis,
      reps: _asInt(recommendation?.completeness['previousReps']),
      rpe: _asInt(recommendation?.completeness['previousRpe']),
    );
    return usefulTarget || last != null;
  }

  void _applySuggestedTarget(
    B02ExecutionDraftState state,
    B02StrengthExecutionSlot slot,
  ) {
    final recommendation = state.targetRecommendations[slot.id];
    if (recommendation == null) return;
    setState(() {
      _loads[slot.id] = recommendation.recommendedLoadKg?.toString() ?? '';
      _reps[slot.id] = recommendation.targetRepsMin?.toString() ?? '';
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  static double? _asDouble(Object? value) => switch (value) {
    num number => number.toDouble(),
    _ => null,
  };

  static int? _asInt(Object? value) => switch (value) {
    int number => number,
    num number => number.toInt(),
    _ => null,
  };

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

  Widget _buildRestCard(
    dynamic provider,
    B02StrengthExecutionUiState ui,
    B02StrengthExecutionLaunch launch,
    B02StrengthExecutionSlot selected,
  ) => _RestCard(
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
              ref.read(provider.notifier).adjustRest(periodId, seconds: 15),
    onDecrease: ui.isBusy
        ? null
        : (periodId) =>
              ref.read(provider.notifier).adjustRest(periodId, seconds: -15),
    onSkip: ui.isBusy
        ? null
        : (periodId) => ref.read(provider.notifier).skipRest(periodId),
    onElapsed: (periodId) => ref.read(provider.notifier).completeRest(periodId),
  );

  Future<void> _record(dynamic provider, B02StrengthExecutionSlot slot) async {
    if (_isSubmittingSet) return;
    final reps = int.tryParse(_reps[slot.id] ?? '');
    if (reps == null || reps < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter positive actual repetitions.')),
      );
      return;
    }
    setState(() => _isSubmittingSet = true);
    try {
      final controller = ref.read(provider.notifier);
      await controller.recordSet(
        slot: slot,
        reps: reps,
        loadKg: double.tryParse(_loads[slot.id] ?? ''),
        actualLoadBasis: slot.targetLoadBasis,
        rpe: int.tryParse(_rpes[slot.id] ?? ''),
        role: _warmup ? B02SetRole.warmup : B02SetRole.working,
        actualExerciseId: _substitutionIds[slot.id],
        actualExerciseNameSnapshot: _substitutionNames[slot.id],
        substitutionReason: _substitutionIds[slot.id] == null
            ? null
            : 'User-selected substitution',
      );
      if (!mounted) return;
      final saved = ref.read(provider);
      if (saved.status != B02StrengthExecutionStatus.failure &&
          saved.status != B02StrengthExecutionStatus.recovery) {
        unawaited(IndiFitHaptics.confirmation());
        if (!_warmup) {
          await controller.beginRest(slot);
        }
        if (mounted && launchForProvider(provider)?.occurrenceId == null) {
          setState(() {
            _reps[slot.id] = slot.targetRepsMin?.toString() ?? '';
            _rpes[slot.id] = '';
            _warmup = false;
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmittingSet = false);
    }
  }

  B02StrengthExecutionLaunch? launchForProvider(dynamic provider) =>
      ref.read(provider).launch;

  void _prepareExtraSet(B02StrengthExecutionSlot slot) {
    setState(() {
      _reps[slot.id] = slot.targetRepsMin?.toString() ?? '';
      _rpes[slot.id] = '';
      _warmup = false;
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _openExercisePicker(dynamic provider) async {
    final exercise = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const QuickExercisePicker(),
    );
    if (exercise?.stableId == null || !mounted) return;
    await ref
        .read(provider.notifier)
        .addUnscheduledExercise(
          exerciseId: exercise!.stableId!,
          exerciseName: exercise.name,
        );
    if (!mounted) return;
    final slots = ref.read(provider).slots;
    if (slots.isNotEmpty) {
      setState(() => _selectedSlotId = slots.last.id);
    }
  }

  Future<void> _showExerciseActions(
    dynamic provider,
    B02StrengthExecutionSlot slot,
  ) async {
    final isQuick = launchForProvider(provider)?.occurrenceId == null;
    final hasLoggedSets = _hasLoggedSet(
      launchForProvider(provider)?.state ?? widget.launch.state,
      slot,
    );
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              title: Text(slot.exerciseNameSnapshot),
              subtitle: Text(
                isQuick ? 'Quick Workout exercise' : 'Planned exercise',
              ),
            ),
            if (isQuick)
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: const Text('Add exercise'),
                onTap: () => Navigator.pop(sheetContext, 'add'),
              ),
            if (isQuick)
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('Remove exercise'),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
            if (!isQuick && !hasLoggedSets)
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded),
                title: const Text('Substitute exercise'),
                onTap: () => Navigator.pop(sheetContext, 'substitute'),
              ),
            if (!isQuick && hasLoggedSets)
              const ListTile(
                leading: Icon(Icons.lock_outline_rounded),
                title: Text('Substitution locked'),
                subtitle: Text(
                  'A different exercise cannot replace sets already logged.',
                ),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'add') {
      await _openExercisePicker(provider);
      return;
    }
    if (action == 'remove') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Remove exercise?'),
          content: Text(
            hasLoggedSets
                ? 'Remove ${slot.exerciseNameSnapshot} from the active list? Its logged sets will stay in the workout and remain available to finish.'
                : 'Remove ${slot.exerciseNameSnapshot} from this workout?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        await ref.read(provider.notifier).removeUnscheduledExercise(slot);
        if (mounted) setState(() => _selectedSlotId = null);
      }
      return;
    }
    if (action == 'substitute') {
      final exercise = await showModalBottomSheet<Exercise>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const QuickExercisePicker(),
      );
      if (exercise?.stableId == null || !mounted) return;
      setState(() {
        _substitutionIds[slot.id] = exercise!.stableId;
        _substitutionNames[slot.id] = exercise.name;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        indiFitSuccessSnackBar('Substitution ready for the next set'),
      );
    }
  }

  Future<void> _openSummary(dynamic provider) async {
    final controller = ref.read(provider.notifier);
    await controller.pauseElapsed();
    if (!mounted) return;
    final launch = ref.read(provider).launch;
    if (launch == null) return;
    await context.push('/b02-strength-summary', extra: {'launch': launch});
    if (mounted) unawaited(controller.resumeElapsed());
  }

  Future<void> _closeWorkout(dynamic provider) async {
    if (_isClosing) return;
    _isClosing = true;
    try {
      final close = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Save and close workout?'),
          content: const Text(
            'Your sets and elapsed workout time will be saved so you can resume later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep training'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save and close'),
            ),
          ],
        ),
      );
      if (close != true || !mounted) return;
      final paused = await ref.read(provider.notifier).pauseElapsed();
      if (!paused || !mounted) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop();
      });
    } finally {
      if (!_allowPop) _isClosing = false;
    }
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

class _R07CExecutionHeader extends StatelessWidget {
  const _R07CExecutionHeader({
    required this.isQuick,
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

  final bool isQuick;
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
    final position = isQuick
        ? 'Quick workout'
        : 'Exercise ${exerciseIndex + 1} of $exerciseCount';
    final status =
        groupContext ??
        (exerciseComplete
            ? 'Exercise complete'
            : 'Set $currentSet${isQuick ? '' : ' of $plannedSets'}');
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
                    child: Text(
                      position.toUpperCase(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.action,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w700,
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

class _R07CExerciseStrip extends StatelessWidget {
  const _R07CExerciseStrip({
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
            _exerciseChip(context, slots[index]),
          ],
        ],
      ),
    );
  }

  Widget _exerciseChip(BuildContext context, B02StrengthExecutionSlot slot) {
    final selected = slot.id == selectedId;
    final complete = state.performedExercises.any(
      (exercise) =>
          (exercise.id == 'performed:${slot.id}' ||
              exercise.sourceExercisePrescriptionId == slot.prescriptionId) &&
          exercise.status == 'completed',
    );
    final label = slot.exerciseNameSnapshot.trim().isEmpty
        ? 'Exercise'
        : slot.exerciseNameSnapshot;
    return Semantics(
      button: true,
      selected: selected,
      label: '${complete ? 'Completed ' : ''}$label',
      onTap: onSelected == null ? null : () => onSelected!(slot.id),
      child: ChoiceChip(
        selected: selected,
        onSelected: onSelected == null ? null : (_) => onSelected!(slot.id),
        avatar: complete ? const Icon(Icons.check_rounded, size: 16) : null,
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(label, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _R07CTargetContext extends StatelessWidget {
  final B02StrengthExecutionSlot slot;
  final B02ExecutionDraftState state;
  final VoidCallback? onApply;
  final VoidCallback? onChange;

  const _R07CTargetContext({
    required this.slot,
    required this.state,
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
    final previousLoad = _asDouble(
      recommendation?.completeness['previousLoadKg'],
    );
    final previousReps = _asInt(recommendation?.completeness['previousReps']);
    final previousRpe = _asInt(recommendation?.completeness['previousRpe']);
    final last = r07cFormatLastPerformance(
      loadKg: previousLoad,
      loadBasis: recommendation?.loadBasis,
      reps: previousReps,
      rpe: previousRpe,
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

  static double? _asDouble(Object? value) => switch (value) {
    num number => number.toDouble(),
    _ => null,
  };

  static int? _asInt(Object? value) => switch (value) {
    int number => number,
    num number => number.toInt(),
    _ => null,
  };
}

class _RpeSelector extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const _RpeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    isExpanded: true,
    initialValue: value,
    decoration: const InputDecoration(labelText: 'RPE'),
    items: [
      const DropdownMenuItem<int>(value: null, child: Text('RPE')),
      for (var effort = 1; effort <= 10; effort++)
        DropdownMenuItem(value: effort, child: Text('$effort')),
    ],
    onChanged: onChanged,
  );
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

class _RestCard extends StatefulWidget {
  final B02StrengthExecutionSlot slot;
  final B02ExecutionDraftState state;
  final VoidCallback? onBegin;
  final ValueChanged<int>? onCustom;
  final ValueChanged<String>? onExtend;
  final ValueChanged<String>? onDecrease;
  final ValueChanged<String>? onSkip;
  final Future<bool> Function(String) onElapsed;

  const _RestCard({
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
    final remaining = period == null ? null : _remainingLabel(period);
    return Card(
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
                child: Text(
                  remaining!,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              const SizedBox(height: 4),
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
                  OutlinedButton(
                    onPressed: widget.onDecrease == null
                        ? null
                        : () {
                            unawaited(IndiFitHaptics.selection());
                            widget.onDecrease?.call(period.id);
                          },
                    child: const Text('−15 sec'),
                  ),
                  OutlinedButton(
                    onPressed: widget.onExtend == null
                        ? null
                        : () {
                            unawaited(IndiFitHaptics.selection());
                            widget.onExtend?.call(period.id);
                          },
                    child: const Text('+15 sec'),
                  ),
                  TextButton(
                    onPressed: widget.onSkip == null
                        ? null
                        : () {
                            unawaited(IndiFitHaptics.selection());
                            widget.onSkip?.call(period.id);
                          },
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ],
          ],
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
        if (b02RestRemainingSeconds(open, now) == 0) {
          _ticker?.cancel();
          _ticker = null;
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
      }
    } catch (_) {
      // A failed durable completion must not create tactile success feedback.
    }
  }
}

@visibleForTesting
int b02RestRemainingSeconds(B02RestPeriod period, DateTime now) {
  final total = period.selectedSeconds ?? period.recommendedSeconds ?? 0;
  final elapsed = now.toUtc().difference(period.startedAtUtc).inSeconds;
  return (total - elapsed).clamp(0, total);
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
