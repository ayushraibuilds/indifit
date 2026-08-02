import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/b02_activity_session_repository.dart';

enum B02ActivityControllerStatus {
  idle,
  loading,
  draftReady,
  ready,
  partial,
  completed,
  error,
  failure,
  recovery,
}

class B02ActivityControllerState {
  final B02ActivityControllerStatus status;
  final B02ActivityDraftRecord? draft;
  final int? completedSessionId;
  final String? errorMessage;

  const B02ActivityControllerState({
    required this.status,
    this.draft,
    this.completedSessionId,
    this.errorMessage,
  });

  const B02ActivityControllerState.idle()
    : status = B02ActivityControllerStatus.idle,
      draft = null,
      completedSessionId = null,
      errorMessage = null;

  B02ActivityControllerState copyWith({
    B02ActivityControllerStatus? status,
    B02ActivityDraftRecord? draft,
    int? completedSessionId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return B02ActivityControllerState(
      status: status ?? this.status,
      draft: draft ?? this.draft,
      completedSessionId: completedSessionId ?? this.completedSessionId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  bool get isBusy => status == B02ActivityControllerStatus.loading;
}

class B02ActivityController extends StateNotifier<B02ActivityControllerState> {
  final ActivitySessionRepository _repository;

  B02ActivityController(this._repository)
    : super(const B02ActivityControllerState.idle());

  Future<void> startManual({
    required String routineName,
    required B02ActivityType activityType,
    B02CardioSessionDetail? cardioDetail,
    B02MobilitySessionDetail? mobilityDetail,
  }) async {
    state = const B02ActivityControllerState(
      status: B02ActivityControllerStatus.loading,
    );
    try {
      final draft = await _repository.startManualDraft(
        routineName: routineName,
        activityType: activityType,
        cardioDetail: cardioDetail,
        mobilityDetail: mobilityDetail,
      );
      if (!mounted) return;
      state = B02ActivityControllerState(
        status: B02ActivityControllerStatus.draftReady,
        draft: draft,
      );
    } catch (error) {
      if (!mounted) return;
      state = B02ActivityControllerState(
        status: B02ActivityControllerStatus.failure,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> saveDraft(B02ExecutionDraftState draft) async {
    final currentDraft = state.draft;
    if (currentDraft == null) {
      state = const B02ActivityControllerState(
        status: B02ActivityControllerStatus.recovery,
        errorMessage: 'No activity draft is loaded.',
      );
      return;
    }
    state = B02ActivityControllerState(
      status: B02ActivityControllerStatus.loading,
      draft: currentDraft,
    );
    try {
      await _repository.saveDraft(draftId: currentDraft.id, state: draft);
      final restored = await _repository.readDraft(currentDraft.id);
      if (!mounted) return;
      state = B02ActivityControllerState(
        status: B02ActivityControllerStatus.partial,
        draft: restored,
      );
    } catch (error) {
      if (!mounted) return;
      state = B02ActivityControllerState(
        status: B02ActivityControllerStatus.failure,
        draft: currentDraft,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> completeDraft() async {
    final currentDraft = state.draft;
    if (currentDraft == null) {
      state = const B02ActivityControllerState(
        status: B02ActivityControllerStatus.recovery,
        errorMessage: 'No activity draft is loaded.',
      );
      return;
    }
    state = B02ActivityControllerState(
      status: B02ActivityControllerStatus.loading,
      draft: currentDraft,
    );
    try {
      final sessionId = await _repository.completeDraft(currentDraft.id);
      if (!mounted) return;
      state = B02ActivityControllerState(
        status: B02ActivityControllerStatus.completed,
        completedSessionId: sessionId,
      );
    } catch (error) {
      if (!mounted) return;
      state = B02ActivityControllerState(
        status: B02ActivityControllerStatus.failure,
        draft: currentDraft,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> recover(int draftId) async {
    state = const B02ActivityControllerState(
      status: B02ActivityControllerStatus.loading,
    );
    try {
      final draft = await _repository.readDraft(draftId);
      if (!mounted) return;
      if (draft == null) {
        state = const B02ActivityControllerState(
          status: B02ActivityControllerStatus.recovery,
          errorMessage:
              'The typed activity draft is unavailable or legacy-shaped.',
        );
        return;
      }
      state = B02ActivityControllerState(
        status: B02ActivityControllerStatus.draftReady,
        draft: draft,
      );
    } catch (error) {
      if (!mounted) return;
      state = B02ActivityControllerState(
        status: B02ActivityControllerStatus.recovery,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> discard() async {
    final currentDraft = state.draft;
    if (currentDraft == null) {
      state = const B02ActivityControllerState(
        status: B02ActivityControllerStatus.recovery,
        errorMessage: 'No activity draft is loaded.',
      );
      return;
    }
    state = B02ActivityControllerState(
      status: B02ActivityControllerStatus.loading,
      draft: currentDraft,
    );
    try {
      await _repository.discardDraft(currentDraft.id);
      if (!mounted) return;
      state = const B02ActivityControllerState.idle();
    } catch (error) {
      if (!mounted) return;
      state = B02ActivityControllerState(
        status: B02ActivityControllerStatus.failure,
        draft: currentDraft,
        errorMessage: error.toString(),
      );
    }
  }
}

final b02ActivitySessionRepositoryProvider =
    Provider<ActivitySessionRepository>(
      (ref) => ActivitySessionRepository(ref.watch(databaseProvider)),
    );

final b02ActivityControllerProvider =
    StateNotifierProvider<B02ActivityController, B02ActivityControllerState>(
      (ref) => B02ActivityController(
        ref.watch(b02ActivitySessionRepositoryProvider),
      ),
    );
