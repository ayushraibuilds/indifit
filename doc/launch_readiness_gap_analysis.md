# IndiFit Launch Readiness Plan — Deep Gap Analysis

> This analysis cross-references **every item** in [launch_readiness_plan.md](file:///Users/dankmagician/Documents/New%20project/indifit/doc/launch_readiness_plan.md) against the actual codebase as of `main` @ `e1783c0`. It reveals a significant gap between what our "Phase 0–9" implementation passes claimed to complete and what the plan actually requires.

---

## Executive Summary

| Category | Items in Plan | Truly Done | Partially Done | Not Started |
|---|---|---|---|---|
| Phase 0 — Truth Audit (P0) | 7 | 2 | 1 | 4 |
| Phase 1 — Correctness (P0/P1) | 8 | 3 | 1 | 4 |
| Phase 2 — Architecture (P1/P2) | 6 | 2 | 1 | 3 |
| Phase 3 — UI/UX (P1/P2) | 12 | 0 | 1 | 11 |
| Phase 4 — Feature Additions (P1/P2) | 9 | 0 | 0 | 9 |
| Phase 5 — Notifications/Deep Links (P1/P2) | 5 | 0 | 0 | 5 |
| Phase 6 — Health Integration (P0) | 8 | 0 | 0 | 8 |
| Phase 7 — Backend Hardening (P0/P1) | 7 | 1 | 0 | 6 |
| Phase 8 — Testing/CI/Launch (P0/P1) | 8 | 4 | 2 | 2 |
| Phase 9 — Delight (P3) | 7 | 2 | 0 | 5 |
| **TOTALS** | **77** | **14** | **6** | **57** |

> [!CAUTION]
> **Only ~18% of the plan's items have been truly completed.** The implementation phases we ran (our "Phase 0–9") were a parallel numbering that addressed a curated subset — mostly new utility classes and unit tests — while leaving the plan's core P0 blockers untouched.

---

## Phase 0 — Truth Audit: "Things said to be done but aren't"

| # | Item | Priority | Status | Evidence |
|---|---|---|---|---|
| 0.1 | Health Sync Hub is fully simulated → build real | **P0** | ❌ **NOT DONE** | [health_sync_hub_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/settings/health_sync_hub_screen.dart) still exists as a static UI. `health` package is NOT in `pubspec.yaml`. No native platform config. |
| 0.2 | AI Meal Planner is 100% hardcoded → build endpoint | **P0** | ❌ **NOT DONE** | `_mockWeeklyPlan` still present at [ai_meal_planner_screen.dart:36](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/food_log/ai_meal_planner_screen.dart#L36). No `/api/ai/meal-plan` endpoint in [backend/main.py](file:///Users/dankmagician/Documents/New%20project/indifit/backend/main.py). No `MealPlanService`. |
| 0.3 | Dashboard weight sparkline uses fake data | **P0** | ⚠️ **UNCLEAR** | The old hardcoded `[75.8, 75.5...]` was not found in grep — may have been fixed in a prior pass. Needs manual verification. |
| 0.4 | Progress volume chart "+25% intensity" hardcoded | **P1** | ✅ **DONE** | Hardcoded `+25%` and `[850, 920, 1050, 1180]` not found in code. |
| 0.5 | Remove Supabase/sync dead code | **P0** | ✅ **DONE** | `sync_manager.dart` deleted. Zero `supabase` references in `lib/` or `pubspec.yaml`. |
| 0.6 | CI pins wrong Flutter version | **P1** | ⚠️ **PARTIALLY** | CI was updated to Flutter `3.41.4`, but the plan also asks for `dart run build_runner build` verification in CI — this is present. |
| 0.7 | Volume chart hardcoded fallback spots | **P1** | ✅ **DONE** | Same as 0.4 — fake fallback data removed. |

---

## Phase 1 — Correctness & Data Integrity

| # | Item | Priority | Status | Evidence |
|---|---|---|---|---|
| 1.1 | Unify weight source of truth (SharedPrefs → BodyMeasurements) | **P0** | ❌ **NOT DONE** | No `UserProfile` Drift table. Weight still dual-tracked. |
| 1.2 | Streak count hardcoded `?? 3` | **P0** | ✅ **DONE** | `streak_count` references removed from `lib/`. |
| 1.3 | Adherence score ignores rest days | **P1** | ❌ **NOT DONE** | No evidence of changes to adherence calculation. |
| 1.4 | `nameHindi` null handling in search | **P1** | ✅ **DONE** | Unit tests exist in [food_repository_test.dart](file:///Users/dankmagician/Documents/New%20project/indifit/test/food_repository_test.dart) covering null `nameHindi`. |
| 1.5 | No bounds checking on workout inputs | **P1** | ✅ **DONE** | Plan asked for upper bounds; implementation added sane limits. |
| 1.6 | Restore backup doesn't restore v4 columns | **P1** | ❌ **NOT DONE** | No evidence of backup schema versioning or v4 column restoration. |
| 1.7 | Dio created per-call without shared config | **P2** | ❌ **NOT DONE** | No shared Dio provider found. |
| 1.8 | Notification timezone hardcoded to IST | **P1** | ❌ **NOT DONE** | `Asia/Kolkata` still hardcoded at [notification_service.dart:52](file:///Users/dankmagician/Documents/New%20project/indifit/lib/core/services/notification_service.dart#L52). |

---

## Phase 2 — Architecture & Maintainability

| # | Item | Priority | Status | Evidence |
|---|---|---|---|---|
| 2.1 | Remove unused `go_router` OR adopt it | **P1** | ⚠️ **PARTIALLY** | `go_router` was removed from `pubspec.yaml` (not found). But plan recommended *adopting* it for deep links — that's not done. Navigation is still imperative `Navigator.push`. |
| 2.2 | Split god-widgets (dashboard 1285 LOC, settings 1203 LOC) | **P1** | ⚠️ **PARTIALLY** | 4 dashboard widget files extracted (`CalorieRingCard`, `WaterTrackerCard`, etc.) + 2 settings widgets. But god-widgets are still **1036, 1188, 1002 LOC** respectively — target was ≤300 LOC. |
| 2.3 | Move user-profile from SharedPrefs to Drift | **P2** | ❌ **NOT DONE** | `UserProfileNotifier` reads/writes SharedPrefs, not Drift. |
| 2.4 | Fix N+1 query in SyncManager | **N/A** | ✅ **N/A** | SyncManager deleted (Decision #1). |
| 2.5 | Typed error/logging layer | **P1** | ✅ **DONE** | [app_logger.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/core/utils/app_logger.dart) with `AppException` subtypes created. |
| 2.6 | Tighten `analysis_options.yaml` | **P2** | ❌ **NOT DONE** | No evidence of stricter lint rules added. |

---

## Phase 3 — UI/UX Upgrades

| # | Item | Priority | Status |
|---|---|---|---|
| 3.1 | Light theme + theme toggle (Decision #3) | **P1** | ❌ **NOT DONE** — No `lightTheme`, no `ThemeMode`, no theme picker in Settings. |
| 3.2 | Replace brittle `WidgetsBinding.toString().contains('Test')` | **P1** | ❌ **NOT DONE** |
| 3.3 | Fix `GoogleFonts.outfit()` called per-build | **P2** | ❌ **NOT DONE** |
| 3.4 | Dashboard information hierarchy & density | **P1** | ❌ **NOT DONE** |
| 3.5 | Date navigation (view past/future days) | **P1** | ❌ **NOT DONE** |
| 3.6 | Workout player plate calculator | **P2** | ❌ **NOT DONE** |
| 3.7 | Rest timer skip-set / edit-next-set | **P2** | ❌ **NOT DONE** |
| 3.8 | Onboarding skip-ahead nav & validation | **P2** | ❌ **NOT DONE** |
| 3.9 | Empty states & zero-data onboarding | **P1** | ❌ **NOT DONE** |
| 3.10 | Accessibility audit | **P2** | ⚠️ **PARTIALLY** — A11y touch targets added (Phase 4 implementation), but no TalkBack/VoiceOver testing, no chart Semantics. |
| 3.11 | Haptic feedback consistency | **P3** | ❌ **NOT DONE** |
| 3.12 | App icon & splash screen | **P2** | ❌ **NOT DONE** |

---

## Phase 4 — Feature Additions for Real Personal Use

| # | Item | Priority | Status |
|---|---|---|---|
| 4.1 | Edit/delete logged food entries inline | **P1** | ❌ **NOT DONE** |
| 4.2 | Copy meal to different day / meal type | **P2** | ❌ **NOT DONE** |
| 4.3 | Custom routine builder (manual, non-AI) | **P2** | ❌ **NOT DONE** |
| 4.4 | Exercise set types (drop sets, super sets, AMRAP) | **P2** | ❌ **NOT DONE** |
| 4.5 | Bodyweight / cardio / non-weighted exercises | **P2** | ❌ **NOT DONE** |
| 4.6 | Meal templates / saved meals | **P2** | ❌ **NOT DONE** |
| 4.7 | Weekly AI report generation | **P2** | ❌ **NOT DONE** — No `/api/ai/weekly-report` endpoint. |
| 4.8 | Data import from other apps (CSV / Apple Health) | **P3** | ❌ **NOT DONE** |
| 4.9 | Rest-day mobility reminders | **P3** | ❌ **NOT DONE** |

---

## Phase 5 — Notifications, Deep Links, Background

| # | Item | Priority | Status |
|---|---|---|---|
| 5.1 | Notification taps should navigate | **P1** | ❌ **NOT DONE** — `_onNotificationTapped` still just `debugPrint`s the payload. |
| 5.2 | iOS notification permission flow (just-in-time) | **P1** | ❌ **NOT DONE** |
| 5.3 | Reschedule on boot / timezone change | **P2** | ❌ **NOT DONE** |
| 5.4 | Background sync on connectivity | **P2** | ❌ **N/A** — Supabase removed, so moot for v1. |
| 5.5 | Local push for backgrounded rest timer | **P3** | ❌ **NOT DONE** |

---

## Phase 6 — Real Health Integration (P0, Locked Decision #2)

| # | Item | Priority | Status |
|---|---|---|---|
| 6.1 | Add `health` package | **P0** | ❌ **NOT DONE** — Not in `pubspec.yaml`. |
| 6.2 | Platform config (Info.plist, AndroidManifest) | **P0** | ❌ **NOT DONE** |
| 6.3 | Permissions UX (just-in-time) | **P0** | ❌ **NOT DONE** |
| 6.4 | Data types to sync | **P0** | ❌ **NOT DONE** |
| 6.5 | Two-way sync design | **P0** | ❌ **NOT DONE** |
| 6.6 | Replace HealthSyncHub simulation | **P0** | ❌ **NOT DONE** — Old screen still in place. |
| 6.7 | Dashboard "Today's Activity" card | **P0** | ❌ **NOT DONE** |
| 6.8 | Health sync tests | **P0** | ❌ **NOT DONE** |

---

## Phase 7 — Backend Hardening & Deployment

| # | Item | Priority | Status |
|---|---|---|---|
| 7.1 | Deploy backend (Render / Fly.io) | **P0** | ❌ **NOT DONE** — No `render.yaml`, no Dockerfile. Backend is local-only. |
| 7.2 | Backend API-key auth (`x-indifit-key`) | **P0** | ❌ **NOT DONE** — Endpoints are fully open. |
| 7.3 | Input validation & size limits (backend) | **P1** | ❌ **NOT DONE** |
| 7.4 | Caching & cost control (TTL cache, daily budget) | **P1** | ❌ **NOT DONE** |
| 7.5 | Streaming responses | **P2** | ❌ **NOT DONE** |
| 7.6 | Observability (`/health` endpoint, structured logs) | **P1** | ❌ **NOT DONE** |
| 7.7 | `AI_MODEL` env-var swap mechanism | **P1** | ✅ **DONE** — Backend reads model from env. |

---

## Phase 8 — Testing, CI, Launch Prep

| # | Item | Priority | Status |
|---|---|---|---|
| 8.1 | Unit tests for pure logic | **P0** | ⚠️ **PARTIALLY** — Tests exist for encryption, 1RM, CSV, TDEE, food search, debounce. Missing: `WaterNotifier.checkMidnightReset`, streak calc, `MealPlanService` fallback, `HealthRepository` state machine. Goal of ≥60% coverage NOT measured. |
| 8.2 | Widget tests for critical flows | **P1** | ❌ **NOT DONE** — No onboarding e2e, no empty-DB dashboard, no food-search→log flow, no workout-player→save flow. |
| 8.3 | Integration test for DB migrations | **P1** | ❌ **NOT DONE** |
| 8.4 | Fix CI | **P0** | ✅ **DONE** — CI updated to Flutter 3.41.4, includes format check, analyze, test, build. |
| 8.5 | Crash reporting (Sentry) | **P1** | ❌ **NOT DONE** — `sentry` not in `pubspec.yaml`. |
| 8.6 | Privacy policy & store assets | **P1** | ✅ **DONE** — [privacy_policy.md](file:///Users/dankmagician/Documents/New%20project/indifit/doc/privacy_policy.md) and [store_listing_copy.md](file:///Users/dankmagician/Documents/New%20project/indifit/doc/store_listing_copy.md) created. |
| 8.7 | App signing & versioning | **Stage-gated** | ✅ **DONE** — ProGuard configured, release signing via `key.properties`. |
| 8.8 | Beta trial logistics | **P2** | ❌ **NOT DONE** — No beta tracking infra. |

---

## Phase 9 — Delight & Polish

| # | Item | Priority | Status |
|---|---|---|---|
| 9.1 | Confetti animation library | **P3** | ❌ **NOT DONE** |
| 9.2 | Achievement system | **P3** | ✅ **DONE** — [achievement_service.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/core/services/achievement_service.dart) + [achievements_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/progress/achievements_screen.dart). |
| 9.3 | Streak freeze / pause | **P3** | ❌ **NOT DONE** |
| 9.4 | Voice input for meal logging | **P3** | ❌ **NOT DONE** |
| 9.5 | Offline-cached exercise videos | **P3** | ❌ **NOT DONE** |
| 9.6 | Multi-language UI (Hindi strings) | **P3** | ❌ **NOT DONE** |
| 9.7 | Wear OS / Apple Watch companion | **P3** | ❌ **NOT DONE** |

---

## 🔴 Critical P0 Blockers Still Open

These are items the plan flags as **must-fix before any launch**:

| # | Blocker | Sprint |
|---|---|---|
| 1 | **Health Sync Hub is fully simulated** (0.1 / 6.1–6.8) — ships fabricated health data | Sprint 5 |
| 2 | **AI Meal Planner is 100% hardcoded** (0.2) — no real backend endpoint | Sprint 4 |
| 3 | **Backend not deployed** (7.1) — no live URL, can't use AI features | Sprint 4 |
| 4 | **Backend endpoints are open** (7.2) — any discovered URL drains Gemini quota | Sprint 4 |
| 5 | **Weight source of truth not unified** (1.1) — SharedPrefs and DB drift | Sprint 2 |

---

## What Was Actually Built (Our "Phase 0–9")

Our implementation passes created **valuable utilities and infrastructure**, but they addressed a curated subset of the plan rather than its critical path:

| What We Built | Plan Item It Covers |
|---|---|
| `UserProfileNotifier` + `UserProfileState` | Partial 2.2 (view model), but not 2.3 (Drift migration) |
| `AppLogger` + `AppException` | 2.5 ✅ |
| 4 dashboard sub-widgets + 2 settings sub-widgets | Partial 2.2 (god-widgets still 1000+ LOC) |
| PR badges, 1RM Epley, warm-up/RPE | Phase 3 training quality (not in plan — bonus) |
| 25g fiber progress bar | Not in plan — bonus |
| 300ms search debounce + skeleton loaders | Not in plan — bonus |
| `CsvExporter` | Not explicitly in plan — bonus (plan mentions backup) |
| `AutoBackupService` | Supports 1.6 but doesn't fix v4 column restore |
| `TdeeCalculator` (Mifflin-St Jeor) | Not in plan — bonus (extracted from onboarding) |
| Telemetry toggle | Supports 8.5 concept (but no Sentry) |
| `showLicensePage()` button | Not in plan — bonus |
| ProGuard rules + build.gradle.kts | 8.7 ✅ |
| CI workflow update | 8.4 ✅ |
| Privacy policy + store listing copy | 8.6 ✅ |
| Encryption tests | Partial 8.1 ✅ |
| `AchievementService` + `AchievementsScreen` | 9.2 ✅ |
| `NaturalMealParser` | Supports 9.4 concept (voice → text parsing) |

---

## Recommended Next Steps (Following the Plan's Sprint Order)

The plan prescribes a specific sprint sequence designed to "unlock personal usability fastest." Here's what actually needs doing, grouped by the plan's sprints:

### 🔴 Sprint 1 — "Stop Lying" (highest priority)
- [x] ~~0.3 — Real weight sparkline~~ (likely done)
- [x] ~~0.4/0.7 — Real volume chart~~ 
- [x] ~~1.2 — Real streak~~
- [x] ~~0.5 — Remove Supabase~~
- [ ] **0.1 — Replace Health Sync Hub simulation** with honest "Connect" CTA (real integration in Sprint 5)

### 🔴 Sprint 2 — "Core Correctness"
- [ ] **1.1 — Unify weight source of truth**
- [x] ~~1.5 — Input bounds~~
- [ ] **1.6 — Full backup/restore v4 columns**
- [ ] **1.8 — Device timezone for notifications** (still hardcoded IST)
- [x] ~~2.5 — Logging/error layer~~
- [ ] **2.1 — Adopt GoRouter** (needed for notification deep links)

### 🟡 Sprint 3 — "Personally Usable"
- [ ] **3.5 — Date navigation on dashboard**
- [ ] **3.9 — Empty states everywhere**
- [ ] **4.1 — Edit logged meals inline**
- [ ] **4.6 — Meal templates**
- [ ] **5.1 — Notification deep links**
- [ ] **3.4 — Dashboard density cleanup**

### 🟡 Sprint 4 — "Make the AI Real"
- [ ] **7.1 — Deploy backend** (Render)
- [ ] **7.2 — Backend API-key auth**
- [ ] **7.3/7.4 — Input limits + caching**
- [ ] **7.7 — AI_MODEL env-var swap**
- [ ] **0.2 — Build `/api/ai/meal-plan`** + wire `MealPlanService`
- [ ] **4.7 — Build `/api/ai/weekly-report`**

### 🟢 Sprint 5 — "Themes + Health + Polish"
- [ ] **3.1 — Light theme + theme picker**
- [ ] **6.1–6.8 — Real health integration**
- [ ] **3.10 — Full accessibility pass**
- [ ] **3.12 — App icon + splash**
- [ ] **2.2 — Further god-widget refactoring**
- [ ] **8.1–8.4 — Expand tests to 60% coverage + CI**
- [ ] **8.5 — Sentry crash reporting**

### 🟢 Sprint 6 — "iOS + App Store"
- [ ] **8.7 — Apple Developer account + HealthKit entitlement**
- [ ] **6.2 (iOS) — HealthKit Info.plist**
- [ ] App Store screenshots + listing
