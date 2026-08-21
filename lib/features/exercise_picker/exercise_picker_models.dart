import 'package:flutter/foundation.dart';

import '../../data/database/app_database.dart';

/// The result of choosing an exercise from the shared picker.
///
/// A picker selection is only valid when it carries the catalog's canonical
/// stable ID. Display names are snapshots for presentation and never become
/// mutation identity.
@immutable
class ExercisePickerSelection {
  final String exerciseId;
  final String exerciseNameSnapshot;

  const ExercisePickerSelection({
    required this.exerciseId,
    required this.exerciseNameSnapshot,
  });

  factory ExercisePickerSelection.fromExercise(Exercise exercise) {
    final id = exercise.stableId?.trim();
    if (id == null || id.isEmpty) {
      throw ArgumentError.value(
        exercise,
        'exercise',
        'Only exercises with a canonical identity can be selected.',
      );
    }
    final name = exercise.name.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(
        exercise,
        'exercise',
        'A selected exercise needs a display name snapshot.',
      );
    }
    return ExercisePickerSelection(exerciseId: id, exerciseNameSnapshot: name);
  }

  @override
  bool operator ==(Object other) {
    return other is ExercisePickerSelection &&
        other.exerciseId == exerciseId &&
        other.exerciseNameSnapshot == exerciseNameSnapshot;
  }

  @override
  int get hashCode => Object.hash(exerciseId, exerciseNameSnapshot);
}

/// A typed target for a replacement. The target variant, rather than a
/// nullable occurrence ID or a string mode flag, preserves Planned/Quick
/// semantics through the selection and commit boundary.
sealed class ExerciseReplacementTarget {
  ExerciseReplacementTarget._({
    required int draftId,
    required String slotId,
    required String currentPerformedExerciseId,
    required String currentExerciseNameSnapshot,
  }) : draftId = _requirePositiveId(draftId, 'draftId'),
       slotId = _requireText(slotId, 'slotId'),
       currentPerformedExerciseId = _requireText(
         currentPerformedExerciseId,
         'currentPerformedExerciseId',
       ),
       currentExerciseNameSnapshot = _requireText(
         currentExerciseNameSnapshot,
         'currentExerciseNameSnapshot',
       );

  final int draftId;
  final String slotId;
  final String currentPerformedExerciseId;
  final String currentExerciseNameSnapshot;

  String get modeLabel;
}

/// A replacement inside a scheduled Planned occurrence.
final class PlannedExerciseReplacementTarget extends ExerciseReplacementTarget {
  PlannedExerciseReplacementTarget({
    required super.draftId,
    required String scheduledOccurrenceId,
    required super.slotId,
    required String expectedExerciseId,
    required super.currentPerformedExerciseId,
    required super.currentExerciseNameSnapshot,
  }) : scheduledOccurrenceId = _requireText(
         scheduledOccurrenceId,
         'scheduledOccurrenceId',
       ),
       expectedExerciseId = _requireText(
         expectedExerciseId,
         'expectedExerciseId',
       ),
       super._();

  final String scheduledOccurrenceId;
  final String expectedExerciseId;

  @override
  String get modeLabel => 'Planned workout';
}

/// A replacement inside an occurrence-less Quick draft.
final class QuickExerciseReplacementTarget extends ExerciseReplacementTarget {
  QuickExerciseReplacementTarget({
    required super.draftId,
    required super.slotId,
    required super.currentPerformedExerciseId,
    required super.currentExerciseNameSnapshot,
  }) : super._();

  @override
  String get modeLabel => 'Quick workout';
}

/// Selection contexts are deliberately typed so a future Training/manual
/// caller can reuse the picker without teaching it about every consumer.
sealed class ExercisePickerSelectionContext {
  const ExercisePickerSelectionContext._();

  String get title;
  String get semanticLabel;
  String? get selectedExerciseId => null;
  bool get isReplacement => false;
}

/// General catalog selection, such as a future Exercise Library or Training
/// authoring surface.
final class ExerciseLibraryPickerContext
    extends ExercisePickerSelectionContext {
  const ExerciseLibraryPickerContext({
    this.title = 'Choose exercise',
    this.semanticLabel = 'Choose an exercise',
    this.selectedExerciseId,
  }) : super._();

  @override
  final String title;

  @override
  final String semanticLabel;

  @override
  final String? selectedExerciseId;
}

/// Occurrence-less exercise addition for Quick Workout. It is not a
/// substitution context and therefore does not inherit Planned restrictions.
final class QuickExercisePickerContext extends ExercisePickerSelectionContext {
  const QuickExercisePickerContext({
    this.title = 'Add exercise',
    this.semanticLabel = 'Add an exercise to Quick workout',
    this.selectedExerciseId,
  }) : super._();

  @override
  final String title;

  @override
  final String semanticLabel;

  @override
  final String? selectedExerciseId;
}

/// Canonical B02 replacement compatibility is input to this presentation
/// context. The picker never computes it from exercise metadata.
final class ExerciseReplacementPickerContext
    extends ExercisePickerSelectionContext {
  factory ExerciseReplacementPickerContext({
    required ExerciseReplacementTarget target,
    required CanonicalReplacementCompatibility compatibility,
    String title = 'Replace exercise',
    String semanticLabel = 'Choose a replacement exercise',
  }) {
    if (target.currentPerformedExerciseId !=
        compatibility.currentPerformedExerciseId) {
      throw ArgumentError.value(
        compatibility,
        'compatibility',
        'Compatibility must describe the exact current performed exercise.',
      );
    }
    return ExerciseReplacementPickerContext._(
      target: target,
      compatibility: compatibility,
      title: title,
      semanticLabel: semanticLabel,
    );
  }

  const ExerciseReplacementPickerContext._({
    required this.target,
    required this.compatibility,
    required this.title,
    required this.semanticLabel,
  }) : super._();

  final ExerciseReplacementTarget target;
  final CanonicalReplacementCompatibility compatibility;

  @override
  final String title;

  @override
  final String semanticLabel;

  @override
  String get selectedExerciseId => target.currentPerformedExerciseId;

  @override
  bool get isReplacement => true;
}

enum CanonicalReplacementKnowledge { known, unknown }

enum CanonicalReplacementCandidateState { allowed, unavailable, unknown }

/// Consumer-safe reason categories. Internal policy/reason IDs do not cross
/// the picker boundary.
enum CanonicalReplacementUnavailableReason {
  notAvailableForWorkout,
  loggedEvidenceLocked,
  unavailableRightNow,
}

/// The effect is supplied by the canonical substitution authority. It is not
/// inferred from whether a row happens to share a muscle or equipment label.
enum CanonicalReplacementEffect {
  remainingUnloggedWork,
  workoutSlotUsesReplacement,
  unspecified,
}

@immutable
class CanonicalReplacementCandidate {
  const CanonicalReplacementCandidate({
    required this.exerciseId,
    required this.state,
    this.unavailableReason,
    this.effect = CanonicalReplacementEffect.unspecified,
    this.requiresConfirmation = false,
    this.preservesLoggedEvidence = false,
  });

  final String exerciseId;
  final CanonicalReplacementCandidateState state;
  final CanonicalReplacementUnavailableReason? unavailableReason;
  final CanonicalReplacementEffect effect;
  final bool requiresConfirmation;
  final bool preservesLoggedEvidence;

  bool get isSelectable =>
      state == CanonicalReplacementCandidateState.allowed &&
      unavailableReason == null;

  String get consumerUnavailableReason {
    if (state == CanonicalReplacementCandidateState.unknown) {
      return 'This replacement is unavailable right now.';
    }
    return switch (unavailableReason) {
      CanonicalReplacementUnavailableReason.loggedEvidenceLocked =>
        'Already logged sets stay with the current exercise.',
      CanonicalReplacementUnavailableReason.notAvailableForWorkout =>
        'This exercise is not available for this workout.',
      CanonicalReplacementUnavailableReason.unavailableRightNow ||
      null => 'This replacement is unavailable right now.',
    };
  }

  String consumerEffect(String replacementName) {
    final name = replacementName.trim();
    return switch (effect) {
      CanonicalReplacementEffect.remainingUnloggedWork =>
        'Already logged sets stay as they are. New sets use $name.',
      CanonicalReplacementEffect.workoutSlotUsesReplacement =>
        'This workout slot will continue with $name.',
      CanonicalReplacementEffect.unspecified =>
        'The workout will continue with $name.',
    };
  }
}

/// Read result supplied by the canonical B02 substitution authority.
///
/// Missing candidate entries intentionally resolve to an unknown, disabled
/// candidate. This is the fail-closed boundary for malformed or incomplete
/// compatibility data.
@immutable
class CanonicalReplacementCompatibility {
  CanonicalReplacementCompatibility({
    required String currentPerformedExerciseId,
    required this.knowledge,
    Iterable<CanonicalReplacementCandidate> candidates = const [],
  }) : currentPerformedExerciseId = _requireText(
         currentPerformedExerciseId,
         'currentPerformedExerciseId',
       ),
       candidates = {
         for (final candidate in candidates)
           if (candidate.exerciseId.trim().isNotEmpty)
             candidate.exerciseId.trim(): candidate,
       };

  factory CanonicalReplacementCompatibility.unknown({
    required String currentPerformedExerciseId,
  }) {
    return CanonicalReplacementCompatibility(
      currentPerformedExerciseId: currentPerformedExerciseId,
      knowledge: CanonicalReplacementKnowledge.unknown,
    );
  }

  final String currentPerformedExerciseId;
  final CanonicalReplacementKnowledge knowledge;
  final Map<String, CanonicalReplacementCandidate> candidates;

  CanonicalReplacementCandidate forExerciseId(String exerciseId) {
    final id = exerciseId.trim();
    if (knowledge != CanonicalReplacementKnowledge.known) {
      return CanonicalReplacementCandidate(
        exerciseId: id,
        state: CanonicalReplacementCandidateState.unknown,
      );
    }
    final candidate = candidates[id];
    if (candidate != null && candidate.exerciseId.trim() == id) {
      return candidate;
    }
    return CanonicalReplacementCandidate(
      exerciseId: id,
      state: CanonicalReplacementCandidateState.unknown,
    );
  }
}

/// The B02 seam for replacement policy and mutation.
///
/// Implementations belong to the canonical execution/substitution layer. The
/// picker consumes the compatibility result and can invoke [commit], but it
/// never derives compatibility or writes a draft itself.
abstract interface class CanonicalExerciseReplacementAuthority {
  Future<CanonicalReplacementCompatibility> readCompatibility({
    required ExerciseReplacementTarget target,
  });

  Future<void> commit({
    required ExerciseReplacementTarget target,
    required ExercisePickerSelection selection,
  });
}

enum ExerciseReplacementCommitStatus { selectedOnly, committed }

/// Returned by [showExerciseReplacementPicker]. A selected-only result is
/// useful for a caller that wants to invoke its existing B02 command after the
/// sheet closes; a committed result means the supplied commit hook completed.
@immutable
class ExerciseReplacementResult {
  const ExerciseReplacementResult({
    required this.target,
    required this.selection,
    required this.status,
    required this.preservesLoggedEvidence,
  });

  final ExerciseReplacementTarget target;
  final ExercisePickerSelection selection;
  final ExerciseReplacementCommitStatus status;
  final bool preservesLoggedEvidence;

  bool get committed => status == ExerciseReplacementCommitStatus.committed;

  bool get remainsPlanned => target is PlannedExerciseReplacementTarget;

  bool get remainsQuick => target is QuickExerciseReplacementTarget;
}

typedef ExerciseReplacementCommitter =
    Future<void> Function({
      required ExerciseReplacementTarget target,
      required ExercisePickerSelection selection,
    });

String _requireText(String value, String field) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be blank.');
  }
  return value.trim();
}

int _requirePositiveId(int value, String field) {
  if (value < 1) {
    throw ArgumentError.value(value, field, 'Must be positive.');
  }
  return value;
}
