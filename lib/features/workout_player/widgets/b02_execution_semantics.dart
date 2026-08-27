import 'package:flutter/foundation.dart';

import '../../../core/presentation/consumer_copy.dart';
import '../../../data/models/b02_execution_models.dart';
import '../../../data/models/b02_rich_set_helpers.dart';

/// Consumer-facing labels for B02 execution values.
///
/// The execution UI must not leak database values or enum spellings. These
/// labels intentionally describe the fact a person is about to record.
String b02ExecutionEffortLabel(B02EffortMode mode) => switch (mode) {
  B02EffortMode.standard => 'Standard set',
  B02EffortMode.amrap => 'As many good reps as possible',
  B02EffortMode.toFailure => 'To failure',
};

String b02ExecutionPausedRepPositionLabel(B02PausedRepPosition position) =>
    switch (position) {
      B02PausedRepPosition.bottom => 'Bottom position',
      B02PausedRepPosition.top => 'Top position',
      B02PausedRepPosition.midpoint => 'Midpoint',
      B02PausedRepPosition.custom => 'Custom position',
    };

String b02ExecutionAssistanceLabel(B02AssistanceMode mode) => switch (mode) {
  B02AssistanceMode.machine => 'Machine assistance',
  B02AssistanceMode.counterweight => 'Counterweight assistance',
  B02AssistanceMode.band => 'Band assistance',
  B02AssistanceMode.partner => 'Partner assistance',
  B02AssistanceMode.unknown => 'Other assistance',
};

String b02ExecutionLoadBasisLabel(B02LoadBasis basis) => switch (basis) {
  B02LoadBasis.totalExternal => 'Total load',
  B02LoadBasis.perImplement => 'Per implement',
  B02LoadBasis.perSide => 'Per side',
  B02LoadBasis.bodyweight => 'Bodyweight',
};

String b02ExecutionSetRoleLabel(B02SetRole role) => switch (role) {
  B02SetRole.warmup => 'Warm-up set',
  B02SetRole.working => 'Working set',
};

String b02ExecutionGroupTypeLabel(B02GroupType type) => switch (type) {
  B02GroupType.superset => 'Superset',
  B02GroupType.circuit => 'Circuit',
  B02GroupType.giantSet => 'Giant set',
};

/// Whether the typed technique carries anything beyond an ordinary set.
bool b02TechniqueHasAdvancedDetails(B02TechniqueFields technique) {
  return technique.effortMode != B02EffortMode.standard ||
      technique.endedAtFailure ||
      technique.hasTempo ||
      technique.pausedRepPosition != null ||
      technique.assistanceMode != null ||
      technique.isDropSet ||
      technique.isRestPause ||
      technique.segments.isNotEmpty;
}

/// Compact, truthful detail text for rows and collapsed controls.
String? b02TechniqueSummary(B02TechniqueFields technique) {
  if (!b02TechniqueHasAdvancedDetails(technique)) return null;
  final details = <String>[];
  if (technique.effortMode != B02EffortMode.standard) {
    details.add(b02ExecutionEffortLabel(technique.effortMode));
  }
  if (technique.endedAtFailure) details.add('Reached failure');
  if (technique.hasTempo) {
    details.add(
      'Tempo ${technique.tempoEccentricSeconds}-'
      '${technique.tempoBottomPauseSeconds}-'
      '${technique.tempoConcentricSeconds}-'
      '${technique.tempoLockoutPauseSeconds}',
    );
  }
  final paused = technique.pausedRepPosition;
  if (paused != null && technique.pausedRepSeconds != null) {
    details.add(
      'Paused reps · ${b02ExecutionPausedRepPositionLabel(paused)} '
      '${technique.pausedRepSeconds}s',
    );
  }
  final assistance = technique.assistanceMode;
  if (assistance != null && technique.assistanceKg != null) {
    details.add(
      '${b02ExecutionAssistanceLabel(assistance)} · '
      '${_formatNumber(technique.assistanceKg!)} kg',
    );
  }
  if (technique.isDropSet) details.add('Drop set');
  if (technique.isRestPause) details.add('Rest-pause');
  if (technique.segments.isNotEmpty) {
    details.add('${technique.segments.length} work segments');
  }
  return details.join(' · ');
}

String _formatNumber(num value) {
  final doubleValue = value.toDouble();
  if (doubleValue == doubleValue.roundToDouble()) {
    return doubleValue.toStringAsFixed(0);
  }
  return doubleValue.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

/// Ordered slot identity for a single canonical group round.
List<B02StrengthExecutionSlot> b02GroupRoundSlots({
  required Iterable<B02StrengthExecutionSlot> slots,
  required String groupId,
  required int roundOrdinal,
}) {
  final result = slots
      .where(
        (slot) => slot.groupId == groupId && slot.roundOrdinal == roundOrdinal,
      )
      .toList();
  result.sort((left, right) {
    final leftOrdinal = left.memberOrdinal;
    final rightOrdinal = right.memberOrdinal;
    if (leftOrdinal == null || rightOrdinal == null) {
      return left.id.compareTo(right.id);
    }
    return leftOrdinal.compareTo(rightOrdinal);
  });
  return result;
}

/// A conservative check for the group graph presented to the player.
///
/// It only accepts slots that match the persisted group/member/round identity.
/// It never treats adjacent standalone slots as a group.
@immutable
class B02GroupExecutionIntegrity {
  final bool isValid;
  final String? consumerMessage;

  const B02GroupExecutionIntegrity.valid()
    : isValid = true,
      consumerMessage = null;

  const B02GroupExecutionIntegrity.invalid(this.consumerMessage)
    : isValid = false;

  static B02GroupExecutionIntegrity check({
    required B02ExerciseGroup group,
    required Iterable<B02StrengthExecutionSlot> slots,
  }) {
    final groupSlots = slots.where((slot) => slot.groupId == group.id).toList();
    final members = [...group.members]
      ..sort((left, right) => left.ordinal.compareTo(right.ordinal));
    if (groupSlots.length != group.roundCount * members.length) {
      return const B02GroupExecutionIntegrity.invalid(
        ConsumerCopy.groupDetailsUnavailable,
      );
    }
    for (var round = 0; round < group.roundCount; round++) {
      final roundSlots = b02GroupRoundSlots(
        slots: groupSlots,
        groupId: group.id,
        roundOrdinal: round,
      );
      if (roundSlots.length != members.length) {
        return const B02GroupExecutionIntegrity.invalid(
          ConsumerCopy.groupDetailsUnavailable,
        );
      }
      for (var index = 0; index < members.length; index++) {
        final slot = roundSlots[index];
        final member = members[index];
        if (slot.memberOrdinal != member.ordinal ||
            slot.prescriptionId != member.exercisePrescriptionId ||
            slot.groupType != group.groupType ||
            slot.plannedSets != 1 ||
            (slot.setPrescriptionOrdinal != null &&
                slot.setPrescriptionOrdinal != round)) {
          return const B02GroupExecutionIntegrity.invalid(
            ConsumerCopy.groupDetailsUnavailable,
          );
        }
      }
    }
    return const B02GroupExecutionIntegrity.valid();
  }

  static B02GroupExecutionIntegrity checkCurrentPosition({
    required B02ExecutionDraftState state,
    required Iterable<B02StrengthExecutionSlot> slots,
  }) {
    final groupId = state.currentGroupId;
    if (groupId == null) {
      if (state.currentGroupOrdinal != null ||
          state.currentRoundOrdinal != null ||
          state.currentMemberOrdinal != null) {
        return const B02GroupExecutionIntegrity.invalid(
          ConsumerCopy.groupDetailsUnavailable,
        );
      }
      return const B02GroupExecutionIntegrity.valid();
    }
    final group = state.groups
        .where((candidate) => candidate.id == groupId)
        .firstOrNull;
    if (group == null ||
        state.currentGroupOrdinal != group.ordinal ||
        state.currentRoundOrdinal == null ||
        state.currentMemberOrdinal == null ||
        state.currentRoundOrdinal! >= group.roundCount ||
        !group.members.any(
          (member) => member.ordinal == state.currentMemberOrdinal,
        )) {
      return const B02GroupExecutionIntegrity.invalid(
        ConsumerCopy.groupDetailsUnavailable,
      );
    }
    final graph = check(group: group, slots: slots);
    if (!graph.isValid) return graph;
    final current = slots.where(
      (slot) =>
          slot.groupId == groupId &&
          slot.roundOrdinal == state.currentRoundOrdinal &&
          slot.memberOrdinal == state.currentMemberOrdinal,
    );
    return current.length == 1
        ? const B02GroupExecutionIntegrity.valid()
        : const B02GroupExecutionIntegrity.invalid(
            ConsumerCopy.groupDetailsUnavailable,
          );
  }
}
