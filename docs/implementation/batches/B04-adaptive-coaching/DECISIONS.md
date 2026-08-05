# B04 — Decision Register

Status: Documentation gate; foundational implementation decisions are
conditional on independent Sol High approval of this remediation and the
accepted B03 parent. This register records the Product Owner qualitative
approval evidence and keeps enabled numerical adaptation under `HOLD-1`.
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
| B04-D04 | Qualitative safety/product policy is Product Owner-authorized; numerical adaptation values remain under `HOLD-1` until independent Sol review and separate approval | Qualitative policy authorized; remediation review required; enabled adaptation remains held |
| B04-D05 | Deterministic local calculation is authoritative; AI is optional wording only | Accepted |
| B04-D06 | Readiness may influence bounded guidance only through complete, provenance-bearing inputs | Accepted |
| B04-D07 | Unknown, partial and range values propagate into guidance and confidence | Accepted |
| B04-D08 | B03 constraint outcomes map to explicit hard-block/unavailable/low-risk-logging states | Accepted subject to cross-contact fixture gate |
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
- **Gate disposition:** The Product Owner has approved the qualitative policy
  records below. `HOLD-1` remains active only for the numerical values that are
  explicitly listed as unapproved. User-set targets, descriptive history and
  non-adaptive logging remain available where their inherited contracts allow.
- **Accepted technical contract:** `HOLD-1` blocks enabled adaptive calorie
  proposals, readiness-driven target or training-change proposals, every
  non-zero adaptive target delta, adaptive deficit/surplus behavior and calorie
  floor/ceiling behavior. It does not block foundational contracts and
  fixtures, schema v18 or Backup v9 foundations, goals, consent, readiness,
  safety, lineage or feedback persistence, deterministic unavailable-state
  behavior, descriptive/history features or valid user-set targets. While the
  hold is active, the adaptive result is `unavailable`; upward, downward and
  aggregate deltas are exactly `0 kcal` per event/local-civil-day guard; no
  adaptive proposal may be accepted because no enabled proposal exists; and
  user override or AI cannot bypass the hold. The guard applies from policy
  version `B04-D04-HOLD-1` until an explicitly approved superseding version.
  No lower/upper target clamp is introduced, and legacy `-500`, `+300` and
  `1200` constants remain non-policy compatibility behavior.
- **Product Owner decision status:** Qualitative policy is authorized by the
  Product Owner. Numerical trend, completeness, cadence/cooldown and target
  bound values remain under `HOLD-1`; no future numerical value is inferred.
  Exact production copy remains subject to Terra review for clarity,
  accessibility and layout.
- **Sol High assessment:** Independent Sol High review is required before
  B04-01 begins. After that approval, foundational tasks may proceed according
  to the accepted DAG; enabled adaptation remains blocked until a superseding
  numerical policy is approved.
- **Rationale:** The canonical roadmap lists these as product-owner decisions;
  choosing them in an architecture document would silently choose medically
  sensitive behavior.
- **Alternatives rejected:** Copying `TdeeCalculator` constants as policy;
  selecting a medical threshold from implementation convenience; treating a
  warning as approval.
- **Consequences:** `B04-02` is the policy gate for adaptive targets and every
  consumer listed in the records below. B04-01 may begin after independent Sol
  approval of this remediation. Later foundational work follows the accepted
  DAG; enabled adaptive behavior remains unavailable under `HOLD-1`.
- **Required tests:** The `HOLD-1` zero-delta guard, policy-unapproved
  unavailable state, explicit Product Owner selection completeness, approved
  fixture bounds with unit/period/inclusivity/missing-data/version/override
  metadata, age/goal-conflict/missing-data fail-closed cases, wording, safety,
  offline and AI-boundary fixtures.
- **Tasks depending on it:** `B04-02`, `B04-07`, `B04-10`, `B04-13`, `B04-17`.

### B04-D04 decision-record convention

Each record below uses the required Product Owner decision fields. Qualitative
choices are approved; `HOLD-1` is retained only where this packet explicitly
withholds a numerical value. Any future enabled numerical option must be
recorded with a stable policy version, effective local date, unit,
inclusive/exclusive boundary, effective period, missing-data rule, versioning
rule, override rule and deterministic tests before implementation.
No age may be inferred from account activity, food logging, photographs or
appearance. No product copy below is a diagnosis, prescription, guarantee or
substitute for professional care.

### B04-D04 approval and implementation baseline evidence

- **Approval source:** Product Owner.
- **Approval date:** `2026-08-05`.
- **Approved D04 commit:** `750ef0999153a7cc41a2493cb6305d2a833b1f12`.
- **Approval scope:** Qualitative B04-D04 policy decisions, including the
  verified `18 completed years` eligibility rule for adaptive calorie and
  readiness-driven proposals.
- **Scope still held:** Numerical adaptation cadence, evidence thresholds,
  calorie adjustment bounds, deficit/surplus limits, and calorie floors or
  ceilings remain under `B04-D04-HOLD-1` and are not approved for enabled
  adaptation.
- **Required independent review:** Sol High must independently review this
  remediation before `B04-01` may begin.

> “I approve the qualitative B04-D04 policy decisions recorded at the approved
> D04 commit, including the 18+ eligibility rule for adaptive calorie and
> readiness-driven proposals.
>
> Numerical adaptation cadence, evidence thresholds, calorie adjustment bounds,
> deficit/surplus limits, and calorie floors or ceilings remain under
> B04-D04-HOLD-1 and are not approved for enabled adaptation.”

The verified implementation lineage is: planning commit
`9102092fd1b18e38beff500e2654ece6a191f66`; accepted B03 commit
`d85e8a16566735e7f6b7fe15cd2a97edb5677178`; B03 timezone correction
`78a43f909bae58dc5e509da97af426ad960c9190`; B03 merge commit
`f976542e395a3e082f1ab5cdfdfd87e969910766`; B04 planning/integration merge
commit `741aa18972ebc1b61cd65c0bf12b442b10b50890`; current D04 documentation
commit `750ef0999153a7cc41a2493cb6305d2a833b1f12`. The integration baseline is
the concrete commit `741aa18972ebc1b61cd65c0bf12b442b10b50890`, whose parent
contains accepted B03.

### B04-D04 durable historical authorities

`coaching_consent_events` is the provisional durable, append-only authority for
coaching consent history. It has a portable event ID, user ID, consent category
(`adaptive_coaching` or `optional_ai`), action (`enable`, `disable` or
`withdraw`), consent-policy version, copy version, UTC timestamp, local date,
IANA timezone, actor/source, optional related or superseded event ID and
created-at metadata. A mutable preference/projection may expose current state,
but it is not historical authority. Prior logging, inactivity and existing
targets never create consent. Disablement affects future proposals immediately
without deleting recommendations, targets or feedback; duplicate commands are
idempotent. Backup v9 includes approved events; older backups do not fabricate
consent. Restore rejects duplicate IDs, invalid event order, invalid user
ownership and unsupported versions.

`coaching_eligibility_evaluations` is the provisional durable, append-only
authority for every age-eligibility evaluation, including withheld and
unavailable states. It has a portable evaluation ID, user ID, result
(`eligible`, `underage`, `unknown_age`, `conflicting_age`, `withheld_age`,
`invalid_evidence` or `policy_unavailable`), reason code, age-input source,
evidence timestamp, evaluation UTC timestamp, evaluation local date, IANA
timezone, policy version, minimum-age rule version, optional goal,
recommendation or attempted-proposal reference and an approved evidence
fingerprint where applicable. Age is never inferred; withheld, unknown and
conflicting age remain explicit. A date-of-birth correction affects future
evaluations only; historical evaluations are immutable. Backup v9 includes
approved evaluations; restore rejects duplicate IDs, cross-user references,
invalid result/source combinations and unsupported policy versions. A current
eligibility projection may be derived, but it is not historical authority.

The two authorities are owned and tested by `B04-03` and `B04-04`, consumed by
`B04-05`, `B04-07`, `B04-13` and `B04-15`, and verified by `B04-16` and
`B04-17`. They are user-owned durable data, not caches, prompts or raw provider
payloads. Consent and eligibility events, goal/target versions and issued
recommendation lineage are append-only; accepted goals/targets receive new
effective-dated versions. All corrections and policy changes affect future
decisions only and never rewrite historical recommendations.

### B04-D04-01 — Minimum supported age

- **Policy question:** What minimum supported age permits adaptive
  calorie-target proposals and readiness-driven training adjustment proposals?
- **Options:** (A) No adaptive coaching in B04; (B) adaptive coaching only for
  a Product Owner-selected integer age in completed years and older; (C) retain
  adaptive coaching unavailable until a separate age/guardian policy is
  approved.
- **Recommended option:** Verified `18 completed years`, inclusive on the
  local civil date of the 18th birthday.
- **Product Owner selection:** Verified age of at least `18 completed years`,
  inclusive on the local civil birthday; no youth/guardian workflow in B04.
- **Rationale:** The approved threshold is explicit, testable and does not
  require inference from behavior or appearance.
- **Safety consequence:** Prevents adaptive target exposure to an unapproved
  age group and prevents age inference.
- **Implementation consequence:** Adaptive eligibility requires a verified,
  user-entered date of birth or another approved verified input; unknown,
  missing, conflicting or invalid age returns `coaching_unavailable`. Age is
  compared as completed years on the stored local civil date, with the 18th
  birthday boundary inclusive. Descriptive logging, workout logging, history,
  user-set targets, dietary filtering, non-adaptive trend display and general
  app access do not require age.
- **Historical consequence:** Append an immutable record to
  `coaching_eligibility_evaluations` with the result, reason, policy version,
  age-input source, evaluation local date/timezone and evidence timestamp;
  include approved user-owned evaluations in Backup v9. No inferred age is
  stored. A later date-of-birth correction affects only future evaluations;
  old recommendations retain their prior eligibility reference.
- **Required tests:** Missing age, conflicting age, exact birthday boundary,
  timezone/local-date boundary, age correction after an issued recommendation,
  no inference from activity/food/appearance, backup lineage and `HOLD-1`
  unavailable output.
- **Tasks affected:** `B04-02`, `B04-05`, `B04-07`, `B04-13`, `B04-15`,
  `B04-17`.

### B04-D04-02 — Eligibility below the minimum age

- **Policy question:** What happens when a verified user is below the selected
  minimum age?
- **Options:** (A) Adaptive coaching unavailable while descriptive logging,
  history and user-set targets remain available; (B) block all nutrition and
  training logging; (C) route the user to a separately approved guardian or
  youth product flow.
- **Recommended option:** A, with the explicit state
  `coaching_unavailable_age`.
- **Product Owner selection:** Below-18 users retain logging, history,
  user-set targets and descriptive summaries; adaptive calorie and
  readiness-driven training proposals are unavailable. No youth/guardian flow
  is in mandatory B04.
- **Rationale:** Blocking data ownership would damage user history, while
  enabling adaptive targets without an approved age policy is unsafe.
- **Safety consequence:** Prevents target adaptation and medical-style coaching
  below the approved boundary without erasing descriptive records.
- **Implementation consequence:** Return an explicit `coaching_unavailable`
  state with approved copy; do not calculate or suggest adaptive calorie or
  readiness-driven training changes. Below-18 uses the distinct
  `coaching_unavailable_age` state, with no medical, punitive or judgmental
  wording. Do not infer age from appearance or usage.
- **Historical consequence:** Append the `underage` result, reason, policy
  version, source and evaluation timestamps to
  `coaching_eligibility_evaluations`; preserve descriptive records and prior
  recommendations as readable history. Do not calculate an unused adaptive
  target in the background, and do not rewrite an earlier evaluation.
- **Required tests:** Below-threshold, unknown-age, age-change, logging/history
  availability, no adaptive proposal, no target mutation, backup/restore and
  wording/accessible-state tests.
- **Tasks affected:** `B04-02`, `B04-05`, `B04-07`, `B04-10`, `B04-13`,
  `B04-15`, `B04-17`.

### B04-D04-03 — Coaching opt-in and default state

- **Policy question:** Is adaptive coaching opt-in or default-on?
- **Options:** (A) Default off; explicit enable required; (B) default on after
  onboarding; (C) enable only after a separate user command for each proposal.
- **Recommended option:** A, plus explicit acceptance for every proposed target
  that would become active.
- **Product Owner selection:** Adaptive coaching is off by default; enabling
  requires an explicit user action after disclosure. Prior logging, continued
  use, inactivity, existing goals and previous targets are not consent.
- **Rationale:** The accepted B04-D02 contract requires opt-in and acceptance;
  inactivity, prior logging and prior targets are not consent.
- **Safety consequence:** Prevents silent target changes and prevents food or
  health logging from being treated as consent.
- **Implementation consequence:** Persist a versioned preference with
  `adaptive_coaching_enabled=false` by default. A proposal is read-only until
  the user accepts it; disabling stops new proposals immediately.
- **Historical consequence:** Append enable/disable/withdraw events to
  `coaching_consent_events` with consent-policy version, copy version,
  effective local date, timezone, UTC timestamp and actor/source; include the
  events in Backup v9. Issued recommendations, accepted target versions and
  feedback remain readable after disablement.
- **Required tests:** Fresh-user default, inactivity/logging is not consent,
  explicit enable/disable, proposal rejection/acceptance, restart, restore,
  duplicate command and effective-date target history.
- **Tasks affected:** `B04-02`, `B04-05`, `B04-07`, `B04-13`, `B04-15`,
  `B04-17`.

### B04-D04-04 — Consent and introductory copy

- **Policy question:** What must be shown before coaching is enabled, and how
  are coaching and AI consent separated?
- **Options:** (A) A pre-enable disclosure followed by separate adaptive and AI
  consent; (B) one bundled consent; (C) implicit consent from use of the app.
- **Recommended option:** A.
- **Product Owner selection:** Separate adaptive and AI consent after the
  approved semantic disclosure. Exact production copy remains subject to Terra
  review for clarity, accessibility and layout.
- **Rationale:** Adaptive targets and optional AI have different data, network
  and authority boundaries; bundled or implicit consent is not reviewable.
- **Safety consequence:** Prevents unreviewed health/allergy disclosure and
  prevents AI wording from being mistaken for target or safety authority.
- **Implementation consequence:** Show before enablement: what user-entered and
  historical inputs may be used; that outputs are proposals; that the user
  accepts each target; that coaching can be disabled; that incomplete evidence
  may return unavailable; that AI is optional and cannot set targets or bypass
  safety; offline/unavailable behavior; and the non-medical boundary. Persist
  separate consent flags, policy/copy versions, effective dates, UTC timestamps,
  local date and timezone. Do not persist raw disclosure text, prompts or
  responses.
- **Historical consequence:** Consent version/timestamp and enable/disable/
  withdrawal events are append-only in `coaching_consent_events` and
  backupable; old recommendations remain readable and feedback is retained
  after disablement. No raw disclosure text or AI prompt is stored.
- **Required tests:** Copy presence/order, separate consent paths, consent
  withdrawal, timestamp/version persistence, offline consent, accessibility
  semantics and no implicit consent from inactivity or food logging.
- **Tasks affected:** `B04-02`, `B04-05`, `B04-13`, `B04-14`, `B04-15`,
  `B04-17`.

### B04-D04-05 — Goal-change and target-change cadence

- **Policy question:** How often may goals, targets and adaptive proposals
  change, and what cooldown follows a manual target change?
- **Options:** (A) No automatic target changes; user-triggered proposals only;
  (B) automatic changes at a Product Owner-selected cadence with a separate
  manual-change cooldown; (C) every new observation may trigger a proposal.
- **Recommended option:** A: no background automatic target changes; explicit
  user action or an explicitly approved scheduled review may initiate an
  evaluation.
- **Product Owner selection:** No background automatic target changes; no
  proposal becomes active automatically; one observation never triggers a
  target change. Proposal frequency and manual-change cooldown remain under
  `HOLD-1`.
- **Rationale:** An unselected cadence can cause repeated or contradictory
  target changes and can reinterpret historical adherence.
- **Safety consequence:** Prevents oscillation, surprise changes and a target
  change triggered by one noisy observation.
- **Implementation consequence:** No adaptive calorie or readiness-driven
  training proposal is emitted under `HOLD-1`. Explicit user action or an
  explicitly approved scheduled review may initiate evaluation; a scheduled
  review may calculate a proposal only after the numerical evidence and cadence
  policy are approved. No proposal becomes active automatically. Same-day
  replacement, duplicate commands, contradiction handling and stale-evidence
  behavior are deterministic; every accepted change gets a new effective-dated
  version.
- **Historical consequence:** Store source, effective local date/timezone,
  superseded version, cooldown/cadence policy version and evidence links; old
  target and recommendation records never update.
- **Required tests:** Repeated trigger suppression, manual-change cooldown,
  same-day replacement, contradictory goals, stale evidence, timezone/DST,
  duplicate command and historical read stability.
- **Tasks affected:** `B04-02`, `B04-05`, `B04-07`, `B04-10`, `B04-11`,
  `B04-13`, `B04-17`.

### B04-D04-06 — Trend window

- **Policy question:** What observation window is required for weight/body
  trend evidence?
- **Options:** (A) No adaptive trend use; (B) a Product Owner-selected count
  of local civil days with an explicit valid-observation count; (C) a single
  current measurement.
- **Recommended option:** A qualitative trend contract with a versioned local-
  civil-day window; C is rejected.
- **Product Owner selection:** A single measurement cannot establish a trend.
  The window must define local-civil-day start/end inclusivity, valid count,
  duplicate/stale/conflicting/correction handling, timezone and ranges. The
  window duration, valid count and staleness cutoff remain under `HOLD-1`.
- **Rationale:** The audit found sparse body measurements and device-local date
  risks; a single measurement cannot establish a trend.
- **Safety consequence:** Prevents noisy or sparse measurements from driving
  adaptation.
- **Implementation consequence:** Under `HOLD-1`, trend-dependent adaptation
  is unavailable. A future policy must record window unit as local civil days,
  start/end inclusion, required valid-day count, source/quality rules,
  timezone, stale cutoff, range handling and policy version.
- **Historical consequence:** Freeze the window definition, measurement IDs,
  values/status/ranges, local dates/timezone and calculation version in
  recommendation evidence; later measurements do not rewrite old trends.
- **Required tests:** Window edges, missing days, duplicate days, out-of-order
  measurements, stale data, DST/travel, range-only measurements, correction
  lineage and no-trend unavailable output.
- **Tasks affected:** `B04-02`, `B04-06`, `B04-07`, `B04-08`, `B04-10`,
  `B04-13`, `B04-17`.

### B04-D04-07 — Minimum evidence before adaptation

- **Policy question:** What minimum valid evidence and completeness threshold
  are required before a target can adapt?
- **Options:** (A) No adaptive output until a Product Owner-selected evidence
  set and numeric completeness threshold pass; (B) adapt from any one valid
  input; (C) fill missing inputs from defaults or zeros.
- **Recommended option:** A: require an explicitly approved evidence set and
  completeness rule; C is prohibited by B03/B02 contracts.
- **Product Owner selection:** The evidence contract includes active goal,
  valid target, verified age eligibility, body metrics, nutrition evidence and
  completeness, recovery/readiness, freshness, timezone/local date, dietary
  safety, ranges and unknown states. Exact completeness percentage, valid-day
  count and range-acceptance threshold remain under `HOLD-1`.
- **Rationale:** B03 unknown/range facts and B02 missing recovery are first-class
  states; defaults would create false precision.
- **Safety consequence:** Prevents adaptation from partial logs, missing health,
  stale metrics or unsupported assumptions.
- **Implementation consequence:** Missing values never become zero; unknown,
  estimated and range-valued inputs retain their status; stale/conflicting
  evidence is exposed; profile defaults and current catalogue values cannot
  replace historical evidence. Missing required evidence returns unavailable
  with a structured missing-input list.
- **Historical consequence:** Store evidence IDs, status/ranges, completeness
  result, threshold/policy version and unavailable reason with each proposal or
  withheld result; do not backfill missing evidence.
- **Required tests:** Each missing input, denied provider, stale input,
  estimated/range input, threshold inclusive/exclusive edges, contradictory
  evidence, no-zero substitution and deterministic replay.
- **Tasks affected:** `B04-01`, `B04-02`, `B04-06`, `B04-07`, `B04-08`,
  `B04-10`, `B04-12`, `B04-13`, `B04-17`.

### B04-D04-08 — Maximum upward and downward adjustment bounds

- **Policy question:** What is the maximum calorie-target increase/decrease per
  adaptation event and over a defined period?
- **Options:** (A) No adaptive change; (B) a Product Owner-selected absolute
  kcal bound per event plus a Product Owner-selected aggregate bound over a
  named local-civil-day period; (C) an unbounded percentage of estimated need.
- **Recommended option:** A until future numerical bounds are separately
  approved; C is rejected.
- **Product Owner selection:** Under `B04-D04-HOLD-1`, maximum upward
  adjustment is `0 kcal`, maximum downward adjustment is `0 kcal`, and maximum
  aggregate adjustment is `0 kcal`.
- **Rationale:** Existing `-500/+300` values have no evidence, period,
  versioning or override contract and therefore cannot be reused.
- **Safety consequence:** Prevents unbounded target movement and prevents a
  user override or AI output from bypassing limits.
- **Implementation consequence:** `HOLD-1` permits exactly `0 kcal` increase
  and `0 kcal` decrease per event and exactly `0 kcal` aggregate change over
  each local-civil-day period, with inclusive zero bounds; missing data yields
  no proposal. A future policy must specify direction, unit (`kcal`),
  inclusive/exclusive edge, event/aggregate period, floor/ceiling interaction,
  stale/missing behavior, policy version and override rule.
- **Historical consequence:** Persist proposed/applied delta, pre/post target,
  event and aggregate period, policy version, evidence and acceptance/override
  event. Never recompute an old delta from a current target.
- **Required tests:** Zero-delta hold, lower/upper exact edges, one-unit beyond
  each edge, aggregate-period edge, repeated events, missing evidence, manual
  override, policy-version replay and historical lineage.
- **Tasks affected:** `B04-02`, `B04-07`, `B04-10`, `B04-13`, `B04-17`.

### B04-D04-09 — Deficit and surplus safety boundaries

- **Policy question:** What deficit and surplus boundaries may an adaptive
  target use, including floor/ceiling behavior?
- **Options:** (A) No adaptive deficit or surplus; (B) a Product Owner-selected
  signed kcal range relative to a named baseline with explicit floor/ceiling;
  (C) reuse the legacy fixed values and floor.
- **Recommended option:** A: no adaptive deficit or surplus until numerical
  policy is separately approved; C is rejected.
- **Product Owner selection:** B04 must not prescribe an adaptive deficit or
  surplus under `HOLD-1`; no calorie floor or ceiling is claimed medically
  safe and no valid user-set target is silently clamped.
- **Rationale:** The existing `1200` floor and `-500/+300` deltas are legacy
  UI behavior, not an accepted medically sensitive product policy.
- **Safety consequence:** Prevents the engine from presenting an unapproved
  calorie prescription or implying that a floor is clinically safe.
- **Implementation consequence:** Under `HOLD-1`, adaptive deficit/surplus
  status is `unavailable`; a valid user-set target is displayed as user-set
  without B04 silently clamping it. A future policy must specify baseline,
  signed unit, inclusive/exclusive boundary, effective period, floor/ceiling,
  unsupported states, versioning, override behavior and tests.
- **Historical consequence:** Persist the target source, baseline/evidence,
  requested delta, policy version, unavailable reason or accepted value and
  effective local date/timezone. Do not rewrite historical targets when policy
  changes.
- **Required tests:** Legacy constants are not invoked, missing baseline,
  floor/ceiling exact edges after approval, unsupported/underweight state,
  manual target preservation, policy-version replay and copy tests.
- **Tasks affected:** `B04-02`, `B04-07`, `B04-10`, `B04-13`, `B04-15`,
  `B04-17`.

### B04-D04-10 — Missing body metrics

- **Policy question:** What happens when required weight, height or other body
  metrics are missing, stale, conflicting or user-withheld?
- **Options:** (A) Show user-set target/history and return adaptive unavailable;
  (B) use a fixed default or profile fallback; (C) infer a metric from account
  activity, appearance or unrelated logs.
- **Recommended option:** A; B and C are rejected.
- **Product Owner selection:** A: preserve typed missing/stale/conflicting
  status, provide no fallback or inference, keep valid user-set targets
  displayable and return unavailable when no valid target exists.
- **Rationale:** The audit found fallback profile facts and mutable current
  profile paths; they are not evidence for a historical adaptive decision.
- **Safety consequence:** Prevents false personalization and prevents missing
  metrics becoming hidden defaults.
- **Implementation consequence:** Preserve missing/stale/conflicting status;
  do not calculate adaptive output. A user-set target remains displayable if
  valid, and any invalid/absent target returns unavailable rather than a
  fallback value.
- **Historical consequence:** Freeze source, timestamp, local date/timezone,
  quality/status and metric values or ranges in evidence; corrections create
  new observations and do not mutate old recommendations.
- **Required tests:** Missing height/weight, stale metric, conflict, user
  withheld value, legacy fallback rejection, user-set display, no target
  mutation and restore lineage.
- **Tasks affected:** `B04-01`, `B04-06`, `B04-07`, `B04-08`, `B04-10`,
  `B04-13`, `B04-15`, `B04-17`.

### B04-D04-11 — Missing or incomplete nutrition logs

- **Policy question:** How does missing, partial, estimated or range-valued
  nutrition history affect adaptation and remaining-target guidance?
- **Options:** (A) Keep unknown/partial/range state and return unavailable when
  the decision cannot be bounded; (B) treat missing as zero; (C) replace it
  with current catalogue values or a point estimate.
- **Recommended option:** A.
- **Product Owner selection:** A, binding B03-D07/D10/D11/D17: use only B03
  immutable read models; known zero may contribute zero, while unknown,
  not-applicable, estimated, range and partial values retain their status.
- **Rationale:** B03 snapshots, nutrient rows, estimates and corrections are
  the historical authority; missing is not zero and estimates are not facts.
- **Safety consequence:** Prevents undercounted intake and exact-looking
  adaptation from incomplete records.
- **Implementation consequence:** Consume only B03 read models. Known zero may
  contribute zero; missing/not-applicable stays non-numeric; ranges propagate;
  stale or insufficient logs return unavailable and list missing evidence.
- **Historical consequence:** Preserve snapshot IDs, nutrient status, bounds,
  estimate/correction lineage, local date/timezone and read-model version in
  recommendation evidence; catalogue changes never rewrite old results.
- **Required tests:** No logs, partial day, unknown nutrient, known zero,
  estimated point, lower/upper range crossing, correction, stale period,
  offline and historical replay.
- **Tasks affected:** `B04-01`, `B04-07`, `B04-08`, `B04-10`, `B04-12`,
  `B04-13`, `B04-15`, `B04-17`.

### B04-D04-12 — Missing recovery/readiness

- **Policy question:** What happens when recovery/readiness is missing,
  denied, stale, contradictory or incomplete?
- **Options:** (A) Readiness is unknown and readiness-driven adaptation is
  unavailable; (B) treat missing recovery as zero/low readiness; (C) infer
  readiness from activity or calendar data.
- **Recommended option:** A.
- **Product Owner selection:** A, binding B02-D11 and B04-D06: preserve
  unknown/unavailable, permission and provenance states; suppress
  readiness-driven proposals and never infer readiness from schedule/activity.
- **Rationale:** B02 explicitly says missing recovery is unknown; provider
  permission/error is not a measurement.
- **Safety consequence:** Prevents health-derived target or load changes from
  fabricated readiness.
- **Implementation consequence:** Persist normalized observations and
  completeness-aware snapshots with source, permission, freshness, range/status
  and provenance. Missing/denied/conflicting inputs suppress readiness-driven
  changes and expose the unavailable reason; no B02 history mutation occurs.
- **Historical consequence:** Freeze observation IDs, source/provenance,
  statuses/ranges, local date/timezone, readiness calculation version and
  supersession links; corrections append new observations/snapshots.
- **Required tests:** Complete/incomplete, denied permission, provider error,
  stale, conflicting, range-only, timezone/DST, idempotent import, no-zero and
  historical replay.
- **Tasks affected:** `B04-01`, `B04-06`, `B04-07`, `B04-10`, `B04-13`,
  `B04-17`.

### B04-D04-13 — Professional-advice wording

- **Policy question:** What wording is allowed for wellness, non-medical,
  missing-evidence and professional-consultation states?
- **Options:** (A) Use a reviewed wording catalog with explicit unavailable
  states; (B) allow free-form generated advice; (C) use clinical-sounding
  target instructions.
- **Recommended option:** A.
- **Product Owner selection:** Use a deterministic reviewed wording catalog for
  the approved semantic states. Exact production copy remains subject to Terra
  review for clarity, accessibility and layout.
- **Rationale:** Wording is part of the safety contract and must match the
  deterministic state, not an AI provider’s style.
- **Safety consequence:** Prevents diagnosis, prescription, guarantee and
  replacement-of-care claims.
- **Implementation consequence:** The approved semantic catalog must cover:
  general wellness guidance that is not medical advice; insufficient reliable
  information with the current target unchanged; unsupported requested goals
  with the target unchanged; consultation with a qualified healthcare
  professional for medical or treatment decisions; no diagnosis,
  prescription, guarantee or replacement-of-care claim; and severe/emergency
  symptoms outside the feature with appropriate local emergency help. Terra
  reviews the exact production copy.
- **Historical consequence:** Persist wording/state key, copy version, policy
  version and evidence references with issued recommendations; raw generated
  wording is not an authority and is not required for replay.
- **Required tests:** Exact state-to-copy mapping, no diagnosis/prescription/
  guarantee terms outside approved catalog, missing/aggressive/medical cases,
  emergency exclusion, localization/accessibility and deterministic replay.
- **Tasks affected:** `B04-02`, `B04-09`, `B04-10`, `B04-12`, `B04-13`,
  `B04-14`, `B04-15`, `B04-17`.

### B04-D04-14 — Medical and diagnostic exclusions

- **Policy question:** Which medical, diagnostic, treatment and outcome claims
  must the system exclude?
- **Options:** (A) Exclude diagnosis, treatment, prescription, clinical
  interpretation, emergency assessment and guaranteed outcomes; (B) allow
  medical interpretation from user-entered conditions; (C) allow AI to fill
  clinical gaps.
- **Recommended option:** A.
- **Product Owner selection:** Exclude diagnosis, diagnosis validation,
  treatment prescription, clinical symptom interpretation, emergency-severity
  assessment, guarantees, professional-equivalence claims, medical inference
  and AI clinical-gap filling. Bind B04 charter exclusions and B03-D19.
- **Rationale:** A user-entered restriction is an input constraint, not a
  clinically verified diagnosis or authorization.
- **Safety consequence:** Prevents the app from replacing professional care or
  converting a goal request into a medical prescription.
- **Implementation consequence:** Medical restrictions are stored as
  user-entered constraints with provenance; the system may filter or withhold
  a candidate but cannot diagnose, validate clinically, prescribe, predict an
  outcome or assess emergency symptoms. Use D04-13 wording.
- **Historical consequence:** Preserve the user-entered restriction reference,
  evidence state, wording/state key and policy version; never store an inferred
  condition or send raw restriction text to AI by default.
- **Required tests:** Medical restriction, aggressive request, symptom/emergency
  text, AI prompt injection, no diagnosis/prescription/guarantee output,
  redaction, restore and history stability.
- **Tasks affected:** `B04-02`, `B04-09`, `B04-10`, `B04-12`, `B04-13`,
  `B04-14`, `B04-15`, `B04-17`.

### B04-D04-15 — Allergy and dietary hard-block behavior

- **Policy question:** Which B03 dietary conflicts are hard blocks, and may a
  user override them?
- **Options:** (A) Map B03 confirmed conflicts for strict allergy, intolerance,
  religious and ethical constraints to hard blocks; (B) show every conflict as
  a soft warning; (C) infer safety from a food name or no-known-conflict result.
- **Recommended option:** A, with no override that changes the safety result.
- **Product Owner selection:** Adopt B03-D14 and B04-D08: confirmed strict
  allergy, intolerance, religious and ethical conflicts are hard blocks; no
  acknowledgement or override changes the evaluator result.
- **Rationale:** B03 is the sole constraint authority and already requires
  typed evidence, strictness, cross-contact relevance and cautious outcomes.
- **Safety consequence:** Confirmed conflicts are removed from eat-now and
  target guidance; a logged historical item remains history, not approval.
- **Implementation consequence:** `confirmed_conflict` is a deterministic hard
  block for the listed strict safety-sensitive types. `no_known_conflict` may
  only render “No known conflict detected for the checked evidence.” Possible
  and insufficient states follow D04-16. User acknowledgement/override may
  record a personal decision or logging event, but cannot present the candidate
  as safe or bypass a hard block in recommendation output.
- **Historical consequence:** Freeze constraint ID/version, evidence IDs,
  strictness/severity, cross-contact result, candidate identity/version,
  acknowledgement/override event and policy version in recommendation lineage.
- **Required tests:** Confirmed allergy/intolerance/religious/ethical cases,
  strictness, cross-contact, no-known wording, unknown ingredient, user
  override/logging, restore and no name-inference.
- **Tasks affected:** `B04-01`, `B04-09`, `B04-10`, `B04-12`, `B04-13`,
  `B04-14`, `B04-15`, `B04-16`, `B04-17`.

### B04-D04-16 — Possible or insufficient evidence

- **Policy question:** What happens when an ingredient conflict or safety
  decision is possible, unknown or insufficiently evidenced?
- **Options:** (A) Withhold safety-sensitive guidance as unavailable; (B) show
  a warning that requires explicit acknowledgement without calling it safe; (C)
  treat the state as no conflict.
- **Recommended option:** A for target/safety guidance; B may be used only for
  a separately approved low-risk logging action and must retain the warning.
- **Product Owner selection:** Possible conflict, unknown conflict,
  insufficient evidence, missing ingredient evidence, possible cross-contact
  and structurally invalid evidence return `unavailable` for eat-now, adaptive
  target, daily/weekly coaching, ranked meal candidates and any output
  represented as suitable under active constraints. No state is downgraded to
  no conflict.
- **Rationale:** Unknown composition and possible cross-contact cannot support
  a safety claim under B03-D14.
- **Safety consequence:** Prevents uncertain candidates from being ranked as
  safe or used to justify a target.
- **Implementation consequence:** Return `unavailable` with the missing or
  conflicting evidence list for every listed safety-sensitive output. If a
  separately defined low-risk logging action permits acknowledgement, retain
  the original evaluator result and warning, do not place the item into
  recommendation output or change its ranking, and never alter the evaluator
  result or bypass a hard block.
- **Historical consequence:** Persist the original B03 outcome, evidence scope,
  missing fields, displayed warning and policy version in the relevant safety
  evaluation/logging lineage; a low-risk acknowledgement or override is an
  append-only feedback event and never becomes recommendation output or a
  ranking input. Corrections append lineage rather than rewriting the result.
- **Required tests:** Unknown ingredient, possible conflict, insufficient
  information, missing ingredient evidence, possible cross-contact,
  structurally invalid evidence, every safety-sensitive output, low-risk
  acknowledgement preservation, no-known negative, offline, restore and
  deterministic replay.
- **Tasks affected:** `B04-01`, `B04-08`, `B04-09`, `B04-10`, `B04-12`,
  `B04-13`, `B04-15`, `B04-17`.

### B04-D04-17 — Offline behavior

- **Policy question:** What deterministic coaching remains available offline,
  and what happens when required evidence cannot be obtained?
- **Options:** (A) Local deterministic reads/guidance remain available when all
  required local evidence is present; missing required evidence is unavailable;
  (B) require network for every recommendation; (C) synthesize missing values
  locally.
- **Recommended option:** A, with `HOLD-1` disabling adaptive target proposals.
- **Product Owner selection:** Local deterministic history, user-set target
  display, descriptive summaries, filtered guidance with complete local
  evidence, feedback and explicit unavailable states remain available offline.
  No invented evidence, queued authoritative target change, cached AI
  authority or safety downgrade is permitted. Bind B04-D05/D15 and B03-D19.
- **Rationale:** Offline operation is a B04 requirement, and network fallback
  values are not nutrition or safety truth.
- **Safety consequence:** Prevents invented data, network-dependent target
  authority and false confidence during provider failure.
- **Implementation consequence:** Local logs, history, user-set target display,
  deterministic filtered guidance, feedback and unavailable states work with
  no network. Required missing/denied/stale evidence remains unavailable; no
  provider call is queued as an authoritative target change.
- **Historical consequence:** Persist only local typed evidence, policy/rule
  versions, state and feedback; do not back up network payloads, raw prompts,
  images or provider health payloads.
- **Required tests:** Airplane mode, offline restart, no-network assertion,
  missing/denied health, partial nutrition, deterministic replay, feedback and
  no background target mutation.
- **Tasks affected:** `B04-01`, `B04-08`, `B04-10`, `B04-12`, `B04-13`,
  `B04-14`, `B04-15`, `B04-16`, `B04-17`.

### B04-D04-18 — AI unavailable behavior

- **Policy question:** What happens when optional AI is disabled, offline,
  unavailable, malformed or returns a conflicting explanation?
- **Options:** (A) Keep the deterministic result unchanged; if no deterministic
  result exists, return unavailable; (B) use AI as a fallback target/safety
  authority; (C) use a stored provider answer as a target default.
- **Recommended option:** A.
- **Product Owner selection:** AI is optional wording assistance only; separate
  explicit AI opt-in is required and is not implied by coaching consent. AI
  cannot alter target, delta, safety, identity, ranking, evidence, ranges,
  completeness, availability or confidence.
- **Rationale:** AI may improve wording only after deterministic filtering and
  target calculation; it cannot author safety, targets or identity.
- **Safety consequence:** Prevents provider failure or prompt injection from
  changing a target, safety state, confidence, candidate or evidence.
- **Implementation consequence:** AI receives a minimized redacted envelope
  only after separate consent. It may return wording/alternative phrasing;
  schema-invalid, unavailable or conflicting output is discarded. AI cannot
  alter target, delta, safety state, candidate identity, ranking, evidence,
  ranges, completeness, availability or confidence; these come only from local
  deterministic results.
- **Historical consequence:** Record provider/model metadata only when needed
  for bounded reproducibility; do not persist or back up raw prompts, responses,
  images, health/allergy payloads, provider secrets or access tokens.
  Deterministic lineage remains complete without AI.
- **Required tests:** Consent off/on, redaction, offline/provider timeout,
  malformed output, conflicting output, prompt injection, no target mutation,
  no safety bypass, log redaction, backup exclusion and deterministic fallback.
- **Tasks affected:** `B04-01`, `B04-10`, `B04-13`, `B04-14`, `B04-15`,
  `B04-16`, `B04-17`.

### B04-D04-19 — Target acceptance, user actions and override

- **Policy question:** What can a user acknowledge, dismiss, accept or
  override, and what does target acceptance mean for safety and history?
- **Options:** (A) Append-only feedback; accept creates a new effective-dated
  target version; hard blocks remain; (B) override changes the evaluator result;
  (C) acceptance silently changes the active target or retrains the engine.
- **Recommended option:** A.
- **Product Owner selection:** Append-only acknowledgement, dismissal,
  acceptance, override and snooze. Acceptance creates a new effective-dated
  target version only after an enabled policy exists; under `HOLD-1` no adaptive
  target can be accepted because no adaptive proposal exists. Bind
  B04-D02/D03/D14 and B03-D14.
- **Rationale:** User control requires reversible explicit actions without
  converting personal choice into evidence or safety approval.
- **Safety consequence:** Acknowledgement cannot make a conflict safe; a hard
  block cannot be bypassed in guidance; acceptance cannot force a target under
  `HOLD-1`.
- **Implementation consequence:** Record `acknowledge`, `dismiss`, `accept`,
  `override`, `snooze` and any exposed reason as append-only events. Adaptive
  proposals are read-only until explicit acceptance; acceptance is idempotent,
  creates a new effective-dated target version and never silently replaces the
  active target. Rejection/dismissal does not mutate it. A manual override is
  labelled user-set and cannot alter B03 evidence, safety output or deterministic
  policy. Snooze carries a typed period and changes presentation only.
- **Historical consequence:** Backup feedback and recommendation lineage;
  preserve issued output, supersession, user action, policy version and target
  versions. Dismissal hides a projection but does not delete history; disabling
  coaching does not delete feedback.
- **Required tests:** Duplicate/retry idempotency, hard-block override attempt,
  warning acknowledgement, acceptance, dismissal, snooze, target versioning,
  offline action, restore and historical replay.
- **Tasks affected:** `B04-05`, `B04-07`, `B04-09`, `B04-10`, `B04-11`,
  `B04-12`, `B04-13`, `B04-15`, `B04-16`, `B04-17`.

### B04-D04-20 — Conditional N8 context boundary

- **Policy question:** Which festival, eating-out, fasting or travel context
  semantics may enter mandatory B04 completion?
- **Options:** (A) Keep N8 conditional and outside mandatory B04; (B) add an
  explicit user-entered context contract through a new approved task DAG; (C)
  infer context from calendar, location, time, food history or restaurant data.
- **Recommended option:** A; B requires a new Product Owner/roadmap decision;
  C is prohibited.
- **Product Owner selection:** A for current B04 scope; no N8 schema-v18 table,
  Backup-v9 section, target rule or implementation branch is authorized.
- **Rationale:** Existing B04-D01/D10 and B04-18 explicitly separate N8 from
  required B04 outcomes, and B01 owns schedule semantics without owning meal
  context.
- **Safety consequence:** Prevents religious, fasting, travel or restaurant
  assumptions from changing targets or safety decisions.
- **Implementation consequence:** B04-08, B04-12 and B04-13 remain independent
  of N8. If context is absent, use ordinary evidence-limited guidance or
  unavailable; never infer a mode. N8 can trigger only through an explicit
  Product Owner decision, defined semantics, privacy review and a new task DAG.
- **Historical consequence:** No current N8 context is persisted or backed up.
  B04-08, B04-12 and B04-13 remain independent of N8. A future approved
  context must be user-entered, effective-dated, typed, versioned, privacy
  reviewed and linked to recommendation lineage before target interaction is
  implemented.
- **Required tests:** No inference from holiday/calendar/location/clock/food;
  absent context ordinary/unavailable state; current-task independence;
  conditional seam unavailable; no N8 rows in v18/v9; future trigger requires
  explicit decision evidence.
- **Tasks affected:** `B04-01`, `B04-02`, `B04-08`, `B04-10`, `B04-13`,
  `B04-14`, `B04-15`, `B04-17`, `B04-18`.

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
  completeness and assumptions from B03. Estimated values remain ranges and
  are never exactified. For eat-now, adaptive target, daily/weekly coaching,
  ranked meal candidates and any output represented as suitable under active
  constraints, possible conflict, unknown conflict state, insufficient
  evidence, missing ingredient evidence, possible cross-contact or
  structurally invalid evidence returns `unavailable`. A warning plus
  acknowledgement is permitted only for a separately defined low-risk logging
  action; it does not create recommendation output or safety. If an estimated
  range crosses an approved safety or decision boundary, the safety-sensitive
  result is `unavailable`; the range is never exactified. Missing data never
  becomes zero.
- **Rationale:** B03-D10/D11/D17 and the roadmap uncertainty principle are
  binding.
- **Alternatives rejected:** Point-only ranking; midpoint-as-fact; suppressing
  incomplete inputs; current catalogue recalculation.
- **Consequences:** Recommendation DTOs carry uncertainty and evidence fields;
  UI must render partial/range/unavailable states accessibly.
- **Required tests:** Known zero vs missing, range aggregation, threshold
  crossing, incomplete daily totals, estimated candidate, structurally invalid
  evidence, each safety-sensitive output state, low-risk logging acknowledgement
  preservation and offline/manual state.
- **Tasks depending on it:** `B04-01`, `B04-08`, `B04-09`, `B04-10`, `B04-12`,
  `B04-15`.

## B04-D08 — Constraint outcomes and hard-block behavior

- **Question:** How should allergy, intolerance, religious/ethical and
  unknown ingredient evidence constrain guidance?
- **Accepted answer:** Reuse B03’s exact evaluator outcomes. A confirmed
  conflict for a strict safety-sensitive constraint hard-blocks a candidate
  from recommendation output; possible conflict, unknown conflict state,
  insufficient evidence, missing ingredient evidence, possible cross-contact
  and structurally invalid evidence return `unavailable` for eat-now, adaptive
  target, daily/weekly coaching, ranked meal candidates and any output
  represented as suitable under active constraints. A warning plus
  acknowledgement is allowed only for a separately defined low-risk logging
  action. A no-known-conflict result is not a safety guarantee and may not be
  used to override the unavailable states. Dislikes and regional preferences
  can be soft filters. A user override records a personal decision but cannot
  downgrade evidence, create a safety claim or bypass a hard block.
- **Rationale:** B03-D14 makes the evaluator and evidence source authoritative.
- **Alternatives rejected:** Name-based allergy inference; treating no-known as
  safe; one generic diet string; hidden hard blocks without explanation.
- **Consequences:** `NutritionSafetyFilter` delegates to B03 and stores the
  original evaluation/result evidence used by a recommendation. The mapper
  emits typed `hard_block` or `unavailable` states for the listed
  safety-sensitive outputs. A low-risk logging acknowledgement preserves the
  original evaluator result and warning, never places the item in
  recommendation output or changes ranking, and cannot bypass a hard block.
  Cross-contact fixtures are a Sol gate before UI exposure.
- **Required tests:** All evaluator outcomes across all constraint types,
  strictness, severity, cross-contact, unknown ingredient, missing/invalid
  evidence, safety-sensitive output unavailability, low-risk logging
  acknowledgement preservation, user override and restore.
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
  Provider/model metadata may be retained only when required by the approved
  recommendation replay contract;
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
  v18 and Backup v9 for versioned nutrition goals, the append-only
  `coaching_consent_events` and `coaching_eligibility_evaluations` authorities,
  coaching projections, recovery observations, readiness snapshots/evidence,
  recommendations, recommendation evidence and feedback. Do not back up
  daily/weekly derived totals, in-memory caches, prompts, images or raw
  provider responses. v5–v8 imports remain valid with B04 sections absent and
  do not fabricate consent or eligibility; invalid v9 graphs restore zero rows
  transactionally.
- **Rationale:** M18 explicitly adds durable observations, snapshots,
  recommendations, evidence and feedback; historical explanation cannot be
  reproduced from a cache.
- **Alternatives rejected:** No version bump with JSON preferences; persisting
  recomputable caches; modifying B03 v17 tables without a new migration.
- **Consequences:** Schema migration precedes all B04 durable work; backup
  follows schema ownership; restore ordering and compensation are required.
- **Required tests:** Fresh v18, real v17→v18, direct accepted chain, migration
  rollback, v5/v6/v7/v8 import without fabricated consent/eligibility, v9
  round trip for events/evaluations and all durable graph edges, restore-order
  validation, malformed graph zero mutation, duplicate/cross-user rejection,
  unsupported-policy rejection and preference compensation.
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

## B04-D04 approval state

The twenty records `B04-D04-01` through `B04-D04-20` are the complete policy
packet for the D04 questions named by the planning report. The current explicit
disposition is:

- **Current product behavior:** `HOLD-1`; adaptive coaching is unavailable,
  user-set targets/history remain readable, and no adaptive target delta is
  emitted.
- **Product Owner approval:** Qualitative policy is authorized by the Product
  Owner. Numerical trend duration/count/cutoff, completeness/range threshold,
  proposal frequency/cooldown and calorie/deficit/surplus bounds remain under
  `HOLD-1`.
- **Independent Sol High verdict:** Required next; no adaptive enablement or
  application implementation is authorized until Sol reviews the authorized
  qualitative contract, inherited B01–B03 boundaries and deterministic
  `HOLD-1` fixtures.
- **External food lookup:** remains out of B04; a future request must reopen
  scope and privacy review and cannot be introduced through D04.

After independent Sol High approval of this remediation, `B04-01` may begin.
Foundational tasks may proceed only according to the accepted DAG and their
own dependencies, including Schema v18 and Backup v9 foundations, consent,
eligibility, goals, readiness, safety, lineage, feedback and deterministic
unavailable-state behavior. `HOLD-1` blocks enabled adaptive calorie proposals,
readiness-driven target or training-change proposals, every non-zero adaptive
target delta, adaptive deficit/surplus behavior and calorie floor/ceiling
behavior. It does not block foundational contracts, fixtures, persistence,
descriptive/history or valid user-set-target features. Runtime behavior must
return a truthful unavailable or user-set state and must not invent a policy
constant. Enabled adaptive behavior remains blocked until a superseding
numerical policy is independently approved.

### B04-D04 task mapping

| Task | D04 consequence |
|---|---|
| `B04-01` | Contract fixtures cover age, consent, target acceptance, missingness, dietary states, wording, offline/AI and N8. This task has not started. |
| `B04-02` | Owns this authorized policy packet, `HOLD-1` register and independent Sol review request. |
| `B04-03` | `coaching_consent_events` is the append-only consent authority and `coaching_eligibility_evaluations` is the append-only eligibility authority; both have explicit ownership, IDs, indexes, foreign keys and negative v17→v18 cases alongside target/recommendation lineage. |
| `B04-04` | Backup v9 carries approved consent events, eligibility evaluations, goal/target versions, recommendation lineage and feedback with ordering, ownership, duplicate and unsupported-version validation; raw disclosure/AI/medical/health payloads remain excluded. |
| `B04-05` | Enforce age eligibility, opt-in, separate append-only consent history, derived current projection, explicit acceptance, idempotency and immutable effective-dated target versions; historical evaluations remain immutable. |
| `B04-06` | Preserve recovery provenance/completeness and suppress readiness-driven proposals when evidence is unavailable. |
| `B04-07` | Enforce `18` eligibility, no automatic activation, `HOLD-1` unavailable output with exact zero upward/downward/aggregate deltas, no user/AI bypass and missing/range rules. |
| `B04-08` | Carry local date/timezone, age/consent/evidence state and N8 absence without inference. |
| `B04-09` | Map B03 hard blocks, unavailable possible/insufficient states and exact no-known-conflict wording. |
| `B04-10` | Keep deterministic ranking/evidence/availability authoritative; AI cannot alter outputs. |
| `B04-11` | Freeze age/consent/target/evidence lineage and append feedback without rewriting history. |
| `B04-12` | Exclude hard blocks and return unavailable for possible/unknown/insufficient safety evidence. |
| `B04-13` | Expose durable eligibility and consent projections, age/withheld/unknown states, missing-data, wording, target-acceptance, offline and feedback states with typed unavailable reasons. |
| `B04-14` | Keep AI separate, consented, redacted and wording-only. |
| `B04-15` | Read current consent from the event-derived projection, render age/withheld/unknown eligibility and unavailable safety states accessibly, and obtain Terra review of exact copy; below-age wording is non-punitive. |
| `B04-16` | Verify one durable authority for consent and eligibility, append-only feedback/history and no B01–B03 contract or legacy-policy regression. |
| `B04-17` | Require Product Owner authorization evidence, Terra copy review, incremental task ledger, independent Sol verdict and numerical `HOLD-1` evidence. |
| `B04-18` | N8 remains conditional and outside mandatory B04. |
