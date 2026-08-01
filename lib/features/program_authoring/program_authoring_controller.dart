import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ProgramAuthoringStatus { idle, loading, partial, failure, recovery }

/// Ephemeral authoring command state. The graph itself remains owned by the
/// screen until it is submitted to [ProgramRepository]; this state only
/// describes the field-editing command lifecycle.
class ProgramAuthoringUiState {
  final ProgramAuthoringStatus status;
  final String? errorMessage;

  const ProgramAuthoringUiState({
    this.status = ProgramAuthoringStatus.idle,
    this.errorMessage,
  });

  bool get isBusy =>
      status == ProgramAuthoringStatus.loading ||
      status == ProgramAuthoringStatus.recovery;

  ProgramAuthoringUiState copyWith({
    ProgramAuthoringStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProgramAuthoringUiState(
      status: status ?? this.status,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final programAuthoringControllerProvider =
    StateNotifierProvider.autoDispose<
      ProgramAuthoringController,
      ProgramAuthoringUiState
    >((ref) => ProgramAuthoringController());

/// Owns only transient authoring command state. Program graph validation and
/// persistence remain in ProgramRepository, so this controller cannot become
/// a second source of relational truth.
class ProgramAuthoringController
    extends StateNotifier<ProgramAuthoringUiState> {
  ProgramAuthoringController() : super(const ProgramAuthoringUiState());

  void beginLoading() {
    state = state.copyWith(
      status: ProgramAuthoringStatus.loading,
      clearError: true,
    );
  }

  void markEdited() {
    state = state.copyWith(
      status: ProgramAuthoringStatus.partial,
      clearError: true,
    );
  }

  void markReady() {
    state = state.copyWith(
      status: ProgramAuthoringStatus.idle,
      clearError: true,
    );
  }

  void markFailure(Object error) {
    state = state.copyWith(
      status: ProgramAuthoringStatus.failure,
      errorMessage: '$error',
    );
  }

  /// Marks a retained in-memory draft as recoverable before a retry/load.
  void recover() {
    state = state.copyWith(
      status: ProgramAuthoringStatus.recovery,
      clearError: true,
    );
  }

  Future<T> run<T>(Future<T> Function() operation) async {
    beginLoading();
    try {
      final result = await operation();
      markReady();
      return result;
    } catch (error) {
      markFailure(error);
      rethrow;
    }
  }
}
