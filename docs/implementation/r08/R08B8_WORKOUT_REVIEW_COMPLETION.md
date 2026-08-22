# R08B.8 — Workout Review and Completion Evidence

## Scope

R08B.8 owns the presentation around the existing B02/A.3 completion boundary:

`active draft → review → canonical finalization → saved result → history detail`

It does not write completion records, advance occurrences, delete drafts, or
own rest/wakelock state.

## Defects found

- The canonical success surface counted exercises, sets, reps, and an ad-hoc
  volume value from the pre-finalization launch.
- Full and partial completion did not have distinct result language.
- Review rows did not consistently show exact substitution or advanced facts.
- Saved B02 history exposed only list counts, so a completed strength result
  could not be reconstructed from history.
- The compatibility summary called the pre-save state complete and shared
  unsupported celebratory copy.

## Canonical authorities

- `B02StrengthExecutionController.finalize` remains the only player completion
  action and delegates to `StrengthExecutionRepository.finalizeDraft`.
- `StrengthExecutionRepository.finalizeDraft` remains authoritative for the
  saved session ID, completion kind, elapsed duration, canonical volume,
  performed exercise/set/group persistence, occurrence completion, idempotency,
  and draft cleanup.
- `B02ExecutionCompatibilityReadRepository.readStrengthSession` is a read-only
  history reconstruction path. It reads the immutable `WorkoutSessions`,
  `PerformedExerciseGroups`, `PerformedExercises`, `PerformedSets`, and
  `PerformedSetSegments` rows by exact session identity.
- The controller carries the returned saved session ID and completion kind only
  as presentation handoff state; it does not become a history authority.

## Review behavior

The B02 pre-completion screen is explicitly titled **Review workout** and
presents current draft facts. The retained legacy route keeps its neutral
**Workout Summary** title, while its body identifies the screen as a review
before saving. Neither route says that the workout has already been saved.
Planned context retains target information and shows actual substitutions,
statuses, group order, and set roles. Quick context remains standalone and does
not invent a planned prescription. Advanced facts are tucked under
**Additional details**.

Full completion has one primary **Complete workout** action. Partial completion
uses the existing `CompletionKind.partial` command and is presented as
**Workout partially completed** after the saved result is available.

## Saved result and history

The post-completion surface loads the persisted session by the exact ID returned
by finalization. Duration and aggregate volume come from the saved session;
exercise rows, stable performed-set IDs, group identity/order, substitution
identity, actual RPE, warm-up/work role, and advanced fields come from typed
performed history. A malformed history detail fails closed to a saved-state
shell with consumer-safe copy.

Canonical strength history rows can be opened from Workout history at
`/workout-history/:sessionId`. Reopening reads persisted history and never
recreates or resumes an active draft.

No calories, e1RM, PR celebration, readiness/progression score, quality score,
or long-term progress system was added. B.6 remains responsible for terminal
rest/wakelock cleanup.
