import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/b02_strength_execution_repository.dart';
import '../../data/repositories/calendar_repository.dart';

/// UI states are deliberately separate from the durable draft. A transient
/// failure never becomes a fake completed/ready state and a recovered draft is
/// retained so the caller can retry without losing offline work.
enum B02StrengthExecutionStatus { loading, ready, partial, failure, recovery }

class B02StrengthExecutionUiState {
  final B02StrengthExecutionStatus status;
  final B02StrengthExecutionLaunch? launch;
  final String? errorMessage;

  const B02StrengthExecutionUiState({
    required this.status,
    this.launch,
    this.errorMessage,
  });

  const B02StrengthExecutionUiState.initial()
    : status = B02StrengthExecutionStatus.loading,
      launch = null,
      errorMessage = null;

  B02StrengthExecutionUiState copyWith({
    B02StrengthExecutionStatus? status,
    B02StrengthExecutionLaunch? launch,
    String? errorMessage,
    bool clearError = false,
  }) {
    return B02StrengthExecutionUiState(
      status: status ?? this.status,
      launch: launch ?? this.launch,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  bool get isBusy => status == B02StrengthExecutionStatus.loading;
}

class B02StrengthExecutionController
    extends StateNotifier<B02StrengthExecutionUiState> {
  final StrengthExecutionCompatibilityAdapter _adapter;

  B02StrengthExecutionController(this._adapter)
    : super(const B02StrengthExecutionUiState.initial());

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
      if (!mounted) return;
      state = B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.ready,
        launch: launch,
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
      if (!mounted) return;
      state = B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.ready,
        launch: launch,
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
