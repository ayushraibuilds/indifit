# IndiFit — Ultimate Launch Readiness Plan

> **Purpose:** Transform IndiFit from a functional MVP into a launch-ready, personally-usable, polished product.
>
> This plan supersedes the gaps in `full_release_roadmap.md`. That roadmap marks Phases 0–7 as COMPLETED, but a source audit found several "completed" items are actually **mocks/stubs** (see Phase 0 below). This plan closes that truth gap and then layers on UX, correctness, and feature work.

---

## Locked Decisions (v1 scope)

These are settled by the user and drive the plan below.

| # | Decision | Implication |
|---|---|---|
| 1 | **Local-only for v1** | Remove Supabase auth + cloud sync code paths entirely. Re-add in a later major version. Ship as a pure offline-first app — this matches the brand and removes a large chunk of work/risk. |
| 2 | **Health integration now** | Build real Apple Health + Health Connect via the `health` package in v1. Replaces the simulated Health Sync Hub. |
| 3 | **Both light & dark theme** | Add `AppTheme.lightTheme` + a `themeModeProvider`. Default to system. |
| 4 | **Beta: you + friends/family → Play Store → App Store** | Three-stage rollout. Each stage has its own bar (see §Rollout Stages below). |
| 5 | **Backend not yet deployed** | Pick a free/cheap host now (see Phase 7.6). App must point at a real URL before any store build. |
| 6 | **Tiered AI model strategy** | Free models for beta/personal → cheap model at Play Store launch → frontier models later. See §AI Model Strategy. |

### Rollout Stages & their bars

- **Stage A — Personal / friends & family beta:** Core flows work, no mocks, real health sync, real backend (free tier). TestFlight internal + Play internal. No store listing yet.
- **Stage B — Play Store (open) launch:** Stage A + privacy policy, store assets, crash reporting, input validation, rate limits. Backend on a cheap/paid tier.
- **Stage C — App Store launch:** Stage B + Apple app-review compliance (HealthKit entitlement, ATT if applicable, screenshots for required device sizes, TestFlight public beta optional).

### AI Model Strategy (tiered)

| Stage | Model | Cost | Notes |
|---|---|---|---|
| Beta / personal | **Gemini 1.5 Flash** (free tier) or **Gemini 2.0 Flash** free tier | $0 | Keep calls within free quota. Cache aggressively. Backend returns `is_fallback=true` on quota errors. |
| Play Store launch | **Gemini 2.0 Flash-Lite** or **Gemini 1.5 Flash** paid | ~$0.10 / 1M tokens | Cheap, fast, good for structured JSON. Add per-user daily budget. |
| Future / frontier | **Gemini 2.5 Pro** / GPT-class for weekly reports & nuanced meal photo analysis | Higher | Gate behind a "Pro" flag or future subscription. |

> The backend must read the model name from env (`AI_MODEL`) so you can swap tiers without app changes.

---

## How to read this plan

Each item is tagged with:
- **P0 (Blocker)** — ships *wrong/misleading/unsafe* behavior. Must fix before launch.
- **P1 (High)** — meaningfully hurts usability or correctness. Fix before personal use.
- **P2 (Medium)** — polish, refactors, "would be nice" UX. Schedule after launch.
- **P3 (Low)** — nice-to-have, long-term vision.

Effort estimates are rough T-shirt sizes (XS / S / M / L / XL) for a single developer.

---

## Phase 0 — Truth Audit: Things the roadmap says are "done" but aren't

These are the highest-trust risks because they're *invisible* — the roadmap claims success, but the code ships mocks or placeholders.

### 0.1 — Health Sync Hub is fully simulated [P0] → **BUILD REAL NOW**
- **Claim:** "Phase 7: Native Health Integrations — Write production integrations for iOS HealthKit and Android Health Connect."
- **Reality:** `health_sync_hub_screen.dart` returns hardcoded `8450 steps / 320 kcal / 7.5h sleep` after a 2.2s fake delay. The "Native SDK" toggle just clears stats and shows "Coming Soon." **No `health` package exists in `pubspec.yaml`.** No native code.
- **Decision:** Per Locked Decision #2, **build the real integration now** using the [`health`](https://pub.dev/packages/health) package (covers both platforms). This is a P0 for v1, not deferred.
- **Implementation (see Phase 6 for detail):**
  1. Add `health: ^11.0.0` to `pubspec.yaml`.
  2. iOS: add `HealthKit` capability + `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` to `Info.plist`. Note: HealthKit requires a **paid** Apple Developer account ($99/yr) — this collides with Stage A personal testing. Workaround: gate health behind Stage B (Play Store first), ship Stage A without health, or use the free sideload without health for iOS beta.
  3. Android: add Health Connect permissions + `<queries>` to `AndroidManifest.xml`. Health Connect works without a paid account.
  4. Replace `HealthSyncHubScreen` simulation UI with real read/write flow.
- **Stage note:** Because HealthKit needs a paid dev account, the iOS path effectively starts at Stage C. Stage A/B on iOS ships without health; Android gets health from Stage A.

### 0.2 — AI Meal Planner is 100% hardcoded [P0] → **BUILD THE ENDPOINT**
- **Claim:** README says "compile weekly report summaries"; planner implies AI generation.
- **Reality:** `ai_meal_planner_screen.dart` contains `_mockWeeklyPlan` — 7 days of hardcoded meal strings. `_generatePlan()` just `await Future.delayed(2s)`. No backend call. The grocery list is hardcoded too.
- **Decision:** Build a real `/api/ai/meal-plan` endpoint (Gemini-based). Keep the mock **only as the offline fallback** when the backend is unreachable — same pattern already used by `ai_routine_service.dart`.
- **Implementation:**
  1. Backend: add `/api/ai/meal-plan` taking `{calorie_goal, diet_preference, days: 7}` and returning structured JSON (`days[].{breakfast,lunch,dinner,snacks}` + aggregated `grocery_list[]`).
  2. App: create `MealPlanService` (mirror `AiRoutineService`'s try-online-then-fallback shape). Replace `_mockWeeklyPlan` with the live response, fall back to it on error.
  3. Surface `is_fallback` badge ("Offline Sample Plan" vs "AI-Generated") so users know which they're seeing.

### 0.3 — Dashboard weight sparkline uses fake data [P0]
- **Reality:** `_buildWeightSparklineCard()` (`dashboard_screen.dart:1118`) plots hardcoded `[75.8, 75.5, 75.2, 74.9, 74.7]` + current weight. Real `BodyMeasurements` exist in the DB and are already used on the Progress screen.
- **Fix:** Replace with actual measurements from `workoutRepositoryProvider.getBodyMeasurements()`. Falls back to "Log your first weight" empty state.

### 0.4 — Progress volume chart shows hardcoded "+25% intensity" [P1]
- **Reality:** `_buildVolumeChartCard()` label is always "+25% intensity" regardless of data. Falls back to fake `[850, 920, 1050, 1180]` spots when no sessions exist.
- **Fix:** Compute real % change between first and last session. Show empty state instead of fake data.

### 0.5 — Supabase code is dead weight [P0] → **REMOVE FOR V1**
- **Claim:** "Phase 6: Identity & Rate Limits — Require active user credentials."
- **Reality:** `main.dart` initializes Supabase only if env vars are present; `SyncManager` silently returns when `currentUser?.id == null`. There is **no login/signup screen anywhere**. Cloud sync can never actually run.
- **Decision:** Per Locked Decision #1, **remove all Supabase/sync code for v1.** This simplifies the app, removes a broken code path, and matches the "local-only" branding honestly.
- **Removal checklist:**
  1. Delete `lib/data/repositories/sync_manager.dart`.
  2. Remove `syncManagerProvider` init from `main.dart` and the `supabase_flutter` import / `Supabase.initialize` block.
  3. Remove `supabase_flutter` from `pubspec.yaml`.
  4. Drop the `isSynced` columns' usage in UI/logic (keep the columns in the DB schema so future migration is clean — just stop reading/writing them).
  5. Keep `uuid` columns (already added in v4 migration) — harmless, future-proof.
  6. Update README "Backend API Sync" bullet to "Local-only (v1). Cloud sync planned for a future version."
- **Future re-add:** When ready (post-v1.x), re-introduce Supabase auth UI + sync manager as a clean, tested feature. Keep a `docs/sync-design.md` stub noting the deferred design.

### 0.6 — CI pins Flutter 3.19.6 but `pubspec.yaml` requires SDK `^3.11.1` [P1]
- **Reality:** `.github/workflows/ci.yml` uses Flutter 3.19.6 (Dart ~3.4), but `environment.sdk: ^3.11.1` implies a much newer toolchain (Dart 3.11+ doesn't exist on Flutter 3.19). The `just_audio: ^0.9.37`, `flutter_local_notifications: ^17.1.2`, and other recent versions suggest a newer SDK is actually in use locally.
- **Fix:** Update CI Flutter version to match local (likely 3.27+). Verify `flutter analyze` passes on CI. Currently CI may be silently broken or using fallback.

### 0.7 — `_buildVolumeChartCard` hardcoded fallback spots [P1]
- Same root as 0.4 — when `_sessions.isEmpty`, chart shows fake progression instead of an empty state.

**→ Takeaway:** Phase 0 is the most important work. A user who logs real data and then sees fake weight charts, fake step counts, and fake AI meal plans will not trust the app. **Fix or remove every mock before launch.**

---

## Phase 1 — Correctness & Data Integrity (P0/P1)

### 1.1 — Unify weight source of truth [P0]
- **Problem:** Weight lives in *two places*: `SharedPreferences.current_weight` (dashboard quick-adjust, onboarding) and `BodyMeasurements` table (progress screen). They drift.
- **Fix:** Make `BodyMeasurements` the canonical source. `current_weight` in prefs becomes a cache of the latest measurement. Whenever a measurement is logged, also write prefs. Dashboard quick-adjust should insert a `BodyMeasurement` row.
- **Effort:** M

### 1.2 — Streak count is hardcoded `?? 3` and never updated [P0]
- **Reality:** `dashboard_screen.dart:62` reads `prefs.getInt('streak_count') ?? 3` but **nothing ever writes `streak_count`**. The "3d" badge is effectively a static lie.
- **Fix:** Compute streak from workout sessions (consecutive days/weeks with a logged session) or from "days with any food log." Store nothing — compute on load. Show 0 honestly when there's no streak.

### 1.3 — Adherence score ignores rest days and goal type [P1]
- **Reality:** `_calculateWeeklyAdherence` counts any day without food logs as a miss. Someone legitimately fasting or with rest days gets penalized.
- **Fix:** Only count days the user has logged *at least one meal* as "active days." Optionally weight by goal (maintenance vs cut vs bulk tolerance).

### 1.4 — `nameHindi` null handling in search [P1]
- **Reality:** `food_repository.dart:27` does `tbl.nameHindi.lower().contains(...)`. If `nameHindi` is null, SQLite `LOWER(NULL)` returns NULL and `LIKE '%x%'` won't match — this is *probably* fine in SQLite, but it's fragile and untested.
- **Fix:** Add `OR tbl.nameHindi IS NULL` guard or `coalesce`. Add a unit test with a null-Hindi food item.

### 1.5 — No bounds checking on workout inputs [P1]
- **Reality:** `WorkoutPlayerScreen._completeSet` only checks `weight <= 0 || reps <= 0`. A typo of `1000` reps or `500` kg silently logs garbage that then becomes a "PR."
- **Fix:** Add sane upper bounds (e.g., weight ≤ 500kg, reps ≤ 100). Confirm with a dialog if exceeded.

### 1.6 — Restore backup doesn't restore v4 columns [P1]
- **Reality:** `_performRestore` in `settings_screen.dart` inserts rows without `uuid`, `mealGroupId`, `rpe`, `isWarmUp`, `setNotes`. Restored data loses these fields and re-sync attempts will regenerate UUIDs.
- **Fix:** Export and restore all columns including v2/v3/v4 additions. Bump export `version` to 2 and version-gate the restore logic.

### 1.7 — `generateRoutine` Dio created per-call without sharing config [P2]
- **Reality:** `AiRoutineService` has a class-level `_dio`, but `AiMealLoggerScreen` and others instantiate `Dio()` ad-hoc inside methods, bypassing timeouts and interceptors.
- **Fix:** Inject a shared, configured Dio instance via Riverpod provider with timeouts and a logging interceptor (debug only).

### 1.8 — Notification timezone hardcoded to IST [P1]
- **Reality:** `NotificationService.initialize` calls `tz.setLocalLocation(tz.getLocation('Asia/Kolkata'))`. Non-Indian users get notifications at wrong local times.
- **Fix:** Detect device timezone via `DateTime.now().timeZoneName` and resolve to a tz location. Fall back to IST only if lookup fails.

---

## Phase 2 — Architecture & Maintainability (P1/P2)

### 2.1 — Remove unused `go_router` dependency OR adopt it [P1]
- **Problem:** `go_router: ^13.2.0` is in `pubspec.yaml` but never imported. Navigation is all imperative `Navigator.push`.
- **Decision required:** Either (a) remove it to reduce bundle size and confusion, or (b) adopt it for named routes + deep linking (needed for notification taps → specific screens).
- **Recommendation:** Adopt it. Notification taps currently just `debugPrint` the payload — with GoRouter you can deep-link `indifit://workout` etc. This unblocks Phase 5.4 (notification deep links).
- **Effort:** M

### 2.2 — Split god-widgets into view models + sub-widgets [P1]
- **Worst offenders:**
  - `dashboard_screen.dart` — 1,285 lines
  - `settings_screen.dart` — 1,203 lines
  - `workout_player_screen.dart` — 928 lines
- **Fix:** Extract business logic into Riverpod `StateNotifier`/`Notifier` view models. Extract reusable UI into separate widget files (e.g., `dashboard/calorie_ring_card.dart`, `dashboard/water_card.dart`, `dashboard/meal_log_section.dart`). Target ≤300 LOC per file.
- **Why:** Enables unit testing of the logic and hot-reload-safe UI iteration. This is the single biggest maintainability win.
- **Effort:** L (do incrementally, one screen at a time)

### 2.3 — Move onboarding/user-profile data from SharedPreferences to Drift [P2]
- **Problem:** Calorie goals, user profile, water config all live in `SharedPreferences` — untyped, no migrations, no relations, no queries.
- **Fix:** Add a `UserProfile` table (singleton row) and `AppSettings` table. Migrate prefs → DB on first run of new version. Keep prefs only for truly ephemeral flags (`onboarding_completed`).
- **Effort:** M

### 2.4 — ~Fix N+1 query in `SyncManager._syncWorkoutSessions`~ [N/A — moot]
- **Originally:** loop fetched sets per-session inside the sync loop.
- **Resolution:** Per Decision #1, `SyncManager` is being deleted entirely (Phase 0.5). This item no longer applies. If/when sync is re-added post-v1, write it correctly from the start with a single `WHERE session_id IN (...)` query.

### 2.5 — Introduce a typed error/logging layer [P1]
- **Problem:** Every `catch (e) {}` is empty or `debugPrint`. No crash reporting, no structured errors, no user-facing error UI beyond SnackBars.
- **Fix:**
  1. Add `LoggerService` (Riverpod provider) wrapping `package:logging`.
  2. Define `AppException` subtypes (`NetworkException`, `DbException`, `ValidationException`).
  3. Add a global `ErrorHandler.widget` that catches builder errors and shows a recovery UI.
  4. Optional: Sentry integration (Phase 8.3).
- **Effort:** M

### 2.6 — Tighten `analysis_options.yaml` [P2]
- **Current:** Default `flutter_lints` only.
- **Fix:** Enable `prefer_single_quotes`, `require_trailing_commas`, `avoid_print`, `unawaited_futures`, `cascade_invocations`, `directives_ordering`. Run `dart fix --apply`. Blocks new god-widgets and unawaited futures from sneaking in.

---

## Phase 3 — UI/UX Upgrades (P1/P2)

### 3.1 — Add light theme + theme toggle [P1] → **COMMITTED (Decision #3)**
- **Current:** Dark theme only (`AppTheme.darkTheme`). Users who prefer light mode get a jarring experience.
- **Decision:** Build both. Default to `ThemeMode.system`.
- **Implementation:**
  1. Add `AppTheme.lightTheme` mirroring the dark `ColorScheme` with light-appropriate surfaces (e.g., `background: Color(0xFFF8FAFC)`, `cardBackground: Color(0xFFFFFFFF)`, `textPrimary: Color(0xFF0F172A)`). Reuse the same `primary` green.
  2. Define a `ColorScheme`-aware palette — replace direct `AppColors.textPrimary` references in widgets with `Theme.of(context).colorScheme.onSurface` where the contrast actually flips. Many widgets hardcode `Colors.white` text which will be unreadable on light theme — audit each.
  3. Add a Riverpod `themeModeProvider` (`StateNotifier<ThemeMode>`) persisted to SharedPreferences.
  4. Wire into `MaterialApp`: `theme: AppTheme.lightTheme, darkTheme: AppTheme.darkTheme, themeMode: ref.watch(themeModeProvider)`.
  5. Add a theme picker in Settings (System / Light / Dark) — radio group or segmented control.
  6. Audit hardcoded `Colors.white`, `Colors.black54`, `withOpacity` usages — these are the main theme-break points.
- **Effort:** M (the theme itself is S; the hardcoded-color audit is the bulk of the work)

### 3.2 — Replace brittle `WidgetsBinding.instance.toString().contains('Test')` [P1]
- **Reality:** `app_theme.dart:60` detects tests by stringifying the binding. Brittle and will break.
- **Fix:** Use `kDebugMode` + a flag passed via `MediaQuery` or `ProviderScope` overrides. Or use `GoogleFonts.config.allowRuntimeFetching = false` at app start (already done in tests).

### 3.3 — Fix `GoogleFonts.outfit()` being called in every `build()` [P2]
- **Reality:** Onboarding screen calls `GoogleFonts.outfit().fontFamily` dozens of times per build, each allocating.
- **Fix:** Set font once in `ThemeData.textTheme` (already done at top level) and remove per-widget `fontFamily` overrides. Cache as `static const`.

### 3.4 — Dashboard information hierarchy and density [P1]
- **Current:** Dashboard has 8+ stacked cards — calorie ring, nutrition review, quick actions, today workout, adherence, 4 meal cards, water, weight. It's a long scroll.
- **Fix:**
  - Collapse "Today's Workout" + "Quick Actions" into one hero card.
  - Move "Daily Nutrition Review" detail into a tap-to-expand on the calorie ring.
  - Consider a tabbed "Meals | Workouts | Body" sub-nav inside the dashboard for density.
  - Add a sticky date header so users can navigate to past days (currently dashboard is *today only* — a real limitation).
- **Effort:** L

### 3.5 — Add date navigation (view past/future days) [P1]
- **Problem:** Dashboard hardcodes `DateTime.now()`. You can't review yesterday's logs or pre-log tomorrow.
- **Fix:** Add a date picker / swipeable day header. `watchLogsForDay(selectedDate)`. Critical for real personal use.
- **Effort:** M

### 3.6 — Workout player: plate calculator integration [P2]
- **Observation:** `ExerciseHistoryScreen` already has a great plate calculator. But during a workout you can't access it without leaving the player.
- **Fix:** Add a "Plates" icon button on the weight input row that opens the plate calc bottom sheet pre-filled with current target weight.

### 3.7 — Rest timer: add skip-set / edit-next-set inline [P2]
- **Current:** Rest timer is a blocking modal. You can't preview/edit the next set while resting.
- **Fix:** Show next-set preview (weight/reps) inside the rest sheet so users can adjust during rest.

### 3.8 — Onboarding: skip-ahead nav and validation [P2]
- **Current:** Linear 8-page wizard, no per-page validation, no jump-to-page.
- **Fix:** Allow tapping progress dots to jump back. Validate age/height/weight ranges before advancing. Persist partial progress so a crash doesn't lose data.

### 3.9 — Empty states and zero-data onboarding [P1]
- **Problem:** First-time users see empty charts, "Rest Day" with no routine, 0 calories, hardcoded streak `3d`. The app looks broken on first launch.
- **Fix:** Show friendly empty states with CTAs ("Generate your first workout split," "Log your first meal"). Compute streak from real data (shows `0d` honestly). Drive users to the AI routine wizard from the dashboard if no routine exists.

### 3.10 — Accessibility audit [P2] (roadmap claims done, verify)
- Verify every `IconButton` has `tooltip`.
- Verify `Semantics` labels on charts (fl_chart is not screen-reader friendly by default).
- Test with TalkBack/VoiceOver.
- Test text scaling at 1.5× and 2×.
- Ensure 44dp minimum tap targets (some `IconButton` constraints are removed via `BoxConstraints()`).

### 3.11 — Haptic feedback consistency [P3]
- **Current:** Vibration only on PR. Water/meal logging has no feedback.
- **Fix:** Light haptic on log actions, medium on set complete, heavy on PR.

### 3.12 — App icon and splash screen [P2]
- **Current:** Default Flutter icon (`@mipmap/ic_launcher`). Splash is a plain background.
- **Fix:** Use `flutter_launcher_icons` and `flutter_native_splash` packages. Design a dumbbell/leaf mark matching the green primary.

---

## Phase 4 — Feature Additions for Real Personal Use (P1/P2)

### 4.1 — Edit/delete logged food entries inline [P1]
- **Current:** You can delete a food log row, but can't *edit* macros/serving after logging.
- **Fix:** Long-press or tap a logged item → edit sheet (reuse the serving-multiplier sheet from `food_search_screen`).

### 4.2 — Copy meal to different day / meal type [P2]
- **Current:** "Repeat last meal" only repeats same meal type.
- **Fix:** "Copy to…" action that lets you duplicate a meal to another day or meal slot.

### 4.3 — Custom routine builder (manual, non-AI) [P2]
- **Current:** Routines only come from the AI wizard or "repeat last workout." Power users want to build their own.
- **Fix:** A routine editor screen: name, days, add/remove exercises, set/rep targets. Save to `WorkoutRoutines`.

### 4.4 — Exercise set types: drop sets, super sets, AMRAP [P2]
- **Current:** Sets are flat (weight × reps, warm-up bool, RPE).
- **Fix:** Add `setType` enum (`working`, `warmup`, `dropset`, `failure`, `amrap`). Render differently in player + summary.

### 4.5 — Bodyweight / cardio / non-weighted exercises [P2]
- **Current:** Every set requires `weight > 0`. Push-ups, planks, running can't be logged properly.
- **Fix:** Allow `weight = 0` for bodyweight. Add duration-based logging for cardio (minutes + distance).

### 4.6 — Meal templates / saved meals [P2]
- **Current:** "Repeat last meal" works, but you can't save a named combo ("My standard breakfast").
- **Fix:** `MealTemplates` table. Save current meal group as template. One-tap log from dashboard.

### 4.7 — Weekly AI report generation [P2] (notification exists, generator doesn't)
- **Current:** Sunday 10 AM notification fires, but tapping it does nothing. No report is generated.
- **Fix:** Add `/api/ai/weekly-report` endpoint. Generate a report screen (calories avg, workout volume trend, PRs hit, adherence, AI coaching tip). Link notification tap → report screen.

### 4.8 — Data import from other apps (CSV / Apple Health) [P3]
- **Long-term:** Let users migrating from MyFitnessPal / HealthKit import history. Lower priority for v1.

### 4.9 — Reminders for rest-day mobility / active recovery [P3]

---

## Phase 5 — Notifications, Deep Links, Background (P1/P2)

### 5.1 — Notification taps should navigate [P1]
- **Current:** `_onNotificationTapped` just `debugPrint`s. Tapping "Log your lunch" does nothing.
- **Fix:** Use GoRouter (Phase 2.1) to deep-link: `meal_lunch` → food search for lunch; `workout` → routine display; `weekly_report` → report screen.

### 5.2 — Notification permission flow on iOS [P1]
- **Current:** iOS requests permission at init via `DarwinInitializationSettings(requestAlertPermission: true, …)`, which is the old eager pattern.
- **Fix:** Use `requestPermissions()` explicitly *after* user opts into a reminder in Settings (just-in-time), not at app start.

### 5.3 — Reschedule on boot / timezone change [P2]
- **Current:** `RECEIVE_BOOT_COMPLETED` permission exists but no boot receiver re-schedules.
- **Fix:** Wire a boot-completed receiver to call `NotificationService.scheduleAllReminders()`. Listen to timezone changes.

### 5.4 — Background sync on connectivity [P2]
- **Current:** `SyncManager` listens to `Connectivity().onConnectivityChanged`. Good, but only runs while app is alive.
- **Fix:** Use `workmanager` for periodic background sync (if cloud sync is kept in v1).

### 5.5 — Local push for in-workout rest timer when app backgrounded [P3]
- **Current:** Rest timer only works while sheet is open.
- **Fix:** Schedule a local notification when rest ends if the user backgrounds the app.

---

## Phase 6 — Real Health Integration [P0, COMMITTED for v1 per Decision #2]

> This is no longer "deferred." Per Decision #2 it ships in v1. Platform asymmetry: Android gets it from Stage A; iOS needs a paid dev account so effectively starts at Stage C.

### 6.1 — Add `health` package
- Add `health: ^11.0.0` (or latest) to `pubspec.yaml`.
- The `health` package unifies Apple HealthKit (iOS) and Health Connect (Android) behind one Dart API.

### 6.2 — Platform configuration
- **iOS** (`ios/Runner/Info.plist`):
  - Add `NSHealthShareUsageDescription` ("IndiFit reads steps, workouts, and weight to enrich your dashboard.")
  - Add `NSHealthUpdateUsageDescription` ("IndiFit writes workouts and weight so your other health apps stay in sync.")
  - Enable the **HealthKit** capability in Xcode (requires paid Apple Developer account — this is why iOS health effectively starts at Stage C).
- **Android** (`AndroidManifest.xml`):
  - Add Health Connect permissions: `android.permission.health.READ_STEPS`, `health.READ_ACTIVE_CALORIES`, `health.READ_SLEEP`, `health.READ_WEIGHT`, plus `WRITE_*` counterparts for write-back.
  - Add `<queries>` for the Health Connect package so Android 11+ can see it.
  - Add an intent-filter / activity alias for Health Connect data types if you want IndiFit to appear as a data source in Health Connect's UI.

### 6.3 — Permissions UX (just-in-time)
- Follow the existing rationale-dialog pattern (`food_search_screen._showBarcodePermissionRationale`).
- In `HealthSyncHubScreen`: a "Connect Apple Health / Health Connect" button → rationale dialog → `health.requestAuthorization()`.
- Never request at app start. Always after a user action.

### 6.4 — Data types to sync
- **Read:** `HealthDataType.STEPS`, `ACTIVE_CALORIES_BURNED`, `SLEEP_ASLEEP`, `WEALTH` (note: iOS spelling), `HEIGHT`.
- **Write:** `WORKOUT` (map each logged `WorkoutSession` to a Health workout), `WEIGHT` (on body-measurement save).
- Android uses `HealthConnectDataType` enum; the `health` package normalizes most of this.

### 6.5 — Two-way sync design
- **Read:** Steps/active cals/sleep → new "Today's Activity" card on the dashboard.
- **Write:** On workout-save success and body-measurement-save, fire-and-forget write to Health.
- Store a sync cursor in a new `HealthSyncState` table (or SharedPreferences): `{lastReadAt, lastWorkoutSyncedSessionId}` so you don't re-read/write duplicates.

### 6.6 — Replace `HealthSyncHubScreen` simulation UI
- Delete `_isSimulating`, `_simulatedSteps`, `_simulatedCalories`, `_simulatedSleep`, and the 2.2s `Future.delayed`.
- New states: (a) not connected → "Connect" CTA, (b) connected + syncing → spinner, (c) connected + synced → real stats + "Last synced 2m ago" + "Sync now" button, (d) permission denied → re-request CTA.
- If health is unavailable on the platform (e.g., iOS without paid account in Stage A), show an honest "Not available on this device/build" message.

### 6.7 — Dashboard integration
- New card "Today's Activity": steps ring, active calories, sleep hours. Pulled from health on dashboard load (cache to avoid repeated reads).
- Fold active calories into the calorie ring (optional: show "eaten / burned / net" on the dashboard calorie section).

### 6.8 — Tests
- Mock `health` package in tests (it has a test helper). Verify the sync-state machine, not real device data.

---

## Phase 7 — Backend Hardening & Deployment [P0/P1]

> Per Decision #5, backend is not deployed yet. Per Decision #6, model tier escalates by stage. Phase 7 makes the backend real and safe.

### 7.1 — Pick a host and deploy (Stage A) [P0]
- **Recommended: Render** (free tier for web services, easy FastAPI deploy via `render.yaml`, sleeps after 15 min idle on free tier — fine for personal/beta).
- **Alternatives:** Fly.io (more config, no sleep but needs credit card), Railway (clean UX, ~$5/mo credit), Koyeb (free tier).
- **Steps:**
  1. Add `render.yaml` or `Dockerfile` to `backend/`.
  2. Add `uvicorn main:app --host 0.0.0.0 --port $PORT` start command.
  3. Set secrets: `GEMINI_API_KEY`, `AI_MODEL` (default `gemini-2.0-flash`), `ALLOWED_ORIGINS`.
  4. Deploy → note the URL (e.g., `https://indifit-ai.onrender.com`).
- **App side:** set `BACKEND_API_URL` via `--dart-define` in release builds. Keep `10.0.2.2:8000` for Android-emulator dev.

### 7.2 — Backend authentication [P0, before any public URL]
- **Current:** `/api/ai/*` is fully open. A discovered URL drains your Gemini quota instantly.
- **Fix:** Shared API key.
  - Backend: `x-indifit-key` header checked via a FastAPI dependency. Key from env `INDIFIT_API_KEY`.
  - App: `AppConfig.apiKey` from `--dart-define=INDIFIT_API_KEY=...`. Dio interceptor injects the header on every request.
  - Rotate the key per stage (different key for beta vs production).
- Add `slowapi` for per-IP rate limiting (e.g., 30 AI calls/hour/IP) as a second defense layer.

### 7.3 — Input validation and size limits [P1]
- Cap photo upload at 5 MB (`UploadFile` size check during read).
- Validate MIME type ∈ {image/jpeg, image/png, image/webp}.
- Sanitize/limit text input length (≤ 500 chars for meal descriptions, ≤ 2000 for injuries).
- Pydantic models already exist for routine/meal — add for meal-plan and weekly-report endpoints.

### 7.4 — Caching and cost control [P1]
- **In-memory TTL cache** (e.g., `cachetools`) keyed by request hash for routine + meal-plan generation. Same inputs → same output within 24h. Cuts Gemini calls dramatically.
- Per-IP daily budget counter (in `slowapi` or a simple SQLite log). Return HTTP 429 + `is_fallback=true` to app when exceeded.
- Log `model`, `prompt_tokens`, `response_tokens` per call to a cheap log sink (console on free tier; Better Stack / Logtail on paid).

### 7.5 — Streaming responses [P2]
- Routine generation can take 10–20s. Use Gemini's `streamGenerateContent` + FastAPI `StreamingResponse` + Dio stream on the client. Show progressive UI ("Generating day 3…").

### 7.6 — Observability [P1]
- `GET /health` → `{status: ok, gemini_configured: bool, model: str}`.
- Structured logs (JSON) for every request: endpoint, latency, status, fallback_used.
- Free uptime monitor: UptimeRobot pinging `/health` every 5 min.

### 7.7 — Model-tier swap mechanism [P1]
- `AI_MODEL` env var read at request time. Endpoints choose the model:
  ```python
  MODEL = os.getenv("AI_MODEL", "gemini-2.0-flash")
  url = f"...models/{MODEL}:generateContent?key=..."
  ```
- **Stage A (beta):** `gemini-2.0-flash` free tier (or `gemini-1.5-flash` if free quota is better for your use case).
- **Stage B (Play Store):** same model, paid tier — predictable latency, no quota cliff.
- **Stage C+ (App Store / future):** optionally bump routine generation to `gemini-2.5-pro` for richer plans, keep meal-photo on Flash for speed/cost.
- No app change required to swap — purely backend env.

---

## Phase 8 — Testing, CI, Launch Prep (P0/P1)

### 8.1 — Unit tests for pure logic [P0]
- **Targets (no Flutter needed, fast):**
  - `EncryptionHelper.encrypt/decrypt` round-trip, wrong password, corrupt input, header tamper.
  - Onboarding BMR/TDEE/macro math in `_completeOnboarding` (extract to a pure function first).
  - `WorkoutRepository` 1RM Epley calculation + PR detection.
  - `WaterNotifier.checkMidnightReset` across date boundaries.
  - Food search with null `nameHindi`.
  - Streak calculation (added in Phase 1.2).
  - `MealPlanService` online→offline-fallback branch (mock Dio).
  - `HealthRepository` sync-state machine (mock `health` package).
- **Note:** sync/UUID tests removed (Decision #1 dropped Supabase). Keep `uuid` columns in schema for future use but they need no tests now.
- **Goal:** ≥60% line coverage on `lib/core` and `lib/data`.
- **Effort:** L

### 8.2 — Widget tests for critical flows [P1]
- Onboarding end-to-end → verify prefs written.
- Dashboard renders with empty DB (zero-data state).
- Food search → log → appears in meal card.
- Workout player → complete one set → summary → save → session in DB.
- Backup export → restore round-trip.
- **Effort:** L

### 8.3 — Integration test for DB migrations [P1]
- Test v1→v2→v3→v4 upgrade path with fixture databases. The migration code in `app_database.dart` has never been verified.
- **Effort:** M

### 8.4 — Fix CI [P0]
- Update Flutter version in `ci.yml` to match local (Phase 0.6).
- Add `dart format --set-exit-if-changed` check.
- Add `flutter test --coverage` and upload coverage report.
- Cache Drift build_runner output.
- Run `dart run build_runner build` in CI to verify generated code is in sync.

### 8.5 — Crash reporting [P1, Stage B gate]
- Integrate **Sentry** (better Flutter story than Crashlytics) with privacy-preserving config: no PII, scrub `Dio` request bodies before send, opt-in toggle in Settings (default off for beta, default on for store with disclosure).
- The roadmap claims "privacy-preserving crash reporting" but nothing is in `pubspec.yaml` yet.
- **Stage A:** skip (personal testing, you'll see crashes locally).
- **Stage B (Play Store):** required before open launch.
- **Effort:** S

### 8.6 — Privacy policy and store assets [P1, Stage B gate]
- **Privacy policy** (draft aligned to Decisions #1 and #2):
  - "All fitness, food, workout, and body data is stored locally on your device. IndiFit does not upload, sync, or back up this data to any server in v1."
  - "AI features (meal estimation, routine generation, weekly reports) send your text descriptions or food photos to IndiFit's backend, where they are processed by a third-party AI provider (Google Gemini) and **not stored**. Images are discarded immediately after estimation."
  - "Health data (steps, workouts, weight) is read from and written to Apple Health / Health Connect **on-device only** — it never transits IndiFit's servers."
  - "Crash reports (if you enable them) are sent to Sentry and contain no personal data."
- App Store / Play Store screenshots. **Required device sizes:** Android (phone + 7" + 10" tablet if supported), iOS (6.9" / 6.7" / 6.1" / 5.5", iPad 13" if supporting tablet).
- App description copy, short description, feature graphic (Play), app preview video (optional but strong).
- Store-listed permission justifications (camera, photos, notifications, HealthKit/Health Connect).

### 8.7 — App signing and versioning [Stage-gated]
- **Android (Stage A → B):**
  - Stage A: sideload debug/release APK directly to testers.
  - Stage B: generate a **real release keystore** (the CI dummy is not for production), store securely (NOT in git — use a secrets manager or encrypted upload to Play Console). Set up Play App Signing.
  - Bump `pubspec.yaml` version per release; Play Console versioning is auto-derived.
- **iOS (Stage A → C):**
  - Stage A: free Personal Provisioning sideload (per README), 7-day cert expiry, max 3 apps/device. **HealthKit unavailable** on free accounts — health features stay off on iOS until Stage C.
  - Stage C: **$99/yr Apple Developer Program** required. Real signing, HealthKit entitlement, push (if added later), TestFlight. This is the gating cost for iOS launch.

### 8.8 — Beta trial [P2, Stage A → B transition]
- **Stage A (friends/family, 5–10 testers):** distribute APK + sideloaded iOS. Track manually: crashes via adb/Xcode console, AI fallback rate, notification delivery, sync cursors.
- **Stage B prep:** recruit via Play Console internal testing track (up to 100 testers). Track: crashes (Sentry), ANRs, AI quota burn, uninstall signals, review feedback.
- **Success bar for moving A → B:** zero P0 crashes for 7 days, all core flows verified on at least 3 Android device sizes, AI fallback rate < 20% of calls.
- **Success bar for moving B → C (iOS):** Play Store rating stable ≥ 4.0, no critical regressions, backend stable for 30 days, Apple Developer account secured.

---

## Phase 9 — Delight & Polish (P3, post-launch)

- Confetti animation library (real, not just an emoji overlay).
- Achievement system (first PR, 7-day streak, 1000kg total volume).
- Streak freeze / pause.
- Voice input for meal logging ("I ate 2 rotis and dal").
- Offline-cached exercise videos (currently YouTube thumbnails fetched online — broken offline).
- Multi-language UI (Hindi UI strings, not just Hindi food names).
- Wear OS / Apple Watch companion for rest timer + set logging.

---

## Suggested Execution Order

> Sequenced to **unlock personal usability fastest**, then build outward, aligned to the rollout stages (A: personal/family → B: Play Store → C: App Store).

### Sprint 1 — "Stop lying" (1–2 days) 🔴
Make the app honest. **All P0 truth-audit fixes that don't depend on backend.**
1. Phase 0.3 — Real weight sparkline from `BodyMeasurements`.
2. Phase 0.4 / 0.7 — Real volume chart, no fake fallback.
3. Phase 1.2 — Real streak calculation.
4. Phase 0.5 — **Remove Supabase/sync code** (Decision #1).
5. Phase 0.1 — Replace Health Sync Hub simulation with an honest "Connect" state (the real integration lands in Sprint 5; until then the screen shows a connect CTA, not fake numbers).

### Sprint 2 — "Core correctness" (3–5 days) 🔴🟡
1. Phase 1.1 — Unify weight source to `BodyMeasurements`.
2. Phase 1.5 — Input bounds on workout/food entries.
3. Phase 1.6 — Full backup/restore columns (v4 schema).
4. Phase 1.8 — Device timezone for notifications.
5. Phase 2.5 — Logging/error layer.
6. Phase 2.1 — Adopt GoRouter (needed for notification deep links in Sprint 3).

### Sprint 3 — "Personally usable" (3–5 days) 🟡
1. Phase 3.5 — Date navigation on dashboard (past/future days).
2. Phase 3.9 — Empty states everywhere (no more fake numbers on first launch).
3. Phase 4.1 — Edit logged meals inline.
4. Phase 4.6 — Meal templates.
5. Phase 5.1 — Notification deep links via GoRouter.
6. Phase 3.4 — Dashboard density cleanup.
7. **→ Stage A checkpoint:** ship to yourself + friends/family on Android (APK sideload) and iOS (free personal provisioning, no health yet).

### Sprint 4 — "Make the AI real + deploy backend" (3–4 days) 🟡
1. Phase 7.1 — Deploy backend to Render (free tier), set secrets.
2. Phase 7.2 — Backend API-key auth (before any public URL).
3. Phase 7.3 / 7.4 — Input limits + caching + daily budget.
4. Phase 7.7 — `AI_MODEL` env-var swap mechanism; set to free-tier Flash.
5. Phase 0.2 — Build `/api/ai/meal-plan`, wire `MealPlanService` (online + offline fallback).
6. Phase 4.7 — Build `/api/ai/weekly-report` + report screen + wire Sunday notification tap to it.

### Sprint 5 — "Themes + Health + Polish" (5–7 days) 🟢
1. Phase 3.1 — Light theme + theme picker (Decision #3).
2. Phase 6.1–6.8 — Real health integration (`health` package, Android-first; iOS gated behind paid account).
3. Phase 3.10 — Accessibility pass.
4. Phase 3.12 — App icon + splash.
5. Phase 2.2 — Refactor god-widgets (dashboard + settings at minimum).
6. Phase 8.1–8.4 — Tests + CI fix.
7. Phase 8.5 — Crash reporting (Sentry, opt-in).
8. Phase 8.6 — Privacy policy + Play Store assets.
9. **→ Stage B checkpoint:** Play Store open launch.

### Sprint 6 — "iOS + App Store" (3–5 days) 🟢
1. Phase 8.7 — Paid Apple Developer account, real signing, HealthKit entitlement.
2. Phase 6.2 (iOS half) — Enable HealthKit, add Info.plist usage strings.
3. App Store screenshots (6.7", 6.1", 5.5", 12.9" iPad if supporting tablet).
4. App Store Connect listing, privacy "nutrition labels," ATT review if applicable.
5. TestFlight public beta (optional) → App Store review → **→ Stage C launch.**

### Sprint 7 — "Frontier AI upgrade" (post-launch, ongoing) 🟢
1. Flip `AI_MODEL` to a frontier tier for richer weekly reports / nuanced meal photo analysis.
2. Consider gating frontier features behind a future "Pro" tier.

---

## Quick-Reference: The Top 10 Must-Fix Before Launch

| # | Item | Why |
|---|------|-----|
| 1 | Replace fake Health Sync with real `health` integration (Phase 0.1 / 6) | Ships fabricated data labeled real |
| 2 | Build real `/api/ai/meal-plan` (Phase 0.2) | Planner is 100% hardcoded today |
| 3 | Real weight sparkline (Phase 0.3) | Shows fake progress over real data |
| 4 | Real streak count (Phase 1.2) | Always shows "3d" — a lie |
| 5 | Remove Supabase/sync dead code (Phase 0.5) | Sync can never run; clutters app |
| 6 | Unify weight source of truth (Phase 1.1) | Two sources drift |
| 7 | Deploy backend + add API-key auth (Phase 7.1–7.2) | No backend yet; open endpoints drain quota |
| 8 | Notification deep links (Phase 5.1) | Taps do nothing |
| 9 | Empty states + date navigation (Phase 3.5 / 3.9) | App looks broken on day 1; can't review past days |
| 10 | Unit tests for logic + CI fix (Phase 8.1 / 8.4 / 0.6) | Zero coverage; CI may be broken |

---

## Decisions Locked

All six scoping questions are settled (see "Locked Decisions" at the top of this plan):

1. ✅ **Local-only for v1** → remove Supabase.
2. ✅ **Health integration now** → build with `health` package (Android from Stage A, iOS from Stage C due to paid-account requirement).
3. ✅ **Light + dark theme** → build both, default to system.
4. ✅ **Rollout: friends/family → Play Store → App Store** → three stages with escalating bars.
5. ✅ **Backend not deployed** → deploy to Render free tier for beta, paid tier at store launch.
6. ✅ **Tiered AI models** → free Flash for beta → paid Flash-Lite at Play launch → frontier models post-launch. Controlled via `AI_MODEL` env var.

### Remaining minor decisions (decide as you encounter them, non-blocking)

- **App name on stores:** "IndiFit" vs "IndiFit — Indian Fitness Tracker" (ASO consideration).
- **Bundle IDs:** currently `com.indifit.IndiFit` — confirm before first store build. May want separate dev/prod IDs.
- **Minimum Android API level / iOS version:** drives Health Connect availability (Android API 26+ for Health Connect, iOS 13+ for HealthKit via the `health` package).
- **Whether to keep the "No Backend Mode" toggle in Settings** once backend is live (probably yes — for offline-purist users).
- **Sentry vs Crashlytics** for crash reporting (Sentry has a better Flutter story; Crashlytics ties into Google Play native crash reporting).
