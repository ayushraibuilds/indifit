# UX R07F-2 Implementation Plan — Product Feel & Interaction Polish

**Branch**: `ux/r07f-product-feel`  
**Baseline**: `7632481` (`Merge R07F-1 training lifecycle`)  
**Scope**: Interaction feel, haptic policy, state transitions, reduced-motion compliance, and execution polish.

---

## 1. Ranked Improvement Scope (Frequency × Benefit × Safety)

| Rank | Surface / Improvement | Frequency | Perceptual Benefit | Regression Risk | Status |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **1** | **Centralized Haptic System (`IndiFitHaptics`)** | High | High | Low | In Scope |
| **2** | **Workout Player: Set Completion Tactile & State Polish** | Very High | Very High | Low | In Scope |
| **3** | **Workout Player: Rest Card & Action Controls** | High | High | Low | In Scope |
| **4** | **Workout Summary: Restrained Completion Delight** | Medium | High | Low | In Scope |
| **5** | **Today Dashboard: Smooth Calorie & Macro State Transitions** | Very High | High | Low | In Scope |
| **6** | **Food Logging: Fast Add & Saved Meal Re-log Tactile Feedback** | High | High | Low | In Scope |
| **7** | **Food Search: Multi-Select Batch Logging Feedback** | Medium-High | Medium-High | Low | In Scope |
| **8** | **Training Lifecycle: Finish & Leave Plan Feedback** | Medium | Medium | Low | In Scope |
| **9** | **Progress: Period Selector & Weight Log Feedback** | Medium | Medium | Low | In Scope |
| **10** | **B05 Motion Policy & Reduced-Motion Standardization** | Global | High | Low | In Scope |

---

## 2. Haptic Policy Definition

Centralized behind `IndiFitHaptics` in `lib/core/services/indifit_haptics.dart`:

1. **Selection (`selection()`)**:
   - *Pattern*: `HapticFeedback.selectionClick()`
   - *Use Cases*: Date/period selector switch (Progress 4W/3M/All), rest adjustment buttons (`+15s`, `-15s`, `Skip`), food multi-select checkbox toggle.
2. **Confirmation (`confirmation()`)**:
   - *Pattern*: `HapticFeedback.mediumImpact()`
   - *Use Cases*: Canonical set completion success, fast-add food log success, saved meal 1-tap re-log success, weight log save success, workout finish finalization, finish training plan success, rest timer completion.
   - *Rule*: Never fire on button tap *before* async operation succeeds. Only fire upon verified persistence success.
3. **Warning / Consequential (`warning()`)**:
   - *Pattern*: `HapticFeedback.heavyImpact()` or `vibrate()`
   - *Use Cases*: Leave Plan confirmed, Delete Saved Meal confirmed, Discard workout.
4. **Restraint & Exclusions**:
   - No haptic feedback on passive scrolling, navigation tab switches, textfield taps, or failed operations.

---

## 3. Motion Policy & Reduced-Motion Rules

- Every transition adheres to `B05MotionPolicy.reduceMotion(context)`.
- Standard transition duration: `180ms` (fast) to `300ms` (standard), `Duration.zero` when reduced motion is requested.
- Curve: `Curves.easeOutCubic` / `Curves.easeInOutCubic` (no bouncing, no elastic overshoot).
- State continuity: State transitions interpolate between previous known state $\rightarrow$ new state. No animation from 0 on ordinary widget rebuilds or screen visits.

---

## 4. Implementation Details by Surface

### A. Centralized Haptics (`IndiFitHaptics`)
- Implement `IndiFitHaptics` with static convenience methods and an injectable callback for testability.
- Silently handle missing plugin / platform unavailability.

### B. Workout Player & Set Completion (`B02StrengthPlayerScreen`)
- In `_record`, on verified persistence success: fire `IndiFitHaptics.confirmation()`.
- Active slot inputs reset cleanly without layout jumps.
- Rest +/- buttons (`+15s`, `-15s`, `Skip`, `Start rest`) fire `IndiFitHaptics.selection()`.
- Rest completion fires `IndiFitHaptics.confirmation()`.

### C. Workout Summary (`B02WorkoutCompletionSuccess`)
- Restrained checkmark scale/fade entrance (`B05MotionContent` / `TweenAnimationBuilder`).
- Staggered metric presentation for Duration, Sets, Volume (if applicable).
- No PR fanfare, no fake gamification.

### D. Today Dashboard (`TodayDailyActionSurface` & `CalorieRingCard`)
- Update `TweenAnimationBuilder` in `TodayDailyActionSurface` and `CalorieRingCard` to avoid `begin: 0` on rebuilds.
- Nutrition updates smoothly interpolate from previous progress to new progress.

### E. Food Logging & Saved Meals
- `FoodSearchScreen`: `_openLegacyFastAdd` and canonical direct add trigger `IndiFitHaptics.confirmation()` upon finalized consumption snapshot.
- `_toggleCanonicalSelection` triggers `IndiFitHaptics.selection()`.
- `_commitSelection` (batch add) triggers `IndiFitHaptics.confirmation()`.
- `SavedMealsScreen`: `_handleQuickLog` triggers `IndiFitHaptics.confirmation()`; `_handleDelete` triggers `IndiFitHaptics.warning()`.

### F. Training Plan Lifecycle
- `TrainingScreen` and `RoutineDisplayScreen`: `finishPlan()` triggers `IndiFitHaptics.confirmation()`; `leavePlan()` triggers `IndiFitHaptics.warning()`.

### G. Progress Screen
- `_WeightRangeSelector`: switching period triggers `IndiFitHaptics.selection()`.

---

## 5. Explicit Deferrals (Non-Goals for R07F-2)

- ❌ No PR / e1RM celebration engine (no canonical PR authority exists).
- ❌ No confetti or gamified badges.
- ❌ No new sound effects (rest timer audio remains untouched).
- ❌ No Hydration features or water cards.
- ❌ No social sharing cards or image generation.
- ❌ No full routing / global page transition rewrite.
- ❌ No physical device testing (deferred to product-owner acceptance).

---

## 6. Verification Plan

1. **Unit & Widget Tests**:
   - Test `IndiFitHaptics` trigger timing (only after canonical write).
   - Test Today calorie ring and macro bar state continuity and reduced-motion paths.
   - Test Workout player set completion and rest timer controls.
   - Test Workout summary completion presentation (no PR copy, no fabricated calories).
   - Test Food fast add, batch logging, and saved meal feedback.
   - Test Training plan Finish/Leave feedback.
2. **Regression Suite**:
   - Run `ux_r07f_product_feel_test.dart` (new).
   - Run `ux_r07f_training_lifecycle_test.dart` (R07F-1).
   - Run `ux_r07c_workout_experience_test.dart` and `ux_r07c_reliability_gate_test.dart`.
   - Run `ux_r07d_food_diary_logging_test.dart` and `ux_r07d_recipes_saved_meals_test.dart`.
   - Run `ux_r07e_progress_insights_test.dart`.
   - Run full serial test suite: `flutter test -j 1 --reporter compact`.
3. **Static Analysis & Build Checks**:
   - `dart format`
   - `flutter analyze --no-pub`
   - `git diff --check`
   - `flutter build ios --release --no-codesign --dart-define=INDIFIT_API_KEY=test_key`
