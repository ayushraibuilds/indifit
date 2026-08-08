import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nutrition_constraints.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../data/repositories/nutrition_constraint_repository.dart';

enum NutritionConstraintManagementStatus {
  loading,
  ready,
  empty,
  saving,
  archiving,
  success,
  failure,
}

class NutritionConstraintManagementState {
  final NutritionConstraintManagementStatus status;
  final List<NutritionConstraintDefinition> definitions;
  final List<NutritionUserConstraint> constraints;
  final String? errorCode;
  final String? message;

  const NutritionConstraintManagementState({
    this.status = NutritionConstraintManagementStatus.loading,
    this.definitions = const [],
    this.constraints = const [],
    this.errorCode,
    this.message,
  });

  NutritionConstraintManagementState copyWith({
    NutritionConstraintManagementStatus? status,
    List<NutritionConstraintDefinition>? definitions,
    List<NutritionUserConstraint>? constraints,
    String? errorCode,
    bool clearError = false,
    String? message,
    bool clearMessage = false,
  }) => NutritionConstraintManagementState(
    status: status ?? this.status,
    definitions: definitions ?? this.definitions,
    constraints: constraints ?? this.constraints,
    errorCode: clearError ? null : errorCode ?? this.errorCode,
    message: clearMessage ? null : message ?? this.message,
  );
}

/// Bounded orchestration owner for the settings management surface. It does
/// not evaluate food or recipe composition; that remains in the repository's
/// pure evaluator boundary.
class NutritionConstraintManagementController
    extends StateNotifier<NutritionConstraintManagementState> {
  final NutritionConstraintRepository _repository;
  final String _userId;

  NutritionConstraintManagementController({
    required NutritionConstraintRepository repository,
    required String userId,
  }) : _repository = repository,
       _userId = userId,
       super(const NutritionConstraintManagementState());

  NutritionConstraintManagementState get currentState => state;

  Future<void> load() async {
    state = state.copyWith(
      status: NutritionConstraintManagementStatus.loading,
      clearError: true,
      clearMessage: true,
    );
    try {
      final definitions = await _repository.listTaxonomy();
      final constraints = await _repository.listAllConstraints(userId: _userId);
      state = state.copyWith(
        status: constraints.isEmpty
            ? NutritionConstraintManagementStatus.empty
            : NutritionConstraintManagementStatus.ready,
        definitions: definitions,
        constraints: constraints,
        clearError: true,
        clearMessage: true,
      );
    } catch (error) {
      _failure(error);
    }
  }

  Future<void> addConstraint({
    required NutritionConstraintType type,
    required NutritionConstraintTarget target,
    NutritionConstraintStrictness strictness =
        NutritionConstraintStrictness.avoid,
    String? severity,
    bool crossContact = false,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    String? notes,
  }) async {
    state = state.copyWith(
      status: NutritionConstraintManagementStatus.saving,
      clearError: true,
      clearMessage: true,
    );
    try {
      final saved = await _repository.createUserConstraint(
        userId: _userId,
        type: type,
        target: target,
        strictness: strictness,
        severity: severity,
        crossContact: crossContact,
        effectiveFrom: effectiveFrom,
        effectiveTo: effectiveTo,
        notes: notes,
      );
      final next = [...state.constraints, saved]
        ..sort((a, b) => a.updatedAtUtc.compareTo(b.updatedAtUtc));
      state = state.copyWith(
        status: NutritionConstraintManagementStatus.success,
        constraints: next,
        message: 'Constraint saved.',
        clearError: true,
      );
    } catch (error) {
      _failure(error);
    }
  }

  Future<void> archiveConstraint(String constraintId) async {
    state = state.copyWith(
      status: NutritionConstraintManagementStatus.archiving,
      clearError: true,
      clearMessage: true,
    );
    try {
      await _repository.archiveConstraint(
        userId: _userId,
        constraintId: constraintId,
      );
      final next = state.constraints
          .map(
            (item) =>
                item.id == constraintId ? item.copyWith(isActive: false) : item,
          )
          .toList(growable: false);
      state = state.copyWith(
        status: next.where((item) => item.isActive).isEmpty
            ? NutritionConstraintManagementStatus.empty
            : NutritionConstraintManagementStatus.success,
        constraints: next,
        message: 'Constraint archived.',
        clearError: true,
      );
    } catch (error) {
      _failure(error);
    }
  }

  Future<void> updateConstraint(NutritionUserConstraint constraint) async {
    if (constraint.userId != _userId) {
      _failure(
        const NutritionConstraintValidationError(
          'constraint_ownership',
          'A dietary constraint can only be edited by its owner.',
        ),
      );
      return;
    }
    state = state.copyWith(
      status: NutritionConstraintManagementStatus.saving,
      clearError: true,
      clearMessage: true,
    );
    try {
      final saved = await _repository.updateConstraint(constraint);
      final next = [
        for (final item in state.constraints)
          if (item.id == saved.id) saved else item,
      ];
      state = state.copyWith(
        status: NutritionConstraintManagementStatus.success,
        constraints: next,
        message: 'Constraint updated.',
        clearError: true,
      );
    } catch (error) {
      _failure(error);
    }
  }

  Future<void> retry() => load();

  void _failure(Object error) {
    final typed = error is NutritionConstraintError ? error : null;
    state = state.copyWith(
      status: NutritionConstraintManagementStatus.failure,
      errorCode: typed?.code ?? 'constraint_operation_failed',
      message: ProductFailurePresentation.fromCode(
        typed?.code ?? 'constraint_operation_failed',
        title: 'Dietary preferences unavailable',
      ).message,
    );
  }
}
