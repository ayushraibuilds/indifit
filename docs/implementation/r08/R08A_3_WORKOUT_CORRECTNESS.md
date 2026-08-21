# R08A.3 — Workout elapsed-time and completion correctness

Status: implementation complete; release validation recorded below

## Current lifecycle traced before the fix

The canonical B02 strength path uses one durable `WorkoutDrafts` row as the
active session owner. Scheduled execution is rooted in a frozen occurrence
snapshot; Quick execution has no occurrence but uses the same draft and
canonical finalization repository.

```text
not started
  -> active (start creates the draft)
  -> paused/backgrounded (foreground interval is saved)
  -> active/resumed (a new foreground interval begins)
  -> completing (summary calls finalization)
  -> completion persisted (session/detail/history and, for scheduled work,
     occurrence event/status are written in one transaction)
  -> terminal completed (the exact draft is deleted last)

active -> persisted active draft -> restored/resumed
completing -> failed save -> draft remains available -> retry
active -> discarded/cancelled -> draft/occurrence is discarded through the
  canonical owner
```

The current implementation already has no separate persisted `completing`
state. `B02StrengthExecutionStatus` is UI state (`loading`, `ready`, `partial`,
`failure`, `recovery`); the durable state is the draft plus the scheduled
occurrence state/event log. A failed finalization rolls back the transaction
and keeps the draft for retry.

Ownership before R08A.3:

| Fact | Existing owner |
|---|---|
| Scheduled start/occurrence status | `CalendarRepository` |
| Active execution state and accumulated elapsed integer | `WorkoutDrafts.executionStateJson` / `B02ExecutionDraftState.elapsedSeconds` |
| Active draft persistence | `StrengthExecutionRepository` |
| Completed canonical session and performed graph | `StrengthExecutionRepository.finalizeDraft` transaction |
| Scheduled completion event/status | `CalendarRepository.completeWithPersistedSessionInTransaction` |
| Completion idempotency | occurrence command event for scheduled work plus a deterministic session UUID marker |

Ownership after R08A.3:

| Fact | Corrected owner |
|---|---|
| Active foreground segment start | `B02ExecutionDraftState.activeSegmentStartedAtUtc`, persisted inside the canonical draft payload |
| Accumulated elapsed duration | `B02ExecutionDraftState.elapsedSeconds`, materialized at durable write boundaries |
| Current displayed duration | `b02ElapsedSecondsAt` / `B02LiveElapsedText`; derived from the two persisted timing facts and the injected/current UTC clock |
| Active draft writes | `B02StrengthExecutionController` serializes its writes and supersedes stale lifecycle intents; `StrengthExecutionRepository` also serializes same-draft mutations across provider/controller instances before its durable write |
| Completion transaction | `StrengthExecutionRepository.finalizeDraft`; one SQLite transaction inserts the canonical session/detail graph, completes the occurrence when applicable, and deletes the exact draft last |
| Completion identity | `b02-draft-completion:<draft-id>:<payload-sha256>` stored in the canonical session UUID compatibility column; the draft ID is the logical execution identity and the payload hash rejects a competing payload |

The P0 gap is that the active segment start was held only in
`B02StrengthExecutionController._activeStartedAtUtc`. It was not part of the
durable draft, and the player header displayed the last persisted integer
without a dedicated repaint source.

## R08A.3 timing authority

The corrected authority remains:

```text
persisted accumulated foreground seconds
  + (current UTC time - persisted active foreground segment start)
```

The segment start is persisted in the B02 execution-state payload as an
additive `activeSegmentStartedAtUtc` field. Lifecycle pause materializes the
interval and clears that field; resume persists a new start. A ticker only
repaints the elapsed presentation and never increments the persisted duration.

The field is additive within the existing B02 v2 envelope. Older v2 payloads
without it decode as paused at their already-persisted `elapsedSeconds`; the
controller starts a new foreground segment when that draft is explicitly
recovered. All timestamps are normalized and serialized as UTC ISO-8601.

## Completion contract

Completion remains a single repository transaction. Its logical identity is
the durable draft ID, with the completion payload hash used to reject a
different payload. A successful retry returns the existing session; a failed
transaction leaves the draft and all completed-history/detail effects absent.
The controller also coalesces overlapping finish requests and can replay the
repository completion marker when a late caller observes that the draft was
already removed.

The controller's completion guard is a UI/service convenience, not the
correctness boundary: independent calls still converge through the repository
transaction and marker lookup. Within the current Flutter process, controller
draft writes are serialized so an unawaited pause/resume callback cannot write
an older timing state after a newer lifecycle intent. The repository also
serializes same-draft saves, completion, discard, and Quick exercise mutations
across controllers that share its provider instance. SQLite transaction
serialization remains the boundary relied on for concurrent repository calls;
no cross-process guarantee is claimed.

## Scope boundary

This package does not redesign Workout Player, implement the R08B session-wide
wakelock owner, change B02 taxonomy/database tables, or alter exercise/media
behavior.

## Validation record

- Deterministic A3 tests cover source-of-truth arithmetic, UTC round-trip,
  persisted active-segment restoration, paused-draft `loadSlots` re-entry,
  excluded background time, rapid pause/resume write ordering, live
  repaint/disposal, controller finish coalescing, failed-finalization retry
  state preservation, repository concurrent completion, fresh-command replay,
  and exact active-draft cleanup.
- Existing B02 execution, warm-up/rest, activity, schema, progress/history,
  R07C reliability, and R07C player regression tests pass.
- Golden player tests receive an injected fixed clock in their test helper so
  the new live elapsed presentation remains deterministic; production keeps
  the system UTC clock by default.
- A serial `flutter test --reporter compact` run reached 1,515 passing tests.
  Its two failures were the pre-existing R08-0.2 review test requiring an
  uncommitted CSV absent from this clean worktree, and an R07B golden that
  needed the same fixed-clock test hook; the complete R07B file passes after
  that compatibility adjustment.
