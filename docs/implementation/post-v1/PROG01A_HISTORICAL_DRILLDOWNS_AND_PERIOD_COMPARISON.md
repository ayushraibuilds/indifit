# Historical Drill-Downs and Period Comparison Specification (PV1-PROG-01A)

**Author:** IndiFit Core Architecture  
**Status:** Approved / Active  
**Milestone:** Post-V1 Analytics Track — PV1-PROG-01A  
**Branch:** `codex/post-v1-net-01-capability-boundary`  

---

## 1. Executive Summary & Intent

In IndiFit, the **Progress** domain provides a truthful mirror of the user's logged habits across workouts, strength, body weight, and nutrition. Naive historical analytics often introduce subtle product falsehoods:
1. **Unbounded Historical Reads:** Loading the entire user history from SQLite into memory before filtering in Dart causes progressive performance degradation as months and years of data accumulate.
2. **Denominator Distortion:** Dividing aggregated metrics across arbitrary calendar windows treats unlogged days as 0 or artificially depresses averages, distorting nutrition and habit compliance.
3. **Synthetic Metrics:** Guessing 1-rep maximums (e1RM), fabricating calorie burns from exercise durations, or calculating composite "fitness/readiness" scores violates user trust and contradicts IndiFit's product truth policy.

`PV1-PROG-01A` specifies the formal contract for **bounded database queries**, **factual completeness states**, and **honest period comparisons** without synthetic scoring.

---

## 2. Supported Period Windows

To eliminate calendar-month variable-day denominator skew (28 vs 30 vs 31 days), comparative periods are restricted strictly to fixed-duration, like-for-like cycles:

| Range ID | Window Size | Current Period Definition | Prior Period (Comparison Baseline) |
|---|---|---|---|
| `PeriodComparisonRange.week` | **7 Days** | Current civil week (Monday 00:00 through Sunday 23:59) | Immediately preceding civil week (Monday through Sunday) |
| `PeriodComparisonRange.fourWeeks` | **28 Days** | Current 28-day training block (today minus 27 calendar days through today) | Immediately preceding 28-day training block (today minus 55 through today minus 28) |

All dates are resolved via canonical civil date authority (`LocalScheduleDateService`) using the user's explicit timezone (`timezoneId`). Wall-clock UTC offsets are never used to determine day boundaries.

---

## 3. Bounded Query Contract & Database Indexing

Every historical query must be bounded at the database level rather than filtered in application memory:

### 3.1 Workouts & Sessions
```sql
SELECT * FROM workout_sessions
WHERE completed_at >= :startUtc AND completed_at < :endExclusiveUtc
ORDER BY completed_at DESC;
```
- **Index Alignment:** Utilizes `idx_workout_sessions_activity_completed` on `(activity_type, completed_at)` or primary completion index.
- **Bound Computation:** `:startUtc` corresponds to the start of `startLocalDate` at 00:00:00 in `timezoneId`, converted to UTC. `:endExclusiveUtc` corresponds to the end of `endLocalDate` at 23:59:59.999 in `timezoneId`, converted to UTC.

### 3.2 Performed Strength Sets
```sql
SELECT ps.*, pe.*, ws.completed_at
FROM performed_sets ps
INNER JOIN performed_exercises pe ON pe.id = ps.performed_exercise_id
INNER JOIN workout_sessions ws ON ws.id = pe.session_id
WHERE ws.completed_at >= :startUtc AND ws.completed_at < :endExclusiveUtc
  AND ps.role = 'working'
  AND ps.actual_load_basis = 'totalExternal';
```
- Only sets with explicit `totalExternal` load basis are compared; bodyweight without added external load or non-standard baselines are excluded to prevent comparing unlike quantities.

### 3.3 Nutrition Daily Totals
- **Read Seam:** Queried through `NutritionReadModelRepository.dailyTotalsForLocalDates(userId: userId, localDates: periodLocalDates)`.
- Reuses the unified B03 consumption snapshot pipeline without scanning all historical table rows.

### 3.4 Body Measurements
```sql
SELECT * FROM body_measurements
WHERE recorded_at >= :startUtc AND recorded_at < :endExclusiveUtc
ORDER BY recorded_at DESC;
```

---

## 4. Completeness Rules & Denominator Truth

### 4.1 Completeness Classification
Every evaluated period is assigned an immutable `PeriodCompletenessStatus`:
- **`complete`**: The period window has fully concluded in civil time (e.g., *Last Week* or a prior completed 28-day cycle).
- **`inProgress`**: The period window includes the user's current civil date (`todayLocalDate`). Comparisons against a completed prior baseline must visibly disclose `In Progress (Day X of N)` so users are not misled by lower interim totals.
- **`sparse`**: Insufficient data points exist in the period to make an evidence-backed comparative claim (e.g., 0 workouts logged, or 0 days of nutrition recorded).

### 4.2 Denominator Rules by Domain

#### A. Nutrition Adherence
- **Logged Days vs Calendar Days:** Average calories and average protein are computed **strictly over logged days** ($N_{logged} \ge 1$), never over total calendar days ($7$ or $28$).
$$\text{Average Protein} = \frac{\sum_{d \in \text{LoggedDays}} \text{Protein}_d}{|\text{LoggedDays}|}$$
- **Missing Data:** An unlogged day is treated as **unknown**, never as 0 kcal or 0g protein.
- **Evidence Badge:** Every nutrition comparison card must display an explicit evidence tag: e.g. `4/7 days logged` vs `6/7 days logged`.
- If $|\text{LoggedDays}| = 0$, the metric is classified as `sparse` and averages are omitted.

#### B. Training Volume & Consistency
- **Event-Based Denominator:** Days with 0 completed workouts are true rest days (known zero sessions).
- **Volume Trustworthiness:** Total volume ($\text{kg}$) includes only sessions where `volumeIsTrustworthy == true` (external load verified). If a session contains unverified or incompatible loads, its volume is excluded from the comparative tonnage, but the workout count still increments.
- **Duration:** Total duration is summed across all completed sessions in the window.

#### C. Body Weight
- **Delta Threshold:** Calculating a truthful weight delta ($\Delta \text{kg}$) and rate of change ($\text{kg/week}$) requires $\ge 2$ distinct measurement days within the compared periods.
- **Single Observation:** If only 1 observation exists in a period, that point observation is displayed as `Latest: X kg` without an ungrounded delta or rate.

---

## 5. Non-Negotiable Invariants

1. **No Synthetic e1RM:** No 1-rep maximum calculations or estimated 1RM progression curves. Strength comparisons report strictly factual heaviest working sets (`loadKg × reps`).
2. **No Calorie Burn Estimation:** Workout sessions display completed duration and volume; the `estimatedCalories = 0` sentinel is preserved.
3. **No Composite Readiness/Fitness Score:** No arbitrary percentages or gamified wellness scores derived from incomplete activity data.
4. **Offline First:** All comparative calculations run locally against SQLite; no server round-trip or network access is required to compute or view historical drill-downs.
