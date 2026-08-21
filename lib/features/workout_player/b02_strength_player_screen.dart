import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/providers.dart';
import '../../core/services/indifit_haptics.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/indi_fit_feedback.dart';
import '../../core/widgets/responsive_form_primitives.dart';
import '../../data/database/app_database.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/models/b02_previous_performance_models.dart';
import '../../data/models/b02_rich_set_helpers.dart';
import '../../data/repositories/b02_strength_execution_repository.dart';
import '../../data/services/b02_execution_progression.dart';
import '../exercise_picker/exercise_picker.dart';
import 'b02_previous_performance_integration.dart';
import 'b02_strength_execution_controller.dart';
import 'b02_workout_elapsed.dart';
import 'quick_workout_screen.dart';
import 'widgets/b02_compact_set_table.dart';
import 'widgets/b02_execution_advanced_controls.dart';
import 'widgets/b02_execution_semantics.dart';
import 'widgets/r07c_workout_presentation.dart';
import 'workout_execution_context.dart';
import 'workout_execution_route.dart';
import 'workout_execution_shell.dart';

/// B02's compact, offline-first player. All mutations go through the
/// successor controller; the widget only collects input and presents state.
class B02StrengthPlayerScreen extends ConsumerStatefulWidget {
  final B02StrengthExecutionLaunch launch;
  final WorkoutExecutionContext? executionContext;
  final DateTime Function()? nowUtc;

  const B02StrengthPlayerScreen({
    super.key,
    required this.launch,
    this.executionContext,
    this.nowUtc,
  });

  @override
  ConsumerState<B02StrengthPlayerScreen> createState() =>
      _B02StrengthPlayerScreenState();
}

class _B02StrengthPlayerScreenState
    extends ConsumerState<B02StrengthPlayerScreen>
    with WidgetsBindingObserver {
  final _repControllers = <String, TextEditingController>{};
  final _loadControllers = <String, TextEditingController>{};
  final _rpes = <String, String>{};
  final _pendingTechniques = <String, B02TechniqueFields>{};
  final _mutatingSetIds = <String>{};
  final _inputIdentities = <String, _B02InputIdentity>{};
  final _loggedSetCounts = <String, int>{};
  final _editedInputFields =
      <({String slotId, B02PreviousPerformanceInputField field})>{};
  late final B02PreviousPerformanceLookupCoordinator _previousLookup;
  String? _selectedSlotId;
  bool _warmup = false;
  var _isSubmittingSet = false;
  var _isClosing = false;
  var _allowPop = false;

  @override
  void initState() {
    super.initState();
    _previousLookup = B02PreviousPerformanceLookupCoordinator(
      resolve: (query) =>
          ref.read(b02PreviousPerformanceRepositoryProvider).resolve(query),
    );
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
    _previousLookup.invalidate();
    for (final controller in _repControllers.values) {
      controller.dispose();
    }
    for (final controller in _loadControllers.values) {
      controller.dispose();
    }
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
    final execution = _executionFor(launch);
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _isClosing) return;
        unawaited(_closeWorkout(provider));
      },
      child: _buildBody(context, provider, ui, launch, execution),
    );
  }

  Widget _buildBody(
    BuildContext context,
    dynamic provider,
    B02StrengthExecutionUiState ui,
    B02StrengthExecutionLaunch launch,
    WorkoutExecutionContext execution,
  ) {
    if (ui.status == B02StrengthExecutionStatus.loading && ui.launch == null) {
      return WorkoutExecutionShell(
        execution: execution,
        isBusy: true,
        contentOverride: const Center(child: CircularProgressIndicator()),
      );
    }
    if (ui.status == B02StrengthExecutionStatus.failure ||
        ui.status == B02StrengthExecutionStatus.recovery) {
      return WorkoutExecutionShell(
        execution: execution,
        isBusy: ui.isBusy,
        onClose: () => _closeWorkout(provider),
        onReview: () => _openSummary(provider),
        onDiscard: () => _discard(provider),
        contentOverride: _ErrorState(
          message:
              ui.errorMessage ??
              'This saved workout needs to be reopened before you can continue.',
          canRetry: ui.launch != null,
          onRetry: ui.launch == null
              ? null
              : () => ref.read(provider.notifier).loadSlots(),
          onClose: () => context.pop(),
        ),
      );
    }
    final slots = ui.slots;
    if (slots.isEmpty) {
      final hasPerformedSets = launch.state.performedExercises.any(
        (exercise) => exercise.sets.isNotEmpty,
      );
      final isQuick = execution is QuickWorkoutExecutionContext;
      return WorkoutExecutionShell(
        execution: execution,
        isBusy: ui.isBusy,
        onClose: () => _closeWorkout(provider),
        onReview: hasPerformedSets ? () => _openSummary(provider) : null,
        onDiscard: () => _discard(provider),
        contentOverride: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('No exercises in this workout yet.'),
            const SizedBox(height: 8),
            const Text(
              'Add an exercise to make this workout ready for logging.',
            ),
            const SizedBox(height: 16),
            if (isQuick)
              B05ActionButton(
                label: 'Add exercise',
                icon: Icons.add_rounded,
                onPressed: ui.isBusy
                    ? null
                    : () => _openExercisePicker(provider),
              ),
            if (hasPerformedSets)
              B05ActionButton(
                label: 'Review and finish saved sets',
                emphasis: B05ActionEmphasis.secondary,
                onPressed: ui.isBusy ? null : () => _openSummary(provider),
              ),
            B05ActionButton(
              label: 'Back',
              emphasis: B05ActionEmphasis.tertiary,
              onPressed: ui.isBusy ? null : () => _closeWorkout(provider),
            ),
          ],
        ),
      );
    }
    final cursorSlot = B02ExecutionProgression.cursorSlot(
      state: launch.state,
      slots: slots,
    );
    final preferredSlotId = _selectedSlotId ?? cursorSlot?.id;
    final selected = slots.firstWhere(
      (slot) => slot.id == (preferredSlotId ?? slots.first.id),
      orElse: () => slots.first,
    );
    _selectedSlotId ??= selected.id;
    final workingSetCount = _workingSetCount(launch.state, selected);
    final hasOpenRest = _hasOpenRest(launch.state, selected);
    final isQuick = execution is QuickWorkoutExecutionContext;
    final exerciseComplete =
        !isQuick && workingSetCount >= selected.plannedSets;
    final currentSet = workingSetCount + 1;
    final performedSets = _performedSets(launch.state, selected);
    final groupSafe = _groupIntegrity(launch.state, selected, slots).isValid;
    _loggedSetCounts[selected.id] = performedSets.length;
    final actualExerciseId = _actualExerciseId(launch.state, selected);
    _syncInputIdentity(selected, actualExerciseId);
    final pendingTechnique = _pendingTechniqueFor(selected, currentSet);
    final previousKey = _previousPerformanceKey(
      launch.state,
      selected,
      pendingTechnique,
    );
    if (previousKey != null) {
      _schedulePreviousPerformanceLookup(previousKey);
    }
    final previousPerformance = _previousLookup.activeKey == previousKey
        ? _previousLookup.activeResult
        : null;
    final currentTarget =
        _hasUsefulTargetContext(launch.state, selected, previousPerformance)
        ? _R07CTargetContext(
            slot: selected,
            state: launch.state,
            previousPerformance: previousPerformance,
            onApply: ui.isBusy
                ? null
                : () => _applySuggestedTarget(launch.state, selected),
            onChange: ui.isBusy
                ? null
                : () => _overrideTarget(provider, selected),
          )
        : null;
    final setLogging = hasOpenRest || !groupSafe
        ? null
        : _buildSetLoggingSlot(
            provider: provider,
            ui: ui,
            launch: launch,
            selected: selected,
            currentSet: currentSet,
            performedSets: performedSets,
            isPlannedMode: execution is PlannedWorkoutExecutionContext,
            pendingTechnique: pendingTechnique,
          );
    final primaryLabel = _warmup
        ? 'Log warm-up set'
        : exerciseComplete
        ? 'Exercise complete'
        : 'Log set';
    final primaryAction = hasOpenRest
        ? null
        : SizedBox(
            width: double.infinity,
            child: B05ActionButton(
              label: primaryLabel,
              hint: _warmup ? 'Save this warm-up set' : 'Save this set',
              onPressed:
                  ui.isBusy ||
                      _isSubmittingSet ||
                      !groupSafe ||
                      !selected.hasCanonicalExercise ||
                      (!_warmup && exerciseComplete)
                  ? null
                  : () => _record(provider, selected),
            ),
          );
    return WorkoutExecutionShell(
      execution: execution,
      isBusy: ui.isBusy,
      onClose: () => _closeWorkout(provider),
      onReview: () => _openSummary(provider),
      onDiscard: () => _discard(provider),
      workoutContextSlot: _R07CExecutionHeader(
        executionContext: execution,
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
        onActions: ui.isBusy || !groupSafe
            ? null
            : () => _showExerciseActions(provider, selected),
      ),
      exerciseProgressSlot: _R07CExerciseStrip(
        slots: slots,
        state: launch.state,
        selectedId: selected.id,
        onSelected: ui.isBusy
            ? null
            : (value) => setState(() => _selectedSlotId = value),
      ),
      currentExerciseSlot: currentTarget,
      restSlot: hasOpenRest
          ? _buildRestCard(provider, ui, launch, selected)
          : null,
      setLoggingSlot: setLogging,
      primaryActionSlot: primaryAction,
      primaryActionGap: 10,
      nextExerciseGap: hasOpenRest
          ? 12
          : isQuick
          ? 10
          : 0,
      nextExerciseSlot: _buildNextExerciseSlot(
        context: context,
        provider: provider,
        ui: ui,
        launch: launch,
        selected: selected,
        slots: slots,
        isQuick: isQuick,
        hasOpenRest: hasOpenRest,
        groupSafe: groupSafe,
      ),
      completionSlot: SizedBox(
        width: double.infinity,
        child: B05ActionButton(
          label: isQuick ? 'Finish workout' : 'Review and finish',
          emphasis: B05ActionEmphasis.secondary,
          onPressed: ui.isBusy ? null : () => _openSummary(provider),
        ),
      ),
    );
  }

  Widget _buildSetLoggingSlot({
    required dynamic provider,
    required B02StrengthExecutionUiState ui,
    required B02StrengthExecutionLaunch launch,
    required B02StrengthExecutionSlot selected,
    required int currentSet,
    required List<B02PerformedSet> performedSets,
    required bool isPlannedMode,
    required B02TechniqueFields pendingTechnique,
  }) {
    final rpe = int.tryParse(_rpes[selected.id] ?? '');
    final techniqueKey = _pendingTechniqueKey(
      selected,
      currentSet,
      isWarmup: _warmup,
    );
    final prescribedTechnique = _warmup
        ? null
        : selected.techniqueForSet(currentSet - 1);
    return B02CompactSetTable(
      slot: selected,
      loggedSets: performedSets,
      isPlannedMode: isPlannedMode,
      isBusy: ui.isBusy || _isSubmittingSet,
      currentSet: currentSet,
      loadController: _loadControllerFor(selected),
      repsController: _repControllerFor(selected),
      rpe: rpe,
      isWarmup: _warmup,
      loadLabel: _loadLabel(selected.targetLoadBasis),
      onRpeChanged: (value) =>
          setState(() => _rpes[selected.id] = value?.toString() ?? ''),
      onWarmupChanged: (value) => setState(() => _warmup = value),
      onLoadChanged: (_) =>
          _markInputEdited(selected.id, B02PreviousPerformanceInputField.load),
      onRepsChanged: (_) =>
          _markInputEdited(selected.id, B02PreviousPerformanceInputField.reps),
      onEdit: (set) => unawaited(_editLoggedSet(provider, selected, set)),
      onDelete: (set) => unawaited(_deleteLoggedSet(provider, selected, set)),
      onAddSet: !isPlannedMode ? () => _prepareExtraSet(selected) : null,
      moreContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          B02ExecutionAdvancedControls(
            initialValue: pendingTechnique,
            prescribedValue: prescribedTechnique,
            // The pending reps field is an editable actual, not a frozen
            // prescription header. Segment totals are checked at log time.
            headerReps: null,
            onChanged: (value) =>
                setState(() => _pendingTechniques[techniqueKey] = value),
          ),
          if (launch.state.warmupRecommendation != null) ...[
            const SizedBox(height: 8),
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
                  : () => _editWarmup(
                      provider,
                      launch.state.warmupRecommendation!,
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNextExerciseSlot({
    required BuildContext context,
    required dynamic provider,
    required B02StrengthExecutionUiState ui,
    required B02StrengthExecutionLaunch launch,
    required B02StrengthExecutionSlot selected,
    required List<B02StrengthExecutionSlot> slots,
    required bool isQuick,
    required bool hasOpenRest,
    required bool groupSafe,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasOpenRest) ...[
          Text(
            'The next set is ready when you are.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (!hasOpenRest)
          if (isQuick) ...[
            B05ActionButton(
              label: 'Add exercise',
              icon: Icons.playlist_add_rounded,
              emphasis: B05ActionEmphasis.secondary,
              onPressed: ui.isBusy || !groupSafe
                  ? null
                  : () => _openExercisePicker(provider),
            ),
          ] else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: ui.isBusy || !groupSafe
                    ? null
                    : () => ref.read(provider.notifier).skipSlot(selected),
                icon: const Icon(Icons.skip_next_rounded),
                label: const Text('Skip exercise'),
              ),
            ),
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
        _GroupProgressCard(launch: launch, slots: slots, selected: selected),
      ],
    );
  }

  String _actualExerciseName(
    B02ExecutionDraftState state,
    B02StrengthExecutionSlot slot,
  ) {
    final performed = _performedForSlot(state, slot);
    return performed?.actualExerciseNameSnapshot ?? slot.exerciseNameSnapshot;
  }

  String? _actualExerciseId(
    B02ExecutionDraftState state,
    B02StrengthExecutionSlot slot,
  ) {
    return _performedForSlot(state, slot)?.actualExerciseId ?? slot.exerciseId;
  }

  B02PerformedExerciseDraft? _performedForSlot(
    B02ExecutionDraftState state,
    B02StrengthExecutionSlot slot,
  ) {
    for (final exercise in state.performedExercises) {
      final direct = exercise.id == 'performed:${slot.id}';
      final sameFrozenSlot =
          exercise.sourceExercisePrescriptionId == slot.prescriptionId &&
          exercise.groupRoundOrdinal == slot.roundOrdinal &&
          exercise.groupMemberOrdinal == slot.memberOrdinal;
      if (direct || sameFrozenSlot) return exercise;
    }
    return null;
  }

  B02GroupExecutionIntegrity _groupIntegrity(
    B02ExecutionDraftState state,
    B02StrengthExecutionSlot slot,
    Iterable<B02StrengthExecutionSlot> slots,
  ) {
    final currentPosition = B02GroupExecutionIntegrity.checkCurrentPosition(
      state: state,
      slots: slots,
    );
    if (!currentPosition.isValid) return currentPosition;
    final groupId = slot.groupId;
    if (groupId == null) return const B02GroupExecutionIntegrity.valid();
    for (final group in state.groups) {
      if (group.id == groupId) {
        return B02GroupExecutionIntegrity.check(group: group, slots: slots);
      }
    }
    return const B02GroupExecutionIntegrity.invalid(
      'This grouped workout detail is unavailable right now.',
    );
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
    B02PreviousExercisePerformance? previousPerformance,
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
    return usefulTarget ||
        B02PreviousPerformancePresentation.lastTime(previousPerformance) !=
            null;
  }

  void _syncInputIdentity(
    B02StrengthExecutionSlot slot,
    String? actualExerciseId,
  ) {
    final next = _B02InputIdentity(
      slotId: slot.id,
      actualExerciseId: actualExerciseId,
    );
    final previous = _inputIdentities[slot.id];
    if (previous != null && previous != next) {
      final oldReps = _repControllers.remove(slot.id);
      final oldLoad = _loadControllers.remove(slot.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldReps?.dispose();
        oldLoad?.dispose();
      });
      _rpes.remove(slot.id);
      _pendingTechniques.removeWhere((key, _) => key.startsWith('${slot.id}:'));
      _editedInputFields.removeWhere((field) => field.slotId == slot.id);
    }
    _inputIdentities[slot.id] = next;
  }

  void _markInputEdited(String slotId, B02PreviousPerformanceInputField field) {
    _editedInputFields.add((slotId: slotId, field: field));
  }

  B02PreviousPerformanceRequestKey? _previousPerformanceKey(
    B02ExecutionDraftState state,
    B02StrengthExecutionSlot slot,
    B02TechniqueFields technique,
  ) {
    final actualExerciseId = _actualExerciseId(state, slot)?.trim();
    if (actualExerciseId == null || actualExerciseId.isEmpty) return null;
    final recommendation = state.targetRecommendations[slot.id];
    final override = state.targetOverrides[slot.id];
    final loadBasis =
        override?.loadBasis ??
        recommendation?.loadBasis ??
        slot.targetLoadBasis;
    if (loadBasis == null) return null;
    return B02PreviousPerformanceRequestKey(
      slotId: slot.id,
      actualExerciseId: actualExerciseId,
      role: _warmup ? B02SetRole.warmup : B02SetRole.working,
      loadBasis: loadBasis,
      effortMode: technique.effortMode,
      endedAtFailure: technique.endedAtFailure,
      assistanceMode: technique.assistanceMode,
      assistanceKg: technique.assistanceKg,
      tempoEccentricSeconds: technique.tempoEccentricSeconds,
      tempoBottomPauseSeconds: technique.tempoBottomPauseSeconds,
      tempoConcentricSeconds: technique.tempoConcentricSeconds,
      tempoLockoutPauseSeconds: technique.tempoLockoutPauseSeconds,
      pausedRepPosition: technique.pausedRepPosition,
      pausedRepSeconds: technique.pausedRepSeconds,
      hasTechniqueSegments: technique.segments.isNotEmpty,
    );
  }

  String _pendingTechniqueKey(
    B02StrengthExecutionSlot slot,
    int currentSet, {
    required bool isWarmup,
  }) => '${slot.id}:$currentSet:${isWarmup ? 'warmup' : 'working'}';

  B02TechniqueFields _pendingTechniqueFor(
    B02StrengthExecutionSlot slot,
    int currentSet,
  ) {
    final key = _pendingTechniqueKey(slot, currentSet, isWarmup: _warmup);
    final prescriptionOrdinal = slot.setPrescriptionOrdinal ?? currentSet - 1;
    return _pendingTechniques.putIfAbsent(
      key,
      () => _warmup
          ? B02TechniqueFields()
          : slot.techniqueForSet(prescriptionOrdinal) ??
                B02TechniqueFields(
                  effortMode: slot.effortMode,
                  endedAtFailure: slot.endedAtFailure,
                ),
    );
  }

  void _schedulePreviousPerformanceLookup(
    B02PreviousPerformanceRequestKey key,
  ) {
    final query = B02PreviousPerformanceQuery(
      canonicalExerciseId: key.actualExerciseId,
      setContext: B02PreviousPerformanceSetContext(
        role: key.role,
        loadBasis: key.loadBasis,
        effortMode: key.effortMode,
        endedAtFailure: key.endedAtFailure,
        assistanceMode: key.assistanceMode,
        assistanceKg: key.assistanceKg,
        tempoEccentricSeconds: key.tempoEccentricSeconds,
        tempoBottomPauseSeconds: key.tempoBottomPauseSeconds,
        tempoConcentricSeconds: key.tempoConcentricSeconds,
        tempoLockoutPauseSeconds: key.tempoLockoutPauseSeconds,
        pausedRepPosition: key.pausedRepPosition,
        pausedRepSeconds: key.pausedRepSeconds,
        hasTechniqueSegments: key.hasTechniqueSegments,
      ),
      asOfUtc: (widget.nowUtc?.call() ?? DateTime.now()).toUtc(),
    );
    unawaited(
      _previousLookup.request(
        key: key,
        query: query,
        onAccepted: (result) {
          if (!mounted || _previousLookup.activeKey != key) return;
          _applySafePrefill(key, result);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  void _applySafePrefill(
    B02PreviousPerformanceRequestKey key,
    B02PreviousExercisePerformance result,
  ) {
    if (!_previousLookup.claimPrefill(key)) return;
    final prefill = result.safePrefill;
    if (result.status != B02PreviousPerformanceStatus.available ||
        prefill == null ||
        prefill.loadBasis != key.loadBasis ||
        prefill.role != key.role ||
        (_loggedSetCounts[key.slotId] ?? 0) != 0 ||
        _inputIdentities[key.slotId]?.actualExerciseId !=
            key.actualExerciseId) {
      return;
    }
    final loadController = _loadControllers[key.slotId];
    final repsController = _repControllers[key.slotId];
    if (loadController != null &&
        !_editedInputFields.contains((
          slotId: key.slotId,
          field: B02PreviousPerformanceInputField.load,
        )) &&
        loadController.text.trim().isEmpty &&
        prefill.loadKg != null) {
      loadController.text = prefill.loadKg.toString();
    }
    if (repsController != null &&
        !_editedInputFields.contains((
          slotId: key.slotId,
          field: B02PreviousPerformanceInputField.reps,
        )) &&
        repsController.text.trim().isEmpty) {
      repsController.text = prefill.reps.toString();
    }
  }

  void _applySuggestedTarget(
    B02ExecutionDraftState state,
    B02StrengthExecutionSlot slot,
  ) {
    final recommendation = state.targetRecommendations[slot.id];
    if (recommendation == null) return;
    setState(() {
      _loadControllerFor(slot).text =
          recommendation.recommendedLoadKg?.toString() ?? '';
      _repControllerFor(slot).text =
          recommendation.targetRepsMin?.toString() ?? '';
    });
    FocusManager.instance.primaryFocus?.unfocus();
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
    final type = b02ExecutionGroupTypeLabel(slot.groupType!);
    final name = slot.groupLabel?.trim().isNotEmpty == true
        ? slot.groupLabel!.trim()
        : type;
    return '$name · Round ${(slot.roundOrdinal ?? 0) + 1} · Member ${(slot.memberOrdinal ?? 0) + 1}';
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
    final roleWasWarmup = _warmup;
    final reps = int.tryParse(_repControllerFor(slot).text);
    if (reps == null || reps < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your completed reps to log this set.'),
        ),
      );
      return;
    }
    final currentLaunch = launchForProvider(provider);
    final currentSet = currentLaunch == null
        ? 1
        : _workingSetCount(currentLaunch.state, slot) + 1;
    final technique = _pendingTechniqueFor(slot, currentSet);
    try {
      B02RichSetValidator.validateTechnique(technique, headerReps: reps);
    } on B02ValidationException catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    setState(() => _isSubmittingSet = true);
    try {
      final controller = ref.read(provider.notifier);
      await controller.recordSet(
        slot: slot,
        reps: reps,
        loadKg: double.tryParse(_loadControllerFor(slot).text),
        actualLoadBasis: slot.targetLoadBasis,
        rpe: int.tryParse(_rpes[slot.id] ?? ''),
        role: roleWasWarmup ? B02SetRole.warmup : B02SetRole.working,
        technique: technique,
      );
      if (!mounted) return;
      final saved = ref.read(provider);
      if (saved.status != B02StrengthExecutionStatus.failure &&
          saved.status != B02StrengthExecutionStatus.recovery) {
        unawaited(IndiFitHaptics.confirmation());
        if (!_warmup) {
          await controller.beginRest(slot);
        }
        final afterSave = ref.read(provider);
        final cursorLaunch = afterSave.launch;
        final cursor = cursorLaunch == null
            ? null
            : B02ExecutionProgression.cursorSlot(
                state: cursorLaunch.state,
                slots: afterSave.slots,
              );
        if (mounted && cursor != null) {
          setState(() => _selectedSlotId = cursor.id);
        }
        final currentLaunch = launchForProvider(provider);
        final currentExecution = currentLaunch == null
            ? null
            : _executionFor(currentLaunch);
        if (mounted && currentExecution is QuickWorkoutExecutionContext) {
          setState(() {
            _repControllerFor(slot).text = slot.targetRepsMin?.toString() ?? '';
            _rpes[slot.id] = '';
            _warmup = false;
            _pendingTechniques.remove(
              _pendingTechniqueKey(slot, currentSet, isWarmup: roleWasWarmup),
            );
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
      _repControllerFor(slot).text = slot.targetRepsMin?.toString() ?? '';
      _rpes[slot.id] = '';
      _warmup = false;
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  TextEditingController _loadControllerFor(B02StrengthExecutionSlot slot) {
    return _loadControllers.putIfAbsent(
      slot.id,
      () => TextEditingController(text: slot.targetLoadKg?.toString() ?? ''),
    );
  }

  TextEditingController _repControllerFor(B02StrengthExecutionSlot slot) {
    return _repControllers.putIfAbsent(
      slot.id,
      () => TextEditingController(text: slot.targetRepsMin?.toString() ?? ''),
    );
  }

  Future<void> _editLoggedSet(
    dynamic provider,
    B02StrengthExecutionSlot slot,
    B02PerformedSet set,
  ) async {
    if (!_mutatingSetIds.add(set.id)) return;
    try {
      // The row action may be tapped while the pending-set field still owns
      // the keyboard. Close that transient input surface before presenting
      // the edit sheet so its safe-area inset is measured from the viewport.
      FocusManager.instance.primaryFocus?.unfocus();
      final repsController = TextEditingController(
        text: set.actualReps?.toString() ?? '',
      );
      final loadController = TextEditingController(
        text: set.actualLoadKg?.toString() ?? '',
      );
      final result = await showModalBottomSheet<_B02LoggedSetEditValues>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) {
          int? rpe = set.actualRpe;
          String? repsError;
          String? loadError;
          String? techniqueError;
          var technique = set.technique;
          final canEditReps = set.technique.segments.isEmpty;
          return StatefulBuilder(
            builder: (context, setModalState) {
              void save() {
                final reps = int.tryParse(repsController.text.trim());
                final rawLoad = loadController.text.trim();
                final load = rawLoad.isEmpty ? null : double.tryParse(rawLoad);
                final nextRepsError = reps == null || reps < 1
                    ? 'Enter at least 1 rep.'
                    : null;
                final nextLoadError =
                    rawLoad.isNotEmpty && (load == null || load < 0)
                    ? 'Enter a valid load.'
                    : null;
                if (nextRepsError != null || nextLoadError != null) {
                  setModalState(() {
                    repsError = nextRepsError;
                    loadError = nextLoadError;
                  });
                  return;
                }
                try {
                  B02RichSetValidator.validateTechnique(
                    technique,
                    headerReps: reps,
                  );
                } on B02ValidationException catch (error) {
                  setModalState(() => techniqueError = error.message);
                  return;
                }
                Navigator.of(sheetContext).pop(
                  _B02LoggedSetEditValues(
                    reps: reps!,
                    loadKg: load,
                    rpe: rpe,
                    technique: technique,
                  ),
                );
              }

              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Edit set ${set.ordinal + 1}',
                        style: B05Typography.title(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        set.role == B02SetRole.warmup
                            ? 'Warm-up set'
                            : 'Logged set',
                        style: B05Typography.caption(context),
                      ),
                      const SizedBox(height: 16),
                      IndiFitResponsiveFieldGroup(
                        spacing: 10,
                        breakpoint: 350,
                        children: [
                          TextFormField(
                            controller: loadController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Load (kg)',
                              helperText:
                                  set.actualLoadBasis == B02LoadBasis.bodyweight
                                  ? 'Bodyweight'
                                  : null,
                              errorText: loadError,
                            ),
                          ),
                          TextFormField(
                            controller: repsController,
                            readOnly: !canEditReps,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Reps',
                              helperText: canEditReps
                                  ? null
                                  : 'Advanced set details are kept together.',
                              errorText: repsError,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: rpe,
                        decoration: const InputDecoration(labelText: 'RPE'),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('Not set'),
                          ),
                          for (var effort = 1; effort <= 10; effort++)
                            DropdownMenuItem(
                              value: effort,
                              child: Text('$effort'),
                            ),
                        ],
                        onChanged: (value) => setModalState(() => rpe = value),
                      ),
                      const SizedBox(height: 12),
                      B02ExecutionAdvancedControls(
                        initialValue: technique,
                        headerReps: int.tryParse(repsController.text),
                        onChanged: (value) => setModalState(() {
                          technique = value;
                          techniqueError = null;
                        }),
                      ),
                      if (techniqueError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            techniqueError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: save,
                            child: const Text('Save changes'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
      repsController.dispose();
      loadController.dispose();
      if (result == null || !mounted) return;
      final loadBasis = result.loadKg == null
          ? set.actualLoadBasis == B02LoadBasis.bodyweight
                ? B02LoadBasis.bodyweight
                : null
          : set.actualLoadBasis ??
                slot.targetLoadBasis ??
                B02LoadBasis.totalExternal;
      final saved = await ref
          .read(provider.notifier)
          .editSet(
            slot: slot,
            setId: set.id,
            reps: result.reps,
            loadKg: result.loadKg,
            actualLoadBasis: loadBasis,
            rpe: result.rpe,
            technique: result.technique,
          );
      if (saved && mounted) {
        showIndiFitSuccessFeedback(context, 'Set updated');
      }
    } finally {
      _mutatingSetIds.remove(set.id);
    }
  }

  Future<void> _deleteLoggedSet(
    dynamic provider,
    B02StrengthExecutionSlot slot,
    B02PerformedSet set,
  ) async {
    if (!_mutatingSetIds.add(set.id)) return;
    try {
      final saved = await ref
          .read(provider.notifier)
          .deleteSet(slot: slot, setId: set.id);
      if (saved && mounted) {
        showIndiFitSuccessFeedback(context, 'Set deleted');
      }
    } finally {
      _mutatingSetIds.remove(set.id);
    }
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

  Future<void> _openReplacementPicker(
    dynamic provider,
    B02StrengthExecutionSlot slot,
  ) async {
    final currentLaunch = launchForProvider(provider);
    if (currentLaunch == null) return;
    final execution = _executionFor(currentLaunch);
    final actualExerciseId = _actualExerciseId(currentLaunch.state, slot);
    if (actualExerciseId == null || !slot.hasCanonicalExercise) return;
    final actualExerciseName = _actualExerciseName(currentLaunch.state, slot);
    final target = execution is PlannedWorkoutExecutionContext
        ? PlannedExerciseReplacementTarget(
            draftId: currentLaunch.draftId,
            scheduledOccurrenceId: execution.occurrenceId,
            slotId: slot.id,
            expectedExerciseId: slot.exerciseId!,
            currentPerformedExerciseId: actualExerciseId,
            currentExerciseNameSnapshot: actualExerciseName,
          )
        : QuickExerciseReplacementTarget(
            draftId: currentLaunch.draftId,
            slotId: slot.id,
            currentPerformedExerciseId: actualExerciseId,
            currentExerciseNameSnapshot: actualExerciseName,
          );
    final authority =
        ref.read(provider.notifier) as CanonicalExerciseReplacementAuthority;
    final compatibility = await authority.readCompatibility(target: target);
    if (!mounted) return;
    final result = await showExerciseReplacementPicker(
      context: context,
      selectionContext: ExerciseReplacementPickerContext(
        target: target,
        compatibility: compatibility,
      ),
      onReplacementCommit: authority.commit,
    );
    if (result?.committed == true && mounted) {
      showIndiFitSuccessFeedback(context, 'Exercise replaced');
    }
  }

  Future<void> _showExerciseActions(
    dynamic provider,
    B02StrengthExecutionSlot slot,
  ) async {
    final currentLaunch = launchForProvider(provider);
    final currentExecution = currentLaunch == null
        ? null
        : _executionFor(currentLaunch);
    final isQuick = currentExecution is QuickWorkoutExecutionContext;
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
              title: Text(
                _actualExerciseName(
                  launchForProvider(provider)?.state ?? widget.launch.state,
                  slot,
                ),
              ),
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
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded),
              title: const Text('Replace exercise'),
              subtitle: Text(
                hasLoggedSets
                    ? 'Already logged sets stay with the current exercise.'
                    : isQuick
                    ? 'Change this exercise in your Quick workout.'
                    : 'Change this exercise for the remaining workout.',
              ),
              onTap: () => Navigator.pop(sheetContext, 'replace'),
            ),
            if (!isQuick && hasLoggedSets)
              const ListTile(
                leading: Icon(Icons.lock_outline_rounded),
                title: Text('Logged sets are protected'),
                subtitle: Text(
                  'They stay attached to the exercise you logged.',
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
    if (action == 'replace') {
      await _openReplacementPicker(provider, slot);
    }
  }

  Future<void> _openSummary(dynamic provider) async {
    final controller = ref.read(provider.notifier);
    await controller.pauseElapsed();
    if (!mounted) return;
    final launch = ref.read(provider).launch;
    if (launch == null) return;
    await context.push(
      '/b02-strength-summary',
      extra: WorkoutExecutionRouteData(_executionFor(launch)),
    );
    if (mounted) unawaited(controller.resumeElapsed());
  }

  WorkoutExecutionContext _executionFor(B02StrengthExecutionLaunch launch) {
    final origin =
        widget.executionContext ??
        WorkoutExecutionContext.fromLaunch(widget.launch);
    return origin.rebind(launch);
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
        title: const Text('Discard saved workout?'),
        content: const Text('This removes only this unfinished workout.'),
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
  final B02StrengthExecutionSlot selected;

  const _GroupProgressCard({
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
                title: Text('Grouped workout unavailable'),
                subtitle: Text(
                  'This grouped workout detail is unavailable right now.',
                ),
              ),
            if (selected.groupId != null &&
                !launch.state.groups.any(
                  (group) => group.id == selected.groupId,
                ))
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline_rounded),
                title: Text('Grouped workout unavailable'),
                subtitle: Text(
                  'This grouped workout detail is unavailable right now.',
                ),
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
        label: 'Grouped workout detail unavailable',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text('Grouped workout unavailable'),
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
          '$name, $completeCount of $expected grouped exercises complete'
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

class _B02LoggedSetEditValues {
  const _B02LoggedSetEditValues({
    required this.reps,
    required this.loadKg,
    required this.rpe,
    required this.technique,
  });

  final int reps;
  final double? loadKg;
  final int? rpe;
  final B02TechniqueFields technique;
}

@immutable
class _B02InputIdentity {
  const _B02InputIdentity({
    required this.slotId,
    required this.actualExerciseId,
  });

  final String slotId;
  final String? actualExerciseId;

  @override
  bool operator ==(Object other) {
    return other is _B02InputIdentity &&
        other.slotId == slotId &&
        other.actualExerciseId == actualExerciseId;
  }

  @override
  int get hashCode => Object.hash(slotId, actualExerciseId);
}

class _R07CExecutionHeader extends StatelessWidget {
  const _R07CExecutionHeader({
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
    final position = executionContext is QuickWorkoutExecutionContext
        ? 'Quick workout'
        : 'Exercise ${exerciseIndex + 1} of $exerciseCount';
    final exercisePosition = 'Exercise ${exerciseIndex + 1} of $exerciseCount';
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
              (exercise.sourceExercisePrescriptionId == slot.prescriptionId &&
                  exercise.performedExerciseGroupId == slot.groupId &&
                  exercise.groupRoundOrdinal == slot.roundOrdinal &&
                  exercise.groupMemberOrdinal == slot.memberOrdinal)) &&
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
  final B02PreviousExercisePerformance? previousPerformance;
  final VoidCallback? onApply;
  final VoidCallback? onChange;

  const _R07CTargetContext({
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
            child: const Text('Keep workout and go back'),
          ),
        ],
      ),
    ),
  );
}
