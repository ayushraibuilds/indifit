# R08B.4 — First-class exercise replacement and shared picker

This branch owns the presentation/selection layer for exercise selection and
replacement. It does not change B02 substitution policy or the B.2 player
hotspot.

## Inventory and duplication found

The pre-B.4 code had several semantically different selectors:

| Surface | Existing selector/query | Decision |
| --- | --- | --- |
| Quick Workout start | `QuickExercisePicker` in `quick_workout_screen.dart`; direct `WorkoutRepository.searchExercises` access; returned an `Exercise` | Replaced the duplicated picker body with a compatibility wrapper around `ExercisePicker`; the old `Exercise` result shape remains for existing callers. |
| B02 Quick add | Existing `B02StrengthPlayerScreen` caller of `QuickExercisePicker` | Not edited on this branch. It continues to use the compatibility wrapper for ad-hoc Quick addition until the B.2 merge integration. |
| B02 Planned substitution | Existing `B02StrengthPlayerScreen` caller of `QuickExercisePicker`; local ID/name maps; the screen already locks the action after logged sets | Not edited on this branch. The replacement hotspot must be moved to the typed replacement hook below after B.2 merges. |
| Legacy player substitution | `workout_player_screen.dart::_substituteExercise`; local `FutureBuilder`, name-only result, and `substituteExercise(String)` | Not migrated. It has different legacy semantics and has no canonical UUID replacement command. |
| Manual log | `widgets/manual_log_sheet.dart`; loads all exercises and filters names locally | Not migrated. It is a manual-log flow, not a B02 replacement flow. |
| Routine authoring | `routine_editor_screen.dart`; loads all exercises and filters names locally | Not migrated. Authoring semantics are different from execution replacement. |
| Exercise Library | `exercise_library_screen.dart`; its own repository query and category/equipment UI | Not redesigned or mechanically migrated. Its category behavior was used as the primary-muscle reference. |

The main duplicated problems were search/filter ownership, inconsistent row
labels, and direct repository access from picker widgets. The shared catalog
repository now owns search, exact stable-ID lookup, primary-muscle category
semantics, and equipment options. Other surfaces remain separate where their
selection semantics differ.

## Shared picker API

The reusable symbols are in `lib/features/exercise_picker/exercise_picker.dart`
and `exercise_picker_models.dart`:

- `ExercisePicker` — embeddable surface for a picker sheet or another host.
- `showExercisePicker(...)` — general selection entry point.
- `showExerciseReplacementPicker(...)` — typed replacement entry point.
- `ExercisePickerRepository` — read-only catalog/search authority.
- `ExercisePickerSelectionContext` — sealed context family for Library,
  Quick-add, and replacement use.
- `ExercisePickerSelection` — exact canonical exercise ID plus display-name
  snapshot.
- `ExerciseReplacementTarget` — sealed Planned/Quick replacement target.
- `CanonicalReplacementCompatibility` — B02-provided candidate state.
- `CanonicalExerciseReplacementAuthority` — the typed B02 seam for reading
  compatibility and committing an allowed selection.

`ExercisePicker` is deliberately unaware of player layout, set entry, draft
mutation, occurrence mutation, or session creation. A generic selection may
use `onExerciseSelected`; replacement uses `onReplacementCommit` or returns a
selected-only result for the caller's existing canonical command.

## Search and filters

Rows are intentionally dense and show:

1. exercise name;
2. `ExerciseDisplayMuscles.primary` and equipment; and
3. quieter secondary-muscle context when present.

Text search matches tokens from the current exercise name, equipment, and the
accepted muscle-group text, so secondary muscles remain useful discovery
terms. Category filtering calls `ExerciseDisplayMuscles.matchesPrimary` and
never treats a secondary substring as a category match. Equipment is a
presentation filter only. There is no image/encyclopedia-card treatment.

Search, loading, error, empty, and no-results states are exposed in the shared
surface. Invalid catalog rows without a canonical stable ID or readable name
are omitted from selectable results.

## Canonical replacement authority

The picker does not infer replacement validity from same-primary-muscle,
same-equipment, name similarity, RepDB families, or external taxonomy. It only
enables a row when the supplied `CanonicalReplacementCompatibility` contains a
known `allowed` result for that exact stable ID. Missing candidates and
unknown compatibility resolve to disabled rows. This is the fail-closed path.

The inspected B02 code already provides the canonical identity/write path:
`B02StrengthExecutionDraftService.recordSet` retains the existing actual
exercise identity, and the B02 repository persists
`B02PerformedExerciseDraft.actualExerciseId` and its name snapshot. The current
branch does not invent a new candidate policy or add a second substitution
writer. The existing B02 UI currently locks Planned substitution after logged
sets; B.4 preserves that observed behavior and does not reattribute logged
evidence. If B02 returns a canonical result that only governs remaining
unlogged work, the picker presents that supplied effect and preserves the
logged-evidence flag.

## Planned and Quick behavior

`PlannedExerciseReplacementTarget` carries the exact draft ID, scheduled
occurrence ID, planned slot ID, expected exercise ID, and current performed
exercise ID. A result remains Planned and retains the occurrence and source
slot identity. The replacement callback must invoke the canonical B02 command
for that target; it must not create a Quick draft or mutate the template.

`QuickExerciseReplacementTarget` carries the exact draft and slot identity but
no scheduled occurrence. `QuickExercisePickerContext` is the separate ad-hoc
add context and does not inherit Planned substitution restrictions. A Quick
replacement result remains Quick and must reuse the existing draft/session.

The picker never creates a second active session. It only returns a typed
selection/result or invokes the one commit callback supplied by its host.

## Exact post-merge B.2 integration hook

Do not add this wiring to `b02_strength_player_screen.dart` on the B.4 branch.
After B.2's player hotspot and set-table changes merge, the replacement action
should construct a target from the live typed B.1 context and the exact B02
slot state, ask the canonical authority for compatibility, then launch the
shared picker:

```dart
final target = PlannedExerciseReplacementTarget(
  draftId: executionContext.draftId,
  scheduledOccurrenceId:
      (executionContext as PlannedWorkoutExecutionContext).occurrenceId,
  slotId: slot.id,
  expectedExerciseId: slot.exerciseId!,
  currentPerformedExerciseId: actualExerciseId,
  currentExerciseNameSnapshot: actualExerciseName,
);
final compatibility = await replacementAuthority.readCompatibility(
  target: target,
);
final result = await showExerciseReplacementPicker(
  context: context,
  selectionContext: ExerciseReplacementPickerContext(
    target: target,
    compatibility: compatibility,
  ),
  onReplacementCommit: replacementAuthority.commit,
);
if (result?.committed == true && context.mounted) {
  // Re-read/rebind the same B02 draft and occurrence; do not start a session.
  controller.refreshFromCanonicalLaunch();
}
```

The real B02 method names may follow the merged controller API, but the
contract is fixed: exact UUIDs in, canonical compatibility out, one canonical
commit, same draft/session/occurrence back. For Quick replacement, construct a
`QuickExerciseReplacementTarget` from the Quick `WorkoutExecutionContext` and
never pass an occurrence ID. For Quick add, keep using
`QuickExercisePickerContext`/`showExercisePicker` until its caller migrates to
the typed selection result.

## Failure and accessibility behavior

Consumer errors are converted through `ProductFailurePresentation`; the picker
does not expose repository names, raw exceptions, UUIDs, or internal policy
reason IDs. A disabled replacement exposes a short consumer-safe explanation,
not just color. Search has a label and hint, rows have complete accessible
labels, selected/current rows expose selected state, disabled rows expose their
reason, tap targets use the shared minimum size, and the result list remains
scrollable under larger text.

## Boundary confirmation

- No substitution policy was added in B.4.
- No RepDB movement-family or heuristic compatibility authority was added.
- No exercise visuals, set table, previous-performance lookup, grouped sets,
  rest, wakelock, or completion work was added.
- `lib/features/workout_player/b02_strength_player_screen.dart` was not
  modified. The replacement hotspot integration is intentionally deferred to
  the post-merge hook above.
