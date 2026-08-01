# B02 — Ordered Implementation Backlog

This backlog implements the B02 `PLAN.md` and `DECISIONS.md`. It is
dependency ordered. No task may introduce B04 readiness/coaching, infer an
exercise or modality from a display name, remove B01 compatibility data, or
write user-owned state outside Drift/backup policy.

## Dependency overview

| ID | Goal | Dependencies | Assigned model | Risk | Size |
|---|---|---|---|---|---|
| B02-01 | Freeze Sol-gate contracts and fixture matrix | — | Sol High | Critical semantics | M |
| B02-02 | Add v16 schema and migration harness | B02-01 | Sol High | Critical data loss | L |
| B02-03 | Add B02 DTOs, validators, codec v2 and compatibility read contracts | B02-02 | GPT Luna | High serialization | L |
| B02-04 | Implement program group authoring/repository contract | B02-03 | Terra High | High immutable graph | M |
| B02-05 | Implement strength execution/finalization successor | B02-03, B02-04 | Terra High | Critical execution integrity | L |
| B02-06 | Implement technique recording and rich-set editor primitives | B02-03 | GPT Luna | High data fidelity | M |
| B02-07 | Implement deterministic warm-up and rest services | B02-03 | GPT Luna | High recommendation UX | M |
| B02-08 | Implement explainable target rule v1 | B02-03, B02-07 | Sol High | Critical safety/integrity | L |
| B02-09 | Implement typed cardio/mobility and Health mapping repositories | B02-03 | Terra High | High modality/provenance | L |
| B02-10 | Integrate B02 player and activity UX flows | B02-05, B02-06, B02-07, B02-08, B02-09 | Terra High | High multi-screen state | L |
| B02-11 | Implement reviewed muscle mappings and volume read model | B02-03, B02-05, B02-06 | Sol High | Critical analytics validity | L |
| B02-12 | Implement history/progress/heat-map UI read models | B02-09, B02-10, B02-11 | GPT Luna | Medium display correctness | M |
| B02-13 | Implement Backup v7 and restore compatibility | B02-04 through B02-11 | Sol High | Critical portability | L |
| B02-14 | Complete legacy-adapter retirement and regression sweep | B02-10, B02-12, B02-13 | Terra High | High regression | M |
| B02-15 | Final verification and release gate | All B02 tasks | Sol High | Critical release quality | M |

## Exact execution order

1. Run B02-01 first and record every Sol-gate/product decision.
2. Run B02-02; do not start a durable B02 writer before its migration fixture
   suite is accepted.
3. Run B02-03. It establishes the DTO/codec contracts used by all feature work.
4. Run B02-04, B02-06, B02-07 and B02-09 in parallel where their dependencies
   permit. B02-08 starts after the target/rest inputs are stable.
5. Run B02-05 after the group contract, then B02-10 after every player-facing
   service is accepted.
6. Run B02-11 after rich strength records exist, then B02-12.
7. Run B02-13 after the complete durable entity set is present; run B02-14 and
   B02-15 last.

## B02-01 — Freeze Sol-gate contracts and fixtures

- Goal: convert the architecture decisions into approved fixtures and exact
  invariants before production schema or algorithms are written.
- Dependencies: none.
- Assigned model: Sol High.
- Risk: Critical semantics / M.
- Exact scope: review B02-D02/D03/D04/D06/D09/D10/D11; create deterministic
  fixture manifests for legacy v15 data, B02 group/technique/modality examples,
  equipment increments, reviewed muscle allocations, target comparator cases,
  and provider type mappings. Record the five product-owner outcomes or their
  provisional behavior in `DECISIONS.md`.
- Implementation instructions: enumerate exact IDs and expected outcomes; use
  stable IDs, never display-name matching; make all unknown/ambiguous examples
  explicit; include valid and invalid graph/backup fixtures.
- Prohibited changes: no production schema, data migration, UI, generated
  catalogue “cleanup,” inferred muscle contributions, or B04 recovery score.
- Acceptance criteria: every B02 gate has a written accept/amend/reject result;
  fixture cases cover the edge conditions named in the decision document; a
  reviewer can determine expected behavior without source-code guesses.
- Tests: fixture parser/determinism tests only.
- Validation commands: `flutter test test/b02_execution_fixture_matrix_test.dart test/exercise_identity_fixture_test.dart test/equipment_fixture_test.dart test/b01_schema_v15_migration_test.dart test/b01_backup_v6_test.dart test/backup_restore_transaction_test.dart`; `flutter analyze`.
- Definition of done: Sol signs off the schema/backup, identity, draft,
  technique, modality, mapping and target contracts. **SOL-GATE REQUIRED**.

## B02-02 — Add schema v16 and migration harness

- Goal: establish the B02 durable tables and a proven v15→v16 migration without
  losing or inventing historical facts.
- Dependencies: B02-01.
- Assigned model: Sol High.
- Risk: Critical data loss / L.
- Exact scope: implement the v16 extensions/new tables, constraints and indexes
  specified in `PLAN.md`; build an on-disk v15 fixture harness; add safe
  `legacy` session defaults; retain every B01/legacy table and existing draft
  field.
- Implementation instructions: use one explicit migration transaction; add
  indexes after table/column creation; do not populate B02 `Performed*`, group,
  mapping or detail rows from legacy text; preserve scheduled occurrence/draft
  linkage; include injected failure rollback coverage.
- Prohibited changes: no table/column deletion, no rewrite of v1 drafts, no
  session modality inference, no B02 backup version bump in this task, no UI.
- Acceptance criteria: a real v15 file upgrades with historical sessions/sets,
  an in-progress B01 scheduled draft, B01 program graph, custom/unresolved
  exercises and health provenance; rollback retains v15 state; all new FKs and
  checks reject invalid writes.
- Tests: database CRUD/constraint/index tests; real migration; failure rollback.
- Validation commands: `dart format --set-exit-if-changed lib/data/database test`; `flutter test test/db_migration_test.dart test/b01_schema_v15_migration_test.dart`; `flutter analyze`.
- Definition of done: fixture output and schema diff are reviewed by Sol.
  **SOL-GATE REQUIRED**.

## B02-03 — Add DTOs, validators, draft codec v2, and compatibility reads

- Goal: make B02 data serializable, validated and readable without changing the
  legacy write path prematurely.
- Dependencies: B02-02.
- Assigned model: GPT Luna.
- Risk: High serialization / L.
- Exact scope: create typed domain DTOs/enums for activity type, group, rich
  set, target, rest, cardio interval, mobility and muscle mapping; implement
  v2 execution-state codec; add repository validators; implement a legacy+B02
  history projection interface.
- Implementation instructions: preserve v0/v1 `WorkoutDraftCodec` decode
  behavior; include snapshot and rule-version fields; reject unknown future v2
  envelopes; validate against IDs/snapshot, not names; make legacy projection
  explicitly flag unknown/legacy coverage.
- Prohibited changes: no finalization replacement, group/player UI, health API
  change, schema alteration, automatic target calculation, or deletion of old
  set-type handling.
- Acceptance criteria: every new DTO round-trips draft JSON; invalid enum,
  tempo, segment, group and modality payloads fail loudly; existing v0/v1 tests
  pass unchanged; B02 queries can distinguish legacy from canonical records.
- Tests: codec, enum, validator, projection and malformed-payload tests.
- Validation commands: `dart format --set-exit-if-changed lib/core lib/data test`; `flutter test test/workout_draft_codec_test.dart test/workout_summary_lifecycle_test.dart`; `flutter analyze`.
- Definition of done: typed contract is consumed by no UI-specific JSON parser
  and is accepted by Terra/Sol integration review.

## B02-04 — Implement group authoring and repository contract

- Goal: let draft program versions create valid explicit supersets, circuits and
  giant sets without changing published/started structure.
- Dependencies: B02-03.
- Assigned model: Terra High.
- Risk: High immutable graph / M.
- Exact scope: add group/member CRUD to `ProgramRepository`, validation,
  contiguous reorder/remove transactions, snapshot inclusion and draft-program
  authoring UI affordances.
- Implementation instructions: enforce B02-D05 cardinality and shared round
  count; retain standalone exercise ordinals; copy groups on new version;
  freeze groups at publication/start; use stable prescription IDs in every
  command.
- Prohibited changes: no group inferred from names/order, no published-version
  mutation, no player execution work, no legacy routine graph rewrite.
- Acceptance criteria: all valid group types author/publish/start; invalid
  cardinality/ordinals reject; reorder/remove works only while draft; snapshot
  represents group/member/rest data exactly; UI exposes explicit group,
  round/member and skipped/partial state per accepted B02-PD01.
- Tests: repository transition/validation tests; snapshot tests; authoring
  controller/widget tests.
- Validation commands: `flutter test test/program_repository_test.dart test/execution_bridge_test.dart`; `flutter analyze`.
- Definition of done: a published B02 template has a deterministic group graph
  and no existing B01 template regression.

## B02-05 — Implement strength execution/finalization successor

- Goal: replace the legacy-shaped scheduled strength bridge with rich B02
  execution while retaining B01 lifecycle/idempotency guarantees.
- Dependencies: B02-03, B02-04.
- Assigned model: Terra High.
- Risk: Critical execution integrity / L.
- Exact scope: add `StrengthExecutionRepository` and a successor to
  `WorkoutExecutionCompatibilityAdapter`; create B02 draft state, performed
  group/exercise/set records, substitutions, full/partial finalization and
  legacy read adapter routing.
- Implementation instructions: retain CalendarRepository as occurrence-state
  owner; bind every draft to its frozen snapshot; make finalization one
  transaction with exact command/payload retry behavior; delete draft last;
  route B01 v1 drafts through the retained legacy bridge.
- Prohibited changes: no direct occurrence writes from widgets, no dual write to
  `WorkoutSets`, no name-based stable-ID recovery for B02 work, no early-finish
  pop without partial finalization.
- Acceptance criteria: scheduled and unscheduled B02 strength sessions record
  canonical detail; group/substitution partial state survives kill/resume;
  same command retries safely; B01 scheduled tests still pass.
- Tests: transaction rollback/idempotency; group resume; substitution; partial
  completion; legacy-v1 compatibility; history projection.
- Validation commands: `flutter test test/execution_bridge_test.dart test/occurrence_state_machine_test.dart test/workout_summary_lifecycle_test.dart`; `flutter analyze`.
- Definition of done: Sol review confirms the B01 completion state machine is
  still sole occurrence authority. **SOL-GATE REQUIRED** for finalization cutover.

## B02-06 — Implement technique recording and editor primitives

- Goal: capture all B02 advanced strength technique facts without mutually
  exclusive set-type strings.
- Dependencies: B02-03.
- Assigned model: GPT Luna.
- Risk: High data fidelity / M.
- Exact scope: implement rich set/segment companions, validators, draft DTO
  helpers, technique editor components and unit/repository tests for tempo,
  paused reps, assistance, drop and rest-pause.
- Implementation instructions: use composable fields; preserve all four tempo
  components; store assistance separately; ensure segment sum/order checks;
  keep warm-up as role and AMRAP/failure as effort, not a generic string.
- Prohibited changes: no modification of legacy set rows/allowed type list, no
  PR algorithm rewrite, no muscle-volume policy, no unsupported exercise-name
  technique inference.
- Acceptance criteria: legal combinations persist/restore; invalid incomplete
  or contradictory records reject; editor remains usable with text scaling and
  screen-reader labels.
- Tests: DTO/validator/codec tests; widget tests for disclosure and errors.
- Validation commands: `flutter test test/workout_draft_codec_test.dart test/wave1_features_test.dart`; `flutter analyze`.
- Definition of done: rich set contract has no lossy JSON or UI-only fields.

## B02-07 — Implement warm-up and rest recommendation services

- Goal: provide deterministic, explainable warm-up ramps and rest selection
  without embedding rules in widgets.
- Dependencies: B02-03.
- Assigned model: GPT Luna.
- Risk: High recommendation UX / M.
- Exact scope: implement pure warm-up and rest services, preference reads,
  equipment increment resolver, rest draft-state coordinator and `PerformedRestPeriod` persistence helpers.
- Implementation instructions: implement B02-D07/D08 constants and fallbacks;
  freeze rule/input evidence in the draft; use wall-clock timing; ensure manual
  choice wins; return unavailable rather than a guessed load/increment.
- Prohibited changes: no health/readiness score, no global player rest rewrite,
  no silent preference writes, no hardcoded display-name rest/cue checks.
- Acceptance criteria: deterministic output for all fixtures; timer survives
  lifecycle; every selected/rest actual/source fact is durable; no configured
  rest is overwritten by auto rule; no preference is persisted until an
  explicit user choice, and timer adjustments remain current-session only per
  accepted B02-PD02/B02-PD03.
- Tests: all warm-up stages/fallbacks; rest precedence; elapsed time; draft
  round trip; preference/equipment fixture tests.
- Validation commands: `flutter test test/equipment_preference_repository_test.dart test/workout_draft_codec_test.dart`; `flutter analyze`.
- Definition of done: service APIs are UI-independent and carry a rule version.

## B02-08 — Implement automatic target rule v1

- Goal: deliver bounded, explainable optional load/repetition recommendations.
- Dependencies: B02-03, B02-07.
- Assigned model: Sol High.
- Risk: Critical safety/integrity / L.
- Exact scope: implement comparator query, pure rule service, evidence DTO,
  recommendation persistence in draft/performed records, confidence/completeness
  calculation and stable-ID history query migration.
- Implementation instructions: implement only B02-D11 v1; query same stable
  ID/load basis; apply one-increment bounds; keep missing recovery unknown;
  record user override separately; surface no load for insufficient data.
- Prohibited changes: no B04 score, coaching/notification, fuzzy equivalence,
  arbitrary 2.5 kg fallback, adaptive calorie behavior or overriding actuals.
- Acceptance criteria: every decision-table fixture returns its specified target
  and evidence; new/unresolved/substituted cases behave safely; completed
  history retains offered versus actual values across restore.
- Tests: rule matrix, deload, RPE/failure, increments, confidence, explanation,
  override, target backup projection.
- Validation commands: `flutter test test/progressive_overload_test.dart test/execution_bridge_test.dart`; `flutter analyze`.
- Definition of done: Sol signs off bounds, evidence and missing-data behavior.
  **SOL-GATE REQUIRED**.

## B02-09 — Implement typed cardio, mobility and Health repositories

- Goal: make manual/imported run/cycle/walk/interval/yoga/mobility sessions
  typed activity records with provenance.
- Dependencies: B02-03.
- Assigned model: Terra High.
- Risk: High modality/provenance / L.
- Exact scope: add activity/cardio/mobility repositories and controllers, exact
  Health Connect/HealthKit type mapping, interval validation, provenance/fingerprint
  deduplication, modality-correct export and typed history queries.
- Implementation instructions: require duration; never store yoga/mobility in
  distance/strength rows; map only reviewed provider enums; preserve imported
  observed data/source; retain legacy Health API failure handling.
- Prohibited changes: no name/substrings for modality, no automatic import of
  unknown types, no cross-provider duplicate merge without provenance proof, no
  post-completion mutation workflow.
- Acceptance criteria: manual activity draft→completion works for every B02
  modality; intervals remain ordered; duplicate import is suppressed; unknown
  type is visible/not imported; export uses correct native type; yoga/mobility
  require duration only and keep style/focus/intensity optional per accepted
  B02-PD04.
- Tests: repository/controller/import adapter tests; provenance duplicate cases;
  optional/required field tests; B01 health regressions.
- Validation commands: `flutter test test/health_service_test.dart test/phase5_health_backup_notifications_test.dart`; `flutter analyze`.
- Definition of done: Android/iOS mapping limitations are documented and Sol has
  reviewed provenance behavior. **SOL-GATE REQUIRED**.

## B02-10 — Integrate B02 player and activity UX

- Goal: expose approved groups, techniques, warm-ups, rest, targets and typed
  modalities in compact, recoverable offline flows.
- Dependencies: B02-05, B02-06, B02-07, B02-08, B02-09.
- Assigned model: Terra High.
- Risk: High multi-screen state / L.
- Exact scope: evolve workout player, rest sheet, summary, substitutions,
  activity creation, draft recovery, partial-finish confirmation and common
  history cards using the bounded repositories.
- Implementation instructions: remove B02-replaced name checks only after typed
  metadata is live; carry loading/empty/error/offline states; implement explicit
  partial completion; preserve B01 legacy route during migration; test compact
  layouts/text scale.
- Prohibited changes: no whole-app design-system rewrite, no direct Drift from
  widgets, no hidden automatic target/rest override, no removal of legacy B01
  player path before B02-14.
- Acceptance criteria: each UX journey in `PLAN.md` works after app restart;
  summary shows actual versus target and modality-appropriate fields; groups
  and intervals remain understandable/accessibile; errors preserve drafts.
- Tests: provider/controller, widget and end-to-end navigation tests; regression
  suite for player/summary/calendar.
- Validation commands: `flutter test test/workout_summary_lifecycle_test.dart test/execution_bridge_test.dart test/calendar_controller_test.dart`; `flutter analyze`.
- Definition of done: accepted B02-PD01–PD04 defaults are visibly implemented.

## B02-11 — Implement muscle mappings and volume read model

- Goal: calculate reproducible weekly working/effective sets and heat-map cells
  from reviewed mappings without false precision.
- Dependencies: B02-03, B02-05, B02-06.
- Assigned model: Sol High.
- Risk: Critical analytics validity / L.
- Exact scope: seed/review canonical muscle taxonomy and mappings; implement
  mapping validator, coverage read model, working/effective set calculation,
  timezone-aware date filtering and stable-ID query paths.
- Implementation instructions: use only accepted mapping fixtures; expose
  unknown/unallocated coverage; derive, do not persist mutable aggregates;
  apply B02-D10 rules for advanced techniques and partial sets.
- Prohibited changes: no parsing `muscleGroups` for arithmetic, no invented
  contributions, no fuzzy custom mapping, no physiological claims or coaching.
- Acceptance criteria: all reviewed allocations sum correctly; custom/unknown
  records are shown as unknown; warm-ups exclude; group/technique behavior is
  deterministic; legacy rows do not masquerade as precise B02 data.
- Tests: mapping seed/constraint tests; volume truth table; timezone range;
  unknown coverage; backup projection contract.
- Validation commands: `flutter test test/phase2_trustworthy_reports_and_achievements_test.dart`; `flutter analyze`.
- Definition of done: Sol signs off source/coverage semantics. **SOL-GATE REQUIRED**.

## B02-12 — Implement B02 history, progress and heat-map UI

- Goal: render approved activity history, target evidence, group history and
  muscle metrics without recalculating domain rules in widgets.
- Dependencies: B02-09, B02-10, B02-11.
- Assigned model: GPT Luna.
- Risk: Medium display correctness / M.
- Exact scope: add read-model providers and screens/cards for modality history,
  group history, target explanations, weekly muscle sets and heat map with
  mapping coverage/unknown state.
- Implementation instructions: use repository read models; label metric and
  date range; differentiate legacy/unknown/missing from zero; meet PD05 and
  accessibility requirements.
- Prohibited changes: no direct SQL/domain arithmetic in widgets, no new
  recommendation algorithm, no hardcoded muscle allocation or color-only cue.
- Acceptance criteria: empty, partial, unknown, loading and error states are
  clear; cards match modality; heat maps use the accepted B02-PD05 neutral
  unknown state plus textual coverage; no legacy session is falsely classified.
- Tests: provider/widget/screenshot-size tests; metric formatting and unknown
  state tests.
- Validation commands: `flutter test test/phase2_trustworthy_reports_and_achievements_test.dart`; `flutter analyze`.
- Definition of done: chart/UI work consumes accepted metric contracts only.

## B02-13 — Implement Backup v7 and restore compatibility

- Goal: make every B02 user-owned record portable and restore-safe.
- Dependencies: B02-04 through B02-11.
- Assigned model: Sol High.
- Risk: Critical portability / L.
- Exact scope: update `BackupData`, JSON envelopes, prevalidation, restore
  deletion/insertion order, old-version import behavior and B02 backup fixtures.
- Implementation instructions: serialize exact table fields/IDs; validate enums,
  FK graph, technique segments, activity/detail pairing, mapping allocations and
  v2 draft envelopes before mutation; retain existing v5/v6 import paths.
- Prohibited changes: no best-effort orphan dropping, no JSON blob for relational
  graph to evade validation, no backup omission of an execution/provenance row,
  no destructive migration cleanup.
- Acceptance criteria: v7 exact round trip preserves scheduled/full/partial
  strength, groups, techniques, rest, targets, every modality, mappings and
  provenance; invalid payload leaves database/preferences unchanged; v5/v6
  imports continue to work.
- Tests: backup schema, restore transaction, v5/v6/v7 fixture, malformed graph
  and forward-version tests.
- Validation commands: `flutter test test/backup_schema_test.dart test/b01_backup_v6_test.dart test/backup_restore_transaction_test.dart`; `flutter analyze`.
- Definition of done: Sol approves restore order and data-loss proof. **SOL-GATE REQUIRED**.

## B02-14 — Retire replaced legacy paths and run compatibility sweep

- Goal: switch B02-capable routes to typed repositories while preserving B01
  legacy execution/history behavior.
- Dependencies: B02-10, B02-12, B02-13.
- Assigned model: Terra High.
- Risk: High regression / M.
- Exact scope: remove/rewrite only the superseded name-based player/cardio/rest
  behavior; route B02 sessions through typed history/progress; retain explicit
  legacy adapter/query projection; audit all former substring/set-type callsites.
- Implementation instructions: make each removal conditional on coverage; keep
  legacy v1 drafts resumable; use repository-level compatibility adapters; add
  a regression checklist covering scheduled/unscheduled and health paths.
- Prohibited changes: no dropping tables/columns, no deprecating B01 occurrence
  state machine, no silent legacy record rewrite, no broad unrelated UI cleanup.
- Acceptance criteria: no B02 behavior depends on display names when metadata
  exists; B01 regression suite passes; old backup/history/drafts still render
  their explicitly legacy state.
- Tests: targeted regression tests for all audited callsites plus full player,
  history, health and scheduled lifecycle suites.
- Validation commands: `flutter test test/execution_bridge_test.dart test/workout_draft_codec_test.dart test/wave3_features_test.dart test/health_service_test.dart`; `flutter analyze`.
- Definition of done: Terra integration review and Sol compatibility sign-off.

## B02-15 — Final verification and release gate

- Goal: prove B02 meets the charter without leaking B04 coaching or losing B01
  behavior.
- Dependencies: all B02 tasks.
- Assigned model: Sol High.
- Risk: Critical release quality / M.
- Exact scope: execute the charter exit criteria, decision gates, task DoDs,
  migration/backup tests, code-quality scan, Android/iOS health/manual matrix,
  offline/restart/compact/accessibility verification and final audit update.
- Implementation instructions: review command outputs and fixture artifacts;
  verify every B02 table is backed up; confirm recommendation evidence and
  unknown-data states; distinguish failed platform prerequisites from code
  failure.
- Prohibited changes: no release waiver for migration/backup/idempotency, no
  unexplained skipped Sol gate, no B04 readiness implementation, no data
  deletion to make tests pass.
- Acceptance criteria: every charter exit criterion has evidence; B01 suite and
  B02 matrix pass; supported release builds succeed; product decisions are
  recorded; residual limitations are explicit and accepted.
- Tests: full automated suite plus manual Android Health Connect, iOS HealthKit,
  offline kill/resume, text-scale and compact-device passes.
- Validation commands: `flutter test`; `flutter analyze`; `flutter build apk --release`; `flutter build ios --release --no-codesign`.
- Definition of done: Sol publishes final verification with command outputs and
  explicitly marks B02 ready or blocked. **SOL-GATE REQUIRED**.
