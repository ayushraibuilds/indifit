# B01 — Ordered Implementation Backlog

This backlog implements the approved `PLAN.md` and `DECISIONS.md`. It is
dependency ordered; a task may be reviewed independently only after its listed
dependencies are accepted. No task may broaden B01 into adaptive progression,
advanced sets, a cardio redesign, a substitution recommendation engine, or
per-exercise notification scheduling.

## Dependency overview

| ID | Title | Depends on | Recommended model | Risk | Size | Status |
|---|---|---|---|---|---|---|
| B01-01 | Freeze identity/equipment migration fixtures | — | Gemini Flash | High data quality | M | Verified |
| B01-02 | Build real v14/v5 migration and backup fixture harness | — | Gemini Flash, Sol review | High test-foundation | M | Verified |
| B01-04 | Repair backward-compatible draft codec and pre-save lifecycle | — | Gemini Flash, Sol review | High user data loss | S | Verified |
| B01-03 | Add stable exercise IDs, accepted v15 graph, and migration | B01-01, B01-02, PO travel/reminder decisions | Sol High | Critical data loss | L | Verified |
| B01-05 | Implement program authoring/version repository | B01-03 | Terra High | High invariants | L | Verified |
| B01-06 | Implement activation and occurrence state machine | B01-03, B01-05 | Sol High | Critical semantics | L | Verified |
| B01-07 | Implement equipment profiles and preference aggregates | B01-03, B01-01 | Gemini Flash | Medium | M | Verified |
| B01-08A | Implement calendar read models and controllers | B01-06 | Terra High | High scheduling | M | Verified |
| B01-08B | Implement travel coordination | B01-06, B01-07, PO travel decision | Terra High, Sol review | High multi-domain | M | Verified |
| B01-09 | Bridge occurrence execution to player/history | B01-04, B01-06, B01-07 | Terra High, Sol review | High compatibility | L | Verified |
| B01-13 | Legacy compatibility adapter and regression sweep | B01-05, B01-09 | Terra High, Sol review | High regression | M | Verified |
| B01-10 | Implement Backup v6 and v5 import compatibility | B01-03, B01-04, B01-06, B01-07, B01-08B, B01-09, B01-13, conditional reminder task | Sol High | Critical portability | L | Verified |
| B01-11A | Build program authoring and calendar UI | B01-05, B01-08A, B01-09, B01-13, PO skip-UI decision | Terra High | Medium | L | Verified |
| B01-11B | Build travel UI | B01-08B, B01-11A, PO travel decision | Terra High | Medium | M | Verified |
| B01-12 | Build equipment/preferences UI and player panel | B01-07, B01-09 | Gemini Flash | Medium | M | Verified |
| B01-07R | Implement scheduled exercise reminders, only if retained | B01-03, B01-07, PO reminder decision | Terra High, Sol review | High platform/state | M | Closed — not retained |
| B01-12R | Build reminder UI, only if retained | B01-07R, PO reminder decision | Terra High | Medium | S | Closed — not applicable |
| B01-14 | Final cross-domain verification and release gates | All applicable B01 tasks | Sol High | Critical | M | Verified |

## Exact execution order

1. Start B01-01, B01-02, and B01-04 in parallel. Each is independently
   reviewable and does not depend on unresolved product scope.
2. Record the travel and reminder product decisions; then run B01-03 after
   B01-01/B01-02 pass their Sol reviews.
3. Run B01-05 and B01-07 in parallel.
4. Run B01-06.
5. Run B01-08A and B01-09 in parallel after their dependencies.
6. Run B01-08B only after the travel decision. Run B01-07R only when scheduled
   reminders are retained.
7. Run B01-13 before replacing the legacy training route.
8. Run B01-10 after all durable conditional entities and execution ancestry are
   implemented.
9. Run B01-11A and B01-12; then B01-11B and B01-12R when applicable.
10. Run B01-14 last.

## B01-01 — Freeze exercise identity and equipment mapping fixtures

- Goal: produce the deterministic inputs that make migration safe.
- Dependencies: none.
- Recommended model: Gemini Flash.
- Risk / size: High data-quality risk / M.
- Exact scope: audit `Exercises` seed data and legacy routine/set names; define
  the stable seeded-catalogue ID manifest, custom UUID expectations, approved
  one-to-one aliases, exact case-fold/whitespace normalization, zero/one/many
  result fixtures, canonical equipment code mappings, and known legacy
  `equipmentAccess` mappings. Add only fixture/test data and an audit report.
- Implementation instructions: enumerate duplicate catalog names before
  defining matcher expectations; ensure custom exercises are handled as exact
  existing rows where applicable; make unknown legacy strings fixtures rather
  than errors.
- Prohibited changes: no production migration, no asset “cleanup”, no aliases
  based on fuzzy/substrings, no schema or UI changes.
- Acceptance criteria: every fixture has expected `resolved`, `ambiguous`, or
  `unresolved` result; stable seeded IDs survive rename fixtures; mappings are
  deterministic across input order.
- Tests: focused unit tests for normalizer/lookup fixtures.
- Validation commands: `flutter test test/<identity-fixture-test>.dart`;
  `flutter analyze`.
- Definition of done: a Sol reviewer can approve the fixture set without
  guessing an identity rule. **SOL-GATE REQUIRED** before B01-03.

## B01-02 — Build real v14/v5 migration and backup fixture harness

- Goal: replace the current fresh-database-only “migration” coverage with
  representative, deterministic v14 database and Backup v5 fixtures.
- Dependencies: none.
- Recommended model: Gemini Flash with Sol review.
- Risk / size: High test-foundation risk / M.
- Exact scope: create fixture builders/files for zero/one/multiple routines,
  historical sessions/sets, custom and unresolved exercises, active legacy
  draft JSON, known/unknown equipment strings, malformed relationships, and
  injected migration/restore failure. Add assertions that open a real v14
  schema and verify rollback.
- Implementation instructions: fixtures must describe source rows exactly and
  avoid depending on future v15 generated companions. Keep identity outcomes in
  expected-data files that B01-01 can fill/approve.
- Prohibited changes: no production v15 migration, no feature schema, no
  automatic mapping policy, no UI.
- Acceptance criteria: the harness demonstrably runs an on-disk v14→current
  upgrade rather than only `AppDatabase.memory()`; v5 restore fixtures exercise
  existing prevalidation and transactional rollback.
- Tests: fixture determinism, real upgrade opening, failed-upgrade preservation,
  v5 valid/orphan/unsupported-version restore.
- Validation commands: `flutter test test/db_migration_test.dart test/backup_restore_transaction_test.dart`.
- Definition of done: fixture manifest and harness are accepted by Sol before
  B01-03. **SOL-GATE REQUIRED**.

## B01-03 — Add stable exercise IDs, accepted v15 graph, and transactional migration

- Goal: land the durable B01 foundation without breaking v14 data.
- Dependencies: B01-01, B01-02, and recorded product-owner decisions for
  travel/reminder scope because both can affect the one-time v15 schema.
- Recommended model: Sol High.
- Risk / size: Critical data loss / L.
- Exact scope: add portable stable IDs to exercises; add the accepted
  program/profile/preference/occurrence tables, constraints and listed
  existing-table nullable columns; bump schema 14→15; implement deterministic
  one-block legacy-import snapshots, source mapping, default equipment profile,
  stable-ID backfill, and empty singleton training settings.
- Implementation instructions: use a single migration transaction; retain all
  legacy rows; order sources deterministically; never auto-select an active B01
  version, activation date, or occurrence; keep import helpers reusable by v5
  restore; make `TrainingPlanSettings.activeProgramVersionId` the only active
  authority; use `draft/published/archived` lifecycle and progression/repeat
  fields from `DECISIONS.md`.
- Prohibited changes: no deletion/replacement of legacy routine tables, no
  fuzzy identity backfill, no historical session-to-occurrence inference, no
  migration-time scheduling, no `ProgramVersions.status=active`, no backup
  format bump in this task.
- Acceptance criteria: all v14 fixtures upgrade; every expected new row/index
  exists; seeded/custom stable IDs are portable; unknown identities remain
  null/raw-name; no active version/occurrence is invented; forced failure
  rolls back.
- Tests: database CRUD, full v14 migration chain/fixture tests, FK/index
  assertions, transaction rollback test.
- Validation commands: `dart format --set-exit-if-changed lib/data/database test`; `flutter analyze`; `flutter test test/db_migration_test.dart test/<b01-migration-test>.dart`.
- Definition of done: schema and migration are reviewed with fixture output
  attached. **SOL-GATE REQUIRED**.

## B01-04 — Repair backward-compatible workout draft serialization

- Goal: stop losing existing set fields and remove the pre-summary draft-loss
  window before B01 schema work begins.
- Dependencies: none.
- Recommended model: Gemini Flash with Sol review.
- Risk / size: High user data loss / S.
- Exact scope: implement a versioned codec inside the existing
  `WorkoutDrafts.loggedSetsJson` field; preserve all supported set fields; parse
  legacy bare arrays; make dashboard resume use the codec; retain the draft
  through the summary and delete it only after successful legacy session save
  or explicit discard.
- Implementation instructions: keep single-draft behavior; make malformed JSON
  a typed recoverable result (never a crash); disable duplicate summary-save
  submission; test old/new payloads and save failure.
- Prohibited changes: no multiple-draft redesign, no player visual redesign,
  no v15 columns, no occurrence/snapshot schema, no changes to set semantics.
- Acceptance criteria: RPE, type, warm-up, duration, distance, incline, and
  notes survive save/resume; old v14 JSON resumes with documented defaults;
  app termination on summary retains a resumable draft; a successful session
  save deletes it once.
- Tests: unit serialization matrix; repository draft persistence regression;
  dashboard resume; summary double-tap/failure lifecycle.
- Validation commands: `dart format --set-exit-if-changed lib/features/workout_player lib/data`; `flutter test test/<draft-tests>.dart`; `flutter analyze`.
- Definition of done: old/new JSON tests pass and no existing draft test
  regresses. **SOL-GATE REQUIRED** review of data-loss fix.

## B01-05 — Implement program authoring and immutable version repository

- Goal: provide draft CRUD, version copying, and immutable aggregate reads.
- Dependencies: B01-03.
- Recommended model: Terra High.
- Risk / size: High invariants / L.
- Exact scope: `ProgramRepository`, authoring DTOs/read models, validation of
  blocks/weeks/templates/prescriptions, draft CRUD, copy-to-new-version,
  archive/delete eligibility, and provider interfaces.
- Implementation instructions: write only draft child rows; use repository
  guards for all immutable lifecycle states; use canonical exercise selection
  with raw fallback only as plan permits; preserve prescription order.
- Prohibited changes: no activation, occurrence scheduling, calendar screen,
  auto-load/RPE targets, or changes to legacy routine CRUD.
- Acceptance criteria: a draft can create a multi-block program with a deload;
  a copied currently selected published version is editable as a new draft;
  direct published-version edits fail without partial writes.
- Tests: repository/database lifecycle and ordinal tests; provider controller
  tests for validation/error state.
- Validation commands: `dart format --set-exit-if-changed lib/data lib/core/di test`; `flutter test test/<program-repository-tests>.dart`; `flutter analyze`.
- Definition of done: bounded authoring API is documented and has no dependency
  on player UI.

## B01-06 — Implement activation, occurrences, and state-machine guards

- Goal: make calendar instances correct, immutable after start, and auditable.
- Dependencies: B01-03, B01-05.
- Recommended model: Sol High.
- Risk / size: Critical scheduling semantics / L.
- Exact scope: `ProgramActivationCoordinator`, `CalendarRepository` mutation
  API, local-date/IANA-zone service, occurrence materialization, append-only
  events, reschedule/skip/cancel/repeat/start/partial/full transition checks,
  progression disposition/repeat purpose, command idempotency, and query
  indexes/read models.
- Implementation instructions: inject clock/timezone provider for tests; apply
  all transition changes and event inserts in one transaction; preserve original
  date/zone; enforce unique `(occurrenceId, commandId)` events and unique
  non-null session ancestry; return typed invalid-transition errors; allow
  confirmed past/future and cross-week/block starts/moves without changing
  ordinals; do not auto-handle overdue sessions.
- Prohibited changes: no drag/drop UI, no shifting other occurrences, no
  re-opening terminal execution records, no mutable progression cursor, no
  automatic substitutions/advancement.
- Acceptance criteria: every PLAN state transition is covered, cross-week/block
  moves retain ordinal, timezone changes preserve civil dates, partial/held
  skips stay pending, repeats have make-up/extra purpose, and duplicate commands
  are idempotent.
- Tests: pure state-machine unit table; repository DB transaction tests; DST/
  timezone fixtures; activation/event history; past/future starts; app
  termination state; duplicate/competing completion tests.
- Validation commands: `flutter test test/<occurrence-state-tests>.dart test/<calendar-repository-tests>.dart`; `flutter analyze`.
- Definition of done: state-machine test matrix and migration-free data tests
  are accepted. **SOL-GATE REQUIRED**.

## B01-07 — Implement equipment profiles and exercise preference aggregates

- Goal: add bounded durable CRUD for profiles, setups, notes, and cues.
- Dependencies: B01-03, B01-01.
- Recommended model: Gemini Flash.
- Risk / size: Medium / M.
- Exact scope: equipment profile/item and preference repositories, canonical
  compatibility service, default/archival safety checks, exact legacy import
  helper use, and preference aggregate DTOs/providers.
- Implementation instructions: treat `bodyweight` as capability only; make
  unknown requirement explicit; prevent deletion of referenced profile; keep
  seeded cues and set notes separate.
- Prohibited changes: no recommendation/substitution engine, no global
  reminder rewrite, no mutable catalog metadata.
- Acceptance criteria: known/unknown legacy equipment handling, default
  selection, item increments, bodyweight semantics, setup/cue order and note
  persistence work offline.
- Tests: CRUD/database constraints, compatibility truth table, archival guard,
  preference aggregate/repository tests.
- Validation commands: `flutter test test/<equipment-tests>.dart test/<exercise-preference-tests>.dart`; `flutter analyze`.
- Definition of done: repositories have no calendar or player screen imports.

## B01-08A — Implement calendar read models and controllers

- Goal: expose reactive date-range calendar and progression behavior without UI
  business rules or unresolved travel scope.
- Dependencies: B01-06.
- Recommended model: Terra High.
- Risk / size: High scheduling / M.
- Exact scope: range/today/week/month occurrence queries, `CalendarUiState`,
  `CalendarController`, active-program read model, derived overdue/deload/
  progression flags, same-date ordering, and precise provider invalidation.
- Implementation instructions: query by effective local date/status indexes;
  query stored civil dates with explicit calendar zone rather than UTC-midnight
  ranges; ensure controller commands call state-machine repository methods only.
- Prohibited changes: no screen implementation, no persisted calendar UI state,
  no travel behavior, no auto-volume changes, no screen-local progression.
- Acceptance criteria: date/zone, multiple-same-day, overdue, pending/satisfied/
  bypassed, and provider invalidation behavior matches `DECISIONS.md`.
- Tests: provider/controller tests, civil-date range/DST tests, same-day sort,
  progression read model, offline restart.
- Validation commands: `flutter test test/<calendar-controller-tests>.dart`; `flutter analyze`.
- Definition of done: controllers contain no SQL and calendar state is not in
  SharedPreferences.

## B01-08B — Implement travel coordination

- Goal: implement only the product-approved travel behavior without mutating
  normal program structure.
- Dependencies: B01-06, B01-07, and recorded product-owner travel decision.
- Recommended model: Terra High with Sol review.
- Risk / size: High multi-domain coordination / M.
- Exact scope: travel context/membership repository, preview/apply/cancel/end,
  equipment-profile override resolution, reschedule membership prompts,
  snapshot provenance, and targeted providers/controllers.
- Implementation instructions: if the recommended MVP is accepted, persist the
  explicitly previewed occurrence membership; never infer cross-zone inclusion
  later from UTC midnight; never mutate dates, ordinals, weeks, or deload flags.
- Prohibited changes: no automatic substitution engine, volume reduction,
  generated substitute week, or consumed/replaced normal week.
- Acceptance criteria: inclusive travel dates/zone, membership, override,
  cancellation/restoration, reschedule in/out, deload, snapshot, restart, and
  offline behavior match `B01-D09`.
- Tests: repository/controller tests, dateline/date-boundary fixtures, overlap/
  cancellation tests, offline restart and frozen-snapshot tests.
- Validation commands: `flutter test test/<travel-tests>.dart`; `flutter analyze`.
- Definition of done: Sol confirms travel has no hidden program-order or date
  mutation. **SOL-GATE REQUIRED**.

## B01-09 — Bridge scheduled occurrences to workout player and history

- Goal: start scheduled work safely while retaining current unscheduled flows.
- Dependencies: B01-04, B01-06, B01-07.
- Recommended model: Terra High.
- Risk / size: High compatibility / L.
- Exact scope: `WorkoutExecutionCompatibilityAdapter`, route arguments/read
  model, frozen execution snapshot creation, player draft linkage, completion
  update for full/partial sessions, player preferences panel data, and null
  ancestry for manual/unscheduled logging.
- Implementation instructions: freeze template/prescriptions and displayed
  setup/cues at start; only one active draft; finalize occurrence/session in
  one Drift transaction with conditional `inProgress` update, unique occurrence
  ancestry, client command ID, session/sets/event insert, and draft deletion
  last; retry returns the existing session; preserve existing `WorkoutRepository`
  history APIs and name equality.
- Prohibited changes: no `ActivitySession` redesign, no changes to PR math,
  no exercise-history ID-only cutover, no edits to source version/template from
  substitutions.
- Acceptance criteria: scheduled full/partial completion has immutable
  snapshot/ancestry, player resume preserves all fields, unscheduled logging
  is unchanged, a second start is blocked while draft exists, DB failure keeps
  draft/in-progress state, and duplicate completion cannot create two sessions.
- Tests: repository/controller bridge tests, player route/widget tests, full
  end-to-end in-memory DB test, legacy player regression test.
- Validation commands: `flutter test test/<execution-bridge-tests>.dart test/<workout-player-tests>.dart`; `flutter analyze`.
- Definition of done: old routine launch/manual log tests remain green and Sol
  accepts the atomic/idempotent finalization evidence. **SOL-GATE REQUIRED**.

## B01-10 — Implement Backup v6 and Backup v5 import compatibility

- Goal: ensure every B01 user-owned row is portable without weakening atomic
  restore.
- Dependencies: B01-03, B01-04, B01-06, B01-07, B01-08B, B01-09, B01-13,
  and B01-07R when scheduled reminders are retained.
- Recommended model: Sol High.
- Risk / size: Critical portability / L.
- Exact scope: BackupData v6 DTO/json/envelope counts, graph validation,
  create/export/restore ordering/remapping, v5 default parsing and deterministic
  inactive legacy-program import on restore, stable exercise IDs,
  progression/repeat/event command metadata, travel membership, conditional
  reminders, and extended session/set/draft serialization.
- Implementation instructions: prevalidate every B01 relationship/enum/date/
  timezone before SharedPreferences or DB mutation; retain existing preference
  compensation and single DB transaction; preserve legacy routine payloads.
- Prohibited changes: no backup encryption format change, no non-atomic
  restore, no acceptance of future versions, no unregistered user-owned B01
  table omitted from export.
- Acceptance criteria: v5 import passes, v6 round trip is graph-equivalent,
  orphan/malformed input and unsupported v7 fail with zero changes, no active
  version/occurrence is invented from v5, and legacy records survive.
- Tests: BackupData parser unit tests, v5/v6 restore integration tests,
  transaction rollback/failure injection, encrypted envelope regression.
- Validation commands: `flutter test test/backup_schema_test.dart test/backup_restore_transaction_test.dart test/<b01-backup-tests>.dart`; `flutter analyze`.
- Definition of done: full backup contract review completed. **SOL-GATE REQUIRED**.

## B01-11A — Build program authoring and calendar MVP UI

- Goal: deliver accessible multi-screen planning journeys after behavior is
  frozen.
- Dependencies: B01-05, B01-08A, B01-09, B01-13, and recorded product-owner
  skip-interaction decision.
- Recommended model: Terra High.
- Risk / size: Medium / L.
- Exact scope: draft author/review/activation screens, today/week/month
  calendar, occurrence detail/actions/date picker, version-copy flow, routes,
  and loading/error/empty states. Travel is explicitly excluded.
- Implementation instructions: use controller commands/read models; use action
  sheets and date pickers rather than drag-to-reschedule; label timezone,
  deload and overdue states accessibly; use semantic theme tokens.
- Prohibited changes: no direct repository SQL in widgets, no drag/drop, no
  travel UI, no automatic substitution/volume changes, no dashboard redesign.
- Acceptance criteria: the journeys as amended by `DECISIONS.md` complete from
  UI; destructive
  actions confirm/undo only when state rules allow; large text remains usable.
- Tests: widget tests for author/review/calendar/action sheets; integration
  test for create→activate→reschedule→start; golden/accessibility tests where
  harness exists.
- Validation commands: `flutter test test/<b01-program-widget-tests>.dart test/<b01-calendar-widget-tests>.dart`; `flutter analyze`.
- Definition of done: UI contains no independent progression calculations.

## B01-11B — Build travel MVP UI ✅ DONE

- Status: DONE.
- Implementation: `TravelModeScreen` (setup form + active summary),
  `TravelPreviewSheet` (preview bottom sheet with incompatibility display),
  `/travel-mode` route, calendar app bar travel badge. Verified via
  `test/b01_travel_widget_test.dart`.
- Goal: expose the approved travel preview/apply/cancel/restore journey.
- Dependencies: B01-08B, B01-11A, and recorded product-owner travel decision.
- Recommended model: Terra High.
- Risk / size: Medium / M.
- Exact scope: choose inclusive dates/destination zone/profile, preview
  occurrence membership and compatibility, apply, display badges, cancel/end,
  and restore normal profile.
- Implementation instructions: use only B01-08B controller/read models; clearly
  state that dates/order/deload are unchanged.
- Prohibited changes: no direct SQL, automatic substitution, volume transform,
  or hidden week consumption.
- Acceptance criteria: all approved travel journeys are accessible, offline,
  and show explicit affected occurrences before apply.
- Tests: widget/controller tests, large-text/semantics, offline integration.
- Validation commands: `flutter test test/<b01-travel-widget-tests>.dart`; `flutter analyze`.
- Definition of done: UI exactly matches the recorded product decision.

## B01-12 — Build equipment/preferences UI and player quick panel

- Goal: expose the approved simple CRUD and execution context.
- Dependencies: B01-07, B01-09.
- Recommended model: Gemini Flash.
- Risk / size: Medium / M.
- Exact scope: profile list/editor/default/archive interactions; exercise
  preference editor; detail/player “Your setup & cues” compact panel.
- Implementation instructions: clearly mark compatibility unknown; prevent
  unsafe deletion through repository error UX; player panel shows frozen
  snapshot and explains edits apply next workout.
- Prohibited changes: no catalog cue editing, no substitution recommender, no
  per-exercise scheduled reminders.
- Acceptance criteria: profile/default selection and note/setup/cue
  editing work through UI; panel shows correct start snapshot.
- Tests: widget/controller tests for each CRUD action, player panel snapshot
  regression, semantics/large-text test.
- Validation commands: `flutter test test/<b01-equipment-widget-tests>.dart test/<b01-preference-widget-tests>.dart`; `flutter analyze`.
- Definition of done: UI is bounded to approved repositories/controllers.

## B01-07R — Implement scheduled exercise reminders, only if retained

- Goal: implement the reminder domain only if the product owner selects
  scheduled per-exercise notifications.
- Dependencies: B01-03, B01-07, and recorded product-owner reminder decision.
- Recommended model: Terra High with Sol review.
- Risk / size: High platform/state coordination / M.
- Exact scope: typed Drift reminder records, repository/controller, effective
  dates/timezone, permissions, quiet-hours integration, local notification
  scheduling/cancellation, and Backup v6 DTO requirements.
- Implementation instructions: reconcile the historical
  `prefRemindWorkout`/`pref_remind_workout` backup alias; keep one notification
  coordinator and one durable reminder owner.
- Prohibited changes: no raw SharedPreferences reminder records, cloud service,
  adaptive coaching, or duplicate scheduling logic in widgets.
- Acceptance criteria: create/edit/disable/delete, timezone change, permission
  denial, quiet hours, offline restart, and backup behavior are deterministic.
- Tests: repository/controller, notification fake, timezone, permission,
  historical key-alias, and backup tests.
- Validation commands: `flutter test test/<exercise-reminder-tests>.dart test/phase5_notifications_test.dart`; `flutter analyze`.
- Definition of done: reminder scope is product-approved and Sol confirms
  single ownership/backup behavior. **SOL-GATE REQUIRED**.

## B01-12R — Build reminder UI, only if retained — ❌ CLOSED

- Status: CLOSED — not applicable.
- Rationale: B01-PD03 (Accepted) selected passive exercise cues, not scheduled
  per-exercise notifications. The definition of done states: "UI is omitted
  entirely if passive cues satisfy the product decision." Passive cues are
  fully served by `PlayerSetupCuesPanel` (B01-12) and
  `ExercisePreferenceEditorScreen` (B01-12). No scheduled-reminder domain
  (B01-07R) was retained, so no reminder UI exists.
- Original goal: expose scheduled reminder CRUD only if B01-07R exists.
- Dependencies: B01-07R and recorded product-owner reminder decision.
- Recommended model: Terra High.
- Risk / size: Medium / S.

## B01-13 — Legacy compatibility adapter and regression sweep

- Goal: prove existing routine/history behavior survives B01 adoption.
- Dependencies: B01-05, B01-09.
- Recommended model: Terra High with Sol review.
- Risk /size: High regression / M.
- Exact scope: route legacy routine display/editor/wizard users through explicit
  compatibility adapter or B01 entry prompts, retain last-routine behavior,
  preserve manual log/history/progress queries, and eliminate duplicate
  authoritative active-routine selection.
- Implementation instructions: put conversion choices in coordinator/repository
  boundaries; use explicit greatest legacy routine ID only for compatibility;
  read/write migrated program data after adapter cutover while retaining legacy
  rows for backup; test old backup/import and preexisting draft paths; emit no
  activation or occurrence just by viewing legacy UI.
- Prohibited changes: no deletion of legacy tables/screens, no historical query
  rewrite requiring exercise IDs, no silent program activation without the
  migration rules in PLAN.
- Acceptance criteria: existing routine creation/view/edit and history tests
  pass through the adapter; migrated snapshots are not silently mutated; legacy
  and B01 entry points do not select conflicting active plans.
- Tests: regression suite for `WorkoutRepository`, routine display/editor,
  manual log, history/progress, migration/import integration.
- Validation commands: `flutter test test/wave3_features_test.dart test/<legacy-b01-regression-tests>.dart`; `flutter analyze`.
- Definition of done: test evidence demonstrates B01 did not remove a v14
  journey and Sol accepts that no duplicate authority remains. **SOL-GATE REQUIRED**.

## B01-14 — Final cross-domain verification and release gates

- Verification status (2026-07-30): final Sol verification, platform manual
  matrix, automated cross-domain checks, and release-build gates are verified.
  B01 is ready for pull request.

- Goal: independently verify that the delivered batch matches the charter and
  this architecture.
- Dependencies: all applicable B01 tasks, including B01-07R/B01-12R only when
  scheduled reminders are retained.
- Recommended model: Sol High.
- Risk / size: Critical / M.
- Exact scope: review schema/migration, state-machine coverage, identity
  policy, backup v5/v6, offline behavior, platform timezone/draft checks,
  acceptance matrix traceability, and product-owner decision resolution.
- Implementation instructions: execute the full suite; inspect at least one
  real v14 fixture upgrade and v5 encrypted/non-encrypted import; record any
  unresolved product decision as a release blocker rather than assuming it.
- Prohibited changes: no feature additions during verification and no waiver of
  migration/backup failure.
- Acceptance criteria: all PLAN acceptance criteria are mapped to passing
  evidence; all SOL gates passed; product-owner decisions are recorded; Android
  and iOS manual checks pass.
- Tests: full automated suite plus manual timezone/DST, offline, accessibility,
  draft-kill/relaunch, backup-import, and release-build checks.
- Validation commands: `dart format --set-exit-if-changed lib test`; `flutter analyze`; `flutter test`; project Android release build; project iOS release build.
- Definition of done: B01 charter exit criteria are demonstrably met and final
  review is signed off. **SOL-GATE REQUIRED**.
