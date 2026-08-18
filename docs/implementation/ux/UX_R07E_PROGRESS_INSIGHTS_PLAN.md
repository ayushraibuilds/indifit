# IndiFit R07E — Progress & Insights Implementation Plan

## 1. Executive Summary & Objective

Transform IndiFit's Progress tab from a sparse measurement screen into an evidence-driven, unified view of:
1. **Training Consistency** (workouts completed this week, week calendar strip, 4-week totals, recent sessions).
2. **Strength Progress** (recently trained exercises, latest performance, load-basis truthful metrics, canonical estimated 1RM, drill-down to Exercise History).
3. **Body Weight Progress** (latest weight, goal-direction alignment, truthful change windows, deterministic 3+ point chart).
4. **Nutrition Adherence** (weekly calorie and protein target adherence over logged days without punishing missing logs).

All insights are derived from canonical B02 (execution/sessions), B03 (nutrition consumption/targets), and B04 (goals/weight) authorities. No fabricated scores, fake streaks, or ungrounded predictions.

---

## 2. Architecture Audit

### 2.1 Authoritative Sources
* **Workouts & History (B02):** `WorkoutSessions` table (finalized sessions with `completedAt != null`), `WorkoutRepository.getSessions()`, `B02StrengthExecutionRepository`.
* **Performed Sets & Strength (B02):** `PerformedSets`, `PerformedExercises`, `WorkoutSessions` (working sets, actualLoadKg, actualReps, actualLoadBasis).
* **Exercise Performance Drill-Down (B02):** `B02ExercisePerformanceReadRepository.read(stableExerciseId)`, `ExerciseHistoryScreen`.
* **Volume (B02):** `WorkoutSessions.totalVolume`, calculated strictly for working sets with valid external loads (excluding bodyweight without external weight).
* **Estimated 1RM:** Epley formula `loadKg * (1 + reps / 30.0)` for sets with valid external load. Truthfully labeled as "Estimated 1RM".
* **Body Weight & Measurements (B04 / B02):** `BodyMeasurements` table, `WorkoutRepository.getBodyMeasurements()`, `WorkoutRepository.logWeightAndSyncProfile()`.
* **Weight Goals (B04):** `SharedPreferences` (`user_target_weight`, `user_goal`: loss, gain, maintenance) and `NutritionGoalRepository`.
* **Nutrition Adherence (B03 / B04):** `NutritionReadModelRepository.dailyTotals()` for daily intake (calories, protein, carbs, fat) and `NutritionGoalRepository.activeGoalForPrimaryProfile()` for canonical daily targets.
* **Achievements:** Secondary access via popup menu and secondary CTA (`AchievementsScreen`).

### 2.2 Reusable vs Missing Metrics
* **Reusable:**
  - `ProgressMeasurementRecord`, `ProgressWorkoutRecord`, `ProgressStrengthSetRecord`, `ProgressWeightGoal`.
  - `_dailyWeightObservations` grouping for multi-measurement days.
  - `LogWeightBottomSheet` for logging weight.
  - `ExerciseHistoryScreen` for exercise drill-down.
* **Added / Enhanced in R07E:**
  - `ProgressNutritionDaySummary` & `ProgressNutritionSummary` for weekly nutrition adherence.
  - `ProgressStrengthExerciseSummary` for ranking and displaying top recent exercises in Strength overview.
  - Compact Mon–Sun weekly training calendar strip.
  - Week consistency metrics (workouts this week, completed working sets this week, 4-week totals).

---

## 3. Sparse-Data Strategy & Deterministic Thresholds

* **0 observations (Empty state):** Friendly onboarding surface with quick actions: "Start workout", "Log weight", "Log food". No blank graphs.
* **1 observation:** Summary metric card with context. No line chart.
* **2 observations:** Two-point comparison (`79.8 → 79.4 kg` or `80 kg vs last session`).
* **3+ observations (Distinct local days):** Render interactive line chart with goal reference lines and date spacing.
* **Multi-domain independence:** If training and weight data exist but nutrition is sparse/absent, render Training and Weight in full and show a concise nutrition prompt without degrading the whole tab.

---

## 4. Progress Information Architecture

```
Progress Screen (Root)
├── Top AppBar (Title: "Progress", Menu: "Achievements")
├── RefreshIndicator / SingleChildScrollView
│   ├── Overview Card
│   │   ├── This Week's Training (workouts + compact week strip)
│   │   ├── Strength Highlight (recent heavy exercise + comparison)
│   │   ├── Weight Highlight (current weight + goal progress)
│   │   └── Nutrition Highlight (weekly adherence summary if logged)
│   │
│   ├── Training Consistency Section
│   │   ├── Workouts this week + compact Mon–Sun calendar strip
│   │   ├── 4-week training totals & completed sets
│   │   └── Recent workouts list (Tap -> Workout History screen)
│   │
│   ├── Strength Progress Section
│   │   ├── Top recently trained exercises (latest set, e1RM, trend)
│   │   └── Tap exercise -> Exercise History & Performance screen
│   │
│   ├── Weight & Body Progress Section
│   │   ├── Latest weight & Goal summary (loss/gain/maintain)
│   │   ├── Range selector (1M, 3M, 6M, 1Y, All)
│   │   ├── Sparse data comparison or LineChart (3+ points)
│   │   ├── Log Weight CTA
│   │   └── Body measurements summary (Waist, Chest, Arms) if present
│   │
│   └── Nutrition Adherence Section
│       ├── Weekly adherence metrics (days near target, protein met)
│       ├── 7-day compact status row (calories & protein)
│       └── Average daily intake vs canonical targets
```

---

## 5. Explicit Deferrals (R07F+)
* No composite "readiness score", "recovery score", or "fitness score".
* No predictive goal attainment date calculations.
* No body-fat estimations from BMI alone.
* No new PR celebration engine (historical bests shown truthfully).
