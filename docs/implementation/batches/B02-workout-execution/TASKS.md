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
| B02-03 | Add pure B02 value objects, validators and codec v2 | B02-02 | GPT Luna + Sol review | High serialization | M |
| B02-13 | Implement Backup v7 and restore compatibility foundation | B02-02, B02-03 | Sol High | Critical portability | L |
| B02-04 | Implement program group authoring/repository contract | B02-03, B02-13 | Terra High | High immutable graph | M |
| B02-05 | Implement strength execution/finalization successor | B02-03, B02-04, B02-13 | Sol High | Critical execution integrity | L |
| B02-06 | Implement technique recording and rich-set editor primitives | B02-03, B02-13 | GPT Luna + Sol review | High data fidelity | M |
| B02-07A | Implement pure deterministic warm-up/rest rules | B02-01, B02-03, B02-13 | GPT Luna + Sol review | High algorithm correctness | M |
| B02-07B | Implement rest timer/draft/performed-rest coordination | B02-03, B02-07A, B02-13 | Terra High + Sol review | Critical state integrity | M |
| B02-08 | Implement explainable target rule v1 | B02-05, B02-07A, B02-13 | Sol High | Critical safety/integrity | L |
| B02-09A | Implement typed manual cardio/mobility execution | B02-03, B02-13 | Terra High + Sol review | High modality integrity | M |
| B02-09B | Implement Health mapping, provenance and deduplication | B02-09A, B02-13 | Sol High | Critical provenance | M |
| B02-10 | Integrate B02 player and activity UX flows | B02-05, B02-06, B02-07B, B02-08, B02-09A, B02-09B | Terra High | High multi-screen state | L |
| B02-11 | Implement reviewed muscle mappings and volume read model | B02-01, B02-03, B02-05, B02-06, B02-13 | Sol High | Critical analytics validity | L |
| B02-12 | Implement history/progress/heat-map UI read models | B02-09B, B02-10, B02-11 | GPT Luna | Medium display correctness | M |
| B02-14 | Complete legacy-adapter retirement and regression sweep | B02-10, B02-12, B02-13 | Terra High | High regression | M |
| B02-15 | Final verification and release gate | All B02 tasks | Sol High | Critical release quality | M |

## Exact execution order

1. Run B02-01 first. Produce the reviewed schema/FK, modality/provider,
   equipment, technique, target, and muscle-mapping fixtures; do not invent
   anatomical weights.
2. Run B02-02, then B02-03. Sol must review the migration output and v2 codec.
3. Run B02-13 before enabling any B02 durable writer. Backup v7 is a foundation,
   not end-of-batch cleanup.
4. After B02-13, B02-04, B02-06, B02-07A, and B02-09A may proceed independently.
5. Run B02-05 after B02-04; B02-07B after B02-07A; and B02-09B after B02-09A.
6. Run B02-08 after B02-05 and B02-07A. Run B02-11 after B02-05 and B02-06.
7. Run B02-10 only after every player-facing state owner is accepted, then
   B02-12, B02-14, and B02-15.

No durable task may add a field/table without updating the single Backup v7
owner and its fixtures in the same change. B02-13 owns the format and restore
ordering; later tasks extend its typed collections, not a second backup path.

## B02-01 — Freeze Sol-gate contracts and fixtures

- Goal: convert the architecture decisions into approved fixtures and exact
  invariants before production schema or algorithms are written.
- Dependencies: none.
- Assigned model: Sol High.
- Risk: Critical semantics / M.
- Exact scope: materialize the accepted B02-D01 through B02-D15 contracts as
  deterministic fixtures: legacy v15/v6 graphs, schema/FK matrix, groups,
  techniques, modalities and provider enums, equipment/bar/minimum increments,
  reviewed muscle mappings, volume truth tables, target comparators, and health
  deduplication, plus accepted B02-PD01 through B02-PD08 fixtures and user
  behavior cases.
- Implementation instructions: enumerate exact IDs and expected outcomes; use
  stable IDs, never display-name matching; make all unknown/ambiguous examples
  explicit; include valid and invalid graph/backup fixtures.
- Prohibited changes: no production schema, data migration, UI, generated
  catalogue “cleanup,” inferred muscle contributions, or B04 recovery score.
- Acceptance criteria: every B02 gate has an accepted fixture outcome; the
  checked-in muscle manifest records source/reviewer/version and leaves
  uncertain mappings unknown; provider mappings use exact platform enums; a
  reviewer can determine expected behavior without source-code guesses.
- Tests: fixture parser/determinism tests only.
- Validation commands: `flutter test test/b02_contract_fixture_test.dart test/b02_mapping_manifest_test.dart test/exercise_identity_fixture_test.dart test/equipment_fixture_test.dart`; `flutter analyze`.
- Definition of done: Sol signs off the schema/backup, identity, draft,
  technique, modality, mapping and target contracts. **SOL-GATE REQUIRED**.

## B02-02 — Add schema v16 and migration harness

- Goal: establish the B02 durable tables and a proven v15→v16 migration without
  losing or inventing historical facts.
- Dependencies: B02-01.
- Assigned model: Sol High.
- Risk: Critical data loss / L.
- Exact scope: implement the v16 extensions/new tables, constraints and indexes
  specified by B02-D01/D02/D06/D09/D10/D15, including strength detail,
  modality prescriptions, interval prescriptions, versioned mappings,
  isometric/unilateral facts and provider-scoped dedup metadata; build an
  on-disk v15 fixture harness; retain every B01/legacy field.
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
- Validation commands: `dart format --set-exit-if-changed lib/data/database test`; `flutter test test/db_migration_test.dart test/b01_schema_v15_migration_test.dart test/b02_schema_v16_migration_test.dart`; `flutter analyze`.
- Definition of done: fixture output and schema diff are reviewed by Sol.
  **SOL-GATE REQUIRED**.

## B02-03 — Add pure value objects, validators, and draft codec v2

- Goal: freeze the pure typed/serialization boundary without changing a write
  repository or UI.
- Dependencies: B02-02.
- Assigned model: GPT Luna; Sol review required.
- Risk: High serialization / M.
- Exact scope: create typed value objects/enums and pure validators for activity
  type/detail, groups/slot state, rich sets/segments, tempo components,
  load/repetition basis, targets, rest, modality prescriptions/intervals,
  mobility, mapping versions and health dedup state; implement v2 execution
  codec. Compatibility history queries remain in B02-14.
- Implementation instructions: preserve v0/v1 `WorkoutDraftCodec` decode
  behavior; include snapshot and rule-version fields; reject unknown future v2
  envelopes; validate against IDs/snapshot, not names; make legacy projection
  explicitly flag unknown/legacy coverage.
- Prohibited changes: no repository writes/history union, finalization, UI,
  health API, schema alteration, target calculation, or legacy set-type change.
- Acceptance criteria: every new DTO round-trips draft JSON; invalid enum,
  tempo, segment, group and modality payloads fail loudly; existing v0/v1 tests
  pass unchanged; B02 queries can distinguish legacy from canonical records.
- Tests: codec, enum, validator, projection and malformed-payload tests.
- Validation commands: `dart format --set-exit-if-changed lib/core lib/data test`; `flutter test test/workout_draft_codec_test.dart test/b02_domain_contract_test.dart test/workout_summary_lifecycle_test.dart`; `flutter analyze`.
- Definition of done: typed contract is consumed by no UI-specific JSON parser;
  Sol approves future-version rejection and v0/v1 compatibility.

## B02-04 — Implement group authoring and repository contract

- Goal: let draft program versions create valid explicit supersets, circuits and
  giant sets without changing published/started structure.
- Dependencies: B02-03, B02-13.
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
  represents group/member/rest data exactly.
- Tests: repository transition/validation tests; snapshot tests; authoring
  controller/widget tests.
- Validation commands: `flutter test test/program_repository_test.dart test/execution_bridge_test.dart`; `flutter analyze`.
- Definition of done: a published B02 template has a deterministic group graph
  and no existing B01 template regression.

## B02-05 — Implement strength execution/finalization successor

- Goal: replace the legacy-shaped scheduled strength bridge with rich B02
  execution while retaining B01 lifecycle/idempotency guarantees.
- Dependencies: B02-03, B02-04, B02-13.
- Assigned model: Sol High.
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
- Definition of done: Sol implements or directly reviews the transaction and
  confirms the B01 completion state machine is still sole occurrence authority.
  **SOL-GATE REQUIRED** for finalization cutover.

## B02-06 — Implement technique recording and editor primitives

- Goal: capture all B02 advanced strength technique facts without mutually
  exclusive set-type strings.
- Dependencies: B02-03, B02-13.
- Assigned model: GPT Luna; Sol review required.
- Risk: High data fidelity / M.
- Exact scope: implement rich set/segment companions, validators, draft DTO
  helpers, technique editor components and unit/repository tests for tempo,
  paused reps, assistance, drop and rest-pause.
- Implementation instructions: use composable fields; preserve all four tempo
  components; store assistance separately; ensure segment sum/order checks;
  keep warm-up as role and AMRAP/failure as effort, not a generic string. The
  editor must expose accepted composable combinations from B02-PD02 and reject
  the D06 contradiction matrix.
- Prohibited changes: no modification of legacy set rows/allowed type list, no
  PR algorithm rewrite, no muscle-volume policy, no unsupported exercise-name
  technique inference.
- Acceptance criteria: legal combinations persist/restore; invalid incomplete
  or contradictory records reject; accepted combined-technique examples round
  trip; editor remains usable with text scaling and screen-reader labels.
- Tests: DTO/validator/codec tests; widget tests for disclosure and errors.
- Validation commands: `flutter test test/workout_draft_codec_test.dart test/wave1_features_test.dart`; `flutter analyze`.
- Definition of done: rich set contract has no lossy JSON or UI-only fields.

## B02-07A — Implement pure warm-up and rest recommendation rules

- Goal: provide deterministic warm-up ramps and rest selection as pure rules.
- Dependencies: B02-01, B02-03, B02-13.
- Assigned model: GPT Luna; Sol review required.
- Risk: High algorithm correctness / M.
- Exact scope: implement pure warm-up/rest services and equipment increment,
  bar/minimum-load, load-basis, precedence and fallback resolvers. Return typed
  evidence only; do not read preferences or persist timer state. The warm-up
  service must return the accepted `ask` default as a preference input for the
  caller and never auto-add a ramp.
- Implementation instructions: implement B02-D07/D08 constants and fallbacks;
  return rule/input evidence for the caller to freeze in the draft; leave
  wall-clock timing to B02-07B; ensure manual choice wins; return unavailable
  rather than a guessed load/increment.
- Prohibited changes: no database/provider access, timer coordination,
  health/readiness score, player rewrite, preference write, or name-based rule.
- Acceptance criteria: deterministic output for every D07/D08 fixture; physical
  load constraints are respected; automatic rest never supersedes an explicit
  value; every result includes source/rule version/unavailable reason; a new
  user receives the accepted non-blocking `ask` behavior.
- Tests: warm-up stages/bar/minimum/basis/fallbacks and full rest precedence
  truth table.
- Validation commands: `flutter test test/b02_warmup_rest_rule_test.dart test/equipment_preference_repository_test.dart`; `flutter analyze`.
- Definition of done: service APIs are pure/UI-independent and Sol accepts the
  constants and boundary results.

## B02-07B — Implement rest timer, draft, and performed-rest coordination

- Goal: persist selected and actual rest without creating a screen-local owner.
- Dependencies: B02-03, B02-07A, B02-13.
- Assigned model: Terra High; Sol review required.
- Risk: Critical state integrity / M.
- Exact scope: preference reads, workout-scoped overrides, wall-clock rest
  coordinator, v2 draft state, and `PerformedRestPeriods` write/finalization.
  Record actual rest only after the user enters a timer/rest state, per
  B02-PD03; skip and extension remain explicit outcomes.
- Implementation instructions: apply the pure selection result; store source,
  selected/recommended duration, start/end UTC, actual elapsed and end reason;
  make background/resume deterministic; update Backup v7 in the same change.
- Prohibited changes: no recommendation constants in widgets, no silent saved
  preference mutation, no timer-dependent set logging, no post-commit cleanup.
- Acceptance criteria: timer survives kill/resume; current and workout overrides
  have the accepted lifetime; skip/extend/notification failure are durable and
  non-blocking; configured rest is never overwritten; idle time without an
  entered timer does not create an actual-rest record.
- Tests: draft/backup round trip, wall-clock/background, clock anomaly,
  skip/extend, every group/rest-pause context and rollback.
- Validation commands: `flutter test test/workout_draft_codec_test.dart test/execution_bridge_test.dart`; `flutter analyze`.
- Definition of done: Sol approves state ownership and performed-rest evidence.

## B02-08 — Implement automatic target rule v1

- Goal: deliver bounded, explainable optional load/repetition recommendations.
- Dependencies: B02-05, B02-07A, B02-13.
- Assigned model: Sol High.
- Risk: Critical safety/integrity / L.
- Exact scope: implement comparator query, pure rule service, evidence DTO,
  recommendation persistence in draft/performed records, confidence/completeness
  calculation and stable-ID history query migration.
- Implementation instructions: implement only B02-D11 MVP; query exact stable
  ID and load/repetition basis; apply one-increment bounds and stable fallback;
  suppress assisted/bodyweight/ambiguous changes; keep missing recovery unknown;
  record offered, prescription-change and user override separately.
- Prohibited changes: no B04 score, coaching/notification, fuzzy equivalence,
  arbitrary 2.5 kg fallback, adaptive calorie behavior or overriding actuals.
- Acceptance criteria: every decision-table fixture returns its specified target
  and evidence; new/unresolved/substituted cases behave safely; completed
  history retains offered versus actual values across restore; target
  application defaults to accepted `ask`/opt-in and never silently pre-fills;
  assisted work is never treated as a standard load/1RM PR candidate.
- Tests: rule matrix, deload, RPE/failure, increments, confidence, explanation,
  override, target backup projection.
- Validation commands: `flutter test test/progressive_overload_test.dart test/execution_bridge_test.dart`; `flutter analyze`.
- Definition of done: Sol signs off bounds, evidence and missing-data behavior.
  **SOL-GATE REQUIRED**.

## B02-09A — Implement typed manual cardio and mobility execution

- Goal: make manually scheduled/unscheduled run, cycle, walk, interval, yoga,
  and mobility sessions canonical typed records.
- Dependencies: B02-03, B02-13.
- Assigned model: Terra High; Sol review required.
- Risk: High modality integrity / M.
- Exact scope: add bounded activity/cardio/mobility repositories, typed
  prescription reads, time-based interval/repeat expansion and finalization
  inputs. Yoga/mobility are session-level only per B02-PD05. Health provider
  translation and deduplication remain in B02-09B.
- Implementation instructions: require duration; preserve missing nullable
  observations and units; never store yoga/mobility in distance/strength rows;
  record interval partial/skipped state and exact draft cursor; update Backup v7.
- Prohibited changes: no name-based modality, Health API calls, direct widget
  writes, post-completion edits, distance-segment authoring, or movement-list
  tables/UI.
- Acceptance criteria: manual activity draft→completion works for every B02
  modality; scheduled prescriptions freeze; intervals/repeats/partial state
  remain ordered; interval authoring is time-based; yoga/mobility use only the
  accepted session-level fields; they never require distance; unknown is not
  zero.
- Tests: repository/controller, unit/required field, repeat/partial cursor,
  finalization rollback and backup tests.
- Validation commands: `flutter test test/execution_bridge_test.dart test/workout_draft_codec_test.dart`; `flutter analyze`.
- Definition of done: Sol reviews modality/detail/finalization integrity.

## B02-09B — Implement Health mapping, provenance, and deduplication

- Goal: import/export typed activities without duplicate or provenance loss.
- Dependencies: B02-09A, B02-13.
- Assigned model: Sol High.
- Risk: Critical provenance / M.
- Exact scope: exact Health Connect/HealthKit type adapters, provider-scoped
  record IDs, versioned fallback fingerprints, payload/update/deletion metadata,
  partial-permission behavior, manual-collision staging, and modality-correct
  export.
- Implementation instructions: follow B02-D15; reimport returns an existing
  result; preserve completed imported facts; skip unknown types; update Backup
  v7 and document platform enum limitations in the same task.
- Prohibited changes: no approximate-timestamp-only key, no silent manual merge,
  no changed-provider-payload rewrite, no provider deletion cascade, no source
  name substring as sole provenance proof.
- Acceptance criteria: stable provider ID and fallback cases are deterministic
  across restart; cross-provider IDs do not collide; updates/deletes preserve
  immutable history; ambiguous manual overlap creates no silent duplicate;
  export selects the matching native modality.
- Tests: D15 matrix, adapter mapping, permission/provider failures, restore
  uniqueness and all B01 health regressions.
- Validation commands: `flutter test test/health_service_test.dart test/phase5_health_backup_notifications_test.dart test/backup_restore_transaction_test.dart`; `flutter analyze`.
- Definition of done: Sol approves provider identity, no-duplicate proof and
  Android/iOS mapping limits. **SOL-GATE REQUIRED**.

## B02-10 — Integrate B02 player and activity UX

- Goal: expose approved groups, techniques, warm-ups, rest, targets and typed
  modalities in compact, recoverable offline flows.
- Dependencies: B02-05, B02-06, B02-07B, B02-08, B02-09A, B02-09B.
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
  and intervals remain understandable/accessibile; accepted PD01/PD02/PD03/
  PD04/PD05/PD06/PD08 behavior is visible; errors preserve drafts.
- Tests: provider/controller, widget and end-to-end navigation tests; regression
  suite for player/summary/calendar.
- Validation commands: `flutter test test/workout_summary_lifecycle_test.dart test/execution_bridge_test.dart test/calendar_controller_test.dart`; `flutter analyze`.
- Definition of done: all B02-PD01 through B02-PD08 outcomes are recorded and
  visibly implemented; no provisional product behavior remains.

## B02-11 — Implement muscle mappings and volume read model

- Goal: calculate reproducible working-set, weighted allocation, completion and
  heat-map read models from reviewed mappings without false precision.
- Dependencies: B02-01, B02-03, B02-05, B02-06, B02-13.
- Assigned model: Sol High.
- Risk: Critical analytics validity / L.
- Exact scope: import the Sol-approved append-only mapping manifest; implement
  mapping-version validator, coverage read model, raw working slots, weighted
  muscle allocation, prescription completion ratio, load×repetitions where
  defined, timezone-aware filtering and stable-ID query paths. Do not implement
  a physiological effective-set estimate.
- Implementation instructions: use only accepted mapping fixtures; expose
  unknown/unallocated coverage; derive, do not persist mutable aggregates;
  apply B02-D14 to techniques, failures, partial, assisted, unilateral and
  isometric work; include rule and mapping versions in every read model. Enforce
  the accepted B02-PD07 rule that user-created mappings are not analytic input.
- Prohibited changes: no parsing `muscleGroups` for arithmetic, no invented
  contributions, no fuzzy custom mapping, no physiological claims or coaching.
- Acceptance criteria: reviewed allocations reproduce for a selected mapping/
  rule version; custom/unknown records are unknown; user-created mappings are
  excluded; zero differs from
  unavailable; warm-ups exclude; completion ratio is never labelled effective
  stimulus; legacy rows do not masquerade as precise B02 data.
- Tests: mapping seed/constraint tests; volume truth table; timezone range;
  unknown coverage; backup projection contract.
- Validation commands: `flutter test test/phase2_trustworthy_reports_and_achievements_test.dart`; `flutter analyze`.
- Definition of done: Sol signs off source/coverage semantics. **SOL-GATE REQUIRED**.

## B02-12 — Implement B02 history, progress and heat-map UI

- Goal: render approved activity history, target evidence, group history and
  muscle metrics without recalculating domain rules in widgets.
- Dependencies: B02-09B, B02-10, B02-11.
- Assigned model: GPT Luna.
- Risk: Medium display correctness / M.
- Exact scope: add read-model providers and screens/cards for modality history,
  group history, target explanations, weekly muscle sets and heat map with
  mapping coverage/unknown state.
- Implementation instructions: use repository read models; label metric and
  date range; differentiate legacy/unknown/missing from zero; show the
  accepted assisted-PR classification and session-level yoga/mobility fields;
  meet accessibility requirements.
- Prohibited changes: no direct SQL/domain arithmetic in widgets, no new
  recommendation algorithm, no hardcoded muscle allocation or color-only cue.
- Acceptance criteria: empty, partial, unknown, loading and error states are
  clear; cards match modality; heat maps are accessible; no legacy session is
  falsely classified.
- Tests: provider/widget/screenshot-size tests; metric formatting and unknown
  state tests.
- Validation commands: `flutter test test/phase2_trustworthy_reports_and_achievements_test.dart`; `flutter analyze`.
- Definition of done: chart/UI work consumes accepted metric contracts and
  product decisions only; no product-default placeholder remains.

## B02-13 — Implement Backup v7 and restore compatibility foundation

- Goal: establish the sole Backup v7 owner before any B02 feature writer is
  enabled.
- Dependencies: B02-02, B02-03.
- Assigned model: Sol High.
- Risk: Critical portability / L.
- Exact scope: update `BackupData`, JSON envelopes, prevalidation, restore
  deletion/insertion order, old-version import behavior and direct database
  fixtures for every v16 entity/extension in B02-D13.
- Implementation instructions: serialize exact table fields/IDs; validate enums,
  FK graph, technique segments, activity/detail pairing, mapping allocations and
  v2 draft envelopes before mutation; retain existing v5/v6 import paths.
- Prohibited changes: no best-effort orphan dropping, no JSON blob for relational
  graph to evade validation, no backup omission of an execution/provenance row,
  no destructive migration cleanup.
- Acceptance criteria: direct v16 fixture rows prove v7 exact round trip for
  scheduled/full/partial strength, prescriptions/groups, techniques, rest,
  targets, every modality, mapping versions, v2 drafts and health provenance;
  accepted ask/opt-in warm-up and target preferences round trip; no user-created
  muscle mappings or movement-list rows are exported; time-based interval
  records retain future-compatible nullable distance fields; invalid payload
  leaves database/preferences unchanged; v5/v6 imports work.
- Tests: backup schema, restore transaction, v5/v6/v7 fixture, malformed graph
  and forward-version tests.
- Validation commands: `flutter test test/backup_schema_test.dart test/b01_backup_v6_test.dart test/b02_backup_v7_test.dart test/backup_restore_transaction_test.dart`; `flutter analyze`.
- Definition of done: Sol approves restore order and data-loss proof before any
  B02 repository writer is enabled. Later writer tasks must extend these same
  typed DTOs/tests in their own changes. **SOL-GATE REQUIRED**.

## B02-14 — Retire replaced legacy paths and run compatibility sweep

- Goal: switch B02-capable routes to typed repositories while preserving B01
  legacy execution/history behavior.
- Dependencies: B02-10, B02-12, B02-13.
- Assigned model: Terra High.
- Risk: High regression / M.
- Exact scope: implement the canonical legacy+B02 history projection, then
  remove/rewrite only superseded name-based player/cardio/rest behavior; retain
  the explicit legacy adapter and audit former substring/set-type callsites.
  Verify accepted assisted-PR classification and all eight accepted product
  defaults are reflected in the compatibility sweep.
- Implementation instructions: make each removal conditional on coverage; keep
  legacy v1 drafts resumable; use repository-level compatibility adapters; add
  a regression checklist covering scheduled/unscheduled and health paths.
- Prohibited changes: no dropping tables/columns, no deprecating B01 occurrence
  state machine, no silent legacy record rewrite, no broad unrelated UI cleanup.
- Acceptance criteria: no B02 behavior depends on display names when metadata
  exists; B01 regression suite passes; old backup/history/drafts still render
  their explicitly legacy state; no product-decision placeholder or conflicting
  default remains.
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
