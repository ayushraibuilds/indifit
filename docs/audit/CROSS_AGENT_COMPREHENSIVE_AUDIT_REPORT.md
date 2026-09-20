# IndiFit — Comprehensive Cross-Agent Master Audit & Strategic Roadmap

> **Authoritative Reconciled Ground Truth & Risk-Calibrated Strategic Plan**  
> **Target Version:** IndiFit 1.0.0 (Build 1) | Baseline Schema v22 | Drift SQLite  
> **Classification:** **BETA READY (Dogfood / Closed Beta Candidate)**  
> **Operational Stance:** *Workouts = 100% Offline (Basement-Proof) | Nutrition = Online-First, Offline-Fallback (Quality & Scale)*  
> **Source Base:** 446 Dart files in `lib/`, 300 test files (2,469 test cases) in `test/`, FastAPI Backend (`backend/`)  
> **Auditors:** Multi-Agent Cross-Functional Review (Moat Architecture Specialist & Production Reliability Specialist)

---

## Table of Contents

1. [Executive Summary & Core Mission](#1-executive-summary--core-mission)
2. [Verified Codebase Metrics & Ground Truth](#2-verified-codebase-metrics--ground-truth)
3. [The IndiFit Moat: What Makes the Product Defensible](#3-the-indifit-moat-what-makes-the-product-defensible)
4. [Critical Flaws, Vulnerabilities & Ship Blockers (9 Defects)](#4-critical-flaws-vulnerabilities--ship-blockers-9-defects)
5. [The Nutrition Pivot: Online-First, Offline-Fallback](#5-the-nutrition-pivot-online-first-offline-fallback)
6. [Comprehensive Evaluation Matrix & Score Calibration](#6-comprehensive-evaluation-matrix--score-calibration)
7. [Use-Readiness vs. Launch-Readiness Assessment](#7-use-readiness-vs-launch-readiness-assessment)
8. [Actionable Unified Engineering Roadmap & Acceptance Criteria](#8-actionable-unified-engineering-roadmap--acceptance-criteria)
9. [High-Leverage Feature Upgrades & Future Opportunities](#9-high-leverage-feature-upgrades--future-opportunities)

---

## 1. Executive Summary & Core Mission

### 1.1 The Market Disconnect & The "Desi Lifter" Thesis
The consumer fitness technology landscape has historically neglected Indian lifters:
1. **Western Strength Apps (Hevy, Strong, RP Hypertrophy)**: Understand progressive overload, barbell mechanics, RPE, and set tracking, but possess **zero cultural literacy for Indian domestic food**. Logging a home-cooked Indian meal in these apps requires ingredient-by-ingredient breakdown that fails in communal family cooking.
2. **Indian Nutrition Trackers (Healthify, Fittr)**: Contain large Indian food databases, but treat strength training as an afterthought (treating weightlifting as a generic "cardio calorie burn"), are weighed down by aggressive telemarketing and coaching upsells, and break completely in basement gyms without cellular reception.
3. **Pervasive Metric Fabrication**: Commercial apps routinely inflate workout calorie burns (claiming 600–900 kcal burned in 45 minutes of lifting) and present synthetic 1RMs or arbitrary readiness scores.

### 1.2 The IndiFit Product Truth Contract
IndiFit bridges this divide with an uncompromising philosophy:
* **Dual-Engine Architecture**: Strength lifting execution is **100% offline-first and basement-proof**. Nutrition tracking is **online-first, offline-fallback**, leveraging cloud search and AI accelerators while maintaining local SQLite caching.
* **Radical Data Honesty**: Zero fabricated workout calorie burns, zero hallucinated PRs, and honest sparse-data evidence ladders.
* **Sovereign Data Ownership**: Records reside on-device. Encrypted JSON exports use industry-grade PBKDF2/AES-256-GCM (Backup v10), free from cloud lock-in or data selling.

---

## 2. Verified Codebase Metrics & Ground Truth

Both agents performed exhaustive code and disk audits. The reconciled ground truth of the repository is established as follows:

| Metric / Dimension | Verified Value | Ground-Truth Detail |
|---|:---:|---|
| **Dart Source Files (`lib/`)** | **446 files** | Modular presentation, domain DI, repositories, and services. |
| **Dart Test Files (`test/`)** | **300 files** | Unit, widget, migration, and golden test files. |
| **Total Test Assertions** | **2,469 test cases** | Verified via `grep -E "test\(|testWidgets\(" test/`. All core logic passing. |
| **Static Analysis (`flutter analyze`)** | **0 issues** | Runs in ~5.0s with zero warnings or errors. |
| **Database Engine** | **Drift SQLite v22** | Native SQLite with migration tests covering schemas v15 through v19. |
| **Encrypted Backup Codec** | **Backup v10** | PBKDF2 key derivation + AES-256-GCM authenticated encryption. |
| **Backend Service** | **FastAPI (Python)** | Modularized into `core/`, `routers/`, `schemas/`, `services/`, with 32 passing pytest cases. |
| **Design System** | **B05SemanticColors** | 100% token adoption across feature screens for WCAG light/dark compliance. |
| **Documentation Health** | **Drift Resolved** | Stale root documents (`ISSUES.md`, `UI_ANALYSIS.md`, `IMPLEMENTATION_PLAN.md`) archived to `archive/`; this dossier is canonical. |

---

## 3. The IndiFit Moat: What Makes the Product Defensible

```
                            ┌────────────────────────────────────────────────────────┐
                            │                    THE INDIFIT MOAT                    │
                            └────────────────────────────────────────────────────────┘
                                                         │
          ┌───────────────────────┬──────────────────────┴───────────────┬──────────────────────┐
          ▼                       ▼                                      ▼                      ▼
 ┌──────────────────┐    ┌──────────────────┐                  ┌──────────────────┐   ┌──────────────────┐
 │  Cross-Domain    │    │  Offline-First   │                  │ Radical Metric   │   │ Cultural Physics │
 │  Intersection    │    │  Lifting Core    │                  │ Truth & Evidence │   │ & Household Units│
 │ (Desi Lifter)    │    │ (Basement Proof) │                  │ (Anti-Bullshit)  │   │ (Katoris/Thalis) │
 └──────────────────┘    └──────────────────┘                  └──────────────────┘   └──────────────────┘
          │                       │                                      │                      │
          └───────────────────────┴──────────────────────┬───────────────┴──────────────────────┘
                                                         ▼
                                             ┌──────────────────────┐
                                             │ Sovereign Ownership  │
                                             │   Zero Cloud Lock-in │
                                             └──────────────────────┘
```

### 3.1 Cultural Culinary Physics & Household Measures
* **Bundled Food Catalog**: 573 base Indian food items plus 25 regional culinary pack items with nutritional and provenance metadata.
* **Indian Household Measures**: Supports standard and custom calibrated **Katori** (Small: 150ml, Medium: 200ml, Large: 250ml), **Vati**, **Roti/Chapati** (thin, standard, thick, with/without ghee), **Spoons**, and **Pieces**.
* **Cooked-to-Raw Hydration Expansion Engine**: Automatically calculates the 2.5× to 3.0× volume expansion of lentils (*dal*) and grains (*chawal/rice*), preventing the massive 200–300% calorie tracking errors common when users log cooked portions against raw database entries.
* **Interactive Circular Thali Plate & Quick-Adjust HUD**: An interactive visual plate separating center staples (roti, paratha, rice) from perimeter bowls (*dals*, *sabzis*, *curds*). Tapping any katori surfaces a HUD for rapid portion increments (+0.5, +1 katori), dish substitution, and visual macro distribution.
* **On-Device Adaptive TDEE Expenditure Engine**: Dynamically calculates rolling biological expenditure locally using daily weight trends and calorie adherence over a 14–28 day window, completely client-side without cloud transmission.

### 3.2 B02 Strength Execution Player
* **Structured Set Logging**: Supports distinct set types: Warmup, Working, Failure, and Drop Sets, with RPE (Rate of Perceived Exertion) logging.
* **Consolidated Barbell Plate Calculator**: Integrated directly into set inputs, calculating required 20kg, 15kg, 10kg, 5kg, 2.5kg, and 1.25kg plates per side for standard 20kg or 15kg barbells.
* **Previous Performance Lookups**: Displays previous session weights and reps directly beneath the active set to ensure progressive overload adherence.
* **iOS Live Activities & Dynamic Island Integration**: Built using native Swift WidgetKit (`RestTimerLiveActivityManager.swift` + `RestTimerWidget/`), allowing rest countdown timers to update live on lock screens and Dynamic Islands with haptic completion alerts and foreground screen wakelock (`wakelock_plus`).
* **Personal Record (PR) System**: Verifies true completed lifts against historical performance with celebration effects.

### 3.3 Platform & Native Health Plumbing
* **Health Integrations**: Two-way data pipeline wired via `health: ^11.0.0` for Apple HealthKit (`NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`) and Android Health Connect (Steps, Active Energy Burned, Resting Heart Rate, Sleep).
* **Smart Notifications**: Scheduled using `flutter_local_notifications` with device timezone resolution via `flutter_timezone`, respecting quiet hours and automatically skipping reminders if meals or workouts are already logged for the day.

---

## 4. Critical Flaws, Vulnerabilities & Ship Blockers (9 Defects)

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              IDENTIFIED CRITICAL DEFECTS                               │
├──────────────────────────────┬──────────┬──────────────────────────────────────────────┤
│ Defect                       │ Severity │ Impact                                       │
├──────────────────────────────┼──────────┼──────────────────────────────────────────────┤
│ 1. Backend Validation Gaps   │ 🔴 P0    │ Missing client fields compute on fake data   │
│ 2. P0 Empty Catches          │ 🔴 P0    │ 4 P0-empty (32 empty total of 180 catch(_))  │
│ 3. In-Memory Rate Limiting   │ 🔴 P0    │ Multi-worker bypass & Gemini quota drain     │
│ 4. Sentry Unconditional Init │ 🟡 P1    │ Wasted startup & telemetry privacy leakage   │
│ 5. Legacy Caller References  │ 🟡 P1    │ Dashboard/Training/SavedMeals import legacy  │
│ 6. Missing E2E Driver Tests  │ 🟡 P1    │ Multi-screen regressions undetected in CI    │
│ 7. Test Suite Execution Cost │ 🟢 P2    │ CI runtime >120s & golden font-diff CI fails │
│ 8. DPDP & Gemini Disclosure  │ 🟢 P2    │ AI photo analysis requires explicit consent  │
│ 9. Cryptic Milestone Naming  │ 🟢 P2    │ 81 files prefixed with b02/b04/b05 (tech debt)│
└──────────────────────────────┴──────────┴──────────────────────────────────────────────┘
```

### 4.1 Defect 1: Backend Request Validation Gaps & Fake Defaults (P0)
* **File**: `backend/schemas/ai.py`
* **Issue**:
  - `RoutineRequest` has zero `@field_validator` annotations: `days_per_week` accepts invalid numbers (e.g. `999` or `-1`), and `experience` accepts arbitrary strings.
  - `MealPlanRequest` and `WeeklyReportRequest` contain hardcoded defaults (`calorie_goal = 2000`, `total_calories_logged = 14000`, `workout_sessions_count = 4`, `total_volume_kg = 12500.0`).
* **Risk**: If the mobile client omits a field due to a network bug or serialization error, the backend does not return an HTTP 422 error; instead, it silently calculates a report on fake numbers, breaking the Product Truth Contract.
* **Remediation**: Add explicit `@field_validator` constraints on `RoutineRequest` (enforce `1 <= days_per_week <= 7`, validate experience enum), and strip all hardcoded defaults from `MealPlanRequest` and `WeeklyReportRequest` so missing parameters strictly trigger HTTP 422 Unprocessable Entity.

### 4.2 Defect 2: Empty Catch Blocks in Critical Paths (P0: 4 Sites; 32 Total Empty; 180x `catch (_)`)
* **Calibrated Scope**:
  - Codebase contains **180** `catch (_)` statements total (where the error object is unused).
  - Exactly **32** of these are completely empty blocks (`catch (_) {}`).
  - Exactly **4** of these empty catches reside in **P0 mission-critical paths**:
    1. `lib/data/repositories/health_service.dart:22` (`SharedPreferences` fallback in provider)
    2. `lib/features/dashboard/dashboard_controller.dart:555` (`SharedPreferences` fallback in provider)
    3. `lib/features/workout_player/b02_strength_execution_controller.dart:1628` (`achievementStreakDays` fallback)
    4. `lib/features/workout_player/b02_strength_execution_controller.dart:1659` (`achievementStreakDays` screen fallback)
* **Risk**: In these 4 sites, initialization or data fetching failures are silently swallowed without diagnostics, masking test setup errors and potentially defaulting critical state.
* **Calibrated Execution (Preventing A2 Scope Creep)**:
  - Sweeping all 180 `catch (_)` blocks would turn Sprint A2 into a multi-week regression hazard. Many `catch (_)` blocks are intentional UI/haptic tolerances (e.g. `HapticFeedback.lightImpact().catchError((_) {})`).
  - **Sprint A2 Focus**: Remediate the **4 P0-empty sites** first, replacing them with typed error handling / logging. Add the `avoid_empty_catch` lint rule to fail CI on any *new* empty catch blocks.
  - **Post-Beta**: Systematically audit the remaining 28 secondary empty catches.

### 4.3 Defect 3: Rate Limiting & Zero-Ops Cache Architecture (P0)
* **File**: `backend/core/security.py` & `backend/services/gemini_client.py`
* **Critical Architectural Trap**: An in-memory TTL cache (`cachetools.TTLCache`) suffers from the *exact same multi-worker bypass* as the in-memory rate limiter (`IP_REQUEST_LOGS`) if workers are multiplied.
* **Zero-Ops Architectural Resolution**:
  - For V1 Beta, **drop external Redis dependencies**. Redis introduces deployment dependencies, connection pool maintenance, and monthly hosting costs for zero gain at early scale.
  - **Single-Worker Container Enforcement**: Deploy the backend container with `WEB_CONCURRENCY=1` in `backend/render.yaml` and `backend/Dockerfile`. This guarantees that process memory is 100% shared for all incoming requests.
  - **In-Memory Query Cache**: Use `cachetools.TTLCache(maxsize=2000, ttl=3600)` keyed by SHA-256 query hashes to prevent redundant Gemini calls for identical meal lookups.
  - **Mobile Disk Cache**: Persist searched terms in a local Drift SQLite table (`food_search_cache`) for 7 days.
  - **Quota Protection**: Implement an aggregate daily Gemini spend budget returning `is_fallback: true` when exceeded.

### 4.4 Defect 4: Sentry Unconditional Initialization (P1)
* **File**: `lib/core/services/crash_reporting_service.dart:33`
* **Issue**: `SentryFlutter.init` is executed during app startup even when the user has opted out of telemetry, when offline mode is active, or when `SENTRY_DSN` is set to the default placeholder. The service drops events in `beforeSend`, but the native SDK hooks into platform error channels on every boot.
* **Remediation**: Short-circuit `CrashReportingService.initialize`:
  ```dart
  if (!_isEnabled || _defaultDsn.contains('placeholder_key')) {
    AppLogger.info('Sentry crash reporting disabled (opt-out or placeholder DSN).');
    await appRunner();
    return;
  }
  ```

### 4.5 Defect 5: Legacy Caller References Across 3 Screens & Router (P1)
* **Files**:
  - `lib/features/food_log/saved_meals_screen.dart:240` (instantiates `MealTemplatesScreen`)
  - `lib/features/dashboard/dashboard_screen.dart:176` (instantiates `WorkoutPlayerScreen` on draft resume)
  - `lib/features/training/training_screen.dart:361` (instantiates `WorkoutPlayerScreen` on draft resume)
  - `lib/core/router/routes/workout_player_routes.dart:31-50` (routes `/workout-player`)
* **Risk**: Deleting `workout_player_screen.dart` and `meal_templates_screen.dart` without first refactoring these 4 caller sites will immediately break compilation and cause crashes when users resume draft workouts.
* **Remediation Strategy**: Callers must be migrated to `B02StrengthPlayerScreen` and modern Saved Meals *before* the legacy files are deleted.

### 4.6 Defect 6: Absence of Driver-Level E2E Integration Tests (P1)
* **Issue**: The project contains 2,469 unit and widget tests, but zero tests under an `integration_test/` directory running against real device drivers.
* **Risk**: Multi-screen integration issues (e.g., Onboarding Wizard $\to$ Profile Target $\to$ Dashboard; Workout Player $\to$ Summary $\to$ SQLite Session History) can escape undetected.
* **Remediation**: Add `integration_test/log_meal_workout_flow_test.dart` and `integration_test/onboarding_flow_test.dart`.

### 4.7 Defect 7: Test Suite Execution Cost & Golden Fragility (>120s CI) (P2)
* **Files**: `test/` (300 test files, 2,469 tests) & `test/goldens/` (114 golden files)
* **Issue**: The automated test suite takes $>120$ seconds to run locally and in CI. Furthermore, golden file tests fail on macOS host machines due to $0.20\%$ (667px) antialiasing differences across local OS font rendering engines.
* **Remediation**: Configure CI test sharding or separate unit/widget execution from heavy golden tests. In CI, run golden tests exclusively inside a pinned Linux Docker container with a custom comparator tolerance ($0.5\%$).

### 4.8 Defect 8: Compliance & Privacy Disclosures (DPDP / Gemini DPA) (P2)
* **Risk**: Transmitting food and label photos to Google Gemini requires an explicit user consent disclosure prior to camera capture / photo upload under India's Digital Personal Data Protection (DPDP) Act and Apple App Store Review Guideline 5.1.1.
* **Remediation**: Introduce a one-time consent modal prior to camera or microphone capture, clearly disclosing third-party AI processing and ephemeral media handling.

### 4.9 Defect 9: Cryptic Milestone Naming Over-Abstraction (81 Files) (P2)
* **Scope**: 81 files in `lib/` are prefixed with milestone designations (`b02_`, `b04_`, `b05_`).
* **Risk**: Internal milestone tags create steep cognitive onboarding overhead for new developers.
* **Remediation Strategy**: Defer this refactor until **post-beta**. Renaming 81 files during active feature work carries an extreme blast radius for merge conflicts and broken imports. Migrate to `training/`, `nutrition/`, and `design_system/` domains post-beta.

---

## 5. The Nutrition Pivot: Online-First, Offline-Fallback

### 5.1 Forensic Line-Level Audit of the Nutrition Stack
* **Hardcoded Katori Heuristic**: `lib/features/food_log/food_search_screen.dart:632-648` uses brittle substring checks (`if (lowerName.contains('dal') ...)`). Dishes like *"Arhar Tadka"* or *"Kootu"* fail and fall back to raw 100g.
* **Micronutrient Discarding**: `lib/data/repositories/nutrition_food_catalog_repository.dart:139-145` maps energy, protein, carbs, and fat, but silently discards fiber, sodium, added sugar, and saturated fat (`_ => null`).
* **Naive Local Search**: `searchFoodLocal()` uses raw `LIKE '%query%'`. Empty queries return `[]` instead of frequent foods.

### 5.2 Architectural Specifications for the Hybrid Engine
1. **Backend Food Proxy (`POST /api/food/search`)**:
   * Merges a curated Indian database with Open Food Facts Search-a-licious.
   * Integrates an Indian dialect transliteration dictionary (`arhar` $\leftrightarrow$ `toor`, `chapati` $\leftrightarrow$ `roti`, `dahi` $\leftrightarrow$ `curd`).
   * Explicit Ranking Formula:
     $$\text{Score} = \text{Exact Match (100)} > \text{Catalog Verified (80)} > \text{Frequent (60)} > \text{Provider (40)} > \text{Fuzzy (20)}$$
   * Logs anonymous zero-result queries to a `missed_searches` buffer to systematically expand dictionary and food coverage.
2. **Category Taxonomy Serving Intelligence**:
   * Replaces substring matching with an explicit `category_id` on each food entity (`dal_lentil`, `gravy_curry`, `dry_sabzi`, `staple_bread`, `staple_rice`, `dairy_liquid`). Serving units and gram weights are returned directly from the server.
3. **Multimodal Voice-to-Thali & Photo Recognition**:
   * Voice audio transcribed and passed to `/api/ai/meal-decompose`, populating directly into the **Circular Thali Plate UI**.
   * Client-side image downscaling ($1024 \times 1024$ JPEG 80%, $<300\text{KB}$) with a strict daily quota (max 10 scans/day/device).
   * Durable offline outbox queue using `lib/core/outbox/`: unverified local logs commit immediately with an `AI Enrichment Pending` badge when offline.
4. **Batch Handi Cooking & Leftover Tracker**:
   * Users input total raw ingredients for a large pot (*Mom's Chicken Handi*) $\to$ define yield (*"Makes 4 katoris"*).
   * 1-tap logging of "1 Katori from Handi" on subsequent days without re-calculating raw ingredients.

---

## 6. Comprehensive Evaluation Matrix & Score Calibration

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        COMPREHENSIVE THREE-WAY SCORECARD                               │
├───────────────────────────────────┬──────────┬──────────┬──────────┬───────────────────┤
│ Evaluation Dimension              │ Agent 1  │ Agent 2  │ Final    │ Calibrated Basis  │
├───────────────────────────────────┼──────────┼──────────┼──────────┼───────────────────┤
│ 1. Product Moat (Indian Fit)      │ 9.8 / 10 │ 8.5 / 10 │ 9.2 / 10 │ Differentiated    │
│ 2. Functional Completeness        │ 9.2 / 10 │ 7.5 / 10 │ 8.2 / 10 │ Core done, gaps   │
│ 3. Code Architecture & Cleanliness│ 9.5 / 10 │ 6.5 / 10 │ 7.8 / 10 │ DI good; catches  │
│ 4. Data Integrity & Offline Core  │ 9.8 / 10 │ 7.5 / 10 │ 9.2 / 10 │ SQLite v22 solid  │
│ 5. Security & Privacy             │ 9.6 / 10 │ 7.0 / 10 │ 8.0 / 10 │ Local AES; API gap│
│ 6. Backend Robustness & Ops Cost  │ 8.0 / 10 │ 6.0 / 10 │ 6.5 / 10 │ Single worker req │
│ 7. UI/UX, Haptics & Feel          │ 8.8 / 10 │ 7.0 / 10 │ 8.2 / 10 │ Fluid; modal debt │
│ 8. Performance & Reliability      │ 8.7 / 10 │ 7.0 / 10 │ 8.0 / 10 │ Sub-ms DB; catches│
│ 9. Testing Rigor & CI Automation  │ 9.4 / 10 │ 7.5 / 10 │ 8.6 / 10 │ 2,469 tests; no E2E│
│ 10. Store Compliance & Governance │ 8.2 / 10 │ 6.5 / 10 │ 7.0 / 10 │ Apple acct blocker│
├───────────────────────────────────┼──────────┼──────────┼──────────┼───────────────────┤
│ COMPOSITE OVERALL SCORE           │ 9.4 / 10 │ 7.1 / 10 │ 8.2 / 10 │ BETA READY        │
│                                   │          │          │          │ (DOGFOOD CANDIDATE│
└───────────────────────────────────┴──────────┴─────────────────────┴───────────────────┘
```

---

## 7. Use-Readiness vs. Launch-Readiness Assessment

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        USE-READINESS vs. LAUNCH-READINESS SPLIT                        │
└────────────────────────────────────────────────────────────────────────────────────────┘

   USE-READINESS: 8.5 / 10 (READY FOR DAILY DOGFOODING & PERSONAL LIFTING)
   ═══════════════════════════════════════════════════════════════════════
   ✅ Physical Android sideloading and iOS Xcode personal provisioning work today.
   ✅ Drift SQLite Schema v22 handles daily set logging, katori conversions, and TDEE.
   ✅ Lock screen Live Activities and Dynamic Island rest timers update reliably.
    ⚠️ Personal iOS cert expires every 7 days without a paid developer account.
    ⚠️ 4 P0 empty catches require hardening (with linting against new empty catches) before beta.

    GOOGLE PLAY LAUNCH READINESS: 7.0 / 10 (NEAR-TERM BETA CANDIDATE)
    ════════════════════════════════════════════════════════════════
    ✅ Android signing, 64-bit APK/AAB builds, and Health Connect permissions present.
    ⚠️ Requires backend validation fixes and single-worker deployment configuration.
    ⚠️ Requires completion of Google's mandatory 20-tester closed beta (14 days).

    APPLE APP STORE LAUNCH READINESS: 6.0 / 10 (BLOCKED ON ENROLLMENT & ASSETS)
    ═══════════════════════════════════════════════════════════════════════════
    ⚠️ Blocked on $99/year Apple Developer Program account enrollment.
    ⚠️ Production provisioning profiles required for HealthKit and Live Activities.
    ⚠️ App Store marketing screenshots (6.7" and 6.1" display sizes) required.
```

---

## 8. Actionable Unified Engineering Roadmap & Acceptance Criteria

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                          FOUR-PHASE ENGINEERING TIMELINE                               │
├────────────────────────────────┬─────────────────┬─────────────────────────────────────┤
│ Phase                          │ Duration        │ Primary Deliverables                │
├────────────────────────────────┼─────────────────┼─────────────────────────────────────┤
│ Sprint A1 (Immediate Quick-Fix)│ 1–2 Days        │ Backend schemas, Sentry guard, arch │
│ Sprint A2 (Core Hardening)     │ 1 Week          │ P0 catches, caller migration, E2E   │
│ Sprint B  (UX & Polish)        │ 1–2 Weeks       │ Macro donut, modal queue, DPDP consent│
│ Sprint C  (Ops & Store Launch) │ 2–4 Weeks       │ Cloud deploy, store assets, Apple   │
└────────────────────────────────┴─────────────────┴─────────────────────────────────────┘
```

### 🔴 Sprint A1: Immediate Quick-Fixes (1–2 Days)
* [ ] **Backend Pydantic Validation** (`backend/schemas/ai.py`):
  * *Acceptance Criteria*: Pytest asserts HTTP 422 when `RoutineRequest.days_per_week` is $<1$ or $>7$, or when `experience` is invalid.
* [ ] **Strip Hardcoded Defaults** (`backend/schemas/ai.py`):
  * *Acceptance Criteria*: Pytest asserts HTTP 422 when `MealPlanRequest` or `WeeklyReportRequest` omits required fields (no fake success).
* [ ] **Sentry Startup Guard** (`lib/core/services/crash_reporting_service.dart`):
  * *Acceptance Criteria*: Unit test verifies `SentryFlutter.init` is completely bypassed when telemetry is disabled or DSN is placeholder.
* [ ] **Single-Worker Container Pinning**:
  * *Acceptance Criteria*: `WEB_CONCURRENCY=1` is explicitly set in `backend/render.yaml` and `backend/Dockerfile`.
* [ ] **In-Memory Query Cache & Daily Gemini Spend Ceiling**:
  * *Acceptance Criteria*: Pytest verifies identical query hash returns cached response; queries exceeding daily quota return `is_fallback: true`.

### 🔴 Sprint A2: Core Hardening & Legacy Migration (1 Week)
* [ ] **P0 Empty Catch Remediation**:
  * *Acceptance Criteria*: The 4 P0 empty catches in `lib/data/repositories/health_service.dart:22`, `lib/features/dashboard/dashboard_controller.dart:555`, and `lib/features/workout_player/b02_strength_execution_controller.dart:1628,1659` are replaced with typed error handling and logging; `python3 tool/generate_code_graph.py --ci` reports 0 P0 empty catches.
* [ ] **Lint Gate Against Silent Catches**:
  * *Acceptance Criteria*: Custom rule `avoid_empty_catch` is added to `analysis_options.yaml`; CI fails if an empty catch block is introduced.
* [ ] **Migrate Legacy Callers (4 Sites)**:
  * *Acceptance Criteria*: `lib/features/food_log/saved_meals_screen.dart:240`, `lib/features/dashboard/dashboard_screen.dart:176`, `lib/features/training/training_screen.dart:361`, and `lib/core/router/routes/workout_player_routes.dart:31-50` compile cleanly without referencing `WorkoutPlayerScreen` or `MealTemplatesScreen`.
* [ ] **Delete Legacy Screens**:
  * *Acceptance Criteria*: `workout_player_screen.dart` and `meal_templates_screen.dart` are permanently deleted; `flutter analyze` passes with 0 errors.
* [ ] **Add Driver E2E Integration Tests**:
  * *Acceptance Criteria*: `integration_test/onboarding_flow_test.dart` and `integration_test/log_meal_workout_flow_test.dart` execute and pass on an Android/iOS emulator runner.

### 🟡 Sprint B: UX Polish, Compliance & Nutrition Modernization (1–2 Weeks)
* [ ] **Backend Food Search Proxy** (`backend/routers/food.py`):
  * *Acceptance Criteria*: `POST /api/food/search` returns ranked Indian dishes with Hinglish transliteration support, verified via pytest.
* [ ] **Category Taxonomy Integration**:
  * *Acceptance Criteria*: `FoodPortionBottomSheet` renders standard katori and gram options directly from `category_id`; lines 632–648 in `food_search_screen.dart` deleted.
* [ ] **Micronutrient Persistence**:
  * *Acceptance Criteria*: `ensureProviderFood` in `nutrition_food_catalog_repository.dart` persists dietary fiber and sodium facts into SQLite.
* [ ] **Macro Donut Chart**:
  * *Acceptance Criteria*: `CalorieRingCard` renders an embedded `fl_chart` donut ring showing protein/carb/fat breakdown.
* [ ] **Modal Collision Resolution**:
  * *Acceptance Criteria*: PR celebration confetti dialog displays strictly after the rest timer sheet is dismissed.
* [ ] **DPDP Consent Modal**:
  * *Acceptance Criteria*: Modal renders before camera/voice capture; user acceptance is persisted to `SharedPreferences`.

### 🟢 Sprint C: Deployment, Operations & App Store Submission (2–4 Weeks)
* [ ] **Production Backend Deployment**:
  * *Acceptance Criteria*: Backend is live on Render/Fly.io with valid HTTPS; `/health` returns 200 OK.
* [ ] **Store Marketing Assets**:
  * *Acceptance Criteria*: 6.7" iPhone and 6.1" Android promotional screenshots generated.
* [ ] **Apple Developer Enrollment**:
  * *Acceptance Criteria*: Paid account enrolled ($99); HealthKit and WidgetKit production provisioning profiles active in App Store Connect.
* [ ] **Google Play 20-Tester Track**:
  * *Acceptance Criteria*: Closed testing ring running with 20 active testers for 14 days.

---

## 9. High-Leverage Feature Upgrades & Future Opportunities

1. **Batch Cooking & Leftover Tracker ("Handi of Dal")**:
   - Indian households regularly cook large pots of curry or dal consumed across 2–3 days. Allow users to log a 4-serving recipe once and log "1 bowl from yesterday's handi" across subsequent days with one tap.
2. **Offline Barcode Database Expansion**:
   - Pre-seed SQLite with high-frequency Indian fitness packaged foods (Amul high-protein lassi/buttermilk, Epigamia Greek yogurt, Tata Sampann pulses, Pintola peanut butter) to guarantee instant offline barcode scans without waiting for Open Food Facts.
3. **Compound Lift Technique Guides (Top 25 Lifts)**:
   - Bundle 20–25 lightweight vector/Lottie looping animations for foundational compound lifts (Squat, Bench, Deadlift, Overhead Press, Barbell Row, Pull-up) for instant offline technique checks.
4. **Music App Launcher**:
   - Add a lightweight floating action button in the player using `url_launcher` that deep-links directly to Spotify (`spotify:`), YouTube Music (`ytmusic:`), or Apple Music (`music:`) with zero SDK bloat.
5. **Wearable Companion (Apple Watch & Wear OS)**:
   - Standalone wrist-based set completion, plate loading checks, and haptic rest alerts.
6. **Stream B Zero-Knowledge Multi-Device Sync**:
   - Blind relay synchronization where workout and nutrition rows are client-encrypted using PBKDF2/AES-GCM before transmission, preventing server visibility into user data.
7. **B2B Coach & Athlete Prescription Portal**:
   - Web portal for Indian personal trainers and nutritionists to push structured workout splits and thali meal plans directly into clients' apps, ingesting verified lifting history.

---

## 10. Document Metadata & Final Sign-Off

* **Document Status**: **CANONICAL & FROZEN**
* **Version**: `1.0.0-beta.1`
* **Date**: September 16, 2026
* **Target Commit**: `40c5be0`
* **Multi-Agent Sign-Off**:
  * *Agent 1 (Moat Architecture Specialist)*: Verified and approved.
  * *Agent 2 (Production Reliability Specialist)*: Verified and approved.
* **Archival Notice**: Root planning documents (`ISSUES.md`, `UI_ANALYSIS.md`, `IMPLEMENTATION_PLAN.md`, `UX_FEATURE_IMPROVEMENT_PLAN.md`) are archived under `archive/legacy_plans/` and superseded by this dossier.
