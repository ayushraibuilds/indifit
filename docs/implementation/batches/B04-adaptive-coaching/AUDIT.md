# B04 — Targeted Repository Audit

Audit mode: read-only, planning only
Checkout: `batch/b04-planning` at `12ce1b05c7626d3fb37eedc37fc0dd4d7af94d8a`
Future-input ref: `batch/b03-nutrition-foundation` at `d85e8a16566735e7f6b7fe15cd2a97edb5677178`

Remediation update: the B04 gate is evaluated from concrete integration
baseline `741aa18972ebc1b61cd65c0bf12b442b10b50890`, whose implementation
parent contains accepted B03. The planning-base observations below are retained
as audit history and are not the current implementation parent.

## Method and scope

The audit began with the canonical roadmap and accepted B01–B03 planning and
verification documents. Repository inspection was limited to the smallest
file/symbol set needed to answer the B04 questions. Three read-only workstreams
were used:

| Workstream | Target | Output |
|---|---|---|
| Audit A — goals, targets and historical context | Profile/goal storage, TDEE, body metrics, goal changes, effective dates and timezone | Existing authorities, missing versioning and historical risks |
| Audit B — recommendation inputs and orchestration | B03 nutrition reads, B01/B02 schedule/activity/health, food candidates, reports and context | Available inputs, missing inputs, duplicate logic and service boundaries |
| Audit C — safety, privacy, UI and AI | B03 constraints/estimates, AI adapters/prompts, privacy gates, screens and tests | Safety/privacy constraints, AI boundary, UI risks and review gates |

No application code, schema, asset or feature branch was changed by the audit.

## Dependency evidence relevant to the audit

| Dependency | Evidence | Current disposition |
|---|---|---|
| B01 | `docs/implementation/batches/B01-training-programs/VERIFICATION.md`: integration baseline `baff96e`, final Sol/platform verification passed; `main` contains the accepted lineage. | Accepted and integrated; no B01 blocker. |
| B02 | `docs/implementation/batches/B02-workout-execution/VERIFICATION.md`: final verification passed, Sol gate released at `330bda5`; `main` is merge `12ce1b0` and schema/backup are v16/v7. | Accepted and integrated; no B02 blocker. |
| B03 | Accepted commit `d85e8a1`, timezone correction `78a43f9` and merge commit `f976542` are ancestors of the concrete B04 integration baseline; schema/backup v17/v8 are present in the implementation parent. | B03 is integrated into the B04 implementation parent; no unresolved B03 release blocker is absorbed by B04. |

The historical B03 r2 section records a blocked verdict, but the r3 section is
the current disposition and supersedes it. B03 follow-ups remain explicitly
out of B04 ownership: 592 catalogue rows remain `manualReview`/unresolved;
disposable CI build-runner/format idempotence may be rerun; and the final r3
review used product-owner attestation rather than a new Sol/Terra instance.

## Existing authorities and targeted findings

| File / symbol | Current behavior | B04 relevance | Disposition | Risk | Planning consequence |
|---|---|---|---|---|---|
| `lib/data/database/tables/user_tables.dart` — `UserProfiles` | One mutable profile row stores age, height, weight, sex, activity, goal, calorie and macro goals; no user ID, effective dates or target history. | Current goal/profile source. | Adapt behind a B04 goal repository. | Historical target reconstruction is impossible after overwrite. | Add versioned goal records; retain the row as a compatibility mirror only. |
| `lib/core/di/user_profile_provider.dart` — `UserProfileNotifier` | Loads Drift and SharedPreferences with DB-first fallback; writes both in `loadProfile`, `updateGoals`, `updateProfile`, `updateWeight`, `updateHeight`. | Main app-facing profile state. | Reuse as compatibility surface; isolate persistence. | Multiple authorities can diverge on restore or partial failure. | Route B04 writes through one durable owner and define mirror compensation. |
| `lib/core/utils/tdee_calculator.dart` — `TdeeCalculator` | Pure Mifflin–St Jeor/TDEE/macro calculation with fixed `-500/+300` goal deltas and a 1,200 kcal floor. | Seed for deterministic target calculation. | Adapt behind a versioned target engine. | No provenance, bounds, trend evidence or approved safety policy. | Reuse arithmetic only after Sol/product policy approval; remove UI authority. |
| `lib/features/onboarding/onboarding_screen.dart` — `_completeOnboarding`; `lib/features/profile/profile_screen.dart` — `_handleSave`; `lib/features/settings/nutrition_goals_sub_screen.dart` — `_calculateRecommendation`, `_saveGoals` | Three UI paths map string enums, calculate targets and persist goals; profile changes optionally recalculate. Goals screen falls back to 74.5 kg/170 cm/age 25 when missing. | Existing user journeys and override behavior. | Adapt to goal proposals/commands; retire local math and fallback facts. | Duplicated policy and false personalization when metrics are missing. | Terra integration must consume a goal read model and explicit missing states. |
| `lib/data/database/tables/workout_tables.dart` — `BodyMeasurements`; `lib/data/repositories/workout_repository.dart` — `logBodyMeasurement`, `getBodyMeasurements` | Weight/waist/chest/arms history exists, but device-local dates, seven-day rate limiting and current-profile synchronization are not a B04 evidence contract. | Weight trend and body-metric input. | Reuse through a typed read adapter; no second measurement table. | Sparse/travel data can be misread as a reliable trend. | Add source/quality/timezone handling at the adapter and test missingness. |
| `lib/core/services/local_schedule_date_service.dart` — `LocalScheduleDateService` | Validates IANA zones and performs DST-safe civil-date operations. | Daily/weekly boundaries. | Reuse. | No nutrition/home-timezone ownership exists today. | B04 goal/recommendation records must store the resolved zone/date context. |
| B03 `lib/data/repositories/nutrition_read_model_repository.dart` — `NutritionReadModelRepository` | Unifies immutable canonical snapshots and legacy records; `dailyTotals` preserves correction lineage, source counts and issues. | Required nutrition totals/history authority. | Reuse. | Dashboard/progress still have direct legacy reads on the B04 base. | Integrate B04 only from this boundary after B03 merge; do not recalculate. |
| B03 `lib/data/repositories/nutrition_consumption_repository.dart` — `dailyTotals`, `listForLocalDate` | Reads active immutable snapshots with UTC/IANA/local-date context and source/result facts. | Historical daily evidence. | Reuse. | Crossing into legacy rows or current catalogue would change history. | Fixture cross-midnight, correction and range behavior before coaching. |
| B03 `nutrition_protein_distribution_repository.dart`, `nutrition_protein_distribution.dart` | Descriptive meal distribution with explicit groups/categories and measured/estimated/unknown leucine. | Optional evidence/context for coaching. | Reuse read-only. | B04 could accidentally turn descriptive data into physiology claims. | No thresholds, quality score or MPS outcome in B04. |
| B03 `lib/core/nutrition_constraints.dart` and `nutrition_constraint_repository.dart` | Typed constraints/evidence; evaluator outcomes are confirmed, possible, no-known and insufficient. | Safety filter for candidates and guidance. | Reuse as sole evaluator. | “No known conflict” can be misrendered as safe; cross-contact follow-up remains. | Add Sol-reviewed hard-block/unavailable fixtures; warning acknowledgement is limited to separately defined low-risk logging and cannot enter recommendations. |
| B03 `lib/core/nutrition_estimates.dart`, `nutrition_estimate_repository.dart` | Typed point/lower/upper facts, confidence, provider/model/rule provenance, correction lineage and unavailable offline state. | Uncertainty and estimate evidence. | Reuse/adapt. | Range-only or legacy point values can be treated as exact. | Propagate status/ranges into ranking and explanation; never use legacy adapter as authority. |
| Current `lib/data/database/tables/food_tables.dart` — `FoodLogs`; `lib/data/repositories/food_repository.dart` — `FoodRepository` | Legacy copied macros; fuzzy text search; 15-minute implicit meal grouping; device-local day reads; in-place update/delete. | Compatibility history only. | Isolate behind B03 legacy adapter. | Totals, grouping and correction lineage can diverge from canonical snapshots. | No new B04 decisions may read or write this path directly. |
| `lib/data/repositories/progress_statistics_repository.dart` — `getWeeklyMetrics`; `dashboard_controller.dart` — weekly adherence/action methods | Existing weekly/report/dashboard paths aggregate legacy logs and use current profile targets. | Current weekly surface. | Adapt to B03/B04 read models; retire duplicate coaching actions. | Editing today’s target can reinterpret past adherence. | One daily/weekly orchestration boundary with effective goal version. |
| B02 `lib/data/repositories/calendar_read_repository.dart` — `readSnapshot`; `calendar_repository.dart` | Provides occurrence status, effective local dates, IANA timezone, deload/travel and progression state; mutation remains in `CalendarRepository`. | Schedule evidence. | Reuse read-only. | Cross-domain coach could mutate or infer schedule state. | Read only; B04 training guidance is an overlay, not a schedule edit. |
| B02 `lib/data/repositories/b02_progress_read_repository.dart`, `b02_activity_session_repository.dart` | Provides typed activity history, performed work, partial completion, target evidence, source and provenance. | Load/activity context. | Reuse read-only. | Imported calories are provider estimates, not exact expenditure. | Carry source/completeness; do not feed unknown as zero. |
| B02 `lib/data/repositories/health_service.dart` — `fetchTodayHealthData`; `b02_health_activity_repository.dart` | Exposes transient current steps, active calories, sleep and connection/permission state; provider imports have provenance. | Raw health input. | Adapt through B04 observation repository. | Missing permission/error can be mistaken for zero; no historical readiness record. | Persist normalized observations/snapshots with unknown states and privacy minimization. |
| `lib/data/services/b02_load_target_recommendation_service.dart` — `LoadTargetRecommendationService` | Pure, versioned B02 load rule with evidence, confidence, rationale and `recoveryKnown`; it does not implement readiness. | Training recommendation precedent/input. | Isolate as B02 authority; compose, do not rewrite. | A “global coach” could duplicate or override B02 rule semantics. | B04 may add a readiness-aware overlay while preserving B02 v1 history. |
| `lib/data/repositories/meal_plan_service.dart`, `ai_meal_planner_screen.dart`, `backend/main.py` — meal-plan endpoint | Cloud meal planning plus hard-coded/offline point scaling and broad diet strings; no canonical constraint/range filtering. | Existing AI planner. | Isolate/retire as B04 authority. | Invented point nutrition and unfiltered outputs are unsafe. | “What can I eat now?” must use local B03 candidates and deterministic filtering. |
| `lib/data/repositories/weekly_report_service.dart`, `backend/main.py` — weekly report endpoint | Existing report narrative/AI path sends metrics to backend and is separate from durable recommendation evidence. | Weekly presentation predecessor. | Adapt only as a renderer/input adapter. | Duplicate recommendation logic and unnecessary health/nutrition disclosure. | B04 engine owns coaching action; report consumes it. |
| `lib/core/privacy/privacy_policy.dart`, `doc/privacy_policy.md`, B03 privacy services | Strict offline mode gates AI/photo/Open Food Facts; B03 rejects images/prompts from durable estimate evidence and cleans temporary files. | Network and data boundary. | Reuse and extend with B04 payload policy. | Existing AI/report endpoints and process-local backend cache need explicit review. | No raw health/food context to AI by default; no prompt/image/cache backup. |

## Available inputs

| Input | Available contract | B04 action |
|---|---|---|
| Daily nutrition | B03 immutable snapshots, totals, local date/timezone, completeness, bounds and lineage | Consume through `NutritionReadModelRepository`. |
| Weekly nutrition | B03 records can be grouped into an explicit seven-civil-day period; existing weekly metrics are legacy | Add a B04 period read model; do not reuse current-profile multiplication. |
| Food candidates | B03 canonical food/recipe/thali repositories and published versions | Use selected/local candidates only; no pantry inference. |
| Dietary safety | B03 constraints and four outcomes | Reuse; do not duplicate. |
| Schedule/activity | B01 calendar and B02 typed activity/history/read-target evidence | Read only; preserve owners. |
| Health | Current HealthService summaries and provider provenance | Normalize into durable B04 observations; missing remains unknown. |
| Body metrics | B01/B02 `BodyMeasurements` history | Adapt with typed completeness/timezone quality. |
| Current goals | `UserProfiles` plus SharedPreferences mirrors | Migrate through versioned B04 goal authority. |

## Missing inputs and contracts

- Goal versions, effective dates, target source, opt-in, override and
  historical target lineage.
- Adaptive target safety policy: minimum evidence, cadence, adjustment bounds,
  minimum-age/consent rule and professional-advice wording.
- Durable recovery observations, readiness snapshots and evidence links.
- A typed recommendation context separating target calculation, safety filter,
  candidate opportunity, ranking and presentation.
- Meal opportunity/current-food selection; B03 has searchable candidates but no
  pantry, availability, preparation-time or next-meal authority.
- Festival, fasting, eating-out and travel context semantics; these are the
  conditional N8 extension and are not silently inferred in B04.
- Recommendation confidence, explanation, feedback, dismissal, supersession
  and historical lineage.
- Redacted optional-AI provider contract with deterministic offline fallback.

## Duplicate or legacy authorities to avoid

| Duplicate | Resolution |
|---|---|
| TDEE calculation in onboarding/profile/goals screens | One versioned B04 target engine; screens issue commands. |
| Drift and SharedPreferences profile/goal values | B04 repository is authoritative; mirror only during compatibility transition. |
| Legacy `FoodLogs` totals and B03 snapshot totals | B03 read model is authoritative for new coaching; legacy is labelled compatibility. |
| Existing weekly report/AI action and B04 recommendation engine | B04 engine owns action/evidence; weekly report renders the result. |
| B02 load, rest and warm-up services and a proposed global coach | Preserve B02 owners; B04 reads/overlays only where the approved contract allows. |
| Meal-plan AI and local hard-coded templates and B04 “eat now” guidance | Existing planner remains legacy; B04 candidates are typed, filtered and evidence-bearing. |
| Screen-local constraint/range/AI wording | Reuse B03 evaluators/read models and central B04 explanation contracts. |

## Planning consequences

1. B04 implementation cannot begin from this branch until B03 v17/v8 is
   integrated into a named parent and the accepted B03 follow-ups remain
   separately tracked.
2. B04 requires new durable M18 records; schema v18 and Backup v9 are therefore
   planned. Daily/weekly projections and recomputable caches are not persisted.
3. The first implementation gate is a contract/fixture matrix, followed by the
   product-owner/Sol safety and target-policy gate.
4. AI is an optional presentation adapter after deterministic results are
   complete; it is not a dependency for offline B04 outcomes.
5. Festival/eating-out/fasting behavior stays outside the required DAG until
   the canonical N8 product decision is explicitly accepted.
