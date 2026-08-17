# IndiFit R07F-1 — Training Lifecycle & Plan Cohesion

## Baseline and scope

Work starts from local `main` at `eefc9ae` (the merged R07F-0 baseline) on
`ux/r07f-training-lifecycle`. Existing unrelated worktree changes are
preserved and will not be staged. This batch is limited to the B01-backed
Training lifecycle, its Training/Calendar/Today read projections, and the
smallest supporting persistence and test changes. Food, hydration, nutrition
discovery, broad routing migration, exercise media, PR/e1RM, and player
redesign remain out of scope.

The canonical contract is B01: `TrainingPlanSettings.activeProgramVersionId`
is the only active-plan pointer; `ProgramVersion.status` remains
`draft`/`published`/`archived`; occurrences retain their program ancestry;
workout sessions and sets retain their existing execution ancestry.

## Existing seams found in audit

- Activation already validates and publishes a draft, materializes dated
  occurrences, and updates the singleton active pointer transactionally.
- Occurrence transitions already preserve completed, partially completed,
  skipped, cancelled, and session-linked history through append-only events.
- There is no safe public plan-end/deactivation command. The legacy
  compatibility adapter can also fall back to an old routine when the B01
  pointer is cleared, so clearing only the pointer would not be sufficient.
- `CalendarReadRepository` is the bounded, batched read owner used by
  Training and Today. It watches the settings row, so a lifecycle write can
  invalidate mounted surfaces without a second active-plan authority.
- B02 has one active draft row. A draft linked to the plan being ended must be
  blocked; a quick, occurrence-less draft remains resumable and is not
  silently discarded.

## Persistence and authority

Extend `TrainingPlanSettings` with nullable, portable lifecycle metadata:

- the last ended B01 version ID;
- the last end outcome (`finished` or `left`);
- the last end timestamp; and
- the last end command ID for retry idempotency.

This is a bounded marker, not a second active pointer or a plan-history table.
The version and all occurrence/session rows remain the source of historical
ancestry. Schema v20 adds the nullable columns. Backup-v10 continues to carry
the generated singleton row; old payloads omit the nullable keys and remain
readable, so a backup-v11 format is not required.

## Lifecycle command

Add one domain-owned `ProgramLifecycleRepository` with explicit Finish Plan
and Leave Plan commands/results. Each command has a caller command ID and runs
in one database transaction:

1. Resolve the singleton active pointer and validate the published version.
2. Return the prior result for the same command ID, or reject a different
   command when no plan is active.
3. Block when a B02 draft is linked to an occurrence in this plan, or when an
   in-progress occurrence has no recoverable draft. A quick draft is retained.
4. Cancel only this plan's unstarted (`planned`/`rescheduled`) occurrences,
   recording one append-only event per occurrence with the Finish/Leave reason.
   Terminal history and any already-created session are never rewritten.
5. Clear the active pointer/date/timezone and write the bounded end marker.

Finish means “the user declared this plan finished”; it does not fabricate
completed workouts. Leave means the user stopped using the plan. Both make
remaining actionable dates non-actionable and leave the user with a truthful
post-end state.

Activation clears the bounded end marker when it establishes a new active B01
version. The legacy compatibility adapter suppresses legacy fallback after a
recorded B01 end until a new B01 activation occurs, preventing a stale plan
from reappearing.

## Read and UI cohesion

- Keep Calendar read hydration batched; do not add per-card or per-day queries.
- Make Training’s `todayWorkout` and `upcoming` projections active-pointer
  aware while allowing completed/partial evidence to remain readable.
- Add a compact current-week strip built from the same bounded occurrence
  snapshot. Its week starts Monday in the selected IANA timezone and exposes
  status through text, icon shape, and accessible labels—not color alone.
- Add an explicit plan-actions sheet from Training and the active-plan surface:
  View plan, View calendar, Finish plan, and Leave plan. Confirmations explain
  what remains in history and what will stop being scheduled. Success refreshes
  Training/Calendar/Today through existing read invalidation.
- If a plan has ended, Training shows “Plan finished” or “Plan left”, preserves
  history access, and offers Quick Workout and Choose a plan. It must not show a
  stale current-plan card or actionable future occurrence.
- When activating a different plan, the review screen shows an explicit
  switch confirmation if another B01 plan is active. The existing B01 atomic
  activation semantics remain the authority; no hidden replacement or new
  router migration is introduced.
- Keep consumer copy free of internal terms such as occurrence, activation
  record, lifecycle, schedule instance, canonical program, and plan version.

## Verification plan

Add focused coverage for Finish/Leave, idempotency/atomicity, linked and quick
draft handling, terminal occurrence preservation, future/today cancellation,
legacy fallback suppression, plan switching confirmation, the Monday week
strip, and post-end Training copy. Run the existing B01, B02, R7B, R07C,
Today, Calendar, History, and R07E regression suites, plus backup/schema
round-trip coverage. Inspect only meaningful golden updates.

Before handoff, run Dart formatting, `flutter analyze`, `git diff --check`,
the full serial `flutter test -j 1`, and:

```text
flutter build ios --release --no-codesign --dart-define=INDIFIT_API_KEY=test_key
```

No merge, push, reset, clean, stash, or unrelated staging is part of this
batch.
