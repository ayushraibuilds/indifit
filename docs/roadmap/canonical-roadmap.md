# IndiFit Canonical Product and Engineering Roadmap

Status: Approved
Owner: Ayush
Architecture baseline: schema v14 / backup v5
Last reviewed commit: 056f959
Last reviewed date: 2026-07-29

This document is the canonical portfolio roadmap for IndiFit. Subsequent feature plans must preserve the domain boundaries, migration rules, privacy behavior and scheduling semantics defined here.

## 1. Executive Strategy

IndiFit should evolve into an offline-first, India-aware adaptive fitness coach rather than a collection of unrelated workout, nutrition and AI utilities.

The strongest differentiation is the combination of structured progression informed by actual training and recovery, Indian food quantities and regional nutrition, and explainable recommendations that work locally and disclose uncertainty.

The next major release must begin with shared domain foundations. Periodization, workout calendars, recipes, adaptive nutrition, readiness and dashboard recommendations should not be built directly on the current name-based routine records and scattered preference keys.

## Product Direction

- Product focus: strength-first adaptive fitness coach with deeply integrated Indian nutrition and recovery support. Nutrition is a major differentiator, but training progression remains the primary product loop.
- Supported platforms: Android and iOS only for the current roadmap. Web and desktop are explicitly out of scope for release planning and platform validation.
- Offline-first: user data remains device-owned and all core functionality works locally. Optional cloud backup or account sync may be introduced later only as encrypted, user-controlled functionality; no current architecture may assume cloud sync is permanently unavailable.

## 2. Current Architecture

- Flutter/Dart application using Riverpod providers and StateNotifier controllers in `lib/core/di` and feature modules.
- Drift schema v14 and migrations in `lib/data/database/app_database.dart`.
- Backup schema v5 in `lib/core/backup/backup_schema.dart`.
- GoRouter owns top-level routes in `lib/core/router/app_router.dart`; raw Navigator usage remains in several feature flows.
- Training currently separates routines, routine days, routine exercises, completed sessions, sets and one serialized active draft in `lib/data/database/tables/workout_tables.dart`.
- Food logging supports local search, Open Food Facts lookup, custom foods, meal templates, regional packs, AI estimates and grouped thali logs.
- Health integration reads steps, energy and sleep, imports walking/running workouts, writes workouts/weight and tracks provenance.
- Weekly reporting uses real seven-day metrics through `ProgressStatisticsRepository` and `WeeklyReportService`.
- Theme selection and light/dark theme objects exist, but feature screens still contain many fixed dark palette references.
- Latest verified baseline: `flutter analyze` passed; the Flutter suite passed; backend security tests passed with `12 tests, 15 subtests`.

## 3. Product Principles

1. Offline-first: logging, history, schedules, core recommendations and educational text work without a network connection.
2. User control: users can override prescriptions, targets, schedules and recommendations with reversible actions.
3. Explainability: every adaptive suggestion exposes evidence, confidence, missing inputs and alternatives.
4. Uncertainty: nutrition estimates and readiness scores never present uncertain inputs as precise facts.
5. Non-medical posture: recommendations remain general wellness guidance with conservative bounds and stop conditions.
6. Progressive disclosure: Today stays simple; advanced techniques and detailed nutrient evidence are available on demand.
7. Accessibility: support dynamic text, semantic labels, high contrast, large targets, reduced motion and non-color-only states.
8. Data portability: every user-owned record, preference and customization participates in backup/export.
9. Privacy: permissions are purpose-bound, uploads are explicit, telemetry is opt-in and secrets are never exported.
10. Lower-end performance: use indexed queries, bounded charts, lazy media and precomputed summaries.

## 4. Current Capability Matrix

Scores use `V/D/E/T/Q/S/F`: user value, differentiation, effort, technical risk, data-quality risk, privacy/safety risk and foundation value. Higher effort and risk scores are worse; the other scores are better.

### Workout

| ID | Feature | Status | Evidence and gap | V/D/E/T/Q/S/F |
|---|---|---|---|---|
| W1 | Periodized programs, progression blocks, deloads and calendars | Not supported | `WorkoutRoutines`, `RoutineDays` and `RoutineExercises` have no blocks, weeks, versions or progression rules in `lib/data/database/tables/workout_tables.dart`. | 5/5/5/5/3/3/5 |
| W2 | Automatic load/repetition targets using sets, RPE, sleep and recovery | Partially supported | `WorkoutPlayerController.prefillInputs` repeats the previous load or adds 2.5 kg after reaching the rep ceiling; RPE, sleep and recovery are ignored. | 5/5/5/5/4/4/4 |
| W3 | Superset, circuit, giant-set, tempo, paused, assisted and rest-pause sets | Partially supported | `WorkoutSets.setType` supports working, warmup, dropset, AMRAP and failure; there is no group, tempo, assistance or rest-pause model. | 4/4/4/4/2/3/4 |
| W4 | Exercise-specific warm-up calculator and ramping sets | Partially supported | `isWarmUp` and manual warm-up selection exist; no ramp calculation or equipment increment logic exists. | 4/3/3/3/2/3/3 |
| W5 | Cardio intervals, running, cycling, walking, yoga and mobility | Partially supported | Sets store duration, distance and incline; the player detects cardio through exercise-name substrings and Health imports walking/running only. | 4/3/5/4/3/3/4 |
| W6 | Muscle-volume heat map and weekly muscle sets | Not supported | Exercise muscles are comma-separated strings and progress charts overall volume only. | 4/4/3/3/4/2/3 |
| W7 | Gym-equipment profiles | Partially supported | `UserProfiles.equipmentAccess` is one string and routine generation accepts one equipment category; multiple named profiles and inventory are absent. | 4/3/3/2/2/1/4 |
| W8 | Exercise notes, cues, setup preferences and reminders | Partially supported | Seeded cues/mistakes and set notes exist; personal setup preferences and reminder records do not. | 3/3/3/2/2/2/3 |
| W9 | Workout calendar, reschedule, skip, repeat and travel-week mode | Blocked by existing technical debt | `RoutineDays.dayOfWeek` is a weekly template, not a scheduled occurrence with state, timezone or ancestry. | 5/4/5/5/2/2/5 |
| W10 | Custom and intensity-based rest times | Partially supported | `_getRecommendedRestSeconds` uses exercise-name rules and opens `RestTimerBottomSheet`; no prescription-level rest configuration exists. | 4/2/3/2/2/2/3 |

### Nutrition

| ID | Feature | Status | Evidence and gap | V/D/E/T/Q/S/F |
|---|---|---|---|---|
| N1 | Recipe builder, scaling and cooked/raw conversion | Blocked by existing technical debt | Meal templates snapshot nutrients but do not model ingredients, yields or cooking transformations. | 5/5/5/4/5/4/5 |
| N2 | Visual thali builder | Partially supported | `ThaliBuilderScreen` composes items with running macros and templates, but has no spatial or plate model. | 4/5/3/2/3/2/2 |
| N3 | Indian household measures | Partially supported | `HouseholdMeasure` provides fixed global gram equivalents; food-specific density and user vessel calibration are absent. | 5/5/4/3/5/3/5 |
| N4 | Confidence ranges for photo estimates | Not supported | AI meal responses and `AiMealLoggerScreen` persist only point estimates. | 4/5/4/4/5/4/3 |
| N5 | Expanded nutrient tracking | Partially supported | Food items include fibre, while logs primarily persist calories and macros; no normalized nutrient model exists. | 4/3/5/4/5/4/4 |
| N6 | Protein distribution and leucine-quality guidance | Not supported | No protein-quality, meal-distribution or leucine model exists. | 4/5/4/4/5/4/3 |
| N7 | Dietary, allergy, religious and regional filters | Partially supported | One diet preference and regional packs exist; structured exclusions, severity and observance rules do not. | 5/5/5/4/5/5/5 |
| N8 | Festival, travel, eating-out and fasting modes | Not supported | No mode, target-policy or observance model exists. | 4/5/4/3/4/4/3 |
| N9 | Adaptive calorie targets | Partially supported | TDEE and editable targets exist, but targets do not learn from weight trend or adherence. | 5/5/5/5/5/5/4 |
| N10 | “What can I eat now?” suggestions | Not supported | No remaining-target, constraint-aware meal suggestion service exists. | 5/5/4/4/5/4/3 |

### Progress and coaching

| ID | Feature | Status | Evidence and gap | V/D/E/T/Q/S/F |
|---|---|---|---|---|
| P1 | Daily briefing | Not supported as a unified surface | Dashboard components are independent; no briefing contract selects one prioritized plan for the day. | 5/4/4/4/4/3/4 |
| P2 | Weekly review | Already supported | `WeeklyReportScreen`, `WeeklyReportService` and `WeeklyMetrics` use real seven-day data with local fallback. Durable evidence references remain absent. | 4/3/2/2/3/2/3 |
| P3 | Strength standards | Not supported | Epley 1RM exists for PR calculation but no standards dataset or comparison service exists. | 4/3/3/3/4/3/2 |
| P4 | PR timeline | Partially supported | PR flags and exercise history exist; there is no unified PR-event timeline. | 4/3/3/2/2/1/2 |
| P5 | Consistency calendar | Already supported | Progress contains a 12-week activity heat map and session-date queries. | 4/2/2/1/2/1/2 |
| P6 | Muscle-balance analysis | Not supported | No weighted muscle contribution or balance analysis exists. | 4/4/4/4/5/3/3 |
| P7 | Recovery/readiness score | Not supported | Health reads today’s sleep but stores no recovery observations or readiness snapshots. | 5/5/5/5/5/5/5 |
| P8 | Body measurements and trends | Partially supported | Weight, waist, chest and arms are stored; the progress UI principally charts weight. | 4/2/3/2/3/3/3 |
| P9 | Explainable recommendations | Partially supported | Weekly reports provide narrative and an action, but there is no durable recommendation or evidence entity. | 5/5/5/5/4/5/5 |

### UI and design

| ID | Feature | Status | Evidence and gap | V/D/E/T/Q/S/F |
|---|---|---|---|---|
| U1 | Today-page redesign | Partially supported | `DashboardScreen` combines date, workout, meals, hydration, activity and weight, but has fixed ordering and no module contract. | 5/3/4/3/2/1/4 |
| U2 | Semantic light/dark design system | Partially supported | Theme selection works, but 58 files still use fixed dark `AppColors` values. | 5/2/5/4/1/1/5 |
| U3 | Restrained surface rounding | Not supported consistently | Global cards use 16 px radius and screens use multiple larger radii. | 3/2/2/1/1/1/1 |
| U4 | Meal icons and accents | Partially supported | Material icons and colors exist, but no food-category semantic accent system exists. | 3/3/2/1/1/1/2 |
| U5 | Dashboard customization | Not supported | Dashboard widget order is fixed and no module preferences are persisted. | 4/4/4/3/1/1/3 |
| U6 | Typography, spacing and icon improvements | Partially supported | `AppTheme` provides a base theme, but many local text sizes, colors and spacing choices remain. | 4/2/4/3/1/1/3 |
| U7 | Compact-screen support | Requires runtime or product validation | Screens scroll, but there is no systematic breakpoint or compact-device test matrix. | 4/2/3/3/1/1/3 |
| U8 | Swipe actions | Partially supported | Food-log deletion uses `Dismissible`; other suitable lists lack consistent swipe behavior and undo. | 3/2/3/2/1/1/2 |

### Education and interactivity

| ID | Feature | Status | Evidence and gap | V/D/E/T/Q/S/F |
|---|---|---|---|---|
| E1 | Offline exercise animations | Not supported | Exercise details link to YouTube; no packaged animation runtime or media manifest exists. | 4/4/5/4/4/2/3 |
| E2 | Interactive muscle diagrams | Not supported | No normalized interactive muscle map exists. | 4/5/5/4/4/2/4 |
| E3 | Form checklists and contextual cues | Partially supported | Seeded cues/mistakes exist, while the player also contains hardcoded name-based cues. | 5/4/3/2/3/3/4 |
| E4 | Mini lessons | Not supported | No versioned lesson or completion model exists. | 3/4/4/3/4/3/2 |
| E5 | Adaptive onboarding | Partially supported | Multi-step profile, TDEE and routine setup exists, but no reusable branching or recommendation-state model exists. | 5/4/4/4/3/3/4 |
| E6 | Playlist launcher | Not supported | `url_launcher` exists, but no playlist-provider workflow exists. | 3/2/1/1/1/1/1 |

## 5. Canonical Domain Architecture

The canonical flow is:

`Profile, constraints and equipment -> planners -> scheduled occurrences -> immutable execution records -> analytics -> one recommendation engine -> daily briefing and weekly review -> configurable dashboard`

Health observations and versioned educational content feed the same downstream analytics and coaching contracts.

### Shared models and ownership

- `Exercise`: stable ID, aliases, movement pattern, weighted muscles, equipment requirements, cues, media and content versions. Owned by the exercise catalog.
- `Muscle` and `ExerciseMuscle`: normalized taxonomy with contribution weights and optional primary/secondary roles.
- `EquipmentProfile` and `EquipmentItem`: named profiles, available items, load increments, unit system and travel overrides.
- `Program`, `ProgramVersion`, `ProgramBlock`, `ProgramWeek`, `SessionTemplate` and `ExercisePrescription`: versioned planning objects.
- `ScheduledSessionOccurrence`: local date/time, timezone, program ordinal, status, travel context and reschedule ancestry.
- `ActivitySession`: immutable execution record shared by strength, cardio and mobility modalities.
- `ExerciseGroup` and `SetPrescription`: ordered group membership, technique, tempo, assistance, target reps/load and rest.
- `PerformedExercise` and `PerformedSet`: actual execution, partial completion, RPE, notes and provenance to the frozen prescription.
- `Quantity`, `UnitDefinition` and `FoodUnitConversion`: canonical storage in grams, millilitres or count with explicit display conversions.
- `Food`, `NutrientValue`, `Recipe`, `RecipeIngredient` and `FoodTransformation`: ingredient graph, raw/cooked state, yield and nutrient basis.
- `DietaryConstraint`: diet, allergy, religious observance, dislike and regional constraint with severity and effective dates.
- `RecoveryObservation` and `ReadinessSnapshot`: sourced input, missingness, confidence and calculation version.
- `Recommendation`, `RecommendationEvidence` and `RecommendationFeedback`: one explainable recommendation contract for training and nutrition.
- `DashboardModule` and `DashboardModulePreference`: stable IDs, order, visibility, size and typed configuration.
- `EducationContent`, `ExerciseChecklist`, `MediaAsset` and `ContentProgress`: versioned text, cues, lessons and offline media state.

Riverpod should expose one repository/coordinator per bounded context. Derived providers may compose read models, but feature screens must not implement their own progression, recommendation, units or scheduling engines.

## 6. Dependency Graph

Foundation codes:

- `F1`: canonical IDs, units, settings and ownership.
- `F2`: training plans, schedules and execution records.
- `F3`: nutrition graph, quantities and constraints.
- `F4`: recovery, analytics and recommendation evidence.
- `F5`: semantic design system and navigation contracts.
- `F6`: versioned education and media.

| Feature | Hard dependencies | Soft dependencies | Unlocks | Must not precede | Migration/platform/data gate |
|---|---|---|---|---|---|
| W1 | F1, F2 | F4 | W2, W9, P6 | None | M15/M16; stable exercise IDs. |
| W2 | W1, F4 | P7 | adaptive progression | F4 confidence contract | M16; calibrated prior-set data. |
| W3 | F2 | W6 | accurate execution analytics | volume rules | M16; no name-based technique logic. |
| W4 | F1, F2 | W2 | safer starts | load prescription | equipment increments. |
| W5 | F2 | Health | modality analytics | unified ActivitySession | native Health validation. |
| W6 | F1, W3 | E2 | P6 | muscle taxonomy | muscle mapping audit. |
| W7 | F1 | W9 | W1, W4 | calendar semantics | equipment migration. |
| W8 | F1 | F6 | contextual coaching | catalog ownership | setup/reminder tables. |
| W9 | W1, W7, F2 | F4 | P1, adherence | direct calendar UI | occurrence state machine and timezone tests. |
| W10 | F2 | W2/W3 | better execution | prescription model | rest fields in M16. |
| N1 | F1, F3 | N3 | N2, N5, N10 | adaptive calories | recipe/transformation migration. |
| N2 | F3 | F5 | better logging | quantity model | visual layout validation. |
| N3 | F1, F3 | N1 | N2, N4 | global fixed conversions | food-specific conversion data. |
| N4 | F3 | privacy | safer AI logging | point-only estimates | backend and backup schema. |
| N5 | F3 | N1 | N6, N9 | nutrient UI | dataset completeness audit. |
| N6 | N5, F4 | N7 | coaching detail | unsupported nutrient claims | evidence and non-medical review. |
| N7 | F3 | regional packs | N8, N10 | free-form diet strings | constraint severity model. |
| N8 | N7, F3 | W7/W9 | travel/festival journeys | hard-coded mode rules | product-owner decisions. |
| N9 | F4, N5, P8 | P7 | adaptive coaching | incomplete evidence | safety bounds and trend windows. |
| N10 | F3, N7 | N1/N9 | P1 | untrusted nutrient inputs | remaining-target read model. |
| P1 | F2, F4, F5 | N10 | Today redesign | independent dashboard heuristics | briefing contract. |
| P2 | F4 | analytics | long-term coaching | duplicate report logic | evidence references. |
| P3 | F1, F4 | P4 | standards coaching | unlicensed dataset | source validation. |
| P4 | F1, F2 | P3 | PR motivation | derived-only UI | event backfill. |
| P5 | F2 | P2 | adherence | planned-vs-completed ambiguity | occurrence semantics. |
| P6 | W6, W3, F4 | E2 | balance coaching | CSV-based counting | weighted muscle data. |
| P7 | F4, Health | P8 | W2, P1, N9 | scoring with zeros | native health validation. |
| P8 | F1 | Health | P7, N9 | trend claims on sparse data | measurement completeness. |
| P9 | F4 | P2 | all adaptive features | second recommendation engine | evidence and feedback schema. |
| U1 | F5, P1 | all analytics | primary daily journey | fixed dashboard assumptions | usability validation. |
| U2 | F5 | none | all UI work | more feature screens | semantic-token scan and visual tests. |
| U3 | F5 | U2 | visual consistency | local radius additions | design approval. |
| U4 | F5, F3 | N2 | nutrition comprehension | taxonomy duplication | category token map. |
| U5 | F5 | P1 | dashboard personalization | unstable module IDs | M19 and backup. |
| U6 | F5 | accessibility | all screens | screen-local typography | token migration. |
| U7 | F5 | accessibility | release quality | desktop-only assumptions | device screenshot matrix. |
| U8 | F5 | none | faster list workflows | destructive action without undo | interaction tests. |
| E1 | F6, F1 | E3 | offline instruction | unlicensed media | media-pack strategy. |
| E2 | F1, F6 | W6/P6 | anatomy education | duplicate muscle taxonomy | diagram asset validation. |
| E3 | F1, F6 | W8 | safer execution | hardcoded cue duplication | catalog cue ownership. |
| E4 | F6 | P1 | retention and education | content without versioning | editorial workflow. |
| E5 | F1, F5 | F4 | higher-quality setup | behavior-based adaptation without evidence | onboarding state migration. |
| E6 | F5 | F6 | optional engagement | core release | provider URL validation. |

## 7. Epic Map

### E0 - Domain Foundations

Purpose: canonical IDs, units, settings ownership, migration and backup compatibility. Includes F1 and excludes net-new user features. Main journey is invisible migration. Affects Drift, repositories, backup and Riverpod. Highest risk is data loss. MVP is a v14 upgrade with equivalent behavior; later remove compatibility mirrors.

### E1 - Program and Calendar

Includes programs, blocks, weeks, session templates, occurrence scheduling, reschedule, skip, repeat and travel mode. Excludes adaptive targets. Journey: choose program, view calendar, adjust week and start occurrence. Depends on E0. MVP is a manual periodized program with a reliable calendar.

### E2 - Execution Expansion

Includes typed strength/cardio/mobility sessions, groups, techniques, warm-ups, rest and equipment. Excludes readiness adaptation. Journey: prepare, execute, partially or fully complete, review. Depends on E0/E1. Highest risk is history compatibility and volume definitions.

### E3 - Nutrition Foundation

Includes quantities, recipes, household conversions, nutrients, constraints, thali and estimate confidence. Excludes adaptive calorie changes. Journey: build or estimate, inspect uncertainty, adjust and log. Depends on E0. Highest risk is conversion quality and allergy safety.

### E4 - Progress Analytics

Includes PR events, standards, muscle volume/balance, measurements and planned-versus-completed consistency. Excludes prescriptive coaching. Depends on E1-E3. Metrics must be reproducible from canonical records.

### E5 - Recovery and Coaching

Includes recovery inputs, readiness, one evidence-backed recommendation engine, daily briefing, adaptive load/calorie targets and “what can I eat now?” Excludes medical advice. Depends on E1-E4 and validated health inputs. This is the highest-risk epic.

### E6 - Today and Visual System

Includes semantic theme migration, restrained surfaces, responsive layout, dashboard modules, typography, icons and swipe actions. Excludes domain algorithms. Depends on E0 contracts and can run alongside E1.

### E7 - Education and Media

Includes form checklists, muscle diagrams, lessons, offline media packs, onboarding adaptation and playlist launcher. Depends on exercise taxonomy, design system and recommendation triggers. Highest risks are licensing and bundle size.

### E8 - Platform and Release Assurance

Includes HealthKit/Health Connect validation, privacy disclosures, migrations, backup, performance, accessibility and release gates. It spans all epics and does not introduce a separate product domain.

## 8. Cross-Feature Decisions

1. Program templates are versioned. Activated versions are immutable; editing creates a new version.
2. Scheduled occurrences are mutable until started. Starting creates an immutable execution snapshot.
3. Rescheduling changes occurrence date, not program ordinal. Progression advances on completion or explicit skip-and-advance.
4. Partial workouts use `partial` status, retain performed work and store a reason; adherence reports partial contribution separately.
5. Warm-ups are excluded from working-set volume. Drop/rest-pause clusters retain actual work and a separate effective-set metric.
6. Cardio, strength and mobility share `ActivitySession`; modality details remain separate.
7. Cooked/raw conversions are explicit food transformations with yield factors, never global multipliers.
8. Household units use food-specific grams/density; users may calibrate bowls and cups.
9. AI estimates retain point, lower/upper bounds, confidence, source, model version and user edits. Accepted logs freeze final values.
10. Missing recovery input is unknown, not zero. Scores expose completeness and suppress adaptation below a confidence threshold.
11. Recommendations store evidence references and rule/model versions; the UI shows why, alternatives and missing evidence.
12. Core text and cues are bundled. Heavier animations use optional verified packs with storage limits and manifests.
13. Dashboard customization uses stable module IDs and typed settings so migrations preserve order and visibility.
14. Scheduling uses local date plus IANA timezone semantics; UTC timestamps alone are insufficient for travel calendars.

## 9. Migration Strategy

### M15 - Identity, taxonomy and settings

Add stable UUIDs, `Muscles`, `ExerciseMuscles`, `EquipmentItems`, `EquipmentProfiles`, `EquipmentProfileItems`, typed settings and user constraints. Add nullable `exerciseId` to routine and set records. Backfill by normalized names and retain unresolved legacy names.

### M16 - Training plan and execution

Add programs, versions, blocks, weeks, templates, prescriptions, scheduled occurrences, occurrence events, performed exercises and modality detail tables. Classify old sessions as strength or imported walking/running. Preserve existing routines as one-block legacy programs.

### M17 - Nutrition graph

Add nutrients, food-nutrient values, unit definitions, food-specific conversions, recipes, ingredients, transformations and estimate provenance. Keep existing macro columns as compatibility columns until all reads migrate.

### M18 - Recovery and recommendations

Add recovery observations, readiness snapshots, recommendations, evidence links and feedback. Do not backfill readiness scores unless input completeness is sufficient.

### M19 - Presentation and content

Add dashboard module preferences, exercise setup preferences, educational progress and downloaded-media manifests.

Required indexes include scheduled date/status, session type/date, set session/exercise, muscle mappings, recipe ingredients, food nutrients, recommendation status/expiry and health provider/external IDs.

Every migration must be transactional, tested from representative v5-v14 fixtures and paired with a backup-schema increment. Backups v3-v5 remain importable; exports after M15 become v6+. Downgrading after M16 cannot safely preserve new program/calendar semantics and must be documented as unsupported.

## 10. Ordered Planning Backlog and Model Routing

### Task 1 - Foundation ADR and migration plan

Goal: define canonical IDs, units, settings ownership, compatibility/backfill, backup v6 and repository boundaries. Context: schema v14, backup v5, SharedPreferences usage and existing audit work. Scope: Drift, backup, core providers and repositories. Output: ADR, migration matrix, repository ownership and acceptance tests. Suitable model: GPT-5.6 Sol High. Depends on none.

### Task 2 - Exercise data audit

Goal: audit `assets/data/exercises.json` and seeding. Context: duplicate exercise variants, CSV muscle labels and hardcoded cues. Scope: exercise assets and seed logic only. Output: alias groups, taxonomy, mapping fixtures and unresolved-data report. Suitable model: Gemini Flash. Depends on Task 1 naming decisions.

### Task 3 - Semantic design-system plan

Goal: migrate the remaining 58 fixed dark-token references. Context: `AppTheme`, `AppColorsExtension`, compact-screen requirements and current screens. Scope: theme, widgets and visual test strategy. Output: token taxonomy, migration batches, responsive rules, radii and golden matrix. Suitable model: GPT-5.6 Terra High. Depends on Task 1 naming conventions.

### Task 4 - Program and scheduling architecture

Goal: define versioned programs and scheduled occurrences. Context: current routines, drafts, GoRouter flows and notifications. Scope: M16 design, state transitions, progression, travel and timezone semantics. Output: domain ADR, schema plan, user journeys and tests. Suitable model: GPT-5.6 Sol High. Depends on Tasks 1-2.

### Task 5 - Execution modality plan

Goal: unify strength, cardio and mobility execution. Context: current sets, RPE, warm-up, cardio fields, rest timer and history. Scope: advanced groups, technique, warm-up, rest, partial completion and volume rules. Output: execution contract and migration/test plan. Suitable model: GPT-5.6 Terra High with Sol validation for algorithms and migration. Depends on Task 4.

### Task 6 - Nutrition domain plan

Goal: define quantities, conversions, recipes, nutrients, constraints, thali and uncertainty. Context: food tables, household measures, AI logger, regional packs and privacy policy. Scope: M17 and service boundaries. Output: data model, conversion rules, safety policy and tests. Suitable model: GPT-5.6 Sol High. Depends on Task 1.

### Task 7 - Progress analytics plan

Goal: define PR events, standards, volume, balance, measurements and adherence. Context: current report repository, workout history and body measurements. Scope: derived read models and reproducibility tests. Output: metrics definitions and fixtures. Suitable model: GPT-5.6 Terra High. Depends on Tasks 2, 4, 5 and 6.

### Task 8 - Recovery and coaching plan

Goal: define observations, readiness confidence, evidence graph, adaptive loads/calories and feedback. Context: Health service, privacy controls, report fallback and missing-data behavior. Scope: M18 and one recommendation engine. Output: safety constraints, explanation contract and validation plan. Suitable model: GPT-5.6 Sol High. Depends on Tasks 4-7.

### Task 9 - Education/media plan

Goal: define lessons, checklists, diagrams, offline media packs and onboarding triggers. Context: exercise cues, YouTube links, assets, `url_launcher` and app-size limits. Scope: F6 and content progress. Output: content schema, licensing assumptions and package strategy. Suitable model: GPT-5.6 Terra High. Depends on Tasks 2-3.

### Task 10 - Final release validation plan

Goal: define migration, privacy, native-platform, performance, accessibility and rollback gates. Context: all previous ADRs and current test suite. Scope: CI/release validation only. Output: release checklist and failure thresholds. Suitable model: GPT-5.6 Sol High. Depends on Tasks 1-9.

Gemini Flash should implement bounded CRUD, generated Drift companions, seed-data corrections and deterministic tests. Terra High should implement medium-blast-radius screens and services after contracts are frozen. Sol High owns migrations, adaptive algorithms, privacy/security decisions and final cross-domain review.

## 11. Delivery Roadmap

### Phase 0 - Prerequisite remediation

Exit criteria: correct the meal-photo disclosure that currently says processing is local although the image is uploaded; consolidate preference ownership; define typed failure/fallback behavior; add native platform test harnesses.

### Phase 1 - Architectural foundations

Exit criteria: M15 and backup v6 pass upgrades from fixtures; no new name-based relationships; one units service and one settings owner exist.

### Phase 2 - Core workout expansion

Exit criteria: M16 is complete; manual periodized programs, occurrence calendar, travel/reschedule/skip, partial completion and typed modalities work offline.

### Phase 3 - Nutrition expansion

Exit criteria: M17 is complete; recipes, food-specific units, constraints, thali and estimate confidence round-trip through backup.

### Phase 4 - Analytics

Exit criteria: PR events, consistency, muscle volume/balance and measurement trends are reproducible from canonical records.

### Phase 5 - Adaptive coaching

Exit criteria: M18 is complete; readiness exposes completeness; recommendations show evidence; adaptation respects safety bounds and user overrides.

### Phase 6 - Design-system migration

Exit criteria: feature screens contain no fixed dark semantic colors; compact and large-text golden tests pass; dashboard modules persist through backup.

### Phase 7 - Education and media

Exit criteria: cues/checklists work offline; optional media packs obey size/storage budgets; content licensing is documented.

### Phase 8 - Stabilization and release

Exit criteria: migration fixtures, backup restore, native health tests, accessibility, privacy, performance and release builds pass on every supported platform.

## 12. Major Risks

- Exercise relationships rely on names and comma-separated muscle strings.
- Profile, reminders, streaks, health settings and weekly actions are split between Drift and SharedPreferences.
- Current photo-permission copy claims local processing while the implementation uploads the image to the backend.
- The mobile API key remains extractable from an application binary; server quotas and abuse controls remain essential.
- Backend rate limiting is process-local.
- Health APIs differ across real iOS and Android devices and are not adequately validated by current mocks.
- Adaptive calories, readiness and allergy-related suggestions carry the highest safety and data-quality risk.
- Current tests have strong unit coverage but limited golden, accessibility, performance, migration-chain and real-platform integration coverage.

## 13. Product-Owner Decisions Required

Resolved direction: IndiFit is strength-first with deeply integrated Indian nutrition and recovery support; Android and iOS are the supported platforms; core data remains device-owned and offline-first, while future cloud backup/account sync must be optional, encrypted and user-controlled.

1. Should skipped sessions advance the program by default, or require an explicit choice?
2. Are adaptive calorie targets opt-in, and what minimum age, trend duration and adjustment bounds apply?
3. Which dietary and religious observances are first-class in the MVP?
4. Should travel mode preserve program order, reduce volume or generate substitute weeks?
5. Will animations and standards datasets be licensed, commissioned or internally produced?
6. Are optional media packs free, premium or simply user-downloaded?

## 14. Exact Prompts to Run Next

### Foundation architecture

```text
Create the implementation-ready ADR and migration plan for IndiFit Foundation M15. Use docs/roadmap/canonical-product-roadmap.md as binding context. Inspect schema v14, backup schema v5, SharedPreferences usage, Riverpod providers and name-based exercise relationships. Define canonical identifiers, unit types, settings ownership, exercise/muscle/equipment normalization, v14-to-v15 backfills, backup v6 compatibility, repository boundaries, failure handling and regression tests. Remain read-only. Do not plan product features beyond the foundation. Suitable model: GPT-5.6 Sol High.
```

### Exercise data audit

```text
Perform a read-only data-quality audit of assets/data/exercises.json and its Drift seeding path. Produce duplicate and alias groups, inconsistent muscle/equipment labels, missing metadata, unsupported movement categories, ambiguous pause/tempo variants and deterministic mapping fixtures required by M15. Do not edit assets or schema. Suitable model: Gemini Flash.
```

### Design-system migration

```text
Produce an implementation-ready plan for IndiFit’s semantic design-system migration. Inventory every remaining AppColors dark-token reference, local typography value, radius above the approved scale, fixed-size compact-screen risk and raw navigation inconsistency. Define semantic tokens, component rules, responsive breakpoints, accessibility requirements, migration batches and golden-test coverage. Remain read-only. Suitable model: GPT-5.6 Terra High.
```

### Program and scheduling architecture

```text
Using the approved M15 foundation, design IndiFit’s versioned program, block, week, session-template and scheduled-occurrence architecture. Resolve activation, editing, rescheduling, skipping, repeating, partial completion, travel weeks, timezone behavior and progression advancement. Include Drift migration M16, backup impact, Riverpod ownership, GoRouter journeys, state transitions and acceptance tests. Remain read-only. Suitable model: GPT-5.6 Sol High.
```
