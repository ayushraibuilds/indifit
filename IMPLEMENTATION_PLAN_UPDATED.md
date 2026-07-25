# IndiFit — Updated Implementation Plan (Post-User Changes)

> Updated: 2026-07-24  
> Previous Plan: `IMPLEMENTATION_PLAN.md`  
> This document reflects the user's code changes and what remains.

---

## ✅ COMPLETED (User Implemented)

### Data Layer & Seeding
| # | Feature | Evidence |
|---|---------|----------|
| 1 | **Exercise library seeding fixed** | `app_database.dart` schema v12 + `upsertSeededExercisesFromAsset()` — idempotent upsert by name instead of silent-failing `insertAll` |
| 2 | **Preloaded workout templates** | `assets/data/split_templates.json` with 6 splits: PPL 3-day, Bro 5-day, Upper/Lower 4-day, Full Body 3-day, Home Bodyweight 3-day, PPL 6-day |
| 3 | **Manual split builder** | `routine_editor_screen.dart` — two-tab UI (Templates + Manual Builder) with full CRUD for days/exercises |
| 4 | **Routine display empty state expanded** | `routine_display_screen.dart` — empty state now shows "Generate with AI", "Templates", "Manual Build" |

### Dashboard & Food
| # | Feature | Evidence |
|---|---------|----------|
| 5 | **Meal cards color-coded** | `dashboard_meal_section.dart` — Breakfast=amber, Lunch=green, Dinner=indigo, Snacks=deepOrange |
| 6 | **Meal logging sheet overhauled** | `dashboard_meal_section.dart` `_showAddMealSheet` — shows "Repeat recent", "Search Food", "Meal Templates", "Thali Builder", "AI Meal Estimator" with text labels and icons |
| 7 | **Empty meal cards show quick actions** | Templates button + "Repeat Last" button surfaced when no items logged |
| 8 | **Health activity moved to bottom** | `dashboard_screen.dart` — `TodaysActivityCard` now renders below `WeightSparklineCard` |
| 9 | **Pull-to-refresh on Dashboard** | `RefreshIndicator` wrapped around `SingleChildScrollView` |
| 10 | **Future workout start blocked** | `_startTodayWorkout()` checks `selectedDay.isAfter(today)` and shows SnackBar |

### Progress & Analytics
| # | Feature | Evidence |
|---|---------|----------|
| 11 | **BMI uses actual height** | `progress_screen.dart` reads `userProfile.userHeight` from `userProfileProvider`; falls back to prompt if missing |
| 12 | **Achievements system wired** | `dashboard_controller.dart` `_evaluateAchievements()` calls `AchievementService.evaluateAchievements()` with 10 achievements |
| 13 | **Achievements accessible from Progress** | `progress_screen.dart` AppBar has `emoji_events_rounded` button → `AchievementsScreen` |
| 14 | **Pull-to-refresh on Progress** | `RefreshIndicator` on `ProgressScreen` |

### Workout Player
| # | Feature | Evidence |
|---|---------|----------|
| 15 | **Rest timer wakelock** | `rest_timer_bottom_sheet.dart` — `WakelockPlus.enable()` keeps screen on during rest |
| 16 | **Workout summary screen** | `workout_summary_screen.dart` — volume, duration, calories, grouped exercises, share via `share_plus` |
| 17 | **Manual past-workout logger** | `manual_log_sheet.dart` — bottom sheet to log completed sessions for any date with exercise picker and set editor |
| 18 | **"Log Completed Session" on dashboard** | `today_workout_card.dart` has "Log Completed Session" text button opening `ManualLogSheet` |

### Settings & Gamification
| # | Feature | Evidence |
|---|---------|----------|
| 19 | **Streak freeze capped** | `streak_freeze_card.dart` — button disabled at 2/2, `dashboard_controller.dart` `purchaseStreakFreeze()` enforces 3-day cooldown |
| 20 | **Water goal adjustable** | `water_settings_section.dart` — editable daily goal (1-40 glasses) and glass size (50-1000ml) with weight-based recommendation |
| 21 | **Light mode calendar fix** | `routine_display_screen.dart` — day number text color changed from `Colors.white70` to `AppColors.textPrimary` |

---

## 🟡 PARTIALLY DONE / NEEDS VERIFICATION

### 22. Onboarding Gate (Still Missing)
**Status:** Onboarding screen exists and collects height/weight, but `main.dart` does NOT check `onboarding_completed` before launching the app.  
**Files:** `lib/main.dart`, `lib/core/router/app_router.dart`  
**Fix:**
```dart
// main.dart
final prefs = await SharedPreferences.getInstance();
final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
// Pass to router or conditionally route
```

### 23. Floating-Point Weight Display
**Status:** `progress_screen.dart` `_buildBmiHealthCard` uses `toStringAsFixed(1)`, but the measurement list in `_buildMeasurementsHistoryCard` (line 404) also uses `toStringAsFixed(1)`. The bottom sheet in `_showLogMeasurementModal` uses `toStringAsFixed(1)`.  
**However:** The screenshots showed `76.49999999999989kg` which may have been from a build before these fixes, OR from `WeightSparklineCard` which was not checked.  
**Action:** Verify `lib/features/dashboard/widgets/weight_sparkline_card.dart` uses `toStringAsFixed(1)` everywhere.

### 24. Light Mode AppBar Colors
**Status:** `routine_display_screen.dart` calendar header fixed, but several screens still hardcode `backgroundColor: AppColors.background` on AppBar:  
- `progress_screen.dart:71` — `backgroundColor: AppColors.background`
- `exercise_library_screen.dart:92` — `backgroundColor: AppColors.background`  
- `workout_summary_screen.dart:62` — `backgroundColor: AppColors.background`
- `settings_screen.dart` — likely same issue  
**Fix:** Replace with `backgroundColor: Theme.of(context).colorScheme.surface` or remove (let theme handle it).

### 25. Rest Timer Background Persistence
**Status:** `WakelockPlus.enable()` keeps screen ON, but `Timer.periodic` still **pauses** when the app is backgrounded or the phone is locked. The `_secondsRemaining` is not persisted.  
**Files:** `lib/features/workout_player/widgets/rest_timer_bottom_sheet.dart`  
**Fix:** Save target end timestamp to SharedPreferences on init, read it on resume:
```dart
// In initState:
final prefs = await SharedPreferences.getInstance();
final savedEnd = prefs.getString('rest_timer_end');
if (savedEnd != null) {
  final end = DateTime.parse(savedEnd);
  final remaining = end.difference(DateTime.now()).inSeconds;
  if (remaining > 0) _secondsRemaining = remaining;
}
prefs.setString('rest_timer_end', DateTime.now().add(Duration(seconds: _secondsRemaining)).toIso8601String());

// On dismiss, clear the key:
prefs.remove('rest_timer_end');
```

### 26. Workout Player Timer Background
**Status:** `WorkoutPlayerController._startTimer()` uses `Timer.periodic` with `_sessionStartedAt` reference. When app backgrounds, the timer pauses. On resume, `syncElapsedOnResume()` recalculates from `_sessionStartedAt` — this is actually correct for elapsed time! The elapsed seconds will jump forward on resume because it computes `DateTime.now().difference(_sessionStartedAt)`.  
**Verdict:** This is actually fine for elapsed time tracking. The draft is saved after every set, so data loss is minimal.  
**However:** There's no `AppLifecycleListener` calling `syncElapsedOnResume()`. Need to verify if this matters.

---

## 🔴 REMAINING (Not Started)

### 27. Macro Visualization (Donut Chart)
**Priority:** High  
**Files:** `lib/features/dashboard/widgets/calorie_ring_card.dart`  
**Status:** Currently shows plain text (`0/120g`, `0/230g`, `0/65g`). The `fl_chart` package is already in pubspec.  
**Implementation:** Replace text-only layout with a `PieChart` (donut style) showing protein/carbs/fat caloric breakdown + remaining calories as grey segment.

### 28. Exercise Form Visuals
**Priority:** Medium  
**Files:** `lib/features/exercise_library/exercise_details_sheet.dart`  
**Status:** `Exercise` table has `formCues`, `commonMistakes`, and `youtubeId`. Need to verify `ExerciseDetailsSheet` renders these nicely.  
**Also needed:** Placeholder for embedded video/image. Use `url_launcher` to open YouTube if `youtubeId` is present.

### 29. Music Integration (Spotify / YT Music)
**Priority:** Low  
**Files:** New `lib/core/services/music_service.dart`  
**Status:** Not started.  
**Lightweight implementation:** Use `url_launcher` to open Spotify / YT Music apps. Add a floating action button in `WorkoutPlayerScreen`.
```dart
Future<void> openSpotify() async {
  final uri = Uri.parse('spotify:');
  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
}
```

### 30. PR Celebration Overlaps Rest Timer
**Priority:** Medium  
**Files:** `lib/features/workout_player/workout_player_screen.dart`  
**Status:** When PR hits, confetti overlay + dialog appear while rest timer bottom sheet also opens. Two modals compete.  
**Fix:** Queue PR celebration to show AFTER rest timer is dismissed, or show as a non-blocking banner.

### 31. No-Equipment AI Path
**Priority:** Medium  
**Files:** `backend/main.py`, `lib/data/repositories/ai_routine_service.dart`  
**Status:** Home bodyweight templates exist locally, but the AI generator backend always assumes gym equipment.  
**Fix:** Update backend prompt to handle `equipment: "none"` or `equipment: "bodyweight"`.

### 32. Quick-Log Bottom Sheet (Old File)
**Priority:** Low  
**Files:** `lib/features/dashboard/widgets/quick_log_bottom_sheet.dart`  
**Status:** Old file still exists with only 4 meal-type buttons. May be dead code.  
**Action:** Verify if it's still referenced anywhere. If not, delete it.

### 33. Weekly Focus Action Card Visibility
**Priority:** Low  
**Files:** `lib/features/dashboard/dashboard_screen.dart`, `lib/features/dashboard/dashboard_controller.dart`  
**Status:** `weeklyActionText` logic exists in controller but the card was not visible in screenshots.  
**Action:** Verify the card renders when `weeklyActionText != null`.

---

## 📋 Recommended Next Steps (Prioritized)

### Sprint A — Ship Blockers (Do First)
1. **Fix onboarding gate** (`main.dart` + `app_router.dart`) — prevents first-time users from skipping profile setup
2. **Verify weight `toStringAsFixed(1)`** across all display locations
3. **Fix light mode AppBar colors** on Progress, Exercise Library, Workout Summary screens
4. **Add rest timer background persistence** via SharedPreferences timestamp

### Sprint B — Visual & UX Polish
5. **Add macro donut chart** to calorie ring card (`fl_chart`)
6. **Fix PR + rest timer overlap** — queue celebration after timer dismiss
7. **Enhance exercise details sheet** with form cues, common mistakes, YouTube link
8. **Clean up dead `quick_log_bottom_sheet.dart`** if unused

### Sprint C — Nice-to-Have
9. **Music launcher** in workout player (Spotify / YT Music via `url_launcher`)
10. **Weekly focus action card** visibility audit
11. **Backend AI no-equipment path**

---

## 🎯 Acceptance Criteria (What's Actually Left)

| # | Item | Status | File |
|---|------|--------|------|
| 1 | Onboarding runs on first install | ❌ Not done | `main.dart` |
| 2 | Weight displays without float leak | ⚠️ Verify | `weight_sparkline_card.dart` |
| 3 | Light mode fully readable | ⚠️ Partial | `progress_screen.dart`, `exercise_library_screen.dart` |
| 4 | Rest timer persists when backgrounded | ⚠️ Partial | `rest_timer_bottom_sheet.dart` |
| 5 | Macro donut chart | ❌ Not done | `calorie_ring_card.dart` |
| 6 | Exercise form visuals | ❌ Not done | `exercise_details_sheet.dart` |
| 7 | Music integration | ❌ Not done | New file |
| 8 | PR/rest timer overlap | ❌ Not done | `workout_player_screen.dart` |
| 9 | AI no-equipment path | ❌ Not done | `backend/main.py` |
| 10 | Clean dead code | ❌ Not done | `quick_log_bottom_sheet.dart` |

---

> **You have implemented roughly 21 of the 33 identified items (~64%).**  
> The remaining work is primarily polish, visual upgrades, and edge-case handling.  
> **Want me to start on the ship blockers (onboarding gate + light mode fixes)?**
