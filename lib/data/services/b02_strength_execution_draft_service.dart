import '../models/b02_execution_models.dart';

/// Pure draft mutations used by the B02 player. Persistence and finalization
/// remain repository concerns; this service only applies a validated user
/// action to the durable draft shape.
class B02StrengthExecutionDraftService {
  const B02StrengthExecutionDraftService();

  B02ExecutionDraftState recordSet({
    required B02ExecutionDraftState state,
    required B02StrengthExecutionSlot slot,
    required int reps,
    double? loadKg,
    int? rpe,
    B02SetRole role = B02SetRole.working,
    B02TechniqueFields? technique,
    String? actualExerciseId,
    String? actualExerciseNameSnapshot,
    String? substitutionReason,
  }) {
    if (reps < 1) {
      throw const B02ValidationException('Repetitions must be positive.');
    }
    final canonicalExerciseId = (actualExerciseId ?? slot.exerciseId)?.trim();
    if (canonicalExerciseId == null || canonicalExerciseId.isEmpty) {
      throw const B02ValidationException(
        'This slot has no resolved canonical exercise; recover the draft before logging it.',
      );
    }
    final performedId = 'performed:${slot.id}';
    final existingIndex = state.performedExercises.indexWhere(
      (exercise) => exercise.id == performedId,
    );
    final existing = existingIndex < 0
        ? null
        : state.performedExercises[existingIndex];
    final ordinal = existing?.sets.length ?? 0;
    final set = B02PerformedSet(
      id: '$performedId:set:$ordinal',
      performedExerciseId: performedId,
      ordinal: ordinal,
      role: role,
      targetLoadKg: slot.targetLoadKg,
      targetLoadBasis: slot.targetLoadBasis,
      targetRepsMin: slot.targetRepsMin,
      targetRepsMax: slot.targetRepsMax,
      targetRpe: slot.targetRpe,
      actualLoadKg: loadKg,
      actualLoadBasis: slot.targetLoadBasis,
      actualReps: reps,
      actualRpe: rpe,
      technique: technique,
    );
    final sets = [...?existing?.sets, set];
    final completed =
        role == B02SetRole.working &&
        sets.where((item) => item.role == B02SetRole.working).length >=
            slot.plannedSets;
    final performed = B02PerformedExerciseDraft(
      id: performedId,
      performedExerciseGroupId: slot.groupId,
      sourceExercisePrescriptionId: slot.prescriptionId,
      groupMemberOrdinal: slot.memberOrdinal,
      groupRoundOrdinal: slot.roundOrdinal,
      ordinal: existing?.ordinal ?? state.performedExercises.length,
      expectedExerciseId: slot.exerciseId,
      expectedExerciseNameSnapshot: slot.exerciseNameSnapshot,
      actualExerciseId: canonicalExerciseId,
      actualExerciseNameSnapshot:
          actualExerciseNameSnapshot ?? slot.exerciseNameSnapshot,
      status: completed ? 'completed' : 'partial',
      substitutionReason: substitutionReason ?? existing?.substitutionReason,
      sets: sets,
      targetRecommendation: existing?.targetRecommendation,
    );
    final updated = [...state.performedExercises];
    if (existingIndex < 0) {
      updated.add(performed);
    } else {
      updated[existingIndex] = performed;
    }
    return state.copyWith(
      elapsedSeconds: state.elapsedSeconds < 1 ? 1 : state.elapsedSeconds,
      currentGroupOrdinal: slot.groupOrdinal,
      currentGroupId: slot.groupId,
      currentRoundOrdinal: slot.roundOrdinal,
      currentMemberOrdinal: slot.memberOrdinal,
      currentExerciseOrdinal: performed.ordinal,
      currentSetOrdinal: ordinal,
      performedExercises: updated,
    );
  }

  B02ExecutionDraftState skipSlot({
    required B02ExecutionDraftState state,
    required B02StrengthExecutionSlot slot,
    String? reason,
  }) {
    if (!slot.hasCanonicalExercise) {
      throw const B02ValidationException(
        'This slot has no canonical exercise identity and cannot be finalized as skipped.',
      );
    }
    final performedId = 'performed:${slot.id}';
    final existingIndex = state.performedExercises.indexWhere(
      (exercise) => exercise.id == performedId,
    );
    final existing = existingIndex < 0
        ? null
        : state.performedExercises[existingIndex];
    final performed = B02PerformedExerciseDraft(
      id: performedId,
      performedExerciseGroupId: slot.groupId,
      sourceExercisePrescriptionId: slot.prescriptionId,
      groupMemberOrdinal: slot.memberOrdinal,
      groupRoundOrdinal: slot.roundOrdinal,
      ordinal: existing?.ordinal ?? state.performedExercises.length,
      expectedExerciseId: slot.exerciseId,
      expectedExerciseNameSnapshot: slot.exerciseNameSnapshot,
      actualExerciseId: slot.exerciseId!,
      actualExerciseNameSnapshot: slot.exerciseNameSnapshot,
      status: 'skipped',
      substitutionReason: reason,
      sets: existing?.sets ?? const [],
      targetRecommendation: existing?.targetRecommendation,
    );
    final updated = [...state.performedExercises];
    if (existingIndex < 0) {
      updated.add(performed);
    } else {
      updated[existingIndex] = performed;
    }
    return state.copyWith(
      elapsedSeconds: state.elapsedSeconds < 1 ? 1 : state.elapsedSeconds,
      currentGroupOrdinal: slot.groupOrdinal,
      currentGroupId: slot.groupId,
      currentRoundOrdinal: slot.roundOrdinal,
      currentMemberOrdinal: slot.memberOrdinal,
      currentExerciseOrdinal: performed.ordinal,
      currentSetOrdinal: existing?.sets.length ?? 0,
      performedExercises: updated,
    );
  }
}
