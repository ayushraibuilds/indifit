import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/b02_strength_execution_repository.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/services/b02_rest_recommendation_service.dart';
import '../../data/services/b02_strength_execution_draft_service.dart';

/// UI states are deliberately separate from the durable draft. A transient
/// failure never becomes a fake completed/ready state and a recovered draft is
/// retained so the caller can retry without losing offline work.
enum B02StrengthExecutionStatus { loading, ready, partial, failure, recovery }

typedef _B02CompletionRequestKey = ({
  int? draftId,
  CompletionKind completionKind,
  String? reason,
  int? completedAtMicroseconds,
});

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
  final DateTime Function() _nowUtc;
  Future<bool>? _finalizationInFlight;
  _B02CompletionRequestKey? _finalizationRequestKey;
  Future<void> _draftWriteTail = Future<void>.value();
  B02ExecutionDraftState? _pendingPauseState;
  int? _pendingPauseDraftId;
  var _timingRevision = 0;
  var _completionStarted = false;

  B02StrengthExecutionController(
    this._adapter, {
    B02StrengthExecutionLaunch? initialLaunch,
    B02StrengthExecutionDraftService? draftService,
    B02RestDraftCoordinator? restCoordinator,
    DateTime Function()? nowUtc,
  }) : _draftService = draftService ?? const B02StrengthExecutionDraftService(),
       _restCoordinator = restCoordinator ?? const B02RestDraftCoordinator(),
       _nowUtc = nowUtc ?? _systemNowUtc,
       super(
         initialLaunch == null
             ? const B02StrengthExecutionUiState.initial()
             : B02StrengthExecutionUiState(
                 status: B02StrengthExecutionStatus.ready,
                 launch: initialLaunch,
               ),
       );

  static DateTime _systemNowUtc() => DateTime.now().toUtc();

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
        nowUtc: _nowUtc().toUtc(),
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
        nowUtc: _nowUtc().toUtc(),
      ),
    );
  }

  Future<bool> saveDraft(B02ExecutionDraftState draft) {
    return _saveDraft(draft, allowDuringCompletion: false);
  }

  Future<bool> _saveDraft(
    B02ExecutionDraftState draft, {
    required bool allowDuringCompletion,
    bool useLatestState = false,
    int? expectedTimingRevision,
  }) {
    final current = state.launch;
    if (current == null) {
      state = const B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.recovery,
        errorMessage:
            'This workout draft is unavailable. Recover it or start over.',
      );
      return Future<bool>.value(false);
    }
    if (_completionStarted && !allowDuringCompletion) {
      return Future<bool>.value(false);
    }
    final requestRevision = _timingRevision;
    final queuedBeforeCompletion = !_completionStarted;
    return _enqueueDraftWrite(() async {
      if (expectedTimingRevision != null &&
          expectedTimingRevision != _timingRevision) {
        return true;
      }
      final latest = state.launch;
      if (latest == null || latest.draftId != current.draftId) {
        return false;
      }
      if (_completionStarted &&
          !allowDuringCompletion &&
          !queuedBeforeCompletion) {
        return false;
      }
      if (mounted) {
        state = state.copyWith(
          status: B02StrengthExecutionStatus.loading,
          clearError: true,
        );
      }
      try {
        final candidate = useLatestState
            ? latest.state
            : requestRevision == _timingRevision
            ? draft
            : draft.copyWith(
                elapsedSeconds: latest.state.elapsedSeconds,
                activeSegmentStartedAtUtc:
                    latest.state.activeSegmentStartedAtUtc,
              );
        final durableDraft = _stampElapsed(
          candidate,
          nowUtc: _nowUtc().toUtc(),
        );
        await _adapter.saveDraft(draftId: latest.draftId, state: durableDraft);
        if (!mounted) return true;
        state = state.copyWith(
          status: B02StrengthExecutionStatus.partial,
          launch: latest.copyWith(state: durableDraft),
          clearError: true,
        );
        return true;
      } catch (error) {
        _setFailure(error, latest);
        return false;
      }
    });
  }

  Future<void> loadSlots() async {
    final current = state.launch;
    if (current == null) {
      state = const B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.recovery,
        errorMessage:
            'This workout draft is unavailable. Recover it or start over.',
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
      final prepared = await _adapter.prepareExecution(current);
      final activeState = await _ensureActiveSegment(
        launch: current,
        state: prepared.state,
      );
      if (!mounted) return;
      state = state.copyWith(
        status: previousStatus,
        launch: current.copyWith(state: activeState),
        slots: prepared.slots,
      );
    } catch (error) {
      _setFailure(error, current);
    }
  }

  Future<void> recordSet({
    required B02StrengthExecutionSlot slot,
    required int reps,
    double? loadKg,
    B02LoadBasis? actualLoadBasis,
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
        errorMessage:
            'This workout draft is unavailable. Recover it or start over.',
      );
      return;
    }
    try {
      final next = _draftService.recordSet(
        state: current.state,
        slot: slot,
        reps: reps,
        loadKg: loadKg,
        actualLoadBasis: actualLoadBasis,
        rpe: rpe,
        role: role,
        technique: technique,
        actualExerciseId: actualExerciseId,
        actualExerciseNameSnapshot: actualExerciseNameSnapshot,
        substitutionReason: substitutionReason,
        sourceExercisePrescriptionId: current.occurrenceId == null
            ? null
            : slot.prescriptionId,
        useSlotPrescription: current.occurrenceId != null,
      );
      await saveDraft(next);
    } catch (error) {
      _setFailure(error, current);
    }
  }

  Future<bool> editSet({
    required B02StrengthExecutionSlot slot,
    required String setId,
    required int reps,
    double? loadKg,
    B02LoadBasis? actualLoadBasis,
    int? rpe,
  }) async {
    final current = state.launch;
    if (current == null) {
      state = const B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.recovery,
        errorMessage:
            'This workout draft is unavailable. Recover it or start over.',
      );
      return false;
    }
    try {
      final next = _draftService.editSet(
        state: current.state,
        slot: slot,
        setId: setId,
        reps: reps,
        loadKg: loadKg,
        actualLoadBasis: actualLoadBasis,
        rpe: rpe,
      );
      return await saveDraft(next);
    } catch (error) {
      _setFailure(error, current);
      return false;
    }
  }

  Future<bool> deleteSet({
    required B02StrengthExecutionSlot slot,
    required String setId,
  }) async {
    final current = state.launch;
    if (current == null) {
      state = const B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.recovery,
        errorMessage:
            'This workout draft is unavailable. Recover it or start over.',
      );
      return false;
    }
    try {
      final next = _draftService.deleteSet(
        state: current.state,
        slot: slot,
        setId: setId,
      );
      return await saveDraft(next);
    } catch (error) {
      _setFailure(error, current);
      return false;
    }
  }

  Future<void> skipSlot(B02StrengthExecutionSlot slot, {String? reason}) async {
    final current = state.launch;
    if (current == null) {
      state = const B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.recovery,
        errorMessage:
            'This workout draft is unavailable. Recover it or start over.',
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

  Future<void> addUnscheduledExercise({
    required String exerciseId,
    required String exerciseName,
  }) async {
    final current = state.launch;
    if (current == null || current.occurrenceId != null) return;
    state = state.copyWith(status: B02StrengthExecutionStatus.loading);
    try {
      final updated = await _adapter.addUnscheduledExercise(
        launch: current,
        exerciseId: exerciseId,
        exerciseName: exerciseName,
      );
      final prepared = await _adapter.prepareExecution(updated);
      if (!mounted) return;
      state = B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.ready,
        launch: updated.copyWith(state: prepared.state),
        slots: prepared.slots,
      );
    } catch (error) {
      _setFailure(error, current);
    }
  }

  Future<void> removeUnscheduledExercise(B02StrengthExecutionSlot slot) async {
    final current = state.launch;
    if (current == null || current.occurrenceId != null) return;
    state = state.copyWith(status: B02StrengthExecutionStatus.loading);
    try {
      final updated = await _adapter.removeUnscheduledExercise(
        launch: current,
        prescriptionId: slot.prescriptionId,
      );
      final prepared = await _adapter.prepareExecution(updated);
      if (!mounted) return;
      state = B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.ready,
        launch: updated.copyWith(state: prepared.state),
        slots: prepared.slots,
      );
    } catch (error) {
      _setFailure(error, current);
    }
  }

  Future<void> beginRest(
    B02StrengthExecutionSlot slot, {
    int? selectedSeconds,
  }) async {
    final current = state.launch;
    if (current == null) return;
    try {
      final performed = current.state.performedExercises.where(
        (exercise) =>
            exercise.id == 'performed:${slot.id}' ||
            (exercise.sourceExercisePrescriptionId == slot.prescriptionId &&
                exercise.groupRoundOrdinal == slot.roundOrdinal &&
                exercise.groupMemberOrdinal == slot.memberOrdinal),
      );
      final sets = performed.expand((exercise) => exercise.sets).toList();
      final lastSet = sets.isEmpty ? null : sets.last;
      final setId = lastSet?.id;
      if (setId == null) {
        throw const B02ValidationException('Log a set before starting rest.');
      }
      final group = slot.groupId == null
          ? null
          : current.state.groups.firstWhere(
              (candidate) => candidate.id == slot.groupId,
              orElse: () => throw const B02ValidationException(
                'This workout is missing a required detail. Recover the draft and try again.',
              ),
            );
      final isLastGroupMember =
          group != null && slot.memberOrdinal == group.members.length - 1;
      final restPauseSeconds = lastSet?.technique.isRestPause == true
          ? lastSet!.technique.segments
                .skip(1)
                .map((segment) => segment.restBeforeSeconds)
                .whereType<int>()
                .firstOrNull
          : null;
      final scope = restPauseSeconds != null
          ? B02RestScope.restPause
          : group == null
          ? B02RestScope.exerciseSet
          : isLastGroupMember
          ? B02RestScope.groupRound
          : B02RestScope.groupTransition;
      final recommendation = const RestRecommendationService().recommend(
        B02RestSelectionRequest(
          scope: scope,
          userSelectedSeconds: selectedSeconds,
          prescribedSeconds: restPauseSeconds ?? slot.prescribedRestSeconds,
          memberTransitionRestSeconds: slot.memberTransitionRestSeconds,
          groupRestAfterRoundSeconds: slot.groupRestAfterRoundSeconds,
          exercisePreferenceSeconds: slot.exercisePreferenceRestSeconds,
          templateDefaultRestSeconds: slot.templateDefaultRestSeconds,
          rpe: lastSet?.actualRpe,
          effortMode: lastSet?.technique.effortMode ?? slot.effortMode,
          endedAtFailure:
              lastSet?.technique.endedAtFailure ?? slot.endedAtFailure,
        ),
      );
      if (!recommendation.isAvailable) {
        throw B02ValidationException(recommendation.explanation);
      }
      final period = B02RestPeriod(
        id: 'rest:${slot.id}:${current.state.restPeriods.length}',
        performedSetId:
            scope == B02RestScope.exerciseSet || scope == B02RestScope.restPause
            ? setId
            : null,
        performedExerciseGroupId:
            scope == B02RestScope.exerciseSet || scope == B02RestScope.restPause
            ? null
            : slot.groupId,
        scope: scope,
        recommendedSeconds: recommendation.recommendedSeconds,
        selectedSeconds: recommendation.selectedSeconds,
        actualSeconds: null,
        source: recommendation.source,
        startedAtUtc: _nowUtc().toUtc(),
      );
      await saveDraft(_restCoordinator.begin(current.state, period));
    } catch (error) {
      _setFailure(error, current);
    }
  }

  Future<void> overrideTarget(
    B02StrengthExecutionSlot slot, {
    double? loadKg,
    B02LoadBasis? loadBasis,
    int? targetRepsMin,
    int? targetRepsMax,
    int? targetRpe,
  }) async {
    final current = state.launch;
    if (current == null) return;
    try {
      final next = _draftService.applyTargetOverride(
        state: current.state,
        slot: slot,
        override: B02TargetOverride(
          loadKg: loadKg,
          loadBasis: loadBasis ?? slot.targetLoadBasis,
          targetRepsMin: targetRepsMin ?? slot.targetRepsMin,
          targetRepsMax: targetRepsMax ?? slot.targetRepsMax,
          targetRpe: targetRpe ?? slot.targetRpe,
        ),
      );
      await saveDraft(next);
      if (!mounted) return;
      final selected = next.targetOverrides[slot.id];
      if (selected == null) return;
      state = state.copyWith(
        slots: [
          for (final value in state.slots)
            value.id == slot.id
                ? value.copyWith(
                    targetLoadKg: selected.loadKg,
                    targetLoadBasis: selected.loadBasis,
                    targetRepsMin: selected.targetRepsMin,
                    targetRepsMax: selected.targetRepsMax,
                    targetRpe: selected.targetRpe,
                  )
                : value,
        ],
      );
    } catch (error) {
      _setFailure(error, current);
    }
  }

  Future<void> chooseWarmup(B02WarmupDecision decision) async {
    final current = state.launch;
    if (current == null) return;
    try {
      await saveDraft(_draftService.chooseWarmup(current.state, decision));
    } catch (error) {
      _setFailure(error, current);
    }
  }

  Future<void> editWarmup(List<B02WarmupSetProposal> proposals) async {
    final current = state.launch;
    if (current == null) return;
    try {
      await saveDraft(
        _draftService.chooseWarmup(
          current.state,
          B02WarmupDecision.edited,
          selectedProposals: proposals,
        ),
      );
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

  Future<void> adjustRest(String periodId, {required int seconds}) async {
    final current = state.launch;
    if (current == null) return;
    try {
      final period = current.state.restPeriods.firstWhere(
        (candidate) => candidate.id == periodId,
      );
      final selected =
          (period.selectedSeconds ?? period.recommendedSeconds ?? 0) + seconds;
      final adjusted = selected.clamp(0, 3600);
      final now = _nowUtc().toUtc();
      final elapsed = now
          .difference(period.startedAtUtc)
          .inSeconds
          .clamp(0, 86400);
      await saveDraft(
        adjusted <= elapsed
            ? _restCoordinator.finish(
                current.state,
                periodId,
                endedAtUtc: now,
                endReason: B02RestEndReason.elapsed,
              )
            : _restCoordinator.select(current.state, periodId, adjusted),
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
          endedAtUtc: _nowUtc().toUtc(),
        ),
      );
    } catch (error) {
      _setFailure(error, current);
    }
  }

  /// Completes an elapsed countdown through the same durable B02 rest path as
  /// an explicit skip. The timer is presentation-only; it never mutates a
  /// rest period directly.
  Future<bool> completeRest(String periodId, {DateTime? endedAtUtc}) async {
    final current = state.launch;
    if (current == null) return false;
    try {
      await saveDraft(
        _restCoordinator.finish(
          current.state,
          periodId,
          endedAtUtc: (endedAtUtc ?? _nowUtc()).toUtc(),
          endReason: B02RestEndReason.elapsed,
        ),
      );
      return mounted &&
          state.status == B02StrengthExecutionStatus.partial &&
          state.launch?.state.restPeriods.any(
                (period) => period.id == periodId && period.endedAtUtc != null,
              ) ==
              true;
    } catch (error) {
      _setFailure(error, current);
      return false;
    }
  }

  Future<bool> finalize({
    required String commandId,
    CompletionKind completionKind = CompletionKind.full,
    String? reason,
    DateTime? completedAtUtc,
  }) {
    final requestKey = (
      draftId: state.launch?.draftId,
      completionKind: completionKind,
      reason: reason?.trim(),
      completedAtMicroseconds: completedAtUtc?.toUtc().microsecondsSinceEpoch,
    );
    final inFlight = _finalizationInFlight;
    if (inFlight != null) {
      if (_finalizationRequestKey == requestKey) return inFlight;
      return Future<bool>.value(false);
    }

    final operation = _finalizeInternal(
      commandId: commandId,
      completionKind: completionKind,
      reason: reason,
      completedAtUtc: completedAtUtc,
    );
    _finalizationInFlight = operation;
    _finalizationRequestKey = requestKey;
    unawaited(
      operation.then<void>(
        (_) {
          if (identical(_finalizationInFlight, operation)) {
            _finalizationInFlight = null;
            _finalizationRequestKey = null;
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_finalizationInFlight, operation)) {
            _finalizationInFlight = null;
            _finalizationRequestKey = null;
          }
        },
      ),
    );
    return operation;
  }

  Future<bool> _finalizeInternal({
    required String commandId,
    required CompletionKind completionKind,
    required String? reason,
    required DateTime? completedAtUtc,
  }) async {
    final requested = state.launch;
    if (requested == null) {
      state = const B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.recovery,
        errorMessage:
            'This workout draft is unavailable. Recover it or start over.',
      );
      return false;
    }
    _completionStarted = true;
    state = state.copyWith(
      status: B02StrengthExecutionStatus.loading,
      clearError: true,
    );
    var current = requested;
    try {
      // Completion closes mutation intake above, then waits for every draft
      // write accepted before that boundary. Snapshot only after those writes
      // have updated the same launch so a rapid log-then-finish cannot persist
      // an older state over the newest set.
      await _draftWriteTail;
      final latest = state.launch;
      if (latest == null || latest.draftId != requested.draftId) {
        throw const B02StrengthExecutionRecoveryException(
          'The workout draft changed before completion could begin.',
        );
      }
      current = latest;
      if (mounted) {
        state = state.copyWith(
          status: B02StrengthExecutionStatus.loading,
          clearError: true,
        );
      }
      final finalState = _stampElapsed(
        current.state,
        nowUtc: _nowUtc().toUtc(),
      ).copyWith(activeSegmentStartedAtUtc: null);
      try {
        await _saveDraft(finalState, allowDuringCompletion: true);
      } catch (_) {
        // A concurrent/late caller may observe the draft after the first
        // completion deleted it. Let the repository replay its durable
        // completion marker before surfacing a failure.
      }
      await _adapter.finalizeDraft(
        draftId: current.draftId,
        commandId: commandId,
        state: finalState,
        completionKind: completionKind,
        reason: reason,
        completedAtUtc: completedAtUtc,
      );
      if (!mounted) return false;
      state = B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.ready,
      );
      return true;
    } on B02StrengthExecutionRecoveryException catch (error, stackTrace) {
      _logFinalizationFailure(
        error,
        stackTrace,
        current: current,
        commandId: commandId,
        completionKind: completionKind,
      );
      _setFailure(error, state.launch ?? current, recovery: true);
      _completionStarted = false;
      return false;
    } catch (error, stackTrace) {
      _logFinalizationFailure(
        error,
        stackTrace,
        current: current,
        commandId: commandId,
        completionKind: completionKind,
      );
      _setFailure(error, state.launch ?? current);
      _completionStarted = false;
      return false;
    }
  }

  void _logFinalizationFailure(
    Object error,
    StackTrace stackTrace, {
    required B02StrengthExecutionLaunch current,
    required String commandId,
    required CompletionKind completionKind,
  }) {
    AppLogger.error(
      'Workout finalization failed '
          '[draftId=${current.draftId}, occurrenceId=${current.occurrenceId ?? 'quick'}, '
          'commandId=$commandId, completionKind=${completionKind.name}, '
          'errorType=${error.runtimeType}]',
      error,
      stackTrace,
      'B02Finalization',
    );
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
      final prepared = await _adapter.prepareExecution(launch);
      final activeState = await _ensureActiveSegment(
        launch: launch,
        state: prepared.state,
      );
      if (!mounted) return;
      state = B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.ready,
        launch: launch.copyWith(state: activeState),
        slots: prepared.slots,
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
      final prepared = await _adapter.prepareExecution(launch);
      final activeState = await _ensureActiveSegment(
        launch: launch,
        state: prepared.state,
      );
      if (!mounted) return;
      state = B02StrengthExecutionUiState(
        status: B02StrengthExecutionStatus.ready,
        launch: launch.copyWith(state: activeState),
        slots: prepared.slots,
      );
    } on B02StrengthExecutionRecoveryException catch (error) {
      _setFailure(error, prior, recovery: true);
    } catch (error) {
      _setFailure(error, prior);
    }
  }

  /// Persists active wall-clock time before the player leaves the foreground.
  Future<bool> pauseElapsed() async {
    if (_completionStarted) return true;
    final current = state.launch;
    if (current == null) return true;

    final pendingPause = _pendingPauseState;
    if (pendingPause != null && _pendingPauseDraftId == current.draftId) {
      final revision = ++_timingRevision;
      final retryState = current.state.copyWith(
        elapsedSeconds: pendingPause.elapsedSeconds,
        activeSegmentStartedAtUtc: null,
      );
      _pendingPauseState = retryState;
      state = state.copyWith(
        launch: current.copyWith(state: retryState),
        clearError: true,
      );
      final saved = await _saveDraft(
        retryState,
        allowDuringCompletion: false,
        useLatestState: true,
        expectedTimingRevision: revision,
      );
      if (saved && revision == _timingRevision) {
        _pendingPauseState = null;
        _pendingPauseDraftId = null;
      }
      return saved;
    }
    if (_pendingPauseDraftId != null &&
        _pendingPauseDraftId != current.draftId) {
      _pendingPauseState = null;
      _pendingPauseDraftId = null;
    }
    if (current.state.activeSegmentStartedAtUtc == null) {
      return true;
    }
    final revision = ++_timingRevision;
    final paused = _stampElapsed(
      current.state,
      nowUtc: _nowUtc().toUtc(),
    ).copyWith(activeSegmentStartedAtUtc: null);
    state = state.copyWith(
      launch: current.copyWith(state: paused),
      clearError: true,
    );
    _pendingPauseState = paused;
    _pendingPauseDraftId = current.draftId;
    final saved = await _saveDraft(
      paused,
      allowDuringCompletion: false,
      useLatestState: true,
      expectedTimingRevision: revision,
    );
    if (saved && revision == _timingRevision) {
      _pendingPauseState = null;
      _pendingPauseDraftId = null;
    }
    return saved;
  }

  /// Starts and persists a fresh foreground interval without counting
  /// background time. Repeated lifecycle notifications are harmless.
  Future<bool> resumeElapsed() async {
    if (_completionStarted) return true;
    final current = state.launch;
    if (current == null || current.state.activeSegmentStartedAtUtc != null) {
      return true;
    }
    final revision = ++_timingRevision;
    final activeLaunch = current.copyWith(
      state: current.state.copyWith(
        activeSegmentStartedAtUtc: _nowUtc().toUtc(),
      ),
    );
    // Update the in-memory authority before awaiting SQLite so a lifecycle
    // callback and the next user action cannot observe a stale paused state.
    state = state.copyWith(launch: activeLaunch, clearError: true);
    final saved = await _saveDraft(
      activeLaunch.state,
      allowDuringCompletion: false,
      useLatestState: true,
      expectedTimingRevision: revision,
    );
    if (saved && revision == _timingRevision) {
      _pendingPauseState = null;
      _pendingPauseDraftId = null;
    }
    if (!saved && mounted && revision == _timingRevision) {
      state = state.copyWith(launch: current);
      if (_pendingPauseDraftId == current.draftId) {
        _pendingPauseState = current.state;
      }
    }
    return saved;
  }

  Future<B02ExecutionDraftState> _ensureActiveSegment({
    required B02StrengthExecutionLaunch launch,
    required B02ExecutionDraftState state,
  }) async {
    if (state.activeSegmentStartedAtUtc != null) return state;
    final active = state.copyWith(activeSegmentStartedAtUtc: _nowUtc().toUtc());
    await _adapter.saveDraft(draftId: launch.draftId, state: active);
    return active;
  }

  B02ExecutionDraftState _stampElapsed(
    B02ExecutionDraftState draft, {
    required DateTime nowUtc,
  }) {
    final started = draft.activeSegmentStartedAtUtc;
    if (started == null) return draft;
    final now = nowUtc.toUtc();
    final added = now.difference(started).inSeconds;
    if (added <= 0) return draft;
    return draft.copyWith(
      elapsedSeconds: draft.elapsedSeconds + added,
      // Keep any fractional remainder in the active segment instead of
      // discarding up to a second at every durable save boundary.
      activeSegmentStartedAtUtc: started.add(Duration(seconds: added)),
    );
  }

  Future<T> _enqueueDraftWrite<T>(Future<T> Function() operation) {
    final next = _draftWriteTail.then<T>((_) => operation());
    _draftWriteTail = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return next;
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
      errorMessage: ProductFailurePresentation.fromCode(
        recovery ? 'workout_recovery_needed' : 'workout_save_failed',
      ).message,
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

extension _B02FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
