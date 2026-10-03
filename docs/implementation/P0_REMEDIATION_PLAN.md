# IndiFit — P0 Remediation Implementation Plan

**Date:** 2026-10-01 · **Base:** `main` @ `fd5c7cb`
**Source:** [`docs/audit/INDEPENDENT_AUDIT_2026-10-01.md`](../audit/INDEPENDENT_AUDIT_2026-10-01.md), §3
**Goal:** Every feature a release build shows works, CI runs every check, and the iOS/Android release artifacts can go to the stores. Backend features stay off until they are safe.

---

## 0. Summary

| # | Problem | Workstream | Effort (solo) | Blocks launch? |
|---|---|---|---|---|
| P0-5 | CI red for 10 days; 30 backend tests never run | **WS1: CI truth** | 0.5–1 day | Yes (everything else needs it) |
| P0-2 | AI features shown in release but can't work | **WS2: Gate connected AI** | 0.5–1 day | Yes |
| P0-1 | Barcode scanner is a stub in release | **WS3: Real scanner** | 1–2 days | Yes (or hide it) |
| P0-7 | iOS release uses testing entitlements; no privacy manifest; Live Activity extension never built | **WS4: iOS release config** | 1–2 days (+ Apple account) | Yes for App Store |
| P0-6 | 79 failing tests and a hanging run | **WS5: Green suite** | 2–3 days | Yes |
| P0-2b, P0-3, P0-4 | Backend auth, identity, storage, rate limiting, retired model | **WS6: Backend hardening** | Quick fixes 0.5 day; Part B only if AI goes through FastAPI | Part A yes; Part B is replaced by WS7 |
| D1 | Ship AI features safely and accurately | **WS7: AI integration** | 6–8 days | Only for the AI features themselves |

**Critical path:** WS1 → (WS2 ∥ WS3 ∥ WS4) → WS5 → release candidate, with WS7 running in parallel after WS2. If WS7 isn't ready in time, launch with the WS2 flag off and turn AI on in a later update. WS6's quick fixes can land any time. Its full version is needed only before connected features are switched on.

Total to a store-ready offline-core v1: **about 6–9 working days**, plus waiting on the Apple Developer account and Google's closed test.

---

## 1. Decisions (defaults chosen; change them if you disagree)

| Decision | Recommended default | Why | Alternative |
|---|---|---|---|
| D1: Connected AI (label OCR, describe meal, photo meal, coaching wording) in v1? | **Ship AI in v1 via WS7** (Firebase AI Logic). Describe-meal and label scan are GA; photo meal is labelled Beta. WS2's flag stays as the build-time and remote kill switch. | Removes the need to secure and operate your own AI backend, and keeps the Gemini key off devices | Off in v1 (WS2 only), or ship through the hardened FastAPI backend (WS6 Part B) |
| D2: Barcode scanner in v1? | **Ship the real scanner** | Lookup goes straight to Open Food Facts (`FoodApiService`), with **no backend needed**. Packaged foods are a big share of urban Indian diets. | Hide the entry point until later |
| D3: Live Activity / Dynamic Island rest timer | **Wire the widget extension** once the Apple account exists; until then, remove it from marketing copy | The Swift code exists but no Xcode target builds it | Drop the feature and delete `ios/RestTimerWidget/` |
| D4: Cloud backup & sync endpoints | **Don't mount them in deployed builds** (env flag, default off) | They're insecure and in-memory, and the client capability is disabled anyway | — |

---

## 2. Branch & PR sequence

Use one PR per row. Each PR must pass CI before the next one merges.

| Order | Branch | Contents |
|---|---|---|
| 1 | `chore/format-baseline` | `dart format` only, plus `.git-blame-ignore-revs` |
| 2 | `ci/truthful-pipeline` | Backend pytest, split CI jobs, timeouts, golden tagging scaffold |
| 3 | `fix/gate-connected-ai` | WS2 |
| 4 | `fix/real-barcode-scanner` | WS3 |
| 5 | `fix/ios-release-config` | WS4 steps 1–4 (Live Activity is a separate PR, 5b) |
| 6 | `test/green-suite` | WS5 (may be split: schema / copy / goldens / hang) |
| 7 | `fix/backend-quick-hardening` | WS6 Part A |
| — | `feat/backend-install-auth` … | WS6 Part B (later, only before enabling connected features) |

First push the 8 local commits that aren't pushed yet (`git push origin main`), so CI history matches your machine.

---

## WS1 — CI truth (P0-5)

**Problem:**
- `dart format --set-exit-if-changed` fails on 258 files, which stops the Flutter job before analyze, tests and builds run.
- Backend CI fails on `import pytest`.
- Worse, CI runs `unittest discover`, which **doesn't collect pytest-style tests**. Locally, `pytest` runs **71 tests (all pass)**, while `unittest` runs only 41. The remaining 30 have never been executed in CI.

### Steps
1. **Format baseline (PR 1).** The diff will be large, so keep it mechanical-only.
   ```bash
   dart format lib test integration_test tool
   git commit -am "style: apply dart format baseline"
   git rev-parse HEAD >> .git-blame-ignore-revs   # commit this file too
   ```
2. **Backend test deps.** Create `backend/requirements-dev.txt`:
   ```
   -r requirements.txt
   pytest==8.3.*
   ```
3. **Rewrite `.github/workflows/ci.yml`** so that one failure can't hide the others:
   - `static` job: format check, `flutter analyze`, the build_runner diff, `generate_code_graph.py`.
   - `unit_widget` job: `flutter test --exclude-tags golden --timeout 2m --reporter github`.
   - `goldens` job (Linux only): `flutter test --tags golden`.
   - `android_release` job: `needs: [static]`, then the APK/AAB builds and artifact verification.
   - `ios_release` job: unchanged.
   - `backend` job: `pip install -r backend/requirements-dev.txt` then `python -m pytest backend/tests -q`. Replace `unittest discover`.
   - Add `timeout-minutes: 30` to each job, plus `concurrency: { group: ci-${{ github.ref }}, cancel-in-progress: true }`.
4. **Test config.** Add `dart_test.yaml` at the repo root:
   ```yaml
   tags:
     golden: {}
   timeout: 2m
   ```
   Mark golden test files with `@Tags(['golden'])` at the top (the 24 files that call `matchesGoldenFile`; `grep -rl matchesGoldenFile test`).
5. **Make CI binding.** In GitHub → Settings → Branches, add a rule for `main` that requires status checks: `static`, `unit_widget`, `goldens`, `backend`, `android_release`. This is a settings change you make yourself.
6. **Optional local guard:** a `.githooks/pre-commit` running `dart format --set-exit-if-changed` on staged Dart files, enabled with `git config core.hooksPath .githooks`.

### Acceptance
- On PR 2, `static` and `backend` are green.
- `backend` reports **71 passed**.
- `unit_widget` and `goldens` run to completion. They're allowed to be red until WS5, but they must **finish**, not hang.

---

## WS2 — Gate connected AI behind a build flag (P0-2, D1)

**Problem:**
- `AppConfig.connectedAiEnabled = true` (`lib/core/config/app_config.dart:8`), so "Describe a meal" and "Scan nutrition label" always show in Food (`lib/features/food_log/widgets/food_search_recent_list.dart:142,162,257,263`).
- Those screens call a backend that requires a key release builds don't have. That backend isn't deployed and uses a retired model.
- The client also calls `/api/ai/coaching-wording`, which doesn't exist.

### Steps
1. **Flag, default off.** In `lib/core/config/app_config.dart`:
   ```dart
   /// Connected AI ships only when a safe backend exists (see P0 plan WS6).
   /// Enable for development with --dart-define=INDIFIT_CONNECTED_AI=true.
   static const bool connectedAiEnabled =
       bool.fromEnvironment('INDIFIT_CONNECTED_AI');
   ```
   `PrivacyPolicy.isAiAllowed` (`lib/core/privacy/privacy_policy.dart:24`) and `aiAssistanceCapabilityProvider` (`capabilities_registry.dart:75`) already read this value. The photo and NL services (`natural_language_meal_service.dart:160,233`) and coaching wording (`b04_optional_ai_assistance.dart:324`) already refuse when it's false.
2. **Hide the entry points.** In `food_search_recent_list.dart`, make `onScanNutritionLabel` and `onDescribeMeal` nullable (`VoidCallback?`). Wrap the tiles at lines ~142, ~162, ~257 and ~263 in `if (onX != null) ...[ ... ]`, the same pattern already used for `onOpenThali`. In `food_search_screen.dart` (~1419–1439), pass them only when `ref.watch(privacyPolicyProvider).isAiAllowed`.
3. **Guard the routes.** In `lib/core/router/routes/nutrition_routes.dart`, add a redirect to `/food/label-ocr`, `/food/describe` and `/food/photo` that sends users to `/food` when AI isn't allowed. Reuse `compatibilityRouteRedirect`, as `/food/ai` already does at line 14. This covers deep links and the `pushReplacement` in `photo_meal_screen.dart:273`.
4. **Settings and privacy copy.** Search the user-facing text and remove AI/Gemini mentions from v1 surfaces:
   ```bash
   grep -rniE "gemini|\bAI\b|artificial" lib/features/settings lib/core/privacy doc/privacy_policy.md doc/store_listing_copy.md
   ```
   Keep the privacy-policy section about AI only if the flag is on.
5. **Backlog item:** either implement `POST /api/ai/coaching-wording` in WS6 or delete `lib/data/services/b04_optional_ai_assistance.dart`'s network path. Record the choice in the PR description.

### Tests
- `privacy_policy_enforcement_test.dart` "V1 blocks connected AI…" now passes, with no edits needed.
- New widget test: the Food landing page shows no "Describe"/"Scan label" tiles by default. With `privacyPolicyProvider` overridden to `connectedAiEnabled: true`, the tiles appear.
- New router test: `/food/describe`, `/food/label-ocr` and `/food/photo` redirect to `/food` when AI is disallowed.

### Acceptance
- A release APK built without the define shows no AI entry points, and deep links fall back to Food.
- With `--dart-define=INDIFIT_CONNECTED_AI=true` against a local backend, the dev flows still work.

---

## WS3 — Real barcode scanner (P0-1, D2)

**Problem:** `mobile_scanner` was commented out of `pubspec.yaml` in `90ec07c` (it was `^5.1.0`) to work around missing iOS-simulator arm64 MLKit slices. `barcode_scanner_screen.dart:8` now imports `lib/core/stubs/mobile_scanner_stub.dart`, which always renders "Camera Inactive (Simulator Mode)".

### Steps
1. **Pick the version.** Check the `mobile_scanner` changelog for the current major. Recent majors moved iOS/macOS to Apple's Vision framework, which removes the MLKit simulator problem; confirm this before pinning. Add `mobile_scanner: ^<current>` to `pubspec.yaml` and delete the comment.
2. **Swap the import** in `lib/features/food_log/barcode_scanner_screen.dart:8` to `package:mobile_scanner/mobile_scanner.dart`. The screen uses only `start()`, `stop()`, `dispose()`, `MobileScanner(controller:, errorBuilder:, onDetect:)` and `capture.barcodes[].rawValue` (lines 56–405). Adjust `errorBuilder`'s signature if the new major changed it.
3. **Configure for food barcodes:**
   ```dart
   final _scannerController = MobileScannerController(
     formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8,
                     BarcodeFormat.upcA, BarcodeFormat.upcE],
     detectionSpeed: DetectionSpeed.noDuplicates,
   );
   ```
   Then handle app lifecycle: stop on `paused`, start on `resumed`, following the package's README pattern. The screen already calls `start()`/`stop()` around lookups.
4. **Test seam.** Move the stub to `test/support/fake_mobile_scanner.dart`. Add a `barcodeScannerViewBuilderProvider` (a `Provider<Widget Function(...)>`) used at line ~394, so `pv1_catalog01c_barcode_scan_test.dart` can override it with a fake that emits a `BarcodeCapture`. Production code then never imports the stub.
5. **Offline behaviour.** Open Food Facts needs the network. When `!privacyPolicy.isOpenFoodFactsAllowed`, keep the "Scan barcode" tile visible but disabled, with the subtitle "Turn off Offline Mode to look up packaged foods". Don't silently hide it.
6. **iOS build settings.** Align deployment targets: the Podfile says `14.0`, the project says `13.0` (`project.pbxproj:470,607,659`). Set both to the higher of 15.0 and the scanner's minimum. Then run:
   ```bash
   cd ios && pod install --repo-update
   ```
   Confirm that `flutter run` works on an Apple Silicon simulator. The camera will show its error state there, which is expected.
7. **Device QA (record results in the PR):** Android and iPhone, scanning 8 common packaged foods (for example Amul butter, Parle-G, Maggi, Haldiram namkeen, Britannia, a Tata product, a cold drink, a private label). Log the Open Food Facts hit rate. Also test: permission denied, then re-granted from Settings; continuous mode; backgrounding during a scan; Offline Mode on.

### Acceptance
- A release build scans real barcodes on both platforms.
- The stub isn't referenced from `lib/` (`grep -r mobile_scanner_stub lib` returns nothing).
- The scanner test passes through the seam.

---

## WS4 — iOS release configuration (P0-7, D3)

**Problems found in `ios/Runner.xcodeproj/project.pbxproj`:**
- Debug (line 677) **and Release (line 704)** both use `Runner/Runner-LocalTesting.entitlements` (`NSFileProtectionComplete`).
- Profile has **no** `CODE_SIGN_ENTITLEMENTS` at all.
- There's no `PrivacyInfo.xcprivacy` and no `ITSAppUsesNonExemptEncryption`.
- `ios/RestTimerWidget/*.swift` isn't part of any target: it was never added to the project in any commit. The Live Activity *manager* (`ios/Runner/RestTimerLiveActivityManager.swift`) is compiled, but nothing renders the activity UI.

### Steps
1. **Entitlements per configuration.** In Xcode → Runner target → Build Settings → Code Signing Entitlements:
   - Debug → `Runner/Runner-LocalTesting.entitlements` (personal-team sideloads)
   - **Release → `Runner/Runner.entitlements`**
   - **Profile → `Runner/Runner.entitlements`**

   Personal-team builds can't use `Runner.entitlements` (no paid HealthKit profile). For release-mode sideloading before the account exists, add a 4th build configuration, `Release-Local`, that points at the LocalTesting file. Don't repoint Release.
2. **Privacy manifest.** Add `ios/Runner/PrivacyInfo.xcprivacy` to the Runner target, starting from:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0"><dict>
     <key>NSPrivacyTracking</key><false/>
     <key>NSPrivacyTrackingDomains</key><array/>
     <key>NSPrivacyAccessedAPITypes</key>
     <array>
       <dict>
         <key>NSPrivacyAccessedAPIType</key><string>NSPrivacyAccessedAPICategoryUserDefaults</string>
         <key>NSPrivacyAccessedAPITypeReasons</key><array><string>CA92.1</string></array>
       </dict>
     </array>
     <key>NSPrivacyCollectedDataTypes</key>
     <array>
       <!-- Crash data only when the user opts in to Sentry -->
       <dict>
         <key>NSPrivacyCollectedDataType</key><string>NSPrivacyCollectedDataTypeCrashData</string>
         <key>NSPrivacyCollectedDataTypeLinked</key><false/>
         <key>NSPrivacyCollectedDataTypeTracking</key><false/>
         <key>NSPrivacyCollectedDataTypePurposes</key>
         <array><string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string></array>
       </dict>
     </array>
   </dict></plist>
   ```
   After the first archive, open Xcode's **Generate Privacy Report**. Add any required-reason API it flags that the plugins' own manifests don't cover.
3. **Export compliance.** The app encrypts backups with AES (pointycastle). Add `ITSAppUsesNonExemptEncryption` to `ios/Runner/Info.plist` with the value that matches your App Store Connect export-compliance answers. Mass-market data-protection encryption usually qualifies for an exemption, but answer the questionnaire once and mirror the result in the plist, so uploads don't stall on the prompt.
4. **Deployment target.** Shared with WS3 step 6: one value across the project and Podfile.
5. **(PR 5b) Live Activity extension, once the paid account exists:**
   1. In Xcode → File → New → Target → **Widget Extension**, name it `RestTimerWidget`, tick "Include Live Activity", and set the bundle id to `com.indifit.indifit.RestTimerWidget`.
   2. Delete the generated Swift files. Add the existing `ios/RestTimerWidget/RestTimerWidgetBundle.swift`, `RestTimerLiveActivityView.swift` and `Info.plist`.
   3. Add `ios/Runner/RestTimerAttributes.swift` to **both** targets' membership.
   4. Set the extension's deployment target to 16.1 and embed it in Runner ("Embed Foundation Extensions").
   5. Verify on a device: start a rest, lock the phone, and confirm the Lock Screen and Dynamic Island show the countdown, then end the rest and confirm it dismisses.
   6. Until this ships, remove "Live Activity / Dynamic Island" from the README, store copy and docs.
6. **Release verification**, once the account exists:
   ```bash
   flutter build ipa --release
   ```
   Then in Xcode Organizer → **Validate App**. Fix anything it reports before the first TestFlight upload.

### Acceptance
- `xcodebuild -showBuildSettings -configuration Release | grep CODE_SIGN_ENTITLEMENTS` shows `Runner.entitlements`.
- A release IPA passes Organizer validation with no missing-privacy-manifest warnings.
- (5b) A Live Activity is visible on a locked device during rest.

---

## WS5 — Green test suite (P0-6)

**Baseline:** 2,473 passed / 79 failed in 38 files, and the run hung after `r08g2_goal_targets_coaching_test.dart`. Most failures are stale expectations, not product bugs.

### Step 1: Fix the hang first (otherwise CI can't finish)
```bash
flutter test test/r08g2_goal_targets_coaching_test.dart --reporter expanded
```
Then run the files that follow it alphabetically, one at a time, until one stalls. Usual causes:
- `pumpAndSettle()` on a repeating animation (`flutter_animate` `.repeat()`, an indeterminate progress indicator). Use `pump(duration)` instead.
- A `Timer.periodic` or stream that isn't cancelled in `dispose`.
- A `ProviderContainer` that's never disposed.

`dart_test.yaml`'s `timeout: 2m` (WS1) turns any future hang into a failure instead of a stall.

### Step 2: Triage into buckets
A bucket list will be committed as `test/failures/TRIAGE.md`; delete it when the bucket is empty.

| Bucket | Approx. count | Files (examples) | Fix |
|---|---|---|---|
| **A. Schema version** | ~16 | `b03_schema_v17_migration_test`, `b04_schema_v18…`, `b05_schema_v19…`, `c0b_schema_v21_contract_test`, `pv1_v22_uuid_migration_test`, `phase1_data_foundation_test` | Add `test/support/schema_version.dart` with `const kCurrentSchemaVersion = 23;` and replace the hard-coded `22`s (31 occurrences). For "upgrades to vN" tests, assert that the upgrade **reaches** `kCurrentSchemaVersion` and that existing rows are intact. |
| **A2. Missing v22→v23 contract** | new | — | Write `test/c0b_schema_v23_contract_test.dart`: open a real v22 fixture DB, upgrade, assert that `food_search_cache` exists with the expected columns and indexes, and that row counts of all prior tables are unchanged. |
| **B. Stale UI copy** | ~15 | `r08c8…` (`1 × 25 kg`), `r08d5…` ("2 foods selected · 230 kcal"), `pv1_catalog01c…` ("glass (200ml)"), `ux_r07c…`, `b02_strength_execution_controller_test` ("Workout duration must be at least 1 second.") | For each one, run `git log -p -S "<old text>" lib/` to confirm the product change was intended. Prefer `find.byKey`/semantics over exact strings. **Check the workout-duration one:** make sure the new validation doesn't block saving a legitimately short session. |
| **C. Goldens** | ~35 | `ux_r06_secondary_goldens`, `ux_r05_progress`, `ux_r02_today_home`, `ux_w06…`, `ux_r03_food_logging` | Regenerate **on Linux**, the same as CI: `docker run --rm -v "$PWD":/app -w /app ghcr.io/cirruslabs/flutter:3.41.4 flutter test --tags golden --update-goldens`. Review every changed PNG in the PR diff before committing. On macOS, run goldens only via Docker. |
| **D. Behaviour/policy** | ~5 | `privacy_policy_enforcement_test` (fixed by WS2), `b03_estimate_privacy_test` (IST alias now normalizes instead of throwing) | For the timezone test, use a truly invalid zone such as `'Mars/Olympus'` so the error path is still covered. |
| **E. Accessibility/layout** | ~6 | `ux_r06_onboarding_secondary` "compact accessibility matrix", `ux_r08d1` "elevated text scale", `ux_w05` plate calculator large text | Treat these as **real UI bugs** until proven otherwise: run them, read the overflow message, and fix the layout (wrap, `Flexible`, scroll), not the test. |

### Step 3: Keep it green
- CI is required (WS1 step 5).
- Add a PR checklist item: "UI copy or layout changed → tests/goldens updated in the same PR."

### Acceptance
- `flutter test` locally: 0 failures, no hang, under ~20 min.
- CI `unit_widget` and `goldens` are both green.

---

## WS6 — Backend hardening (P0-2b, P0-3, P0-4)

### Part A: quick fixes now (0.5–1 day, PR 7). Safe even while connected features stay off.
1. **Don't expose unfinished routers.** In `backend/main.py` `create_app()`:
   ```python
   if os.getenv("ENABLE_CLOUD_SYNC") == "1":
       application.include_router(backup_router)
       application.include_router(sync_router)
   ```
   Keep the backup/sync tests by setting the env var in their fixtures.
2. **Retired model.** Change the default in `backend/core/config.py:12` and `backend/render.yaml` from `gemini-1.5-flash` to a currently supported Gemini model (check Google's model list at deploy time). Add a startup log line with the model name, and a `/health` field already exists (`main.py:91`).
3. **Gemini key out of the URL.** In `backend/services/gemini_client.py:38,82`, drop `?key=` and send `headers={"x-goog-api-key": gemini_key, ...}`.
4. **Don't leak internals.**
   - Replace `HTTPException(500, detail=f"Gemini API Error: {response.text}")` with a logged error plus `HTTPException(502, "Upstream AI service error")`.
   - In `routers/ai.py`, change fallback `reason=str(e)` to a fixed code such as `"upstream_unavailable"`, and log `e` server-side.
5. **Trusted client IP.**
   - Change the start command in `Dockerfile` and `render.yaml` to:
     ```bash
     uvicorn main:app --workers 1 --host 0.0.0.0 --port $PORT --proxy-headers --forwarded-allow-ips='*'
     ```
     This is acceptable only because Render's proxy is the sole ingress; document that in a comment.
   - Add a test that sends `X-Forwarded-For` and asserts per-client buckets.
6. **Bounded memory.** In `backend/core/security.py:10,14`, replace the plain dicts with `cachetools.TTLCache(maxsize=50_000, ttl=window)`.
7. **Container hygiene.** Drop `build-essential` from the `Dockerfile` (all deps are pure-Python wheels), and add a non-root `USER app`.

### Part B: required before switching on any connected feature (1–2 weeks)
1. **Per-install identity (replaces the shared key on clients).**
   - `POST /v1/installs` registers an install, attested by **App Attest** on iOS and **Play Integrity** on Android. The server stores `install_id` and returns a short-lived signed token (HMAC-SHA256 JWT, roughly 24 h) plus a refresh secret.
   - The client keeps both in `flutter_secure_storage`. A Dio interceptor in `lib/core/di/core_providers.dart:68` adds `Authorization: Bearer <token>` and refreshes on 401.
   - **Remove `x-indifit-key` from the app entirely.** The server key stays only for admin/ops routes.
2. **Identity check.** Rewrite `_get_backup_user_id` (`backend/core/security.py:101`) to **verify** the token signature and expiry, and return its `sub`. Delete the `"default_api_user"` branch.
   Note: install identity is enough for AI quotas, but **cross-device backup and sync need real accounts** (Sign in with Apple/Google). Keep sync and cloud backup post-v1.
3. **Persistent storage.** Use Postgres (Render Postgres, Neon or Supabase) with tables:
   - `installs`
   - `ai_usage(install_id, day, count)` for per-install daily quotas and the global daily Gemini budget (it's currently in memory and resets on restart)
   - later `backup_snapshots` and `sync_mutations`, with a `UNIQUE(user_id, domain, entity_id, hlc_millis, hlc_counter, hlc_node)` constraint that replaces the O(n²) dedup in `routers/sync.py:136`

   Blobs go in object storage (Cloudflare R2/S3), not in the database.
4. **Rate limiting** keyed on the verified `install_id`, with IP as a secondary limit. Photo limits stop trusting `X-Device-UUID` (`security.py:64`).
5. **Validation & honesty.** Add `Field(ge=1, le=7)` and enums to `RoutineRequest`. Remove the fake defaults in `MealPlanRequest` and `WeeklyReportRequest` (`backend/schemas/ai.py`) so missing fields return 422.
6. **Coaching wording:** implement `POST /api/ai/coaching-wording` or delete the client path (WS2 step 5).
7. **Deploy & operate:** Render service with a health check, secrets in the dashboard, an uptime monitor on `/health`, log retention, and a daily cost alert on the Gemini project.
8. **Then** flip `INDIFIT_CONNECTED_AI=true` in release builds, update the privacy policy, App Privacy labels and Play Data Safety (photos and text sent to Google Gemini), and add the one-time consent sheet before the first photo or text upload.

### Tests
- Run under pytest: token forgery is rejected, an expired token is rejected, two installs can't read each other's data, X-Forwarded-For bucketing works, quota persists across app restarts, and a missing field returns 422.

---

## WS7 — Ship AI features in v1 (D1)

### 7.1 What's wrong with the current AI flow (beyond the backend)
1. **Fabricated results on failure.** `_mock_photo_decomposition_v2` (`backend/services/ai_fallbacks.py:391`) answers *any* photo with the same "2 rotis + 1 katori dal tadka" at `confidence: "high"` when Gemini fails. The other mocks do the same for text. An `is_fallback` flag doesn't make made-up food acceptable for a nutrition app.
2. **Weak catalog matching.** `natural_language_meal_service.dart:~196` takes an exact name match, **else the first search result**. "Dal" can silently become whichever dal sorts first.
3. **The LLM invents the nutrition numbers.** Gemini returns kcal and macros per item, while you already have a curated, reviewed Indian catalog with household measures. Your best asset goes unused for AI logs.
4. **Prompt injection and formatting.** User text is pasted straight into the prompt (`backend/routers/ai.py:362`), and the JSON shape is enforced only by prose ("Return STRICTLY a JSON…").
5. **Privacy gaps.** Photos are uploaded at full size, with EXIF (possibly GPS location). There's no in-app consent before data leaves the device, and Apple's guideline 5.1.2(i) (since Nov 2025) explicitly requires disclosure and opt-in before sending personal data to third-party AI.

### 7.2 Architecture choice

| Option | How | Effort | Verdict |
|---|---|---|---|
| **A. Firebase AI Logic** (`firebase_ai` Dart SDK) + **App Check** (App Attest / Play Integrity) | The app calls Gemini through Firebase's proxy. The Gemini key never ships. App Check blocks non-genuine clients, with per-user rate limits configured in the console. | 2 days foundation | **Recommended for v1.** Nothing to host or secure yourself. |
| B. Your FastAPI backend, hardened (WS6 Part B) | Attested install tokens, Postgres quotas, deploy and operate it | 1–2 weeks plus ongoing ops | Only if you need server-side prompts or logic, or want to stay provider-neutral |
| C. Thin serverless proxy (Cloud Run / Workers) that verifies App Check tokens | Prompts stay server-side; Firebase handles attestation | about 4 days | Good later, if prompt iteration without app updates becomes important |

With option A, prompts live in the app. Put the **model name, prompt version and kill switch in Firebase Remote Config** so you can change them without a release.

### 7.3 Design principle: *AI parses, the catalog computes*
```
user text / photo / label
        │
        ▼
Gemini (structured output schema) ──► items: name, aliases, qty, unit, prep, confidence
        │                                (+ AI nutrition estimate, used ONLY as fallback)
        ▼
Local resolver (offline, deterministic)
  • search catalog with name + aliases, score candidates
  • score ≥ threshold → auto-select;  else → "Choose: Dal tadka / Dal makhani / Moong dal"
  • map unit → catalog household measure (katori, roti, piece) via existing conversions
        │
        ▼
Nutrition = catalog facts × quantity     (AI numbers only for unmatched items, badged "AI estimate ±30%")
        │
        ▼
Review screen (existing /food/estimate-review) — user confirms; NEVER auto-logged
```
Label scan is the exception. There the AI's job is to **read printed numbers** (per 100 g and per serving), which is high-accuracy. The user confirms the values, and the result is saved as a custom food.

### 7.4 Steps

**Funding:** the Google Developer Program Premium plan provides about ₹955 per month in Gen AI & Cloud credits, each grant valid for 12 months, on the billing account "My Billing Account". Five grants were unused as of 2026-10-01, roughly ₹4,800 in total. Link the Firebase/GCP project to that billing account and AI usage draws down the credits first. Check *Billing → Credits* for the exact scope and expiry dates.

**Phase 1: foundation (≈2 days)**
1. Create a Firebase project on the **Blaze (paid) plan**, linked to the credited billing account and select the Gemini Developer API provider. Unpaid-tier Gemini API data may be used by Google to improve its products, which your privacy promise can't allow; check the current terms when you set it up.
2. Configure the app:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Then add `firebase_core`, `firebase_app_check`, `firebase_ai` and `firebase_remote_config`.
3. App Check: use App Attest on iOS (DeviceCheck as the fallback) and Play Integrity on Android. Use the **debug provider** for simulators and CI, and register its token in the console. Turn on **enforcement** for Firebase AI Logic once the release build is verified.
4. In the Google Cloud console, restrict the Firebase API key to the required APIs and your bundle/package ids. Set a **budget alert**.
5. Create `lib/core/ai/ai_gateway.dart`:
   ```dart
   abstract interface class AiGateway {
     Future<MealParse> parseMealText(String text);
     Future<MealParse> parseMealPhoto(Uint8List jpeg);
     Future<LabelReading> readNutritionLabel(Uint8List jpeg);
   }
   ```
   with `FirebaseAiGateway` (production) and `FakeAiGateway` (tests). Each call uses `responseMimeType: 'application/json'` and a `responseSchema` built with the SDK's `Schema` type, so output is constrained by the schema, not by prompt wording.
6. Swap the Dio calls in `natural_language_meal_service.dart:166,250` and `nutrition_label_ocr_service.dart:156` for the gateway. Keep the result models (`MealDecompositionResult`, `NutritionLabelOcrResult`) so the screens and review flow stay unchanged.
7. Gating: `isAiAllowed = buildFlag && remoteConfig.ai_enabled && !offlineOnly && consentGiven`, extending `PrivacyPolicy` (`lib/core/privacy/privacy_policy.dart:24`).

**Phase 2: accuracy and honesty (≈2–3 days)**
1. Write a `MealItemResolver` (pure Dart, unit-tested):
   - Score catalog candidates by exact name, alias, then normalized/fuzzy match.
   - Return `resolved`, `needsChoice(top3)` or `unmatched`.
   - Replace the first-result fallback.
2. Map units to catalog measures. Unknown units fall back to a gram estimate, flagged in the UI.
3. Compute nutrition from the catalog. Use AI numbers only for `unmatched` items, with a visible "AI estimate" badge.
4. **Remove every mock fallback from user-facing paths.** On failure, show "Couldn't analyse this right now," with **"Search instead"** pre-filled with the user's text.
5. Prompt the model with Indian context: Hinglish ("2 roti aur ek katori dal"), regional dishes, katori/plate/glass units. Tell it to return items, not totals, and to answer `low` confidence rather than guess.
6. Photos: downscale to about 1024 px JPEG and **strip EXIF** before sending. The photo flow always asks the user to confirm portions. Label it **Beta**.

**Phase 3: consent and compliance (≈1 day)**
1. `AiConsentSheet` appears before the first AI use of each kind (text or photo). It says plainly what is sent (meal text or photo), to whom (Google Gemini, via Firebase), that IndiFit doesn't store it, and how to turn it off. Store the consent version, and add a revoke toggle in Settings → Privacy.
2. Update `doc/privacy_policy.md`, the App Store **App Privacy** labels (photos and user content processed by a third party) and **Play Data Safety** to match. Update the store copy to describe AI as "assistive, review before saving."
3. Offline Mode keeps blocking all AI. That already holds through `isAiAllowed`.

**Phase 4: cost, limits, operations (≈1 day)**
1. Set Firebase AI Logic's **per-user rate limit** low (roughly 10 requests/min/user), plus a local daily soft cap held in Remote Config (for example 30 text / 10 photo / 10 label per day) with a friendly "daily limit reached" message.
2. Remote Config keys: `ai_enabled`, `ai_model`, `ai_prompt_version`, `ai_daily_caps`, `ai_photo_enabled`.
3. Billing guardrails: set a GCP budget of about ₹950/month with alerts at 50%, 90% and 100%. Budgets alert but **don't stop spending**, so on a 100% alert flip `ai_enabled=false` in Remote Config. Optionally automate this with a budget → Pub/Sub → function. Credits run out silently and the card on file is charged after that.
3. Only if analytics are opt-in: count success, edit-before-save rate and abandon rate per feature. A high edit rate means the prompt or resolver needs work.

> **Status (2026-10-03):** Done, apart from analytics.
> - Done: local daily soft caps per feature (`DailyCapAiGateway`, `lib/core/ai/ai_daily_caps.dart`). The Remote Config key `ai_daily_caps` defaults to `{"text":30,"photo":10,"label":10}`. 0 pauses a feature. Malformed values fall back to the defaults. Each request that may reach the model counts; requests never sent (offline, switched off) are given back. Users see a "daily limit reached" message that points them to food search, on both the meal and label screens.
> - Not done: `ai_prompt_version` is not added yet. There is only one prompt version, so a remote switch would have nothing to choose between. Add it with the second prompt version.
> - Done (console): per-user rate limit. The Firebase AI Logic API quota "Generate content requests per minute per project per user" is set to 10 in all 44 regions and in the `(default)` row. Firebase applies only the regional rows. The Bidi (Live API) quotas stay at 100 because the app doesn't use them.
> - Verified (console): a ₹950/month billing-account budget with alerts at 50/90/100/150 %, plus a Firebase-generated ₹950/month **spend cap** on the Gemini API for this project (alerts at 50/80/100 %, status Configured). The spend cap pauses Gemini when exceeded, so `ai_enabled=false` is no longer the only stop. Use it to switch AI off earlier or more gracefully.
> - Not started: per-feature analytics. The app has no analytics SDK; this waits for an opt-in analytics decision.

**Phase 5: evaluation harness (≈1–2 days, then reused on every prompt or model change)**
1. Create `tool/ai_eval/meals.jsonl`: at least 60 real Indian meal descriptions (Hinglish, regional, mixed plates) with expected items, quantities and catalog ids.
2. Add `tool/ai_eval/labels/`: about 20 label photos with true values. Add `tool/ai_eval/photos/`: about 30 meal photos, with weighed ground truth where possible.
3. A runner script reports **item recall/precision, catalog-match accuracy, kcal error (MAPE)** and **label-field accuracy**. Run it before each release and before any change to `ai_model` or `ai_prompt_version`. Any regression blocks the change.
4. Suggested launch bar: label fields ≥95% exact, text item recall ≥90%, catalog match ≥85%. Photo stays Beta until its kcal error is acceptable to you.

> **Status (2026-10-03):** The harness is built (`tool/ai_eval/`, 64 meals). On `gemini-3.8-flash` it meets the meal-text bar:
> - item recall 100 %;
> - catalogue match 100 %, with 94.2 % auto-matched;
> - wrong auto-matches 0 %;
> - meal kcal error 3.6 % mean.
>
> Label and photo cases are still to be collected. Results: `tool/ai_eval/results/`.

**Phase 6: cleanup**
- The FastAPI `/api/ai/*` routes are no longer used by the app. Keep them for local experiments or delete them, but **don't deploy them**. Delete `ai_fallbacks.py` from any deployed path.
- Coaching wording (`b04_optional_ai_assistance.dart`): move it onto the gateway, or remove it for v1.

> **Status (2026-10-03):** Done.
> - The FastAPI AI router mounts only with `ENABLE_AI_ROUTES=1` (local development) and keeps only the three routes the dev gateway uses.
> - Failures return HTTP errors, and `ai_fallbacks.py` is deleted.
> - Coaching wording is removed for v1: its network provider pointed at a deleted endpoint and nothing read it. The consent and data model stay.

### 7.5 Tests
- Unit: resolver scoring and unit mapping; gating matrix (flag × remote × offline × consent); EXIF stripping; cap enforcement.
- Widget, with `FakeAiGateway`:
  - the consent sheet appears once;
  - failure shows "Search instead" and never invented food;
  - nothing logs without the review screen;
  - "needs choice" items block saving until a choice is made.
- Update `privacy_policy_enforcement_test.dart` to the new rule: AI is allowed only when flag, remote config and consent are all on and the app isn't offline.

### 7.6 Acceptance
- Release build: describe-meal and label scan work on real devices behind App Check enforcement. A tampered or emulator client without the debug token is rejected.
- No fabricated result is reachable on any failure path.
- The eval harness meets the launch bar, and results are saved in `tool/ai_eval/results/<date>.md`.
- The consent flow, privacy policy, App Privacy labels and Data Safety form all match actual behaviour.

---

## 3. Definition of done (all P0s)

- [ ] `main` CI green across all jobs and required for merges; backend reports 71+ tests.
- [x] Full local `flutter test`: 0 failures, no hang. *(2,504 pass, 2026-10-03)*
- [ ] AI either meets WS7 acceptance (App Check enforced, consent, no fabricated results, eval bar met) **or** is hidden by the WS2 flag, with AI deep links falling back to Food.
- [ ] Real barcode scanning works on an Android device and an iPhone; offline state is explained in the UI.
- [ ] iOS Release/Profile use `Runner.entitlements`; privacy manifest present; Organizer validation passes.
- [ ] Live Activity either works on a device or isn't claimed anywhere.
- [x] Backend: backup/sync routers unmounted by default, current model, key in header, no error leakage, trusted proxy IPs, bounded memory. *(Proxy trust counts hops via `TRUSTED_PROXY_HOPS`, 2026-10-03.)*
- [ ] README, store copy and `docs/implementation/MASTER_TRACKER.md` describe what actually ships (schema v23, features as gated). *(README and tracker are done; store copy waits for the store listings.)*

## 4. Things only you can do

- Enroll in the Apple Developer Program (blocks WS4 step 6 and 5b).
- Add the GitHub branch-protection rule (WS1 step 5).
- Start Google Play's closed test as early as possible (new personal accounts need ≥12 testers for 14 days before production).
- Answer App Store Connect's export-compliance questionnaire (WS4 step 3).
- Decide D1–D4 if you disagree with the defaults.
