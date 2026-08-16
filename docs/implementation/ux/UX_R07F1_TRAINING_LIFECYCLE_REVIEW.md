# IndiFit R07F-1 — Training Lifecycle & Plan Cohesion Review

## Baseline

Started from local `main` at `eefc9ae` and worked on
`ux/r07f-training-lifecycle`. No merge or push was performed. The unrelated
pre-existing worktree changes remain unstaged and untouched.

## Existing B01 Plan Lifecycle

B01 already owns draft/published/archived program versions, the singleton
`TrainingPlanSettings.activeProgramVersionId` pointer, materialized
occurrences, append-only occurrence events, and workout-session ancestry.
Activation remains the atomic command that validates, publishes, materializes,
and makes one version active.

## Lifecycle Authority Added/Reused

Added `ProgramLifecycleRepository` as the domain owner for ending the active
plan. The active pointer remains the sole active-plan authority. Four nullable
settings fields provide only a bounded last-ended marker: version ID, outcome,
UTC timestamp, and command ID. Activation clears that marker.

## Finish Plan

Finish requires an active published plan, blocks linked recoverable drafts and
unrecoverable in-progress work, cancels only that plan's unstarted dates, and
records one append-only `planFinished` event per cancelled date. It clears the
active pointer without fabricating completed workouts.

## Leave Plan

Leave uses the same transactional safety rules and records `planLeft` events.
It preserves all completed, partial, skipped, cancelled, and session-backed
history while making remaining dates non-actionable.

## Draft Interaction

A B02 draft linked to an occurrence in the active plan blocks either end
command with recovery guidance. A quick, occurrence-less draft is retained and
remains resumable; no draft is silently discarded.

## Future Occurrences

Training and Calendar expose actionable upcoming dates only for the active
plan. After ending or switching, stale planned/rescheduled dates cannot be
started, restored, or repeated through the mutation repository guard.

## Historical Integrity

Terminal occurrence rows, append-only events, workout sessions, sets, and
program ancestry are retained. Calendar reads continue to expose terminal
history across versions while excluding stale actionable rows.

## Plan Switching

Program review now asks for explicit confirmation when another plan is active.
The user can keep the current plan or switch; the existing B01 activation
transaction remains the authority and no hidden replacement is performed.

## Training Landing

The Training landing has explicit plan actions: view plan, view calendar,
finish, and leave. After ending, it shows truthful “Plan finished” or “Plan
left” copy, history access, Quick Workout, and Choose a plan without a stale
current-plan card.

## Week Progression

Training includes a compact seven-day strip starting Monday in the selected
local timezone. Each day exposes date, status text, icon shape, and accessible
semantics for rest, scheduled, in progress, completed, partial, skipped, and
cancelled states.

## Today Integration

Today now filters skipped and cancelled planned occurrences from actionable
presentation while retaining completed and partial evidence. Its read path
continues to invalidate from the B01 settings/calendar authority after
lifecycle changes.

## Progress Integrity

No Progress write path or historical calculation was changed. Existing
progress projections continue to read completed B02 evidence only; the R07E
regression suite passes.

## Navigation

Actions use the existing targeted Training, Calendar, routine-display, and
Quick Workout routes. No broad router migration was introduced.

## Consumer Terminology

Visible copy uses “plan”, “workout”, “date”, “history”, “finish”, and “leave”.
Persistence and repository names retain precise implementation terminology
without exposing it in the consumer surface.

## Responsive / Accessibility

Lifecycle actions use existing B05 action primitives and confirmation sheets.
The week strip provides text and semantics in addition to color, and the
existing compact-width/large-text matrix remains green.

## B01 Integrity

The active pointer, published-version rules, occurrence state machine,
append-only event rules, ancestry, and activation idempotency remain intact.
The lifecycle command is atomic and command-id idempotent, with conflicting
reuse rejected.

## B02 Integrity

Linked drafts and in-progress execution are protected from destructive plan
ending. Quick Workout remains independent and resumable. The B02 execution and
draft regression suites pass.

## B04 Integrity

Backup-v10 continues to serialize the singleton settings row. Schema v20 adds
nullable lifecycle metadata; missing nullable keys from older payloads remain
readable. Migration and backup tests pass without changing the backup format
version.

## Backup / Persistence

The v19-to-v20 migration adds the four nullable settings columns transactionally
and is safe for fixtures whose declared schema already includes them. Lifecycle
writes update the pointer, marker, occurrences, and events in one transaction.

## Goldens

Only the meaningful R04 Training landing light/dark goldens were updated for
the current-week strip. The unrelated R07D golden change was not staged.

## Tests

- Focused lifecycle, occurrence-state, and downstream Today/Calendar/B02/R7B/R07C/R07E suites passed.
- Migration and backup coverage passed, including v18/v19 boundary cases and old nullable payloads.
- Full serial suite passed: `flutter test -j 1 --reporter compact` — 1,424 tests passed.

## Analyze / Format / Diff

All scoped Dart files were formatted. `flutter analyze --no-pub` passed with no
issues. `git diff --check` passed before handoff.

## iOS Release Build

The exact requested command passed:

```text
flutter build ios --release --no-codesign --dart-define=INDIFIT_API_KEY=test_key
```

Xcode produced `build/ios/iphoneos/Runner.app` successfully.

## Deferred to R07F-2+

Plan analytics, richer completion summaries, achievements, broader plan
history browsing, and any new lifecycle policy beyond Finish/Leave remain
deferred. Food, hydration, nutrition discovery, media, PR/e1RM, and broad
routing work remain outside this batch.

## Files Changed

The scoped batch changes B01 lifecycle persistence/repositories, Training,
routine display, program review, Today presentation, backup/schema expectations,
focused lifecycle tests, and the two R04 Training landing goldens. Existing
unrelated deletions, reference assets, audit files, R07D edits, and failure
artifacts remain outside the commit.

## Commit

This report is included in the single scoped R07F-1 batch commit; the commit
hash is recorded in the final handoff after commit creation.

## Verdict

Ready for R07F-1 review
