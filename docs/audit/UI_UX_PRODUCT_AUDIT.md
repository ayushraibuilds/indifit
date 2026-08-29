# IndiFit — UI/UX, Design & Product Audit

**Project**: IndiFit (offline-first fitness & nutrition platform, Flutter/Riverpod/Drift)
**Audit date**: 2026-08-16
**Branch reviewed**: `ux/r07e-progress-insights` (post-R07E)
**Companion to**: `docs/audit/INDIFIT_COMPREHENSIVE_AUDIT_REPORT.md` (launch-readiness/compliance). This document covers the experience layer that report does not: UI/UX, design, interactivity, feel, product gaps, and code quality that affects the UI.

---

## 0. Method & sources

| Source | How used |
|---|---|
| `docs/reference/ui/REFERENCE_GUIDE.md` | The project's own curated analysis of the competitor screenshot library (Healthify 13, Gymverse 25, Muscle Booster 7, VGFIT 3) and legacy IndiFit — used as the benchmark map |
| `docs/implementation/ux/*` (UX_AUDIT, UX_PRODUCT_RESET, R7A→R07E plans/reviews) | Intended direction, frozen contracts, explicit deferrals |
| Production code under `lib/` (~305 files, ~155k hand-written lines) | Ground truth for every screen's layout, copy, and interaction — cited as `file:line` |
| Current screenshots (`docs/reference/ui/current/**`, `current-regressions/**`) | One direct vision pass succeeded (Today, light mode); the image-analysis service was rate-limited for the remainder of the session. The 16 `current-regressions` shots are the same set documented finding-by-finding in `UX_AUDIT.md`, which is used as their record |
| Root trackers (`UI_ANALYSIS.md`, `UX_FEATURE_IMPROVEMENT_PLAN.md`, `ISSUES.md`) | Prior waves' open items cross-checked against live code |

> **Limitation, stated plainly:** direct pixel-level inspection of every screenshot was not possible this session (vision-service rate limiting). Every claim below is instead anchored in code (which is stronger evidence for behavior/copy, weaker for pure aesthetics) or in the project's own documented screenshot analyses. Where a claim rests on aesthetics alone, it is marked *(verify visually)*.

---

## 1. Executive summary

IndiFit's engineering and information architecture are exceptional. The UX reset (R0→R07E) genuinely fixed the worst problems: the four-tab shell, the nutrition hero, the diary-first Food tab, the calm workout player, and the honest sparse-data Progress screen are all the right bones, and the accessibility discipline (reduce-motion policy, semantics, 320pt/2.0x goldens) is beyond typical solo-dev apps.

The remaining gap to "feels as good as Healthify/Gymverse" is concentrated in five things:

1. **Dead features still referenced by the product's own principles.** Hydration logging has **no live surface** (the water card exists only in dead code, and water is persisted as a SharedPreferences int — not even in the DB). PR confetti lives only in the legacy player. Streak-freeze mechanics are dead code. The engagement layer was orphaned when the dashboard was rebuilt.
2. **A design system that exists but isn't enforced.** Three parallel color systems, 854 raw color references, 293 raw `fontSize:` calls, three different loading idioms, two confirmation idioms, and at least one screen family (saved meals / data management) still on dark-only legacy colors that will misrender in light mode.
3. **Moments of triumph are silent.** The current B02 player and summary have no PR celebration, no shareable workout card, no count-up numbers, no haptics beyond set/rest. Gymverse and Hevy win loyalty at exactly this moment. R07E explicitly deferred a PR engine to R07F+ — it should be the next UX wave's centerpiece.
4. **Trust and copy leaks.** "Canonical workout" in history UI, "Occurrence cancelled" snackbars, "provider" language, a photo-estimator permission string that claims local processing while images are uploaded (a documented Phase-0 compliance item), and a hardcoded 6.5 kcal/min "calories burned" on the legacy summary that violates the project's own no-fabricated-data principle.
5. **Structural debt that slows everything:** a 3,448-line food search file with a ~965-line method, a 2,343-line progress file, ~2,500 lines of dead dashboard widgets, dual workout players, dual "saved meal" concepts (Saved Meals vs legacy Meal Templates), and blocking startup work before first frame.

### UX scorecard

| Dimension | Score | Verdict |
|---|---|---|
| Information architecture & navigation | 8.5/10 | Right structure; minor inconsistencies (router vs `Navigator.push`) |
| Visual design system | 6/10 | Strong tokens exist; adoption ~60%, three systems coexist |
| Food logging UX | 8/10 | Near-Healthify; diary extra tap, jargon strings, god-file risk |
| Training & workout execution UX | 7.5/10 | Near-Gymverse calm; no media, no celebration, no end-plan |
| Progress & insights | 7/10 | Honest and clean; thin vs Gymverse+Healthify benchmarks |
| Interactivity, motion & "feel" | 5/10 | The biggest gap: haptics/animation/celebration mostly missing in live paths |
| Onboarding | 8/10 | Short, skippable, draft-safe; missing a payoff/summary screen |
| Accessibility | 9/10 | Excellent for an indie app; saved-meals/history rows lag |
| Copy & terminology | 6.5/10 | Mostly consumer-grade; a dozen real leaks remain |
| Perceived performance | 7/10 | Skeletons on Today/Food; blocking startup work; three loading idioms |

---

## 2. What is already excellent (protect these)

Per `REFERENCE_GUIDE.md` §10, redesigns must preserve canonical behavior. These are genuine strengths the audit found in live code:

- **Today module system** — reorderable/hideable modules, per-module skeletons, per-module retry, "Your Today view is clear" empty state, layout-save retry row (`today_daily_action_surface.dart:230-276, 1578-1724`).
- **Fast food logging** — Today meal-row `+` → `/food?mealType=` → autofocused search = 2 taps + typing; 1-tap fast-add with undo snackbar (`food_search_screen.dart:708, 1826`; `main_navigation_scaffold.dart:146-162`).
- **Search quality** — deterministic Indian-food ranking, synonym retrieval (dahi↔curd, roti↔chapati), typo recovery, custom-food discovery, offline+online merge with graceful degradation (`UX_R07D_FOOD_SEARCH_DISCOVERY_REVIEW.md`).
- **Workout player calm** — load/reps dominant, tools behind disclosure, bounded rest controls, lifecycle-aware elapsed clock, structured review, substitution ancestry (`b02_strength_player_screen.dart`).
- **Honest progress** — the 0/1/2/3+ observation ladder (prompt → tile → delta → chart) and fail-closed volume are differentiating integrity features most competitors lack.
- **Accessibility spine** — `B05MotionPolicy` gating animations, 163 `Semantics` uses in features, text-scale compaction on Today and the portion sheet, 320pt + 2.0x goldens.
- **Onboarding restraint** — 4 steps, "Skip for now", continuous draft save with restore state (`onboarding_screen.dart:442, 539-576`).

---

## 3. Competitive benchmark — where IndiFit stands vs the reference library

Benchmark map = `REFERENCE_GUIDE.md` §11. Rating: ● parity, ◐ partial, ○ missing.

| Area | Benchmark | IndiFit today | Gap summary |
|---|---|---|---|
| Today glanceability | Legacy IndiFit + Healthify | ◐ | Nutrition hero exists; hydration absent, weight quick-log buried, no count-up animation |
| Nutrition summary | Legacy IndiFit | ◐ | Ring + macro bars present; no fiber display (token `fiberTeal` exists, unused), no macro pie/detail toggle |
| Food logging speed | Healthify | ● | Fast-add + recent/frequent + multi-select batch; diary "Add food" adds one extra tap |
| Food search | Healthify | ◐ | Ranking excellent; no catalog-wide cache, limited brand normalization (deferred R07D-3+) |
| Hydration | Healthify | ○ | **No live logging surface at all** — the flagship Healthify pattern |
| Training landing | Gymverse | ◐ | Dominant action right; lacks Gymverse's week-by-week plan progression visual |
| Workout execution | Gymverse | ● (interaction) / ○ (media) | Calm set logging done; no exercise imagery/video (B05 media empty, licensing unresolved) |
| Previous-performance context | Gymverse | ● | Guide/Performance split, stable-ID joins (`B02ExercisePerformanceReadRepository`) |
| Exercise details | Gymverse + VGFIT | ◐ | Cues + history yes; muscles-worked visuals and media no |
| Progress | Gymverse + Healthify | ◐ | Consistency/strength/weight/nutrition done; no PR badges, e1RM trends (deferred), body comp |
| Onboarding | Muscle Booster | ● (clarity) / ◐ (payoff) | Short + skippable (better than MB); missing MB's personalized summary screen |
| Celebration/share | Hevy/Strong (industry) | ○ | No PR celebration in current player, no shareable workout card |

---

## 4. Screen-by-screen findings

### 4.1 Today / Home

**Current state** (`dashboard_screen.dart` 392L, `today_daily_action_surface.dart` 1,757L): greeting → date bar → reorderable modules (`today.meals` hero with animated ring + macro bars + "Log food"/"What can I eat?", `next_action`, `meal_rows`, `workout`, `activity`, `progress`). Confirmed visually: light mode, white cards, green ring showing "1,748 remaining", green filled "Log food" CTA, macro bars (protein green / carbs amber / fat red per `today_daily_action_surface.dart:898-900`).

**Findings**

| # | Severity | Finding | Evidence |
|---|---|---|---|
| T1 | **P0** | **Hydration has no live surface.** `water_tracker_card.dart` (164L) is dead code referenced only by tests; no Today module logs water; water state is `prefs['water_logged']` int, not a Drift table — so no history, no charts, no per-day backfill. `REFERENCE_GUIDE.md` §5 names Healthify's "highly visual, immediately interactive" water tracker as a primary pattern. | `lib/features/dashboard/widgets/water_tracker_card.dart`; grep shows `logWater` has no live caller |
| T2 | P1 | Weight quick-log not on Today; the log-weight sheet lives in Progress. Healthify/Muscle Booster surface daily weight on home. | `widgets/log_weight_bottom_sheet.dart` used by Progress |
| T3 | P1 | PR/engagement moments absent: streak chip appears only when >0 (`:460`), no streak milestone feedback, streak-freeze earn mechanics are dead code (`streak_freeze_card.dart`). | dead widgets folder |
| T4 | P2 | Fat macro uses `Icons.water_drop_outlined` — semantically a *water* icon for *fat*; confusing next to a (future) hydration module. | `today_daily_action_surface.dart:907` |
| T5 | P2 | No count-up/animated number transitions on ring & macros (planned in `UX_FEATURE_IMPROVEMENT_PLAN.md` #13, never landed in the rebuilt surface). | plan vs live code |
| T6 | P2 *(verify visually)* | Empty-day macro bars render red/amber tracks at 0g logged in the one vision pass — ensure 0-progress tracks don't read as "over/error". | IMG_1323 pass |
| T7 | P3 | "Double tap to inspect this meal" hint is an unusual interaction contract; single-tap row + chevron is the platform norm. | `today_daily_action_surface.dart:1288` |

**Recommendations**
1. Build a **hydration module for Today** (B05 token for water = blue/cyan per guide §9): glass icons or a fillable jug, tap to add, quick chips (250/500ml), goal from settings, stored in a new `WaterLogs` Drift table (also unlocks Progress hydration trends and weekly-report accuracy). This is the single highest ROI UX addition in the app.
2. Surface **weight quick-add** as a Today module (reuse `log_weight_bottom_sheet.dart`); default-hidden for users who don't weigh daily (module system already supports hiding).
3. Fix T4/T6 (trivial), add count-up via existing `flutter_animate` dep under `B05MotionPolicy`.
4. Revive streak-freeze *earn* rules (cost/cooldown per `UX_FEATURE_IMPROVEMENT_PLAN.md` #7) before re-exposing any streak UI — don't restore the spammable version.

### 4.2 Food (diary, search, portions)

**Current state** (`food_search_screen.dart` 3,448L + `food_log_surface.dart` 342L): search-first screen with landing (Recent → Frequent → Saved & recipes → More ways: barcode/AI/photo → today's entries), diary screen with summary + 4 meal rows, meal detail, ~965-line portion/log bottom sheet.

| # | Severity | Finding | Evidence |
|---|---|---|---|
| F1 | **P0 (trust/compliance)** | Photo-estimator permission copy claims local processing while images are uploaded — a documented unmet Phase-0 exit criterion. This is a store-review and user-trust risk, not just copy. | `canonical-roadmap.md` §11/§12 |
| F2 | P1 | `_showLogDialog` ≈ 965 lines inside a 3,448-line file holding 12+ widgets/3 screens — the app's biggest maintainability smell; every portion-sheet tweak risks regressions across search+diary+detail. | `food_search_screen.dart:814-1600` |
| F3 | P1 | Diary "Add food" opens a meal-choice sheet first (extra tap); meal rows in the diary should carry their own `+`. | agent-verified; `FoodDiaryScreen` |
| F4 | P1 | Duplicate saved-meal concepts: "Saved meals" (R07D-3, canonical) and legacy `MealTemplates` screen (385L) both exist; retirement explicitly pending. Users can meet both vocabularies. | `meal_templates_screen.dart`; `UX_R07D_RECIPES_SAVED_MEALS_REVIEW.md` §Deliberate deferrals |
| F5 | P2 | Copy: "Online food search could not reach the provider." / "The online food provider is unavailable right now." — "provider" is internal vocabulary. | `food_search_screen.dart:600,602` |
| F6 | P2 | Capitalization drift: "Add Food" vs "Add food". | `food_search_screen.dart:3133` |
| F7 | P2 | No search debounce (generation-guarded, but every keystroke recomputes the merge+rank); saved-meals search *does* debounce 300ms — inconsistent. | `food_search_screen.dart:499` vs `saved_meals_screen.dart:40` |
| F8 | P3 | Barcode flow: MLKit unusable on arm64 iOS 26+ simulators (device fine) — pin a CI/device-test note so it doesn't surprise the next contributor. | R07C review |

**Recommendations**
1. Fix F1 now (truthful copy + upload disclosure), independent of any redesign.
2. Split `food_search_screen.dart` into `food_search/`, `food_diary/`, `food_portion_sheet/`, `food_meal_detail/` files with widget tests pinned first (the R07D goldens already cover behavior).
3. Add `+` to diary meal rows; keep the FilledButton as "Add to a meal…" (secondary).
4. Schedule `MealTemplates` retirement with a one-time migration to Saved Meals, then delete 385L + compatibility paths.
5. Unify copy: "Online food search is unavailable right now." etc.

### 4.3 Training landing & planning

**Current state** (`training_screen.dart` 1,057L): START TRAINING → resume draft → TODAY → CURRENT PLAN → UPCOMING(3) → RECENT(3) → EXPLORE (calendar, exercises, history).

| # | Severity | Finding | Evidence |
|---|---|---|---|
| R1 | **P1 (product gap)** | **No way to end/switch an active plan.** "No safe public deactivation command exists" so the action was deliberately omitted — users who finish or abandon a program are stuck with it as CURRENT PLAN. | `UX_R7B_DEVICE_ACCEPTANCE_REMEDIATION_PLAN.md` |
| R2 | P1 | Gymverse benchmark: visible week-by-week progression with completed/current/future states. IndiFit has an occurrence calendar (7 files under `features/calendar/`) but it's behind EXPLORE; the landing shows only CURRENT PLAN + 3 upcoming. A compact week strip (like Progress's consistency strip) on the landing would close most of the gap with existing data. | `REFERENCE_GUIDE.md` §4 vs `training_screen.dart:531-708` |
| R3 | P2 | "Canonical workout" label rendered per-row in history (worst jargon leak; also read by semantics). | `workout_history_screen.dart:79,82` |
| R4 | P2 | All Training navigation uses raw `Navigator.push(MaterialPageRoute…)` while dashboard/settings use go_router — breaks deep links/back-stack consistency app-wide. | `training_screen.dart` throughout; `ISSUES.md` #6 |
| R5 | P3 | "Occurrence cancelled." snackbar and "Occurrence history" section title — domain vocabulary. | `occurrence_actions_sheet.dart:280,395` |

**Recommendations**
1. Design an explicit **"Finish plan" / "Leave plan"** flow (confirm → mark plan completed → suggest next plan). This is a B01 authority question, not just UI; it deserves its own small spec (draft exists conceptually in R7B notes).
2. Add the week strip to CURRENT PLAN (reuse `_WeekCalendarStrip` pattern).
3. Replace R3/R5 strings: "Workout" / "Earlier workout" → just date + plan name; "Session cancelled." / "Session history".
4. Complete the go_router migration (mechanical; `ISSUES.md` #6 acceptance criteria still apply).

### 4.4 Workout execution

**Current state**: dual players — legacy `workout_player_screen.dart` (751L, reachable for legacy drafts) and current `b02_strength_player_screen.dart` (1,636L + controller 721L + summary 461L).

| # | Severity | Finding | Evidence |
|---|---|---|---|
| W1 | **P1 (feel)** | **No PR celebration in the current player.** Confetti + "NEW PERSONAL RECORD!" exist only in the legacy player; R07E deferred a new PR engine to R07F+. The strongest emotional beat in the product is silent in the canonical path. | `workout_player_screen.dart:715-745` vs no `Confetti`/PR refs in b02 files (grep-verified) |
| W2 | P1 | No shareable workout summary card (industry-standard delight; strong fit with offline-first brand). | deferred P2 in companion audit |
| W3 | P1 | **Fabricated calories**: legacy summary hardcodes 6.5 kcal/min as calories burned — violates the project's own "no fake data" principle (R07E cut invented metrics for exactly this reason). Remove or label as estimate-from-duration. | `workout_summary_screen.dart:56` |
| W4 | P2 | `_RestCard` styles itself with raw `Card`/`Theme.of` instead of the B05 primitives used elsewhere in the same file — visual drift in the most-viewed card during workouts. | `b02_strength_player_screen.dart:1366+` |
| W5 | P2 | Rest timer: no Live Activity / Dynamic Island / ongoing notification for background rest; no audio ducking (timer beeps vs user's music). | companion audit P2; deps already present (`just_audio`, `flutter_local_notifications`) |
| W6 | P2 | Exercise guidance has no imagery: B05 media manifest has empty `youtube_id`s and unresolved licensing; Gymverse/VGFIT win heavily here. | `batches/B05…/AUDIT.md` |
| W7 | P3 | Legacy player error state is a bare `Text('No exercises found in routine.')`. | `workout_player_screen.dart:468` |
| W8 | P3 | Two players shipped; legacy retained for legacy drafts — set a sunset (migrate legacy drafts on open, then delete 751L). | `workout_contextual_launcher.dart:86` |

**Recommendations**
1. R07F centerpiece: **PR engine + celebration + share card** (see §7 roadmap). Detection logic (stable-ID performance reads) already exists — this is presentation work, deliberately deferred, now due.
2. Delete W3's fake calorie number this week (one line) — it's a values violation, not a feature.
3. Rest timer background presence: Android ongoing notification is cheap and high-value; iOS Live Activity second.
4. License ~20 exercise animations/videos for the top-20 B05 media list (the roadmap already routes this decision to the product owner — §13 of canonical-roadmap).

### 4.5 Progress & insights

**Current state** (`progress_screen.dart` 2,343L, 23 classes): overview metrics → consistency strip → strength → weight (range selector) → nutrition adherence → volume → muscle balance → measurements; achievements behind AppBar popup menu.

| # | Severity | Finding | Evidence |
|---|---|---|---|
| P1 | P1 | Thin vs benchmark: no PR badges, no e1RM trend (deferred pending a B02 authority), no body-fat/composition read model, weight goal is a legacy onboarding pref shown as "reference", not a target. | `UX_R07E_PROGRESS_INSIGHTS_REVIEW.md` §Deferred to R07F+ |
| P2 | P2 | Achievements: hidden behind a popup menu, content thin (4 achievements; expansion to ~10 planned in `UX_FEATURE_IMPROVEMENT_PLAN.md` #12, never landed in the rebuilt surface). | `progress_screen.dart` AppBar; plan #12 |
| P3 | P2 | File is 23 classes / 2,343L — same god-file risk as food. | line count |
| P4 | P3 | Text-scale compaction less consistent here than Today (26 `textScalerOf` uses concentrated elsewhere). | agent sweep |
| P5 | P3 | Hydration history impossible today (no water table) — blocks a Progress module later. | T1 dependency |

**Recommendations**
1. R07F: e1RM authority (small, well-scoped: `totalExternal` only, Epley, per R07E review constraints) + PR badge list + goal line on weight chart once a typed B04 target exists.
2. Promote Achievements to a visible Progress section (or Today module) and expand to ~10; wire unlock feedback (confetti is already a shared widget).
3. Split the file per section (one file per card) — behavior is golden-covered, safe mechanical refactor.

### 4.6 Settings

Twelve screenshots exist for settings — itself a signal of depth.

| # | Severity | Finding | Evidence |
|---|---|---|---|
| S1 | P2 | "Choose an IndiFit backup file. Pasting a legacy backup remains available below." and "Optional: paste a legacy JSON backup…" — migration vocabulary in consumer copy. | `data_management_section.dart:93,142` |
| S2 | P2 | Workout playlist setting is a dead end (no in-app music; picker never built — `UX_FEATURE_IMPROVEMENT_PLAN.md` #18 deferred). Hide it until the playlist picker exists. | plan #18; `UX_AUDIT.md` P1 |
| S3 | P3 | `RadioListTile` with `// ignore: deprecated_member_use` — M3 replacement due before a store release. | `settings_screen.dart:262-286` |
| S4 | P3 | Data-management section still imports dark-only legacy `AppColors` — verify light-mode rendering *(verify visually)*. | `data_management_section.dart` imports |

### 4.7 Onboarding

Strong: 4 steps, skip, draft restore, progress bar. Gaps:

| # | Severity | Finding |
|---|---|---|
| O1 | P2 | Validation errors via SnackBar ("Choose an option above to continue.") instead of inline field-adjacent messaging used elsewhere (`ConsumerStatusRow`). |
| O2 | P2 | No personalized summary/payoff screen before "Finish setup" — Muscle Booster's pattern (plan preview: "Your 4-day Push/Pull/Legs + 2,150 kcal target are ready") is cheap here and materially lifts completion motivation. |
| O3 | P3 | Completion embeds TDEE calculation + ~15 `SharedPreferences` writes inline in the screen (`onboarding_screen.dart:322-422`) — move to a service; it also duplicates the Drift-vs-prefs split flagged as open risk in the roadmap. |

---

## 5. Cross-cutting design-system findings

### 5.1 Three color systems coexist

- `B05SemanticColors` (436L, light+dark, ThemeExtension, lerp) — the real system.
- `AppColorsExtension` — second extension wrapping legacy feature tokens.
- `AppColors` (35L) — dark-only literals (`#060A12` bg, white text) still imported by **saved meals, data management, profile** screens → these will render dark-styled colors in light mode. 854 raw `AppColors.`/`Colors.` references and 293 raw `fontSize:` calls bypass tokens across features.

**Fix:** finish the migration file-by-file (start with the two broken-light-mode screens), then delete `colors.dart` + `AppColorsExtension` merges. Add an analysis-rule/CI grep (`AppColors\.` forbidden outside `core/theme/`) so it can't regress.

### 5.2 Missing semantic tokens

- No hydration/water token (guide §9 wants blue/cyan) — blocked by T1.
- Fiber token (`fiberTeal`) exists in the legacy set but fiber isn't displayed anywhere in the live UI despite `fiberG` being in the DB and seeded (carried over from `UI_ANALYSIS.md` #25, still open).

### 5.3 Three loading idioms

Skeletons (Today, food search, exercise library) / `ConsumerStatusRow` text rows (Training, Progress, Settings) / full-screen `CircularProgressIndicator` (saved meals). Pick one rule: **skeletons for content-shaped lists, status row for task-shaped panels, never full-screen spinners** — then make saved meals comply.

### 5.4 Two confirmation idioms

`AlertDialog` (resume workout, delete, rest-skip) vs bottom sheets (meal choice, start workout, exercise actions); destructive buttons differ (danger `ElevatedButton` in saved meals vs plain `FilledButton` elsewhere). Write the rule into `REFERENCE_GUIDE.md` §9 and enforce: destructive = bottom sheet + danger button; quick binary = dialog.

### 5.5 Typography

Outfit via `GoogleFonts` **runtime fetching** (`app_theme.dart:147-153`) — an offline-first app whose typography depends on first-run network. Bundle the fonts (ISSUES.md #16, still open). Otherwise the scale/weights (w700 display, 1.45 body height) are sound; the 293 raw `fontSize:` sites should collapse onto the theme roles.

### 5.6 Motion & haptics inventory (the "feel" gap)

- `flutter_animate` (a dependency!) used in exactly 2 files. Explicit `Animated*` in ~9. One `Hero` in the app. No Lottie.
- Haptics in live paths: food fast-add, both players' set/rest, profile. **Tab switching, water (dead), meal add, set complete chips, pull-to-refresh completions — none.** Most haptic calls live in dead dashboard widgets.
- `B05MotionPolicy` is excellent — the constraint layer exists, the content layer was never built on it.

**Fix:** a one-week "feel sprint": selection haptics on nav + key taps, count-up ring/macros, ring → meal-detail Hero, animated module reorder, confetti on achievement unlock + PR (shared widget already exists).

---

## 6. Copy & terminology audit (live UI strings)

| Leak | Location | Replace with |
|---|---|---|
| "Canonical workout" | `workout_history_screen.dart:79` | (drop the label; show plan name + date) |
| "Occurrence cancelled." / "Occurrence history" | `occurrence_actions_sheet.dart:280,395` | "Session cancelled." / "Session history" |
| "…reach the provider." / "…food provider is unavailable…" | `food_search_screen.dart:600,602` | "Online food search is unavailable." |
| "Pasting a legacy backup…" | `data_management_section.dart:93,142` | "Restore from an older IndiFit export" |
| "imported provider" / "legacy record" protein-source labels | `protein_distribution_screen.dart:397,401` | "Imported" / "Earlier entries" |
| "Photos and provider secrets are not backed up." | `nutrition_estimate_review_screen.dart:263` | "Photos are not included in backups." |
| Thrown-and-likely-shown: "The current group is missing from the frozen draft." | `b02_strength_execution_controller.dart:310` | map to a typed `AppFailure` consumer message |
| "The typed activity draft is unavailable or legacy-shaped." | `b02_activity_controller.dart:174` | same |
| "Occurrence $occurrenceId not found." | `calendar_controller.dart:294` | same (never surface IDs) |
| "B02 strength draft is unavailable." | `app_router.dart:284` | "This workout draft is unavailable." |

The reset removed the worst (UUIDs, reason codes, UTC strings, "canonical nutrition totals") — these ~10 are the residue. One focused PR closes the set.

---

## 7. Feature additions & product roadmap (prioritized)

Mapped to benchmark gaps and the project's own deferred list (R07F+). Effort: S ≤1d, M ≤3d, L ≤1w.

| # | Feature | Why (gap) | Effort | Notes |
|---|---|---|---|---|
| 1 | **Hydration module on Today** + `WaterLogs` table + Progress trend | Healthify flagship pattern; currently impossible | M | T1; biggest ROI in this report |
| 2 | **PR celebration engine + shareable workout card** | W1/W2; R07E deferred to R07F+; detection exists | M | detection = stable-ID perf reads; share via `share_plus` (dep present) |
| 3 | **End/leave plan flow** | R1; users stuck with CURRENT PLAN forever | M | needs small B01 spec first |
| 4 | **Week strip on Training landing** | Gymverse plan-overview benchmark | S | reuse consistency-strip widget |
| 5 | **Truthful photo-AI disclosure + offline-font bundling** | F1 trust/compliance + §5.5 | S | both are one-sitting fixes |
| 6 | **Feel sprint** (haptics, count-up, Hero, reorder animation) | §5.6 | M | all under existing MotionPolicy |
| 7 | **Fiber display + macro detail toggle (pie)** | token+data exist; `UI_ANALYSIS.md` #22/#25 still open | S–M | |
| 8 | **Rest timer background presence** (Android ongoing notification → iOS Live Activity) | W5 | M→L | deps present |
| 9 | **Exercise media starter pack (top-20)** | W6; VGFIT/Gymverse benchmark | L | blocked on licensing decision (roadmap §13) |
| 10 | **Onboarding payoff screen** | O2; Muscle Booster pattern | S | |
| 11 | **Achievements expansion + visibility** | P2; plan #12 | M | |
| 12 | **Streak mechanics revival** (earn rules first) | T3; plan #7 | M | do **after** cost/cooldown design |
| 13 | **Barcode → Open Food Facts async fallback save** | companion audit; OFF integration already hardened (R7A/B) | S | |
| 14 | **Plate-calculator quick button beside load input** | W4 adjacency; exists as context elsewhere | S | |
| 15 | Weight quick-log Today module | T2 | S | |
| 16 | Audio ducking for timer chimes | companion audit | S | |
| 17 | e1RM authority + PR badges + typed weight goal (B04 read model) | P1; R07F+ scope already defined | L | needs the B02 authority spec R07E asked for |
| 18 | Watch companion | industry; post-launch | XL | explicitly later |

---

## 8. Code-quality & performance findings (UX-impacting)

| # | Severity | Finding | Evidence |
|---|---|---|---|
| C1 | P1 | **Blocking startup work before first frame**: `await NotificationService.scheduleAllReminders(db)` (cancelAll + prefs + DB queries) runs pre-`runApp`; plus Sentry init awaited. Move post-frame; measure cold start. | `main.dart` steps 5–7 |
| C2 | P1 | Router `redirect` awaits `SharedPreferences.getInstance()` on **every navigation**. Cache once. | `app_router.dart:91-106` |
| C3 | P1 | God files: `food_search_screen.dart` 3,448L (13 classes), `progress_screen.dart` 2,343L (23), `today_daily_action_surface.dart` 1,757L (27), `b02_strength_player_screen.dart` 1,636L, `program_author_screen.dart` 1,385L (single ~402-line `build()`). | line counts |
| C4 | P1 | ~2,500L dead dashboard widgets (`dashboard_meal_section` 1,046, `calorie_ring_card`, `water_tracker_card`, `streak_freeze_card`, `today_workout_card`, …) referenced only by tests — misleading (they hold the app's haptics!) and rotting. Decide per widget: revive (water, streak) or delete + drop tests. | `lib/features/dashboard/widgets/` |
| C5 | P2 | `providers.dart` 898-line manual registry importing ~50 classes; no codegen. Workable but every feature touches it. | `core/di/providers.dart` |
| C6 | P2 | ~9,000L fixture matrices compiled into `lib/core/fixtures/` — belongs in assets (smaller binary tree, faster analyze). | `core/fixtures/*` |
| C7 | P2 | Milestone prefixes (`b02_`…`b05_`) leaked into 72 production filenames and user-adjacent copy ("B02 strength draft"). Rename opportunistically; never in strings. | filename sweep |
| C8 | P2 | Backup v8/v9/v10 are layered copies (4,167 + 3,801 + 1,646L). Consider a versioned codec core. | `core/backup/` |
| C9 | P3 | Notification-tap callback assigned inside `build()` of `_IndiFitAppState` — side effect in build. | `main.dart:118-127` |
| C10 | P3 | Legacy adapters (three `*_compatibility_adapter`s) — transitional dual domain; schedule retirement after legacy draft/player sunset (W8). | `data/repositories/` |

**Also noted (process):** `MASTER_TRACKER.md` is stale (says B04/B05 "not started", 391 tests — reality is R07E-complete, ~1,389 tests); `canonical-roadmap.md` still baselines schema v14/backup v5 vs current v19/v10. Re-baseline both, or the next planning cycle inherits fiction.

---

## 9. Prioritized action plan

### P0 — trust, correctness, compliance (this week)
1. Photo-AI disclosure copy truthful (F1).
2. Delete fabricated 6.5 kcal/min calories (W3).
3. Jargon-leak PR (§6 table — ~10 strings).
4. Fix light-mode-unsafe legacy `AppColors` imports (saved meals, data management) *(verify visually after)*.

### P1 — biggest UX gaps (next 2–3 weeks)
5. Hydration module + `WaterLogs` table (T1).
6. PR celebration + shareable workout card (W1/W2).
7. End/leave plan flow (R1).
8. Feel sprint: haptics + count-up + motion (§5.6).
9. Startup de-blocking (C1/C2) + bundle fonts (§5.5).
10. Week strip on Training landing (R4 item 2) + go-router migration completion (R4).

### P2 — consistency & hygiene (next month)
11. Dead-widget triage (revive water/streak designs or delete) (C4).
12. Split the three god files (C3) behind existing goldens.
13. Loading/confirmation idioms unified (§5.3/§5.4).
14. MealTemplates retirement + migration (F4).
15. Diary meal-row `+` (F3); fiber + macro pie (§7 #7); onboarding payoff screen (O2).
16. Rest-timer Android ongoing notification (W5).

### P3 — later (post-launch)
17. Exercise media pack (licensing-gated), Live Activities, e1RM/PR-badge authority work, achievements expansion, watch companion, `MealTemplates`-style legacy-player sunset (W8), backup codec consolidation (C8), docs re-baseline.

---

## 10. Closing assessment

IndiFit has already done the hard, rare part: a domain model with integrity (no fake data, honest sparsity, stable identities), a disciplined reset that killed administrative UI, and accessibility machinery most apps never build. What separates it from feeling like Healthify/Gymverse today is not architecture — it is **the engagement layer (hydration, celebration, motion, haptics), token enforcement, and a handful of trust-level copy fixes**. All of them are small-to-medium, well-scoped, and unusually safe to ship behind the existing golden/test wall.

The recommended next UX wave (**R07F**) in one sentence: *"Hydration on Today, celebration in the player, an exit from every plan, and a week where everything that moves also feels right."*
