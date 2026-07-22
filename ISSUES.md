# IndiFit — Prioritized Issues Tracker

> Generated from codebase analysis on 2026-07-22.  
> Each issue includes file references, severity, acceptance criteria, and suggested assignee scope.

---

## 🔴 P0 — Critical (Ship Blockers)

---

### #1 Remove hardcoded default API key from backend and Flutter
**Labels:** `security`, `backend`, `flutter`, `P0`  
**Severity:** High  
**Files:** `backend/main.py:28`, `lib/core/di/providers.dart:23`

#### Description
Both the FastAPI backend and the Flutter client ship with a hardcoded fallback API key (`indifit_secret_key_v1`). If the environment variable is unset during deployment, the backend accepts requests from anyone who knows this string. The same string is compiled into the Flutter binary, making it extractable.

#### Acceptance Criteria
- [ ] Remove the default value from `os.getenv("INDIFIT_API_KEY", "...")` in `backend/main.py`
- [ ] Remove the default value from `String.fromEnvironment('INDIFIT_API_KEY', defaultValue: '...')` in `lib/core/di/providers.dart`
- [ ] Backend crashes on startup with a clear error message if `INDIFIT_API_KEY` is missing
- [ ] Flutter app shows a developer-friendly error screen if the API key is missing in debug builds
- [ ] Update `README.md` with instructions for setting the key in both `.env` and compile-time defines

#### Suggested Fix
```python
# backend/main.py
INDIFIT_API_KEY = os.getenv("INDIFIT_API_KEY")
if not INDIFIT_API_KEY:
    raise RuntimeError("INDIFIT_API_KEY environment variable is required")
```

---

### #2 Duplicate AppDatabase instantiation causes double SQLite connection
**Labels:** `architecture`, `flutter`, `data-layer`, `P0`  
**Severity:** High  
**Files:** `lib/main.dart:33`, `lib/core/di/providers.dart:11`

#### Description
`main.dart` creates `AppDatabase()` directly to pass into `NotificationService.scheduleAllReminders(db)` and `AutoBackupService.performBackup(db)`. Meanwhile, `databaseProvider` also instantiates `AppDatabase()` for the rest of the app. Drift handles file locking, but this creates two independent connection objects to the same SQLite file, which can lead to subtle race conditions, WAL journal conflicts, or inconsistent read snapshots.

#### Acceptance Criteria
- [ ] `main.dart` uses `databaseProvider` (or a shared singleton) instead of a raw `AppDatabase()` constructor
- [ ] `NotificationService.scheduleAllReminders` and `AutoBackupService.performBackup` accept an `AppDatabase` instance from the provider container
- [ ] Verify via logging that only one `LazyDatabase` / `NativeDatabase` is opened per app lifecycle

#### Suggested Fix
```dart
// main.dart
final container = ProviderContainer();
final db = container.read(databaseProvider);
await NotificationService.scheduleAllReminders(db);
AutoBackupService.performBackup(db).catchError(...);
```

---

### #3 Add input validation to FastAPI endpoints
**Labels:** `backend`, `api`, `P0`  
**Severity:** High  
**Files:** `backend/main.py`

#### Description
The FastAPI Pydantic request models do not validate numeric ranges or enum constraints. For example, `days_per_week` can be `999`, `calorie_goal` can be negative, and `diet_preference` accepts any string.

#### Acceptance Criteria
- [ ] `RoutineRequest.days_per_week` validated to `1 <= v <= 7`
- [ ] `RoutineRequest.experience` validated to `beginner | intermediate | advanced`
- [ ] `MealPlanRequest.calorie_goal` validated to `500 <= v <= 10000`
- [ ] `MealPlanRequest.diet_preference` validated to `veg | non-veg | vegan`
- [ ] `TextMealRequest.text` validated to non-empty, max 500 chars
- [ ] Add a custom exception handler that returns structured `{"detail": "...", "field": "..."}` responses

#### Suggested Fix
```python
from pydantic import field_validator

class RoutineRequest(BaseModel):
    goal: str
    equipment: str
    days_per_week: int
    experience: str
    injuries: str

    @field_validator('days_per_week')
    @classmethod
    def validate_days(cls, v: int) -> int:
        if not 1 <= v <= 7:
            raise ValueError('days_per_week must be between 1 and 7')
        return v

    @field_validator('experience')
    @classmethod
    def validate_experience(cls, v: str) -> str:
        allowed = {'beginner', 'intermediate', 'advanced'}
        if v.lower() not in allowed:
            raise ValueError(f'experience must be one of {allowed}')
        return v.lower()
```

---

## 🟡 P1 — High (Required for v1.0)

---

### #4 Silent error swallowing hides runtime failures
**Labels:** `reliability`, `flutter`, `P1`  
**Severity:** Medium  
**Files:** `lib/features/dashboard/dashboard_controller.dart:174`, `lib/features/dashboard/dashboard_screen.dart:106`, `lib/data/database/app_database.dart:102,159,181`

#### Description
Multiple critical paths use empty `catch (_) {}` blocks, which silently discard errors. This makes debugging impossible in production and can leave the app in an inconsistent state (e.g., dashboard shows stale data because `loadTodayWorkout()` failed but the UI never knew).

#### Acceptance Criteria
- [ ] Replace all empty `catch (_) {}` with at minimum `AppLogger.error(...)`
- [ ] In controllers, consider adding an `errorMessage` field to the state so the UI can show a SnackBar or error card
- [ ] In `app_database.dart` seed/upsert failures, log the exception and stack trace rather than swallowing

#### Suggested Fix
```dart
// dashboard_controller.dart
try {
  await loadTodayWorkout();
} catch (e, st) {
  AppLogger.error('Failed to load today workout', e, st, 'DashboardController');
  state = state.copyWith(errorMessage: 'Could not load workout schedule');
}
```

---

### #5 DashboardController initialization is fully sequential
**Labels:** `performance`, `flutter`, `P1`  
**Severity:** Medium  
**Files:** `lib/features/dashboard/dashboard_controller.dart:87–102`

#### Description
Five independent async initialization methods are awaited sequentially, blocking the dashboard from rendering until the slowest one finishes. On slower devices this can add 200–500ms to first paint.

#### Acceptance Criteria
- [ ] Group independent async calls with `Future.wait([...])`
- [ ] Ensure error handling still works for individual failures inside `Future.wait`
- [ ] Verify dashboard first-paint time improvement (manual stopwatch or widget test timer)

#### Suggested Fix
```dart
Future<void> loadStateData() async {
  final prefs = await SharedPreferences.getInstance();
  final weight = prefs.getDouble('current_weight') ?? 74.5;
  final calGoal = prefs.getInt('calorie_goal') ?? 2000;
  state = state.copyWith(currentWeight: weight, calorieGoal: calGoal);

  await Future.wait([
    loadTodayWorkout(),
    calculateWeeklyAdherence(),
    loadWeightHistory(),
    computeStreak(),
    loadWeeklyActionProgress(),
  ]);
}
```

---

### #6 Unify navigation: migrate MaterialPageRoute pushes to GoRouter
**Labels:** `ux`, `flutter`, `navigation`, `P1`  
**Severity:** Medium  
**Files:** `lib/features/dashboard/dashboard_screen.dart:85,125,136,254`, `lib/core/router/app_router.dart`

#### Description
The app declares `GoRouter` in `app_router.dart` but internally uses `MaterialPageRoute` pushes for half the screens. This breaks deep-linking, breaks the browser back button (if web is ever added), and makes route parameters inconsistent.

#### Acceptance Criteria
- [ ] All `Navigator.push(context, MaterialPageRoute(...))` calls in `dashboard_screen.dart` replaced with `context.go('/path')` or `context.push('/path')`
- [ ] `WorkoutPlayerScreen` route added to `app_router.dart` with query parameters for `routineName`, `exerciseIndex`, `setIndex`, `elapsedSeconds`
- [ ] Resume-workout dialog navigates via GoRouter instead of raw `Navigator.push`
- [ ] Deep-link to `/workout` from notification payload still works after migration

---

### #7 Duplicate/overlapping repository methods
**Labels:** `tech-debt`, `flutter`, `P1`  
**Severity:** Medium  
**Files:** `lib/data/repositories/food_repository.dart`

#### Description
`FoodRepository` contains near-duplicate method pairs that do the same operation with slightly different signatures. This increases maintenance surface and invites bugs when one is updated but the other is not.

#### Acceptance Criteria
- [ ] Consolidate `saveMealTemplate()` (line 215) and `createMealTemplate()` (line 462) into a single method
- [ ] Consolidate `getAllMealTemplates()` (line 277) and `getMealTemplates()` (line 448) into a single method
- [ ] Consolidate `logFromMealTemplate()` (line 309) and `logMealTemplate()` (line 495) into a single method
- [ ] Update all call sites to use the canonical method name
- [ ] Verify no regressions via `food_repository_test.dart`

---

### #8 Add backend unit and integration tests
**Labels:** `testing`, `backend`, `P1`  
**Severity:** Medium  
**Files:** `backend/`

#### Description
The Flutter frontend has 26 test files, but the FastAPI backend has zero. The mock fallback constructors (`_mock_routine`, `_mock_meal_estimate`, `_mock_meal_plan`, `_mock_weekly_report`) and the API key verification are untested.

#### Acceptance Criteria
- [ ] Add `pytest` and `httpx` to `backend/requirements.txt` (dev section)
- [ ] Test `verify_api_key` dependency: valid key, missing key, wrong key
- [ ] Test `enforce_rate_limit`: under limit, at limit, over limit, window expiry
- [ ] Test each `_mock_*` fallback constructor returns valid JSON matching the expected schema
- [ ] Test each endpoint (`/api/ai/routine`, `/api/ai/meal-estimate-text`, `/api/ai/meal-plan`, `/api/ai/weekly-report`) with valid payloads and assert 200 + schema
- [ ] Test `/api/ai/meal-estimate-photo` with an invalid MIME type asserts 400
- [ ] Add GitHub Actions workflow (or equivalent) to run backend tests on PR

---

### #9 Fix or remove unused cache and rate-limit dead code
**Labels:** `backend`, `tech-debt`, `P1`  
**Severity:** Medium  
**Files:** `backend/main.py:31–38`

#### Description
`RESPONSE_CACHE` and `CACHE_TTL_SECONDS` are defined but never read or written. The in-memory rate limiter (`IP_REQUEST_LOGS`) won't work across multiple Uvicorn workers.

#### Acceptance Criteria
- [ ] **Option A:** Implement a real cache (Redis, or simple in-memory with TTL) and wire it into the Gemini query helpers
- [ ] **Option B:** Remove `RESPONSE_CACHE` and `CACHE_TTL_SECONDS` to eliminate dead code
- [ ] Add a `README.md` note explaining that rate limiting should be handled at the reverse-proxy layer (nginx, Cloudflare) for production multi-worker deployments

---

## 🟢 P2 — Medium (Architecture & Polish)

---

### #10 Raw SQL in `getRecentFoods` bypasses Drift type safety
**Labels:** `data-layer`, `flutter`, `P2`  
**Severity:** Low-Medium  
**Files:** `lib/data/repositories/food_repository.dart:359`

#### Description
`getRecentFoods()` uses `customSelect` with a raw SQL string. If the `food_logs` table schema changes (e.g., column rename), this will fail at runtime instead of being caught by `drift_dev` / `build_runner`.

#### Acceptance Criteria
- [ ] Rewrite `getRecentFoods()` using Drift's Dart query DSL, or create a DAO class with a generated query
- [ ] Ensure the query still returns the same `List<FoodItem>` shape
- [ ] Add a unit test that asserts the query returns recently-logged items ordered correctly

---

### #11 JSON blob column for workout draft sets loses type safety
**Labels:** `data-layer`, `flutter`, `P2`  
**Severity:** Low  
**Files:** `lib/features/dashboard/dashboard_screen.dart:70`, `lib/data/database/tables/workout_tables.dart`

#### Description
`WorkoutDrafts.loggedSetsJson` stores a JSON-encoded list of maps. This means schema changes to `WorkoutSetsCompanion` won't be caught at compile time for draft restoration.

#### Acceptance Criteria
- [ ] Evaluate whether normalizing draft sets into a separate `draft_sets` table is worth the migration cost
- [ ] If keeping JSON, add a schema-version check on restore and show an error if the JSON shape is incompatible
- [ ] Add a unit test that round-trips a draft through JSON encode → decode → `WorkoutSetsCompanion`

---

### #12 `WaterNotifier` timer runs every 15 seconds continuously
**Labels:** `performance`, `battery`, `flutter`, `P2`  
**Severity:** Low  
**Files:** `lib/core/di/providers.dart:62–71`

#### Description
A `Timer.periodic(Duration(seconds: 15), ...)` runs for the entire app lifecycle to detect midnight. On a phone left open overnight, this is unnecessary battery usage.

#### Acceptance Criteria
- [ ] Replace the periodic timer with a check on `AppLifecycleState.resumed` (via `WidgetsBindingObserver`)
- [ ] Alternatively, use `Workmanager` or `flutter_local_notifications` to schedule a midnight callback
- [ ] Ensure water count still resets correctly when the app is opened after midnight

---

### #13 Dashboard `SingleChildScrollView` rebuilds entire tree on every food log change
**Labels:** `performance`, `flutter`, `P2`  
**Severity:** Low  
**Files:** `lib/features/dashboard/dashboard_screen.dart:148–283`

#### Description
The entire dashboard is wrapped in a `StreamBuilder` over `watchLogsForDay()`. Every time a food log is inserted, updated, or deleted, the entire widget tree rebuilds. As the dashboard grows, this becomes expensive.

#### Acceptance Criteria
- [ ] Extract `CalorieRingCard` and `DashboardMealSection` into independent `Consumer` widgets that watch only the data they need
- [ ] Use `select` on Riverpod providers to narrow rebuilds (e.g., `ref.watch(dashboardControllerProvider.select((s) => s.selectedDate))`)
- [ ] Profile with Flutter DevTools to confirm reduced rebuild count after refactor

---

### #14 Add integration tests for core user flows
**Labels:** `testing`, `flutter`, `P2`  
**Severity:** Low  
**Files:** `test/`

#### Description
The unit and widget test coverage is excellent, but there are no end-to-end integration tests for critical user journeys.

#### Acceptance Criteria
- [ ] Add `integration_test/log_meal_workout_flow_test.dart` covering:
  1. Open app → log a breakfast item → verify dashboard calorie ring updates
  2. Start a workout → log sets → finish workout → verify session appears in history
  3. Generate weekly report → verify report screen renders
- [ ] Add `integration_test/onboarding_flow_test.dart` covering onboarding wizard completion
- [ ] Document how to run integration tests in `README.md`

---

## 🔵 P3 — Low (Nice to Have)

---

### #15 Dead code: `_buildQuickActionsRow` is never called
**Labels:** `cleanup`, `flutter`, `P3`  
**Severity:** Low  
**Files:** `lib/features/dashboard/dashboard_screen.dart:341–387`

#### Description
The `_buildQuickActionsRow` method is fully implemented but never referenced in the `build()` method. It appears to have been replaced by inline buttons or another layout.

#### Acceptance Criteria
- [ ] Either wire `_buildQuickActionsRow` back into the dashboard layout, or delete it
- [ ] If deleting, check for any unused imports that were only needed by this method

---

### #16 `AppTheme` Google Fonts runtime fetching may fail offline
**Labels:** `ux`, `flutter`, `P3`  
**Severity:** Low  
**Files:** `lib/core/theme/app_theme.dart:100–108`

#### Description
`GoogleFonts.outfitTextTheme(baseTextTheme)` fetches fonts from Google servers at runtime. If the user is offline on first launch, text will fall back to system defaults unexpectedly.

#### Acceptance Criteria
- [ ] Bundle the Outfit font files in `assets/fonts/` and declare them in `pubspec.yaml`
- [ ] Use `GoogleFonts.outfitTextTheme(baseTextTheme)` only as a fallback, or switch to explicitly bundled fonts
- [ ] Verify offline-first behavior: uninstall app → enable airplane mode → install → text renders correctly

---

### #17 Inconsistent use of `AppLogger` vs `debugPrint`
**Labels:** `cleanup`, `flutter`, `P3`  
**Severity:** Low  
**Files:** Various

#### Description
Some files use `AppLogger.error/warning`, while others might still use `print` or `debugPrint`. The `analysis_options.yaml` enables `avoid_print`, but manual audit is needed.

#### Acceptance Criteria
- [ ] Run `flutter analyze` and fix any `avoid_print` violations
- [ ] Search for any remaining `print(` or `debugPrint(` statements outside of `AppLogger`
- [ ] Ensure all error logs include a `tag` parameter for filtering in Sentry/crash reports

---

### #18 HealthKit / Health Connect usage descriptions missing audit
**Labels:** `compliance`, `ios`, `android`, `P3`  
**Severity:** Low  
**Files:** `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`

#### Description
The `health: ^11.0.0` plugin requires specific `Info.plist` keys (`NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`) and Android permissions. These should be audited to ensure they are present and user-friendly.

#### Acceptance Criteria
- [ ] Verify `ios/Runner/Info.plist` contains `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` with descriptive strings
- [ ] Verify `AndroidManifest.xml` contains the necessary `android.permission.ACTIVITY_RECOGNITION` or Health Connect permissions
- [ ] Ensure health data is never sent to the backend (currently local-only — verify and document)

---

### #19 Weekly report endpoint uses fixed default values instead of real data
**Labels:** `backend`, `data`, `P3`  
**Severity:** Low  
**Files:** `backend/main.py:503–510`

#### Description
`WeeklyReportRequest` has hardcoded defaults for all fields (`total_calories_logged: int = 14000`, etc.). If the Flutter app forgets to send a field, the backend silently uses a fake value instead of failing.

#### Acceptance Criteria
- [ ] Remove all default values from `WeeklyReportRequest` fields
- [ ] Ensure Flutter client always sends real computed values
- [ ] Add a test that asserts 422 when required fields are missing

---

### #20 Sentry DSN should not be hardcoded in release builds
**Labels:** `security`, `flutter`, `P3`  
**Severity:** Low  
**Files:** `lib/core/services/crash_reporting_service.dart`

#### Description
If the Sentry DSN is hardcoded in Dart source, it is visible in the compiled binary. For a public repo or open-source project, this could allow abuse of your Sentry quota.

#### Acceptance Criteria
- [ ] Move Sentry DSN to `--dart-define=SENTRY_DSN=...` or `.env` file
- [ ] Initialize Sentry only if the DSN is present (graceful no-op in debug or self-builds)
- [ ] Document the DSN setup in `README.md`

---

## Issue Count Summary

| Priority | Count | Theme |
|----------|-------|-------|
| 🔴 P0 — Critical | 3 | Security, data integrity, input validation |
| 🟡 P1 — High | 6 | Reliability, performance, navigation, testing |
| 🟢 P2 — Medium | 5 | Architecture, polish, battery, integration tests |
| 🔵 P3 — Low | 6 | Cleanup, compliance, offline UX, documentation |
| **Total** | **20** | |

---

## Quick-Start: Recommended Sprint Order

**Sprint 1 (Week 1):** #1, #2, #3, #4  
**Sprint 2 (Week 2):** #5, #6, #7, #8  
**Sprint 3 (Week 3):** #9, #10, #11, #12, #14  
**Sprint 4 (Week 4):** #13, #15, #16, #17, #18, #19, #20

---

> **How to use this file:**  
> Copy each issue into your GitHub/GitLab Issues tab. The file references use `path:line` format so developers can jump directly to the relevant code in their IDE.
