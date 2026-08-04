# B04 — Decision Register

Status: Planning gate; implementation decisions are conditional on the B03
integration gate and the explicit policy gates below.
Decision IDs: `B04-D01` onward.
Canonical authority: `docs/roadmap/canonical-roadmap.md`, especially E5/M18,
N8–N10, P1/P2/P7/P8/P9, the F4 cross-feature decisions and the Phase 5 exit
criteria.

## Decision summary

| ID | Decision | Status |
|---|---|---|
| B04-D01 | B04 scope is E5/M18 adaptive coaching with one engine; N8 context modes and detailed protein physiology are not required exit outcomes | Accepted |
| B04-D02 | Goals use a hybrid user-set/calculated/adaptive model with explicit opt-in and override | Architecture accepted; policy constants gated |
| B04-D03 | Goal and target history is append-only, versioned and effective-dated | Accepted |
| B04-D04 | Safety-sensitive adaptation constants require Product Owner + Sol approval; no current hard-coded values become B04 policy | Open policy gate |
| B04-D05 | Deterministic local calculation is authoritative; AI is optional wording only | Accepted |
| B04-D06 | Readiness may influence bounded guidance only through complete, provenance-bearing inputs | Accepted |
| B04-D07 | Unknown, partial and range values propagate into guidance and confidence | Accepted |
| B04-D08 | B03 constraint outcomes map to explicit block/warn/confirm/unavailable states | Accepted subject to cross-contact fixture gate |
| B04-D09 | “What can I eat now?” uses user-selected/local canonical candidates; no external search or pantry inference | Accepted |
| B04-D10 | Festival, eating-out, fasting and travel modes are user-entered conditional N8 extensions, not required B04 behavior | Accepted boundary; later product gate |
| B04-D11 | Meal opportunity is an explicit user/context input, not an inferred meal window | Accepted |
| B04-D12 | Historical recommendations persist frozen context/evidence/lineage; daily/weekly projections are derived | Accepted |
| B04-D13 | Every recommendation has explanation, confidence, priority, alternatives and missing evidence | Accepted |
| B04-D14 | Acknowledgement, dismissal and override are append-only feedback events | Accepted |
| B04-D15 | Offline deterministic behavior is complete; AI uses a redacted, bounded provider boundary | Accepted |
| B04-D16 | Daily uses local civil date; weekly uses an explicit seven-civil-day period with IANA timezone | Accepted |
| B04-D17 | B04 requires schema v18 and Backup v9 for goal, recovery, readiness, recommendation and feedback history | Accepted |
| B04-D18 | B03/B02 authorities remain bounded; B04 adds orchestration, not replacement calculators or repositories | Accepted |

## B04-D01 — Canonical scope and one recommendation engine

- **Question:** Which deferred candidates are actually B04 outcomes?
- **Accepted answer:** Implement E5/M18: readiness with completeness; adaptive
  load/calorie targets; one evidence-backed recommendation engine; daily
  briefing; weekly consumer of the same engine; “what can I eat now?”;
  evidence, explanations, feedback and user overrides. N8 festival,
  eating-out, fasting and travel modes are contract-ready but conditional. The
  detailed leucine/protein-quality/MPS path, nested recipes and B03 follow-ups
  remain out of scope.
- **Rationale:** E5 names the required adaptive-coaching outcomes. N8 is a
  separate roadmap feature with product-owner decisions; B03 explicitly
  defers it but does not prove it belongs in B04’s required exit.
- **Alternatives rejected:** Treating every B03 deferral as mandatory B04
  scope; creating separate nutrition and training recommendation engines;
  extending B04 into B05 design/education work.
- **Consequences:** `B04-01`, `B04-10`, `B04-12`, `B04-13`, `B04-18` and the
  traceability matrix must preserve the required/conditional distinction.
- **Required tests:** Roadmap-to-outcome trace; no N8 implementation branch in
  the required DAG; one engine serves daily, weekly, training and nutrition
  outputs.
- **Tasks depending on it:** All B04 tasks.

## B04-D02 — Hybrid goals, targets and user control

- **Question:** Are nutrition targets user-set, calculated, adaptive or
  hybrid?
- **Accepted answer:** Hybrid. A user may retain a user-set target; the
  deterministic engine may propose a calculated target from typed profile
  inputs; an adaptive proposal is optional and requires explicit coaching
  opt-in plus explicit acceptance. Acceptance creates a new target version.
  A proposal never silently changes the active target. Training-load targets
  remain B02-owned; B04 can produce a recovery-aware overlay recommendation.
- **Rationale:** This preserves the existing user override contract while
  making calculation and adaptation explainable and historical.
- **Alternatives rejected:** Silent adaptive replacement; current profile row as
  history; AI-generated target values; a single service that owns every domain.
- **Consequences:** Add `NutritionGoalRepository` and a pure target engine;
  adapt profile/settings screens through commands and read models.
- **Required tests:** User-set precedence, calculated proposal, opt-in off,
  acceptance, explicit override, reset-to-calculated and training/nutrition
  ownership separation.
- **Tasks depending on it:** `B04-02`, `B04-05`, `B04-07`, `B04-13`, `B04-15`.

## B04-D03 — Goal versions and effective dates

- **Question:** How do target changes preserve historical meaning?
- **Accepted answer:** Each accepted goal/target change appends an immutable
  version with portable ID, user owner, monotonic version number, source,
  calculation/policy version, effective local date/time, IANA timezone,
  superseded version, created-at UTC and optional end date. The active version
  is derived, not a second mutable authority. A day/week resolves the version
  effective for its stored local period.
- **Rationale:** `UserProfiles` and SharedPreferences currently overwrite the
  current values and cannot reconstruct old adherence.
- **Alternatives rejected:** Reusing `updatedAt`; mutating one active row;
  using UTC alone; recalculating old recommendations from today’s target.
- **Consequences:** Goal versions and target values are included in v18/v9;
  legacy profile values are imported as an explicit initial compatibility
  version without inventing historical dates.
- **Required tests:** Same-day replacement, date boundaries, travel timezone,
  DST, old recommendation reads after a goal change, restore order and
  idempotent import.
- **Tasks depending on it:** `B04-03`, `B04-04`, `B04-05`, `B04-07`, `B04-12`,
  `B04-13`.

## B04-D04 — Safety-sensitive target policy gate

- **Question:** What minimum age, trend duration, adjustment cadence and
  calorie/deficit bounds may adaptation use?
- **Accepted answer:** The architecture is fail-closed, but the numerical
  policy is **not silently resolved here**. Product Owner and Sol High must
  explicitly approve age eligibility, evidence window, adjustment cadence,
  maximum change, minimum/maximum target behavior, goal conflict handling and
  professional-advice wording before adaptive target exposure. Until then the
  engine may show a user-set target or an unavailable policy state, never an
  adaptive value. Existing `-500/+300` and `1200` constants are not accepted
  B04 policy.
- **Rationale:** The canonical roadmap lists these as product-owner decisions;
  choosing them in an architecture document would silently choose medically
  sensitive behavior.
- **Alternatives rejected:** Copying `TdeeCalculator` constants as policy;
  selecting a medical threshold from implementation convenience; treating a
  warning as approval.
- **Consequences:** `B04-02` is a hard implementation gate for adaptive
  targets. Planning is approved; implementation is not.
- **Required tests:** Policy-unapproved returns unavailable; approved fixture
  values are bounded, versioned and auditable; age/goal conflict/missing-data
  cases fail closed.
- **Tasks depending on it:** `B04-02`, `B04-07`, `B04-10`, `B04-13`, `B04-17`.

## B04-D05 — Deterministic authority and optional AI

- **Question:** Should recommendations be deterministic or AI-assisted?
- **Accepted answer:** Deterministic calculation, filtering, ranking and
  safety are authoritative and offline-capable. AI may optionally summarize or
  vary wording over a typed, already-filtered candidate/result envelope. AI
  cannot choose targets, infer availability, evaluate allergies, change
  confidence, add foods or persist a recommendation.
- **Rationale:** The roadmap requires explainability/offline operation, and
  current AI meal/report paths are separate point-based authorities.
- **Alternatives rejected:** AI-first coaching; using backend fallback values as
  nutrition truth; placing prompts in widgets; a second AI recommendation path.
- **Consequences:** `NutritionAIAdapter` is isolated and optional; no network
  is needed for B04 core behavior.
- **Required tests:** Same deterministic context yields same output; malformed
  or unavailable AI leaves deterministic result unchanged; AI cannot mutate
  evidence/safety/target fields.
- **Tasks depending on it:** `B04-10`, `B04-14`, `B04-15`, `B04-16`.

## B04-D06 — Readiness inputs and influence

- **Question:** May health/recovery/readiness change nutrition or training
  guidance?
- **Accepted answer:** Yes, only as a provenance-bearing, confidence-scored
  input to approved bounded guidance. Readiness can alter recommendation
  priority or choose a pre-reviewed action band; it cannot invent a health
  condition, rewrite B02 history, mutate the schedule or silently change a
  calorie target. Missing/permission-error/conflicting inputs yield unknown
  readiness and suppress adaptation below the approved threshold.
- **Rationale:** E5 requires readiness completeness; the roadmap says missing
  recovery is unknown, not zero.
- **Alternatives rejected:** Treating missing health data as zero; using a
  single current summary as historical readiness; medical/injury inference.
- **Consequences:** Normalize provider/user observations, persist immutable
  snapshots and preserve source IDs; keep B02 health provenance authoritative.
- **Required tests:** Permission denied, provider unavailable, stale data,
  contradictory inputs, complete/incomplete bands, timezone and replay tests.
- **Tasks depending on it:** `B04-06`, `B04-07`, `B04-08`, `B04-10`, `B04-13`.

## B04-D07 — Unknown, partial and range propagation

- **Question:** How do missing nutrition facts and estimated ranges affect
  guidance?
- **Accepted answer:** Preserve status, lower/point/upper bounds, source,
  completeness and assumptions from B03. If every defensible bound fits the
  requested target, guidance may be cautious; if bounds cross a safety or
  decision threshold, return warning/confirmation or unavailable. Missing
  data never becomes zero or an exact-looking value.
- **Rationale:** B03-D10/D11/D17 and the roadmap uncertainty principle are
  binding.
- **Alternatives rejected:** Point-only ranking; midpoint-as-fact; suppressing
  incomplete inputs; current catalogue recalculation.
- **Consequences:** Recommendation DTOs carry uncertainty and evidence fields;
  UI must render partial/range/unavailable states accessibly.
- **Required tests:** Known zero vs missing, range aggregation, threshold
  crossing, incomplete daily totals, estimated restaurant candidate and
  offline/manual state.
- **Tasks depending on it:** `B04-01`, `B04-08`, `B04-09`, `B04-10`, `B04-12`,
  `B04-15`.

## B04-D08 — Constraint outcomes and hard-block behavior

- **Question:** How should allergy, intolerance, religious/ethical and
  unknown ingredient evidence constrain guidance?
- **Accepted answer:** Reuse B03’s exact four outcomes. A confirmed conflict
  for a strict safety-sensitive constraint hard-blocks a candidate from
  “eat now”; a possible conflict or insufficient evidence produces a visible
  warning/confirmation and cannot be called safe. A no-known-conflict result
  permits a candidate only with “no known conflict” wording. Dislikes and
  regional preferences can be soft filters. A user override records a personal
  decision but cannot downgrade evidence or create a safety claim.
- **Rationale:** B03-D14 makes the evaluator and evidence source authoritative.
- **Alternatives rejected:** Name-based allergy inference; treating no-known as
  safe; one generic diet string; hidden hard blocks without explanation.
- **Consequences:** `NutritionSafetyFilter` delegates to B03 and stores the
  evaluation/result evidence used by a recommendation. Cross-contact fixtures
  are a Sol gate before UI exposure.
- **Required tests:** All four outcomes across all constraint types, strictness,
  severity, cross-contact, unknown ingredient, user override and restore.
- **Tasks depending on it:** `B04-01`, `B04-09`, `B04-10`, `B04-12`, `B04-15`,
  `B04-16`.

## B04-D09 — Local candidate policy for “what can I eat now?”

- **Question:** Should the current-food recommendation use local logs/recipes
  only or external search?
- **Accepted answer:** Use canonical local foods, published recipes, saved
  thalis and explicitly selected user-provided candidates. “Available” means
  selected for this opportunity; it is not inferred from pantry, location or
  recent use. External search is out of scope for B04. A candidate with no
  reliable identity/nutrient/constraint evidence remains partial or unavailable.
- **Rationale:** Offline-first and B03 identity/uncertainty contracts are
  stronger than current online field coercion.
- **Alternatives rejected:** Open Food Facts/network-first search; recent food
  as pantry evidence; AI-invented ingredients; restaurant search.
- **Consequences:** `MealOpportunityService` accepts an explicit candidate set;
  no new pantry table is needed for B04.
- **Required tests:** Empty selection, duplicate candidates, local recipe/thali,
  missing nutrient, possible conflict, offline candidate ranking and no network
  assertion.
- **Tasks depending on it:** `B04-08`, `B04-09`, `B04-12`, `B04-14`.

## B04-D10 — Festival, eating-out, fasting and travel context

- **Question:** Who owns context modes and how do they affect targets?
- **Accepted answer:** B04 defines only an input seam and safe unavailable
  state. No mode is inferred from calendar, holiday, location, restaurant name
  or clock. A future N8 implementation must use explicit user-entered,
  effective-dated context, typed evidence and a separately approved target
  policy. Until that gate, mode-specific target changes, fasting windows and
  eating-out coaching are outside the B04 DAG.
- **Rationale:** N8 is a separate roadmap feature with product-owner
  decisions; B03 defers it but does not authorize automatic semantics.
- **Alternatives rejected:** Calendar-holiday inference; a free-form mode
  string; changing calories during fasting/festivals without confirmation;
  treating restaurant estimates as exact.
- **Consequences:** No `NutritionContextRepository` is persisted in v18 unless
  the product decision is reopened. `B04-18` is conditional planning only.
- **Required tests:** For the required batch, absent/unknown context returns
  ordinary or unavailable guidance without inference. Conditional tests are
  listed but not implementation-gated.
- **Tasks depending on it:** `B04-01`, `B04-08`, conditional `B04-18`.

## B04-D11 — Meal opportunity and timing semantics

- **Question:** How is “now” or the next meal opportunity determined?
- **Accepted answer:** The caller supplies the current instant, validated IANA
  timezone and optional user-selected opportunity (`now`, planned meal,
  post-workout, user-entered fasting exclusion). B04 may use local date,
  explicit meal category and logged history; it must not infer a meal group or
  meal window from an arbitrary duration. If the opportunity is absent, return
  a prompt/unavailable state rather than inventing timing.
- **Rationale:** B03-PD05 rejected hidden time-window grouping; B01 owns civil
  dates, not meal semantics.
- **Alternatives rejected:** The legacy 15-minute grouping; workout date as
  meal time; device-local `DateTime.now()` without zone.
- **Consequences:** Meal opportunity is an ephemeral input in B04; historical
  recommendation records freeze it when a recommendation is persisted.
- **Required tests:** Cross-midnight, DST, explicit meal group, no opportunity,
  user-selected opportunity and offline restart.
- **Tasks depending on it:** `B04-08`, `B04-12`, `B04-13`, `B04-15`.

## B04-D12 — Historical recommendation lineage

- **Question:** What must be persisted so an old recommendation remains
  explainable?
- **Accepted answer:** Persist each surfaced recommendation that can affect
  user action with portable ID, user owner, scope/period, created/effective
  times, local date/timezone, rule/calculation/provider version, goal-version
  reference, context fingerprint, output state, explanation, confidence,
  supersession and typed evidence rows. Evidence freezes source IDs plus the
  value/status needed for replay. Daily/weekly caches are derived and not
  persisted.
- **Rationale:** The canonical architecture names recommendation/evidence/
  feedback and requires historical explanation; recomputable totals are not
  backup entities.
- **Alternatives rejected:** Recompute from today’s facts; store only a text
  message; persist a daily cache without evidence; let AI output become history.
- **Consequences:** Recommendation history is immutable/superseding; feedback
  is separate append-only history; v18/v9 is required.
- **Required tests:** Goal change, catalogue/recipe change, source correction,
  readiness recompute, recommendation supersession, replay hash and restore.
- **Tasks depending on it:** `B04-03`, `B04-04`, `B04-10`, `B04-11`, `B04-13`,
  `B04-17`.

## B04-D13 — Explanation, confidence and prioritization

- **Question:** What must users see and how are multiple recommendations
  prioritized?
- **Accepted answer:** Every result has typed priority, action, rationale,
  evidence references, confidence, completeness, missing inputs, uncertainty,
  alternatives and an explicit state (`available`, `cautious`, `confirm`,
  `unavailable`, `dismissed`, `superseded`). Ranking is deterministic with
  stable tie-breaks. Safety blocks outrank convenience; urgent or user-selected
  actions outrank generic education; no evidence means no recommendation.
- **Rationale:** Canonical principles require evidence, alternatives and
  missing-input disclosure, while Today should remain simple.
- **Alternatives rejected:** Score-only opaque ranking; random tie breaks; UI
  ordering as authority; confidence from an AI provider alone.
- **Consequences:** Daily/weekly read models can select a small prioritized set
  without changing engine output; Terra reviews wording and accessibility.
- **Required tests:** Priority tie-break, missing-input suppression, blocked
  candidate exclusion, alternatives, deterministic ordering and semantic labels.
- **Tasks depending on it:** `B04-01`, `B04-10`, `B04-12`, `B04-13`, `B04-15`.

## B04-D14 — Feedback, acknowledgement, dismissal and override

- **Question:** What does user feedback do to recommendation history and
  future behavior?
- **Accepted answer:** Store append-only feedback events for acknowledge,
  dismiss, accept, override, snooze and “not relevant” where exposed. A
  dismissal hides the current projection but does not delete history. An
  override records the user action and may create a new goal/target version;
  it does not retrain an algorithm in B04 or imply safety.
- **Rationale:** User control and historical lineage are required; learning
  behavior from unreviewed feedback would create an unbounded policy.
- **Alternatives rejected:** Deleting dismissed recommendations; mutating one
  feedback flag; silently treating acceptance as truth; online model training.
- **Consequences:** `RecommendationFeedback` is backupable; current state is a
  derived fold over events.
- **Required tests:** Duplicate event idempotency, dismiss/restore, override
  lineage, old recommendation visibility and offline feedback.
- **Tasks depending on it:** `B04-04`, `B04-11`, `B04-12`, `B04-15`, `B04-16`.

## B04-D15 — Offline and privacy boundary

- **Question:** What data may leave the device and what happens when AI is
  unavailable?
- **Accepted answer:** Core B04 works without network. Strict offline/privacy
  policy blocks AI, photo upload, Open Food Facts and any new remote coaching
  request. Optional AI receives only a minimized/redacted candidate/result
  envelope after user consent; no raw health observations, allergies,
  unrestricted food logs, prompts, images or secrets are sent by default.
  Provider/model metadata may be retained only as needed for reproducibility;
  raw response and prompt/image data are not persisted. Provider failure leaves
  the deterministic result or an unavailable/manual state.
- **Rationale:** Existing privacy gates and B03-D19 are binding; current meal
  plan/report paths need isolation and redaction review.
- **Alternatives rejected:** Cloud-required coaching; sending the full profile
  and food history; provider fallback points; storing prompts for convenience.
- **Consequences:** `NutritionAIAdapter` has no repository write access and
  requires Sol privacy review plus backend security tests.
- **Required tests:** Strict offline no-network, consent refusal, payload
  redaction, provider failure, no prompt/image/path backup, log redaction and
  deterministic fallback.
- **Tasks depending on it:** `B04-04`, `B04-14`, `B04-16`, `B04-17`.

## B04-D16 — Daily, weekly and timezone boundaries

- **Question:** What period does a recommendation describe?
- **Accepted answer:** A daily recommendation uses one validated local civil
  date and IANA timezone stored in the context. A weekly recommendation uses an
  explicit seven-civil-day period, with start/end local dates and timezone
  frozen in the recommendation. The weekly consumer reuses the established
  report period contract and must not silently switch to a different calendar
  week. UTC timestamps remain for ordering/audit; UTC alone is insufficient.
- **Rationale:** B01/B03 use local-date/IANA semantics and existing weekly
  reporting must not be reinterpreted by B04.
- **Alternatives rejected:** Device-local dates; UTC-only aggregation; hidden
  Monday/week-start changes; current profile target for all historical days.
- **Consequences:** Indexes and fixtures cover DST, travel and cross-midnight;
  daily/weekly projections are explicit read models.
- **Required tests:** Asia/Kolkata, DST gap/overlap, travel zone, cross-midnight
  food snapshot, seven-day period, partial current day and goal change boundary.
- **Tasks depending on it:** `B04-03`, `B04-06`, `B04-08`, `B04-12`, `B04-13`.

## B04-D17 — Schema and backup versioning

- **Question:** Does B04 require durable schema and backup changes?
- **Accepted answer:** Yes. After the accepted B03 v17/v8 baseline, use schema
  v18 and Backup v9 for versioned nutrition goals/coaching preferences,
  recovery observations, readiness snapshots/evidence, recommendations,
  recommendation evidence and feedback. Do not back up daily/weekly derived
  totals, in-memory caches, prompts, images or raw provider responses. v5–v8
  imports remain valid with B04 sections absent; invalid v9 graphs restore zero
  rows.
- **Rationale:** M18 explicitly adds durable observations, snapshots,
  recommendations, evidence and feedback; historical explanation cannot be
  reproduced from a cache.
- **Alternatives rejected:** No version bump with JSON preferences; persisting
  recomputable caches; modifying B03 v17 tables without a new migration.
- **Consequences:** Schema migration precedes all B04 durable work; backup
  follows schema ownership; restore ordering and compensation are required.
- **Required tests:** Fresh v18, real v17→v18, direct accepted chain, rollback,
  v5/v6/v7/v8 import, v9 round trip, malformed graph zero mutation and
  preference compensation.
- **Tasks depending on it:** `B04-03`, `B04-04`, `B04-05`, `B04-06`, `B04-11`,
  `B04-17`.

## B04-D18 — Bounded repository ownership

- **Question:** How do B04 services avoid becoming an oversized nutrition
  coach or duplicating B01–B03 authorities?
- **Accepted answer:** Use separate owners: `NutritionGoalRepository`, pure
  `AdaptiveNutritionTargetService`, `RecoveryObservationRepository`, pure
  `ReadinessService`, `NutritionRecommendationContextAssembler`,
  `MealOpportunityService`, `NutritionSafetyFilter`, pure
  `NutritionRecommendationEngine`, `RecommendationHistoryRepository`,
  `DailyBriefingReadRepository`, `WeeklyReviewReadRepository` and optional
  `NutritionAIAdapter`. A coordinator composes them but owns no second domain
  model or calculator.
- **Rationale:** The canonical roadmap requires one repository/coordinator per
  bounded context and B03/B02 already have accepted owners.
- **Alternatives rejected:** One `NutritionCoachService`; controllers writing
  Drift; widgets doing nutrient math; global constraint/target calculators.
- **Consequences:** Task ownership and review are split; repository dependency
  graph must remain acyclic.
- **Required tests:** Provider graph, no widget Drift/AI access, one calculator,
  one constraint evaluator, one recommendation engine and legacy adapter
  isolation.
- **Tasks depending on it:** All implementation tasks.

## Open policy decisions that must remain visible

These are not implementation preferences. They require explicit product-owner
and/or Sol approval before the affected behavior can be enabled:

1. Adaptive calorie opt-in copy/default, minimum eligible age, minimum trend
   window, adjustment cadence and maximum change.
2. Exact lower/upper target safety bounds and the wording/route for aggressive
   deficits, contradictory goals and medical restrictions.
3. First-class N8 festival, eating-out, fasting and travel modes, including
   observance ownership, fasting-window semantics and restaurant uncertainty.
4. Whether any future external-food lookup may be offered after B04; B04’s
   answer is no.

Until these are approved, the implementation must return a truthful unavailable
or user-set state and must not invent a policy constant.
