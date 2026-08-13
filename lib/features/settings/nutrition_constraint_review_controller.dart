import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nutrition_constraints.dart';
import '../../data/repositories/nutrition_constraint_repository.dart';

enum NutritionConstraintEvaluationReviewStatus {
  idle,
  loading,
  success,
  failure,
}

class NutritionConstraintEvaluationReviewState {
  final NutritionConstraintEvaluationReviewStatus status;
  final NutritionConstraintEvaluationResult? evaluation;
  final String? errorCode;
  final String? message;

  const NutritionConstraintEvaluationReviewState({
    this.status = NutritionConstraintEvaluationReviewStatus.idle,
    this.evaluation,
    this.errorCode,
    this.message,
  });

  NutritionConstraintEvaluationReviewState copyWith({
    NutritionConstraintEvaluationReviewStatus? status,
    NutritionConstraintEvaluationResult? evaluation,
    bool clearEvaluation = false,
    String? errorCode,
    bool clearError = false,
    String? message,
    bool clearMessage = false,
  }) => NutritionConstraintEvaluationReviewState(
    status: status ?? this.status,
    evaluation: clearEvaluation ? null : evaluation ?? this.evaluation,
    errorCode: clearError ? null : errorCode ?? this.errorCode,
    message: clearMessage ? null : message ?? this.message,
  );
}

/// Controller for a pre-resolved review surface. It accepts portable food or
/// immutable recipe-version identity from the owning selection flow; it never
/// resolves display text and never performs evaluation arithmetic.
class NutritionConstraintEvaluationReviewController
    extends StateNotifier<NutritionConstraintEvaluationReviewState> {
  final NutritionConstraintRepository _repository;
  final String _userId;
  String? _lastFoodId;
  String? _lastRecipeVersionId;

  NutritionConstraintEvaluationReviewController({
    required NutritionConstraintRepository repository,
    required String userId,
  }) : _repository = repository,
       _userId = userId,
       super(const NutritionConstraintEvaluationReviewState());

  Future<void> reviewFood(String foodId) async {
    final id = foodId.trim();
    _lastFoodId = id;
    _lastRecipeVersionId = null;
    await _run(() => _repository.evaluateFood(userId: _userId, foodId: id));
  }

  Future<void> reviewRecipeVersion(String recipeVersionId) async {
    final id = recipeVersionId.trim();
    _lastFoodId = null;
    _lastRecipeVersionId = id;
    await _run(
      () => _repository.evaluateRecipeVersion(
        userId: _userId,
        recipeVersionId: id,
      ),
    );
  }

  Future<void> retry() async {
    if (_lastFoodId != null) return reviewFood(_lastFoodId!);
    if (_lastRecipeVersionId != null) {
      return reviewRecipeVersion(_lastRecipeVersionId!);
    }
    state = state.copyWith(
      status: NutritionConstraintEvaluationReviewStatus.failure,
      errorCode: 'missing_review_subject',
      message: 'Choose a food or recipe before reviewing this check.',
    );
  }

  Future<void> _run(
    Future<NutritionConstraintEvaluationResult> Function() operation,
  ) async {
    state = state.copyWith(
      status: NutritionConstraintEvaluationReviewStatus.loading,
      clearError: true,
      clearMessage: true,
    );
    try {
      final evaluation = await operation();
      state = state.copyWith(
        status: NutritionConstraintEvaluationReviewStatus.success,
        evaluation: evaluation,
        clearError: true,
        clearMessage: true,
      );
    } catch (error) {
      final typed = error is NutritionConstraintError ? error : null;
      state = state.copyWith(
        status: NutritionConstraintEvaluationReviewStatus.failure,
        errorCode: typed?.code ?? 'constraint_review_failed',
        message: 'We couldn’t complete this dietary check. Try again.',
      );
    }
  }
}
