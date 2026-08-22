# R08B.6 Rest, Stable Execution Layout, and Session Wake Lock

## Scope

R08B.6 keeps rest inside the shared B.1 execution shell and gives the active
workout session, rather than the rest surface or a route, ownership of the
screen-awake intent. It does not change B02 rest policy, B.5 progression, the
compact table's ordinary logging path, or the B.6-excluded visual/completion
packages.

## Rest authority

The durable `B02RestPeriod` in the execution draft remains the only rest
authority. `RestRecommendationService` selects the canonical duration and
scope; `B02RestDraftCoordinator` begins, adjusts, skips, and finishes the
period. `B02RestTimerSnapshot` derives remaining time from the persisted start
timestamp and selected/recommended duration. A widget ticker only requests
repaints and never decrements durable truth.

The B02 player passes `startRestAfterRecord` to the execution controller. The
controller starts rest only after the set/progression draft write succeeds.
Failed persistence therefore cannot present a false rest. B02's existing
scope rules are preserved: rest-pause intervals use the prescribed
rest-pause value, group members use member-transition rest, completed group
rounds use group-round rest, and standalone working sets use the existing
prescription/preference/template/automatic precedence. Warm-up logging does
not automatically create the ordinary working-set rest.

The controller serializes rest actions and treats repeated skip, completion,
and adjustment actions as harmless. The existing `-15/+15` player controls
remain; the existing `+30` controller extension remains available to existing
callers. The existing technical draft bound is retained when an adjustment
would otherwise become invalid.

The retained legacy compatibility player still uses its existing
`RestTimerBottomSheet` presentation. That timer is also wall-clock based and
presentation-only; it has no screen-awake ownership and does not replace the
durable B02 rest authority used by Planned and Quick strength execution.

Rest never blocks another set. Logging the next set finalizes the current
period with the canonical next-action reason in the same durable write; if
that write fails, the existing rest remains open. Session completion likewise
closes any open interval before the terminal draft is finalized.

## Stable layout and accessibility

The compact set table and primary action slot remain mounted and usable while
rest is open. The rest card is an integrated shell slot, not a separate
navigation stack. It presents the
remaining duration from the wall clock, the next canonical cursor context,
adjustment actions, and Skip rest. Countdown semantics expose a stable
remaining-time label without making every one-second repaint a live-region
announcement.

## Session-wide wake lock

`WorkoutSessionWakeLockCoordinator` is app-scoped and is the single owner of
the `wakelock_plus` boundary. B02 and the retained compatibility player only
set or reconcile an active session key. Screen disposal, route changes, and
rest start/finish do not release it.

The coordinator enables/reconciles on active-session start, rebind/resume, and
foreground return. It releases after canonical completion, discard/cancel, or
the retained compatibility summary's successful terminal save. Calls are
serialized; stale route clears are ignored; plugin failures are logged as
diagnostics and never change draft persistence, logging, or finalization
results.

## Integration boundary

R08B.6 does not add a new rest route or modify B.7/B.8 behavior. The B.1–B.5
execution controllers remain the lifecycle, set, evidence, replacement, and
group-progression authorities respectively.
