# IndiFit R07F-1 — Training Lifecycle & Plan Cohesion Review

## Baseline

- Implementation branch: `ux/r07f-training-lifecycle`
- Implementation commit: `802514a` (`feat(r07f): add training plan lifecycle
  cohesion`), directly on top of `eefc9ae` (`Merge R07F-0`, verified in
  ancestry).
- Review-and-resolve pass performed on the same branch; review commit recorded
  below. No merge or push. Unrelated user-owned worktree changes (reference
  screenshots, old-dashboard deletions, `ios/Flutter/Release.xcconfig`, R07D
  golden/test edits, audit docs, failure artifacts) preserved untouched.

## B01 architecture (traced)

`TrainingPlanSettings.activeProgramVersionId` remains the **sole active-plan
pointer**. Activation (`ProgramActivationCoordinator`) validates + publishes +
materializes dated occurrences + updates the pointer in one transaction and
now also clears the end marker. Occurrence execution stays owned by
`CalendarRepository` (append-only events, terminal preservation). Ending a plan
is owned by the new `ProgramLifecycleRepository`. UI is a projection of these
authorities via `CalendarReadRepository` (batched, watch-driven).

## Lifecycle marker authority

The four nullable v20 settings fields (`lastEndedProgramVersionId`,
`lastEndedOutcome`, `lastEndedAtUtc`, `lastEndedCommandId`) are
**presentation-only bounded metadata plus a retry idempotency key**:
used only by the lifecycle repository (idempotent replay + conflict
detection), activation (clear), the legacy adapter (fallback suppression),
the read repository (name/outcome projection), and Training presentation. A
usage audit found **no** consumer answering historical questions from it
(e.g., "was plan X finished"). Historical truth remains the append-only event
graph; only the latest ended outcome is a product concept today (documented
limitation, not silently claimed history).

## Finish Plan

Requires an active published version; returns the prior result for a repeated
command ID and rejects a different outcome for the same ID; blocks linked
recoverable drafts (by `scheduledOccurrenceId` ancestry, never names) and
`inProgress` occurrences; cancels only this plan's `planned`/`rescheduled`
rows with one append-only event each; clears pointer/date/timezone and writes
the marker — all in one transaction. No completion fabrication: terminal rows,
sessions, sets, and ancestry untouched.

## Leave Plan

Same transactional safety; semantically distinct ("stopped using", never
"failed"/"abandoned"); copy verified neutral in the sheet, both confirm
dialogs, and post-end landing.

## Occurrence event semantics

Each affected future occurrence receives exactly **one append-only event**
recording `fromStatus → cancelled` with `eventType` `planFinished`/`planLeft`,
`reason` = outcome, and metadata carrying the version ID. The occurrence
projection interprets the row's `toStatus` (cancelled); the event type is the
human-facing cause. No state/event duplication on the same-command retry
(idempotent replay returns the recorded result without new writes). Verified
tests cover double-command, conflicting-outcome reuse, and interruption-style
retries.

**Review correction (labels)**: the Session-history label converter rendered
camelCase event types as single words ("Planfinished"; also pre-existing
"Startdiscarded"/"Repeatcreated"). Fixed: `occurrenceEventLabel` is now public
and splits both snake_case and camelCase ("Plan Finished", "Start
Discarded").

## Plan switching

Design is deliberately **Option B**: switching does not rewrite the old plan's
rows; inactive-plan occurrences become non-actionable schedule artifacts
enforced by (a) read filtering — range shows active-plan rows plus terminal
history only, overdue and next-required are active-plan-only — and (b) the
central `_requireActivePlan` mutation guard. A dormant explicit cancellation
mechanism (`cancelPriorOccurrenceIds` + `activationCancelled` events) exists
in the activation command for callers that want Option A semantics.

**Verified non-defect**: re-activating the *same* published version is
rejected by B01 ("create a replacement draft"), so duplicate/resurrected
occurrences from re-activation are impossible by construction; every
activation materializes a fresh version's schedule.

**Review correction (defense-in-depth)**: the guard covered `start`,
`restore`, and `repeat` only. `skip`, `cancel`, and `reschedule` still
mutated inactive-plan occurrences (empirically confirmed by probe before the
fix). All six mutation paths now enforce the active-plan invariant.

## Draft / in-progress protection

Linked drafts block ending via `scheduledOccurrenceId` membership in the
active plan's occurrence set (canonical ancestry; quick drafts — null link —
are untouched and remain resumable; a draft linked to another, inactive plan
does not block ending the active one). `inProgress` occurrences without a
recoverable draft fail closed with recovery guidance. Consumer copy verified
("Finish or discard the current workout before ending this plan."), no IDs.

## Quick Workout independence

Occurrence-less drafts survive Finish and Leave (tested; the cleanup filter
selects only drafts linked to the ended plan's occurrences).

## Historical integrity

Terminal rows (completed / partiallyCompleted / skipped / cancelled) are never
rewritten and receive no new events; session/sets ancestry intact; event
history append-only. The singleton marker replacing Finish→Leave sequences
means only the latest outcome is presented — accepted as the bounded design.

## Today integration

`todayVisibleWorkoutOccurrences` filters skipped/cancelled from actionable
presentation while completed/partial evidence stays readable; watch-based
invalidation from the settings row updates Today/Training/Calendar without
restart (verified by the implementer's tests; landing tests assert the
post-end state).

## Calendar integrity

Past terminal facts remain visible across versions; stale actionable rows
are hidden by reads and now blocked in **all** mutation paths; the
occurrence action sheet exposes actions only for rows that pass the same
status gates.

## Week progression

Single bounded `readSnapshot` for [week start, max(week end, +14d)] — no
N+1; Monday start in the selected IANA timezone; states map to canonical
occurrence status with text + icon shape + semantics (not color alone);
same-day collapse prioritizes any-pending → scheduled (a completed+pending
day never reads "Completed"); a completed Quick Workout is never linked to a
planned occurrence.

**Review correction (§38)**: empty days were labeled "recovery day" — an
inference B01 cannot support (no explicit rest evidence; empty also means
no-plan-data). Now neutral: `no workout scheduled` with a neutral icon and
the semantics label extracted to a tested pure function
(`trainingWeekDaySemanticLabel`). R04 goldens pass unchanged (their fixtures
fill the week).

## Training landing hierarchy

Start/Resume stays dominant; Finish/Leave live behind the plan-actions sheet
as contextual secondary actions; the post-end state is a restrained status
inside the CURRENT PLAN slot (not a hero state) with Quick Workout, Choose a
plan, and history access; the ended status persists until the next activation
by design (marker cleared on activation — no stale "Plan finished" after a
new plan is active; tested).

## Navigation

Existing targeted routes; no duplicates; screens refresh via invalidation
after lifecycle mutations. Raw `Navigator.push` usage remains in places but
is coherent (no forced migration, per scope).

## Schema v20

Four nullable columns + `CHECK (last_ended_outcome IN ('finished','left'))`,
added transactionally with already-present-column tolerance for
schemaVersionOverride fixtures; fresh and migrated schemas match; migration
tests (v15/v18/v19/v20 boundaries) pass.

## Backup v10 compatibility

Backup stays v10 deliberately: the settings row round-trips through the
generated singleton JSON, so new nullable keys survive and older payloads
without them restore as null (no invented end state). Round-trip tests cover
active-plan restore, ended-plan restore, and old payloads. No format bump
needed; no silent field loss.

## B04 integrity

Adaptive coaching reads the active pointer through the same watch-driven
settings row, so ending/switching invalidates assumptions without a second
authority. No B04 code changed; its suites pass.

## Findings resolved in this review

| # | Severity | Root cause | Fix |
|---|---|---|---|
| 1 | High (defense-in-depth) | `_requireActivePlan` guarded only start/restore/repeat; skip/cancel/reschedule could mutate inactive-plan occurrences (probe-confirmed) | Guard added to all three; regression asserts rejection + untouched row + no new events |
| 2 | Medium | Session-history label converter didn't split camelCase event types ("Planfinished", pre-existing "Startdiscarded") | Public `occurrenceEventLabel` splits both cases; unit-tested |
| 3 | Medium (spec §38) | Week strip labeled empty days "recovery day" — inferred rest without evidence | Neutral `no workout scheduled` + neutral icon + tested pure label function |
| 4 | Low | Finish snackbar could read "0 future workouts stopped"; routine-display variant lacked pluralization and an async double-tap entry guard | Count-aware/pluralized copy in both surfaces; `_loading` entry guard |

Verified non-defects: same-version re-activation duplicates (B01 rejects);
marker-as-history (usage audited, presentation-only); atomicity (single
transaction); idempotency (replay + conflict tested).

## Tests

- Focused: `ux_r07f_training_lifecycle_test.dart` now 11 tests (8
  implementation + 3 review regressions), all passing.
- Regression batches: R04 Training + goldens, R7B quick workout, R07C
  workout experience + reliability gate, R07E progress, calendar controller,
  occurrence state machine, program calendar widget, backup v10, schema
  v15/v19 migrations, B02 compatibility/preparation, legacy adapter — all
  passing (90 focused tests across batches).
- Full serial suite: see final count in the review commit message
  (implementation baseline was 1,424; final includes the 3 new regressions).

## Analyze / Format / Diff

`dart format` clean · `flutter analyze --no-pub` 0 issues · `git diff --check`
clean.

## iOS Release Build

`flutter build ios --release --no-codesign
--dart-define=INDIFIT_API_KEY=test_key` — result recorded in the final
handoff. Build-only; no device activity.

## Deferred to R07F-2+

Plan analytics / richer completion summaries; broader plan-history browsing
beyond the bounded last-ended presentation; multi-plan lifecycle history as a
product concept (if ever needed, from the event graph); activating the
dormant Option-A switch cancellation for explicit per-occurrence choice;
hydration, PR engine, media, e1RM, broad routing migration (unchanged scope
boundaries).

## Review Commit

Recorded in the final handoff (single review commit on
`ux/r07f-training-lifecycle`).

## Verdict

Ready to merge R07F-1
