# IndiFit — P1 Remediation Implementation Plan

**Date:** 2026-10-03 (revised the same day after a self-review; see §5) · **Base:** `main` @ `32cf07d`
**Source:** [`docs/audit/INDEPENDENT_AUDIT_2026-10-01.md`](../audit/INDEPENDENT_AUDIT_2026-10-01.md), §5 (P1), plus the "Week 2" items from §6 and §8, plus issues found while checking those findings
**Goal:** What release builds advertise actually works. Failures are visible instead of silent. A user whose database breaks can still get their data out. Each number the app shows (streak, workout state) comes from one place. Then cut friction from the two daily loops: logging a set and logging food.

Every item was checked against `main` on 2026-10-03 with the command or file reference given. Where the audit was wrong or out of date, the plan says so.

---

## 0. Summary

| # | Problem (as of 2026-10-03) | Workstream | Effort (solo) | Before launch? |
|---|---|---|---|---|
| **P1-0** *(new, P0-grade)* | Release builds send online food search to `https://api.indifit.app`, which doesn't resolve (NXDOMAIN). Search has no fallback, so **online food search fails in every release build**. | **WS-0: Release food lookup** | 0.5 day | **Yes, blocker** |
| P1-1 | **No release build has a Sentry DSN** (`SENTRY_DSN` is never set), so crash reporting does nothing, even though Settings and the privacy policy offer it. Separately, opting in needs a restart, and exception messages aren't scrubbed. | **WS-A: Crash reporting** | 0.5 day (+ Sentry account, or 0.25 day to hide it) | Yes: either make it real or remove it |
| P1-2 | No recovery screen when the database fails to open | **WS-B: Startup resilience** | 1.5 days | Yes |
| P1-3 | About 104 `CREATE … IF NOT EXISTS` statements plus repairs run on every launch | **WS-B** | 0.5 day + measurement | Measure first; fix only if over budget |
| P1-4 | 37 empty `catch (_) {}` blocks in 26 files, and 14 no-op `catchError`. The audit's "add the `empty_catches` lint" fix **wouldn't work**: the lint is already on and exempts `catch (_)`. | **WS-C: No silent failures** | 1–1.5 days | Data-path ones yes; the rest any time |
| P1-5 | Streak cached in SharedPreferences and written only by the dashboard. Also, **`StreakCalculator` is wrong**: unused freezes inflate the streak, and freezes are never used up. | **WS-D: Single sources of truth** | 1 day | Yes (user-visible numbers) |
| P1-6 | Two controllers hold the same workout. **Concrete risk:** both reconcile notification rest actions on app resume, so a "Skip rest" or "+30 s" tap can be lost, or applied to an outdated copy. | **WS-D** | 0.5–1 day for tests and a minimal fix; 1–2 days for the full refactor | Tests and minimal fix: yes. Refactor: after launch. |
| P1-7 | Misleading "HKDF stops brute force" comment in cloud backup | **WS-E: Dormant code** | 0.1 day | No: nothing creates this code in v1 |
| P1-8 | Backend hygiene | **WS-F: Backend leftovers** | 0.25 day | No: 4 of 5 items are already fixed and no backend is deployed |
| P1-9 | No router `errorBuilder`; unknown links show go_router's raw error page | **WS-G: Router fallback** | 0.25 day | Yes |
| UX | Player friction, dashboard colour meaning, disabled-looking tiles, empty thali | **WS-H: Daily-loop polish** | 3–4 days | Strongly recommended |

**Order:** WS-0 → WS-A (once E0 is decided) → WS-G → WS-D part 1 → WS-D part 2 (tests and minimal fix) → WS-B → WS-C → WS-H. WS-E and WS-F any time.

**Total:** about 6–7 days for P1-0 to P1-9, plus 3–4 days of UX polish. Most of it is code only and can run while P0 waits on the Apple and Google accounts. **Two items need you first:** the `indifit.app` ownership question (WS-0) and the Sentry decision (E0).

---

## 1. Decisions (defaults chosen; change them if you disagree)

| Decision | Recommended default | Why | Alternative |
|---|---|---|---|
| **E0: Crash reporting in v1** | **Make it real:** create a Sentry project (free tier) and pass `--dart-define=SENTRY_DSN=…` in release builds, then do WS-A | A solo developer has no other way to see field crashes. The opt-in, privacy-scrubbed design is already built. | Remove the Settings toggle and the privacy-policy and store-copy mentions for v1 (0.25 day). Don't ship a toggle that does nothing. |
| **E-0b: Release food lookup** | **Release builds call Open Food Facts directly** (`backendUrl` empty in release) until a backend is actually deployed | Matches P0 decisions D2/D4; removes the dependency on a host that doesn't exist | Deploy the backend and point `api.indifit.app` at it (needs WS-6 Part B security first) |
| E1: Dormant cloud backup/sync client code (`cloud_backup_service.dart`, `sync_service.dart`) | **Keep it; fix the comment** | Nothing creates these services (`grep -rn "CloudBackupService(\|SyncService(" lib` finds no construction), so no user is exposed | Delete both, with their tests, in a post-launch cleanup PR |
| E2: When the DB fails to open | **Recovery screen with "Export database files" and "Contact support"; never auto-reset** | Auto-reset destroys the only copy of the user's data | Also offer "Reset app" behind a typed confirmation, after real reports |
| E3: Per-launch repairs (P1-3) | **Measure first.** Gate behind a repair version only if `beforeOpen` costs more than 300 ms on a mid-range Android phone. | The trigger reinstall is a deliberate safety measure; don't trade it for an unmeasured gain | Gate unconditionally |
| E4: Streak storage | **Compute it from the DB on demand in one repository; keep only freezes in prefs** | Removes "whoever last opened the dashboard" staleness; the queries only read dates | Keep the prefs cache, but refresh it from every writer |
| **E6: Streak freezes** | **A freeze only bridges a missed day that has active days on both sides. Unused freezes add nothing. A streak is alive only if today or yesterday is active (or yesterday is bridged).** Freezes stay a standing allowance, not consumed. | Fixes the visible bugs without designing a new economy | Make freezes consumable: use one per bridged gap and store it. That's a product change, so decide it separately. |
| E5: Workout controllers (P1-6) | **Before launch:** reproduce with tests, then stop the app root from reconciling rest intents (the player screen already does it). **After launch:** make the screen controller the only draft writer. | Small, low-risk fix on the most-used screen; the refactor can wait | Do the full refactor now (1–2 days, higher risk) |

---

## 2. Branch & PR sequence

Use one PR per row. Each PR must pass CI before the next one merges. Run `flutter analyze`, `flutter test --exclude-tags golden` and `python3 tool/generate_code_graph.py` before every push.

| Order | Branch | Contents |
|---|---|---|
| 1 | `fix/release-food-lookup` | WS-0 |
| 2 | `fix/crash-reporting` | WS-A (after E0) |
| 3 | `fix/router-error-fallback` | WS-G |
| 4 | `fix/streak-calculation` | WS-D part 1 |
| 5 | `fix/rest-intent-single-owner` | WS-D part 2, steps 1–3 |
| 6 | `feat/db-open-recovery` | WS-B part 1 |
| 7 | `perf/launch-repair-gate` | WS-B part 2: only if the measurement says so |
| 8 | `fix/no-silent-catches` | WS-C |
| 9+ | `feat/player-*`, `fix/dashboard-colours`, … | WS-H, one PR per bullet |
| any | `chore/backend-cors-tidy`, `docs/cloud-crypto-comment` | WS-F, WS-E |
| post-launch | `refactor/single-draft-owner` | WS-D part 2, step 4 |

---

## WS-0 — Release food lookup points at a host that doesn't exist (P1-0, new)

**Problem (verified 2026-10-03):**
- `AppConfig.backendUrl` defaults to `https://api.indifit.app` in release builds (`lib/core/config/app_config.dart:14-19`). No CI workflow or doc sets `BACKEND_API_URL`.
- `api.indifit.app` returns **NXDOMAIN**. `indifit.app` itself was registered on **2026-10-02** through Hostinger; the registration record doesn't show who owns it.
- `FoodApiService.searchOnline` (`lib/data/repositories/food_api_service.dart:315-493`) uses the backend URL whenever it's non-empty and **rethrows** `DioException` with no fallback. In a release build, online food search always fails, and only local catalogue results show.
- `fetchByBarcode` does fall back to Open Food Facts on `connectionError` (`:275-289`). So barcode lookup works in release, after a failed DNS lookup.
- The P0 plan (D2) assumed lookups go straight to Open Food Facts. They don't.
- **Privacy risk if the domain isn't yours:** whoever controls `indifit.app` can create `api.indifit.app` and receive every release user's food searches and barcodes.

### Steps
1. **You:** confirm whether `indifit.app` is your domain. If not, this PR is urgent, and `privacy@indifit.app` in `doc/privacy_policy.md:81` and the user agent `https://indifit.app` (`food_api_service.dart:26`) need a domain you control.
2. **Release default to Open Food Facts direct (E-0b):** set `backendUrl`'s release default to `''`. Development keeps `http://10.0.2.2:8000`. Code paths that already exist then take over:
   - search goes to `kOpenFoodFactsSearchUrl` (`https://search.openfoodfacts.org/search`), with `isOffSearch` request shaping at `:381`;
   - barcode lookup goes to `_fetchByBarcodeOff`.
3. **Add a search fallback**, like barcode lookup has: on `connectionError`, `connectionTimeout`, 502 or 503 from the backend, retry the same query against Open Food Facts. Then a configured backend that's down doesn't break search either.
4. **Privacy check:** `searchOnline` and `fetchByBarcode` check `isNutritionOnlineAllowed` themselves (`:325`, `:254`). The network interceptor's path rule (`core_providers.dart:107-109`, `/api/food`) wouldn't catch a direct Open Food Facts URL. Keep the explicit checks, and add a test that direct Open Food Facts search is refused when online nutrition is off.
5. **Rate limits:** check Open Food Facts' published limits for the search API against the search screen's debounce. Record the numbers in the PR. If they're tight, raise the debounce or cache harder (`food_search_cache` exists).
6. Correct D2's wording in `P0_REMEDIATION_PLAN.md`.

### Tests
- `FoodApiService` with an empty base URL sends search to `search.openfoodfacts.org` and parses results (mock Dio).
- Backend `connectionError` on search falls back to Open Food Facts; 404 and 400 don't.
- Online nutrition off: search and barcode both throw before any request.

### Acceptance
- A release build on a device finds a packaged food by name online (e.g. "Parle-G"), with `api.indifit.app` never contacted (check the debug log's `event=food_search_start host=`).

---

## WS-A — Crash reporting that actually reports (P1-1)

**Problem:**
- `_defaultDsn` is `String.fromEnvironment('SENTRY_DSN', defaultValue: 'https://placeholder_key@…')` (`crash_reporting_service.dart:15-18`), and `initialize` skips Sentry when the DSN contains `placeholder_key` (`:45`). No workflow or doc sets `SENTRY_DSN`. **In every release build, reporting is off whatever the user picks.**
- The toggle is still shown (`data_management_section.dart:~722`), and the privacy policy (`doc/privacy_policy.md:27,54`) and store copy (`doc/store_listing_copy.md:46,62`) describe it.
- If a DSN is supplied: opting in at runtime only sets `_isEnabled` and the preference (`:150-159`). Sentry was never initialised, so nothing is reported until the next launch.
- `_beforeSendPrivacyFilter` (`:69-83`) clears the user and request, but not `event.message` or exception values, which can quote user text. Breadcrumbs are already scrubbed (`:86-99`, message sanitised and data cleared).

### Steps
1. **Decide E0.** If you choose "remove for v1", hide the toggle, remove the policy and store-copy lines, and stop here (keep the service code dormant).
2. **Release builds pass the DSN:** add `--dart-define=SENTRY_DSN=$SENTRY_DSN` (a CI secret) to the release build steps, and document it in the README next to the other defines.
3. **Initialise on opt-in:** pull the options block into `_configure(SentryFlutterOptions)`. In `setEnabled`, when the result is enabled, `Sentry.isEnabled` is false and the DSN is real, call `await sentryInitRunner(_configure)` without `appRunner`.
   - Errors in the current session are then captured; startup crashes from the next launch.
   - Sentry's Flutter error integrations chain to the handlers bootstrap already installs (`bootstrap.dart` `FlutterError.onError` and `PlatformDispatcher.onError`). Check the existing `AppLogger` path still runs.
4. **Opt-out mid-session:** `_isEnabled = false` already makes `beforeSend` drop events. Also `await Sentry.close()`.
5. **Scrub messages** in `_beforeSendPrivacyFilter`: set `message: null`, and replace each exception's `value` with `'<redacted>'`, keeping `type`, `stackTrace` and `mechanism`.

### Tests (`test/crash_reporting_test.dart`, extend)
- Opted out at init, then `setEnabled(true)` with a non-placeholder DSN (`debugDsnOverride`): `sentryInitRunner` is called once.
- With the placeholder DSN, `setEnabled(true)` never initialises.
- `beforeSend` on an event whose exception value is `'FormatException: 2 aloo paratha'` returns JSON with no `aloo` in it.
- Offline-only mode: `setEnabled(true)` neither initialises nor enables.

### Acceptance
- A release-mode build with the test DSN: turning reporting on and triggering a test crash sends an event in the same session, with no user text in it.

---

## WS-B — Startup resilience (P1-2, P1-3)

### Part 1: recovery screen when the DB can't open (P1-2)

**Problem:**
- `bootstrap()` constructs `AppDatabase`. The connection is a `LazyDatabase` that opens `indifit.db` in the app documents folder, using `NativeDatabase.createInBackground` (`database_connection.dart`).
- Migrations and `beforeOpen` (`app_database.dart:395-430`) run on the **first query**. That's either the first screen's provider or the post-frame bootstrap (`indifit_app.dart:37-63`: reminder watchers, auto-backup).
- If opening throws (`_ensurePreReleaseV17VesselGraph` at `schema_migrations.dart:830`, a migration, a corrupt file, a full disk), each screen fails on its own, with no way out.

#### Design: gate inside the app, not before `runApp`
A pre-`runApp` probe with a timeout was considered and rejected. If a slow upgrade migration hit the timeout, the recovery screen would offer to export a half-migrated file while the migration was still running, and "Try again" would open a second connection to it. It would also delay the first frame, which R07F-0 deliberately avoided. Note there's no `flutter_native_splash` in the project; the OS launch screen only covers time before the first frame.

#### Steps
1. Add `databaseReadyProvider = FutureProvider<void>((ref) => ref.watch(databaseProvider).customSelect('SELECT 1').get())`. **No timeout:** a slow migration shows a "Getting your data ready…" screen, never an error.
2. In `IndiFitApp.build`, switch on it:
   - **loading:** a minimal `MaterialApp` with the "Getting your data ready…" screen;
   - **error:** a minimal `MaterialApp` with `DatabaseRecoveryScreen` (no providers, no database access);
   - **data:** the existing `MaterialApp.router`.
3. Make `_runPostFrameBootstrap` await `databaseReadyProvider.future` first, and skip its work if that fails. Hold notification-tap navigation (`NotificationService.onNotificationNavigate`) until the database is ready.
4. **`DatabaseRecoveryScreen`** (new, `lib/app/database_recovery_screen.dart`):
   - Title "IndiFit couldn't open your data". Body: your data hasn't been deleted.
   - **Export database files:** share `indifit.db` plus `-wal`/`-shm` if present, from the app documents folder, with `share_plus` `shareXFiles`. `share_plus` is already a dependency; there's no zip library, and none is needed.
   - **Try again:** invalidate `databaseProvider` (its `onDispose` closes the old `AppDatabase`) and `databaseReadyProvider`.
   - **Contact support:** `mailto:` with the app version and the error *type* only, never the message.
   - No reset button (E2).
5. Map `SqliteException` result code 13 (SQLITE_FULL) to "Your phone is out of storage. Free up space, then tap Try again."

#### Tests
- Widget test: with `databaseReadyProvider` overridden to throw, the app shows the recovery screen with three actions, and "Export" calls an injected exporter with the three file paths.
- While loading, it shows the readiness screen and no router page builds.
- "Try again" after a transient failure reaches the router. **Check that drift retries opening** after a failed `LazyDatabase` open; if it doesn't, recreating `databaseProvider` covers it, and the test proves which.
- Manual: truncate `indifit.db` on an emulator and launch; the recovery screen shows and export produces files.

### Part 2: per-launch repair cost (P1-3)

**Problem:**
- Every launch, `beforeOpen` runs:
  - two seed `COUNT(*)` checks;
  - `_ensurePreReleaseV17VesselGraph`, `_repairMissingV17LegacyFoodMappings` and `_retireMergedCatalogueDuplicates`;
  - `_createV17Indexes` (62 `CREATE` statements) and `_createV18Indexes` (42), about 104 `CREATE … IF NOT EXISTS` index and trigger statements;
  - the manifest cache check.
- The trigger reinstall is deliberate (code comment): it protects databases created before a boundary repair.

#### Steps
1. **Measure:** time `beforeOpen` with a `Stopwatch` in debug and profile builds. Record cold and warm launches on a mid-range Android phone (or the slowest emulator profile) and on the iOS simulator, and put the numbers in the PR.
2. **Under 300 ms:** close P1-3 as measured and acceptable; keep the timing log.
3. **Over 300 ms:**
   - store `launch_repair_version` in the existing **`user_settings` key-value table** (inside the database, so it travels with the data);
   - run the vessel-graph repair, the legacy-mapping repair and the V17/V18 index and trigger reinstall only when the stored version is lower than `kLaunchRepairVersion`, then store it;
   - keep `_retireMergedCatalogueDuplicates` and the manifest check on every launch, since they're cheap and keyed to data.
   - **Why the DB and not SharedPreferences:** prefs can disagree with the database. A new table would need a schema migration.
   - **Restore is safe:** restore imports rows into the existing schema and never drops tables or triggers (`grep -rn "DROP TABLE\|DROP TRIGGER" lib/core/backup` finds nothing). `user_settings` is in backups, so restoring an older value just re-runs the repairs once.
4. Bump `kLaunchRepairVersion` whenever a repair changes.

#### Tests
- Existing migration and repair tests pass unchanged.
- Second open with the version current skips the repairs (spy counter). Restoring a backup holding an older version re-runs them once.

---

## WS-C — No silent failures (P1-4)

**Problem:**
- 37 `catch (_) {}` blocks in 26 files:
  ```bash
  grep -rnE "catch \((_|e|error)\) \{\s*\}" lib --include='*.dart' | grep -v '\.g\.dart'
  ```
- 14 no-op `.catchError((_) {})`: 13 in `onboarding_screen.dart` (draft saves) and 1 in `profile_screen.dart`.
- **The audit's fix wouldn't work.** `empty_catches` is already enabled through `flutter_lints` (core lint set). By design it exempts a catch variable named `_`, and all 37 use `_`, which is why `flutter analyze` is clean.

| Area | Files (count) | Kind |
|---|---|---|
| Data | `hydration_repository` (2), `progress_statistics_repository` (2), `adaptive_tdee_repository` (1), `progress_period_comparison_repository` (1), `diary_structure_controller` (1), `hydration_providers` (2) | data |
| Platform | `rest_presence_service` (4), `barcode_scanner_screen` (5) | notifications, camera |
| AI screens | `photo_meal`, `nutrition_label_ocr`, `natural_language_meal` (2 each) | UI |
| Other | settings, theme, onboarding, profile, dashboard, food search and others (13) | UI and prefs |

### Steps
1. **Sort each catch into one of three kinds** and record the decision in the PR table:
   - **Expected and harmless:** keep it, add a `// Safe: <reason>` comment, and `AppLogger.debug`.
   - **The user should know:** rethrow or return a failure value; the controller sets an error state the screen already renders.
   - **Quiet but logged:** `AppLogger.error(msg, e, s)`, which also reaches Sentry when opted in (after WS-A).
2. **Data rows first.** A hydration or TDEE read that silently returns a default is the "number looks wrong, nobody knows why" bug.
3. **Onboarding:** replace the 13 `_saveDraft().catchError((_) {})` with one `_saveDraftLogged()` helper that logs.
4. **A guard that actually works:** add `test/no_silent_catch_test.dart`. It scans `lib/**/*.dart` (excluding `*.g.dart`) for `catch (_) {}` and `catchError((_) {})` with no `// Safe:` comment on the same or previous line, and fails if any are found. A test, unlike a lint, can't be bypassed by naming the variable `_`.

### Tests
- Each data-path catch changed to rethrow or return a failure gets a test where the DB call throws, asserting the visible outcome (error state, not a silent zero).
- The guard test passes at 0 unexplained catches.

---

## WS-D — Single sources of truth (P1-5, P1-6)

### Part 1: streak computed correctly, in one place (P1-5)

**Problem 1, staleness:** `DashboardController.computeStreak` (`dashboard_controller.dart:231-274`) works out the streak and writes `userStreakCount` to prefs. `achievements_screen.dart:46` and both player providers' `achievementStreakDays` (`b02_strength_execution_controller.dart:~1649, ~1686`) read the cached value. Opening a workout before the dashboard has run shows a stale streak and gives achievement checks the wrong number.

**Problem 2, wrong calculation (verified with a throwaway test on 2026-10-03):** `StreakCalculator.calculateStreak` (`lib/core/utils/streak_calculator.dart`) keeps looping while `freezesRemaining > 0`, so unused freezes add days at the end of the run:

| Active days | Freezes | Returned | Should be |
|---|---|---|---|
| today only | 1 (the default every user gets) | **2** | 1 |
| today only | 2 | **3** | 1 |
| last active 5 days ago | 1 | **1** | 0 |
| today and 2 days ago | 1 | 3 | 3 (correct; the only freeze case tested) |

Freezes are also never used up: the count only grows, through `purchaseStreakFreeze`, up to 2.

#### Steps
1. **Fix the calculator (E6):**
   - a missed day counts only if a freeze is left **and** an active day exists earlier in the same run, within the remaining freezes;
   - trailing freezes add nothing;
   - start from today if today is active, otherwise from yesterday;
   - if yesterday is missed and can't be bridged, the streak is 0.
   - Add the four rows above as tests. Keep the existing case.
2. **`StreakRepository`** (`lib/data/repositories/streak_repository.dart`) with `Future<StreakSnapshot> current({DateTime? now})`. It takes over `computeStreak`'s body: food log dates plus session dates, civil dates on the device clock, freezes from prefs. Move `purchaseStreakFreeze` (`:276-300`) here too.
3. **Callers ask the repository directly:** the dashboard, the achievements screen and both player `achievementStreakDays` callbacks. These queries read only dates, so no cache or provider invalidation is needed.
4. Stop writing `userStreakCount`. Backups export it (`backup_schema.dart:281`), so leave it in the backup allow-list for import compatibility. A restored value is ignored, because the streak is recomputed from the restored logs.

#### Tests
- Calculator: the table above, plus local midnight (00:30 IST counts as the new day).
- The achievements screen shows the repository value with no dashboard visit.
- The player's achievement check sees a streak that includes a set logged just now.

### Part 2: one owner for each workout (P1-6)

**Problem:**
- `b02StrengthExecutionControllerProvider` (global, `:1620`) is used at 12 sites: the dashboard (4), training (2), the calendar launcher (2), quick workout (2), the app root (1) and the user invalidator (1).
- `b02StrengthExecutionScreenControllerProvider` (autoDispose family, `:1654`) is used by the player.
- Both are full `B02StrengthExecutionController` instances, with separate `_draftWriteTail` and `_timingRevision`, so nothing serialises their writes against each other.
- **Concrete path:** on app resume, **both** call `reconcilePendingRestIntent`: the app root on the global controller (`indifit_app.dart:133-141`) and the player screen on its own (`b02_strength_player_screen.dart:132-139`).
  - Each calls `RestPresenceService.loadAndClearPendingIntent()`, so whichever runs first takes the notification's "Skip" or "+30 s" action.
  - The global controller's `state.launch` is the copy from when the dashboard or launcher recovered the workout, so it may hold no active rest. The action is then **lost**.
  - If the workout was recovered mid-rest, `skipRest` and `adjustRest` call `saveDraft` with a draft built from that **outdated** copy (`:1004-1030`), which could **overwrite sets logged since**.

#### Steps
1. **Reproduce first** (the PR starts with failing tests):
   - (a) recover from the dashboard, log 2 sets on the player, start a rest, store a "skip" intent, simulate resume: assert the rest is skipped exactly once and both sets are still in the draft;
   - (b) the same, recovered mid-rest.
2. **Minimal fix (before launch):** remove the app-root resume call. The player already reconciles on resume and on open (`b02_strength_player_screen.dart:110`), so an intent stored while the player isn't open is applied when it opens.
3. Check the other global-controller writes (`resumeScheduled`, `recover`, `resumeElapsed`) only happen before the player screen exists. List them in the PR.
4. **After launch (refactor):**
   - map the 12 call sites by need (launch/resume, active-workout state, discard);
   - move them to a `WorkoutLaunchService` that resolves a `B02StrengthExecutionLaunch` and never edits an existing draft;
   - make the screen controller the only writer;
   - delete the global provider.

#### Tests
- Steps 1(a) and 1(b) pass after step 2.
- Existing player and draft tests pass unchanged; they're the safety net.
- Manual on Android: start a workout from the dashboard, lock the phone during a rest, tap "Skip" on the notification, then reopen. The rest is skipped and all sets are kept.

---

## WS-E — Dormant cloud crypto (P1-7)

**Current state:**
- `CloudBackupEnvelopeManager._deriveKmsKey` (`cloud_backup_envelope_manager.dart:304-318`) uses HKDF with a fixed salt, and its comment says this stops brute-forcing of low-entropy secrets. HKDF has no work factor, so that's wrong.
- Nothing in `lib/` creates `CloudBackupService` or `SyncService`, and the backend routers are unmounted by default.

### Steps
1. Fix the comment: "HKDF assumes a high-entropy secret (a server-issued or random 256-bit key). It is not a password KDF. A user-chosen secret needs PBKDF2 or Argon2 with a per-user salt (see `encryption_helper.dart`)."
2. Add a backlog line under connected features: before cloud backup ships, the wrapping key comes from the server or from PBKDF2 (600k, per-user salt).

A length assert was considered and dropped: length says nothing about entropy.

---

## WS-F — Backend leftovers (P1-8)

**Re-checked on 2026-10-03:**

| Audit item | Status |
|---|---|
| `str(e)` returned to clients | Fixed in WS6 |
| Gemini key in the URL | Fixed: `x-goog-api-key` header (`backend/services/gemini_client.py:41,88`) |
| Raw Gemini errors re-raised as 500 | Fixed in WS6; AI routes are dev-only (`ENABLE_AI_ROUTES=1`) |
| Docker runs as root, `build-essential` | Fixed: non-root `appuser`, slim image |
| CORS `allow_credentials=True` | **Open** (`backend/main.py:87`) |

No backend is deployed, and after WS-0 release builds don't call one. So this isn't a launch item; do it before any backend deploy.

### Steps
1. Set `allow_credentials=False`. Set `allow_headers` to `x-indifit-key`, `authorization` and `content-type` (`backend/core/security.py:91,148`). Derive `allow_methods` from the mounted routers: GET/POST by default, plus DELETE when backup routes are mounted.
2. Test: a preflight from a disallowed origin gets no `access-control-allow-origin`, and no response carries `access-control-allow-credentials: true`.

---

## WS-G — Router fallback (P1-9)

**Problem:** `GoRouter` in `lib/core/router/app_router.dart` has no `errorBuilder`. An unknown path (an old deep link, a notification payload from an older version, a typo) shows go_router's default error page.

### Steps
1. Add `errorBuilder: (context, state) => RouteNotFoundScreen(location: state.uri.path)`: "That page isn't available", with a "Go to Today" button that runs `context.go('/')`.
2. Log the path with `AppLogger.warning`, never the query string.
3. Check that every `NotificationService.destinationForPayload` result (`indifit_app.dart:~150`) is a registered route.

### Tests
- `router.go('/does-not-exist')` renders `RouteNotFoundScreen`; tapping the button lands on Today.
- Every destination `destinationForPayload` can return resolves to a real route.

---

## WS-H — Daily-loop polish (audit §6 and §8 Week 2)

These are not bugs, but the audit ties them to retention. **Re-check each one against the current UI before starting:** the audit screenshots are from 2026-10-01. Some already exist in part:
- a single "last time" line in the player (`b02_player_cards.dart:~472`);
- "copy yesterday's meal" in the diary (`food_diary_screen.dart:~476`).

| # | Change | Where | Effort |
|---|---|---|---|
| H1 | **Previous column:** last session's weight × reps on each set row, not one "last time" line | `widgets/b02_compact_set_table.dart`; data from `b02_previous_performance_integration.dart` | 0.5–1 day |
| H2 | **One-tap set completion:** the row checkmark logs the planned or prefilled values; one status icon replaces the "Not logged / Ready" columns | `b02_compact_set_table.dart:~367, ~408` | 0.5–1 day |
| H3 | **Prefill weight** from last session, or the suggestion if there's no history; if "Log set" is still disabled, show the reason beside it | player screen and controller | 0.5 day |
| H4 | Fold the "Suggested 8–12 reps · Apply · Change" card into the "Next set" header; show elapsed time instead of `0:00`; let the title wrap | `b02_strength_player_screen.dart` | 0.5 day |
| H5 | **Dashboard colours:** no red on the calorie ring or the Fat bar unless over target; move "Fiber: Not available" and "incomplete" behind an info icon | `today_consumer_presentation.dart`, `dashboard_screen.dart` | 0.5 day |
| H6 | Make "More training" tiles look tappable (outlined cards or list rows) | `training_screen.dart` | 0.25 day |
| H7 | Progress → Highlights: 2×2 grid, or hide until there are 2 or more; fix clipped cards | progress screen | 0.25 day |
| H8 | Onboarding: contrast on the unselected Male/Female chips; consider asking the goal first | `onboarding_screen.dart` | 0.25–0.5 day |
| H9 | Empty thali starts from the user's most-used archetype instead of `-- kcal` | thali builder | 0.5 day |
| H10 | "Repeat yesterday's lunch" as one action on the Food landing page, not only in the diary | Food landing | 0.5 day |

**Tests:**
- Each item gets a widget test for its new behaviour.
- H1–H5 change goldens: regenerate with `update-goldens.yml` (Linux) in the same PR.
- Add before and after screenshots to each PR.

**Order:** H3 → H2 → H1, after WS-D part 2's minimal fix and not in the same release as its refactor. Then H5, then the rest.

---

## 3. Definition of done (all P1s)

- [ ] Release builds find packaged foods online via Open Food Facts, and never contact a host the project doesn't control (WS-0).
- [ ] Crash reporting either works in release (DSN set, takes effect without a restart, no user text in events) or is removed from the UI, the policy and the store copy (WS-A).
- [ ] An unopenable DB shows the recovery screen and can export its files; a slow migration shows a waiting screen, never an error (WS-B part 1).
- [ ] `beforeOpen` cost is measured and recorded, and gated if over 300 ms (WS-B part 2).
- [ ] No unexplained empty catches, enforced by `no_silent_catch_test.dart`; data-path failures are visible (WS-C).
- [ ] The streak is correct for the four cases in WS-D and comes from one repository (WS-D part 1).
- [ ] A notification rest action is applied exactly once and never overwrites newer sets (WS-D part 2, steps 1–3).
- [ ] Cloud crypto comment is truthful (WS-E).
- [ ] Unknown routes show a friendly page with a way home (WS-G).
- [ ] H1–H5 shipped, with screenshots in their PRs (WS-H).
- [ ] `main` CI green after every PR; full local suite at 0 failures.

Not needed for launch: WS-F (before any backend deploy) and the WS-D part 2 refactor (after launch).

## 4. Things only you can do

- **Confirm you own `indifit.app`** (registered 2026-10-02 through Hostinger). If not, WS-0 becomes urgent and the policy email and user agent need a domain you control.
- **Decide E0:** create a Sentry project and add its DSN as a CI secret, or remove crash reporting from v1.
- Run the WS-B measurements on a real mid-range Android phone (emulator numbers understate cold start).
- Do the manual device passes for WS-B (truncated DB) and WS-D part 2 (lock the phone mid-rest, tap Skip on the notification, reopen).
- Decide E1–E6 if you disagree with the defaults.
- Approve the WS-H before and after screenshots.

---

## 5. Self-review changes (2026-10-03)

The first draft was checked again against the code. What changed and why:

1. **Added WS-0 (P0-grade).** Release online search targets a host that doesn't exist (NXDOMAIN), with no fallback. Found by following `AppConfig.backendUrl`; the audit and the P0 plan both missed it.
2. **WS-A reframed.** No build sets `SENTRY_DSN`, so "make opt-in take effect immediately" fixed a feature that can't run in release. Added decision E0.
3. **WS-B part 1 redesigned.** The first draft probed before `runApp` with a 20 s timeout. That could show a recovery and export screen during a slow migration, and the draft also wrongly assumed a native splash. Replaced with an in-app readiness gate with no timeout. Export uses `shareXFiles`, since there's no zip library.
4. **WS-B part 2 corrected.** About 104 statements, not about 40. The repair version moved from a new table or prefs to the existing `user_settings` table. Removed an unnecessary "reinstall triggers on restore" step, because restore never drops tables or triggers.
5. **WS-C guard replaced.** `empty_catches` is already on and exempts `catch (_)`, so a test-based guard replaces the lint. The `catchError` count is corrected to 14 no-op (13 in onboarding).
6. **WS-D part 1 expanded.** `StreakCalculator` miscounts (inflates by unused freezes; a broken streak shows 1); confirmed with a throwaway test. Added decision E6. Dropped the provider-invalidation step: computing on demand is simpler.
7. **WS-D part 2 made concrete.** Found the actual cross-controller path (both reconcile rest intents on resume). Split into "reproduce plus minimal fix" before launch and "refactor" after.
8. **WS-E and WS-F downgraded.** WS-E's length assert was dropped as security theatre. WS-F is not a launch item because nothing deployed uses the backend.
9. Effort and order updated: about 6–7 days plus 3–4 days of polish (was 5–6 plus 3–4).
