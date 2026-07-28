# B01 — Ordered Implementation Backlog

This backlog implements the approved `PLAN.md` and `DECISIONS.md`. It is
dependency ordered; a task may be reviewed independently only after its listed
dependencies are accepted. No task may broaden B01 into adaptive progression,
advanced sets, a cardio redesign, a substitution recommendation engine, or
per-exercise notification scheduling.

## Dependency overview

| ID | Title | Depends on | Recommended model | Risk | Size |
|---|---|---|---|---|---|
| B01-01 | Freeze identity/equipment migration fixtures | — | Gemini Flash | High data quality | M |
| B01-02 | Approve v15 migration and backup graph contract | B01-01 | Sol High | Critical data loss | M |
| B01-03 | Add v15 tables, DTOs, and migration | B01-02 | Sol High | Critical data loss | L |
| B01-04 | Repair backward-compatible workout draft serialization | B01-03 | Gemini Flash | High user data loss | S |
| B01-05 | Implement program authoring/version repository | B01-03 | Terra High | High invariants | L |
| B01-06 | Implement activation and occurrence state machine | B01-03, B01-05 | Sol High | Critical semantics | L |
| B01-07 | Implement equipment profiles and preference aggregates | B01-03, B01-01 | Gemini Flash | Medium | M |
| B01-08 | Implement calendar/travel read models and controllers | B01-06, B01-07 | Terra High | High multi-domain | L |
| B01-09 | Bridge occurrence execution to player/history | B01-04, B01-06, B01-07 | Terra High | High compatibility | L |
| B01-10 | Implement Backup v6 and v5 import compatibility | B01-03, B01-04, B01-07, B01-09 | Sol High | Critical portability | L |
| B01-11 | Build program authoring/calendar/travel UI | B01-05, B01-08, B01-09 | Terra High | Medium | L |
| B01-12 | Build equipment/preferences UI and player panel | B01-07, B01-09 | Gemini Flash | Medium | M |
| B01-13 | Legacy compatibility adapter and regression sweep | B01-05, B01-09, B01-11 | Terra High | High regression | M |
| B01-14 | Final cross-domain verification and release gates | B01-01–B01-13 | Sol High | Critical | M |

## B01-01 — Freeze exercise identity and equipment mapping fixtures

- Goal: produce the deterministic inputs that make migration safe.
- Dependencies: none.
- Recommended model: Gemini Flash.
- Risk / size: High data-quality risk / M.
- Exact scope: audit `Exercises` seed data and legacy routine/set names; define
  exact case-fold/whitespace normalization, zero/one/many result fixtures,
  canonical equipment code mapping fixtures, and known legacy
  `equipmentAccess` mappings. Add only fixture/test data and an audit report.
- Implementation instructions: enumerate duplicate catalog names before
  defining matcher expectations; ensure custom exercises are handled as exact
  existing rows where applicable; make unknown legacy strings fixtures rather
  than errors.
- Prohibited changes: no production migration, no asset “cleanup”, no aliases
  based on fuzzy/substrings, no schema or UI changes.
- Acceptance criteria: every fixture has expected `resolved`, `ambiguous`, or
  `unresolved` result; mappings are deterministic across input order.
- Tests: focused unit tests for normalizer/lookup fixtures.
- Validation commands: `flutter test test/<identity-fixture-test>.dart`;
  `flutter analyze`.
- Definition of done: a Sol reviewer can approve the fixture set without
  guessing an identity rule. **SOL-GATE REQUIRED** before B01-02.

## B01-02 — Approve v15 migration and Backup v6 graph contract

- Goal: translate the plan into an implementation-level migration/restore
  contract before any production schema work.
- Dependencies: B01-01.
- Recommended model: Sol High.
- Risk / size: Critical data loss / M.
- Exact scope: confirm each v15 table/column/index/FK, text UUID strategy,
  nullable ancestry, deterministic legacy program import, singleton settings,
  transition validation ownership, and B01 BackupData graph order.
- Implementation instructions: review representative v14 and v5 fixtures;
  document transaction order and failure/rollback assertions in the task PR.
- Prohibited changes: do not implement UI, alter historical session ancestry,
  or decide product-owner travel/skip behavior unilaterally.
- Acceptance criteria: no unresolved FK cycle, no destructive legacy-table
  action, and every v6 collection has a v5 default/import rule.
- Tests: reviewable migration/backup test matrix and fixture manifests.
- Validation commands: `flutter test test/db_migration_test.dart test/backup_restore_transaction_test.dart`.
- Definition of done: recorded approval of the migration, identity, state, and
  backup contracts. **SOL-GATE REQUIRED**.

## B01-03 — Add schema v15, relational DTOs, and transactional v14 migration

- Goal: land the durable B01 foundation without breaking v14 data.
- Dependencies: B01-02.
- Recommended model: Sol High.
- Risk / size: Critical data loss / L.
- Exact scope: add required tables/indexes and listed existing-table nullable
  columns; bump schema 14→15; implement the deterministic one-block legacy
  import, default equipment profile migration, exact set-ID backfill, and
  `TrainingPlanSettings` creation.
- Implementation instructions: use a single migration transaction; retain all
  legacy rows; order legacy IDs deterministically; do not materialize an active
  schedule if an active legacy draft exists; keep migration helpers reusable by
  v5 restore. Add fresh-DB and representative upgrade fixtures.
- Prohibited changes: no deletion/replacement of legacy routine tables, no
  fuzzy identity backfill, no historical session-to-occurrence inference, no
  backup format bump in this task.
- Acceptance criteria: all v14 fixtures upgrade; every expected new row/index
  exists; unknown identities remain null/raw-name; forced failure rolls back.
- Tests: database CRUD, full v14 migration chain/fixture tests, FK/index
  assertions, transaction rollback test.
- Validation commands: `dart format --set-exit-if-changed lib/data/database test`; `flutter analyze`; `flutter test test/db_migration_test.dart test/<b01-migration-test>.dart`.
- Definition of done: schema and migration are reviewed with fixture output
  attached. **SOL-GATE REQUIRED**.

## B01-04 — Repair backward-compatible workout draft serialization

- Goal: stop losing existing set fields and support occurrence snapshots.
- Dependencies: B01-03.
- Recommended model: Gemini Flash.
- Risk / size: High user data loss / S.
- Exact scope: add v15 draft columns/default; implement a versioned envelope
  serializer/parser preserving all set fields named in the charter and optional
  occurrence/snapshot; use parser defaults for legacy bare arrays.
- Implementation instructions: keep single-draft behavior; make malformed JSON
  a typed recoverable result (never a crash); test old and new draft payloads.
- Prohibited changes: no multiple-draft redesign, no player visual redesign,
  no changes to set semantics.
- Acceptance criteria: RPE, type, warm-up, duration, distance, incline, and
  notes survive save/resume; old v14 JSON resumes with documented defaults.
- Tests: unit serialization matrix; repository draft persistence regression;
  player-controller resume test.
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
  a copied active version is editable; direct active-version edits fail without
  partial writes.
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
  and query indexes/read models.
- Implementation instructions: inject clock/timezone provider for tests; apply
  all transition changes and event inserts in one transaction; preserve original
  date/zone; return typed invalid-transition errors; do not auto-handle overdue
  sessions.
- Prohibited changes: no drag/drop UI, no shifting other occurrences, no
  re-opening terminal records, no automatic substitutions/advancement.
- Acceptance criteria: every PLAN state transition is covered, cross-week/block
  moves retain ordinal, timezone changes preserve civil dates, and repeat makes
  a distinct linked record.
- Tests: pure state-machine unit table; repository DB transaction tests; DST/
  timezone fixtures; activation and event-history tests.
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

## B01-08 — Implement calendar and travel read models/controllers

- Goal: expose reactive date-range calendar and travel behavior without UI
  business rules.
- Dependencies: B01-06, B01-07.
- Recommended model: Terra High.
- Risk / size: High multi-domain coordination / L.
- Exact scope: range/today/week/month occurrence queries, `CalendarUiState`,
  `CalendarController`, travel context CRUD/controller, active profile
  resolution, derived overdue/travel/deload/compatibility flags, and precise
  provider invalidation.
- Implementation instructions: query by effective local date/status indexes;
  resolve travel from stored range/zone without mutating occurrence; ensure
  controller commands call state-machine repository methods only.
- Prohibited changes: no screen implementation, no persisted calendar UI state,
  no auto-volume changes or program-order changes due to travel.
- Acceptance criteria: travel profile overrides applies only in range, normal
  context resumes after range, and all mutation/provider invalidation tests pass.
- Tests: provider/controller tests, date-range repository tests, offline
  restart test, overlap validation test.
- Validation commands: `flutter test test/<calendar-controller-tests>.dart test/<travel-tests>.dart`; `flutter analyze`.
- Definition of done: controllers contain no SQL and calendar state is not in
  SharedPreferences.

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
  one transaction or compensating guarded workflow; preserve existing
  `WorkoutRepository` history APIs and name equality.
- Prohibited changes: no `ActivitySession` redesign, no changes to PR math,
  no exercise-history ID-only cutover, no edits to source version/template from
  substitutions.
- Acceptance criteria: scheduled full/partial completion has immutable
  snapshot/ancestry, player resume preserves all fields, unscheduled logging
  is unchanged, and a second start is blocked while draft exists.
- Tests: repository/controller bridge tests, player route/widget tests, full
  end-to-end in-memory DB test, legacy player regression test.
- Validation commands: `flutter test test/<execution-bridge-tests>.dart test/<workout-player-tests>.dart`; `flutter analyze`.
- Definition of done: old routine launch and manual log tests remain green.

## B01-10 — Implement Backup v6 and Backup v5 import compatibility

- Goal: ensure every B01 user-owned row is portable without weakening atomic
  restore.
- Dependencies: B01-03, B01-04, B01-07, B01-09.
- Recommended model: Sol High.
- Risk / size: Critical portability / L.
- Exact scope: BackupData v6 DTO/json/envelope counts, graph validation,
  create/export/restore ordering/remapping, v5 default parsing and deterministic
  legacy-program import on restore, extended session/set/draft serialization.
- Implementation instructions: prevalidate every B01 relationship/enum/date/
  timezone before SharedPreferences or DB mutation; retain existing preference
  compensation and single DB transaction; preserve legacy routine payloads.
- Prohibited changes: no backup encryption format change, no non-atomic
  restore, no acceptance of future versions, no unregistered user-owned B01
  table omitted from export.
- Acceptance criteria: v5 import passes, v6 round trip is graph-equivalent,
  orphan/malformed input fails with zero DB changes, and legacy records survive.
- Tests: BackupData parser unit tests, v5/v6 restore integration tests,
  transaction rollback/failure injection, encrypted envelope regression.
- Validation commands: `flutter test test/backup_schema_test.dart test/backup_restore_transaction_test.dart test/<b01-backup-tests>.dart`; `flutter analyze`.
- Definition of done: full backup contract review completed. **SOL-GATE REQUIRED**.

## B01-11 — Build program, calendar, and travel MVP UI

- Goal: deliver accessible multi-screen planning journeys after behavior is
  frozen.
- Dependencies: B01-05, B01-08, B01-09.
- Recommended model: Terra High.
- Risk / size: Medium / L.
- Exact scope: draft author/review/activation screens, today/week/month
  calendar, occurrence detail/actions/date picker, version-copy flow, travel
  date/profile/preview/apply/end flow, routes and loading/error/empty states.
- Implementation instructions: use controller commands/read models; use action
  sheets and date pickers rather than drag-to-reschedule; label timezone,
  deload, overdue and travel states accessibly; use semantic theme tokens.
- Prohibited changes: no direct repository SQL in widgets, no drag/drop, no
  automatic substitution/volume changes, no dashboard redesign.
- Acceptance criteria: listed PLAN user journeys complete from UI; destructive
  actions confirm/undo only when state rules allow; large text remains usable.
- Tests: widget tests for author/review/calendar/action sheets; integration
  test for create→activate→reschedule→start; golden/accessibility tests where
  harness exists.
- Validation commands: `flutter test test/<b01-program-widget-tests>.dart test/<b01-calendar-widget-tests>.dart`; `flutter analyze`.
- Definition of done: UI contains no independent progression calculations.

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
- Acceptance criteria: profile/default/travel selection and note/setup/cue
  editing work through UI; panel shows correct start snapshot.
- Tests: widget/controller tests for each CRUD action, player panel snapshot
  regression, semantics/large-text test.
- Validation commands: `flutter test test/<b01-equipment-widget-tests>.dart test/<b01-preference-widget-tests>.dart`; `flutter analyze`.
- Definition of done: UI is bounded to approved repositories/controllers.

## B01-13 — Legacy compatibility adapter and regression sweep

- Goal: prove existing routine/history behavior survives B01 adoption.
- Dependencies: B01-05, B01-09, B01-11.
- Recommended model: Terra High.
- Risk /size: High regression / M.
- Exact scope: route legacy routine display/editor/wizard users through explicit
  compatibility adapter or B01 entry prompts, retain last-routine behavior,
  preserve manual log/history/progress queries, and eliminate duplicate
  authoritative active-routine selection.
- Implementation instructions: put conversion choices in coordinator/repository
  boundaries; test old backup/import and preexisting draft paths; emit no
  hidden mutation just by viewing legacy UI.
- Prohibited changes: no deletion of legacy tables/screens, no historical query
  rewrite requiring exercise IDs, no silent program activation without the
  migration rules in PLAN.
- Acceptance criteria: existing routine creation/view/edit and history tests
  pass; legacy and B01 entry points do not select conflicting active plans.
- Tests: regression suite for `WorkoutRepository`, routine display/editor,
  manual log, history/progress, migration/import integration.
- Validation commands: `flutter test test/wave3_features_test.dart test/<legacy-b01-regression-tests>.dart`; `flutter analyze`.
- Definition of done: test evidence demonstrates B01 did not remove a v14
  journey.

## B01-14 — Final cross-domain verification and release gates

- Goal: independently verify that the delivered batch matches the charter and
  this architecture.
- Dependencies: B01-01 through B01-13.
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
