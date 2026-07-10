# Implementation Plan - Phase 6 Features & Hardening (Sprint 5)

This plan outlines the implementation of six advanced features and refinements for IndiFit.

## Proposed Changes

### 1. Water Tracker Refinements

#### [MODIFY] [dashboard_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/dashboard/dashboard_screen.dart)
- Check the current local date on load. Compare it to the shared preferences value `water_last_logged_date`.
- If the date has changed (local midnight passed), automatically reset `water_glasses` to `0` and update `water_last_logged_date` to today's date.
- Support reading `water_goal` from SharedPreferences (default to 8).

#### [MODIFY] [settings_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/settings/settings_screen.dart)
- Add a new input setting under Notifications for "Daily Water Goal (glasses)" to let users edit their hydration target.

---

### 2. Fast Daily Logging Shortcuts

#### [MODIFY] [food_repository.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/data/repositories/food_repository.dart)
- Add `getLastLoggedMeal(String mealType)` to retrieve the most recent food logs for a given meal category.

#### [MODIFY] [workout_repository.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/data/repositories/workout_repository.dart)
- Add `getLastCompletedSession()` to retrieve the most recently logged workout session and its sets.
- Add `duplicateSession(WorkoutSession session, List<WorkoutSet> sets)` to log a completed workout today with the same details.

#### [MODIFY] [dashboard_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/dashboard/dashboard_screen.dart)
- In the Today's Workout card, if a previous session exists, show a button **"Repeat Last Workout"** to instantly log the same sets for today.
- In each expansion meal card (Breakfast, Lunch, etc.), if empty, show a text button **"Repeat Last Breakfast/Lunch"** to copy yesterday's exact portions into today's log in one tap.

---

### 3. Per-Exercise History, 1RM Trend & Plate Calculator

#### [NEW] [exercise_history_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/exercise_library/exercise_history_screen.dart)
- A new details screen displaying:
  - **History List**: All logged sessions containing this exercise, ordered by date descending.
  - **1RM Progression Chart**: A line chart (`fl_chart`) plotting estimated 1RM over time (`weight * (1 + reps/30)`).
  - **Plate Calculator**: A utility tab where users input a target weight (e.g. 60kg). It subtracts a standard 20kg bar and lists the specific plates needed on each side (using denominations: 25, 20, 15, 10, 5, 2.5, 1.25 kg).

#### [MODIFY] [exercise_library_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/exercise_library/exercise_library_screen.dart)
- Route to `ExerciseHistoryScreen` when tapping an exercise card in the library.

---

### 4. Health Sync Hub & Encrypted Backups

#### [NEW] [health_sync_hub_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/settings/health_sync_hub_screen.dart)
- A dashboard screen inside Settings showing permissions status for Apple Health and Health Connect.
- Includes a toggled simulation mode for importing steps, active calories, and sleep statistics to demonstrate sync visual workflows securely offline.

#### [NEW] [encryption_helper.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/core/utils/encryption_helper.dart)
- Implement a password-based SHA256 key derivation stream XOR cipher to encrypt and decrypt JSON data string bundles.

#### [MODIFY] [settings_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/settings/settings_screen.dart)
- Add navigation to `HealthSyncHubScreen`.
- Modify "Export Backup" to prompt for an optional password and encrypt the output.
- Add a "Restore Encrypted Backup" button that prompts for password, decrypts, and seeds the Drift database tables.

---

### 5. AI Confidence Labels & Edit-Before-Save forms

#### [MODIFY] [ai_meal_logger_screen.dart](file:///Users/dankmagician/Documents/New%20project/indifit/lib/features/food_log/ai_meal_logger_screen.dart)
- Replace static text labels in the result section with text controllers (`_nameEditController`, `_caloriesEditController`, etc.) so the user can edit estimated portions inline before hitting "Verify & Save".
- Show a clear AI confidence label: `High (Live AI Estimate)` if `is_fallback` is false, and `Low (Offline Simulation)` if `is_fallback` is true.

---

### 6. Readme Claims Correction

#### [MODIFY] [README.md](file:///Users/dankmagician/Documents/New%20project/indifit/README.md)
- Correct the seeded food database claim from "500+ common Indian dishes" to "413 common Indian dishes" to accurately represent the seeded database size.

---

## Verification Plan

### Automated Tests
- Run `flutter analyze` and `flutter test` to ensure code robustness.

### Manual Verification
- Test password-based encrypted export and import, validating that correct decryption restores database logs successfully.
- Verify midnight reset logic by changing emulator system date manually and checking if water reset triggers.
