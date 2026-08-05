# B04 — Adaptive Coaching

Status: Planning gate only; implementation blocked pending the accepted B03 integration baseline, independent Sol High review, and the remaining `HOLD-1` numerical gates
Planning branch: `batch/b04-planning`
Planning base: `main` at `12ce1b05c7626d3fb37eedc37fc0dd4d7af94d8a`
Accepted B03 integration source (not yet a parent): `batch/b03-nutrition-foundation` at `d85e8a16566735e7f6b7fe15cd2a97edb5677178`
Accepted B03 schema/backup baseline: v17 / v8
Proposed B04 durable change: schema v18 / Backup v9
D04 packet branch: `b04/d04-safety-policy-gate`
D04 packet planning baseline: `9102092`
B04 integration baseline marker: `[B04-INTEGRATION-BASELINE]`
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
| B04-R05 | “What can I eat now?” uses only selected/local canonical food, recipe and thali candidates, remaining-target evidence and B03 safety/uncertainty contracts | E5; N10; B03 explicit deferral | No candidate is invented, unsafe candidates are blocked/warned, and unknown/range data remains visible. |
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
- Safety filtering through the B03 constraint evaluator, including uncertainty
  and confirmation states.
- Durable recommendation evidence, historical lineage and append-only feedback.
- Daily briefing and weekly review orchestration over explicit local-date
  periods.
- Optional, privacy-minimized AI wording adapter behind the existing policy gate.

## Explicit exclusions

- Medical diagnosis, treatment, injury rehabilitation, allergy-safety
  guarantees, or professional nutrition prescriptions.
- Numerical deficit/surplus policy, minimum-age policy or other medically
  sensitive constants until the product-owner/Sol policy gate records them.
- Adaptive target output while `B04-D04` is in `HOLD-1`; user-set targets,
  descriptive history and unavailable states remain in scope.
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
- Product-owner/Sol approval of target safety constants and adaptation policy.
- A Product Owner-authorized `B04-D04` qualitative decision packet and an
  independent Sol High verdict. Numerical trend, completeness, cadence,
  cooldown, deficit/surplus and adjustment values remain under `HOLD-1`;
  adaptive target exposure remains unavailable.
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
  offline/AI and N8 decisions are explicitly recorded and Product Owner-
  authorized; independent Sol review and the remaining `HOLD-1` numerical
  gates must close before adaptive exposure.
- Readiness exposes completeness and never adapts from missing/permission-error
  inputs as if they were zero.
- Adaptive target proposals are deterministic, bounded, opt-in and explainable.
- One engine produces daily, weekly and meal-opportunity recommendations with
  evidence, confidence, alternatives and unavailable states.
- B03 food/recipe/thali candidates retain quantity, nutrient, estimate and
  constraint provenance through “what can I eat now?”.
- Confirmed conflicts are blocked according to approved severity/strictness;
  possible/insufficient evidence requires warnings or confirmation.
- Recommendation snapshots and feedback survive backup/restore and remain
  reproducible after goal, catalogue, health or recipe changes.
- B03 and B02 historical authorities remain intact; no duplicate calculator,
  safety evaluator, schedule engine or weekly coaching authority is introduced.
- Schema/backup migration, rollback, idempotency, offline, privacy,
  accessibility, Android and iOS verification pass.
- Final Sol High review and Terra High production-integration review pass.

## Non-goals

- No B04 feature branch, schema migration or application implementation is
  authorized by this charter. This branch is documentation-only.
- No B04 implementation may start until the dependency gate in
  `VERIFICATION.md` is green.
