import 'package:flutter/material.dart';

import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/services/b02_execution_progression.dart';
import '../../data/services/b02_warmup_recommendation_service.dart';
import '../progress/training_bests.dart';
import 'widgets/plate_calculator_sheet.dart';
import 'widgets/r07c_workout_presentation.dart';

/// The player's next-set suggestion (UF-12) for [slot], from [history]
/// (this exercise's earlier sessions). Null when there is nothing honest to
/// suggest: no earlier session, no rep range, bodyweight, or a last session
/// with assisted, tempo, paused or drop sets (the [TrainingBests]
/// exclusions), or a slot that prescribes those.
B02NextSetSuggestion? nextSetSuggestionFor({
  required B02StrengthExecutionSlot slot,
  required String exerciseName,
  required Iterable<TrainingBestsEntry> history,
}) {
  final basis = slot.targetLoadBasis;
  if (basis == null || basis == B02LoadBasis.bodyweight) return null;
  // 1–20 means "any reps" (quick workouts), not a planned range.
  if (r07cIsPlaceholderRepRange(slot.targetRepsMin, slot.targetRepsMax)) {
    return null;
  }
  for (final prescription in slot.setPrescriptions) {
    if (TrainingBests.isTechnique(prescription.technique)) return null;
  }
  final last = _lastSession(history);
  if (last.isEmpty) return null;
  final sets = <({double loadKg, int reps})>[];
  for (final entry in last) {
    for (final set in entry.sets) {
      if (set.role != B02SetRole.working) continue;
      final segmented = entry.segmentedSetIds.contains(set.id);
      if (!TrainingBests.isComparable(set, segmented: segmented)) return null;
      if (set.actualLoadBasis != basis) return null;
      sets.add((loadKg: set.actualLoadKg!, reps: set.actualReps!));
    }
  }
  return B02ExecutionProgression.nextSetSuggestion(
    lastWorkingSets: sets,
    repsMin: slot.targetRepsMin,
    repsMax: slot.targetRepsMax,
    stepKg: nextSetStepKg(slot, exerciseName: exerciseName),
  );
}

/// The smallest load step for [slot]: the frozen equipment increment when
/// there is one, else two of the plate calculator's lightest plates on a
/// barbell (one per side when loading is per side), 1 kg per dumbbell, and
/// 2.5 kg on a machine or anything else.
double nextSetStepKg(
  B02StrengthExecutionSlot slot, {
  required String exerciseName,
}) {
  final equipment = const B02EquipmentIncrementResolver().resolve(
    B02EquipmentIncrementInput(
      effectiveItemIncrementKg: slot.effectiveItemIncrementKg,
      profileDefaultIncrementKg: slot.profileDefaultIncrementKg,
    ),
  );
  final frozen = equipment.incrementKg;
  if (frozen != null) return frozen;
  final basis = slot.targetLoadBasis;
  if (basis == B02LoadBasis.perImplement ||
      exerciseName.toLowerCase().contains('dumbbell')) {
    return 1.0;
  }
  if (isBarbellPlateCalculatorSupported(
    exerciseName: exerciseName,
    loadBasis: basis,
  )) {
    final plate = kPlateCalculatorPlatesKg.last;
    return basis == B02LoadBasis.perSide ? plate : plate * 2;
  }
  return 2.5;
}

/// The entries of the most recent earlier session.
List<TrainingBestsEntry> _lastSession(Iterable<TrainingBestsEntry> history) {
  TrainingBestsEntry? latest;
  for (final entry in history) {
    if (latest == null || entry.completedAt.isAfter(latest.completedAt)) {
      latest = entry;
    }
  }
  if (latest == null) return const [];
  final session = latest.sessionId;
  return [
    for (final entry in history)
      if (session != null
          ? entry.sessionId == session
          : identical(entry, latest))
        entry,
  ]..sort((a, b) => a.exerciseOrdinal.compareTo(b.exerciseOrdinal));
}

/// "Last time 60 kg × 12, 12, 12 · top of 8–12 → try 62.5 kg" with an
/// "Apply" chip under the set inputs. Never applied by itself.
class NextSetSuggestionHint extends StatelessWidget {
  const NextSetSuggestionHint({
    super.key,
    required this.suggestion,
    required this.loadController,
    required this.repsController,
    this.enabled = true,
    this.onApplied,
  });

  final B02NextSetSuggestion suggestion;
  final TextEditingController loadController;
  final TextEditingController repsController;
  final bool enabled;

  /// After "Apply" filled the load and, when [B02NextSetSuggestion.reps]
  /// is set, the reps.
  final VoidCallback? onApplied;

  void _apply() {
    loadController.text = suggestion.loadText;
    final reps = suggestion.reps;
    if (reps != null) repsController.text = '$reps';
    onApplied?.call();
  }

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('next_set_suggestion'),
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(suggestion.copy, style: B05Typography.caption(context)),
        ),
        const SizedBox(width: 8),
        ActionChip(
          key: const Key('next_set_suggestion_apply'),
          label: const Text('Apply'),
          onPressed: enabled ? _apply : null,
        ),
      ],
    ),
  );
}
