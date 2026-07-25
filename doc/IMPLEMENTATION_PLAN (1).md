# IndiFit — Implementation Plan

Consolidates everything found across the codebase review: security/architecture P0s, core logging
correctness bugs, the onboarding redesign, the workout/AI Coach rework, and the visual/engagement
polish pass. Organized into six phases, ordered by how badly each one is currently hurting real users.
Each item has the problem, the fix, exact files, effort, and how to verify it's actually done.

## How to use this doc
Work top to bottom. Phase 0 and Phase 1 items are shipped-and-broken for every user right now — do
these first, regardless of what feels more interesting. Each item is written to be handed to Claude Code
or done by hand in an afternoon; nothing here requires a redesign meeting first.

---

## Summary table

| # | Item | Phase | Effort | Files touched |
|---|------|-------|--------|----------------|
| 0.1 | Onboarding unreachable for new users | P0 | S | `app_router.dart`, `main.dart` |
| 0.2 | Exercise library always empty | P0 | S | `app_database.dart` |
| 0.3 | Hardcoded backend auth key | P0 | S | `backend/main.py`, `providers.dart`, `render.yaml` |
| 0.4 | Duplicate `AppDatabase()` instance | P0 | S | `main.dart` |
| 1.1 | Meal logging always logs against "today" | P1 | S | `ai_meal_logger_screen.dart`, `food_repository.dart` |
| 1.2 | Meals can be logged for future dates | P1 | S | `dashboard_date_bar.dart` |
| 1.3 | Deleting a meal is swipe-only, no visible affordance | P1 | S | `dashboard_meal_section.dart` |
| 1.4 | Weight trend chart looks broken; no real rate-limiting | P1 | M | `workout_repository.dart`, `weight_sparkline_card.dart` |
| 1.5 | Calorie goal stuck at 2000, no way to customize | P1 | M | `settings_screen.dart` (new), `user_profile_provider.dart` |
| 2.1 | 77MB APK committed to git history | P2 | M | repo history, `.gitignore`, CI |
| 2.2 | Silent `catch (_) {}` swallowing errors | P2 | M | 21 files across `lib/` |
| 2.3 | Oversized "god screens" | P2 | L | `progress_screen.dart`, `onboarding_screen.dart`, others |
| 3.1 | Two disconnected onboarding-shaped flows | P3 | M | `onboarding_screen.dart`, `onboarding_wizard_screen.dart` |
| 3.2 | Dead "target weight" onboarding page | P3 | S | `onboarding_screen.dart`, `progress_screen.dart` |
| 3.3 | Silent defaults on required-feeling choices | P3 | S | `onboarding_screen.dart` |
| 3.4 | No draft persistence during onboarding | P3 | M | `onboarding_screen.dart` |
| 3.5 | Raw `Navigator` mixed with `go_router` | P3 | S | onboarding + workout player files |
| 4.1 | AI routines ignore equipment/goal/injuries almost every time | P4 | L | `ai_routine_service.dart` |
| 4.2 | No way to edit an existing split once generated | P4 | L | `routine_display_screen.dart`, `routine_editor_screen.dart` |
| 4.3 | "Log a completed workout" exists but easy to miss | P4 | S | `routine_display_screen.dart` |
| 4.4 | Wizard naming/consolidation | P4 | — | cross-ref to 3.1, no separate work |
| 4.5 | Extend engagement pass to workout screens | P4 | M | `routine_display_screen.dart`, `workout_player_screen.dart` |
| 5.1 | Light mode is likely broken | P5 | L | `colors.dart` (709 call sites) |
| 5.2 | Celebration pattern used once instead of app-wide | P5 | S | `dashboard_screen.dart` |
| 5.3 | Static progress bars/rings, no animation | P5 | M | dashboard widget cards |
| 5.4 | Hero numbers too small | P5 | S | `calorie_ring_card.dart` + others |
| 5.5 | Ad hoc color usage outside the design system | P5 | S | `colors.dart`, scattered `Colors.X` |
| 5.6 | Achievement badges use generic stock icons | P5 | M | `achievements_screen.dart` |
| 5.7 | Empty states are functional but generic | P5 | M | multiple screens |
| 5.8 | Settings buried in overflow menu | P5 | S | `dashboard_header.dart` |
| 5.9 | `lottie` dependency installed, unused | P5 | S | `pubspec.yaml` |

S = under an hour, M = a few hours, L = half a day or more / needs its own sub-plan.

---

## Phase 0 — Critical fixes (do these first, in any order)

These are the items where the app is currently broken for every real user, not just "could be better."

### 0.1 Onboarding is unreachable for new users
**Problem:** `app_router.dart` has `initialLocation: '/'`, which goes straight to
`MainNavigationScaffold`. There's no `redirect` logic. The `onboarding_completed` flag is written at the
end of onboarding and reset by a Settings action, but **never read anywhere**. The only path to
`OnboardingScreen` is the manual "Reset" button in `data_management_section.dart`. Fresh installs land on
an empty dashboard with no profile, no calorie targets.

**Fix:**
```dart
// app_router.dart
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool('onboarding_completed') ?? false;
      final goingToOnboarding = state.matchedLocation == '/onboarding';
      if (!completed && !goingToOnboarding) return '/onboarding';
      if (completed && goingToOnboarding) return '/';
      return null;
    },
    routes: [ /* unchanged */ ],
  );
});
```
`SharedPreferences.getInstance()` is async and `GoRouter.redirect` supports async redirects, so this
works without a splash screen. If you want to avoid a flash of the dashboard before the redirect fires,
read the flag once in `main()` before `runApp()` and pass it in as an override, or add a tiny splash
route as `initialLocation` that checks synchronously via a pre-warmed provider.

**Verify:** Uninstall the app (or clear app data), launch fresh — you should land on `/onboarding`, not
the dashboard. Complete onboarding, force-quit, relaunch — you should land on the dashboard, not
onboarding again. Use the Settings "Reset" action — confirm it still routes back to onboarding.

### 0.2 Exercise library always empty
**Problem:** `app_database.dart`, in `upsertSeededExercisesFromAsset()` (lines ~197 and ~214), does:
```dart
muscleGroups: Value((raw['muscle_groups'] as List).join(',')),
```
but `assets/data/exercises.json` stores `muscle_groups` as a plain string (`"Chest,Triceps,Shoulders"`),
not a JSON array — confirmed across all 140 entries. The cast throws inside the seeding transaction,
which rolls back, and the exception is silently swallowed by the enclosing `catch (_) {}`. The
`exercises` table never gets populated, on fresh install or migration.

**Fix:** both occurrences, drop the cast and the join:
```dart
// before
muscleGroups: Value((raw['muscle_groups'] as List).join(',')),
...
muscleGroups: (raw['muscle_groups'] as List).join(','),

// after
muscleGroups: Value(raw['muscle_groups'] as String),
...
muscleGroups: raw['muscle_groups'] as String,
```
Also bump `schemaVersion` to `13` and add an `if (from < 13) { await upsertSeededExercisesFromAsset(); }`
migration step, so existing installs (which are currently stuck at a permanently-empty table from the
v12 "fix" that didn't fix it) get re-seeded. Without a schema bump, only fresh installs benefit.

**Verify:** Fresh install → Exercise Library tab shows 140 exercises. Existing install (simulate by
running the app on a DB already at schema 12) → after the v13 migration runs, exercises appear too.
Also add a debug assertion or startup log (see 2.2) so if this ever regresses, it fails loudly instead
of silently.

### 0.3 Hardcoded backend auth key
**Problem:** `backend/main.py:28` and `lib/core/di/providers.dart:23` both fall back to the literal
string `"indifit_secret_key_v1"` if the real env var isn't set. That string is baked into every shipped
APK and readable by decompiling it, letting anyone call your Gemini-proxying backend directly if
`INDIFIT_API_KEY` isn't set on the server (or even to guess/reuse it if it is, since it's public).

**Fix:**
- On the backend, remove the default entirely — fail closed:
  ```python
  INDIFIT_API_KEY = os.getenv("INDIFIT_API_KEY")
  if not INDIFIT_API_KEY:
      raise RuntimeError("INDIFIT_API_KEY must be set")
  ```
- On the client, stop hardcoding the matching fallback. Pass the real key via
  `--dart-define=INDIFIT_API_KEY=...` at build time (already using
  `String.fromEnvironment`, just drop the `defaultValue`), and fail loudly in debug builds if it's
  missing rather than silently using a known string.
- Confirm `render.yaml` has `INDIFIT_API_KEY` set with `sync: false` in the actual Render dashboard (the
  file only declares the var exists, it doesn't set the value — check the deployed value isn't still the
  old default).
- Rotate the key once, since the old one is effectively public now.

**Verify:** Build a release APK, decompile/grep the resulting binary for `indifit_secret_key_v1` —
confirm it's gone. Hit the backend with no key / a wrong key — confirm 401, not silent pass-through.

### 0.4 Duplicate `AppDatabase()` instance
**Problem:** `main.dart:33` does `final db = AppDatabase();` directly, while the rest of the app gets its
database through `databaseProvider` (Riverpod). Two separate connections to the same SQLite file can
cause missed reactive updates (a write through one connection doesn't notify streams/watchers on the
other) and, in the worst case, write contention.

**Fix:**
```dart
// main.dart
final container = ProviderContainer();
final db = container.read(databaseProvider); // instead of AppDatabase()
```
Then pass that same `container` into `UncontrolledProviderScope` (or wrap `runApp` in
`ProviderScope(parent: container, ...)`) so the rest of the app's `ref.watch(databaseProvider)` resolves
to the identical instance. Search `lib/` for any other direct `AppDatabase()` construction outside of
`AppDatabase.memory()` (used in tests) and fix those too.

**Verify:** `grep -rn "AppDatabase()" lib/` should return zero hits outside of provider definitions and
test files. Functionally: log a meal, confirm the dashboard's `StreamBuilder` picks it up without a
manual refresh (this is the kind of thing that silently breaks with dual connections).

---

## Phase 1 — Core logging correctness

These all sit in the primary daily-use loop (log a meal, log your weight, see your calorie target) and
are currently producing silently wrong data or blocking basic actions — higher real-world impact than
the repo-hygiene items in Phase 2, even though they're individually smaller fixes.

### 1.1 Meal logging always logs against "today"
**Problem:** The dashboard's date bar lets you select a past day, but the "add meal" flow has no idea
that selection exists. `AiMealLoggerScreen` (`ai_meal_logger_screen.dart`) only takes a `mealType`
constructor argument — no date. It's pushed directly via
`MaterialPageRoute(builder: (context) => AiMealLoggerScreen(mealType: type))` from
`dashboard_meal_section.dart:194`, with the selected date dropped entirely. Its save handler calls
`repo.logFoodEntry(...)` (`food_repository.dart:41`), whose signature also has **no date parameter at
all**. The resulting `FoodLogsCompanion.insert()` never sets `loggedAt`, so it falls back to the Drift
column default — `dateTime().withDefault(currentDateAndTime)()` in `food_tables.dart:31` — which is
always "now." Selecting "Yesterday" and logging a meal silently files it under today instead, with no
error or warning, quietly corrupting the historical record (and anything built on it, like weekly
reports).

**Fix:**
- Add `required DateTime date` to `AiMealLoggerScreen`'s constructor and thread it from
  `dashboard_meal_section.dart` (pass the dashboard's currently-selected date, not `DateTime.now()`).
- Add an optional `DateTime? loggedAt` parameter to `FoodRepository.logFoodEntry()`, defaulting to
  `DateTime.now()` for any other callers, and pass it into `FoodLogsCompanion.insert(loggedAt:
  Value(loggedAt ?? DateTime.now()), ...)` instead of relying on the column default.
- Add a small, visible "Logging for [date]" label on the meal logger screen so the behavior is confirmed
  to the user, not just silently correct.
- Check `food_search_screen.dart` for the same gap — it's a separate meal-logging entry point and likely
  has the identical bug.

**Verify:** Select "Yesterday" on the dashboard date bar, log a meal, confirm it appears under yesterday
(not today) both immediately and after reopening the app — and that today's calorie total is unaffected.

### 1.2 Meals (and other logging) can be logged for future dates
**Problem:** `DashboardDateBar`'s `showDatePicker` call uses `lastDate: DateTime(2030)`, and the "next
day" chevron button has no bound check against today — both let you navigate arbitrarily far into the
future and log against it. Worth noting the workout-start flow already does this correctly (it blocks
starting a future-dated workout with a snackbar) — that's the pattern to copy, not reinvent.

**Fix:**
```dart
// dashboard_date_bar.dart
lastDate: DateTime.now(),
```
and disable (not just visually gray, actually disable) the "next day" `IconButton` when
`selectedDate` is already today:
```dart
onPressed: isToday ? null : () => onDateChanged(selectedDate.add(const Duration(days: 1))),
```

**Verify:** Confirm the date picker can't select a date past today, and the "next day" arrow does nothing
once you're on today.

### 1.3 Deleting a logged meal is swipe-only with no visible affordance
**Problem:** Delete functionality actually already exists and is correctly wired — `_LoggedItemRow` in
`dashboard_meal_section.dart:562` is a `Dismissible` with a confirmation dialog, correctly calling
`repo.deleteLogEntry(log.id)` (which itself is implemented correctly in `food_repository.dart`). The gap
is discoverability, not capability: there's no visible icon or hint in the row's resting state — a user
has to already know to swipe left to find it, which is why it reads as "no way to delete."

**Fix:** Add a visible, low-effort trigger alongside the existing swipe gesture — e.g., a small trailing
"..." or trash icon on each row that opens the same confirmation dialog already built. Keep the swipe
gesture as a shortcut for people who discover it, don't remove it.

**Verify:** A first-time user should be able to find and use delete without being told to swipe.

### 1.4 Weight trend chart looks broken; no real rate-limiting
**Problem:** `logBodyMeasurement()` (`workout_repository.dart:212`) already upserts by calendar day —
querying for an existing row between `todayStart` and `todayEnd` and updating it if found, inserting
only if not. That part is correct: logging weight multiple times in one sitting already correctly
overwrites the same row rather than creating duplicates. But the trend chart
(`weight_sparkline_card.dart`) requires `weightHistory.length >= 2`, and each calendar day only ever
contributes one point — so the chart needs entries on **two different days** before it renders anything.
Its empty-state copy, "Log at least 2 weight entries to see your trend chart," doesn't communicate that,
so anyone testing it within a single session (logging, re-logging, adjusting) sees it stuck and
reasonably concludes it's broken.

**Fix — matching what was asked (edit current entry freely, but lock out new entries for a longer
window):**
- Replace the pure same-day upsert with an explicit two-tier rule in `logBodyMeasurement()`: allow free
  edits to the most recent entry within a short grace window after it was logged (same day is a
  reasonable window, or tighten to the first several minutes if same-day is too loose), then block
  creating a *new* distinct entry until 7 days have passed since the last one.
- Surface this clearly in `LogWeightBottomSheet` — if within the edit window, show "Editing today's
  entry"; if locked, show "Next weigh-in unlocks in X days" rather than silently no-op'ing or always
  looking like a fresh log action.
- Fix the misleading empty-state copy in `weight_sparkline_card.dart` to reflect the real requirement
  ("Log entries on 2+ different days to see your trend" or similar), and consider showing an interim
  state (e.g., "1 entry logged — check back in a few days") instead of a generic blocked message.
- Worth flagging as a product tradeoff, not just an implementation detail: locking to a weekly cadence is
  a deliberate deviation from the more common "log daily, let the app average out fluctuations" pattern
  used by most fitness trackers. That's fine if it's intentional, just confirm it's the desired behavior
  rather than assumed — a mistyped entry is now locked in for a week if the edit window is missed.

**Verify:** Log weight today, confirm the sheet shows it's editable; try again same day, confirm it
updates the existing entry with clear "editing" feedback; after the lock window has passed (simulate by
adjusting the device clock or a debug flag), confirm a new entry is allowed and the chart now renders
with 2+ points.

### 1.5 Calorie goal stuck at 2000, no way to customize
**Problem:** `2000` is hardcoded as a fallback in at least six places (`dashboard_controller.dart`,
`ai_meal_planner_screen.dart`, `user_tables.dart`'s column default, `user_profile_provider.dart`,
`tdee_calculator.dart`), used whenever `SharedPreferences`'s `calorie_goal` key hasn't been set yet.
Onboarding *does* compute a real, personalized value via `TdeeCalculator` and saves it — but because of
0.1 (onboarding currently unreachable), no real user today ever completes onboarding, so everyone is
stuck on the generic fallback. This is very likely the direct cause of what's being seen. Separately,
independent of 0.1: there is currently **no UI anywhere** — checked `settings_screen.dart` and
`settings_controller.dart` — that lets a user view or manually adjust their calorie/macro target after
onboarding. It's write-once.

**Fix:**
- This item's biggest lever is 0.1 — once onboarding reliably runs for new users, most of "stuck at
  2000" resolves on its own. Don't duplicate that fix here, just note the dependency.
- Add a "Nutrition Goals" section to Settings: show the current calorie/protein/carb/fat targets, label
  the calculated value clearly as "Recommended: X kcal, based on your goal" (recomputed live from the
  stored profile via the same `TdeeCalculator` onboarding already uses), and make each field editable
  with the override saved back to the same `calorie_goal`/macro prefs keys everything else already
  reads.
- If a manual override diverges sharply from the calculated recommendation (e.g., more than ~20% off),
  show a soft inline warning rather than blocking it — respect the user's choice, just flag it.

**Verify:** A completed profile shows its real computed target in Settings, not 2000. Editing a value
there updates the dashboard's calorie ring and macro bars on next load.

---

## Phase 2 — Repo & code hygiene

### 2.1 Remove the 77MB APK from git history
**Problem:** `test_builds/indifit-v1.0.0-release.apk` is committed directly to git (confirmed via
`git ls-files`). Every clone of the repo pays for this permanently, and it'll only get worse as more
builds get added the same way.

**Fix:**
1. Stop the bleeding: add `test_builds/` (or `*.apk`) to `.gitignore`.
2. Set up a GitHub Actions release step (or manual release) that uploads built APKs to GitHub Releases
   instead of the repo.
3. Strip the existing blob from history with `git filter-repo` (preferred over `filter-branch`) or the
   BFG Repo-Cleaner:
   ```
   git filter-repo --path test_builds/indifit-v1.0.0-release.apk --invert-paths
   ```
   This rewrites history — coordinate with anyone else with a local clone, since they'll need to
   re-clone or hard-reset afterward.

**Verify:** `du -sh .git` before and after — should drop meaningfully. `git log --all -- test_builds/`
should show nothing.

### 2.2 Silent `catch (_) {}` swallowing errors
**Problem:** 21 instances across `lib/`, including the exact code path that caused 0.2. Comments like
`// Non-fatal; user keeps prior catalog` are reasonable for genuinely non-critical paths, but the pattern
makes bugs invisible — there's no way to know a seed/migration/write failed short of noticing a feature
doesn't work.

**Fix:** Not "add error UI to all 21" — most should still fail silently from the *user's* perspective.
Instead, route every swallowed exception through a single logging call so it's visible in Sentry/crash
reporting (already integrated per the CI setup) without changing user-facing behavior:
```dart
} catch (e, st) {
  CrashReportingService.instance.recordCrash(e, st, fatal: false);
}
```
Prioritize the data-seeding paths first (`app_database.dart`'s seed/upsert functions) since those are
exactly where 0.2 came from and where a silent failure has the biggest blast radius (an entire feature
looking empty with no error anywhere).

**Verify:** Deliberately break a seed function (e.g., reintroduce the 0.2 bug in a branch) and confirm it
now shows up in whatever dashboard `CrashReportingService` reports to, instead of just an empty screen.

### 2.3 Oversized "god screens"
**Problem:** Despite a commit claiming to decompose these, `progress_screen.dart` (786 lines),
`onboarding_screen.dart` (700), `dashboard_meal_section.dart` (670), `ai_meal_logger_screen.dart` (621),
and `workout_player_screen.dart` (592) are all still large, mixed-concern files (UI + state + business
logic in one `StatefulWidget`).

**Fix:** This is a genuine refactor, not a quick patch — treat it as its own mini-project per screen:
1. Extract a `XxxController` (Riverpod `Notifier`/`AsyncNotifier`) holding all state and business logic
   currently living in `_XxxScreenState` fields and methods.
2. Split the `build()` method's sub-trees into separate widget files under a `widgets/` subfolder (the
   dashboard already does this well — use it as the template).
3. Do one screen per PR, starting with `progress_screen.dart` (largest) or `onboarding_screen.dart`
   (touched heavily in Phase 3 anyway, so worth restructuring while you're in there).

**Verify:** No hard line-count target, but a reasonable goal is no single screen file over ~300 lines,
with state/logic living in a controller, not the widget's `State` class.

---

## Phase 3 — Onboarding redesign

Do 3.1–3.5 as one connected pass since they all touch `onboarding_screen.dart`; trying to land them as
separate PRs will cause merge pain.

### 3.1 Reconcile the two onboarding-shaped flows
**Problem:** `OnboardingScreen` (profile + calorie targets, 8 pages) and `OnboardingWizardScreen`
("AI Coach Setup," reused from Training Split to regenerate a routine) are entirely disconnected. Both
ask a "goal" question with different, non-reconciled option sets (`lose/maintain/gain` vs
`hypertrophy/strength/weight_loss`), and the second never pre-fills from the first.

**Fix — recommended approach:** Chain them into one continuous first-run flow, keep the wizard
independently reachable later for regeneration:
1. After `_completeOnboarding()` saves the profile, instead of navigating straight to
   `MainNavigationScaffold`, push `OnboardingWizardScreen` (rename it — see below) with the user's
   already-chosen goal passed in as a starting value.
2. Add a goal-mapping function so the two vocabularies talk to each other instead of asking twice:
   ```dart
   String mapDietGoalToTrainingGoal(String dietGoal) => switch (dietGoal) {
     'lose' => 'weight_loss',
     'gain' => 'hypertrophy',
     _ => 'hypertrophy',
   };
   ```
   Pass this as the wizard's initial `_selectedGoal` instead of the hardcoded `'hypertrophy'` default,
   and let the user confirm/change it rather than answering from scratch.
3. Rename `OnboardingWizardScreen` → `RoutineWizardScreen` (and the "AI Coach Setup" title can stay, but
   the class/file name should stop implying it's onboarding-specific, since it's also invoked later from
   Training Split). Update the two call sites in `routine_display_screen.dart` and the new one in
   `onboarding_screen.dart` accordingly.
4. Give the user a skip: not everyone wants an AI-generated split on day one. A "Skip for now, I'll build
   my own" option on the wizard's first step that routes straight to the dashboard is enough — and should
   route to the manual builder from 4.2 rather than a dead end.

**Verify:** Fresh onboarding → profile pages → routine wizard pre-filled with a sensible goal → dashboard
has both calorie targets and a workout split, no separate "empty state, go find Training Split" hop
required. Regenerating a split later from Training Split still works standalone.

### 3.2 Dead "target weight" onboarding page
**Problem:** `_targetWeightController` / `user_target_weight` is written to `SharedPreferences` at the
end of onboarding and never read anywhere else in the app — confirmed via a full-codebase grep. It's a
full onboarding page (extra friction) for data that currently does nothing.

**Fix — recommended:** wire it up rather than cut it, since a progress-to-goal indicator is a natural,
motivating dashboard element once it exists:
1. Add a small "Goal weight: X kg · Y kg to go" element to `progress_screen.dart`, computed from
   `user_target_weight` vs. the latest `BodyMeasurements` entry.
2. Pre-fill `_targetWeightController` with something smarter than a hardcoded `'70'` — default it to the
   user's just-entered current weight, or current weight ± 5–10% depending on the goal they picked one
   page earlier (lose → below current, gain → above, maintain → equal).

If wiring it up is out of scope right now, the fallback is to cut the page entirely and shorten
onboarding by one step — don't leave it collecting data that goes nowhere.

**Verify:** Enter a target weight in onboarding, confirm it appears somewhere real (progress screen)
afterward, not just written to prefs and forgotten.

### 3.3 Silent defaults on required-feeling choices
**Problem:** Sex, activity level, goal, and diet all start pre-selected (`male`, `moderate`, `maintain`,
`veg`). A user tapping through quickly can complete onboarding with defaults that don't reflect them,
silently skewing their BMR/TDEE calculation (sex specifically shifts the Mifflin-St Jeor result by ~166
kcal).

**Fix:** For the sex page specifically (it directly changes the calorie formula), require an explicit tap
before `Next` is enabled — no pre-selection:
```dart
String? _sex; // nullable, no default
...
onPressed: (_currentPage == 0 && _sex == null) ? null : _nextPage,
```
Activity/goal/diet are lower-stakes and reasonable to default, but consider visually distinguishing
"this is our suggested default" vs. "you chose this" (e.g., a subtle "Recommended" tag on the
pre-selected card) so it doesn't look identical to an active user choice.

**Verify:** On the sex page, confirm `Next` is disabled until a card is tapped. Confirm calorie
calculation changes correctly when sex changes on a re-run.

### 3.4 No draft persistence during onboarding
**Problem:** All 8 pages live in local widget state (`_age`, `_height`, text controllers, etc.) with
nothing saved until the very last step. Getting interrupted — a call, a notification, Android reclaiming
memory in the background — loses everything typed so far.

**Fix:** Debounce-save each field to `SharedPreferences` as the user moves between pages (you already do
this pattern at the end — just move it earlier and make it incremental):
```dart
void _nextPage() async {
  // existing validation...
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('onboarding_draft_age', _ageController.text);
  // ...one line per field, or serialize the whole draft as JSON under one key
  // ...existing page-advance logic
}
```
On `initState`, check for a draft and pre-fill controllers/state from it if present. Clear the draft keys
in `_completeOnboarding()` once the real values are saved.

**Verify:** Get partway through onboarding, force-quit the app, relaunch — you should resume with
previously entered values still in place, not a blank first page.

### 3.5 Raw `Navigator` mixed with `go_router`
**Problem:** Onboarding and the routine wizard both use `Navigator.push`/`pushReplacement` with
`MaterialPageRoute`, while the rest of the app routes through `go_router`. Mixing imperative and
declarative navigation can desync the router's internal state from the actual navigation stack —
particularly relevant now that 0.1 adds `redirect` logic that depends on the router knowing where you
are.

**Fix:** Replace with `context.go('/')` / `context.push(...)` equivalents, adding routes for onboarding
sub-flows to `app_router.dart` if they don't exist yet (the wizard currently has no route at all — it's
only reachable via direct widget push).

**Verify:** After finishing onboarding via the redirect-based flow from 0.1, confirm system back-button
behavior is sane (doesn't pop back into onboarding after you've completed it).

---

## Phase 4 — Workout & AI Coach rework

This is the biggest single area in the plan, and it's the one place worth treating as a genuine
mini-project rather than a list of patches — schedule it as its own block of time rather than
interleaving with everything else.

### 4.1 AI-generated routines ignore equipment/goal/injuries almost every time
**Problem:** This is a two-part bug that compounds. `AiRoutineService.generateRoutine()`
(`ai_routine_service.dart`) calls the backend with very aggressive timeouts —
`connectTimeout: 3s`, `receiveTimeout: 5s` (set in the constructor) — for what is a Gemini-backed
structured generation call, very likely against a Render free-tier backend that spins down after
inactivity and can take 30-50+ seconds to cold-start. Any timeout or error there silently falls through
to `_generateOfflineFallback()` (line 92), which:
- Completely ignores `equipment`, `goal`, and `experience` when choosing exercises — the exercise names
  are hardcoded (`Flat Barbell Bench Press`, `Barbell Squat`, `Lat Pulldown`) regardless of what was
  selected, so a "Bodyweight Only" or "Dumbbells Only" user still gets barbell and cable-machine moves.
- Only branches on `daysPerWeek == 3` vs. everything else — 4, 5, 6, or any other day count all collapse
  into the identical fixed 4-day Upper/Lower split.
- Doesn't even receive the `injuries` parameter — it's dropped at the call site, so injury-avoidance
  (which *is* sent to the real API) silently disappears the moment the fallback triggers.

This lines up exactly with what's being seen: "the same 3 or 4 day workout for every combination" and
"barbell workouts for a dumbbell-only setup" is exactly what you'd get if the app is landing on this
fallback near-constantly rather than the real Gemini-backed generation.

**Fix:**
- Raise the timeouts substantially — `connectTimeout` to ~10s, `receiveTimeout` to 30-45s — so a
  cold-starting backend and a genuine LLM call have room to finish. The wizard already shows a "crafting
  your split" loading state; it just needs the time budget to match.
- If cold starts on Render are the main culprit, a scheduled keep-alive ping (every ~10 minutes) is a
  cheap mitigation short of moving to a paid tier.
- Rebuild the offline fallback to actually use its inputs instead of returning static routines: query
  the local `exercises` table (equipment-tagged, and populated correctly once 0.2 is fixed) filtered by
  the selected equipment and relevant muscle groups, and give `daysPerWeek` a real branch for each common
  value (3/4/5/6) instead of a shared default for "everything that isn't 3." Pass `injuries` through and
  do basic keyword exclusion (e.g., skip squat/deadlift variants if "knee" or "lower back" was
  mentioned) — this tier doesn't need to be as smart as the real AI path, just no longer blind to its
  inputs.
- Label which path was used ("Generated offline" vs. "Generated by AI Coach") on the result screen, so
  this is visible and debuggable going forward instead of silently indistinguishable from the real thing.

**Verify:** With the backend intentionally unreachable (airplane mode, or point the base URL somewhere
invalid), generate a split for each equipment option — confirm the results are now genuinely different
per equipment choice, not the same barbell-heavy list every time. Separately, with the backend reachable
and warm, confirm a real call completes within the new timeout without falling back unnecessarily.

### 4.2 No way to edit an existing split once generated
**Problem:** `RoutineEditorScreen`'s "Templates" and "Manual Build" entry points
(`routine_display_screen.dart`, inside `_buildEmptyState()`, lines ~148-193) are only reachable when
there's no active routine yet. The moment a routine exists, `_buildRoutineLayout()` (line 201 on) offers
only "Start Workout" for the selected day and a weekly day-picker — no per-day edit, no add/remove/swap
exercise, no route into `RoutineEditorScreen` at all. The only way to change anything post-setup is the
AppBar's "Re-generate Split," which replaces the entire routine via the AI wizard. This matches the
report precisely: once a split exists, the only lever is "throw it away and start over."

**Fix:**
- Add a visible edit entry point inside `_buildRoutineLayout()` — e.g., an icon button next to the day
  title that opens `RoutineEditorScreen` pre-loaded with the current routine's data. Check whether
  `RoutineEditorScreen` currently only supports building a routine from scratch (likely, since it's
  presently only reachable from the empty state) and extend it to load-and-edit an existing one if so.
- At minimum, support day-level actions: add an exercise to a day, remove one, reorder, and toggle a day
  to/from rest. That covers the bulk of "let me manually tweak my split" without needing a full rebuild
  of the editor.
- Keep "Re-generate Split" available as a clearly-labeled, confirmation-gated destructive action, not the
  only option.

**Verify:** With an active routine, confirm there's a reachable edit path that doesn't require
regenerating the whole split. Add and remove a single exercise from one day, confirm it persists and
shows correctly the next time that day is opened in `WorkoutPlayerScreen`.

### 4.3 "Log a completed workout" already exists but is easy to miss
**Note — this one's in better shape than it looks.** `ManualLogSheet`
(`workout_player/widgets/manual_log_sheet.dart`) already accepts a `selectedDate` and correctly logs a
completed workout against that specific date. It's reachable via a `TextButton.icon` on the dashboard's
"Today's Workout" card (`today_workout_card.dart`, line ~109). So most of "log workouts that are already
completed" is already built and working — the gap is discoverability: it's a small text button that only
lives on the dashboard card, not somewhere someone reworking their split via Training Split would
naturally look.

**Fix:** Surface the same "Log a past workout" action from within `RoutineDisplayScreen` as well, so it's
discoverable from both places someone would reasonably look for it — no new logging logic needed, just a
second entry point into the existing sheet.

**Verify:** Confirm a completed workout can be logged for a specific past date from both the dashboard
and the Training Split screen, and that it shows up correctly in history/reports for that date.

### 4.4 Wizard naming/consolidation
Already covered under 3.1 — the "AI Coach Setup" wizard rename and goal-vocabulary reconciliation applies
here too, since it's the same screen invoked from both first-run onboarding and Training Split's
regenerate action. No separate work item, just flagging the overlap so it isn't done twice.

### 4.5 Extend the engagement pass to the workout section specifically
The visual/engagement items in Phase 5 were originally scoped mostly around the dashboard. Once 4.1 and
4.2 land, apply the same treatment here — this is the direct answer to "make it more engaging and easy
to use," not just "fix the bugs":
- The weekly day-selector (`_buildWeeklyCalendarHeader()`) currently only distinguishes "selected" vs.
  "rest day." Add a completed/missed state once a day's workout is logged (a checkmark or filled dot),
  turning it into an at-a-glance weekly-adherence view instead of just a day switcher.
- Apply the hero-number treatment from 5.4 to in-workout stats in `WorkoutPlayerScreen` (current set/rep,
  session volume) — this is the single most-engaged-with screen during actual training and currently
  uses the same modest typography as everything else.
- The PR-confetti pattern already exists here and works well — no action needed, just don't lose it in
  any rework of this screen.

**Verify:** Subjective/UX judgment call rather than a functional test — compare before/after for whether
the weekly view communicates "how am I doing this week" at a glance.

---

## Phase 5 — Visual & engagement polish

These don't have the "actively broken" urgency of Phases 0–1, but they're where the app currently reads
as a generic dark dashboard rather than something distinctive. Roughly ordered by impact-for-effort.

### 5.1 Light mode is likely broken
**Problem:** `colors.dart`'s `AppColors` class is one static, non-brightness-aware palette (near-white
text, near-black backgrounds) referenced directly in 709 places, vs. only 4 places using the actual
theme-aware `Theme.of(context).colorScheme`. The Settings toggle for light/dark/system almost certainly
produces broken (illegible) results in light mode today.

**Fix — this is the biggest single item in the plan, treat it as its own project:**
- **Quick mitigation (do this now):** remove or hide the light-mode option in Settings until it's fixed,
  so users can't hit a broken state. One line in `settings_screen.dart`.
- **Proper fix (schedule separately):** turn `AppColors` from static constants into brightness-aware
  getters, e.g.:
  ```dart
  class AppColors {
    static Color textPrimary(BuildContext c) =>
        Theme.of(c).brightness == Brightness.dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    // ...one per token
  }
  ```
  then mechanically update all 709 call sites from `AppColors.textPrimary` to
  `AppColors.textPrimary(context)` (a scripted find/replace gets most of the way, but every call site
  needs a `BuildContext` in scope, which isn't always true as-is). Alternatively, migrate to Flutter's
  own `Theme.of(context).colorScheme` + a custom `ThemeExtension` for the extra tokens (`success`,
  `warning`, `border`, etc.) — more idiomatic, but a bigger one-time rewrite.
- Given the size, this is a good candidate to hand to Claude Code as a dedicated task once you're ready,
  rather than doing by hand inline with everything else.

**Verify:** Toggle to light mode in Settings, walk through every tab — confirm all text is legible
against its background, not just the scaffold.

### 5.2 Extend the celebration pattern app-wide
**Problem:** A well-built 60-particle `ConfettiOverlay` and haptic feedback already exist and are used
for hitting the calorie goal and hitting a workout PR — but streak milestones (7/14/30/100 days) and
achievement unlocks currently just show a plain `SnackBar` with an emoji, in `dashboard_screen.dart`
around the `ref.listen` block.

**Fix:** Reuse the existing widget instead of building something new:
```dart
// track a bool like `_celebratingAchievement` in DashboardState,
// set it true when an achievement/milestone fires, then:
ConfettiOverlay(
  isPlaying: state.celebratingMilestone || isCalorieGoalMet,
  child: ...
)
```
`ConfettiOverlay` already does rising-edge detection (`didUpdateWidget`), so multiple trigger sources
feeding into one `isPlaying` bool is safe — it won't double-fire. Consider a distinct particle palette
(gold/amber tones) for achievement unlocks vs. the default rainbow, so the two moments feel different by
color.

**Verify:** Hit a streak milestone (or force one for testing) — confirm confetti fires, not just a
snackbar. Confirm it still also fires correctly for the calorie-goal case (no regression).

### 5.3 Static progress bars/rings, no animation
**Problem:** `flutter_animate` is installed and proven working in `skeleton_loader.dart`, but used
nowhere else. Every `CircularPercentIndicator` and `LinearProgressIndicator` on the dashboard snaps
instantly to its new value on rebuild.

**Fix:** Wrap the value, not just the widget — animate the underlying number so both the number and the
bar/ring move together:
```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0, end: calPercent),
  duration: const Duration(milliseconds: 600),
  curve: Curves.easeOutCubic,
  builder: (context, value, _) => CircularPercentIndicator(percent: value, /* ... */),
)
```
Apply the same pattern to the macro bars in `calorie_ring_card.dart`, the weekly-action bar in
`dashboard_screen.dart`, and the streak/water trackers. This is a small, mechanical, repeatable change —
good candidate to batch across all dashboard cards in one pass.

**Verify:** Log a meal and watch the dashboard update — bars/rings should ease to their new value over
~500ms rather than jumping.

### 5.4 Hero numbers too small
**Problem:** The calorie ring's central number — the single most-viewed stat in the app — renders at
20sp inside a 60px-radius ring, with macro labels at 10-11sp.

**Fix:** In `calorie_ring_card.dart`, bump the central calorie number to something in the 32-40sp range,
increase ring radius/stroke proportionally (e.g., radius 70-75, stroke 12-14), and add small food-type
icons (protein/carbs/fat) next to each macro bar instead of relying on color alone. Apply the same
"biggest number gets the most visual weight" principle to streak count and current weight elsewhere on
the dashboard, and to in-workout stats per 4.5.

**Verify:** Side-by-side screenshot before/after — the calorie number should be the clear focal point of
the card at a glance, not competing evenly with the macro bars.

### 5.5 Ad hoc color usage outside the design system
**Problem:** `primary` (`#1D9E75`) and `success` (`#10B981`) are close enough in hue that they don't
clearly distinguish "brand color" from "good news." Meanwhile `Colors.orange` (streaks),
`Colors.blue` (equipment filter chips), `Colors.teal` (fiber macro) are pulled in directly rather than
being part of `AppColors`.

**Fix:** Add these as named tokens in `colors.dart` (`streakOrange`, `infoBlue`, `fiberTeal`, etc.) so
they're intentional and reusable rather than one-off `Colors.X` calls scattered through feature files.
Consider shifting `success` toward a more visually distinct hue from `primary` if you want color to
reliably communicate "this specific thing succeeded" vs. "this is a branded/interactive element."

**Verify:** `grep -rn "Colors\.\(orange\|blue\|teal\|amber\)" lib/` — every hit should either move into
`AppColors` or have a clear reason not to.

### 5.6 Achievement badges use generic stock icons
**Problem:** `achievements_screen.dart` renders every badge with the same one or two stock Material
icons (`Icons.workspace_premium_rounded`, `Icons.emoji_events_rounded`) regardless of what was earned.
For a feature literally named "Achievements & Badges," this is the highest-leverage place in the app to
add visual distinctiveness.

**Fix:** Doesn't require commissioned art — a small set of flat-colored SVG or custom-painted badge
shapes (bronze/silver/gold tiers, distinct silhouettes per achievement category: streak, strength, meal
logging, etc.) goes a long way. Even 6-8 distinct badge designs reused across achievement instances would
be a large visible improvement over one repeated trophy icon.

**Verify:** Unlock two different achievement types — confirm they look visually distinct, not just
different text next to the same icon.

### 5.7 Empty states are functional but generic
**Problem:** Exercise library, achievements, and Training Split all use the identical pattern: muted
icon, gray text, optional outlined button. Fine, but forgettable, and seen often by new/light users.

**Fix:** Not urgent enough to redo everywhere, but worth a pass once 5.6's badge artwork exists — reuse
that same illustration style for empty states so the app develops a consistent "custom art" vocabulary
instead of falling back to Material defaults everywhere.

**Verify:** Subjective — compare before/after screenshots for whether it reads as "designed" vs.
"default."

### 5.8 Settings buried in overflow menu
**Problem:** Settings is only reachable via a 3-dot `PopupMenuButton` on the dashboard header, alongside
"AI Meal Planner" — a fairly low-discoverability spot for a frequently-needed destination.

**Fix:** Give Settings its own icon button next to (not inside) the overflow menu, or move it into the
bottom nav / a dedicated profile entry point if the app grows a "Profile" concept later.

**Verify:** Subjective/UX-judgment call, not a functional test — just confirm it's a one-tap reach rather
than two.

### 5.9 Unused `lottie` dependency
**Problem:** `lottie: ^3.1.0` is in `pubspec.yaml` and never imported anywhere — adds to build size for
zero benefit currently.

**Fix — pick one:** either remove it (`flutter pub remove lottie`) if there's no near-term plan to use
it, or actually use it for one or two of the celebration moments from 5.2 (a Lottie file can be richer
than the hand-built particle confetti for something like a first-achievement-ever moment). Don't leave it
installed-and-unused indefinitely.

**Verify:** `flutter pub deps` no longer lists it (if removed), or at least one `Lottie.asset(...)` call
exists in the codebase (if kept).

---

## Suggested sequencing

1. **Week 1:** Phase 0 in full (0.1–0.4). Small, independent, each fixes something broken for every user.
2. **Week 1-2:** Phase 1 in full (1.1–1.5) alongside the tail of Phase 0 — these are the next tier of
   "silently wrong data / blocked basic actions" and are mostly small, contained fixes. 2.1 and 2.2
   (repo hygiene) can slot in wherever there's spare time, low risk either way.
3. **Week 2-3:** Phase 3, the onboarding redesign, as one connected pass (3.1–3.5) — benefits from being
   done as a single coherent rework rather than piecemeal edits.
4. **Week 3-5:** Phase 4, the workout/AI Coach rework. Treat 4.1 and 4.2 as their own mini-projects (each
   is genuinely "a feature," not a patch); 4.3 is quick and can land anytime; do 4.5 once 4.1/4.2 are
   stable so the engagement work isn't built on top of the broken generator.
5. **Week 4-6 (parallel with Phase 4):** Phase 5 items 5.2–5.5, 5.8, 5.9 (small/independent, good filler
   between bigger work). Schedule 5.1 (light mode) and 2.3 (god screens) as their own dedicated efforts
   given their size — don't try to squeeze either in alongside other work.
6. **Ongoing:** 5.6/5.7 (custom badge and empty-state artwork) whenever design time is available — not
   blocking, but the highest-visibility "makes the app feel designed" item on the list.

## Testing checklist before considering this plan "done"

- [ ] Fresh install → onboarding appears, completes, routes to dashboard with real data
- [ ] Fresh install → Exercise Library shows all 140 exercises
- [ ] Release APK contains no hardcoded auth key string
- [ ] Only one `AppDatabase` instance exists app-wide
- [ ] Selecting a past date and logging a meal files it under that date, not today
- [ ] The date bar can't be pushed into the future
- [ ] A logged meal can be deleted without already knowing to swipe
- [ ] Weight log gives clear "editing" vs. "locked until X" feedback, and the chart renders once 2+
      distinct days of data exist
- [ ] Settings shows the real computed calorie goal (not 2000) and lets it be edited
- [ ] AI-generated routines visibly differ by equipment selection, including when the offline fallback
      is the one generating them
- [ ] An existing workout split can be edited (add/remove/swap an exercise) without full regeneration
- [ ] Light mode is either fully legible or hidden from Settings
- [ ] Streak milestone and achievement unlock both trigger the confetti+haptic pattern
- [ ] Dashboard progress bars/rings animate on value change
- [ ] `git clone` of the repo no longer pulls down a 77MB APK
