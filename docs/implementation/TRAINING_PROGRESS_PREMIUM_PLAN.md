# Training and progress: premium feel and a weekly habit

**Status:** approved direction (Ayush, 2026-10-06) · **Owner:** Claude (code), Ayush (review, device feel checks) · **Last updated:** 2026-10-07 (tracker: PR-L, M and N merged)

Related:
- [LAUNCH_ROADMAP_FINAL.md](LAUNCH_ROADMAP_FINAL.md): launch gates, the ready queue (§ 2.5) and the hard rules (§ 0). This plan adds PR-L, M and N to v1; PR-O to PR-S go in the ready queue.
- [FINAL_LAUNCH_AUDIT_2026-10-05.md](../audit/FINAL_LAUNCH_AUDIT_2026-10-05.md): UX-05 (rest card), UX-21 (polish), shots 96–113.
- [NUTRITION_CATALOGUE_PACKS_PLAN.md](NUTRITION_CATALOGUE_PACKS_PLAN.md): the matching plan for food data.
- [REFERENCE_GUIDE_UPDATED.md](../reference/ui/REFERENCE_GUIDE_UPDATED.md) § 9–10: product principles and visual direction. This plan follows them.
- [R08_0_FINAL_PRE_IMPLEMENTATION_DECISION_REVIEW.md](r08/R08_0_FINAL_PRE_IMPLEMENTATION_DECISION_REVIEW.md) § 546–548: rejected synthetic PRs. **Amended on 2026-10-06 for factual bests** (§ 1 below).

---

## 0. Tracker

Update this table in every PR that touches training or progress UI. IDs are referenced from commits and the roadmap.

| ID | Work item | Release | PR | Depends on | Status |
|---|---|---|---|---|---|
| TP-1 | Factual-bests engine: derived from logged sets, never stored, never estimated | **v1** | L | — | Merged (#66) |
| TP-2 | Bests in the player: "New best" on the set row, success haptic, best shown next to "last time" | **v1** | L | TP-1 | Merged (#66) |
| TP-3 | Bests on the workout summary, share card and exercise history ("Best ever") | **v1** | L | TP-1 | Merged (#66) |
| TP-4 | Weekly training goal: goal source, goal history, weekly streak calculator | **v1** | M | — | Merged (#67) |
| TP-5 | Weekly goal on screen: Training week card, Progress consistency, summary line; daily streak off training surfaces | **v1** | M | TP-4 | Merged (#67) |
| TP-6 | Summary as the payoff: headline, "vs last time" per exercise, one celebration moment, "Total lifted" | **v1** | N | TP-3, TP-5 | Merged (#68) |
| TP-7 | Motion and haptics map: `success()` and `restEnd()` haptics, set-row tick, count-up numbers, reduce-motion tests | **v1** | N | — | Merged (#68) |
| TP-8 | Player sets as rows ("60 kg × 8 ✓"), no spreadsheet header; full workout title | Next | O | PR-D | Not started |
| TP-9 | Progress visuals: muscles-this-week body map, 12-week consistency heatmap (**Plus**, decided 2026-10-06); recent bests list (free) | Plus-gated (list: Next) | P | TP-1, TP-4; Plus entitlement | Not started |
| TP-10 | `animations` package: card-to-screen and between-exercise transitions | Next | P | — | Not started |
| TP-11 | Dependency housekeeping: remove `percent_indicator`; upgrade `fl_chart` when charts are touched | Next | P | — | Not started |
| TP-12 | Specific reminders: "Full Body B today. Last time: Leg Press 60 kg × 8" | Next | Q | TP-1 | Not started |
| TP-13 | Home-screen widget (`home_widget`): today's workout, week goal, kcal left | Next (native target) | R | TP-4 | Not started |
| TP-14 | Rest timer on the lock screen (`live_activities`) | When Apple enrolment is done | S | PR-D; Apple Developer Program | Blocked (needs the paid Apple account) |

Status values: Not started · In progress (PR #) · Merged (PR #) · Blocked (reason).

"Release" is a group, not a date. **v1** items ship in whichever tester or store build they're ready for. **Next** items can start as soon as their dependencies are met, during the closed test or after launch (roadmap § 2.5).

**Order inside v1:** L, then M, then N (N builds on both). Only the roadmap's hard rules apply: CI green, one PR per topic, the tracker updated, and a feature freeze about 3 days before a store submission build. *(The 20 Oct cut line was dropped on 2026-10-06.)*

---

## 1. Decision record

**Context (verified 2026-10-06)**
- The app logs sets well, but it never tells a lifter "you beat last time":
  - the player and Progress have no best or PR moment;
  - R08 deliberately rejected "synthetic e1RM" and "unsupported/synthetic PR events and celebration" ([R08_0 review:546-548](r08/R08_0_FINAL_PRE_IMPLEMENTATION_DECISION_REVIEW.md));
  - exercise history already shows a factual "Heaviest working set" ([exercise_history_screen.dart:685-698](../../lib/features/exercise_library/exercise_history_screen.dart)).
- The only streak is a daily activity streak: days with food or a workout ([streak_repository.dart:10-13](../../lib/data/repositories/streak_repository.dart)). Rest days are part of lifting, so a daily streak is the wrong habit signal for training.
- The workout summary (shot 110) is the flattest screen:
  - grey tiles;
  - an "External volume" label;
  - no comparison with last time.

  It should be the reward moment.

**Decisions (Ayush, 2026-10-06)**
1. **Factual best-ever sets ship in v1.**
   - A best is computed only from sets the user logged. Two kinds:
     - "Heaviest": the most weight lifted for the exercise;
     - "Most reps at this weight or more".
   - Never estimated: no e1RM, no formulas, no stored PR flag.
   - This amends R08_0 § 546–548. Synthetic e1RM stays rejected.
2. **Training uses a weekly goal, not a daily streak.**
   - Example: "2 of 3 workouts this week · 4 weeks in a row".
   - The daily streak stays on Today as "days logged", for food. It no longer shows on training surfaces.
3. **PR-L (bests), PR-M (weekly goal) and PR-N (summary payoff, motion and haptics) are v1.** They ship to testers as soon as they're merged. Everything else is in the ready queue, in any order.

**Why factual bests are safe now.** The R08 objection was to *invented* numbers and to a PR "event owner" that didn't exist. Factual bests are a derived read, like the existing "Heaviest working set":
- the same logged sets always give the same answer;
- editing or deleting a workout re-derives it;
- nothing new is persisted except "already celebrated" flags.

This is the "new product decision" that [post-v1-roadmap.md § 7](../roadmap/post-v1-roadmap.md) asks for. It does not reuse the removed inference code or the legacy `workout_sets.is_pr` column ([workout_tables.dart:68](../../lib/data/database/tables/workout_tables.dart)). Its only input is canonical B02 performed sets. A stored PR-event system, for sync or sharing, stays a separate later decision.

---

## 2. Goals and non-goals

**Goals**
1. Each workout ends with a clear, true reward: what you did, what improved, and where you stand this week.
2. Lifters have a reason to come back next session: beat a best, and keep the week goal.
3. The app feels premium through motion, haptics and layout, not decoration.
4. Nothing gets more complicated for a beginner. Every new element is either one line of data or one moment.

**Non-goals**
- No XP, levels, leaderboards or social feeds.
- No e1RM, strength standards, calorie burn or readiness scores.
- No confetti on every set and no sounds by default.
- No daily streak on training surfaces.
- No new database tables for bests or goals in v1.

**The rule of thumb: one moment of delight per loop.**

| Loop step | The single moment |
|---|---|
| Open Training | The week card: "2 of 3 this week" |
| Log a set | A tick and a light haptic. "New best" appears only when it's true. |
| Finish | The summary headline plus one celebration (bests or week goal) |
| Progress | The week ring and, with Plus, the muscles-this-week map |

---

## 3. What already exists (reuse, don't rebuild)

| Asset | Where | Use in this plan |
|---|---|---|
| Motion tokens: fast 160 ms, standard 240 ms, completion 360 ms; `easeOutCubic`; reduce-motion check | [b05_accessibility_primitives.dart:589-616](../../lib/core/widgets/b05_accessibility_primitives.dart) (`B05MotionPolicy`, 35 call sites) | All new motion uses these. No new durations. |
| `flutter_animate` 4.5 | `pubspec.yaml`; used only by [skeleton_loader.dart](../../lib/core/widgets/skeleton_loader.dart) | Set-row tick, staged summary cards |
| Confetti overlay that respects reduce motion | [confetti_overlay.dart](../../lib/core/widgets/confetti_overlay.dart), used by the achievement sheet | The one celebration per workout. **No new confetti package.** |
| Haptics service: selection, confirmation, warning; fires after persistence | [indifit_haptics.dart](../../lib/core/services/indifit_haptics.dart), about 16 call sites | Add `success()` and `restEnd()` |
| Per-exercise history read | [b02_exercise_performance_read_repository.dart](../../lib/data/repositories/b02_exercise_performance_read_repository.dart) | Input to the bests engine. It drops technique fields today (see TP-1). |
| Factual heaviest set and trend | [r08f3_strength_performance_presentation.dart](../../lib/features/progress/r08f3_strength_performance_presentation.dart) | The bests engine generalises it |
| Recap with previous-session comparison | [workout_completion_recap.dart](../../lib/features/workout_player/models/workout_completion_recap.dart) (`PreviousSessionComparison`) | Summary "vs last time" |
| Share card | [workout_share_card.dart](../../lib/features/workout_player/widgets/workout_share_card.dart) | Add a bests line |
| 9 achievements and the celebration sheet | `achievement_service.dart`, [achievement_celebration_sheet.dart](../../lib/features/workout_player/widgets/achievement_celebration_sheet.dart) | Kept; merged into one moment (TP-6) |
| Training week strip with scheduled days | [training_screen.dart:1447](../../lib/features/training/training_screen.dart) (`_TrainingWeekStrip`, Monday weeks) | Gains the goal ring |
| MuscleMap geometry (MIT, ported to Dart) | [indifit_muscle_map.dart](../../lib/features/media/indifit_muscle_map.dart), [provenance](../legal/MUSCLEMAP_GEOMETRY_PROVENANCE.md) | Muscles-this-week map (TP-9) |
| Display units Metric / Imperial | [unit_preference.dart](../../lib/features/settings/unit_preference.dart) | Bests compare in kg and display in the user's unit |

---

## 4. Factual bests (TP-1 … TP-3, PR-L)

### 4.1 Definitions

A set is **comparable** when all of these hold:
- its role is `working` (warm-ups never count);
- it has `actualReps ≥ 1`;
- it has no assistance, tempo, paused reps or segments (drop sets and rest-pause);
- its exercise occurrence status is `completed` or `partial`, and its session's `completionKind` is `full` or `partial`. These are the existing read filters.

Comparisons group by **`actualExerciseId` + `actualLoadBasis`**:
- what was actually performed counts, so a substitution counts toward the substitute;
- total load, per implement, per side and bodyweight are never compared with each other.

Two kinds of best:

| Kind | A set is a new best when … | Example copy |
|---|---|---|
| **Heaviest** | Its load is more than 0.1 kg above every earlier comparable set. Bodyweight basis counts only when added load is above 0. | "New best · Heaviest: 62.5 kg × 8 (was 60 kg × 10)" |
| **Most reps** | Its reps are higher than every earlier comparable set at the same load or heavier (within 0.1 kg) | "New best · 10 reps at 60 kg (was 8)" |

**Rules**
- **Baseline:** the first session with comparable sets for an exercise and basis sets the baseline and produces no bests. Copy: "First time logged. This is your baseline."
- **Ties are not bests.** The 0.1 kg tolerance absorbs lb→kg rounding: 135 lb = 61.235 kg.
- **Within a workout:** a set must also beat earlier sets in the same workout. If set 1 is 62.5 kg and set 3 is 65 kg, both get the badge; if set 2 is 62.5 kg again, it doesn't.
- **One badge per set:** Heaviest wins over Most reps.
- **Derived on read, never stored.** Edits and deletions re-derive. The only stored state is a SharedPreferences set of celebrated session ids (`training_bests_celebrated_v1`, last 200), so a summary reopened from history doesn't celebrate again.
- **Display:** values are kept in kg and shown in the user's units with the existing formatter.

### 4.2 Engine (TP-1)

- **New:** `lib/features/progress/training_bests.dart`.
  - Pure functions: `TrainingBests.evaluate(history, currentSession)` returns `List<TrainingBest>` (set id, kind, value, previous value, previous date).
  - No Flutter or database imports, so it's fully unit-testable.
- **Input:**
  - `B02ExercisePerformanceReadRepository.read()` must fill `technique` (assistance, tempo, pause, segments). Today `_toPerformedSet` leaves it empty ([b02_exercise_performance_read_repository.dart:92-121](../../lib/data/repositories/b02_exercise_performance_read_repository.dart)).
  - Without that fix, assisted or tempo sets would be compared as normal sets.
  - **Suspected:** the existing "Heaviest working set" on exercise history has the same gap. Check it in PR-L and fix it with the same change.
- **Provider:** `trainingBestsForExerciseProvider(exerciseId)` and `trainingBestsForSessionProvider(sessionId)`.
  - Reads are per exercise, so a 5-exercise workout makes 5 queries.
  - A test with 2 years of history (300 sessions) must evaluate in under 50 ms on desktop.

### 4.3 Where bests show

| Place | What | PR |
|---|---|---|
| Player set row | After the set is saved: a small "New best" chip with a trophy icon, a scale-in (`B05MotionPolicy.completionDuration`) and `IndiFitHaptics.success()`. Never on tap, only after persistence. | L (TP-2) |
| Player "last time" line | "Last time 60 kg × 8 · Best 62.5 kg × 8": data first, one line | L (TP-2) |
| Workout summary | A "New bests" block, top 3 plus "and 2 more", above the stats | L (TP-3) |
| Share card | One line: "2 new bests: Leg Press 62.5 kg × 8, …" | L (TP-3) |
| Exercise history | A "Best ever" card: heaviest and most reps at the top weights, with dates | L (TP-3) |
| Progress | Strength tile: "2 new bests this week". The recent-bests list follows with PR-P. | L (tile), P (list) |

---

## 5. Weekly training goal (TP-4, TP-5, PR-M)

### 5.1 Model (TP-4)
- **Week:** Monday to Sunday in device-local civil dates, as the Training week strip already uses.
- **What counts:** a saved workout session of any activity type (full or partial) on that local date. Several workouts on one day each count.
  - Check in PR-M: does `WorkoutRepository.getAllSessionDates()` only ever see saved sessions? It doesn't filter by `completionKind` ([workout_repository.dart:745](../../lib/data/repositories/workout_repository.dart)). Add a test either way.
  - *Answered in PR-M:* yes. Every `workout_sessions` insert is a finished workout (full or partial, or an import); unfinished workouts live in `workout_drafts`. `weekly_training_goal_repository_test.dart` covers it.
- **Goal:**
  - With an active plan: the number of scheduled sessions this week. The data is already loaded as `currentWeekOccurrences`.
  - Without a plan: the user's goal, 1–7 and default 3, set from the week card in one sheet.
  - No override of a plan's goal in v1, to keep it simple.
- **Goal history:**
  - SharedPreferences `training_week_goals_v1`: `{weekStart: goal}`, written the first time a week is seen.
  - Each past week is judged by its own goal, so changing the goal never rewrites history.
  - Weeks before the first entry use the first entry's goal.
- **Weekly streak:**
  - The number of consecutive finished weeks that met their goal, ending last week.
  - Plus the current week, once it is met.
  - The week in progress never breaks the streak.
- **Pure calculator:** `WeeklyTrainingGoalCalculator`, with tests next to `StreakCalculator`'s.

### 5.2 On screen (TP-5)

| Place | Change |
|---|---|
| Training "This week" card | A small ring "2 of 3" plus "4 weeks in a row" (hidden at 0). Trained days get a filled tick in the strip. The goal sheet is one tap away (no plan only). |
| Progress → Training consistency | Headline "2 of 3 this week · 4 weeks in a row", replacing "1 workout completed this week" |
| Workout summary | "2 of 3 this week". When this workout meets the goal: "Week goal done", which is the celebration in TP-6. |
| Today | The daily streak chip stays and is labelled "days logged" (food or workouts, unchanged maths). It does not appear on Training, the player, the summary or Progress → Training. |
| Achievements | `streak_7` and `streak_30` stay daily and unchanged. Weekly 4- and 12-week badges are decided as a Next item (§ 13). |

---

## 6. The workout summary as the payoff (TP-6, PR-N)

Order, top to bottom, all data first:
1. **Headline:** "Workout complete", then one line: "1,440 kg lifted · 3 sets · 2 min 48 s".
2. **The one moment:** if there are new bests, or the week goal was just met, show them here with the existing `ConfettiOverlay` and `IndiFitHaptics.success()`.
   - If an achievement sheet will also open, that sheet animates and the inline block stays still.
   - At most one burst per workout.
3. **New bests** (TP-3).
4. **Vs last time,** per exercise, one line each: "Leg Press: +2.5 kg on top set" or "same as last time". Uses `PreviousSessionComparison` and the bests engine.
5. **This week:** "2 of 3 workouts".
6. **What you logged** (exists), then Share and Done.

**Copy fixes**
- "External volume" becomes "Total lifted".
- The black check icon becomes the brand-colour check, with a completion scale-in.

---

## 7. Motion and haptics map (TP-7, PR-N)

**Motion.** Only `B05MotionPolicy` tokens, with everything instant when reduce motion is on.

| Element | Motion |
|---|---|
| Set logged | The row fills and ticks: scale 0.9 → 1 plus fade, `fastDuration` |
| New best chip | Scale-in, `completionDuration` |
| Summary numbers | Count up once, `completionDuration`. Final values are shown immediately with reduce motion. |
| Summary blocks | Staggered fade/slide 8 px, 40 ms apart, first view only |
| Week ring | Animates from the old value to the new one, `standardDuration` |

**Haptics.** These extend `IndiFitHaptics`. Every one fires after persistence, never on tap.

| Event | Haptic |
|---|---|
| Set saved | `confirmation()` (exists) |
| Rest ends (in app) | `restEnd()`: two light pulses |
| New best saved | `success()`: one medium pulse, then one heavy |
| Week goal met | `success()` |
| Discard or leave | `warning()` (exists) |

**Tests**
- With `debugHandler` (exists): each event emits exactly one haptic type, and none fires before persistence.
- With `MediaQuery(disableAnimations: true)`: no animation controllers run, and final values render on the first frame.

---

## 8. Next items (TP-8 … TP-14)

- **TP-8 Player sets as rows (PR-O).**
  - Replace the PLANNED / ACTUAL / STATUS header (shot 100) with rows such as:
    - "Set 2 · 8–12 reps",
    - a faint "last 60 × 8" under it,
    - the actual "60 kg × 8 ✓" once logged.
  - The title shows only the workout name ("Full Body A"), not "Beginner — 3-Day Fu…".
  - It goes after the closed test because it changes the most-used control, and #51 changed it recently.
- **TP-9 Progress visuals (PR-P):**
  - **Muscles this week:** the MuscleMap body front and back, shaded by working sets per muscle this week. It uses the local geometry, so no new licence. A tap shows the list. Today's muscle-balance section is text only ([progress_sections.dart:1065](../../lib/features/progress/widgets/progress_sections.dart)).
  - **12-week consistency heatmap:** a custom painter, one cell per day, ringed when the week met its goal. No package.
  - **Recent bests:** the last 5, linking to exercise history.
- **TP-10 `animations` (PR-P):** `OpenContainer` from the Today and Training workout cards into the player and summary, and a shared-axis transition between exercises in the player. All of it is turned off under reduce motion.
- **TP-11 Housekeeping (PR-P):**
  - remove `percent_indicator` (no imports anywhere);
  - upgrade `fl_chart` 0.67 → 1.x only together with chart work, because the API changes; refresh the goldens afterwards.
- **TP-12 Specific reminders (PR-Q):**
  - Workout reminder text names the session and last time's top set: "Full Body B today. Last time: Leg Press 60 kg × 8."
  - Evening nudge, only when the week goal is still reachable: "1 more workout to hit this week's goal."
  - Uses the existing `notification_service.dart` schedules. No new permissions.
- **TP-13 Home-screen widget (PR-R):**
  - Uses `home_widget`. Shows today's workout, "2 of 3 this week" and kcal left. It deep-links to the player or food search.
  - Needs a WidgetKit extension target (none today) and an Android AppWidget.
- **TP-14 Lock-screen rest timer (PR-S, once the Apple Developer Program is active):**
  - Uses `live_activities` for a Live Activity with the countdown plus Skip and +30 s.
  - This makes true the Live Activity claim the audit flagged.
  - Needs the paid Apple Developer Program and an extension target.

---

## 9. Libraries (checked on pub.dev 2026-10-06)

| Package | Version / date | Licence, publisher | Decision |
|---|---|---|---|
| `flutter_animate` | 4.5.2 · 2024-11-25 (repo pins ^4.5.0) | BSD-3, gskinner.com | **Use more** (v1) |
| `animations` | 3.0.0 · 2026-08-19 | BSD-3, flutter.dev | **Add with PR-P** (TP-10) |
| `home_widget` | 0.10.0 · 2026-09-17 | BSD-3 | **Add with PR-R** (TP-13) |
| `live_activities` | 2.6.0 · 2026-09-11 | MIT | **Add with PR-S** (TP-14) |
| `confetti` | 0.8.0 · 2024-09-28 | MIT | **No:** the in-repo `ConfettiOverlay` already does this |
| `lottie` / `rive` | 3.6.1 / 0.14.11 | MIT / MIT | **Not now:** each animation file has its own licence and they add app size. Revisit for one or two designer-made hero animations. |
| `percent_indicator` | in pubspec, unused | — | **Remove** (TP-11) |
| `fl_chart` | repo pins 0.67; latest 1.2.0 · 2026-03-13 | MIT | Upgrade only with chart work (TP-11) |

Sources: `https://pub.dev/api/packages/<name>` and `/score`, read 2026-10-06.

---

## 10. Copy rules

- Say "New best", not "PR", inside the app; it's clearer for beginners. The share card may say "New best (PR)".
- Show numbers before words: "62.5 kg × 8 (was 60 kg × 10)", not a sentence about progressive overload.
- Say "Total lifted", not "External volume". Say "2 of 3 workouts this week", not "adherence".
- Never imply an estimate. No "≈", "projected" or "max" unless the value was actually lifted.

---

## 11. Work items: change, tests, risks, verification

### TP-1 Bests engine  (PR-L)
- **Change:** § 4.1–4.2; fill `technique` in the performance read.
- **Tests:**
  - the first session is a baseline (no bests);
  - a tie isn't a best;
  - 60 kg × 10 then 62.5 kg × 8 gives Heaviest;
  - 60 kg × 8 then 60 kg × 10 gives Most reps;
  - 60 × 8 then 55 × 10 gives nothing (lighter weight, so no reps best);
  - warm-ups ignored;
  - assisted, tempo, paused and drop sets ignored;
  - basis mismatch ignored;
  - a substitution counts for the substitute;
  - 135 lb twice gives no best (tolerance);
  - deleting the session that held a best re-derives the old one;
  - a partial session counts;
  - 300 sessions evaluate in under 50 ms.
- **Risk:** early weeks are full of bests for beginners. Mitigated by one badge per set, top 3 on the summary and one celebration per workout.

### TP-2 Player  (PR-L)
- **Change:** a chip on the set row plus a best on the last-time line. The haptic fires after the save completes.
- **Tests:**
  - widget: logging 62.5 × 8 after a 60 × 8 history shows "New best", and `success` fires once;
  - logging 60 × 8 shows nothing;
  - the chip has a semantics label "New best, heaviest".
- **Risk:** conflicts with PR-D (rest bar) in `b02_strength_player_screen.dart`. Merge PR-D first, or rebase L onto it.

### TP-3 Summary, share card, exercise history  (PR-L)
- **Tests:** summary golden with 0, 1 and 4 bests ("and 1 more"); the share text includes bests; the exercise history "Best ever" card matches the engine.

### TP-4 Weekly goal model  (PR-M)
- **Tests:**
  - goal from the plan (3 scheduled) vs no plan (default 3);
  - a goal change doesn't rewrite past weeks;
  - the week in progress doesn't break the streak;
  - a missed week ends it;
  - two workouts on one day count as 2;
  - Monday boundary at 00:00 local;
  - a DST-free civil-date check like `StreakCalculator`'s.

### TP-5 Weekly goal UI  (PR-M)
- **Tests:**
  - widget: the Training card shows "2 of 3" and "4 weeks in a row";
  - the streak line is hidden at 0;
  - the goal sheet saves 1–7;
  - Today's chip reads "days logged";
  - no daily streak widget on Training, player, summary or Progress → Training (a finder test).
- **Risk:** existing Progress goldens change. Refresh them on Linux with `update-goldens.yml`.

### TP-6 Summary payoff  (PR-N)
- **Tests:**
  - order of blocks;
  - one celebration when bests and the week goal both happen;
  - no inline burst when an achievement sheet opens;
  - "Total lifted" copy;
  - count-up final values with reduce motion.

### TP-7 Motion and haptics  (PR-N)
- **Tests:** § 7.
- **Verification (owner, device):** feel the set, rest-end, best and week-goal haptics on one iPhone and one Android phone. The simulator has no haptics.

### TP-8 … TP-14
Each gets its own section when an agent picks it up. Their tests follow the same pattern: pure logic first, then a widget test, then goldens.

**Every PR in this plan runs:** `flutter analyze`, the full `flutter test` in a scratchpad worktree (never in the main checkout), `python3 tool/generate_code_graph.py --ci` (the graph itself isn't committed), and a golden refresh when UI changed.

---

## 12. Order (no dates)

1. **v1:** L → M → N, alongside the roadmap's A, B, C, G, D and T. They ship in the next tester build after they merge.
2. **Next, any order:** O, Q, P (the free parts: TP-10, TP-11 and the recent-bests list), then R. S starts once the Apple Developer Program is active.
3. **Plus-gated:** the TP-9 muscle map and heatmap ship behind the Plus switch, whenever Plus launches.

Relative sizes: L is M–L, M and N are M. Agents can build them in parallel in separate worktrees, but they merge one at a time (L before N) and each needs a green full suite. On this Mac only one full suite runs at a time.

## 13. Open questions for Ayush

**Decided 2026-10-06:** all three as recommended. Also decided: the muscle map and heatmap (TP-9) are **Plus** features. Bests, the weekly goal, reminders and the home widget stay free forever (market doc § 6.5). Until Plus exists, TP-9 waits or ships behind the Plus flag; it must not ship free and then move. Weekly badges come as a Next item, there's no goal override with a plan in v1, and the closed-test feedback form gets the tester question.

1. **Weekly badges:** add "Week goal 4 weeks running" and "12 weeks running" achievements? *Recommend yes, as a Next item.* It's cheap once TP-4 exists, but v1 doesn't need it.
2. **Goal override with a plan:** allow "my goal is 4" when the plan schedules 3? *Recommend no for v1.* Keep one source; revisit if testers ask.
3. **Ask testers directly:** add one question to the closed-test feedback form, "Did a 'New best' or the week goal make you want to train again?" *Recommend yes;* it's the cheapest signal before launch.
