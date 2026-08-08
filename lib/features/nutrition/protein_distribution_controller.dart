import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nutrition_protein_distribution.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../data/repositories/nutrition_protein_distribution_repository.dart';

enum NutritionProteinDistributionStatus { idle, loading, ready, empty, failure }

class NutritionProteinDistributionState {
  final NutritionProteinDistributionStatus status;
  final NutritionProteinDistribution? distribution;
  final String? errorCode;
  final String? errorMessage;
  final bool retryable;

  const NutritionProteinDistributionState({
    this.status = NutritionProteinDistributionStatus.idle,
    this.distribution,
    this.errorCode,
    this.errorMessage,
    this.retryable = false,
  });

  bool get isLoading => status == NutritionProteinDistributionStatus.loading;

  NutritionProteinDistributionState copyWith({
    NutritionProteinDistributionStatus? status,
    NutritionProteinDistribution? distribution,
    bool clearDistribution = false,
    String? errorCode,
    String? errorMessage,
    bool clearError = false,
    bool? retryable,
  }) => NutritionProteinDistributionState(
    status: status ?? this.status,
    distribution: clearDistribution ? null : distribution ?? this.distribution,
    errorCode: clearError ? null : errorCode ?? this.errorCode,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    retryable: retryable ?? this.retryable,
  );
}

/// State owner for the descriptive protein view. It performs no nutrient
/// arithmetic and does not access Drift; the read-only repository owns both.
class NutritionProteinDistributionController
    extends StateNotifier<NutritionProteinDistributionState> {
  final Future<NutritionProteinDistributionRepository> _repositoryFuture;
  final String userId;
  final String localDate;
  Future<void> Function()? _lastRetry;
  int _loadGeneration = 0;

  NutritionProteinDistributionController({
    required Future<NutritionProteinDistributionRepository> repository,
    required this.userId,
    required this.localDate,
  }) : _repositoryFuture = repository,
       super(const NutritionProteinDistributionState());

  Future<void> load() async {
    final generation = ++_loadGeneration;
    state = state.copyWith(
      status: NutritionProteinDistributionStatus.loading,
      clearError: true,
      retryable: false,
    );
    _lastRetry = load;
    try {
      final distribution = await (await _repositoryFuture).forLocalDate(
        userId: userId,
        localDate: localDate,
      );
      if (!mounted || generation != _loadGeneration) return;
      state = state.copyWith(
        status: distribution.isEmpty
            ? NutritionProteinDistributionStatus.empty
            : NutritionProteinDistributionStatus.ready,
        distribution: distribution,
        clearError: true,
        retryable: false,
      );
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      final typed = error is NutritionProteinDistributionError ? error : null;
      state = state.copyWith(
        status: NutritionProteinDistributionStatus.failure,
        errorCode: typed?.code ?? 'protein_distribution_failed',
        errorMessage: ProductFailurePresentation.fromCode(
          typed?.code ?? 'protein_distribution_failed',
        ).message,
        retryable: true,
      );
    }
  }

  Future<void> retry() async {
    final retryAction = _lastRetry;
    if (retryAction != null) await retryAction();
  }
}
