# R08B.3 — Evidence-backed previous performance and safe defaults

Status: implementation package for `r08-b3-evidence-defaults`.

This package gives workout execution a typed, read-only boundary for truthful
previous performance. It does not own the player, set-table layout, exercise
replacement, grouped-set semantics, rest timing, wakelock behavior, or any
adaptive recommendation rule.

## Canonical evidence source

Previous performance is read only from the typed B02 history graph:

- `WorkoutSessions` supplies the persisted session identity, activity type,
  completion timestamp, and completion kind.
- `PerformedExercises.actualExerciseId` supplies the exercise identity that
  was actually performed. `expectedExerciseId`,
  `sourceExercisePrescriptionId`, the immutable name snapshot, and
  `substitutionReason` are retained as provenance.
- `PerformedSets` supplies the actual ordinal, role, reps, load in kilograms,
  load basis, RPE, effort mode, failure marker, assistance, tempo, pause, and
  other typed set facts.
- `PerformedSetSegments`, when present, is treated as an explicit technique
  marker. B.3 does not flatten or compare those rows because the persisted
  segment table does not carry the complete drop-set/rest-pause intent needed
  by this query contract.

The legacy `WorkoutSets` name-based history/PR path is not an evidence source
for this package. It can contain older compatibility data and recommendation
logic, including e1RM behavior, which B.3 deliberately does not reuse.

An active B02 draft is not historical evidence: it is held in `WorkoutDrafts`
and does not create a canonical `WorkoutSessions` history row until the B02
completion boundary persists it. Callers may additionally pass
`excludeSessionId` when reading during a just-completed or review flow.

## Eligibility rules

`B02PreviousPerformanceRepository.resolve` accepts a canonical exercise UUID,
the current B02 set semantics, an explicit UTC cutoff, and an optional session
to exclude. A set is comparable only when all of the following hold:

1. The persisted `PerformedExercises.actualExerciseId` exactly equals the
   query ID. Names, aliases, base-name stripping, technique suffixes, family
   inference, fuzzy matching, planned-slot ancestry, and RepDB families never
   establish equivalence.
2. The session activity type is exactly the requested typed modality. B.3
   currently supports `strength`; another activity type returns typed
   `incompatible` rather than being guessed into strength.
3. The session is a canonical completed/logically authoritative row. B02
   `completionKind` values `full` and `partial` are accepted. A null or other
   value is malformed for typed strength history and is rejected. The performed
   exercise status must be `completed` or `partial`; `inProgress` and
   `skipped` are not history evidence.
4. The session completion timestamp is at or before `asOfUtc`. Timestamps are
   normalized to UTC and the selected ordering is deterministic.
5. Reps are present and greater than zero. RPE is either absent or an integer
   from 1 through 10; an absent RPE remains absent.
6. The persisted load basis is present and exactly equals the current query's
   basis. B.3 does not convert total load, per-implement load, per-side load,
   bodyweight, assisted load, machine-stack assumptions, time, or distance.
7. For non-bodyweight bases, actual load is finite, present, and nonnegative.
   For bodyweight, actual external load must be null; a contradictory
   bodyweight-plus-kilograms row fails closed.
8. Role, effort mode, failure marker, assistance mode/load, tempo, and pause
   position/duration exactly match the current
   `B02PreviousPerformanceSetContext`. Incomplete or malformed scalar values
   are rejected rather than partially copied.
9. Any `PerformedSetSegments` row makes the set `incompatible` for B.3,
   regardless of whether the caller asks for segmented semantics. This is a
   deliberate fail-closed boundary: B.2 cannot safely treat a drop set,
   rest-pause set, or mixed technique structure as equivalent from the current
   boolean marker alone. A caller that asks for segmented semantics receives
   `technique_segments_unsupported`.

There is no deletion flag in the canonical B02 set schema; therefore a row is
eligible only through the canonical persisted graph, its authoritative status,
and the validation rules above. Database/read exceptions return
`queryFailure`, which is distinct from a normal empty history result.

## Identity and substitution

History belongs to the actual performed canonical ID. If a planned exercise is
substituted, the result reports the substitute only when the query asks for the
substitute's `actualExerciseId`. The result keeps expected ID, source
prescription ID, name snapshot, and substitution reason for presentation and
audit. Asking for the planned exercise does not leak the substitute's numbers.

## Selection and result shape

The repository groups eligible sets by persisted session and performed
exercise occurrence. It chooses the session with:

1. greatest `WorkoutSessions.completedAt` in UTC;
2. greatest session ID when timestamps tie.

Within that session, occurrences sort by exercise ordinal then performed
exercise ID, and sets sort by set ordinal then performed-set ID. This avoids
database row order becoming product behavior. The result exposes the full
comparable occurrence sequence from the selected session rather than assuming
that historical set 2 corresponds to current set 2.

`B02PreviousExercisePerformance` distinguishes:

- `available`: comparable facts exist;
- `noHistory`: no exact canonical evidence exists, including the normal
  first-use case;
- `incompatible`: exact history exists but none matches the requested typed
  set semantics;
- `invalidQuery`: the caller did not provide a canonical exercise ID; and
- `queryFailure`: the canonical read failed.

The available result includes the session ID/name, UTC completion timestamp,
performed occurrence provenance, and immutable factual set values. It does not
include a recommendation, target, PR, readiness score, or progression delta.

## Warm-up, RPE, and safe prefill

Warm-up and working roles are exact compatibility dimensions. A warm-up set
cannot seed a working-set default, and a working set cannot be presented as a
warm-up fact.

`safePrefill` is deliberately conservative:

- it is present only when the selected comparable session has exactly one
  compatible set across its returned occurrences;
- it is absent for multiple sets, any technique-segment set, or incompatible
  semantics, so B.2 never needs an arbitrary set-number mapping;
- it copies only the persisted load (including null for bodyweight), reps, RPE,
  role, basis, and provenance IDs;
- missing RPE stays null;
- no zero is manufactured for missing load; and
- the repository does not mutate the current draft. B.2 remains responsible
  for initializing editable fields and for saving the user's edits.

Thus a safe prefill is a factual editable starting value, not “you should lift
this” and not a progression offer.

## B.2 integration contract

The stable provider boundary is
`b02PreviousPerformanceRepositoryProvider` in `lib/core/di/providers.dart`.
B.2 can later call:

```dart
final result = await ref
    .read(b02PreviousPerformanceRepositoryProvider)
    .resolve(
      B02PreviousPerformanceQuery(
        canonicalExerciseId: slot.exerciseId,
        setContext: currentSetContext,
        asOfUtc: DateTime.now().toUtc(),
        excludeSessionId: activeHistorySessionId,
      ),
    );
```

The player/set table may show the returned historical evidence as history
context. It may initialize editable fields only when `result.safePrefill` is
non-null and its basis/role match the current row, leaving the user free to
edit or clear them. It must preserve the result's unavailable state instead of
showing a zero or a recommendation. The current B.2 player files are not
modified by this package; the small post-merge hook is this query plus the
optional `safePrefill` handoff at the B.2 set-row controller boundary. Until a
future exact segment model exists, B.2 should present segmented previous
history as unavailable/incompatible rather than copying it into a simple row.

## Explicit non-scope

B.3 adds no e1RM, PR comparison, percentage increase, fixed increment,
progression formula, readiness adjustment, calorie estimate, or adaptive load
recommendation. It adds no player UI, set-table ownership, replacement policy,
grouped-set behavior, rest/wakelock behavior, or media behavior.
