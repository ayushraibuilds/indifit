# R08B.1 — Shared Planned / Quick Workout Shell

Status: implementation complete for the B.1 foundation

## Flow inventory

| Flow | Canonical entry | Shared execution path | Completion |
|---|---|---|---|
| Planned | Today/Training or Calendar occurrence | `WorkoutContextualLauncher` → `B02StrengthPlayerScreen` | `B02StrengthSummaryScreen` → `StrengthExecutionRepository.finalizeDraft` |
| Quick | Quick Workout picker or active-draft recovery | `QuickWorkoutScreen` → `B02StrengthPlayerScreen` | `B02StrengthSummaryScreen` → `StrengthExecutionRepository.finalizeDraft` |
| Legacy compatibility | Retained legacy routine/unsupported occurrence bridge | `WorkoutPlayerScreen` | `WorkoutSummaryScreen` / legacy adapter |

The root Planned/Quick duplication was presentation and routing shape, not a
second canonical draft writer: both canonical B02 paths already used the same
controller, draft codec, elapsed authority, set mutation service, and
finalizer, but they entered the player through different untyped extras and
the player inferred mode from a nullable occurrence ID. The legacy player is
still retained only for legacy-shaped routines and occurrences without the
canonical B02 coverage required to migrate safely.

## Shared boundary

`WorkoutExecutionContext` is a sealed presentation context with two variants:

- `PlannedWorkoutExecutionContext` retains the exact scheduled occurrence ID
  and the canonical B02 launch.
- `QuickWorkoutExecutionContext` retains the standalone B02 launch and has no
  scheduled occurrence.

The context owns no persistence, timers, draft mutation, or completion. A
`rebind` operation only attaches the same origin to the latest launch after a
controller update. Variant construction rejects a Planned context whose exact
occurrence does not match its launch and rejects a Quick context with any
scheduled occurrence. Rebinding also rejects a different draft, frozen
snapshot payload, snapshot ID, or occurrence origin.

`WorkoutExecutionShell` owns common chrome and stable slots for workout
context, exercise progress, current exercise, rest, set logging, primary
action, next exercise, and review/completion. It deliberately does not own
the values rendered in those slots or any domain action.

`WorkoutExecutionRouteData` is the typed payload for both player and review
routes. Older launch/map extras remain a compatibility parser only; new
Planned and Quick callers pass the typed payload directly. Malformed legacy
payloads fail closed to the existing unavailable-workout route surface.

## Authority boundaries

- Active draft identity, elapsed time, resume, persistence, finalization, and
  retry/idempotency remain with the R08A.3 controller/repository path.
- Occurrence status, frozen prescription ancestry, and scheduled completion
  linkage remain with the calendar/B01 authority.
- Quick exercise selection remains an occurrence-less B02 snapshot/draft.
- Error text remains mapped through the safe product failure boundary.
- B.1 establishes slots around the existing truthful set logging; it does not
  replace the set table or absorb later B.2–B.8 behavior.

## Deliberate non-scope

This package does not implement the compact editable set table, previous-load
prefill, exercise replacement picker, grouped-set UX, rest redesign, wakelock,
ExerciseVisual/muscle-map integration, or completion evidence/celebration.
