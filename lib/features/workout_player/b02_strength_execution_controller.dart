import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/b02_strength_execution_repository.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/services/b02_rest_recommendation_service.dart';
import '../../data/services/b02_strength_execution_draft_service.dart';

/// UI states are deliberately separate from the durable draft. A transient
/// failure never becomes a fake completed/ready state and a recovered draft is
/// retained so the caller can retry without losing offline work.
enum B02StrengthExecutionStatus { loading, ready, partial, failure, recovery }

class B02StrengthExecutionUiState {
  final B02StrengthExecutionStatus status;
  final B02StrengthExecutionLaunch? launch;
  final List<B02StrengthExecutionSlot> slots;
  final String? errorMessage;

  const B02StrengthExecutionUiState({
    required this.status,
    this.launch,
    this.slots = const [],
    this.errorMessage,
  });

  const B02StrengthExecutionUiState.initial()
    : status = B02StrengthExecutionStatus.loading,
      launch = null,
      slots = const [],
      errorMessage = null;

  B02StrengthExecutionUiState copyWith({
    B02StrengthExecutionStatus? status,
    B02StrengthExecutionLaunch? launch,
    List<B02StrengthExecutionSlot>? slots,
    String? errorMessage,
    bool clearError = false,
  }) {
    return B02StrengthExecutionUiState(
      status: status ?? this.status,
      launch: launch ?? this.launch,
      slots: slots ?? this.slots,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  bool get isBusy => status == B02StrengthExecutionStatus.loading;
}

class B02StrengthExecutionController
    extends StateNotifier<B02StrengthExecutionUiState> {
  final StrengthExecutionCompatibilityAdapter _adapter;
  final B02StrengthExecutionDraftService _draftService;
  final B02RestDraftCoordinator _restCoordinator;

  B02StrengthExecutionController(
    this._adapter, {
    B02StrengthExecutionLaunch? initialLaunch,
    B02StrengthExecutionDraftService? draftService,
    B02RestDraftCoordinator? restCoordinator,
  }) : _draftService = draftService ?? const B02StrengthExecutionDraftService(),
       _restCoordinator = restCoordinator ?? const B02RestDraftCoordinator(),
       super(
         initialLaunch == null
             ? const B02StrengthExecutionUiState.initial()
             : B02StrengthExecutionUiState(
                 status: B02StrengthExecutionStatus.ready,
                 launch: initialLaunch,
               ),
       );

  Future<void> startScheduled({
    required String occurrenceId,
    required String commandId,
    bool confirmedOutsideEffectiveDate = false,
  }) async {
    await _load(
      () => _adapter.startScheduledOccurrence(
        occurrenceId: occurrenceId,
        commandId: commandId,
        confirmedOutsideEffectiveDate: confirmedOutsideEffectiveDate,
      ),
    );
  }

  Future<void> resumeScheduled(String occurrenceId) async {
    await _load(() => _adapter.resumeScheduledOccurrence(occurrenceId));
  }

  Future<void> startUnscheduled({
    required String routineName,
    required String executionSnapshotJson,
    Iterable<B02ExerciseGroup> groups = const [],
    String? snapshotId,
  }) async {
    await _load(
      () => _adapter.startUnscheduledDraft(
        routineName: routineName,
        executionSnapshotJson: executionSnapshotJson,
        groups: groups,
        snapshotId: snapshotId,
      ),
    );
  }

  Future<void> saveDraft(B02ExecutionDraftState draft) async {
    final current = state.launch;
    if (current == null) {
      state = const B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.recovery,
        errorMessage: 'No B02 strength draft is loaded.',
      );
      return;
    }
    state = state.copyWith(
      status: B02StrengthExecutionStatus.loading,
      clearError: true,
    );
    try {
      await _adapter.saveDraft(draftId: current.draftId, state: draft);
      if (!mounted) return;
      state = state.copyWith(
        status: B02StrengthExecutionStatus.partial,
        launch: current.copyWith(state: draft),
        clearError: true,
      );
    } catch (error) {
      _setFailure(error, current);
    }
  }

  Future<void> loadSlots() async {
    final current = state.launch;
    if (current == null) {
      state = const B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.recovery,
        errorMessage: 'No B02 strength draft is loaded.',
      );
      return;
    }
    final previousStatus = state.status == B02StrengthExecutionStatus.partial
        ? B02StrengthExecutionStatus.partial
        : B02StrengthExecutionStatus.ready;
    state = state.copyWith(
      status: B02StrengthExecutionStatus.loading,
      clearError: true,
    );
    try {
      final slots = await _adapter.readExecutionSlots(current);
      if (!mounted) return;
      state = state.copyWith(status: previousStatus, slots: slots);
    } catch (error) {
      _setFailure(error, current);
    }
  }

  Future<void> recordSet({
    required B02StrengthExecutionSlot slot,
    required int reps,
    double? loadKg,
    int? rpe,
    B02SetRole role = B02SetRole.working,
    B02TechniqueFields? technique,
    String? actualExerciseId,
    String? actualExerciseNameSnapshot,
    String? substitutionReason,
  }) async {
    final current = state.launch;
    if (current == null) {
      state = const B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.recovery,
        errorMessage: 'No B02 strength draft is loaded.',
      );
      return;
    }
    try {
      final next = _draftService.recordSet(
        state: current.state,
        slot: slot,
        reps: reps,
        loadKg: loadKg,
        rpe: rpe,
        role: role,
        technique: technique,
        actualExerciseId: actualExerciseId,
        actualExerciseNameSnapshot: actualExerciseNameSnapshot,
        substitutionReason: substitutionReason,
      );
      await saveDraft(next);
    } catch (error) {
      _setFailure(error, current);
    }
  }

  Future<void> skipSlot(B02StrengthExecutionSlot slot, {String? reason}) async {
    final current = state.launch;
    if (current == null) {
      state = const B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.recovery,
        errorMessage: 'No B02 strength draft is loaded.',
      );
      return;
    }
    try {
      final next = _draftService.skipSlot(
        state: current.state,
        slot: slot,
        reason: reason,
      );
      await saveDraft(next);
    } catch (error) {
      _setFailure(error, current);
    }
  }

  Future<void> beginRest(
    B02StrengthExecutionSlot slot, {
    int selectedSeconds = RestRecommendationService.defaultSeconds,
  }) async {
    final current = state.launch;
    if (current == null) return;
    try {
      final performed = current.state.performedExercises.where(
        (exercise) =>
            exercise.sourceExercisePrescriptionId == slot.prescriptionId &&
            exercise.groupRoundOrdinal == slot.roundOrdinal &&
            exercise.groupMemberOrdinal == slot.memberOrdinal,
      );
      final sets = performed.expand((exercise) => exercise.sets).toList();
      final setId = sets.isEmpty ? null : sets.last.id;
      if (setId == null && slot.groupId == null) {
        throw const B02ValidationException(
          'Log a set before starting exercise rest.',
        );
      }
      final period = B02RestPeriod(
        id: 'rest:${slot.id}:${current.state.restPeriods.length}',
        performedSetId: setId,
        performedExerciseGroupId: setId == null ? slot.groupId : null,
        scope: slot.groupId == null
            ? B02RestScope.exerciseSet
            : B02RestScope.groupTransition,
        recommendedSeconds: selectedSeconds,
        selectedSeconds: selectedSeconds,
        actualSeconds: null,
        source: B02RestSource.user,
        startedAtUtc: DateTime.now().toUtc(),
      );
      await saveDraft(_restCoordinator.begin(current.state, period));
    } catch (error) {
      _setFailure(error, current);
    }
  }

  Future<void> extendRest(String periodId, {int seconds = 30}) async {
    final current = state.launch;
    if (current == null) return;
    try {
      await saveDraft(
        _restCoordinator.extend(current.state, periodId, seconds: seconds),
      );
    } catch (error) {
      _setFailure(error, current);
    }
  }

  Future<void> skipRest(String periodId) async {
    final current = state.launch;
    if (current == null) return;
    try {
      await saveDraft(
        _restCoordinator.skip(
          current.state,
          periodId,
          endedAtUtc: DateTime.now().toUtc(),
        ),
      );
    } catch (error) {
      _setFailure(error, current);
    }
  }

  Future<void> finalize({
    required String commandId,
    CompletionKind completionKind = CompletionKind.full,
    String? reason,
    DateTime? completedAtUtc,
  }) async {
    final current = state.launch;
    if (current == null) {
      state = const B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.recovery,
        errorMessage: 'No B02 strength draft is loaded.',
      );
      return;
    }
    state = state.copyWith(
      status: B02StrengthExecutionStatus.loading,
      clearError: true,
    );
    try {
      await _adapter.finalizeDraft(
        draftId: current.draftId,
        commandId: commandId,
        state: current.state,
        completionKind: completionKind,
        reason: reason,
        completedAtUtc: completedAtUtc,
      );
      if (!mounted) return;
      state = B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.ready,
      );
    } on B02StrengthExecutionRecoveryException catch (error) {
      _setFailure(error, current, recovery: true);
    } catch (error) {
      _setFailure(error, current);
    }
  }

  Future<void> discard() async {
    final current = state.launch;
    if (current == null) return;
    state = state.copyWith(
      status: B02StrengthExecutionStatus.loading,
      clearError: true,
    );
    try {
      await _adapter.discardDraft(draftId: current.draftId);
      if (!mounted) return;
      state = const B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.ready,
      );
    } catch (error) {
      _setFailure(error, current);
    }
  }

  Future<void> recover(int draftId) async {
    state = const B02StrengthExecutionUiState.initial();
    try {
      final launch = await _adapter.readDraft(draftId);
      final slots = await _adapter.readExecutionSlots(launch);
      if (!mounted) return;
      state = B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.ready,
        launch: launch,
        slots: slots,
      );
    } catch (error) {
      _setFailure(error, null, recovery: true);
    }
  }

  Future<void> _load(
    Future<B02StrengthExecutionLaunch> Function() operation,
  ) async {
    final prior = state.launch;
    state = state.copyWith(
      status: B02StrengthExecutionStatus.loading,
      clearError: true,
    );
    try {
      final launch = await operation();
      final slots = await _adapter.readExecutionSlots(launch);
      if (!mounted) return;
      state = B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.ready,
        launch: launch,
        slots: slots,
      );
    } on B02StrengthExecutionRecoveryException catch (error) {
      _setFailure(error, prior, recovery: true);
    } catch (error) {
      _setFailure(error, prior);
    }
  }

  void _setFailure(
    Object error,
    B02StrengthExecutionLaunch? launch, {
    bool recovery = false,
  }) {
    if (!mounted) return;
    state = B02StrengthExecutionUiState(
      status: recovery
          ? B02StrengthExecutionStatus.recovery
          : B02StrengthExecutionStatus.failure,
      launch: launch,
      errorMessage: error.toString(),
    );
  }
}

final b02StrengthExecutionControllerProvider =
    StateNotifierProvider<
      B02StrengthExecutionController,
      B02StrengthExecutionUiState
    >(
      (ref) => B02StrengthExecutionController(
        ref.watch(strengthExecutionCompatibilityAdapterProvider),
      ),
    );

final b02StrengthExecutionScreenControllerProvider = StateNotifierProvider
    .autoDispose
    .family<
      B02StrengthExecutionController,
      B02StrengthExecutionUiState,
      B02StrengthExecutionLaunch
    >(
      (ref, launch) => B02StrengthExecutionController(
        ref.watch(strengthExecutionCompatibilityAdapterProvider),
        initialLaunch: launch,
      ),
    );
