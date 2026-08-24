# R08C.9 — Plan Overview + Training History Coherence

## Boundary

C.9 adds a read-only plan overview and makes the shared training-history
destination usable from Training, while preserving the existing B01/B02
authorities. It does not add plan, schedule, session, completion, or history
storage semantics.

The canonical entry point for an exact plan version is:

```text
/plan-overview/:versionId
```

Plan Library now carries the selected `ProgramVersion.id` to this route. The
older `/plan-library/:programId` route remains as a compatibility surface for
existing callers; it uses the same overview body but resolves the library's
preferred version until those callers migrate.

## Read composition

`PlanOverviewReadRepository` composes three existing read authorities:

- `PlanLibraryReadRepository.readVersion` reads the exact non-archived
  program/version graph and active-version pointer.
- `CalendarReadRepository.readOccurrencesForVersion` reads materialized
  occurrences for that exact version and reuses the calendar's next-required
  projection.
- `B02ExecutionCompatibilityReadRepository.readHistory` reads persisted
  workout/activity history.

The overview joins saved history only through the persisted
`scheduledOccurrenceId` and the exact occurrence IDs returned for the selected
version. It never reconstructs occurrences, infers a plan from names, or
reattributes unscheduled Quick/manual activity to a plan.

`PlanOverviewSnapshot` is a presentation read model. Its invalidation provider
only causes a fresh read after canonical plan, occurrence, session, performed
record, or activity-detail changes; it owns no mutation or lifecycle state.

## Consumer behavior

The overview exposes plan identity, notes/focus, version-derived structure,
current-plan state, factual schedule status, and a compact list of workouts
saved against that plan. Planned rows retain exact occurrence identity and can
open `/calendar?date=...`; linked history opens the existing B08 detail route.
The secondary actions are:

- `Edit plan` → `/program-author?versionId=...` (C.4 Builder)
- `Open in calendar` / `View full calendar` → C.5 Calendar
- `View all training history` → `/workout-history`

Activation still calls `ProgramActivationCoordinator` through the existing C.3
flow. The overview does not replace Training/Today current-action resolution.

History keeps genuine source differences visible without guessing unsupported
provenance. Scheduled sessions are labelled `Planned workout`; unscheduled
strength records are labelled `Independent workout` because the current
persisted session schema does not distinguish Quick from manual strength;
Other Activity is labelled `Logged activity`, and legacy projections remain
`Earlier workout`. Partial completion is read from the canonical
`completionKind` field.

## Fail-closed rules and non-scope

Missing, archived, malformed, or otherwise unavailable versions render the
consumer-safe unavailable state. Empty schedules and empty history are normal
states. No calories, scores, progression, readiness, e1RM, PR, or invented
version/occurrence facts are displayed. C.9 does not redesign Training Home,
Calendar, Builder, manual activity persistence, or the B02 player.
