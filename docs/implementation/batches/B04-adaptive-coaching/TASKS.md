# B04 — Implementation Task DAG

Status: planning only. No task below has started. The DAG assumes the
accepted B03 branch has first been integrated into the implementation parent;
that external gate is not a task to be hidden inside B04.

## Task rules

- A task has one primary owner and a bounded review surface.
- “Parallelizable” means the stated dependencies are merged, ownership is
  isolated, no shared migration/central controller is being edited, and no
  decision gate remains open.
- Every critical task has a required Sol High review. Terra High reviews
  production state ownership, navigation, wording and accessibility.
- `B04-02` is the sole owner of the D04 policy packet. No implementation task
  may choose an unrecorded age, evidence threshold, cadence, bound, wording or
  N8 semantic.
- Product Owner qualitative decisions are authorized in the D04 packet:
  verified age `18` inclusive, below-age `coaching_unavailable_age`, opt-in,
  explicit target acceptance, no background automatic activation, typed
  missing-data behavior, dietary hard blocks, reviewed wording boundaries,
  offline/AI limits and conditional N8. Numerical values remain under
  `HOLD-1`.
- `B04-18` is a conditional product/scope gate only. It is not required for
  B04 completion and must not create an implementation branch without a new
  roadmap decision.

## B04-01 — Contract and fixture matrix

- **Objective:** Convert the roadmap outcomes, inherited B01–B03 contracts,
  safety states and historical evidence requirements into typed contract and
  fixture acceptance matrices.
- **Dependencies:** None for planning; implementation baseline must contain
  accepted B01–B03.
- **Risk / size:** High / M.
- **Primary model / required reviewer:** GPT Luna / Sol High.
- **Likely files or domains:** B04 docs, `lib/core` contract fixtures,
  existing B02/B03 model and repository tests.
- **Acceptance criteria:** Every B04 outcome has an owner and fixture set;
  unknown/range/provenance/timezone/feedback states are enumerated; no B03
  authority is duplicated; `B04-D04-01` through `B04-D04-20` each have the
  required decision fields, affected tasks and deterministic negative fixture;
  policy gates are marked blocking.
- **Required tests:** Contract serialization, state-transition and roadmap
  traceability fixtures; negative fixtures for missing evidence and dangling
  lineage.
- **Explicit exclusions:** No schema migration, UI, engine or AI code.
- **Parallelizable:** No; it establishes the shared contract baseline.

## B04-02 — Product, target and safety policy gate

- **Objective:** Finalize and verify the Product Owner-authorized qualitative
  D04 contract, record the exact `HOLD-1` numerical guards, and prepare the
  packet for independent Sol High review. This task is documentation/policy
  finalization only.
- **Dependencies:** `B04-01`.
- **Risk / size:** Critical / M.
- **Primary model / required reviewer:** Sol High / Product Owner and Sol High;
  Terra High for copy and accessibility.
- **Likely files or domains:** Decision register, target-policy fixtures,
  safety wording catalog and release checklist.
- **Acceptance criteria:** `B04-D04-01` through `B04-D04-20` record the
  authorized qualitative selections; age is verified `18 completed years`
  inclusive; below-age output is `coaching_unavailable_age`; coaching and AI
  consent are separate; target acceptance is explicit and idempotent; no
  background target activation occurs; possible/insufficient safety evidence
  returns unavailable; N8 remains conditional; and `HOLD-1` records zero
  upward, downward and aggregate kcal adjustment. Any future enabled numeric
  policy must record unit, inclusive/exclusive edge, effective period,
  missing-data behavior, policy version, override rule and boundary tests.
  Existing TDEE constants remain legacy and are not B04 policy.
- **Required tests:** Decision-record completeness, zero-delta hold,
  boundary-value policy fixtures, contradictory-goal fixtures,
  missing-body-metric fixtures, missing nutrition/recovery fixtures,
  consent/withdrawal, hard-block/possible/insufficient evidence,
  professional-wording, offline/AI redaction and N8 non-inference tests.
- **Explicit exclusions:** No target engine or UI implementation before the
  independent Sol review, dependency gate and remaining numerical approvals
  are closed.
- **Parallelizable:** No; it gates all safety-sensitive implementation.

## B04-03 — Schema v18 migration contract

- **Objective:** Add the minimal durable schema for goal versions, coaching
  preferences, recovery observations, readiness snapshots/evidence,
  recommendations/evidence and feedback.
- **Dependencies:** `B04-01`, `B04-02`, accepted B03 integration baseline.
- **Risk / size:** Critical / L.
- **Primary model / required reviewer:** Sol High / Sol High.
- **Likely files or domains:** `lib/data/database/app_database.dart`,
  `nutrition_tables.dart`, migration tests, foreign keys and indexes.
- **Acceptance criteria:** v17→v18 and fresh creation are deterministic;
  planned B04 entities own consent evidence, verified-age eligibility,
  effective-dated target lineage, recommendation evidence and feedback as
  specified in `DECISIONS.md`; IDs, ownership, effective dates, timestamps,
  supersession, indexes and foreign keys match the existing v18 plan; no new
  D04 table, cache, prompt or image table is added.
- **Required tests:** Fresh schema, direct upgrade, chained upgrade, failed
  migration rollback, foreign-key and index checks, idempotent open.
- **Explicit exclusions:** Repository behavior, backup serialization and UI.
- **Parallelizable:** No; it is the shared persistence baseline.

## B04-04 — Backup v9 graph and restore contract

- **Objective:** Extend the versioned backup graph for B04 entities with
  transactional restore, compatibility and relationship validation.
- **Dependencies:** `B04-03`.
- **Risk / size:** Critical / L.
- **Primary model / required reviewer:** GPT Luna / Sol High.
- **Likely files or domains:** `lib/core/backup/backup_schema.dart`, backup
  envelope/manifest code, restore coordinator, backup fixtures and tests.
- **Acceptance criteria:** Backup v9 round-trips the already planned durable
  B04 data, including consent/eligibility evidence, effective-dated target
  lineage and feedback; v5–v8 imports restore with an empty B04 graph;
  restore ordering and invalid graph rollback are atomic; no raw AI,
  disclosure, medical-restriction or health payloads are serialized.
- **Required tests:** Round-trip, old-version import, future-version rejection,
  malformed relationship, duplicate identity, failure injection and
  post-restore read verification.
- **Explicit exclusions:** The pre-existing unrelated backup-schema edit in
  the current worktree; B04 implementation must not absorb it silently.
- **Parallelizable:** No; it follows the approved schema and must merge before
  persistence repositories.

## B04-05 — Goal/version and coaching-preference repositories

- **Objective:** Replace mutable current-goal authority with commands and
  read models for accepted effective-dated versions, explicit overrides and
  adaptive opt-in/consent.
- **Dependencies:** `B04-03`, `B04-04`, `B04-02`.
- **Risk / size:** High / L.
- **Primary model / required reviewer:** GPT Luna / Sol High; Terra High for
  production settings integration.
- **Likely files or domains:** New goal models/repository, profile/settings
  controllers, `UserProfileNotifier`, `TdeeCalculator` adapter boundary,
  nutrition-goal screens and fixtures.
- **Acceptance criteria:** Accepted versions are append-only and historical;
  user-set target remains authoritative unless the user explicitly accepts a
  proposal; adaptive coaching defaults off; adaptive and AI consent are
  separate, versioned and effective-dated; verified age is `18` inclusive;
  below-age/unknown-age/disabled states cannot create adaptive output; duplicate
  acceptance is idempotent; legacy profile fields have one-way compatibility
  mapping and no competing write authority.
- **Required tests:** Version/effective-date history, override, reset,
  opt-in-off, timezone boundary, duplicate command and backup restore.
- **Explicit exclusions:** No adaptive formula, readiness scoring, external
  search or final dashboard redesign.
- **Parallelizable:** Yes, after `B04-04`; isolated from readiness repository
  and target engine. Merge before `B04-07`.

## B04-06 — Recovery observations and readiness

- **Objective:** Normalize provenance-bearing recovery observations and create
  completeness-aware, immutable readiness snapshots without treating missing
  inputs as zero.
- **Dependencies:** `B04-03`, `B04-04`, accepted B02 health/activity contracts.
- **Risk / size:** Critical / XL.
- **Primary model / required reviewer:** Sol High / Sol High.
- **Likely files or domains:** New recovery/readiness models and repositories,
  B02 health provenance/read models, `ReadinessService`, fixtures and backup
  tests.
- **Acceptance criteria:** Source, freshness, status/range and permissions are
  visible; incomplete/denied/conflicting inputs produce unknown or unavailable
  readiness; snapshots freeze evidence and supersession; stale/missing
  evidence suppresses readiness-driven adaptation; schedule/activity alone
  cannot infer readiness; no readiness is backfilled without evidence.
- **Required tests:** Complete/incomplete/denied/stale/conflicting health,
  timezone/date boundaries, provenance lineage, idempotent import and
  historical immutability.
- **Explicit exclusions:** Clinical scoring, sleep diagnosis, B02 record
  mutation and adaptive targets.
- **Parallelizable:** Yes, after `B04-04`; owns a distinct repository graph
  from `B04-05`. Merge before `B04-07`.

## B04-07 — Deterministic adaptive target engine

- **Objective:** Calculate bounded, explainable calorie/macro proposals and a
  separate readiness-aware training overlay using approved policy and goal
  versions.
- **Dependencies:** `B04-02`, `B04-05`, `B04-06`, accepted B02/B03 integration.
- **Risk / size:** Critical / XL.
- **Primary model / required reviewer:** Sol High / Sol High.
- **Likely files or domains:** New pure target engine, policy/rule version
  contracts, B02 load evidence adapters, B03 totals/estimate read models,
  calculation fixtures.
- **Acceptance criteria:** No silent target mutation; verified age `18` is
  inclusive; below-age/unknown-age returns the explicit unavailable state; no
  background automatic target change occurs; one observation never changes a
  target; while `HOLD-1` is active no adaptive calorie or readiness-driven
  training proposal is emitted and upward/downward/aggregate delta is exactly
  `0 kcal`; goals, trends, workload, readiness and overrides are named
  evidence; training ownership remains B02-owned.
- **Required tests:** Golden calculations, bounds, trend windows, missing and
  range propagation, opt-in/override, contradictory goals, idempotency and
  rule-version lineage.
- **Explicit exclusions:** AI-generated targets, medical prescriptions,
  unapproved aggressive deficits and B02 load-target replacement.
- **Parallelizable:** No; it depends on both new histories and the policy gate.

## B04-08 — Recommendation context and meal opportunity

- **Objective:** Assemble a typed local context and explicit meal opportunity
  for the recommendation engine without inferring food availability or time
  windows.
- **Dependencies:** `B04-05`, `B04-06`, `B04-07`, accepted B01–B03 contracts.
- **Risk / size:** High / L.
- **Primary model / required reviewer:** GPT Luna / Sol High.
- **Likely files or domains:** New context/meal-opportunity contracts,
  `NutritionReadModelRepository`, `NutritionConsumptionRepository`, B02
  calendar/activity/readiness adapters, recipe/thali reads and local time
  service.
- **Acceptance criteria:** Context carries local date/timezone, target version,
  totals/lineage, readiness completeness, workload, schedule, constraints,
  estimates, age/consent/eligibility, missing evidence and N8 absence;
  candidates are explicit local selections; no legacy FoodLogs/meal-plan path
  can become authority.
- **Required tests:** Daily/weekly context, no-candidate, unknown totals,
  local timezone/DST, explicit meal opportunity and data redaction fixtures.
- **Explicit exclusions:** External search, pantry inference, festival-mode
  inference and duplicated nutrient calculations.
- **Parallelizable:** No; the shared context contract is consumed by safety
  and engine tasks.

## B04-09 — Dietary and nutrition safety filter

- **Objective:** Adapt the B03 constraint evaluator and nutrient evidence into
  typed recommendation outcomes without duplicating conflict logic.
- **Dependencies:** `B04-08`, `B04-02`, accepted B03 constraint/estimate
  contracts.
- **Risk / size:** Critical / L.
- **Primary model / required reviewer:** Sol High / Sol High.
- **Likely files or domains:** B03 constraint repository/evaluator,
  `nutrition_constraints.dart`, estimate facts/ranges, new B04 policy mapper
  and safety fixtures.
- **Acceptance criteria:** Confirmed strict allergy, intolerance, religious and
  ethical conflicts hard-block; possible, unknown, insufficient and missing
  ingredient evidence return unavailable for adaptive/target/eat-now safety
  guidance; no-known-conflict uses the approved exact semantic and is not a
  safety guarantee; unknown and range data remain visible; user override cannot
  bypass a hard block.
- **Required tests:** Allergy, intolerance, religious, ethical, cross-contact,
  unknown ingredient, unknown nutrient, range crossing and user-override
  fixtures; no inference of restrictions.
- **Explicit exclusions:** Medical diagnosis, guarantee language, new B03
  evaluator or unrestricted safety rules.
- **Parallelizable:** No; it consumes the shared context and policy mapping.

## B04-10 — Recommendation contract, engine and prioritization

- **Objective:** Implement one deterministic recommendation engine that ranks
  bounded training and nutrition actions and emits explanation, confidence,
  alternatives, missing evidence and rule versions.
- **Dependencies:** `B04-07`, `B04-08`, `B04-09`.
- **Risk / size:** Critical / XL.
- **Primary model / required reviewer:** Sol High / Sol High.
- **Likely files or domains:** New recommendation/evidence models, pure engine,
  prioritization policy, deterministic fixtures and UI state DTOs.
- **Acceptance criteria:** Daily, weekly, training and nutrition consumers call
  the same engine; priority is deterministic; safety outcomes cannot be
  bypassed; explanation names evidence and uncertainty; age/consent/policy
  state, professional wording, target-acceptance state and unavailable reasons
  are explicit; no AI is required for an authoritative result or may change
  targets/safety.
- **Required tests:** Golden ranking, tie-breaking, priority, no-evidence,
  range, conflict, readiness-incomplete, offline and deterministic replay.
- **Explicit exclusions:** Separate nutrition/training engines, silent
  prioritization, clinical advice and raw AI output as authority.
- **Parallelizable:** No; it is the central contract and critical review gate.

## B04-11 — Historical recommendations, evidence and feedback

- **Objective:** Persist immutable recommendation lineage and append-only user
  feedback while keeping daily/weekly projections recomputable.
- **Dependencies:** `B04-03`, `B04-04`, `B04-10`.
- **Risk / size:** Critical / L.
- **Primary model / required reviewer:** GPT Luna / Sol High.
- **Likely files or domains:** Recommendation/evidence/feedback repositories,
  schema/backup adapters, graph validators and history read models.
- **Acceptance criteria:** Issued output freezes context/evidence/rule/model
  versions, age eligibility, consent evidence and target version; supersession
  is explicit; acceptance/rejection/dismissal/override/snooze feedback cannot
  rewrite history; duplicate commands are idempotent; dangling references fail
  closed; projections do not create duplicate recommendations.
- **Required tests:** Historical reads after goal changes, lineage graph,
  feedback idempotency, duplicate recommendation prevention, backup round-trip,
  rollback and deletion/retention policy fixtures.
- **Explicit exclusions:** Persistent daily/weekly caches, raw prompts,
  unbounded event payloads and product analytics unrelated to feedback.
- **Parallelizable:** No; it depends on the central engine and persistence
  graph.

## B04-12 — “What can I eat now?” guidance

- **Objective:** Produce local, safety-filtered, target-aware candidate guidance
  using the remaining-target read model and explicit meal opportunity.
- **Dependencies:** `B04-08`, `B04-09`, `B04-10`, `B04-11`.
- **Risk / size:** High / L.
- **Primary model / required reviewer:** Sol High / Sol High.
- **Likely files or domains:** Nutrition food/recipe/thali providers,
  consumption/totals read model, new current-food controller/state, candidate
  cards and fixtures.
- **Acceptance criteria:** Candidates come only from trusted local/B03 data or
  explicit user selection; remaining targets show source/range/unknown state;
  confirmed conflicts are excluded; possible/unknown/insufficient/missing
  ingredient evidence returns unavailable for safety-sensitive guidance; the
  approved no-known-conflict wording is not a safety claim; no
  meal-time/availability invention; no AI/network is necessary.
- **Required tests:** Candidate ranking, no candidate, consumed/estimated/
  missing totals, allergy and unknown ingredient, offline, acknowledgement and
  effective-date goal changes.
- **Explicit exclusions:** External food search, pantry scanning, exact claims
  for unknown nutrients and new recipe/nutrient calculation logic.
- **Parallelizable:** No; it consumes the engine, safety and history contracts.

## B04-13 — Daily briefing and weekly review orchestration

- **Objective:** Build daily and seven-civil-day weekly read models from the
  same recommendation history/engine, with truthful loading/unknown/error and
  feedback states.
- **Dependencies:** `B04-10`, `B04-11`, `B04-12`.
- **Risk / size:** High / XL.
- **Primary model / required reviewer:** Terra High / Sol High and Terra High.
- **Likely files or domains:** Today/dashboard controllers and providers,
  weekly review/progress read models, local period service and accessibility
  state components.
- **Acceptance criteria:** Daily uses local civil date; weekly period is
  explicit and timezone-aware; no duplicate recommendation logic; explanation,
  alternatives, missing evidence, age/consent state, professional wording,
  target acceptance and feedback are reachable; below-age wording is not
  punitive or judgmental; no-data, policy-hold and offline states are truthful.
- **Required tests:** DST/cross-midnight/week rollover, changed goals, missing
  logs, readiness incomplete, feedback projection, large text and semantics.
- **Explicit exclusions:** Full dashboard redesign, new analytics metrics,
  calendar ownership or legacy weekly AI report as authority.
- **Parallelizable:** No; it owns central production read-model integration.

## B04-14 — Optional AI-assistance boundary

- **Objective:** Add a bounded optional adapter for wording or candidate
  explanation only after deterministic results are available.
- **Dependencies:** `B04-10`, `B04-12`, `B04-13`; explicit AI consent policy.
- **Risk / size:** Critical / M.
- **Primary model / required reviewer:** Sol High / Sol High.
- **Likely files or domains:** AI adapter/provider boundary, privacy redaction,
  `meal_plan_service.dart` and weekly-report legacy isolation, offline/error
  states and privacy tests.
- **Acceptance criteria:** AI cannot set targets, alter deltas, override safety,
  invent foods, infer allergies, alter identity/ranking/evidence/ranges/
  completeness/availability/confidence or exactify ranges; request is redacted
  and separately consented; offline/provider failure leaves the deterministic
  result unchanged or unavailable; raw prompts, responses, disclosure text,
  health/allergy payloads and images are not persisted.
- **Required tests:** Consent off, redaction, provider failure, malformed output,
  prompt-injection-like food claims, offline and lineage metadata.
- **Explicit exclusions:** AI as nutrition authority, unrestricted external
  search, health/allergy payloads and replacement of B03 estimate privacy.
- **Parallelizable:** Yes, after `B04-13`; isolated from UI except the optional
  wording state. It may be omitted without affecting authoritative behavior.

## B04-15 — Production UI integration

- **Objective:** Integrate goal/version settings, readiness states, daily and
  weekly guidance, “what can I eat now?”, feedback and safety wording into
  production surfaces with one state owner per surface.
- **Dependencies:** `B04-05`, `B04-12`, `B04-13`; `B04-14` only if optional AI
  wording is exposed.
- **Risk / size:** High / XL.
- **Primary model / required reviewer:** Terra High / Terra High and Sol High.
- **Likely files or domains:** Goal/settings screens, Today/dashboard, food and
  report screens, providers/controllers, navigation, semantic labels and
  responsive layouts.
- **Acceptance criteria:** User can inspect evidence, uncertainty, opt-in,
  consent, target acceptance, override, confirmation, dismissal and
  unavailable states; below-18 users retain general app access and descriptive
  features without punitive wording; no duplicate TDEE/weekly/AI authority
  remains; compact layouts and assistive technology expose the same truth as
  data models.
- **Required tests:** Widget/controller tests, navigation restoration,
  accessibility semantics, compact/large text, offline and error state tests.
- **Explicit exclusions:** New domain calculations, schema edits, final
  dashboard redesign and hidden background target changes.
- **Parallelizable:** No; it modifies shared production state ownership and
  central navigation.

## B04-16 — Integration regression and legacy-authority sweep

- **Objective:** Prove B04 coexists with B01–B03 and isolate or retire legacy
  goal, meal-plan, weekly-report and food-log authorities.
- **Dependencies:** `B04-03` through `B04-15` as applicable; accepted B03
  integration; `B04-14` if included.
- **Risk / size:** Critical / L.
- **Primary model / required reviewer:** Terra High / Sol High and Terra High.
- **Likely files or domains:** Repository ownership map, providers/controllers,
  legacy `FoodRepository`, `TdeeCalculator`, AI meal-plan/weekly-report paths,
  migration/backup and integration tests.
- **Acceptance criteria:** One write/read authority per contract; no B03
  reimplementation; B02 load/readiness provenance ownership remains intact; old
  data and backups remain readable; age/consent/target-acceptance,
  missing-data, dietary, offline and AI boundaries are covered; all B04
  outcomes trace to the engine/history.
- **Required tests:** Full regression, duplicate-authority detection, migration
  and backup compatibility, offline, privacy and cross-batch end-to-end tests.
- **Explicit exclusions:** Refactoring unrelated B01–B03 foundations or
  absorbing their accepted follow-ups.
- **Parallelizable:** No; it observes all merged contracts and shared
  controllers.

## B04-17 — Final verification and release gate

- **Objective:** Execute the complete B04 verification matrix and make the
  Sol release disposition, including physical-device and accessibility checks.
- **Dependencies:** `B04-16`.
- **Risk / size:** Critical / L.
- **Primary model / required reviewer:** Sol High / Sol High; Terra High for
  production UI and accessibility evidence.
- **Likely files or domains:** `VERIFICATION.md`, CI/build configuration,
  migration/backup fixtures, Android/iOS artifacts and manual evidence.
- **Acceptance criteria:** All required gates pass or have explicitly
  accepted non-blocking follow-ups; no unresolved safety/privacy/historical
  blocker; Product Owner qualitative authorization, Terra copy review and
  independent Sol High verdict for `B04-D04-01` through `B04-D04-20` are
  recorded; `HOLD-1` numerical values remain explicit until separately
  approved; Android and iOS physical checks are recorded; implementation
  branch is eligible for integration only after the dependency gate closes.
- **Required tests:** Full matrix in `VERIFICATION.md`, manual journeys,
  release builds and rollback/idempotency evidence.
- **Explicit exclusions:** Feature changes during verification without a
  reviewed remediation task; B05 scope.
- **Parallelizable:** No; final gate follows the integrated baseline.

## B04-18 — Conditional N8 context scope gate (not required)

- **Objective:** If Product Owner later adds festival, eating-out, fasting or
  travel behavior to B04, define explicit user-entered semantics, safety,
  privacy and persistence contracts before implementation.
- **Dependencies:** `B04-01`, `B04-02`, and a new roadmap/product decision.
- **Risk / size:** Critical / M planning only.
- **Primary model / required reviewer:** Sol High / Product Owner and Sol High;
  Terra High for wording.
- **Likely files or domains:** Decision register, context contract and privacy
  review only.
- **Acceptance criteria:** Context ownership, effective dates, no-inference
  semantics, target-policy interaction and backup decision are approved; no
  N8 work is pulled into `B04-08`, `B04-12` or `B04-13`; a new task DAG is
  issued if implementation is authorized.
- **Required tests:** Decision/fixture matrix only; no B04 implementation test
  is required while the scope remains conditional.
- **Explicit exclusions:** No feature branch, schema table, UI or target
  change under the current B04 plan.
- **Parallelizable:** No; it is gated by product scope.

## Dependency graph

```text
B04-01 -> B04-02 -> B04-03 -> B04-04
                         |          |
                         +----------+-> B04-05
                         +----------+-> B04-06
B04-02 + B04-05 + B04-06 -> B04-07 -> B04-08 -> B04-09 -> B04-10
B04-03 + B04-04 + B04-10 -> B04-11 -> B04-12 -> B04-13
B04-10 + B04-12 + B04-13 -> B04-14 (optional)
B04-05 + B04-12 + B04-13 (+ optional B04-14) -> B04-15
B04-03..B04-15 -> B04-16 -> B04-17
B04-01 + B04-02 + new N8 decision -> B04-18 (conditional, outside release DAG)
```

## Parallel execution waves

The waves are deliberately conservative and never exceed three concurrent
implementation tasks.

| Wave | Tasks / branches | Shared baseline | Expected merge order | Combined review |
|---|---|---|---|---|
| 0 | `B04-01`, then `B04-02` | Planning branch and accepted B01–B03 contract evidence | Contract matrix before policy gate | Sol; Product Owner; Terra for copy |
| 1 | `B04-03` | Accepted B03 integration parent | Schema first | Sol schema gate |
| 2 | `B04-04` | Schema v18 merged | Backup graph after migration | GPT Luna implementation, Sol restore gate |
| 3 | `B04-05` and `B04-06` | Schema/backup baseline | Merge repositories independently, then shared fixtures | Sol; Terra only for settings surface |
| 4 | `B04-07` | Goal/preferences and readiness contracts | Target engine before context | Sol critical algorithm review |
| 5 | `B04-08`, then `B04-09` | Target/context contracts | Context before safety mapper | Sol safety and provenance review |
| 6 | `B04-10` | Safety and target contracts | Engine before all consumers | Sol critical engine review |
| 7 | `B04-11` | Engine and schema/backup | History before current-food and briefing consumers | Sol lineage review |
| 8 | `B04-12` | History, context and safety | Current-food read model | Sol safety review |
| 9 | `B04-13` and optional `B04-14` | Engine/history/current-food contracts | Core read models before optional AI; AI cannot block deterministic core | Sol; Terra for UI/orchestration |
| 10 | `B04-15` | Production read models and optional AI contract | UI after state ownership review | Terra + Sol |
| 11 | `B04-16` | All implementation waves merged | Regression/authority sweep | Terra + Sol |
| 12 | `B04-17` | Regression-clean integration branch | Final verification only | Sol release gate |

Branches are conceptual task branches; they are not to be created until B03
is integrated and the dependency/policy gates are closed. No B04-01 branch is
to be started from this planning-only branch.
