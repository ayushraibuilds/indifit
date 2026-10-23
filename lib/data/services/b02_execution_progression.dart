import '../models/b02_execution_models.dart';

/// Read-only progression helpers for the canonical B02 execution graph.
///
/// The repository supplies the ordered slot read model and the draft supplies
/// the persisted cursor. This helper only reconciles those two authorities; it
/// does not create a schedule or infer a group from neighboring slots.
///
/// It holds one load rule, added on purpose (UF-12): the next-set
/// suggestion by double progression ([nextSetSuggestion]). It is only ever
/// shown as a suggestion; nothing here changes a draft or a prescription.
abstract final class B02ExecutionProgression {
  /// UF-12 double progression, from the last session's working sets of this
  /// exercise ([lastWorkingSets], in order) and the planned rep range:
  ///
  /// - every working set at the same load reached [repsMax] → that load
  ///   plus [stepKg];
  /// - any working set under [repsMin] → keep the load;
  /// - otherwise → one more rep than last time.
  ///
  /// Null without history, without a rep range, or when an increase is due
  /// but no step is known. Callers leave out sets the rule can't read
  /// (bodyweight, assisted, timed, tempo, drop sets).
  static B02NextSetSuggestion? nextSetSuggestion({
    required List<({double loadKg, int reps})> lastWorkingSets,
    required int? repsMin,
    required int? repsMax,
    required double? stepKg,
  }) {
    if (lastWorkingSets.isEmpty ||
        repsMin == null ||
        repsMax == null ||
        repsMin < 1 ||
        repsMax < repsMin) {
      return null;
    }
    final first = lastWorkingSets.first;
    final sameLoad = lastWorkingSets.every(
      (set) => (set.loadKg - first.loadKg).abs() < 0.001,
    );
    if (sameLoad && lastWorkingSets.every((set) => set.reps >= repsMax)) {
      final step = stepKg;
      if (step == null || !step.isFinite || step <= 0) return null;
      return B02NextSetSuggestion(
        rule: B02NextSetRule.addLoad,
        lastSets: lastWorkingSets,
        repsMin: repsMin,
        repsMax: repsMax,
        loadKg: first.loadKg + step,
        reps: repsMin,
      );
    }
    if (lastWorkingSets.any((set) => set.reps < repsMin)) {
      final last = lastWorkingSets.last;
      return B02NextSetSuggestion(
        rule: B02NextSetRule.keepLoad,
        lastSets: lastWorkingSets,
        repsMin: repsMin,
        repsMax: repsMax,
        loadKg: last.loadKg,
        reps: null,
      );
    }
    return B02NextSetSuggestion(
      rule: B02NextSetRule.oneMoreRep,
      lastSets: lastWorkingSets,
      repsMin: repsMin,
      repsMax: repsMax,
      loadKg: first.loadKg,
      reps: first.reps + 1,
    );
  }

  static B02StrengthExecutionSlot? cursorSlot({
    required B02ExecutionDraftState state,
    required List<B02StrengthExecutionSlot> slots,
  }) {
    final groupId = state.currentGroupId;
    if (groupId != null) {
      if (state.currentRoundOrdinal == null ||
          state.currentMemberOrdinal == null ||
          !state.groups.any((group) => group.id == groupId)) {
        return null;
      }
      return slots
          .where(
            (slot) =>
                slot.groupId == groupId &&
                slot.roundOrdinal == state.currentRoundOrdinal &&
                slot.memberOrdinal == state.currentMemberOrdinal,
          )
          .firstOrNull;
    }
    if (state.currentRoundOrdinal != null ||
        state.currentMemberOrdinal != null ||
        state.currentGroupOrdinal != null) {
      return null;
    }
    if (state.currentExerciseOrdinal < 0 ||
        state.currentExerciseOrdinal >= slots.length) {
      return null;
    }
    return slots[state.currentExerciseOrdinal];
  }

  /// Advances a Planned cursor after a completed working slot.
  ///
  /// A partially logged slot remains current. Group progression is exact:
  /// member order within the round, then the next round, then the next slot in
  /// the repository's canonical read order. If the graph cannot identify the
  /// next position, the caller keeps the last safe cursor instead of guessing.
  static B02ExecutionDraftState advanceAfterCompletedSlot({
    required B02ExecutionDraftState state,
    required List<B02StrengthExecutionSlot> slots,
    required B02StrengthExecutionSlot current,
  }) {
    final performed = _performedForSlot(state, current);
    final workingCount =
        performed?.sets.where((set) => set.role == B02SetRole.working).length ??
        0;
    if (workingCount < current.plannedSets) return state;
    return _moveToNext(state: state, slots: slots, current: current);
  }

  /// Advances a Planned cursor after an explicit skip of the current slot.
  static B02ExecutionDraftState advanceAfterSkippedSlot({
    required B02ExecutionDraftState state,
    required List<B02StrengthExecutionSlot> slots,
    required B02StrengthExecutionSlot current,
  }) {
    return _moveToNext(state: state, slots: slots, current: current);
  }

  /// Returns the next slot using the same persisted group/member/round
  /// ordering used by cursor advancement. This is a read-only presentation
  /// seam; it adds no ordering rule and does not mutate the draft. (The
  /// one load rule here is [nextSetSuggestion].)
  static B02StrengthExecutionSlot? nextSlot({
    required B02ExecutionDraftState state,
    required List<B02StrengthExecutionSlot> slots,
    required B02StrengthExecutionSlot current,
  }) {
    return _nextSlot(state: state, slots: slots, current: current);
  }

  static B02ExecutionDraftState _moveToNext({
    required B02ExecutionDraftState state,
    required List<B02StrengthExecutionSlot> slots,
    required B02StrengthExecutionSlot current,
  }) {
    final next = _nextSlot(state: state, slots: slots, current: current);
    if (next == null) return state;
    final index = slots.indexWhere((slot) => slot.id == next.id);
    if (index < 0) return state;
    return state.copyWith(
      currentGroupOrdinal: next.groupOrdinal,
      currentGroupId: next.groupId,
      currentRoundOrdinal: next.roundOrdinal,
      currentMemberOrdinal: next.memberOrdinal,
      currentExerciseOrdinal: index,
      currentSetOrdinal: 0,
    );
  }

  static B02StrengthExecutionSlot? _nextSlot({
    required B02ExecutionDraftState state,
    required List<B02StrengthExecutionSlot> slots,
    required B02StrengthExecutionSlot current,
  }) {
    final groupId = current.groupId;
    if (groupId != null) {
      final group = state.groups
          .where((candidate) => candidate.id == groupId)
          .firstOrNull;
      if (group == null ||
          current.roundOrdinal == null ||
          current.memberOrdinal == null) {
        return null;
      }
      final roundSlots =
          slots
              .where(
                (slot) =>
                    slot.groupId == groupId &&
                    slot.roundOrdinal == current.roundOrdinal,
              )
              .toList()
            ..sort(
              (left, right) => (left.memberOrdinal ?? -1).compareTo(
                right.memberOrdinal ?? -1,
              ),
            );
      final memberIndex = roundSlots.indexWhere(
        (slot) => slot.memberOrdinal == current.memberOrdinal,
      );
      if (memberIndex < 0 ||
          memberIndex >= group.members.length ||
          roundSlots.length != group.members.length) {
        return null;
      }
      if (memberIndex + 1 < roundSlots.length) {
        return roundSlots[memberIndex + 1];
      }
      final nextRound = current.roundOrdinal! + 1;
      if (nextRound < group.roundCount) {
        final nextRoundSlots =
            slots
                .where(
                  (slot) =>
                      slot.groupId == groupId && slot.roundOrdinal == nextRound,
                )
                .toList()
              ..sort(
                (left, right) => (left.memberOrdinal ?? -1).compareTo(
                  right.memberOrdinal ?? -1,
                ),
              );
        return nextRoundSlots.length == group.members.length
            ? nextRoundSlots.first
            : null;
      }
      final lastGroupIndex = slots.lastIndexWhere(
        (slot) => slot.groupId == groupId,
      );
      if (lastGroupIndex >= 0 && lastGroupIndex + 1 < slots.length) {
        return slots[lastGroupIndex + 1];
      }
      return null;
    }

    final currentIndex = slots.indexWhere((slot) => slot.id == current.id);
    if (currentIndex < 0 || currentIndex + 1 >= slots.length) return null;
    return slots[currentIndex + 1];
  }

  static B02PerformedExerciseDraft? _performedForSlot(
    B02ExecutionDraftState state,
    B02StrengthExecutionSlot slot,
  ) {
    return state.performedExercises
        .where(
          (exercise) =>
              exercise.id == 'performed:${slot.id}' ||
              (exercise.sourceExercisePrescriptionId == slot.prescriptionId &&
                  exercise.groupRoundOrdinal == slot.roundOrdinal &&
                  exercise.groupMemberOrdinal == slot.memberOrdinal),
        )
        .firstOrNull;
  }
}

enum B02NextSetRule { addLoad, keepLoad, oneMoreRep }

/// A next-set suggestion and the rule that made it (UF-12). [loadKg] and
/// [reps] are what "Apply" puts in the inputs; null [reps] leaves the reps
/// field as it is.
class B02NextSetSuggestion {
  const B02NextSetSuggestion({
    required this.rule,
    required this.lastSets,
    required this.repsMin,
    required this.repsMax,
    required this.loadKg,
    required this.reps,
  });

  final B02NextSetRule rule;
  final List<({double loadKg, int reps})> lastSets;
  final int repsMin;
  final int repsMax;
  final double loadKg;
  final int? reps;

  /// "Last time 60 kg × 12, 12, 12 · top of 8–12 → try 62.5 kg".
  String get copy {
    final range = '$repsMin–$repsMax';
    return '${lastTimeLabel()} · ${switch (rule) {
      B02NextSetRule.addLoad => 'top of $range → try ${_kg(loadKg)} kg',
      B02NextSetRule.keepLoad => 'under $range → Keep ${_kg(loadKg)} kg',
      B02NextSetRule.oneMoreRep => 'within $range → Aim for one more rep than last time',
    }}';
  }

  /// [loadKg] as typed into the load field: "62.5", "60".
  String get loadText => _kg(loadKg);

  /// "Last time 60 kg × 12, 12, 12"; mixed loads list each set.
  String lastTimeLabel() {
    final load = lastSets.first.loadKg;
    final same = lastSets.every((set) => (set.loadKg - load).abs() < 0.001);
    if (same) {
      return 'Last time ${_kg(load)} kg × '
          '${lastSets.map((set) => set.reps).join(', ')}';
    }
    return 'Last time '
        '${lastSets.map((set) => '${_kg(set.loadKg)} × ${set.reps}').join(', ')}';
  }

  static String _kg(double value) {
    final rounded = (value * 100).round() / 100;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toString();
  }
}
