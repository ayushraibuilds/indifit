# B04 — Implementation Task DAG

Status: planning only. No task below has started. The DAG uses the concrete
B04 integration baseline `741aa18972ebc1b61cd65c0bf12b442b10b50890`, whose
parent contains accepted B03. Numerical-policy authoring baseline is
`61cac3dd35579fde01118626b5fa009024a04a7f`. `B04-D04-ENABLED-1` is proposed
but inactive; this branch does not authorize B04-01, application work or
runtime activation.

## Task rules

- A task has one primary owner and a bounded review surface.
- “Parallelizable” means the stated dependencies are merged, ownership is
  isolated, no shared migration/central controller is being edited, and no
  decision gate remains open.
- Every critical task has a required Sol High review. Terra High reviews
  production state ownership, navigation, wording and accessibility.
- `B04-02` is the sole owner of the D04 policy packet. No implementation task
  may choose an unrecorded age, evidence threshold, cadence, bound, wording or
  N8 semantic. `B04-D04-ENABLED-1` is the only proposed enabled calorie
  numerical contract; its activation requires fresh independent Sol High
  approval, branch merge and explicit release/feature-policy selection.
- `B04-D04-HOLD-1` remains retained for historical replay and for
  installations/users that do not select `ENABLED-1`; until activation it is
  the current/default behavior. It blocks adaptive calorie proposals,
  readiness-driven target/training-change proposals, every non-zero adaptive
  target delta, adaptive deficit/surplus behavior and calorie floor/ceiling
  behavior. Under the hold, adaptive output is `unavailable`, all adaptive
  deltas are exactly `0 kcal`, no proposal can be accepted, and user
  override/AI cannot bypass it. `B04-D04-READINESS-HOLD-1` separately fixes
  readiness numerical effects at exactly zero. Neither hold blocks contracts,
  fixtures, Schema v18 or Backup v9 foundations, goals, consent, readiness,
  safety, lineage, feedback, deterministic unavailable states,
  descriptive/history features or valid user-set targets.
- Product Owner qualitative decisions are authorized in the D04 packet:
  verified age `18` inclusive, below-age `coaching_unavailable_age`, opt-in,
  explicit target acceptance, no background automatic activation, typed
  missing-data behavior, dietary hard blocks, reviewed wording boundaries,
  offline/AI limits and conditional N8. The proposed numerical values are
  recorded only in `B04-D04-ENABLED-1`; they are not active until the fresh
  Sol/merge/release activation gate passes. `HOLD-1` remains retained for
  replay and non-selection.
- `B04-18` is a conditional product/scope gate only. It is not required for
  B04 completion and must not create an implementation branch without a new
  roadmap decision.

## `B04-D04-ENABLED-1` task acceptance overlay

The following acceptance criteria and deterministic tests apply in addition
to each task’s base criteria. They define the enabled numerical contract but
do not authorize implementation from this branch. Until the activation gate
passes, tasks must exercise `HOLD-1` and `READINESS-HOLD-1` behavior.

| Task | Acceptance criteria | Required deterministic tests |
|---|---|---|
| `B04-01` | Contract matrix includes exact `ENABLED-1` eligibility, goal rates, 21-day window, weight/nutrition/maintenance evidence, Theil–Sen trend, deadbands, 100-kcal step, cadence, expiry, aggregate, deficit/surplus, floor/ceiling, rapid-change, future-only activation and replay; task remains not started. | Every edge listed in `VERIFICATION.md`, including `HOLD-1`/`ENABLED-1` policy-version replay. |
| `B04-02` | Owns the Product Owner selection, version, activation conditions, retained `HOLD-1`, `READINESS-HOLD-1`, exact numeric semantics and fresh independent Sol review packet. | Decision-record completeness; all unit/period/inclusivity/missing-data/version/override fields; no legacy-constant inference; activation remains blocked. |
| `B04-03` | Planned Schema v18 entities carry policy/algorithm versions, effective dates, evidence links, target lineage and feedback; no new numerical-policy or N8 tables are introduced. | Fresh/v17→v18/idempotent migration ownership and required-field tests; policy/version lineage round trip. |
| `B04-04` | Planned Backup v9 graph preserves `HOLD-1` and `ENABLED-1` policy-version history, future-only effective dates and evidence lineage; no new N8/raw-payload sections. | Round trip, unsupported policy version, duplicate/cross-user graph, rollback and historical replay tests. |
| `B04-05` | Enforces verified 18+ age, explicit consent, supported rates/defaults, goal versions, user-set labeling, explicit acceptance, idempotency and 21-day reset after goal/target/policy changes. | Exact birthday, underage/unknown/withheld, consent, rate, target acceptance, duplicate command, effective-date and reset edges. |
| `B04-06` | Preserves readiness provenance and completeness; `READINESS-HOLD-1` yields exactly `0 kcal/day`, `0%` load, `0%` intensity and `0` schedule duration, including complete readiness. | Complete/missing/denied/stale/conflicting readiness and all exact-zero numerical effect cases. |
| `B04-07` | Implements the pure deterministic calorie engine only after activation; otherwise returns `HOLD-1` unavailable. Enforces all `ENABLED-1` evidence, trend, deadband, direction, delta, cadence, aggregate, deficit/surplus, floor/ceiling and rapid-change rules. | Full numerical edge suite, deterministic replay, no target mutation, explicit acceptance, user/AI bypass rejection and future-only activation. |
| `B04-08` | Context carries recorded local date/timezone, goal/target/policy versions, B03 snapshots, maintenance estimate, missing/range states and N8 absence without inference. | 21/42-day period, timezone/DST, cross-midnight, stale/conflicting evidence, redaction and no-N8-inference tests. |
| `B04-09` | B03 remains the sole dietary evaluator; hard blocks and possible/unknown/insufficient/missing/cross-contact evidence prevent safety-sensitive enabled output. | All B03 conflict/uncertainty states before and after policy selection; acknowledgement/override cannot bypass safety. |
| `B04-10` | One deterministic engine owns direction, exact `100 kcal/day` delta, availability, confidence, evidence and wording state; AI cannot alter numerical or safety output. | Golden direction/deadband/boundary/ranking/replay tests and malformed/conflicting AI output discard. |
| `B04-11` | Freezes every enabled-policy input/result and appends accept/reject/dismiss/override/snooze events; corrections and policy changes never rewrite history. | Append-only lineage, duplicate actions, correction snapshots, target versions, policy-version replay and backup tests. |
| `B04-12` | Calorie policy never becomes food-safety authority; eat-now output remains B03-filtered, unavailable when evidence is insufficient and independent of N8. | Offline/local candidate, hard-block, range/unknown, target-version and no-N8 tests. |
| `B04-13` | Daily/weekly views expose future-only policy state, exact deltas/reasons, deadbands, rapid-change/boundary states, acceptance, user-set targets and historical replay. | Local period, 21/42-day, expiry, offline, missing evidence, wording and acceptance presentation tests. |
| `B04-14` (optional) | AI is separately consented, redacted and wording-only; it cannot alter any `ENABLED-1` or readiness-hold value/state. | AI consent, redaction, provider failure, malformed output, offline and numerical non-effect tests. |
| `B04-15` | UI renders exact units/edges, user-set labels, unavailable/boundary/rapid-change states, non-medical wording and no hidden activation accessibly. | Exact edge presentation, accessibility, compact/large text, offline, consent and no-bypass tests. |
| `B04-16` | Regression proves B01–B03 ownership, HOLD-1 replay, ENABLED-1 future-only activation, readiness hold, legacy constant isolation and timezone/DST correction behavior. | Full cross-batch, migration/backup, legacy-authority, replay and policy-selection tests. |
| `B04-17` | Release evidence contains Product Owner selection, fresh Sol verdict, branch merge, explicit activation selection, Terra copy review, all numerical edges and no readiness enablement. | Complete matrix, device/accessibility, rollback/idempotency, offline, AI, historical and activation-gate evidence. |
| `B04-18` (conditional) | Remains outside mandatory B04; no festival/fasting/eating-out/travel inference, schema, backup or calorie-policy dependency is added. | N8 independence and no-inference tests only; separate DAG required for future work. |

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
  authority is duplicated; `coaching_consent_events` and
  `coaching_eligibility_evaluations` are represented as append-only durable
  authorities; `B04-D04-01` through `B04-D04-20` each have the required
  decision fields, affected tasks and deterministic negative fixture; policy
  gates are marked blocking; this task produces contracts and fixtures only.
- **Required tests:** Contract serialization, state-transition and roadmap
  traceability fixtures; negative fixtures for missing evidence, dangling
  lineage, possible/unknown/insufficient dietary evidence and exact
  `HOLD-1` unavailable/zero-delta behavior; no application implementation.
- **Explicit exclusions:** No schema migration, UI, engine or AI code.
- **Parallelizable:** No; it establishes the shared contract baseline.

## B04-02 — Product, target and safety policy gate

- **Objective:** Record the Product Owner-authorized qualitative D04 contract,
  the proposed `B04-D04-ENABLED-1` calorie policy and retained
  `B04-D04-READINESS-HOLD-1`, then prepare the complete packet for fresh
  independent Sol High review. This is documentation-only policy work and does
  not activate or implement the engine.
- **Dependencies:** `B04-01`.
- **Risk / size:** Critical / M.
- **Primary model / required reviewer:** Sol High / Product Owner and Sol High;
  Terra High for copy and accessibility.
- **Likely files or domains:** Decision register, target-policy fixtures,
  safety wording catalog and release checklist.
- **Acceptance criteria:** `B04-D04-01` through `B04-D04-20` retain the
  authorized qualitative selections; `B04-D04-ENABLED-1` records the exact
  Product Owner-selected numerical contract, and
  `B04-D04-READINESS-HOLD-1` records zero readiness numerical effect. Age is
  verified `18 completed years` inclusive; consent and AI consent are
  separate; target acceptance is explicit/idempotent; no background activation
  occurs; safety-sensitive insufficient evidence is unavailable; N8 remains
  conditional; and `HOLD-1` remains available for replay/non-selection with
  zero adaptive deltas. Every enabled number records unit, period,
  inclusive/exclusive edge, missing-data behavior, policy version, override
  rule and deterministic boundary tests. Legacy TDEE constants remain
  non-policy. The task records activation gates but does not activate them.
- **Required tests:** Decision-record completeness; `HOLD-1` unavailable result,
  exact zero upward/downward/aggregate delta, no proposal acceptance and no
  user/AI bypass; boundary-value policy fixtures only for future approval;
  contradictory-goal fixtures; missing-body-metric fixtures; missing
  nutrition/recovery fixtures; consent/withdrawal; hard-block and
  possible/unknown/insufficient/missing/invalid dietary evidence; warning
  preservation for low-risk logging only; professional-wording; offline/AI
  redaction; and N8 non-inference tests.
- **Explicit exclusions:** No target engine, UI, schema, migration or backup
  implementation; no B04-01 start; no runtime activation before the fresh
  independent Sol verdict, branch merge and explicit release selection.
- **Parallelizable:** No; it gates all safety-sensitive implementation.

## B04-03 — Schema v18 migration contract

- **Objective:** Add the minimal durable Schema v18 contracts for goal
  versions, `coaching_consent_events`, derived coaching preferences,
  `coaching_eligibility_evaluations`, recovery observations, readiness
  snapshots/evidence, recommendations/evidence and feedback.
- **Dependencies:** `B04-01`, `B04-02`, accepted B03 integration baseline.
- **Risk / size:** Critical / L.
- **Primary model / required reviewer:** Sol High / Sol High.
- **Likely files or domains:** `lib/data/database/app_database.dart`,
  `nutrition_tables.dart`, migration tests, foreign keys and indexes.
- **Acceptance criteria:** v17→v18 and fresh creation are deterministic;
  `coaching_consent_events` is append-only and owns consent history;
  `coaching_eligibility_evaluations` is append-only and owns eligible,
  underage, unknown, conflicting, withheld, invalid and policy-unavailable
  evaluations; current projections are derived; effective-dated target
  lineage, recommendation evidence and feedback have explicit ownership; the
  existing planned entities carry `ENABLED-1`/`HOLD-1`/readiness policy and
  algorithm versions, numeric evidence, effective dates and replay links; no
  new D04 numerical or N8 table is added; IDs, ownership, effective dates,
  timestamps, supersession, indexes and foreign keys match `DECISIONS.md`;
  caches, prompts and raw provider payloads are not durable schema entities.
- **Required tests:** Append-only consent-event schema; current consent
  projection derived from events; enable/disable history; consent category
  separation; withheld eligibility; unknown/conflicting eligibility;
  cross-user relationship rejection; invalid result/source combinations;
  portable IDs; required indexes and foreign keys; fresh schema; direct and
  chained migration; idempotent open; failed migration rollback; and negative
  v17-to-v18 migration cases.
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
- **Acceptance criteria:** Backup v9 round-trips the durable B04 data,
  including append-only consent events, eligibility evaluations,
  effective-dated target lineage, `HOLD-1`/`ENABLED-1` policy-version
  evidence and feedback; restore ordering is explicit; no new N8 or numerical
  policy section is added;
  v5–v8 imports restore with an empty B04 graph and do not fabricate consent
  or eligibility; invalid graph rollback is atomic; no raw AI, disclosure,
  medical-restriction or health payloads are serialized.
- **Required tests:** Consent enable/disable/withdrawal round trip; separate
  adaptive and AI consent round trip; consent event ordering; withheld
  eligibility round trip; unknown/conflicting eligibility round trip;
  local-ID remapping; duplicate ID rejection; cross-user rejection;
  unsupported policy-version rejection; older backups do not fabricate
  consent or eligibility; transactional restore and retry; future-version
  rejection; malformed relationship; failure injection; and post-restore read
  verification.
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
  proposal; adaptive coaching defaults off; consent history is append-only in
  `coaching_consent_events`; adaptive and AI consent are separate, versioned
  and effective-dated; the current consent view is derived; verified age is
  `18` inclusive; below-age/unknown/conflicting/withheld-age/disabled states
  cannot create adaptive output; duplicate acceptance and consent commands are
  idempotent;
  legacy profile fields have one-way compatibility mapping and no competing
  write authority.
- **Required tests:** Default-off coaching; explicit enable; consent
  withdrawal; consent policy/copy version history; restart and restore; age
  eligibility and withheld age; historical goal unaffected by later consent or
  age corrections; target acceptance creates an effective-dated version; and
  duplicate commands are idempotent.
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
  cannot infer readiness; no readiness is backfilled without evidence. Under
  `B04-D04-READINESS-HOLD-1`, readiness contributes exactly `0 kcal/day`,
  `0%` training-load change, `0%` intensity change and `0` schedule-duration
  change even when readiness is complete; only descriptive coaching may use
  it.
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
  eligibility decision is inferred or reconstructed from a current projection;
  immutable evaluations are read from `coaching_eligibility_evaluations`; no
  background automatic target change occurs; one observation never changes a
  target. While `HOLD-1` is active, no adaptive proposal is emitted and all
  adaptive deltas are exactly `0 kcal`. After the separate activation gate
  selects `ENABLED-1`, the engine enforces its exact 21-day/evidence/trend,
  deadband, `100 kcal/day`, cadence, aggregate, deficit/surplus,
  floor/ceiling and rapid-change contract. `READINESS-HOLD-1` keeps all
  readiness numerical effects exactly zero. User override and AI cannot bypass
  any policy; training ownership remains B02-owned.
- **Required tests:** `HOLD-1` emits no adaptive proposal and returns its
  unavailable reason; upward/downward/aggregate delta exactly `0 kcal`; no
  hidden calculation, user override or AI bypass; `ENABLED-1` exact numerical
  edge matrix; `READINESS-HOLD-1` exact-zero effects; activation gate;
  policy-version replay; append-only correction; timezone/DST; offline
  determinism; and duplicate acceptance idempotency.
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
  local timezone/DST, explicit meal opportunity and data redaction fixtures;
  no N8 inference from holiday, calendar, location, clock, food history,
  restaurant data, religion or region; and absence of N8 produces ordinary
  evidence-limited or unavailable behavior.
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
  ethical conflicts hard-block; possible, unknown, insufficient, missing
  ingredient, possible cross-contact and structurally invalid evidence return
  unavailable for eat-now, adaptive target, daily/weekly coaching, ranked meal
  candidates and any output represented as suitable under active constraints;
  no-known-conflict uses the approved exact semantic and is not a safety
  guarantee; unknown and range data remain visible; a low-risk logging warning
  preserves the evaluator result and never enters recommendation output; user
  override cannot bypass a hard block or create safety.
- **Required tests:** Allergy, intolerance, religious, ethical, cross-contact,
  possible conflict, unknown conflict, insufficient evidence, missing
  ingredient, structurally invalid evidence, unknown nutrient, range crossing,
  every safety-sensitive output, low-risk acknowledgement preservation,
  user-override and offline fixtures; no inference of restrictions.
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
  the same engine; priority is deterministic; confirmed hard blocks and
  possible/unknown/insufficient/missing/invalid dietary evidence cannot be
  bypassed; those safety-sensitive recommendation states are unavailable;
  explanation names evidence and uncertainty; age/consent/policy state,
  professional wording, target-acceptance state and unavailable reasons are
  explicit; no AI is required for an authoritative result or may change
  targets/safety.
- **Required tests:** Golden ranking, tie-breaking, priority, no-evidence,
  possible/unknown/insufficient/missing/invalid dietary evidence, low-risk
  warning preservation, range, conflict, readiness-incomplete, `HOLD-1`
  unavailable, offline and deterministic replay.
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
  versions, immutable eligibility evaluation, consent-event reference and
  target version; supersession is explicit; acceptance/rejection/dismissal/
  override/snooze feedback is append-only and cannot rewrite history; duplicate
  commands are idempotent; dangling or cross-user references fail closed;
  projections do not create duplicate recommendations.
- **Required tests:** Historical reads after goal, consent or age changes;
  append-only event/evaluation lineage graph; feedback idempotency; duplicate
  recommendation prevention; backup round-trip; rollback; rejected cross-user
  references; and deletion/retention policy fixtures.
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
  missing totals, allergy, possible/unknown/insufficient/missing/invalid
  dietary evidence, offline, low-risk logging acknowledgement preservation and
  effective-date goal changes; no safety-sensitive acknowledgement bypass.
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
  alternatives, missing evidence, durable age-evaluation and consent-derived
  state, professional wording, target acceptance and feedback are reachable;
  below-age/unknown/withheld wording is not punitive or judgmental; no-data,
  policy-hold and offline states are truthful; possible/unknown/insufficient/
  missing/invalid dietary evidence is unavailable for safety-sensitive output.
- **Required tests:** Under-18 coaching-unavailable state; unknown/withheld age
  state; consent disabled; consent withdrawn; `HOLD-1`; offline deterministic
  unavailable state; missing nutrition evidence; missing readiness evidence;
  possible/unknown/insufficient/missing/cross-contact/structurally invalid
  safety evidence unavailable; no silent target activation; accessibility and
  semantic presentation of unavailable reasons;
  DST/cross-midnight/week rollover, changed goals, missing logs, readiness
  incomplete, feedback projection and large text.
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
- **Acceptance criteria:** AI cannot set targets, alter deltas, override safety
  or `HOLD-1`, invent foods, infer allergies, alter identity/ranking/evidence/
  ranges/completeness/availability/confidence or exactify ranges; optional AI
  consent is separate, append-only and withdrawable; request is redacted and
  separately consented; offline/provider failure leaves the deterministic
  result unchanged or unavailable; raw prompts, responses, disclosure text,
  health/allergy payloads and images are not persisted.
- **Required tests:** Separate AI consent enable/disable/withdrawal; consent
  event history; `HOLD-1` bypass attempt; redaction; provider failure;
  malformed output; prompt-injection-like food claims; offline and lineage
  metadata.
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
  append-only consent-history projection, age/withheld/unknown eligibility,
  target acceptance, override, dismissal and unavailable states; warnings are
  acknowledgement-capable only for a separately defined low-risk logging
  action and never represent recommendation safety; below-18 users retain
  general app access and descriptive features without punitive wording; no
  duplicate TDEE/weekly/AI authority remains; compact layouts and assistive
  technology expose the same truth as data models.
- **Required tests:** Widget/controller tests for default-off coaching,
  consent enable/disable/withdrawal, consent copy/policy version history,
  unknown/withheld age, safety-sensitive unavailable states and no hard-block
  bypass; navigation restoration; accessibility semantics; compact/large text;
  offline and error state tests.
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
- **Acceptance criteria:** One write/read authority per contract;
  `coaching_consent_events` and `coaching_eligibility_evaluations` remain the
  durable historical authorities; no B03 reimplementation; B02 load/readiness
  provenance ownership remains intact; old data and backups remain readable;
  age/consent/target-acceptance, missing-data, dietary, offline and AI
  boundaries are covered; all B04 outcomes trace to the engine/history.
- **Required tests:** Full regression; duplicate-authority detection; consent
  and eligibility event/evaluation ownership; cross-user and unsupported
  version rejection; migration and v5–v8/v9 backup compatibility;
  possible/unknown/insufficient dietary evidence unavailable; offline, privacy
  and cross-batch end-to-end tests.
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
  blocker; Product Owner qualitative authorization, Product Owner selection of
  proposed `ENABLED-1`, Terra copy review and a fresh independent Sol High
  verdict covering the numerical contract are recorded. Branch merge and
  explicit release/feature-policy selection are recorded before any enabled
  activation; `HOLD-1` remains replayable/non-selected and
  `READINESS-HOLD-1` remains active. The incremental evidence ledger is
  updated immediately after each approved/merged task; Android and iOS
  physical checks are recorded; this planning branch does not begin B04-01 or
  implementation.
- **Required tests:** Full matrix in `VERIFICATION.md`, direct task-level D04
  acceptance tests, manual journeys, release builds and rollback/idempotency
  evidence; ledger completeness is itself a release check.
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
| 0 | `B04-01`, then `B04-02` | Concrete B04 integration baseline, accepted B01–B03 contract evidence and independent Sol approval of this remediation | Contract matrix before policy gate | Sol; Product Owner; Terra for copy |
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

Branches are conceptual task branches. B04-01 may be created only after the
independent Sol High verdict approves this remediation and the accepted parent
is used; every later branch requires its own DAG dependencies and review
evidence. No task is marked implemented by this planning document.
