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
    B02LoadBasis? actualLoadBasis,
    int? rpe,
    B02SetRole role = B02SetRole.working,
    B02TechniqueFields? technique,
    String? actualExerciseId,
    String? actualExerciseNameSnapshot,
    String? substitutionReason,
    String? sourceExercisePrescriptionId,
    bool useSlotPrescription = true,
  }) {
    if (reps < 1) {
      throw const B02ValidationException('Repetitions must be positive.');
    }
    final performedId = 'performed:${slot.id}';
    final existingIndex = state.performedExercises.indexWhere(
      (exercise) => exercise.id == performedId,
    );
    final existing = existingIndex < 0
        ? null
        : state.performedExercises[existingIndex];
    // A recovered substitution remains the actual exercise until the user
    // explicitly chooses another one. Falling back to the planned slot here
    // would silently reattribute all earlier performed sets after resume.
    final canonicalExerciseId =
        (actualExerciseId ?? existing?.actualExerciseId ?? slot.exerciseId)
            ?.trim();
    if (canonicalExerciseId == null || canonicalExerciseId.isEmpty) {
      throw const B02ValidationException(
        'This slot has no resolved canonical exercise; recover the draft before logging it.',
      );
    }
    final offeredRecommendation =
        existing?.targetRecommendation ?? state.targetRecommendations[slot.id];
    final override = state.targetOverrides[slot.id];
    final ordinal = existing?.sets.length ?? 0;
    final set = B02PerformedSet(
      id: _nextSetId(performedId, existing?.sets ?? const []),
      performedExerciseId: performedId,
      ordinal: ordinal,
      role: role,
      targetLoadKg: override?.loadKg ?? slot.targetLoadKg,
      targetLoadBasis: override?.loadBasis ?? slot.targetLoadBasis,
      targetRepsMin: override?.targetRepsMin ?? slot.targetRepsMin,
      targetRepsMax: override?.targetRepsMax ?? slot.targetRepsMax,
      targetRpe: override?.targetRpe ?? slot.targetRpe,
      actualLoadKg: loadKg,
      actualLoadBasis:
          actualLoadBasis ??
          slot.targetLoadBasis ??
          (loadKg == null ? null : B02LoadBasis.totalExternal),
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
      sourceExercisePrescriptionId: useSlotPrescription
          ? sourceExercisePrescriptionId ?? slot.prescriptionId
          : null,
      groupMemberOrdinal: slot.memberOrdinal,
      groupRoundOrdinal: slot.roundOrdinal,
      ordinal: existing?.ordinal ?? state.performedExercises.length,
      expectedExerciseId: slot.exerciseId,
      expectedExerciseNameSnapshot: slot.exerciseNameSnapshot,
      actualExerciseId: canonicalExerciseId,
      actualExerciseNameSnapshot:
          actualExerciseNameSnapshot ??
          existing?.actualExerciseNameSnapshot ??
          slot.exerciseNameSnapshot,
      status: completed ? 'completed' : 'partial',
      substitutionReason: substitutionReason ?? existing?.substitutionReason,
      sets: sets,
      targetRecommendation: offeredRecommendation,
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
      targetRecommendations: {
        ...state.targetRecommendations,
        slot.id: ?offeredRecommendation,
      },
      performedExercises: updated,
    );
  }

  /// Applies a correction to one already logged set in the active draft.
  ///
  /// The set ID is the mutation identity. Display ordinals and list indexes
  /// are deliberately not accepted as a lookup key, so a row can be edited
  /// safely after another row has been removed.
  B02ExecutionDraftState editSet({
    required B02ExecutionDraftState state,
    required B02StrengthExecutionSlot slot,
    required String setId,
    required int reps,
    double? loadKg,
    B02LoadBasis? actualLoadBasis,
    int? rpe,
  }) {
    if (reps < 1) {
      throw const B02ValidationException('Repetitions must be positive.');
    }
    final match = _findSet(state: state, slot: slot, setId: setId);
    final exercise = state.performedExercises[match.exerciseIndex];
    final existing = exercise.sets[match.setIndex];
    if (existing.technique.segments.isNotEmpty) {
      final segmentReps = existing.technique.segments.fold<int>(
        0,
        (sum, segment) => sum + segment.reps,
      );
      if (reps != segmentReps) {
        throw const B02ValidationException(
          'Advanced set details must be edited together.',
        );
      }
    }
    final updatedSet = B02PerformedSet(
      id: existing.id,
      performedExerciseId: existing.performedExerciseId,
      ordinal: existing.ordinal,
      role: existing.role,
      targetLoadKg: existing.targetLoadKg,
      targetLoadBasis: existing.targetLoadBasis,
      targetRepsMin: existing.targetRepsMin,
      targetRepsMax: existing.targetRepsMax,
      targetRpe: existing.targetRpe,
      actualLoadKg: loadKg,
      actualLoadBasis: actualLoadBasis,
      actualReps: reps,
      actualRpe: rpe,
      technique: existing.technique,
      notes: existing.notes,
    );
    final updatedSets = [...exercise.sets];
    updatedSets[match.setIndex] = updatedSet;
    final updatedExercises = [...state.performedExercises];
    updatedExercises[match.exerciseIndex] = _replaceExercise(
      exercise,
      sets: updatedSets,
      status: _statusFor(sets: updatedSets, plannedSets: slot.plannedSets),
    );
    return state.copyWith(performedExercises: updatedExercises);
  }

  /// Removes one set from the active draft while retaining the performed-set
  /// IDs of every remaining row. Ordinals are presentation order only and are
  /// compacted after removal to satisfy the canonical draft invariant.
  B02ExecutionDraftState deleteSet({
    required B02ExecutionDraftState state,
    required B02StrengthExecutionSlot slot,
    required String setId,
  }) {
    final match = _findSet(state: state, slot: slot, setId: setId);
    final exercise = state.performedExercises[match.exerciseIndex];
    final remaining = [
      for (var index = 0; index < exercise.sets.length; index++)
        if (index != match.setIndex) exercise.sets[index],
    ];
    final renumbered = [
      for (var index = 0; index < remaining.length; index++)
        _copySet(remaining[index], ordinal: index),
    ];
    final updatedExercises = [...state.performedExercises];
    updatedExercises[match.exerciseIndex] = _replaceExercise(
      exercise,
      sets: renumbered,
      status: _statusFor(sets: renumbered, plannedSets: slot.plannedSets),
    );
    return state.copyWith(performedExercises: updatedExercises);
  }

  /// Changes the actual canonical exercise for one still-unlogged slot.
  ///
  /// The planned slot, prescription ancestry, and occurrence identity remain
  /// untouched. Once a set exists, the current B02 draft must retain that
  /// performed evidence rather than reattributing it to another exercise;
  /// the canonical replacement authority enforces that boundary before this
  /// mutation is called.
  B02ExecutionDraftState replaceExercise({
    required B02ExecutionDraftState state,
    required B02StrengthExecutionSlot slot,
    required String actualExerciseId,
    required String actualExerciseNameSnapshot,
    required String substitutionReason,
  }) {
    final replacementId = actualExerciseId.trim();
    final replacementName = actualExerciseNameSnapshot.trim();
    if (replacementId.isEmpty || replacementName.isEmpty) {
      throw const B02ValidationException(
        'A replacement needs a canonical exercise identity and name.',
      );
    }
    final performedId = 'performed:${slot.id}';
    final existingIndex = state.performedExercises.indexWhere(
      (exercise) => exercise.id == performedId,
    );
    final existing = existingIndex < 0
        ? null
        : state.performedExercises[existingIndex];
    final currentActualId = existing?.actualExerciseId ?? slot.exerciseId;
    if (replacementId == currentActualId) {
      throw const B02ValidationException(
        'The selected exercise is already in this slot.',
      );
    }
    if (existing?.sets.isNotEmpty == true) {
      throw const B02ValidationException(
        'Logged sets cannot be reassigned to another exercise.',
      );
    }
    final replaced = B02PerformedExerciseDraft(
      id: performedId,
      performedExerciseGroupId:
          existing?.performedExerciseGroupId ?? slot.groupId,
      sourceExercisePrescriptionId:
          existing?.sourceExercisePrescriptionId ?? slot.prescriptionId,
      groupMemberOrdinal: existing?.groupMemberOrdinal ?? slot.memberOrdinal,
      groupRoundOrdinal: existing?.groupRoundOrdinal ?? slot.roundOrdinal,
      ordinal: existing?.ordinal ?? state.performedExercises.length,
      expectedExerciseId: existing?.expectedExerciseId ?? slot.exerciseId,
      expectedExerciseNameSnapshot:
          existing?.expectedExerciseNameSnapshot ?? slot.exerciseNameSnapshot,
      actualExerciseId: replacementId,
      actualExerciseNameSnapshot: replacementName,
      status: 'partial',
      substitutionReason: substitutionReason.trim(),
      sets: existing?.sets ?? const [],
      targetRecommendation:
          existing?.targetRecommendation ??
          state.targetRecommendations[slot.id],
    );
    final updated = [...state.performedExercises];
    if (existingIndex < 0) {
      updated.add(replaced);
    } else {
      updated[existingIndex] = replaced;
    }
    return state.copyWith(performedExercises: updated);
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
    final offeredRecommendation =
        existing?.targetRecommendation ?? state.targetRecommendations[slot.id];
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
      targetRecommendation: offeredRecommendation,
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
      targetRecommendations: {
        ...state.targetRecommendations,
        slot.id: ?offeredRecommendation,
      },
      performedExercises: updated,
    );
  }

  B02ExecutionDraftState applyTargetOverride({
    required B02ExecutionDraftState state,
    required B02StrengthExecutionSlot slot,
    required B02TargetOverride override,
  }) {
    final recommendation = state.targetRecommendations[slot.id];
    if (recommendation == null) {
      throw const B02ValidationException(
        'A target override requires an existing recommendation.',
      );
    }
    final marked = recommendation.copyWith(wasOverridden: true);
    final performedId = 'performed:${slot.id}';
    final updatedExercises = [
      for (final exercise in state.performedExercises)
        exercise.id == performedId
            ? exercise.copyWith(targetRecommendation: marked)
            : exercise,
    ];
    return state.copyWith(
      targetRecommendations: {...state.targetRecommendations, slot.id: marked},
      targetOverrides: {...state.targetOverrides, slot.id: override},
      performedExercises: updatedExercises,
    );
  }

  String _nextSetId(String performedId, List<B02PerformedSet> existing) {
    final used = existing.map((set) => set.id).toSet();
    var sequence = existing.length;
    var candidate = '$performedId:set:$sequence';
    while (used.contains(candidate)) {
      sequence += 1;
      candidate = '$performedId:set:$sequence';
    }
    return candidate;
  }

  ({int exerciseIndex, int setIndex}) _findSet({
    required B02ExecutionDraftState state,
    required B02StrengthExecutionSlot slot,
    required String setId,
  }) {
    final trimmedId = setId.trim();
    if (trimmedId.isEmpty) {
      throw const B02ValidationException('This set is no longer available.');
    }
    final matches = <({int exerciseIndex, int setIndex})>[];
    for (
      var exerciseIndex = 0;
      exerciseIndex < state.performedExercises.length;
      exerciseIndex++
    ) {
      final exercise = state.performedExercises[exerciseIndex];
      for (var setIndex = 0; setIndex < exercise.sets.length; setIndex++) {
        if (exercise.sets[setIndex].id == trimmedId) {
          matches.add((exerciseIndex: exerciseIndex, setIndex: setIndex));
        }
      }
    }
    if (matches.length != 1) {
      throw const B02ValidationException('This set is no longer available.');
    }
    final match = matches.single;
    final exercise = state.performedExercises[match.exerciseIndex];
    final belongsToSlot =
        exercise.id == 'performed:${slot.id}' ||
        (exercise.sourceExercisePrescriptionId == slot.prescriptionId &&
            exercise.groupRoundOrdinal == slot.roundOrdinal &&
            exercise.groupMemberOrdinal == slot.memberOrdinal);
    if (!belongsToSlot) {
      throw const B02ValidationException('This set is no longer available.');
    }
    return match;
  }

  B02PerformedExerciseDraft _replaceExercise(
    B02PerformedExerciseDraft exercise, {
    required List<B02PerformedSet> sets,
    required String status,
  }) {
    return B02PerformedExerciseDraft(
      id: exercise.id,
      performedExerciseGroupId: exercise.performedExerciseGroupId,
      sourceExercisePrescriptionId: exercise.sourceExercisePrescriptionId,
      groupMemberOrdinal: exercise.groupMemberOrdinal,
      groupRoundOrdinal: exercise.groupRoundOrdinal,
      ordinal: exercise.ordinal,
      expectedExerciseId: exercise.expectedExerciseId,
      expectedExerciseNameSnapshot: exercise.expectedExerciseNameSnapshot,
      actualExerciseId: exercise.actualExerciseId,
      actualExerciseNameSnapshot: exercise.actualExerciseNameSnapshot,
      status: status,
      substitutionReason: exercise.substitutionReason,
      sets: sets,
      targetRecommendation: exercise.targetRecommendation,
    );
  }

  B02PerformedSet _copySet(B02PerformedSet set, {required int ordinal}) {
    return B02PerformedSet(
      id: set.id,
      performedExerciseId: set.performedExerciseId,
      ordinal: ordinal,
      role: set.role,
      targetLoadKg: set.targetLoadKg,
      targetLoadBasis: set.targetLoadBasis,
      targetRepsMin: set.targetRepsMin,
      targetRepsMax: set.targetRepsMax,
      targetRpe: set.targetRpe,
      actualLoadKg: set.actualLoadKg,
      actualLoadBasis: set.actualLoadBasis,
      actualReps: set.actualReps,
      actualRpe: set.actualRpe,
      technique: set.technique,
      notes: set.notes,
    );
  }

  String _statusFor({
    required List<B02PerformedSet> sets,
    required int plannedSets,
  }) {
    final workingSets = sets.where((set) => set.role == B02SetRole.working);
    return workingSets.length >= plannedSets ? 'completed' : 'partial';
  }

  B02ExecutionDraftState chooseWarmup(
    B02ExecutionDraftState state,
    B02WarmupDecision decision, {
    List<B02WarmupSetProposal>? selectedProposals,
  }) {
    final recommendation = state.warmupRecommendation;
    if (recommendation == null) {
      throw const B02ValidationException(
        'A warm-up decision requires an existing recommendation.',
      );
    }
    final selected =
        selectedProposals ??
        (decision == B02WarmupDecision.accepted
            ? recommendation.proposals
            : const <B02WarmupSetProposal>[]);
    return state.copyWith(
      warmupRecommendation: recommendation.copyWith(
        decision: decision,
        selectedProposals: selected,
      ),
    );
  }
}
