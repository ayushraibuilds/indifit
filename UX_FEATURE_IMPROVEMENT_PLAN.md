# IndiFit — 18-Point UX & Feature Improvement Plan

> **Created**: 2026-07-24
> **Status**: Planning — awaiting approval to begin execution
> **Estimated effort**: ~3–4 focused days for the 15 NOW items

---

## Scope Decisions (Confirmed)

- **Batch this pass** = Core 14 items. Music (#18) and form-video/animations (#14) are deferred to a follow-up.
- **Music**: future approach = embedded playlist picker (curated cards → deep-link to installed music app).
- **Form media**: future approach = Lottie/GIF animations (offline-capable).
- **Splits**: prebuilt templates + manual builder.
- All 18 are designed here; **14 are implemented now**, 2 deferred with stubs prepared, 2 fully deferred.
- Each item below is tagged **[NOW]**, **[STUB]**, or **[LATER]**.

---

## Batch 1 — Data Correctness Bugs (do first, unblocks testing)

### #2 — Exercise library empty for existing installs [NOW]

**Root cause**: `seedExercisesFromAsset()` (`app_database.dart:164`) uses raw `insertAll` in the `from < 11` migration. If any exercises already exist, the insert throws a `UNIQUE` constraint error, which the `catch (_) {}` silently swallows — so the library stays empty.

**Fix**:
- In `app_database.dart`, make `seedExercisesFromAsset` use the same **upsert-by-name** pattern already used by `upsertSeededFoodsFromAsset` (lines 108–150): fetch existing non-custom exercise names, insert only new ones, update changed fields.
- Bump `schemaVersion` 11 → 12 and add `if (from < 12) { await seedExercisesUpsert(); }` so every existing install gets the corrected seed.
- **Verify**: after upgrade, Exercise Library → search empty shows all 140 exercises.

| | |
|---|---|
| **Files** | `lib/data/database/app_database.dart` |
| **Effort** | S |

---

### #3 — BMI hardcoded to 170cm; height never reaches Progress [NOW]

**Root cause**: `progress_screen.dart:121` uses `const double heightCm = 170.0;`. Onboarding captures height into `SharedPreferences('user_height')` and `UserProfileNotifier`, but Progress doesn't read it.

**Fix**:
- Add `userHeight` to `DashboardState`/`UserProfileState` (it's already in prefs as `user_height`).
- In `progress_screen.dart`, read height via `ref.watch(userProfileProvider).userHeight` (default 170 if unset). Replace the hardcoded const and the "170 cm baseline" label with the real value.
- If height is 0/unset, show a gentle *"Set your height in onboarding/profile"* prompt instead of a wrong BMI.

| | |
|---|---|
| **Files** | `lib/features/progress/progress_screen.dart`, `lib/core/di/user_profile_provider.dart` |
| **Effort** | XS |

---

### #4 — Verify onboarding isn't broken [NOW — investigate]

Onboarding exists and writes `onboarding_completed`. I'll smoke-test the full flow (8 pages → calculate → dashboard) and fix any crash. Most likely issue: a controller/provider wiring regression after the recent refactor. If no bug found, mark resolved.

| | |
|---|---|
| **Effort** | XS–S |

---

## Batch 2 — UI/UX Layout & Theme Fixes

### #5 — Move Health Activity card to the bottom of the dashboard [NOW]

**Current**: `dashboard_screen.dart:242` — `TodaysActivityCard` sits between calorie ring and meals.

**Fix**: Reorder the dashboard `Column` children to: Header → StreakFreeze → CalorieRing → MealSection → TodayWorkout → Water → Weight → **TodaysActivityCard (last)**.

**Rationale**: not everyone has a watch/health data, so it's least important.

| | |
|---|---|
| **Files** | `lib/features/dashboard/dashboard_screen.dart` |
| **Effort** | XS |

---

### #6 — Light-mode contrast bugs (tabs, headers, split fonts) [NOW]

**Root cause**: `routine_display_screen.dart` has ~6 hardcoded `Colors.white` (lines 136, 219, 284, 293, 301…) for text/foregrounds that become invisible on the light theme's white surface.

**Fix**: Audit and replace hardcoded `Colors.white` with theme-aware values:
- Text on cards → `Theme.of(context).colorScheme.onSurface` or `AppColors.textPrimary` (already adapts via theme).
- Selected-tab text/icon → keep white only when the chip background is `AppColors.primary` (green); otherwise use `onSurface`.
- Sweep `routine_display_screen.dart`, `exercise_library_screen.dart`, `workout_player_screen.dart`, dashboard widgets for `Colors.white`/`Colors.white70` used as text color on adaptive surfaces.

| | |
|---|---|
| **Files** | `routine_display_screen.dart`, `exercise_library_screen.dart`, `workout_player_screen.dart`, dashboard widgets |
| **Effort** | M (mechanical sweep, ~15–20 sites) |

---

### #8 — AI Meal Estimator tile cut off in "Log Food Item" sheet [NOW]

**Root cause**: `dashboard_meal_section.dart:60` — `_showAddMealSheet` uses `showModalBottomSheet` with a `Column(mainAxisSize: min)` containing ~6 `ListTile`s + a dynamic "repeat recent" block, but **no `isScrollControlled: true`** and **no scroll wrapper**. On smaller screens the bottom tiles (Thali, AI Estimator) render off-screen and are unreachable.

**Fix**:
- Add `isScrollControlled: true` to the `showModalBottomSheet` call.
- Wrap the `Column` in a `SingleChildScrollView` (or convert to `ListView`) with `padding` including `bottom: MediaQuery.of(context).viewInsets.bottom`.
- Add a drag handle at the top.

| | |
|---|---|
| **Files** | `lib/features/dashboard/widgets/dashboard_meal_section.dart` |
| **Effort** | XS |

---

### #10 — Hydration default/adjustability [NOW — minor]

**Current**: `water_goal` defaults to 8 glasses × 250ml = 2000ml (not 2500ml). It IS adjustable in Settings. The 2500ml you saw is likely from onboarding TDEE calc.

**Fix**: Verify the water settings sub-screen (`water_settings_sub_screen.dart`) lets users set both glass count AND ml per glass (it does). Add a "recommended" hint based on bodyweight (35ml/kg). No structural change needed — confirm and close.

| | |
|---|---|
| **Effort** | XS |

---

### #16 — Prevent starting workouts for future dates [NOW]

**Current**: Dashboard date bar lets you navigate to any future date, and `_startTodayWorkout` doesn't check whether `selectedDate` is in the future.

**Fix**: In `dashboard_screen.dart` `_startTodayWorkout` (and the `TodayWorkoutCard` start callback), guard: if `state.selectedDate.isAfter(DateTime.now())` (ignoring time), show a SnackBar *"You can't start a future workout. Switch to today or log a past session."* Allow viewing future-day plans (read-only), but block the player launch. Past dates remain loggable via "Log Past Workout" (see #9).

| | |
|---|---|
| **Files** | `lib/features/dashboard/dashboard_screen.dart`, `lib/features/dashboard/widgets/today_workout_card.dart` |
| **Effort** | S |

---

## Batch 3 — Features: Splits, Workout Logging, Home Workouts

### #1 + #11 — Prebuilt split templates + functional manual builder [NOW]

This is the biggest item. Replaces the stub `RoutineEditorScreen` (which hardcodes one generic exercise per day) with a real system.

**New asset**: `assets/data/split_templates.json` — 6 ready-made splits:

| Template | Days |
|---|---|
| Push/Pull/Legs (PPL) | 3-day |
| Bro Split | 5-day (Chest / Back / Shoulders / Arms / Legs) |
| Upper/Lower | 4-day |
| Full Body | 3-day |
| Home Bodyweight | 3-day (no equipment — addresses #15) |
| Push/Pull/Legs | 6-day |

Each template: `{name, goal, days: [{name, dayOfWeek, isRestDay, exercises: [{name, sets, repsRange}]}]}`.

**New screen**: Replace `routine_editor_screen.dart` with a two-mode editor:
- **Templates tab** — cards for each preset, one-tap "Use this split" → calls existing `repo.saveRoutine(...)`.
- **Builder tab** — name field, add/remove days, per-day: add exercise (search the exercise library), set sets + reps range, reorder, mark rest day. Save via `repo.saveRoutine`.

**Entry point**: `RoutineDisplayScreen` empty state currently only offers "Generate Split with AI." Add a segmented control: `[AI Coach] [Templates] [Manual Build]`.

**Reuse**: `WorkoutRepository.saveRoutine` + `RoutineDayWithExercises`/`RoutineExerciseInput` already exist — no schema change needed.

| | |
|---|---|
| **Files** | new `assets/data/split_templates.json`, rewrite `routine_editor_screen.dart`, update `routine_display_screen.dart` empty state, add asset to `pubspec.yaml` |
| **Effort** | L |

---

### #9 — "Log today's/past workout" entry point [NOW]

**Current**: `TodayWorkoutCard` has Start + Repeat Last, but no explicit "log a workout I just did / did earlier."

**Fix**:
- Add a third action to `TodayWorkoutCard`: **"Log Completed Workout"** (icon: `edit_note`).
- Opens a lightweight **manual session logger sheet**: pick routine/day (or freeform), for each exercise enter weight×reps×sets quickly (reuse the `ExerciseSetInputCard` widget), enter duration, Save → `repo.logSession(...)`.
- If `selectedDate != today`, pre-fill `completedAt = selectedDate` so past workouts log to the right day (works with #16).

| | |
|---|---|
| **Files** | new `lib/features/workout_player/widgets/manual_log_sheet.dart`, update `today_workout_card.dart`, reuse `exercise_set_input_card.dart` |
| **Effort** | M |

---

### #15 — No-equipment / home workout path [NOW — partly via #1]

Resolved by: the **"Home Bodyweight 3-day"** template in #1, plus an equipment filter in the exercise library.

- Add an **equipment filter row** (`Barbell` / `Dumbbells` / `Bodyweight` / `Cables` / `Machine`) to `exercise_library_screen.dart` alongside the existing muscle filter (28 bodyweight exercises already exist in the data).
- In `OnboardingWizardScreen` equipment step, when user picks "bodyweight," the AI routine + template picker both surface the Home Bodyweight template first.

| | |
|---|---|
| **Files** | `exercise_library_screen.dart`, `onboarding_wizard_screen.dart`, (template from #1) |
| **Effort** | S |

---

## Batch 4 — Polish, Engagement, Timer Robustness

### #7 — Streak Freeze spammable (no cost/cooldown) [NOW]

**Current**: `StreakFreezeCard` → `controller.purchaseStreakFreeze()` adds a token with no cost. Default starts with 1 token.

**Fix**:
- Add a **cost**: each freeze costs streak-XP or requires earning it (e.g., *"Complete 3 workouts this week to earn 1 freeze"*). Simplest v1: cap at 2 freezes max, and each freeze requires logging a workout since the last claim (cooldown = 1 per 3 days).
- Track `lastFreezeClaimedAt` in `UserSettings` table (key-value, already exists at schema v10).
- Disable the claim button + show *"Next freeze available in X days"* / *"Max freezes reached"* instead of allowing infinite spam.

| | |
|---|---|
| **Files** | `dashboard_controller.dart`, `streak_freeze_card.dart`, UserSettings table |
| **Effort** | S |

---

### #12 — Achievements system [NOW — verify + expand]

**Current**: `AchievementService` (4 achievements) + `AchievementsScreen` exist and are routed. May be thin.

**Fix**:
- Expand to **~10 achievements** (first PR, 7/30-day streak, 1000/5000/10000kg total volume, 10/50/100 meals logged, first thali, first custom food, week consistency).
- Wire `AchievementService.evaluate(...)` into `DashboardController.loadStateData()` so unlocks trigger a toast/confetti when newly achieved (store `unlocked_achievement_ids` in UserSettings to detect new unlocks).
- Add an achievements entry point on the Progress screen (currently only reachable via router/deep link).

| | |
|---|---|
| **Files** | `achievement_service.dart`, `dashboard_controller.dart`, `progress_screen.dart` |
| **Effort** | M |

---

### #13 — Engagement & interactivity [NOW — light pass]

**Current**: Confetti (PR + dashboard), scan animation, haptics on PR exist.

**Fix (additive, not a rewrite)**:
- **Haptics** on common actions: light `HapticFeedback.selectionClick()` on water log, meal add, set complete, tab switch.
- **Streak milestone toast** when streak increments (e.g., *"🔥 7-day streak!"*).
- **Animated number transitions** on the calorie ring / macro bars (use `flutter_animate` — already a dep — for count-up).
- **Pull-to-refresh** on dashboard and progress screens.

| | |
|---|---|
| **Files** | `water_tracker_card.dart`, `calorie_ring_card.dart`, `dashboard_screen.dart`, `progress_screen.dart` |
| **Effort** | M |

---

### #17 — Timer pauses when app minimized / screen off [NOW]

**Root cause**: `WorkoutPlayerController` uses plain `Timer.periodic` (line 107). Dart timers don't fire while the OS suspends the app, so the elapsed-time clock drifts/freezes.

**Fix**:
- Track `_sessionStartedAt: DateTime` instead of (or alongside) counting ticks.
- Add `WidgetsBindingObserver` to the workout player screen. On `AppLifecycleState.resumed`, recompute `elapsedSeconds = _pausedElapsed + DateTime.now().difference(_sessionStartedAt)`. On paused, snapshot `_pausedElapsed`.
- Keep `wakelock_plus` (already a dep) enabled during the active workout so the screen stays on while the app is foregrounded.
- Optionally show a *"Workout was paused for X min while you were away — adjust?"* prompt on resume.

| | |
|---|---|
| **Files** | `workout_player_controller.dart`, `workout_player_screen.dart` |
| **Effort** | M |

---

## Deferred Items (acknowledged, minimal/no code now)

### #14 — Form depiction via Lottie/GIF [LATER]

**Why deferred**: Sourcing or creating ~140 animations is a large content effort, not a code task.

**Stub now**: Ensure `exercise_details_sheet.dart` gracefully handles a future `animationAsset` field (no crash if null). Keep the existing text form cues (present for all 140) as the baseline.

**Future**: Add `animation_asset` column to `Exercises`, bundle a starter set of ~20 Lottie files for the most common lifts, render via `Lottie.animations` (already a dep).

---

### #18 — Music integration (embedded playlist picker) [LATER]

**Why deferred**: Music + video deferred by design. Design is settled for when it returns.

**Future design**:
- Add a "Workout Music" FAB/icon in the workout player.
- Opens a bottom sheet with 4–5 curated workout playlists (*Beast Mode*, *Cardio*, *Cooldown*, *Focus*) stored as a small JSON asset (`{title, subtitle, spotifyUri, ytmusicUri, appleMusicUri}`).
- Tapping a playlist uses `url_launcher` to deep-link into whichever music app is installed (Spotify → `spotify:playlist/...`, YT Music → `ytmusic://`, Apple Music → `music://`).
- No in-app playback, no SDK, no licensing. Persists last-used choice.

---

## Summary Table

| # | Item | Status | Batch | Effort |
|---|---|---|---|---|
| 2 | Exercise library empty (seeding bug) | NOW | 1 | S |
| 3 | BMI hardcoded 170cm | NOW | 1 | XS |
| 4 | Onboarding broken? | NOW (investigate) | 1 | XS–S |
| 5 | Health card to bottom | NOW | 2 | XS |
| 6 | Light-mode contrast | NOW | 2 | M |
| 8 | AI estimator tile cut off | NOW | 2 | XS |
| 10 | Hydration default | NOW (verify) | 2 | XS |
| 16 | Block future-date workouts | NOW | 2 | S |
| 1+11 | Prebuilt splits + builder | NOW | 3 | L |
| 9 | Log completed/past workout | NOW | 3 | M |
| 15 | Home/bodyweight path | NOW | 3 | S |
| 7 | Streak freeze cost/cap | NOW | 4 | S |
| 12 | Achievements expand | NOW | 4 | M |
| 13 | Engagement pass | NOW | 4 | M |
| 17 | Timer lifecycle fix | NOW | 4 | M |
| 14 | Form Lottie/GIF | LATER | — | (content) |
| 18 | Music playlist picker | LATER | — | S (when resumed) |

---

## Execution Order

1. **Batch 1** (data bugs) — fixes #2, #3, #4. Unblocks real testing of everything else.
2. **Batch 2** (UI/UX) — #5, #6, #8, #10, #16. Quick, high visible impact.
3. **Batch 3** (features) — #1/#11 (splits), #9 (log workout), #15 (home). The meat of the work.
4. **Batch 4** (polish) — #7, #12, #13, #17.

> Run `flutter analyze` + `flutter test` after each batch. Add/extend tests for: exercise upsert seed, BMI calc, future-date guard, streak-freeze cooldown, timer resume math.

---

## Non-Goals (explicitly out of scope this pass)

- Full in-app music player (#18 future = playlist picker only).
- Creating/sourcing 140 exercise animations (#14 future).
- Cloud sync (removed for v1 per prior decision).
- Rewriting the navigation scaffold/bottom bar beyond minor animation.
