import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nutrients.dart';
import '../../core/nutrition_estimates.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../data/repositories/nutrition_estimate_repository.dart';

enum NutritionEstimateReviewControllerStatus {
  idle,
  loading,
  ready,
  partial,
  accepting,
  correcting,
  accepted,
  corrected,
  rejecting,
  rejected,
  failure,
}

class NutritionEstimateReviewControllerState {
  final NutritionEstimateReviewControllerStatus status;
  final NutritionEstimate? estimate;
  final String? errorCode;
  final String? errorMessage;
  final bool retryable;

  const NutritionEstimateReviewControllerState({
    required this.status,
    required this.estimate,
    required this.errorCode,
    required this.errorMessage,
    required this.retryable,
  });

  const NutritionEstimateReviewControllerState.idle()
    : status = NutritionEstimateReviewControllerStatus.idle,
      estimate = null,
      errorCode = null,
      errorMessage = null,
      retryable = false;

  bool get isBusy =>
      status == NutritionEstimateReviewControllerStatus.loading ||
      status == NutritionEstimateReviewControllerStatus.accepting ||
      status == NutritionEstimateReviewControllerStatus.correcting ||
      status == NutritionEstimateReviewControllerStatus.rejecting;

  bool get isPartial =>
      estimate?.completeness.state == NutrientCompletenessState.partial ||
      estimate?.completeness.state == NutrientCompletenessState.unknown;

  NutritionEstimateReviewControllerState copyWith({
    NutritionEstimateReviewControllerStatus? status,
    NutritionEstimate? estimate,
    bool clearEstimate = false,
    String? errorCode,
    String? errorMessage,
    bool clearError = false,
    bool? retryable,
  }) {
    return NutritionEstimateReviewControllerState(
      status: status ?? this.status,
      estimate: clearEstimate ? null : estimate ?? this.estimate,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      retryable: retryable ?? this.retryable,
    );
  }
}

/// Bounded review/correction state owner. It contains no nutrient arithmetic
/// and never accesses Drift; all mutations go through the estimate repository.
class NutritionEstimateReviewController
    extends StateNotifier<NutritionEstimateReviewControllerState> {
  final NutritionEstimateRepository _repository;
  final String userId;
  String? _estimateId;
  Future<void> Function()? _lastRetry;

  NutritionEstimateReviewController({
    required NutritionEstimateRepository repository,
    required this.userId,
    String? estimateId,
  }) : _repository = repository,
       _estimateId = estimateId?.trim(),
       super(const NutritionEstimateReviewControllerState.idle());

  Future<void> load({String? estimateId}) async {
    _estimateId = (estimateId ?? _estimateId)?.trim();
    final id = _estimateId;
    if (id == null || id.isEmpty) {
      state = state.copyWith(
        status: NutritionEstimateReviewControllerStatus.failure,
        errorCode: 'missing_estimate',
        errorMessage: 'No estimate was selected.',
        retryable: false,
      );
      return;
    }
    state = state.copyWith(
      status: NutritionEstimateReviewControllerStatus.loading,
      clearError: true,
      retryable: false,
    );
    _lastRetry = () => load(estimateId: id);
    try {
      final estimate = await _repository.getEstimate(
        userId: userId,
        estimateId: id,
      );
      if (estimate == null) {
        throw const NutritionEstimateValidationError(
          'missing_estimate',
          'This estimate is no longer available for review.',
        );
      }
      state = state.copyWith(
        status:
            estimate.completeness.state == NutrientCompletenessState.partial ||
                estimate.completeness.state == NutrientCompletenessState.unknown
            ? NutritionEstimateReviewControllerStatus.partial
            : NutritionEstimateReviewControllerStatus.ready,
        estimate: estimate,
        clearError: true,
        retryable: false,
      );
    } catch (error) {
      _fail(error, retryable: true);
    }
  }

  Future<void> accept({String? commandId}) async {
    final estimate = state.estimate;
    if (estimate == null) return;
    state = state.copyWith(
      status: NutritionEstimateReviewControllerStatus.accepting,
      clearError: true,
      retryable: true,
    );
    _lastRetry = () => accept(commandId: commandId);
    try {
      final accepted = await _repository.acceptEstimate(
        userId: userId,
        estimateId: estimate.id,
        commandId: commandId,
      );
      state = state.copyWith(
        status: NutritionEstimateReviewControllerStatus.accepted,
        estimate: accepted,
        clearError: true,
        retryable: false,
      );
    } catch (error) {
      _fail(error, retryable: true);
    }
  }

  Future<void> reject({String? commandId}) async {
    final estimate = state.estimate;
    if (estimate == null) return;
    state = state.copyWith(
      status: NutritionEstimateReviewControllerStatus.rejecting,
      clearError: true,
      retryable: true,
    );
    _lastRetry = () => reject(commandId: commandId);
    try {
      final rejected = await _repository.rejectEstimate(
        userId: userId,
        estimateId: estimate.id,
        commandId: commandId,
      );
      state = state.copyWith(
        status: NutritionEstimateReviewControllerStatus.rejected,
        estimate: rejected,
        clearError: true,
        retryable: false,
      );
    } catch (error) {
      _fail(error, retryable: true);
    }
  }

  Future<void> correct({
    required NutritionEstimateCorrection correction,
  }) async {
    final estimate = state.estimate;
    if (estimate == null) return;
    state = state.copyWith(
      status: NutritionEstimateReviewControllerStatus.correcting,
      clearError: true,
      retryable: true,
    );
    _lastRetry = () => correct(correction: correction);
    try {
      final corrected = await _repository.correctEstimate(
        userId: userId,
        estimateId: estimate.id,
        correction: correction,
      );
      _estimateId = corrected.id;
      state = state.copyWith(
        status: NutritionEstimateReviewControllerStatus.corrected,
        estimate: corrected,
        clearError: true,
        retryable: false,
      );
    } catch (error) {
      _fail(error, retryable: true);
    }
  }

  Future<void> retry() async {
    final retryAction = _lastRetry;
    if (retryAction != null) await retryAction();
  }

  void _fail(Object error, {required bool retryable}) {
    final code = error is NutritionEstimateError
        ? error is NutritionEstimateValidationError
              ? error.code
              : error is NutritionEstimateConflictError
              ? error.code
              : error is NutritionEstimatePersistenceError
              ? error.code
              : 'estimate_operation_failed'
        : 'estimate_operation_failed';
    final message = ProductFailurePresentation.fromCode(code).message;
    state = state.copyWith(
      status: NutritionEstimateReviewControllerStatus.failure,
      errorCode: code,
      errorMessage: message,
      retryable: retryable,
    );
  }
}
