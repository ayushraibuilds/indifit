# IndiFit — Independent Codebase Audit

**Date:** 2026-10-01 · **Commit:** `fd5c7cb` (main, 8 commits ahead of `origin/main`)
**Scope:** docs, graphify knowledge graph, Flutter app (`lib/`, ~200k hand-written lines, 456 files), backend (`backend/`, ~2.6k lines), platform config, CI, test suite (325 files, ~130k lines).

**How it was done:** I used the knowledge graph to find structure and hubs. I ran the analyzer, the full Flutter test suite, the backend tests, the formatter and the CI history. I then read the high-risk paths in full: bootstrap, DB/migrations, backup crypto, backend, the workout controller, platform manifests and config. Wider anti-patterns were found with targeted searches. Every finding below cites a file and line I checked. Nothing is copied from the earlier audit docs without checking it.

---

## 1. Verdict

| | Score | Summary |
|---|---|---|
| **Personal use / dogfooding** | **8 / 10** | The offline core (logging, workouts, nutrition, backups) is solid and carefully engineered. |
| **Public store launch (as-is)** | **5.5 / 10** | Several advertised features don't work in a release build. CI has been red for 10 days, and the backend isn't production-safe. |
| **Public launch, offline-core scope (after ~1–2 weeks of fixes)** | ~7.5 / 10 projected | Hide or finish the connected features, make CI green, and fix the iOS release config. |

The earlier self-assessments (9.5/10 "production benchmark" in the dossier, 8.2/10 in the cross-agent report) are **too optimistic**. They claim "2,469+ tests pass" and score testing 9.9/10. On this commit the suite has a significant number of failures (§4), and CI hasn't completed a green run recently. The engineering underneath is better than most solo projects. The gap is between what the docs say and what has actually been verified.

### Scorecard

| Dimension | Score | Notes |
|---|---|---|
| Product concept & India-specific moat | 8.5 | Katori/thali logging plus a strength player is a real, underserved niche. |
| Offline core functionality | 8 | Logging, the player, the thali builder and progress all work offline. |
| Data integrity | 8.5 | Transactional, tested migrations; DB on a background isolate; single DB instance. |
| Local security & privacy | 8.5 | PBKDF2 600k + AES-GCM with authenticated headers, off the UI isolate; offline mode enforced in the network interceptor. |
| Backend security & ops | 3.5 | Shared static key, unverified identities, in-memory storage, retired model, not deployed. |
| Architecture & maintainability | 6.5 | No import cycles and clean DI, but milestone naming, giant files, and test fixtures inside `lib/`. |
| UI/UX | 7 | Clean, consistent M3. The workout player and dashboard need friction removed. |
| Testing & CI | 5 | Huge suite, but it isn't green and isn't enforced. |
| Store compliance | 5 | iOS release uses the testing entitlements, there's no privacy manifest, and the scanner is a stub. |
| Docs & process | 5 | Very thorough, but stale, contradictory and self-congratulatory. |

---

## 2. What is genuinely strong

- **Data layer discipline.** One shared `AppDatabase` instance is created in bootstrap and reused through Riverpod. The comment at `lib/app/bootstrap.dart:56` explains the earlier two-connection bug well. The DB runs on a background isolate (`lib/data/database/connection/database_connection.dart:15`). Migrations v15–v19 have failure-injection tests that prove rollback.
- **Local crypto is done right** (`lib/core/utils/encryption_helper.dart`): versioned format, 16-byte random salt, PBKDF2-SHA256 at 600k iterations stored in the header, GCM with the header bound as AAD, and V1 backward compatibility. V10 export runs in `Isolate.run`, so the KDF doesn't freeze the UI (`lib/core/backup/backup_file_adapter.dart:387`).
- **Privacy by construction.** `PrivacyNetworkInterceptor` rejects requests in offline mode (`lib/core/di/core_providers.dart:91`). Sentry is opt-in and skipped entirely when disabled or when the DSN is a placeholder. Android has `allowBackup=false`. Health Connect permission rationale and permission-usage activities are correctly declared.
- **Correct domain math.** BMR is Mifflin-St Jeor (`lib/core/utils/tdee_calculator.dart:60`). The adaptive TDEE engine labels its fallback as "calibrating" instead of presenting it as fact.
- **Clean food data.** All 573 base foods: no duplicate names, and every item's macros agree with its calories within 35% (4/4/9 check).
- **Static health.** `flutter analyze` reports no issues, graphify finds no import cycles, and fonts are bundled for offline use.
- **Workout draft handling.** A serialized write tail (`_draftWriteTail`), durable drafts, explicit "unavailable, recover or start over" states, and wakelock tied to the launch.

---

## 3. Critical issues (P0: fix before any public release)

### P0-1 Barcode scanner never opens the camera in release builds
`pubspec.yaml` has `mobile_scanner` commented out. `lib/features/food_log/barcode_scanner_screen.dart:7` imports `lib/core/stubs/mobile_scanner_stub.dart`, which always renders **"Camera Inactive (Simulator Mode)"**. Real users get a fake scanner, while the README and `NSCameraUsageDescription` promise barcode scanning.
**Fix:** Bring back the real package for device builds. Recent `mobile_scanner` releases use Apple's Vision framework on iOS rather than MLKit, which should remove the simulator-slice problem; check this against the version you pick. Alternatively, keep the stub only for simulator runs via a `--dart-define` flag, and hide the scanner entry point when it's stubbed.

### P0-2 AI features are switched on in release but can't work
- `AppConfig.connectedAiEnabled = true` (`lib/core/config/app_config.dart:8`), so the photo, natural-language and OCR screens are reachable (`lib/core/router/routes/nutrition_routes.dart:32-46`).
- Every `/api/ai/*` route requires `x-indifit-key` (`backend/routers/ai.py` router dependency). Release builds send it only if `INDIFIT_API_KEY` is passed via `--dart-define`. If you pass it, anyone can extract it from the binary. If you don't, every call returns 401.
- The release backend URL `https://api.indifit.app` isn't deployed, according to your own launch docs.
- The backend's default model is `gemini-1.5-flash` (`backend/core/config.py:12`, `backend/render.yaml`). Google retired the Gemini 1.5 models in 2025, so even a deployed backend would send every request down the mock-fallback path.
- The client calls `/api/ai/coaching-wording` (`lib/data/services/b04_optional_ai_assistance.dart:135`), but **no such endpoint exists** in `backend/routers/ai.py`.

**Fix (recommended for v1):** Gate the AI capability on "backend configured and reachable," and ship v1 with connected AI hidden. Before turning it on, add real per-install auth (Firebase App Check / App Attest + Play Integrity, or anonymous auth with server-issued tokens), switch to a current Gemini model, and either implement or remove `coaching-wording`.

### P0-3 Backend identity and storage aren't production-safe
These are dormant today because sync and cloud backup are disabled in `capabilities_registry.dart` and have no UI. They must not ship as they are.
- `_get_backup_user_id` (`backend/core/security.py:101`) **accepts any Bearer string** and uses its hash as the user id. Nothing is verified, so identity is "whatever token you choose."
- Every caller using the shared API key maps to the **same bucket**, `"default_api_user"` (`security.py:110`). All those users would read and overwrite each other's backups.
- Backups, blobs and sync mutations live in Python dicts (`routers/backup.py:9-10`, `routers/sync.py:12`). They're lost on every restart or deploy, and Render's free tier restarts often.
- Sync dedup is O(n²) per push (`routers/sync.py:136`), and the stream grows without bound.

### P0-4 Rate limiting won't work behind Render's proxy
- `request.client.host` (`security.py:58`) will be the proxy's IP unless uvicorn runs with `--proxy-headers --forwarded-allow-ips='*'`, or you read a trusted `X-Forwarded-For`. In that case **all users share one 30-requests-per-hour bucket**.
- The photo limit trusts a client-supplied `X-Device-UUID` header, so rotating the header bypasses it.
- `IP_REQUEST_LOGS` and `DEVICE_PHOTO_LOGS` never evict keys. Rotating UUIDs therefore grows memory without limit.

### P0-5 CI has been red for 10 days, so nothing is actually enforced
- The last 6+ runs on GitHub all failed. **Flutter CI fails at its first step, "Verify Formatting":** `dart format` would change **258 files**. As a result, analyze, the critical-journey gate, the tests and the Android build haven't run in CI since the failures began.
- **Backend CI fails** because `backend/tests/test_food_search.py` and `test_sync_endpoints.py` import `pytest`, which isn't in `backend/requirements.txt`. Worse, CI uses `unittest discover`, which doesn't collect pytest-style tests: under `pytest` the suite is **71 tests (all pass)**, so 30 have never run in CI.
- 8 local commits aren't pushed.

### P0-6 The test suite isn't green
Full local run: **2,473 passed, 79 failed (38 files)**, then the run hung on the last test file (`r08g2_goal_targets_coaching_test.dart`) and was stopped after a ~10 min stall. Most failures are **stale tests and goldens**, not logic bugs. Examples: the plate calculator now prints `1 × 25 kg` but `test/r08c8_exercise_library_detail_test.dart:267` expects `1x 25.0kg`; the schema contract tests expect v22 but the schema is v23 (`app_database.dart:255`). Some failures (macOS vs Linux font rendering) are golden-only. Either way, a red suite hides real regressions. Some failures are **meaningful**:
- `privacy_policy_enforcement_test.dart`: "V1 blocks connected AI even when Offline Mode is off" fails. Your own test encodes the v1 decision that P0-2 violates.
- Migration tests (v17/v18/v19/v21/v22) all assert `schemaVersion == 22` against v23. The upgrade path to v23 therefore has **no passing contract test**.
- `b02_strength_execution_controller_test.dart`: the save-failure message changed to "Workout duration must be at least 1 second." Check that this is intended UX and not a validation that blocks short sessions.
**Fix:** Refresh the goldens on Linux (the CI platform) and update stale expectations. Then make CI required on `main`.

### P0-7 iOS release build uses the local-testing entitlements
In `ios/Runner.xcodeproj/project.pbxproj:677,704`, both Debug and **Release** point to `Runner-LocalTesting.entitlements`. That file sets `NSFileProtectionComplete`, which makes files unreadable while the phone is locked. This can break DB and notification work that runs on the lock screen during rest timers. The production file correctly uses `...UntilFirstUserAuthentication`.
Also missing:
- The Live Activity widget extension: `ios/RestTimerWidget/*.swift` was never added as a target in `project.pbxproj` in any commit. The Runner-side manager is compiled, but nothing renders the Lock Screen / Dynamic Island UI the docs advertise.
- `ios/Runner/PrivacyInfo.xcprivacy`. The app uses required-reason APIs, such as UserDefaults through `shared_preferences`.
- `ITSAppUsesNonExemptEncryption` in `Info.plist`. The app uses AES, so you'll need an export-compliance answer on every upload.

---

## 4. Test and CI evidence

| Check | Result |
|---|---|
| `flutter analyze` | ✅ No issues |
| `dart format --set-exit-if-changed lib test` | ❌ 258 files need formatting (this is what fails CI) |
| `flutter test` (full, local) | ❌ 2,473 passed / 79 failed; run hung at the end |
| Backend tests (local, `pytest`) | ✅ 71/71 (CI's `unittest` collects only 41) |
| Backend CI | ❌ `ModuleNotFoundError: pytest` |
| GitHub Actions, last 6 runs | ❌ all failed |
| iOS unsigned release build (CI) | ✅ |

Failing test files:

```
8 ux_r06_secondary_goldens   7 ux_r05_progress            6 ux_r02_today_home
5 ux_w06_visual_accessibility 4 ux_r03_food_logging        4 b04_schema_v18_migration
3 ux_r07c_workout_experience  3 pv1_v22_uuid_migration     3 b05_schema_v19_migration
3 b03_schema_v17_migration    2 privacy_policy_enforcement 2 c0b_schema_v21_contract
2 r08d5_multiselect_food      2 ux_r04_training            2 r08g2_goal_targets_coaching
2 rc_phase3b_exercise_family  + 22 files with 1 failure each
```

---

## 5. High-priority issues (P1)

1. **Crash-reporting opt-in only takes effect after a restart.** `CrashReportingService.initialize` skips `SentryFlutter.init` when the user is opted out at boot. `setEnabled(true)` later sets `_isEnabled`, but Sentry was never initialized, so `captureException` does nothing until the next launch (`lib/core/services/crash_reporting_service.dart:41-45, 140-149`). Also, `beforeSend` scrubs only the request and user, not the exception messages, which can contain user food text.
2. **No recovery path if the database fails to open.** `beforeOpen` can throw (`_ensurePreReleaseV17VesselGraph`, `lib/data/database/migrations/schema_migrations.dart:830`), and there's no startup error screen. A user stuck there sees broken screens with no option to export or reset. Add a guarded "database problem" screen that offers to export the raw DB file and contact support.
3. **Repair work runs on every launch.** `beforeOpen` runs integrity repairs and reinstalls dozens of v17/v18 indexes and triggers on every launch (`app_database.dart:386-418`). Gate them behind a stored "repair version" flag to cut cold-start time.
4. **35 empty `catch (_) {}` blocks** (up from the 32 noted in the earlier audit) plus 14 no-op `catchError`. Several are in data paths: `hydration_repository.dart:483,519`, `adaptive_tdee_repository.dart:274`, `progress_statistics_repository.dart:336,371`, `diary_structure_controller.dart:223`. At minimum, log them through `AppLogger`. Add the `empty_catches` lint so the count can't grow.
5. **Streak can be stale.** The streak is cached in SharedPreferences and written **only** by `dashboard_controller.dart:265`. The workout player's achievement checks (`b02_strength_execution_controller.dart:1646`) and `achievements_screen.dart:46` read whatever the dashboard last wrote. Derive the streak from the DB in one repository.
6. **Two controllers over one draft.** The global `b02StrengthExecutionControllerProvider` (launch/resume from the dashboard, training, calendar and quick workout) and the per-screen `b02StrengthExecutionScreenControllerProvider` are separate instances. Both bind to the `RestPresenceService.instance` singleton, and their `_draftWriteTail` serialization doesn't cover each other. It works today, but it's fragile. Have the launcher return a launch value only, and let the screen controller own the draft.
7. **Misleading crypto comment in cloud backup.** `cloud_backup_envelope_manager.dart:290` uses HKDF with a fixed salt and claims this stops brute-forcing of low-entropy secrets. HKDF has no work factor. If the wrapping secret is ever user-chosen, use PBKDF2/Argon2 with a per-user salt.
8. **Backend hygiene.**
   - Fallback responses return `str(e)` to clients (`routers/ai.py:93,127,...`).
   - The Gemini key is sent in the URL query string (`gemini_client.py:38`); use the `x-goog-api-key` header instead.
   - Upstream errors are re-raised as HTTP 500 with Gemini's raw body.
   - The Docker image runs as root and installs `build-essential` unnecessarily.
   - CORS has `allow_credentials=True` with a static origin list, which a mobile app doesn't need.
9. **No `errorBuilder` on the router.** Unknown or deep-link routes fall through to go_router's default error page.

---

## 6. UI/UX review

Based on the 47 E2E screenshots in `docs/audit/screenshots/` and the code. The visual system is clean and consistent: Outfit, a restrained green palette, readable cards, a sensible four-tab IA. The problems are friction and semantics, not looks.

### Workout player (highest impact: this is the screen lifters use most)
- **"Log set" is greyed out with no explanation** when weight is empty (`05_player_01`). Prefill weight from the last session or the suggestion, and if input is invalid, say why next to the button.
- **There's no "Previous" column.** Strong and Hevy users expect to see last time's weight × reps beside each set. That's the most important number when deciding today's load.
- The table has two columns that mostly repeat each other ("Not logged" / "Ready"). Use one compact status checkmark per row, with **one-tap completion that copies the planned values**, so logging takes one tap instead of type-then-press.
- The **"Suggested 8–12 reps · Apply · Change"** card sits below the fold. Fold it into the set row or the "Next set" header.
- The header shows `0:00` and a truncated title ("Chest & Triceps Hyp…"). Show elapsed time from the start, and let the title wrap or shrink.

### Today dashboard
- **Colour meaning is off.** The calorie ring starts with a red arc, and the Fat bar is red. Red reads as "over budget" or "warning." Keep red for actual overages, and use neutral or distinct hues for macros.
- "Fiber: Not available" and "Some nutrition details are incomplete" take space on the hero card. Move incompleteness to an info icon.
- The date-switcher pill uses a lot of vertical space for a rarely used control.

### Training, Progress, Onboarding
- The **"More training"** tiles (Exercise Library, Calendar, Plan Library) use a flat grey fill that looks disabled. Use list rows or outlined cards.
- **Progress → Highlights** is a single small tile with lots of empty space, and the cards are clipped at the screen edges. Use a 2×2 grid or hide the section until there are at least two highlights.
- **Onboarding:** the unselected Male/Female chips have very low contrast. Consider asking the goal first: motivation before demographics improves completion rates.

### Food logging (the strongest flow)
- Search chips (Roti/Dal/Rice/Paneer/Chai), recents with kcal and protein, and one-tap Add are excellent.
- Next steps: **"Repeat yesterday's lunch"** as a single action, and **show the katori/bowl visually** in the portion sheet so household measures feel concrete.
- The empty thali shows `-- kcal` and four empty macro chips. Default to the user's most common archetype (for example "North Indian Classic") so the screen starts useful.

---

## 7. Architecture and maintainability

| Smell | Evidence | Recommendation |
|---|---|---|
| Milestone naming | **87** files in `lib/` named `b0x_*` / `r0x_*` | After launch, rename by domain (`training/`, `nutrition/`, `coaching/`). Do it in one mechanical PR. |
| Test fixtures shipped in the app | `lib/core/fixtures/` = **10,033 lines**, imported by production features (e.g. `training_workout_customization.dart`, `exercise_picker.dart`) | Split real registries (food identity manifest, education content) from test matrices. Move the matrices to `test/`. |
| God files | 12 feature files over 1,000 lines. `food_search_screen.dart` is 2,445 lines with 27 `setState` calls; `program_author_screen.dart` is 2,221. | Extract sections into widgets, and move state into Riverpod notifiers. |
| Backup format sprawl | `backup_schema.dart` (4,202), `backup_v8.dart` (3,801), `backup_v9.dart` (1,646), plus v10 | Keep the **importers** for old versions; delete the old **exporters** (`exportV8ToEnvelopeJson`, `exportV9...`), which still run the KDF synchronously. |
| Repo bloat | `graphify-out/` is tracked (561 files, including a 24 MB `graph.json`); `phase0-fixes.patch` sits at the root | Add `graphify-out/` to `.gitignore` and regenerate locally or in CI. |
| Docs sprawl and staleness | About 150 planning and audit docs. `MASTER_TRACKER.md` still says "schema v16, active batch B02" (the actual schema is v23). The root `IMPLEMENTATION_PLAN.md`, `ISSUES.md` and others coexist with *different* copies in `archive/legacy_plans/`. | Keep one `STATUS.md` (current schema, what's shipped, what's next, known issues) and archive the rest. Generate any scores from CI results, not by hand. |

---

## 8. Roadmap to launch

**Week 1: make what you ship true**
1. Run `dart format lib test`, add `pytest` to the backend requirements, push, and make CI a required check.
2. Fix the stale tests and regenerate the goldens on Linux until the suite is green.
3. Decide on connected features. **Recommended:** hide the AI entry points for v1. Ship the real barcode scanner or hide it.
4. iOS: use `Runner.entitlements` for Release, and add `PrivacyInfo.xcprivacy` and `ITSAppUsesNonExemptEncryption`.
5. Add a DB-open failure screen, and fix the Sentry opt-in so it takes effect immediately.

**Week 2: polish the daily loop**
6. Player: previous-performance column, one-tap set completion, prefilled weight, a visible reason when Log set is disabled.
7. Dashboard colour semantics; "repeat yesterday's meal"; fix the disabled-looking training tiles.
8. Log the empty catches in data repositories, and add the `empty_catches` lint.

**Store logistics (in parallel)**
- Google Play: new personal developer accounts must run a closed test with at least 12 testers for 14 days before production. Start this early, because it gates your Android launch date.
- Apple: the paid developer account is needed for HealthKit and Live Activities on real distribution builds.
- Host the privacy policy at a public URL, and complete the Data Safety form and App Privacy labels to match what the app actually does.

**Before turning on any backend feature**
- Real per-install auth (App Check / App Attest + Play Integrity, or server-issued tokens), and remove the shared key from clients.
- A current Gemini model, trusted proxy headers, a persistent store (Postgres or Redis) for backup and sync, eviction for the rate-limit maps, and no internal error text in responses.

**After launch**
- Domain renaming, splitting the god files, moving fixtures out of `lib/`, pruning old backup exporters, consolidating docs.

---

## 9. Product insight

- **Your moat is real but narrow:** Indian household-measure logging plus a serious strength player. Very few apps do both well. Lead store screenshots and copy with the thali/katori logging and the set logger, not with the architecture ("PBKDF2", "DPDP", "schema v22").
- **Offline-first is a feature, but don't over-explain it.** "Works in the gym basement" lands; "local-first capability contract" doesn't.
- **Retention will come from the daily loop:** log food in under 10 seconds and log a set in one tap. Every hour on that loop is worth more than new modules. The codebase already has far more surface area (coaching, education, period comparison, calendars) than a v1 needs. Consider hiding the less-polished modules behind "Labs" for launch.
- **Process advice:** much of the documentation reads as AI-generated self-scoring ("9.9/10 test rigor", "benchmark quality"). That builds false confidence. Let CI be your source of truth, and when you use AI agents, ask them to *prove* claims with commands rather than grade the work.
