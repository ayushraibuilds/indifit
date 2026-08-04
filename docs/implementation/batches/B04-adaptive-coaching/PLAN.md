# B04 — Adaptive Coaching Plan

Status: planning-only package. This document authorizes design and review
work, not B04 implementation.

## Gate and authority

The exact batch title is **B04 — Adaptive Coaching**. The repository roadmap
does not label a section “B04”; the title is the canonical batch name in
`docs/implementation/MASTER_TRACKER.md`, and the scope is mapped to the
roadmap’s E5 Recovery and Coaching epic, M18 migration, Phase 5 exit criteria,
Task 8, and the N9/N10/P1/P2/P7/P9 dependency entries.

| Item | Evidence | Planning consequence |
|---|---|---|
| Planning branch | `batch/b04-planning` at `12ce1b05c7626d3fb37eedc37fc0dd4d7af94d8a` | Documentation only; no feature branch is created. |
| Integration baseline | `main` at the same commit; schema v16, backup v7 | This is the accepted B02 parent available to the planning worktree. |
| B01 | Final verification passed; B01 lineage is in `main` | B04 may consume programs, occurrences, local-date/timezone and immutable execution contracts. |
| B02 | Final verification passed and B02 is integrated in `main` | B04 may consume activity history, load evidence, health provenance and typed optional recovery inputs. |
| B03 | Final r3 passed with non-blocking follow-up; branch `batch/b03-nutrition-foundation` at `d85e8a1` is authorized for final merge | B03 is not an ancestor of `main`; implementation is blocked until the accepted B03 graph is integrated. |
| B03 follow-ups | Manual-review catalogue rows, CI/format idempotence, and reviewer-process evidence are non-blocking B03 follow-ups | B04 must handle unknown/manual-review states but must not absorb B03 remediation. |

The dependency status is therefore:

- **B04 planning allowed:** yes.
- **B04 implementation allowed from this branch:** no; this branch is a
  planning gate.
- **B04 implementation blocked:** yes, pending B03 integration into the
  eventual implementation parent, plus the safety-policy gate in `B04-D04`.
  Planning may proceed while either gate is open.

The implementation parent must be a clean branch containing accepted B01,
B02 and B03. It must not be inferred from the planning branch’s schema v16/v7
state.

## Canonical scope extraction

### Required outcomes

These are the outcomes explicitly supported by E5/M18, the Phase 5 exit
criteria and Task 8. They are the only required B04 product outcomes.

| ID | Required outcome | Roadmap anchor |
|---|---|---|
| B04-R01 | Versioned, explainable nutrition goals and calorie targets that preserve user overrides and historical meaning. | N9, Task 8, cross-feature effective-date and evidence rules |
| B04-R02 | Recovery observations and readiness with explicit completeness/confidence; missing recovery is unknown, not zero. | E5 recovery inputs, P7, cross-feature decision 10 |
| B04-R03 | One evidence-backed recommendation engine used by training and nutrition coaching. | E5, P9, cross-feature decision 11 |
| B04-R04 | Bounded adaptive calorie and training-load guidance that respects safety bounds and accepted user overrides. | E5, N9, Phase 5 exit criteria |
| B04-R05 | Local “what can I eat now?” guidance from trusted B03 candidates, with safety filtering, uncertainty and remaining-target evidence. | N10, E5 |
| B04-R06 | Daily briefing and weekly review read models consuming the same evidence-backed engine and showing why, alternatives and missing evidence. | E5, P1/P2, cross-feature decision 11 |
| B04-R07 | Recommendation evidence, lineage and user feedback sufficient to explain historical guidance. | M18, Task 8, shared `RecommendationEvidence`/`RecommendationFeedback` models |

### Explicit exclusions

- Medical diagnosis, treatment, clinical nutrition advice, allergy guarantees,
  or claims that a food is safe.
- Silent target changes, unbounded calorie deficits, or a target policy that
  has not passed the Product Owner + Sol safety gate.
- Reimplementation of B01 scheduling/execution, B02 activity/load/history or
  B03 nutrition calculation, constraint evaluation, estimate parsing,
  consumption snapshots, recipes or thali.
- N8 festival, travel, eating-out and intermittent-fasting product behavior
  as a required B04 exit outcome. B04 may expose an explicit context seam;
  user-entered modes require a later product decision and are not inferred.
- External food search, pantry inference, invented availability or a cloud
  service as the source of authoritative nutrition advice.
- Detailed leucine/protein-quality/MPS adaptation, nested recipes, vessel-mass
  calibration and unreviewed raw/cooked factors deferred by B03.
- A final replacement of the whole Today/dashboard information architecture.
- Persistent recommendation caches, raw prompts, raw AI responses, images or
  health-provider payloads when the value can be recomputed locally.
- Any later-batch education, social, travel or product-surface expansion not
  named by E5/M18/N9/N10/P1/P2.

### Inherited capabilities

| Capability | Accepted authority | B04 use | B04 must not do |
|---|---|---|---|
| Schedule and occurrences | B01 `CalendarRepository`, local date + IANA timezone | Identify scheduled opportunities and civil-day boundaries | Recreate scheduling or occurrence identity |
| Execution and workout history | B02 `ActivitySessionRepository`, `B02ProgressReadRepository` | Supply immutable workload and completion evidence | Rewrite completed activity records |
| Health provenance | B02 health import/provenance repositories | Preserve source, permission and freshness evidence | Treat unavailable health data as zero or infer recovery |
| Load guidance | B02 `LoadTargetRecommendationService` | Consume existing load evidence and expose B04 overlay separately | Replace B02 ownership or silently mutate load targets |
| Nutrition snapshots/totals | B03 `NutritionConsumptionRepository`, `NutritionReadModelRepository` | Read immutable daily totals and lineage | Aggregate legacy logs as a competing authority |
| Nutrient uncertainty | B03 nutrient status/range/provenance contracts | Propagate known, missing and estimated bounds | Convert missing values to zero or exact values |
| Recipes and thali | B03 canonical repositories and calculation service | Offer trusted local candidates | Use meal templates or AI plans as canonical nutrition |
| Constraints and conflicts | B03 constraint repository and pure evaluator | Apply typed allergy/intolerance/religious/ethical outcomes | Infer constraints or claim “no known conflict” means safe |
| Estimate provenance | B03 estimate repository/parser | Show source, model, confidence and ranges | Persist images/full prompts or hide uncertainty |
| Time handling | B01/B02 `LocalScheduleDateService` and B03 snapshot local date/timezone | Build daily/weekly periods | Use device timezone silently for historical records |
| Accessibility patterns | Accepted B03 constraint/estimate states | Reuse truthful state and semantic wording | Introduce ambiguous loading/unknown/safe states |

### Open decisions

Only product or safety decisions remain open; implementation preferences are
not promoted to product decisions.

| Decision | Why it remains open | Required gate |
|---|---|---|
| Minimum age, adaptive opt-in default and target override copy | The roadmap calls for opt-in/min-age decisions but does not set values. | Product Owner + Sol; Terra for user-facing wording. |
| Deficit/surplus bounds, trend window, cadence and missing-metric behavior | Existing `TdeeCalculator` constants are legacy UI behavior, not an accepted B04 policy. | Product Owner + Sol safety review before `B04-07`. |
| N8 context semantics and ownership | Roadmap makes festival/travel/eating-out/fasting a separate product-owner decision. | Product Owner decision; Sol architecture/safety review before any persistence. |
| Future external lookup | N10 does not authorize a cloud food-search authority. | Reopen scope and privacy review; not a B04 implementation dependency. |

The decisions are recorded as `B04-D01` through `B04-D18` in
`DECISIONS.md`. No other open item found in the targeted audit changes the
product boundary.

## Minimum system boundaries

The design uses small contracts with explicit owners. It intentionally avoids
an oversized “nutrition coach” service that owns schema, calculation, safety,
AI and UI state at once.

| Boundary | Purpose; inputs; outputs | Authoritative owner | Mutable / immutable; history | Privacy | B03 dependency | Persist? / B04? |
|---|---|---|---|---|---|---|
| Goal and target versions | Store accepted user goals, proposed/accepted target values, source and effective local dates; output active and historical versions. Inputs: profile metrics, user command, policy version, optional readiness evidence. | New B04 `NutritionGoalRepository`; profile remains an input, not the history authority. | Preferences and current pointer mutable; accepted versions append-only with supersession/effective dates. Historical reads required. | User-owned sensitive health/goal data; backup allowed. | Reads B03 nutrient units only when setting macro targets. | Durable; B04. |
| Coaching preferences | Store adaptive opt-in, health-input permission/use, AI wording consent and user display choices. | New B04 preferences repository; no second `SharedPreferences` authority for durable settings. | Current preference mutable/versioned; changes timestamped. | Sensitive consent/preferences; backup allowed, no provider payload. | B03 privacy/AI policy informs AI flag. | Durable; B04. |
| Recovery observations | Normalize typed recovery inputs with source, status, ranges, freshness and provenance. | B04 adapter/repository; B02 health/import repositories remain source authorities. | Imported observations immutable; corrections are new records. | Health data; source/provider identifiers only, no raw payload. | No direct B03 dependency. | Durable if needed for historical readiness; B04. |
| Readiness | Calculate a completeness-aware readiness snapshot from accepted observations; output band/status, confidence, evidence IDs and unavailable reason. | New pure B04 `ReadinessService` plus snapshot repository. | Snapshots immutable and superseded; observation links frozen. | Health-derived; backup only with user-owned evidence. | No direct B03 dependency. | Durable for historical recommendations; B04. |
| Adaptive target engine | Calculate proposed calorie/macro and bounded training overlay from goal versions, measurements, trends, workload and readiness. | New pure B04 engine; B02 retains load-target authority. | Proposals ephemeral; accepted targets become goal versions. | Sensitive health/weight data; no AI required. | Consumes B03 totals/ranges for trend evidence. | Engine no; accepted goal yes; B04. |
| Recommendation context | Assemble a typed, redacted snapshot of schedule, activity, nutrition totals, goals, readiness, constraints, time and evidence completeness. | New B04 context assembler; each source repository remains authoritative. | Context snapshot immutable when attached to a recommendation; otherwise ephemeral. | Minimize data; no raw images/prompts; provider-ready redaction. | Strong: B03 totals, estimates, constraints and provenance. | Attached context/evidence durable; transient assembly no. |
| Meal opportunity / current availability | Represent the user’s explicit meal opportunity and selected local candidates for “what can I eat now?”. | New B04 query/service; user selection and B03 catalogue remain authorities. | Input is ephemeral unless referenced by a recommendation; no inferred meal windows. | Local food choices and constraints; no external search. | Strong: B03 recipes, thali, snapshots, constraints. | No standalone table required; B04. |
| Safety filter | Map B03 constraint outcomes and nutrient evidence into block, warning, confirmation or unavailable states. | B03 evaluator remains conflict authority; B04 maps outcomes to recommendation policy. | Pure evaluation; output attached to recommendation if persisted. | Allergy/medical restrictions sensitive; never sent to AI by default. | Strong and non-duplicating. | No independent persistence; B04. |
| One recommendation engine | Rank deterministic training/nutrition actions from context, safety results and policy; output typed recommendation, explanation, confidence, alternatives and missing evidence. | New pure B04 `NutritionRecommendationEngine`. | Output immutable once issued; policy/rule/model versions recorded. | Local by default; optional provider gets redacted text only. | Strong. | Durable recommendation history; B04. |
| Historical lineage and evidence | Freeze source references, values/status/ranges, rule/model/provider versions and supersession relationships for each recommendation. | New B04 history/evidence repositories. | Append-only; no in-place mutation of issued guidance. | User-owned; backups include typed evidence, not raw provider data. | References B03 snapshot/estimate/constraint IDs. | Durable; B04. |
| Daily and weekly read models | Project the same engine/history into local daily briefing and explicit seven-civil-day weekly review. | New B04 read services; no separate recommendation logic. | Recomputable projections; historical recommendation rows immutable. | Local summaries; backup only underlying history. | B03 daily totals and evidence. | No daily/weekly cache table; B04. |
| Feedback | Record acknowledge, dismiss, accept, override, snooze and optional reason as events. | New B04 feedback repository. | Append-only; never rewrite recommendation history. | User-owned behavioral data; backup allowed. | No direct B03 dependency. | Durable; B04. |
| N8 context seam | Accept explicit festival/eating-out/fasting/travel context only if later product scope approves it. | Future context owner; B04 only defines an adapter seam. | No inferred context; no durable table in current B04 plan. | Potentially sensitive religious/health data; explicit consent. | B03 constraints can be read, not redefined. | No current persistence; conditional only. |
| AI provider boundary | Optionally improve wording or alternatives after deterministic result; never author target/safety decision. | New B04 `NutritionAIAdapter` behind privacy policy. | Request/response ephemeral; provider/model version may be recorded as lineage. | Explicit consent; redact health/allergy/raw prompts/images; offline fallback. | Strong B03 privacy and estimate contracts. | No raw AI persistence; optional provider metadata in history. |

## Schema and backup impact

The planning branch itself remains schema v16/backup v7. After B03 is
integrated, the proposed B04 implementation baseline is schema v17/backup v8
and B04 would require schema v18/backup v9. The version increase is justified
by durable historical goals, recovery/readiness, recommendations/evidence and
feedback; it is not justified by recomputable daily/weekly caches.

### Proposed durable entities

| Entity | Portable identity and ownership | Version/time/effective data | Relationships and restore order | Backup/privacy/history |
|---|---|---|---|---|
| `nutrition_goal_versions` | UUID; user-owned; unique user + version | `created_at`, `effective_from_local_date`, IANA timezone, optional `effective_to`, source, calculation/policy version, supersedes | User/profile input; restore after preferences, before readiness/recommendations | Included; sensitive goal data; append-only and historically readable |
| `nutrition_coaching_preferences` | UUID or stable user key; one user-owned current record | version, `created_at`, `updated_at`, opt-ins/consent, archive flag | No child graph; restore first | Included; sensitive consent; mutable current state |
| `recovery_observations` | UUID; user-owned; optional provider external ID with dedupe | observed UTC, local date/timezone, status/range/unit, source/provenance, freshness, created timestamp | Referenced by readiness; restore before readiness | Included without raw health payload; immutable/corrected by new row |
| `readiness_snapshots` + evidence links | UUIDs; user-owned | local date/timezone, completeness/status, calculation version, created/superseded timestamps | References observations; restore after observations and before recommendations | Included; immutable, historical-read required |
| `recommendations` + `recommendation_evidence` | UUIDs; user-owned; evidence child UUID | scope, local period start/end/timezone, status/priority/confidence, rule/model/provider version, goal/readiness/context refs, created/effective/superseded timestamps | Restore after goals/readiness, evidence after recommendation | Included; typed/redacted only; immutable lineage |
| `recommendation_feedback` | UUID; user-owned; recommendation UUID | action/reason, created UTC/local timestamp | Restore after recommendations/evidence | Included; append-only behavioral history |

Required indexes are user/effective-date, observation user/time/kind,
readiness user/local-date/version, recommendation user/scope/period/status,
evidence recommendation/source, feedback recommendation/time and the unique
preference user key. Foreign keys must prevent dangling evidence and feedback.

Restore order is preferences → goals → observations → readiness → readiness
evidence → recommendations → recommendation evidence → feedback. A failed
relationship or preference restore must roll back the entire transaction and
leave the pre-restore database unchanged. v5–v8 imports remain valid with an
empty B04 graph; unknown future B04 records fail closed rather than being
partially restored.

No target cache, daily briefing cache, weekly cache, raw prompt, raw AI
response, image, pantry snapshot or provider health payload is backed up.

## Recommendation safety contract

The deterministic engine must classify every candidate before presentation.
“No known conflict” is not a guarantee of safety, and user override changes
feedback/intent only; it cannot turn a conflict into a safe result.

| Case | Required behavior | Classification |
|---|---|---|
| Confirmed allergy, intolerance, strict religious or ethical conflict | Remove from “eat now” and target guidance; explain the typed conflict. A logged historical item remains history, not approval. | Deterministic hard block |
| Possible conflict or unknown ingredient evidence | Do not claim safe; request confirmation or withhold the candidate when the risk is material. | Warning/confirmation or unavailable |
| No known conflict | Present only “no known conflict” with evidence scope. | Cautious deterministic guidance |
| Unknown nutrient data | Preserve unknown state; do not count it as zero. If target fit cannot be bounded, suppress exact guidance. | Cautious or unavailable |
| Estimated nutrient range | Show estimate/source/range. If the range crosses a meaningful policy boundary, warn or request confirmation. | Cautious, warning or unavailable |
| User-entered medical restriction | Respect it as a constraint; do not diagnose, validate clinically or infer a condition. Use professional-advice wording where policy requires. | Confirmation/professional wording or unavailable |
| Weight-loss or muscle-gain goal | Use only the accepted goal version and approved policy; no guarantee of outcome. | Deterministic bounded guidance |
| Aggressive deficit/surplus | Never silently apply legacy `-500`, `+300` or `1200` values as B04 policy. Until D04 is approved, return a policy-unavailable state. | Unavailable/professional wording |
| Fasting, eating-out or festival context | Never infer it. Without an approved explicit context contract, provide ordinary evidence-limited guidance or unavailable state; do not change targets. | Cautious/unavailable |
| Missing body metrics or recent logs | Show user-set values if valid; do not produce personalized adaptive output without required evidence. | Cautious or unavailable |
| Contradictory goals | Do not choose silently; present the conflict and require user resolution. | User confirmation/unavailable |
| Missing/denied/conflicting health input | Readiness is incomplete/unknown; no readiness-driven adaptation. | Cautious or unavailable |
| AI unavailable or offline | Use deterministic local result or return unavailable; never invent food, consumption, safety or confidence. | Deterministic fallback/unavailable |

These rules require Sol review at `B04-02`, `B04-07`, `B04-09`, `B04-10`,
`B04-14` and the final gate. Terra reviews user-facing wording, confirmation,
dismissal and accessibility at the production integration.

## Outcome traceability

| Required outcome | Implementation tasks |
|---|---|
| B04-R01 | `B04-02`, `B04-05`, `B04-07`, `B04-15` |
| B04-R02 | `B04-01`, `B04-06`, `B04-07`, `B04-13` |
| B04-R03 | `B04-01`, `B04-08`, `B04-09`, `B04-10`, `B04-11`, `B04-16` |
| B04-R04 | `B04-02`, `B04-06`, `B04-07`, `B04-10`, `B04-13`, `B04-15` |
| B04-R05 | `B04-08`, `B04-09`, `B04-12`, `B04-15` |
| B04-R06 | `B04-10`, `B04-11`, `B04-13`, `B04-15` |
| B04-R07 | `B04-01`, `B04-10`, `B04-11`, `B04-13`, `B04-16`, `B04-17` |

Every outcome has at least one implementation owner and a final verification
gate. Conditional N8 work is isolated in `B04-18` and is not required to
declare B04 complete.
