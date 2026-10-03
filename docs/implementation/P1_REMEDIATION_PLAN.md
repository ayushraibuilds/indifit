# IndiFit — P1 Remediation Implementation Plan

**Date:** 2026-10-03 · **Base:** `main` @ `32cf07d`
**Source:** [`docs/audit/INDEPENDENT_AUDIT_2026-10-01.md`](../audit/INDEPENDENT_AUDIT_2026-10-01.md), §5 (P1), plus the "Week 2" items from §6 and §8
**Goal:** No silent failures. A user whose database breaks can still get their data out. Settings take effect when changed. Everything the app shows (streak, workout state) comes from one source of truth. Then cut friction from the two daily loops: logging a set and logging food.

Each item was re-checked against `main` on 2026-10-03. Some audit findings are already fixed or smaller than the audit said; those are marked.

---

## 0. Summary

| # | Problem (as of 2026-10-03) | Workstream | Effort (solo) | Before launch? |
|---|---|---|---|---|
| P1-1 | Crash-reporting opt-in does nothing until restart; exception messages aren't scrubbed | **WS-A: Crash reporting** | 0.5 day | Yes (privacy) |
| P1-2 | No recovery screen when the database fails to open | **WS-B: Startup resilience** | 1–1.5 days | Yes |
| P1-3 | Repairs and index rebuilds run on every launch | **WS-B** (same PR series) | 0.5 day + measurement | Measure first; fix if cold start > 300 ms |
| P1-4 | 37 empty `catch` blocks across 26 files; no lint | **WS-C: No silent failures** | 1 day | Data-path ones yes; the rest any time |
| P1-5 | Streak stored in SharedPreferences, written only by the dashboard | **WS-D: Single sources of truth** | 0.5–1 day | Yes (shown on achievements and in the player) |
| P1-6 | Two separate controllers can own the same workout draft | **WS-D** | 1–2 days | Recommended; risky to rush |
| P1-7 | Misleading "HKDF stops brute force" comment in cloud backup | **WS-E: Dormant code** | 0.25 day | No: the code isn't reachable in v1 |
| P1-8 | Backend hygiene | **WS-F: Backend leftovers** | 0.25 day | Mostly already done (see below) |
| P1-9 | No router `errorBuilder`; unknown links show go_router's raw error page | **WS-G: Router fallback** | 0.25 day | Yes |
| UX | Player friction, dashboard colour meaning, disabled-looking tiles, empty thali | **WS-H: Daily-loop polish** | 3–4 days | Strongly recommended |

**Order:** A, G, F (quick wins, 1 day) → B → C → D → H. E can be done any time or dropped.

**Total:** about 5–6 days for P1-1 to P1-9, plus 3–4 days for the UX polish. Everything here is code-only. Nothing needs the Apple or Google accounts, so it can run while P0 waits on them.

---

## 1. Decisions (defaults chosen; change them if you disagree)

| Decision | Recommended default | Why | Alternative |
|---|---|---|---|
| E1: Dormant cloud backup/sync client code (`lib/core/backup/cloud_backup_service.dart`, `lib/core/sync/sync_service.dart`) | **Keep it; fix the comment and add a "not for user-chosen secrets" assert** | Nothing creates these services today, so there's no user exposure. Deleting about 1k lines with tests is a separate cleanup. | Delete both, with their tests, in a post-launch cleanup PR |
| E2: When the DB fails to open | **Show a recovery screen offering "Export database file" and "Contact support"; never auto-reset** | Auto-reset destroys the only copy of the user's data | Also offer "Reset app" behind a typed confirmation (add later, after real reports) |
| E3: Per-launch repairs (P1-3) | **Measure first.** Gate behind a stored repair version only if `beforeOpen` costs more than 300 ms on a mid-range Android phone. | The trigger reinstall is a deliberate safety measure (comment in `app_database.dart`); don't remove it for an unmeasured gain | Gate unconditionally |
| E4: Streak storage | **Derive it from the DB in one repository; keep only freezes in prefs** | Removes the "whoever last opened the dashboard" staleness | Keep the prefs cache, but have every reader refresh it first |
| E5: Workout controllers (P1-6) | **The screen controller owns the draft; the global provider only launches** | One owner per draft removes the write-race class of bugs | Leave as is and add a test proving the two never write concurrently |

---

## 2. Branch & PR sequence

Use one PR per row. Each PR must pass CI before the next one merges. Run `flutter analyze`, `flutter test --exclude-tags golden` and `python3 tool/generate_code_graph.py` before every push.

| Order | Branch | Contents |
|---|---|---|
| 1 | `fix/crash-reporting-live-optin` | WS-A |
| 2 | `fix/router-error-fallback` | WS-G |
| 3 | `chore/backend-cors-tidy` | WS-F |
| 4 | `feat/db-open-recovery` | WS-B part 1 (P1-2) |
| 5 | `perf/launch-repair-gate` | WS-B part 2 (P1-3): only if the measurement says so |
| 6 | `fix/no-silent-catches` | WS-C |
| 7 | `fix/streak-from-db` | WS-D part 1 (P1-5) |
| 8 | `refactor/single-draft-owner` | WS-D part 2 (P1-6) |
| 9 | `docs/cloud-crypto-comment` | WS-E |
| 10+ | `feat/player-*`, `fix/dashboard-colours`, … | WS-H, one PR per bullet |

---

## WS-A — Crash reporting takes effect immediately (P1-1)

**Problem:**
- `CrashReportingService.initialize` (`lib/core/services/crash_reporting_service.dart:33-66`) skips `SentryFlutter.init` when the user is opted out at launch.
- `setEnabled(true)` (`:150-159`) only flips `_isEnabled` and saves the preference. Sentry was never initialised, so nothing is reported until the next launch. The setting looks like it works but doesn't.
- `_beforeSendPrivacyFilter` (`:69-83`) clears `user` and the request, but not `event.message` or exception values. Those can contain food text, for example a `FormatException` quoting a meal description.

### Steps
1. **Initialise on opt-in.** Pull the options block out of `initialize` into a private `_configure(SentryFlutterOptions)`. In `setEnabled`, if the result is enabled and `Sentry.isEnabled` is false (and the DSN isn't a placeholder), call `await sentryInitRunner(_configure)` without `appRunner`. Errors in the current session are then captured. Startup crashes are covered from the next launch, which is acceptable.
2. **Opt-out mid-session.** `_isEnabled = false` already makes `beforeSend` drop events. Also call `await Sentry.close()` so nothing is queued or retried.
3. **Scrub messages.** In `_beforeSendPrivacyFilter`:
   - set `message: null`;
   - map each `SentryException` to keep `type`, `stackTrace` and `mechanism`, replacing `value` with `'<redacted>'`.

   The exception type and stack trace are enough to triage a crash.
4. **Breadcrumbs:** check that `_beforeBreadcrumbPrivacyFilter` drops `message` and `data` for categories other than navigation. Add a test if it doesn't.

### Tests (`test/crash_reporting_test.dart`, extend)
- Opted out at init, then `setEnabled(true)`: `sentryInitRunner` is called once and `isEnabled` is true.
- Opted in, then `setEnabled(false)`: `beforeSend` returns null.
- `beforeSend` on an event whose exception value is `'FormatException: 2 aloo paratha'` comes back with no `aloo` anywhere in `toJson()`.
- Offline-only mode: `setEnabled(true)` neither initialises nor enables.

### Acceptance
- With a test DSN, turning reporting on in Settings and triggering a debug crash sends an event in the same session.
- Event JSON contains no user text.

---

## WS-B — Startup resilience (P1-2, P1-3)

### Part 1: recovery screen when the DB can't open (P1-2)

**Problem:**
- `bootstrap()` constructs `AppDatabase` (`lib/app/bootstrap.dart:~80`). The connection is lazy and runs on a background isolate, so migrations and `beforeOpen` (`app_database.dart:395-430`) run at the first query, after the UI is up.
- If any of them throws (`_ensurePreReleaseV17VesselGraph`, a migration, a corrupt file, disk full), every screen fails separately with no way out.

#### Steps
1. **Probe before `runApp`.** In `bootstrap()`, after `container.read(databaseProvider)`, call `await db.customSelect('SELECT 1').get()` inside `try` with a 20 s timeout. This forces migrations and `beforeOpen` to run before the first frame.
   - First check on a real Android phone how long migrations take from v16 to v23. If the probe would delay the first frame by more than about 1 s on upgrade, show the native splash longer instead (it already covers that time).
2. **On failure:**
   - log the error through `AppLogger` and `CrashReportingService.recordCrash`;
   - `runApp(DatabaseRecoveryApp(error: e))`, a minimal `MaterialApp` that uses no providers and no database.
3. **`DatabaseRecoveryApp`** (new, `lib/app/database_recovery_app.dart`):
   - Title "IndiFit couldn't open your data"; plain-language body saying your data hasn't been deleted.
   - **Export database file:** copy the `.sqlite` file (path from `database_connection.dart`), plus `-wal`/`-shm` if present, to a temp zip and open the system share sheet. `share_plus` is already a dependency.
   - **Try again:** re-runs `bootstrap()`.
   - **Contact support:** `mailto:` with the app version and the error *type* only, never the message.
   - No reset button in v1 (decision E2).
4. **Error mapping:** treat `SqliteException` code 13 (SQLITE_FULL) separately, with the copy "Your phone is out of storage". It's the most likely real-world cause.

#### Tests
- Widget test: `DatabaseRecoveryApp` renders the three actions; "Export" calls an injected exporter with the DB path.
- Bootstrap test with an injected database factory that throws: `runApp` receives `DatabaseRecoveryApp`. This may need a small seam: pass `AppDatabase Function()` into `bootstrap`.
- Manual: corrupt the DB file on an emulator (`adb shell` and truncate it) and launch; the recovery screen appears and export produces a file.

### Part 2: per-launch repair cost (P1-3)

**Problem:**
- Every launch, `beforeOpen` (`app_database.dart:395-430`) runs:
  - two `COUNT(*)` seed checks;
  - `_ensurePreReleaseV17VesselGraph`, `_repairMissingV17LegacyFoodMappings` and `_retireMergedCatalogueDuplicates`;
  - `_createV17Indexes()` and `_createV18Indexes()`, about 40 `CREATE … IF NOT EXISTS` statements including triggers;
  - the manifest cache check.
- The trigger reinstall is deliberate (see the code comment), so this is a performance question, not a correctness bug.

#### Steps
1. **Measure.** Wrap `beforeOpen` in a `Stopwatch` and log the time in debug and profile builds. Record warm and cold launches on a mid-range Android phone (or the slowest emulator profile) and on the iOS simulator. Put the numbers in the PR.
2. **Under 300 ms:** close P1-3 as "measured, acceptable" and keep the stopwatch log.
3. **Over 300 ms:**
   - add `kLaunchRepairVersion = 1` and a `PRAGMA user_version`-style row in a tiny `app_meta` table (or the SharedPreferences key `launch_repair_version`);
   - run the repairs only when the stored version is lower, then store it;
   - keep `_retireMergedCatalogueDuplicates` and the manifest check on every launch; they're cheap and keyed to data changes;
   - **keep the trigger reinstall when restoring a backup**, by calling it from the restore path explicitly.
4. Bump `kLaunchRepairVersion` whenever a repair changes.

#### Tests
- The existing migration and repair tests must still pass.
- New: a second open with the stored version current skips the repairs (spy on a counter); a backup restore still reinstalls the triggers.

---

## WS-C — No silent failures (P1-4)

**Problem:** 37 empty `catch` blocks in 26 files (the audit counted 35), plus 20 `catchError` call sites, some of which do nothing. The data-path ones hide real failures:

| File | Count | Path |
|---|---|---|
| `lib/data/repositories/hydration_repository.dart` (~503, ~539) | 2 | data |
| `lib/data/repositories/progress_statistics_repository.dart` (~336, ~372) | 2 | data |
| `lib/data/repositories/adaptive_tdee_repository.dart` (~304) | 1 | data |
| `lib/data/repositories/progress_period_comparison_repository.dart` | 1 | data |
| `lib/features/food_log/diary_structure_controller.dart` | 1 | data |
| `lib/features/hydration/hydration_providers.dart` | 2 | data |
| `lib/core/services/rest_presence_service.dart` | 4 | platform (notifications) |
| `lib/features/food_log/barcode_scanner_screen.dart` | 5 | platform (camera) |
| AI screens (`photo_meal`, `nutrition_label_ocr`, `natural_language_meal`) | 6 | UI |
| Settings, theme, onboarding, profile, other UI | 13 | UI and prefs |

To list them yourself:
```bash
grep -rnE "catch \((_|e|error)\) \{\s*\}" lib --include='*.dart' | grep -v '\.g\.dart'
```

### Steps
1. **Triage each catch into one of three kinds** and record it in the PR table:
   - **Expected and harmless** (for example, a disposed controller after `mounted` turned false, or a platform channel missing in tests): keep it, but add a one-line comment saying why it's safe, and `AppLogger.debug` it.
   - **Real failure the user should know about:** surface it. Repositories rethrow or return a failure value; controllers set an error state the screen already renders.
   - **Real failure that should stay quiet:** `AppLogger.error(..., error, stackTrace)`. This also reaches Sentry when the user has opted in.
2. **Data repositories first** (top six rows). A hydration or TDEE read that silently returns a default is exactly the "number looks wrong, nobody knows why" bug.
3. **`catchError` sites:** the same triage. Replace `.catchError((_) {})` with `.catchError((Object e, StackTrace s) => AppLogger.error(...))`.
4. **Lint:** add `empty_catches: true` under `linter: rules:` in `analysis_options.yaml`. Leave `avoid_catches_without_on_clauses` off; it's too noisy for this codebase.

### Tests
- For each data-path catch changed to rethrow or return a failure, add a test where the DB call throws and assert the visible outcome (error state, not a silent zero).
- `flutter analyze` is clean with the new lint, which proves the count can't grow.

---

## WS-D — Single sources of truth (P1-5, P1-6)

### Part 1: streak from the database (P1-5)

**Problem:**
- `DashboardController` (`lib/features/dashboard/dashboard_controller.dart:~240-273`) works out the streak from food and workout dates and writes `userStreakCount` to SharedPreferences.
- `achievements_screen.dart:46` and both workout-player providers (`b02_strength_execution_controller.dart:~1649, ~1686`) read that cached value. If the dashboard hasn't run since the last log (cold start straight into a workout from a notification, for example), they show a stale streak, and achievement checks use the wrong number.

#### Steps
1. Create `StreakRepository` (`lib/data/repositories/streak_repository.dart`) with `Future<StreakSnapshot> current({DateTime? now})`. Move the logic from the dashboard into it: food log dates plus session dates, civil dates on the device clock, `StreakCalculator.calculateStreak`, and freezes read from prefs.
2. Add `streakProvider = FutureProvider.autoDispose((ref) => ...)` that is invalidated when food logs or sessions change. Reuse whatever the dashboard already invalidates on; check `user_provider_invalidator.dart`.
3. Switch the dashboard, the achievements screen and both player providers' `achievementStreakDays` to the repository.
4. Delete the `userStreakCount` write, and remove the key once nothing reads it. Backups export `user_streak_count` (`lib/core/backup/backup_schema.dart:281`), so keep the key in the backup allow-list for import compatibility. A restored value is simply ignored, because the streak is recomputed from the restored logs.
5. **Freeze semantics:** `streakFreezesCount` is set to 1 at `dashboard_controller.dart:237` and incremented at `:295`. Move these into the repository too, so all freeze logic lives in one place.

#### Tests
- Repository: food on D-2, a workout on D-1 and nothing today gives 2 (or 3 with a freeze), with "today" in local time at 00:30 IST.
- Achievements screen shows the repository value with no prior dashboard visit (pump only that screen).
- Player achievement check gets the fresh value after a set is logged.

### Part 2: one owner per workout draft (P1-6)

**Problem:**
- `b02StrengthExecutionControllerProvider` (global, `:1620`) is used by the dashboard, training, calendar, quick workout, the app root and the user invalidator (12 sites).
- `b02StrengthExecutionScreenControllerProvider` (autoDispose family keyed by launch, `:1654`) is used by the player screen.
- Both build a full `B02StrengthExecutionController`, both bind `RestPresenceService.instance`, and each has its own `_draftWriteTail`, so their draft writes aren't serialised against each other. It works today because the global one usually stops writing once the screen opens. Nothing enforces that.

#### Steps
1. **Map responsibilities.** Write out (in the PR) what each of the 12 global-provider call sites uses: launch/resume, "is a workout active?" state, end/discard. Expect three groups.
2. **New `WorkoutLaunchService`** (plain class plus provider) for the global needs:
   - `Future<B02StrengthExecutionLaunch?> resolveLaunch(...)`, which reads the draft and returns a launch value;
   - `Stream<ActiveWorkoutSummary?> watchActive()` for the dashboard and training banners;
   - `discardActive()`.

   It never mutates the draft beyond creating it.
3. **The screen controller** (family) is the only thing that writes sets, rest state and completion. `RestPresenceService.instance` is bound only there.
4. Migrate call sites one group at a time, with the suite green between groups. Then delete the global provider.
5. **App root (`indifit_app.dart`):** check what it uses (likely lifecycle resume or rest presence) and move that to the service.

#### Tests
- Existing player and draft tests must pass unchanged. They are the safety net, so run the full suite after each group.
- New: launching from the dashboard and then opening the player produces exactly one writer. Assert with a spy on the draft repository that all writes come from one controller instance.
- New: killing the screen mid-rest and resuming from the dashboard restores the same draft and rest timer.
- Manual on a device: start a workout from a notification, lock the phone during a rest, and resume.

**Risk:** this is the most-used screen. Land it behind the full suite plus a manual pass, and not in the same release as WS-H's player changes.

---

## WS-E — Dormant cloud crypto (P1-7)

**Current state:**
- `CloudBackupEnvelopeManager._deriveKmsKey` (`lib/core/backup/cloud_backup_envelope_manager.dart:304-318`) uses HKDF with a fixed salt.
- Its comment says this fixes brute-forcing of low-entropy secrets, which is wrong: HKDF has no work factor.
- Nothing creates `CloudBackupService` or `SyncService` anywhere in `lib/` (checked with `grep -rn "CloudBackupService(\|SyncService(" lib`), and the backend routers are unmounted by default (P0 WS6). No user is exposed.

### Steps (default E1)
1. Fix the comment: "HKDF assumes a high-entropy secret (a server-issued or random 256-bit key). It is not a password KDF: user-chosen secrets need PBKDF2 or Argon2 with a per-user salt."
2. Add `assert(secret.length >= 32, ...)` in debug builds so a short secret fails loudly in tests.
3. Add a line under "connected features" in the backlog: before cloud backup ships, take the wrapping key from the server or from PBKDF2 (600k, per-user salt), reusing `encryption_helper.dart`.

---

## WS-F — Backend leftovers (P1-8)

**Re-checked on 2026-10-03. Most of the audit's list is already fixed:**

| Audit item | Status |
|---|---|
| `str(e)` returned to clients | Fixed in WS6 (no remaining matches) |
| Gemini key in the URL | Fixed: `x-goog-api-key` header (`backend/services/gemini_client.py:41,88`) |
| Raw Gemini errors re-raised as 500 | Fixed in WS6; AI routes are dev-only (`ENABLE_AI_ROUTES=1`) |
| Docker runs as root, `build-essential` | Fixed: non-root `appuser`, slim image (`backend/Dockerfile`) |
| CORS `allow_credentials=True` | **Still open** (`backend/main.py:87`) |

### Steps
1. Set `allow_credentials=False`. Narrow `allow_methods` to `["GET", "POST"]` and `allow_headers` to the headers actually used (`x-indifit-key`, `authorization`, `content-type`; see `backend/core/security.py`). A mobile app doesn't send CORS preflights at all, so this only affects browsers.
2. Add a test: a preflight from a disallowed origin gets no `access-control-allow-origin`, and responses never include `access-control-allow-credentials: true`.

---

## WS-G — Router fallback (P1-9)

**Problem:** `GoRouter` in `lib/core/router/app_router.dart` has no `errorBuilder`. An unknown path (old deep link, notification payload from an older version, typo) shows go_router's default error page.

### Steps
1. Add `errorBuilder: (context, state) => RouteNotFoundScreen(location: state.uri.path)`. It's a simple scaffold: "That page isn't available", plus a "Go to Today" button that runs `context.go('/')`.
2. Log the path through `AppLogger.warning`, never the query string, which may hold IDs.
3. Check notification payloads (`NotificationService`) and widget deep links all map to real routes. List them in the PR.

### Tests
- `router.go('/does-not-exist')` renders `RouteNotFoundScreen`, and tapping the button lands on Today.
- Each registered notification route resolves; build the router and `go` each one.

---

## WS-H — Daily-loop polish (audit §6 and §8 Week 2)

These are not bugs, but the audit ties them to retention. **Re-check each against the current UI before starting.** Some may have moved since the 2026-10-01 screenshots. For example, a previous-performance "last time" line already exists (`b02_player_cards.dart:~472`), and the diary has "copy yesterday's meal" (`food_diary_screen.dart:~476`).

| # | Change | Where | Effort |
|---|---|---|---|
| H1 | **Previous column** in the set table: last session's weight × reps per set row, not just one "last time" line | `widgets/b02_compact_set_table.dart`, data from `b02_previous_performance_integration.dart` | 0.5–1 day |
| H2 | **One-tap set completion**: tapping the row checkmark logs the planned or prefilled values; replace the duplicate "Not logged / Ready" columns with one status icon | `b02_compact_set_table.dart:~367, ~408` | 0.5–1 day |
| H3 | **Prefill weight** from last session, or from the suggestion if there's no history. If "Log set" is still disabled, show the reason next to it ("Enter a weight") | player screen and controller | 0.5 day |
| H4 | Fold the "Suggested 8–12 reps · Apply · Change" card into the "Next set" header; show elapsed time instead of `0:00`; let the title wrap | `b02_strength_player_screen.dart` | 0.5 day |
| H5 | **Dashboard colours:** no red on the calorie ring or the Fat bar unless over target; move "Fiber: Not available" and "incomplete" notes behind an info icon | `today_consumer_presentation.dart`, `dashboard_screen.dart` | 0.5 day |
| H6 | Make "More training" tiles look tappable (outlined cards or list rows) | `training_screen.dart` | 0.25 day |
| H7 | Progress → Highlights: 2×2 grid, or hide it until there are 2 or more highlights; fix clipped cards | progress screen | 0.25 day |
| H8 | Onboarding: contrast on the unselected Male/Female chips; consider asking the goal first | `onboarding_screen.dart` | 0.25 day (order change: 0.5) |
| H9 | Empty thali: start from the user's most-used archetype instead of `-- kcal` | thali builder | 0.5 day |
| H10 | "Repeat yesterday's lunch" as one action on Food (not only in the diary) | Food landing | 0.5 day |

**Tests:**
- Each H item gets a widget test for its new behaviour.
- H1–H5 change goldens, so regenerate them with the `update-goldens.yml` workflow (Linux) in the same PR.
- Add before and after screenshots to each PR.

**Order:** H3 → H2 → H1 (the player loop first, but after WS-D part 2 lands), then H5, then the rest.

---

## 3. Definition of done (all P1s)

- [ ] Turning crash reporting on works in the same session; events contain no user text (WS-A).
- [ ] A corrupt or unopenable DB shows the recovery screen and can export the file (WS-B part 1).
- [ ] `beforeOpen` time is measured and recorded, and gated if it's over 300 ms (WS-B part 2).
- [ ] Zero empty `catch` blocks without a reason comment; `empty_catches` lint on; data-path failures visible (WS-C).
- [ ] Streak comes from one repository; no surface reads a cached value (WS-D part 1).
- [ ] One controller writes each workout draft; the global provider is gone (WS-D part 2).
- [ ] Cloud crypto comment is truthful and short secrets fail in debug (WS-E).
- [ ] Backend CORS has no credentials and allows only the methods and headers used (WS-F).
- [ ] Unknown routes show a friendly page with a way home (WS-G).
- [ ] H1–H5 shipped, with screenshots in their PRs (WS-H).
- [ ] `main` CI green after every PR; the full local suite at 0 failures.

## 4. Things only you can do

- Run the WS-B measurements on a real mid-range Android phone (emulator numbers understate cold start).
- Do the manual device passes for WS-B (corrupt DB) and WS-D part 2 (lock the phone mid-rest, resume from a notification).
- Decide E1–E5 if you disagree with the defaults.
- Judge the WS-H changes visually: approve the before/after screenshots.
