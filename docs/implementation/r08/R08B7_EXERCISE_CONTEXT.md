# R08B.7 — Exercise cues, execution context, and visual integration

Status: implementation package for `r08-b7-exercise-context`.

## Scope and authority

B.7 is a presentation package on top of the merged B.1–B.6 execution path. It
does not create a lifecycle, draft, timer, rest, replacement, set-table, or
completion authority.

The shared player integration passes the exact actual performed exercise UUID
and immutable name snapshot to `B07ExerciseContextPanel`. The read-only
`B07ExerciseContextRepository` queries `Exercises.stableId` exactly. It reads
only existing canonical fields:

- `formCues` for execution cues;
- `commonMistakes` for expanded guidance;
- `equipment` for setup context; and
- `muscleGroups` through `ExerciseDisplayMuscles` for primary/secondary
  presentation.

There is no name matching, fuzzy matching, family inference, muscle-based
replacement, or RepDB identity lookup. A missing catalog row is a normal
unavailable context state. A database error is a typed query-failure state;
both retain the exercise name and neutral/icon visual fallback so logging stays
available.

## Visual contract

`b05ExerciseVisualRegistryProvider` loads the existing R08-0 provenance-backed
`B05ExerciseVisualRegistry` through the packaged manifest. The registry remains
the only RepDB binding authority. `B07ExerciseVisualRegion` passes the exact
UUID to `ExerciseVisual` and uses the existing chain:

```text
approved local still → IndiFit MuscleMap → IndiFit semantic icon → neutral icon
```

Start and Peak are shown only when the registry exposes both roles. A MAIN-only
or partial set renders one still; B.7 never interpolates, animates, or creates
a second pose. Local RepDB files are optional and absent in the public clone;
checksum/load failures are swallowed by the existing visual widget and never
surface paths or exceptions.

The visual is deliberately bounded and supplies an image cache width. It is
not tied to the elapsed/rest ticker's durable state. Registry and context
lookups are keyed by the current UUID, so a late lookup for exercise A cannot
replace exercise B after a canonical substitution.

## Cue and context hierarchy

The player header remains the independent exercise-name and set-progress
authority. The B.7 context card adds a small visual region, concise primary /
secondary muscle text, equipment text, and the first canonical cue. Remaining
canonical cues and common-mistake text stay behind the accessible `Technique`
disclosure. RepDB technique-disclosure text is not used as IndiFit coaching
authority.

The existing target / previous-performance card remains separate and factual.
B.7 does not label history as a recommendation or add progression/e1RM/PR
logic. The shared B.2 player appends the visual/context card inside its
existing secondary slot after set logging and the primary action, so it cannot
displace the compact editable table or make the logging path depend on context
resolution.

## Current and next context

`B02ExecutionProgression.nextSlot` is a read-only exposure of the existing B.5
cursor ordering. The player uses it for the compact `Next exercise` surface;
group type, round, and member are taken from the exact canonical slot fields.
It does not infer a group from adjacency or names. Rest continues to use the
same selected/next slot state and the B.6 durable rest card; B.7 does not own
rest timing or wakelock.

## Planned, Quick, and replacement behavior

- Planned retains its occurrence and frozen prescription. Visual/cues/equipment
  follow the actual performed UUID; planned target context remains separate.
- Quick uses the same panel and remains occurrence-less. No fake planned target
  or schedule is created.
- B.4 replacement rebinding is consumed, not reimplemented. After A → B, the
  player derives name, visual, muscles, equipment, cues, and previous-performance
  identity from B's exact actual UUID and current performed snapshot.

The B.2 compact set table remains the logging owner, and B.6 remains the rest
and session-wake-lock owner.

## B.2 integration hook (implemented)

In `B02StrengthPlayerScreen`, after B.2's existing `primaryActionSlot` and
before its existing next-exercise content, the player mounts one keyed
`B07ExerciseContextPanel`:

```dart
B07ExerciseContextPanel(
  key: ValueKey('b07-context:${actualExerciseId ?? ''}'),
  canonicalExerciseId: actualExerciseId ?? '',
  exerciseNameSnapshot: _actualExerciseName(launch.state, selected),
)
```

Use the same current actual UUID/name derivation already used by the player;
do not use the planned prescription ID after substitution. For grouped next
context, pass `B02ExecutionProgression.nextSlot(...)` into
`B07NextExerciseContext` using the existing B.5 draft state and slot list. Keep
`currentExerciseSlot` and the compact set table unchanged. No B.8
completion/review behavior is included.
