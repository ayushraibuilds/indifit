# B04 — Adaptive Coaching

Status: Documentation-only numerical policy gate; `B04-D04-ENABLED-1` is proposed but inactive. Foundational implementation remains gated by independent Sol High approval and the accepted dependency parent; `B04-D04-HOLD-1` remains the current/default behavior until an explicit release activation.
Planning branch: `batch/b04-planning`
Planning base: `main` at `12ce1b05c7626d3fb37eedc37fc0dd4d7af94d8a`
Accepted B03 integration source: `batch/b03-nutrition-foundation` at `d85e8a16566735e7f6b7fe15cd2a97edb5677178`
Accepted B03 schema/backup baseline: v17 / v8
Proposed B04 durable change: schema v18 / Backup v9
D04 packet branch: `b04/d04-safety-policy-gate`
D04 packet planning baseline: `9102092fd1b18e38beff500e2654ece6a191f66f`
B04 implementation parent: `f976542e395a3e082f1ab5cdfdfd87e969910766`
B04 integration baseline: `741aa18972ebc1b61cd65c0bf12b442b10b50890`
Prior D04 qualitative documentation commit: `750ef0999153a7cc41a2493cb6305d2a833b1f12`
D04 numerical-policy authoring baseline: `61cac3dd35579fde01118626b5fa009024a04a7f`
Proposed enabled calorie policy: `B04-D04-ENABLED-1` (not active; future-only)
Readiness numerical policy: `B04-D04-READINESS-HOLD-1` (retained hold; readiness numerical effect is zero)
Platforms: Android and iOS

## Canonical authority

The exact batch title is **B04 — Adaptive Coaching**, recorded in
`docs/implementation/MASTER_TRACKER.md`. The canonical roadmap maps B04 to
Phase 5 / Epic E5, **Recovery and Coaching**. The binding E5 scope is:

- recovery inputs and readiness with explicit completeness;
- one evidence-backed recommendation engine;
- adaptive training-load and calorie targets;
- a daily briefing and prioritized guidance;
- “what can I eat now?” guidance;
- user overrides and safe, non-medical behavior;
- an explicit Product Owner + independent Sol High policy gate for age,
  consent, evidence, bounds, dietary safety, wording, offline/AI behavior and
  the conditional N8 seam.

The roadmap’s M18 migration adds recovery observations, readiness snapshots,
recommendations, evidence links and feedback. The canonical dependency graph
requires E1–E4, F2/F3/F4 and validated health inputs. B03’s final charter and
decision register explicitly defer adaptive calories, remaining-target
suggestions, recommendation feedback and context-mode coaching to a later
batch; those contracts are consumed here, not reimplemented.

## Goal

Add a local, explainable coaching layer that turns accepted training,
nutrition, body-metric and optional health evidence into bounded guidance. A
recommendation is an evidence-bearing product record, not a hidden mutation of
the user’s schedule, targets or history. Core calculation and safety behavior
must work offline; optional AI may only improve wording over an already filtered
deterministic result.

## Required outcomes

| ID | Required outcome | Canonical evidence | B04 exit proof |
|---|---|---|---|
| B04-R01 | Versioned user goals and target proposals with effective dates, source, user override and historical association | M18; N9; roadmap product-owner decision 2 | A target used for a day/week resolves to the effective goal version and never rewrites prior records. |
| B04-R02 | Recovery observations and readiness snapshots expose completeness, missingness and calculation version | E5; F4; roadmap cross-feature decision 10 | Missing health input remains unknown; readiness is suppressed or downgraded below the approved evidence threshold. |
| B04-R03 | One evidence-backed recommendation engine covers training and nutrition guidance, prioritization, explanation, confidence and alternatives | E5; canonical `Recommendation`, `RecommendationEvidence`, `RecommendationFeedback` | The same frozen context and rule version produce the same result and evidence lineage. |
| B04-R04 | Adaptive calorie targets and bounded recovery-aware training guidance respect safety bounds and user overrides | E5; N9; roadmap Phase 5 exit criteria | Adaptive proposals are opt-in, bounded by an approved policy, reversible, and never silently replace a user-set target. |
| B04-R05 | “What can I eat now?” uses only selected/local canonical food, recipe and thali candidates, remaining-target evidence and B03 safety/uncertainty contracts | E5; N10; B03 explicit deferral | No candidate is invented; confirmed strict conflicts hard-block; possible/unknown/insufficient/missing/possible-cross-contact/structurally invalid evidence is unavailable for safety-sensitive output; unknown/range data remains visible. |
| B04-R06 | Daily briefing and weekly coaching read models consume the same engine without creating a second recommendation authority | E5; P1/P2; canonical flow | Daily and weekly views show prioritized evidence, missing inputs, feedback state and historical goal context. |
| B04-R07 | Recommendation evidence, historical lineage and user feedback preserve why guidance was issued and how the user responded | M18; Task 8; canonical `RecommendationEvidence`/`RecommendationFeedback` | A recommendation remains explainable after goal, catalogue, readiness or source changes; feedback is append-only. |

## Included features

- Hybrid user-set/calculated/adaptive nutrition goal lifecycle.
- Immutable goal versions, effective dates and accepted override lineage.
- Recovery observation normalization from supported local/user-entered and
  provider-backed sources, with provenance and unknown states.
- Versioned readiness calculation and completeness read model.
- One deterministic recommendation contract for training and nutrition.
- Remaining-target and meal-opportunity guidance over local B03 candidates.
- Safety filtering through the B03 constraint evaluator, including uncertainty,
  hard-block and typed unavailable states. Warning plus acknowledgement is
  limited to a separately defined low-risk logging action and never creates
  recommendation output or a safety claim.
- Durable recommendation evidence, historical lineage and append-only feedback.
- Daily briefing and weekly review orchestration over explicit local-date
  periods.
- Optional, privacy-minimized AI wording adapter behind the existing policy gate.

## Explicit exclusions

- Medical diagnosis, treatment, injury rehabilitation, allergy-safety
  guarantees, or professional nutrition prescriptions.
- Runtime enabled adaptation from this documentation branch. The proposed
  `B04-D04-ENABLED-1` contract is not active until Product Owner approval,
  independent fresh Sol High approval, branch merge and explicit release or
  feature-policy selection. `B04-D04-HOLD-1` remains available for historical
  replay and for installations/users not selecting the enabled policy.
- Readiness-driven numerical calorie or training changes. They remain under
  `B04-D04-READINESS-HOLD-1`; descriptive completeness-aware coaching only is
  in scope.
- Reimplementation of B01 scheduling, B02 activity/history, B02 load-rule v1,
  B03 nutrient calculation, B03 immutable snapshots, B03 constraints, B03
  estimates, recipes, thalis or household conversions.
- External food search, pantry inference, restaurant-menu discovery or a claim
  that a food is available. B04 uses local canonical candidates plus explicit
  user selection.
- Automatic festival, travel, eating-out or intermittent-fasting inference or
  target-policy changes. These are the conditional N8 context extension in
  `DECISIONS.md`, not required B04 exit outcomes.
- Detailed leucine thresholds, protein-quality scores, muscle-protein
  synthesis claims or adaptive protein physiology.
- Persistent AI prompts, raw provider responses, images, image caches or
  provider-side history; AI is never a safety, target or identity authority.
- A second weekly-report narrative engine, a dashboard redesign, design-system
  migration, education/media work or cloud/account synchronization.
- B03’s accepted non-blocking follow-ups. They remain B03-owned and must not
  be silently absorbed into B04 implementation.

## Required foundations

- B01 program, occurrence, local-date/timezone and immutable execution
  contracts.
- B02 typed `ActivitySession`, activity history, health provenance, reviewed
  load-target evidence and backup v7.
- B03 accepted v17/v8 nutrition identity, quantities, nutrient statuses/ranges,
  immutable consumption snapshots, recipes/thali, estimate provenance,
  structured dietary constraints and read-model ownership.
- A named, integrated B03 parent branch with no unresolved integration merge.
- Product Owner approval of the proposed `B04-D04-ENABLED-1` numerical target
  policy and an independent fresh Sol High safety/implementation-readiness
  verdict. The policy is not active from this branch: merge and an explicit
  release/feature-policy selection are also required. The disabled `HOLD-1`
  contract remains sufficient for historical replay and for foundational
  contracts, but not for enabled numerical runtime behavior.
- A Product Owner-authorized `B04-D04` qualitative packet, the proposed
  `B04-D04-ENABLED-1` numerical packet, and an independent fresh Sol High
  verdict. The enabled packet is future-only and inactive until the branch is
  merged and the release/feature policy explicitly selects it. `HOLD-1`
  remains available for historical replay and non-enabled installations/users;
  `B04-D04-READINESS-HOLD-1` keeps all readiness-driven numerical effects at
  zero. Neither hold blocks schema/backup foundations, persistence,
  unavailable states, descriptive behavior or valid user-set-target behavior.
- One user/profile identity and timezone authority for B04 writes.

## Inherited contracts B04 may consume

| Contract | Authoritative owner | B04 use | B04 must not do |
|---|---|---|---|
| Scheduled occurrences and effective local dates | B01 `CalendarRepository` / `CalendarReadRepository` | Read schedule, next required session, deload/travel context | Mutate occurrences or infer meal timing from workout dates |
| Typed activity and performed history | B02 `ActivitySessionRepository`, `B02ProgressReadRepository` | Read load, volume, duration, partial completion and source | Reclassify or rewrite completed activity |
| Health provider provenance | B02 `HealthActivityImportRepository`, `HealthProvenances` | Import/normalize evidence through an observation adapter | Treat missing permission/error as zero |
| Nutrition history/totals | B03 `NutritionReadModelRepository` / `NutritionConsumptionRepository` | Read immutable snapshots, local-date totals and lineage | Recalculate history from current catalogue or legacy macros |
| Nutrition facts and uncertainty | B03 nutrient registry/calculation/snapshot contracts | Propagate known/missing/estimated/range states | Coalesce missing to zero or exact-format ranges |
| Recipes, thalis and local candidates | B03 recipe/thali/catalogue repositories | Supply candidate identities and calculation inputs | Create a second calculator or interpret meal templates as recipes |
| Dietary safety | B03 `NutritionConstraintEvaluator` and repositories | Filter and explain four-state outcomes | Infer allergies, downgrade evidence or call “no known conflict” safe |
| Estimate provenance | B03 estimate parser/repository/privacy boundary | Carry source, model/rule, bounds and correction lineage | Store prompts/images or make an estimate authoritative |
| Existing training targets | B02 `LoadTargetRecommendationService` | Use as evidence/input to a recovery-aware overlay | Replace B02 rule v1 or create a global target service |

## Binding principles

- Offline-first: logging, history, target display, deterministic guidance,
  daily/weekly reads and feedback work without network access.
- User control: adaptive coaching is explicitly opt-in; target and guidance
  overrides are visible, reversible and historically recorded.
- Explainability: every surfaced recommendation exposes evidence, rule/model
  version, confidence, missing inputs, alternatives and uncertainty.
- Unknown is not zero; an estimate is not a verified fact; a range is not an
  exact value.
- Safety-sensitive conflict states fail closed. A user may record an explicit
  personal decision where B03 permits it, but B04 never claims that decision is
  safe.
- Local civil dates plus validated IANA timezone semantics are stored with
  every historical target, readiness snapshot and recommendation period.
- Screens render read models and commands; they do not calculate, filter,
  persist Drift rows or call an AI provider directly.
- Durable history is append-only or superseding. Recomputable daily/weekly
  projections and caches are not backup entities.

## Batch exit criteria

- Goal changes and user overrides produce versioned, effective-dated records.
- `B04-D04` age, consent, target acceptance, evidence, dietary, wording,
  offline/AI, N8 and `B04-D04-ENABLED-1` decisions are explicitly recorded.
  The Product Owner has authorized the qualitative packet and selected
  `ENABLED-1` as the proposed first enabled calorie policy. Independent fresh
  Sol approval, branch merge and explicit release/feature-policy selection
  remain required before activation; `HOLD-1` remains selectable and
  readiness numerical behavior remains held.
- Readiness exposes completeness and never adapts from missing/permission-error
  inputs as if they were zero.
- Enabled adaptive target proposals are deterministic, bounded, opt-in and
  explainable only when `ENABLED-1` is explicitly selected after all activation
  gates pass. Under `HOLD-1`, adaptive results are unavailable and all
  adaptive deltas are exactly zero. Under `READINESS-HOLD-1`, readiness has
  exactly zero numerical calorie/training effect.
- One engine produces daily, weekly and meal-opportunity recommendations with
  evidence, confidence, alternatives and unavailable states.
- B03 food/recipe/thali candidates retain quantity, nutrient, estimate and
  constraint provenance through “what can I eat now?”.
- Confirmed strict conflicts are hard-blocked. Possible, unknown,
  insufficient, missing, possible-cross-contact and structurally invalid
  evidence return `unavailable` for safety-sensitive recommendation output.
  Warning plus acknowledgement is limited to a separately defined low-risk
  logging action and never changes safety or recommendation output.
- Recommendation snapshots and feedback survive backup/restore and remain
  reproducible after goal, catalogue, health or recipe changes.
- B03 and B02 historical authorities remain intact; no duplicate calculator,
  safety evaluator, schedule engine or weekly coaching authority is introduced.
- Schema/backup migration, rollback, idempotency, offline, privacy,
  accessibility, Android and iOS verification pass.
- Final Sol High review and Terra High production-integration review pass.

## Non-goals

- This branch is documentation-only and no B04-01 task has started. This
  packet does not authorize B04-01 or any application implementation. Later
  work remains subject to the accepted DAG and its own review gates.
  `HOLD-1` does not block foundational contracts, schema v18, Backup v9,
  persistence, unavailable states, goals, lineage, feedback, descriptive
  behavior or user-set targets; it continues to be the non-enabled policy and
  blocks runtime adaptive exposure until `ENABLED-1` is activated.
- No B04 implementation may start until the dependency gate in
  `VERIFICATION.md` is green.
