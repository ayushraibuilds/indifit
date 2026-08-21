# R08B.2 — Compact Editable Workout Set Table

## Status

R08B.2 establishes the shared Planned/Quick set-entry presentation on top of
the R08B.1 execution shell. It keeps set persistence in the existing B02 draft
service/controller path and adds current-session edit/delete mutations by
canonical performed-set ID.

## Root problem

The player previously rendered the pending load/reps fields separately from a
read-only performed-set list. Planned and Quick therefore had the same data in
different vertical treatments, logged rows could not be corrected in place,
and the `initialValue` fields were vulnerable to reset/focus churn during a
controller rebuild.

## Canonical state boundary

| Fact | Authority | B.2 treatment |
| --- | --- | --- |
| Planned target load/basis/reps/RPE | `B02StrengthExecutionSlot` and the existing prepared draft | Rendered as a target label; no new target calculation |
| Actual load/basis/reps/RPE | `B02PerformedSet` | Rendered as actual value and prefilled for edit |
| Warm-up/working role | `B02PerformedSet.role` and existing player state | Preserved in the compact disclosure |
| Set identity | `B02PerformedSet.id` | Used for edit/delete; never replaced by row number |
| Set order | `B02PerformedSet.ordinal` | Sorted for display and compacted after deletion to preserve the B02 invariant |
| Persistence | `B02StrengthExecutionController.saveDraft` and existing repository | Reused without a second write or lifecycle authority |

## Presentation symbols

- `B02CompactSetRow` is the immutable presentation model for a logged or
  planned row. It only formats facts already supplied by B02.
- `B02CompactSetTable` is the shared Planned/Quick surface. It owns row
  hierarchy, responsive layout, input semantics, and edit/delete affordances;
  its parent owns controllers and mutations.
- `WorkoutExecutionShell` keeps the primary logging action immediately before
  the set table so the action remains visible in the first execution viewport.

## Planned and Quick behavior

Planned mode shows the frozen target alongside actual logged values and fills
remaining planned working rows as `Ready` placeholders. Quick mode uses the
same row and pending-input components; targetless Quick rows omit the planned
column and do not fabricate target values. If a Quick slot already has a
truthful target, the same target treatment is available.

Quick retains its existing `Add set` presentation hook. No new set-generation
policy is introduced; the player continues to seed that input from the
canonical slot values only.

## Mutation behavior

Logging still calls `recordSet` and keeps the existing validation, rest start,
and `_isSubmittingSet` protection. Logged rows expose labelled 48px edit and
delete controls. Edit preloads actual load/reps/RPE, allows only the ordinary
fields exposed by the current B02 model, preserves advanced technique fields,
and saves through the controller. Delete targets the stable performed-set ID,
retains the IDs of remaining rows, and only updates the UI after the canonical
save succeeds. Failed mutations retain the prior truthful draft and use A.5
safe product copy.

## Input stability

The player now owns one `TextEditingController` per slot for load and reps and
disposes them with the player. The table receives those controllers and stable
slot keys. Rebuilds therefore do not recreate `initialValue` fields, reset
typed values, or move the cursor during unrelated state updates.

## Future-package boundaries

- B.3 may supply evidence-backed initial values through the existing controller
  or caller boundary; B.2 contains no history lookup or suggested-load logic.
- B.4 may change the current exercise through its canonical replacement flow;
  the table consumes the resulting slot/set facts and owns no picker.
- Grouped/special-set semantics, rest redesign/wakelock, exercise visuals, and
  review/completion redesign remain in B.5–B.8.

## Validation focus

The B.2 tests cover stable-ID edit/delete after row removal, Planned/Quick
target truthfulness, warm-up/RPE preservation, controller persistence and safe
failure copy, parent-owned input stability, labelled action semantics, and
320/360/430px plus elevated-text-scale light/dark layout coverage.
