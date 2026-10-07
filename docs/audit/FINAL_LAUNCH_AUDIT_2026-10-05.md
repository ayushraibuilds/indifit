# IndiFit: Final Launch-Readiness Audit

**Date:** 2026-10-05 · **Commit audited:** `25195e6` (`main` = `origin/main`, CI green) · **Auditor:** Claude (independent; earlier audits and plans were treated as claims, not evidence)

Companion documents:
- [Market, moat and revenue](../strategy/MARKET_MOAT_REVENUE_2026-10-05.md)
- [Final launch roadmap and fix plans](../implementation/LAUNCH_ROADMAP_FINAL.md)
- [Nutrition catalogue packs plan](../implementation/NUTRITION_CATALOGUE_PACKS_PLAN.md)
- [Training and progress plan](../implementation/TRAINING_PROGRESS_PREMIUM_PLAN.md)

> **Update 2026-10-06:** Ayush decided nutrition will be online-sourced and locally served: versioned catalogue packs, local search, no search server. The fixes for C-01, C-04, C-06, C-09, A-01 and A-02 now run through that plan (CAT-1 … CAT-12). The findings below are unchanged.
>
> **Update 2026-10-06 (training):** Ayush decided factual best-ever sets and a weekly training goal ship in v1. The workout summary also becomes the reward moment, with motion and haptics. Plan: [TRAINING_PROGRESS_PREMIUM_PLAN.md](../implementation/TRAINING_PROGRESS_PREMIUM_PLAN.md) (TP-1 … TP-14). It covers UX-05 together with PR-D, and part of UX-21.

**Evidence labels used throughout**
- **Verified (live):** reproduced on the iOS Simulator, with a screenshot.
- **Verified (code):** read in the code at the cited line.
- **Verified (probe):** confirmed with a throwaway test, run and then deleted (§ 3.4).
- **Verified (source):** checked against a dated external source.
- **Suspected:** reasoned from code or docs, not reproduced.

---

## 1. Executive summary

### Verdict

| Target | Verdict | Readiness |
|---|---|---|
| **Play closed test (12 testers × 14 days)** | **Not yet. Go after one 2–3 day fix batch (PR-A + PR-B) and four owner steps.** | 5 / 10 |
| **Public production launch (Play + App Store)** | **No-go today.** Realistic only after the closed test, the P1 fixes, and App Check attestation working before Firebase's 2 Nov 2026 enforcement date. | 3.5 / 10 |

### Why

The engineering underneath is better than most solo apps. The data layer, backup crypto, offline food search, one-tap food logging with undo, and the one-tap set logger all held up in a live walkthrough.

But the green suite (2,653 tests) and the earlier "all P0/P1 merged" status hide **defects in IndiFit's headline feature that only show up against the real catalogue**:

1. **Every thali logs 0 kcal and reports "Thali logged successfully!"** (C-01).
   - **Live:** shots 37–45, 54–68.
   - **Probe:** all four presets, and plain roti at any unit.
   - **Cause:** thali and recipe nutrition read only canonical fact rows (`nutrition_recipe_log_coordinator.dart:556`). The 535 bundled foods don't have those rows; their nutrition comes through a legacy adapter.
   - **Why tests miss it:** they use synthetic fixture foods.
2. **A thali started from any meal or date lands in *today's Lunch*** (C-02). `food_search_screen.dart:1583` pushes `/food/thali` with no parameters, and the route defaults to `'lunch'` and today (`nutrition_routes.dart:70`). Live: shots 48–49, 64–68.
3. **The presets pick the wrong foods** (C-03): "egg" → *Baingan Bharta (Roasted eggplant)*, "chicken" → *Boiled Eggs (… Extra Chicken/Meat pieces)*, "curd" → *Home Thali (Veg)*.
4. **"Encrypted cloud backup – IndiFit Cloud – Back up now"** is shown although no cloud exists (SC-03). Tapping it blames the user's connection (shot 118). This also contradicts the privacy policy.
5. **Store basics are missing.** `indifit.app` is a Hostinger parked page with no privacy policy, and it has **no MX record**, so `privacy@indifit.app` (policy contact, recovery-screen support email, Open Food Facts user agent) cannot receive mail. The app has no in-app privacy-policy link, which Apple 5.1.1(i) requires.
6. **AI is on in release builds, but:**
   - attestation isn't registered;
   - Firebase makes App Check enforcement **mandatory for AI Logic from 2 Nov 2026** (source in § 4.3);
   - the ₹950/month Gemini spend cap supports only about 140 AI-active users a month (estimate in the market doc).
   Store users would see "The AI service is unavailable right now" (shot 78).

### What to do (order)

1. **PR-A** (thali correctness), then **PR-B** (store honesty: cloud card, privacy link, jargon, labels).
2. **Owner, this week:**
   - host the privacy policy;
   - set up email forwarding;
   - Play Console app and closed-test track;
   - Apple enrolment;
   - upload keystore;
   - branch protection.
3. Start the closed test as soon as PR-A lands.
4. PR-C/D/E/F during the closed test.
5. Attestation is registered and verified on store-signed builds before **25 Oct**, leaving margin before 2 Nov.
6. Submit.

Full plan: [LAUNCH_ROADMAP_FINAL.md](../implementation/LAUNCH_ROADMAP_FINAL.md).

---

## 2. Scorecard

No generous averaging. A wrong-numbers bug in a core flow caps Correctness at 5; this audit scores it 4.

| Dimension | Score | One-line justification (evidence) | What raises it by 2 |
|---|---:|---|---|
| Correctness & data integrity | **4** | Thali logs 0 kcal with success, and thalis land on the wrong day and meal (C-01/02, live + probe); catalogue variants mislabel measures (C-04). Direct-food logging, totals and undo are correct (shots 23, 30, 34). | PR-A; a real-catalogue test harness; catalogue data v2 (C-04). |
| Reliability | **6** | No crash in about 90 minutes of use; clean resume mid-rest (shot 105); DB opened in 55 ms. But: onboarding page desync (shots 07–09); thali total stuck on "Calculating…" forever; no rest alerts (R-02/03). | Fix R-01/02/03; send handled errors to Sentry breadcrumbs. |
| Security & privacy | **6** | Strong: local crypto, consent copy, EXIF strip. Weak: public repo key with unenforced App Check; privacy labels miss Device ID; "never retained" claim is false; no hosted policy. | Enforce App Check; fix labels and copy; host the policy. |
| Performance | **7** | Cold first DB open 55 ms (sim); search feels instant; crypto and photo work run in isolates. Auto-backup fingerprinting runs on the UI isolate at every start (Suspected). | Measure on a mid-range Android; move backup fingerprinting off the UI isolate. |
| Architecture & maintainability | **5** | Two nutrition-fact sources with lazy materialisation caused C-01. 38 files over 1,000 lines; 10,105 fixture lines in `lib/` with 42 production imports; 87 `b0x_`/`r0x_` files; `graphify-out/` 181 MB tracked. | One fact source; split `food_search_screen`; move fixtures; untrack graphify-out. |
| Test & CI quality | **5** | 2,653 pass, 0 flakes, strong static gates. But the suite never exercises logging against the real catalogue, so C-01/02/03 shipped green. No branch protection. | Real-catalogue integration tests; a copy-lint test; branch protection. |
| UI/UX (daily loop) | **5** | Food search plus one-tap Add is excellent (3 taps for poha), and so is the one-tap set row. But: thali is broken; the portion stepper compounds (×1.25); the Today ring reads as full at 40 %; the rest timer sits below the fold; internal jargon leaks. | Top-10 list in § 6.3. |
| Accessibility | **5** | Dynamic Type scales (good), but breaks words mid-word at the largest size (shot 126). 18/108 `IconButton`s are unlabeled. Reduced-motion is respected (`B05MotionPolicy`). | Labels, large-text layouts, a VoiceOver pass. |
| Store compliance | **3** | No privacy URL or in-app link; dead support email; fake cloud feature; privacy labels incomplete; iPad and landscape enabled but untested; unvalidated "±30 %" accuracy claim. | Close SC-01…SC-08 (mostly S-size). |
| Operability & release | **4** | Kill switch, daily caps and a spend cap exist. But: no branch protection, no Sentry DSN, no signing, AI eval stale (predates #54) and photo/label never evaluated, AI budget too small for launch. | Owner items plus eval rerun plus budget sizing. |
| AI feature quality | **5** | Text eval was good on 3 Oct, but the store's flagship example ("katori dal") needs a manual choice that doesn't offer toor dal; bowl, plate and grams don't convert; release AI can't work until attestation. | PR-F, then rerun the eval with photos and labels. |
| Product focus | **5** | The differentiator (thali) is broken while peripheral surfaces exist: a cloud card, plan filters, Learn, coaching, calendar. | Labs-gate the extras; make thali and set logging perfect. |
| Market differentiation | **6** | A real niche: Indian measures, a serious set logger, and no account, ads or paywall. But the catalogue has 261 distinct dishes, and competitors' AI and katori support exist. | Working thali; 600+ verified dishes; "usual thali" in one tap. |
| Monetisation readiness *(informational)* | **2** | No entitlement, paywall or billing code; no analytics to measure conversion. | Stage-2 plan in the market doc. |

---

## 3. Baseline numbers (2026-10-05)

### 3.1 Commands (audit worktree at `25195e6`)

| Check | Command | Result |
|---|---|---|
| Analyzer | `flutter analyze` | **No issues** (19.6 s) |
| Format | `dart format --set-exit-if-changed --output=none lib test tool` | **839 files, 0 changed** |
| Flutter tests | `flutter test --exclude-tags golden --timeout 120s -j 4` | **2,653 passed, 0 failed, 0 skipped**; 711 s wall; no flakes, so no reruns needed |
| Backend tests | `backend/venv/bin/python -m pytest backend/tests` | **76 passed** (+9 subtests), 3.5 s |
| Code graph | `python3 tool/generate_code_graph.py --ci` | Gate passed: 0 P0 empty catches. 476 Dart files, 2,374 edges, **7 layer violations** (`core/di/user_provider_invalidator.dart` → features) |
| CI on `main` | `gh run list --branch main` | Last 6: 5 success, 1 cancelled (#56, superseded) |
| Branch protection | `gh api …/branches/main/protection` | **404 Not protected** (repo is **public**) |
| Repo secrets | `gh secret list` | **None** (so `SENTRY_DSN` is empty in CI release builds) |

### 3.2 Size and shape

| Metric | Value |
|---|---|
| Hand-written `lib/` | 208,434 lines in 476 files (+132,893 generated) |
| Biggest areas | `food_log` 20,644; `workout_player` 14,176; `settings` 8,841; `dashboard` 8,353; `progress` 6,227; `training` 6,086; `nutrition_ai` 4,310 |
| Files over 1,000 lines | **38**. Largest: `backup_schema.dart` 4,202; `backup_v8.dart` 3,801; `b02_execution_models.dart` 2,704; `b04_adaptive_coaching_fixture_matrix.dart` 2,607; `food_search_screen.dart` 2,585 (29 `setState`) |
| `setState` calls | 445 |
| `lib/core/fixtures` | 12 files, 10,105 lines; imported by **42** production files |
| Milestone-named files | 87 (`b0x_`, `r0x_`, `pv1_`, `c0x_`) |
| Tests | 340 test files, 137,092 lines; 112 golden images |
| Schema | **v23**, 22 `onUpgrade` steps; `beforeOpen` 55 ms on first launch (sim, debug log) |
| Catalogue | 573 rows = **261 distinct dishes + 312 templated variants** ("Mini", "Double", "Low Oil", "With extra cheese / butter"…). 38 retired, so 535 active; 25 regional; 140 exercises. |
| Outdated direct deps | 23. Majors behind: `go_router` 13→18, `flutter_riverpod` 2.6→3.4, `sentry_flutter` 8→9, `flutter_local_notifications` 17→22, `health` 11→13, `fl_chart` 0.67→1.2. `sqlite3_flutter_libs` latest is `0.6.0+eol`. |
| Repo weight | `graphify-out/` = 566 tracked files, **181 MB**; pack 91 MB |
| Docs | 710 Markdown files in the repo |

### 3.3 Store and build state

| Item | State | Evidence |
|---|---|---|
| Android signing | `android/key.properties` → `dummy.keystore` / `dummy_alias`; Gradle throws if missing (good) | `android/app/build.gradle.kts`, `key.properties` |
| Android permissions | INTERNET, CAMERA, ACTIVITY_RECOGNITION, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, VIBRATE, **SCHEDULE_EXACT_ALARM**, 6 Health Connect | `AndroidManifest.xml`; `allowBackup=false` |
| iOS entitlements | Debug → LocalTesting; Profile → dev App Attest; **Release → `Runner.entitlements`** (App Attest production, `…UntilFirstUserAuthentication`) | `project.pbxproj:494,686,713` |
| `PrivacyInfo.xcprivacy` | UserDefaults CA92.1; collects CrashData, OtherUserContent, PhotosorVideos (not linked, no tracking). **No Device ID / Diagnostics** (see S-02). | file |
| Purpose strings | Camera, Photos, HealthShare, HealthUpdate present and accurate (shot 80) | `Info.plist` |
| Export compliance | `ITSAppUsesNonExemptEncryption = false` | `Info.plist` |
| Device family / orientation | **`TARGETED_DEVICE_FAMILY = "1,2"` (iPad) and landscape enabled on iPhone**; no orientation lock in Dart | `pbxproj:483`, `Info.plist` |
| Live Activity | `NSSupportsLiveActivities = true`, but **no widget-extension target** in the project (only app and unit tests) | `pbxproj` product types |
| App Check providers | Release: Play Integrity / App Attest-with-DeviceCheck-fallback; debug: debug provider | `firebase_ai_gateway.dart:167-174` |
| AI in release | **On by default** (`connectedAiEnabled = … : kReleaseMode`) | `app_config.dart:11-14` |
| CI release jobs | APK + AAB with a CI-generated keystore; unsigned iOS app; only `--dart-define=SENTRY_DSN` (empty) | `.github/workflows/ci.yml:104-208` |
| Hosted privacy policy | **None.** `https://indifit.app/*` returns a Hostinger parked page for every path. | `curl` on `/`, `/privacy`, `/privacy-policy`, `/support` (all the same 32 KB page) |
| Email | **`dig MX indifit.app` returns nothing** | DNS |

### 3.4 Probe tests (written in the scratchpad, copied into `test/`, run, deleted; `git status` clean afterwards)

| Probe | Shows |
|---|---|
| `zz_probe_thali_test` | Every real-catalogue thali item: `energy=NULL`, 18/18 nutrients unresolved. That holds for Whole Wheat Roti at 100 g, 1 piece and 2 pieces, and still holds after the main catalogue search ran and with the catalogue's own 1-serving base. All 4 presets have NULL energy. Preset picks: roti→Bajra Roti, dal→Chana Dal Palak, sabzi→missing, curd→Home Thali (Veg), chicken→Boiled Eggs (Extra Chicken/Meat pieces), egg→Baingan Bharta (Roasted eggplant). |
| `zz_probe_ai_binding_test` | "2 roti" → 170 kcal ✓; "4 boiled eggs" → 2 servings, 310 kcal ✓; "1 katori dal" → *choose* Dal Makhani / Urad / Dal Fry (no Toor Dal Tadka); "1 bowl rajma/dal tadka", "1 plate poha/biryani", "150 g rice" → reset to 1 katori; "1 katori curd" → 100 g; "1 banana" → choose *Raw Banana Stir Fry* variants; "1 katori upma" → choose including "(Double healthy bowl)". |

---

## 4. Findings

Severity: **P0** blocks the closed test or public launch; **P1** must be fixed before public launch; **P2** soon after; **P3** polish. Effort: S under half a day, M about a day, L several days.

### 4.1 Correctness and data integrity

| ID | Sev | Finding | Evidence | V/S | User impact | Fix sketch | Eff |
|---|---|---|---|---|---|---|---|
| C-01 | **P0** | Thali (and likely recipe) nutrition is never computed for bundled foods; logging still succeeds with no calories. | Shots 37–45, 54–68 ("Calculating…" for 70 s+, Lunch "— kcal", detail "1 pieces · — · —"). Probe § 3.4. `nutrition_recipe_log_coordinator.dart:556` reads only `nutrition_food_nutrient_facts`; bundled foods' facts come from the legacy adapter (`nutrition_food_catalog_repository.dart:64-100`, lazily copied by `_ensureFacts` :567). | Verified (live + probe) | A user's thali lunch adds 0 kcal; daily totals, targets and streak "food logged" are wrong, with a success message. | One fact reader for all foods (materialise canonical facts for seeded foods once, version-guarded); refuse or flag finalize when energy is unknown; real-catalogue tests. | M–L |
| C-02 | **P0** | The "Indian Thali" chip ignores the meal and date of the landing it was opened from; everything logs to today's Lunch. | `food_search_screen.dart:1583` `context.push('/food/thali')`; `nutrition_routes.dart:70` `meal ?? 'lunch'`, date null. Live: opened from "Log dinner · Yesterday" → title "Lunch Thali" → logged under today's Lunch (shots 48, 49, 65–68). | Verified (live + code) | Back-filling or logging dinner puts food on the wrong day and meal. | Pass `meal` and `date` (reuse the AI-route query helper from #53). | S |
| C-03 | P1 | Thali presets match by substring and use gram defaults against katori/piece foods; one preset food is missing. | `nutrition_thali_controller.dart:669-748`; `thali_presets.dart:38-155`; probe: egg→eggplant, chicken→eggs variant, curd→Home Thali, sabzi missing; shot 48 notice. | Verified (probe) | The default "usual" thali contains wrong foods. | Presets reference stable food ids plus each food's own serving measure; test every preset resolves. | S–M |
| C-04 | P1 | Catalogue variants contradict their measure: 6 rows store grams as katori ("Basmati White Rice (Cooked) (Mini)": 60 katori = 78 kcal); 21 "Double serving/healthy bowl" and 8 "Small side bowl" rows say "Per 1 katori" at 2× or 0.5× kcal. | `assets/data/indian_foods.json` scan; live: three poha rows all "Per 1 katori" at 230/460/115 kcal (shot 21). | Verified (data + live) | Picking "Double healthy bowl" then 2 katori logs 4× the food. | Correct `serving_size` (2 / 0.5 / grams) via a catalogue-v2 migration; invariant test. | M |
| C-05 | P1 | The portion stepper compounds: step = current ÷ 4, giving 1 → 1.25 → 1.5625 → … → **3.0517578125 katori**. | `food_portion_bottom_sheet.dart:553`; shots 25–27. | Verified (live + code) | You can't reach 1½ or 3 katori; amounts show absurd precision. | Additive steps: ½ for household and serving measures (¼ below 1), 10 g / 10 ml. | S |
| C-06 | P1 | AI matcher: household units don't convert (bowl, plate, glass, grams ↔ katori); the flagship "1 katori dal" offers no toor dal; templated variants crowd the choices. | Probe § 3.4; eval file `tool/ai_eval/results/2026-10-03-…md` rows m002, m062–m064. | Verified (probe) | The store copy's own example needs manual fixing; "1 plate biryani" is under-logged by half. | Convert via the portion-sheet vessel grams (katori 150 g, bowl 300 g) or the user's calibrated vessels; a canonical default per generic name ("dal" → Toor Dal Tadka); hide templated variants from choices. | M |
| C-07 | P1 | Saved recipes built from catalogue foods likely compute no nutrition (same coordinator path as C-01). | `NutritionRecipeLogCoordinator` shares `_readCurrentFacts` (:556). | **Suspected** | Recipes log 0 kcal. | Covered by the C-01 fix; add a recipe probe as a regression test. | — |
| C-08 | P2 | Unmatched AI items are saved as permanent custom foods with AI-estimated macros. | `nutrition_ai_controllers.dart:298, 369` (`createUserFood`). | Verified (code) | The custom-food list fills with unreviewed estimates that later look user-made. | Log as a one-off estimate snapshot, or tag the source as "AI estimate" and hide it from search by default. | S |
| C-09 | P2 | 312 templated variants (some nonsensical: "Pani Puri (With extra cheese / butter)", "Idli with Sambar (… extra cheese / butter)") inflate "535 Indian foods". | Data scan; shots 52, 59. | Verified (data) | Clutter and lost trust; misleading store copy. | Retire nonsense variants; the store says "≈260 dishes, with size and oil variants". | S |
| C-10 | P3 | Streak freezes are an allowance re-applied on every calculation over the whole run. | `streak_calculator.dart` doc comment. | Verified (code) | Very forgiving streaks (design choice). | Document it, or consume freezes per week. | S |

### 4.2 Reliability

| ID | Sev | Finding | Evidence | V/S | User impact | Fix sketch | Eff |
|---|---|---|---|---|---|---|---|
| R-01 | P1 | Onboarding can show the **Goal page while the state says "2 of 5"**. Next then validates invisible About fields ("Enter weight between 25 and 350 kg") and Back does nothing: a dead end until Skip or a restart. | Shots 06–09. Trigger: keyboard dismissal on About after editing weight (the PageView was rebuilt at page 0). `onboarding_screen.dart:714-724`, `consumer_task_primitives.dart` (Column children change with `hidePrimaryAction`). | Verified (live, once); trigger Suspected | First-run drop-off. | A widget test toggling `viewInsets`; key the PageView; on validation failure `jumpToPage(_aboutPage)`; a guard keeping `_currentPage` and `controller.page` in sync. | M |
| R-02 | P1 | **iOS:** the rest timer never asks for notification permission. It is requested only from Settings reminder toggles, so lock-screen rest alerts never appear for most users. | `notification_service.dart:137-141` (`request*Permission: false`), `settings_reminder_toggle.dart:89`; live: no prompt during the workout, no notification in Notification Center mid-rest (shots 103–104). | Verified (live + code) | Lifters who lock the phone miss the end of rest. | Ask once, with rationale, on the first rest (iOS + Android 13+ `POST_NOTIFICATIONS`). | S |
| R-03 | P1 | **Android 14+:** when exact alarms aren't granted (the default for new installs), the rest-done alarm is **not scheduled at all**; there's no inexact fallback. | `rest_presence_service.dart:273-277` (`if (!canExact) return false;`); targetSdk 36. | Verified (code); device effect Suspected | No rest alert on most new Android phones. | Fall back to `inexactAllowWhileIdle`, or a foreground-service countdown; optionally deep-link to "Alarms & reminders". | S–M |
| R-04 | P2 | Thali failure state shows "Calculating…" forever; queued notices stack and persist over the totals bar and the Log button. | `thali_nutrition_summary_bar.dart:107-109`; `thali_builder_screen.dart:172-205`; shots 48, 55–56. | Verified (live) | The user can't see that nutrition failed. | Show the failure ("Couldn't calculate: fix the amounts"); disable Log until computed or acknowledged; short-lived notices. | S |
| R-05 | P2 | Handled errors vanish in release: `AppLogger.error` is a no-op outside debug and doesn't reach Sentry. | `app_logger.dart:41-51`. | Verified (code) | No field visibility into AI, backup or repeat failures. | Opt-in Sentry breadcrumbs or events for `AppLogger.error` (scrubbed). | S |
| R-06 | P2 | Auto-backup runs only at cold start; restore and erase don't take a pre-action recovery copy. | `indifit_app.dart:77`; `auto_backup_service.dart`. | Verified (code) | A mistaken restore after a day of logging loses that day. | Snapshot before restore and before erase. | S |
| R-07 | P3 | Debug builds hit `10.0.2.2:8000` (an Android-emulator loopback) for 15 s before falling back to Open Food Facts. | Logs; `app_config.dart:31-34`. | Verified (live) | Debug-only slowness; masks timings. | Default the debug backend to empty on iOS. | S |
| R-08 | P3 | The "Use this plan" first tap gives no feedback; a second tap offers to switch the plan to itself. | Shots 92–95. | Verified (live) | Confusion. | Confirmation plus navigate to Training; show "Current plan". | S |

### 4.3 Security and privacy

| ID | Sev | Finding | Evidence | V/S | Impact | Fix sketch | Eff |
|---|---|---|---|---|---|---|---|
| S-01 | P1 | The repo is **public** with the Firebase API key committed (`54ba36d`), and App Check isn't enforced. Firebase says unverified requests proceed until enforcement, and that **"Starting November 2, 2026, Firebase App Check enforcement will be required to use Firebase AI Logic"**. | `gh repo view` (PUBLIC); `git log -S AIza`; [Firebase AI Logic App Check docs](https://firebase.google.com/docs/ai-logic/app-check) (updated 2026-10-01, accessed 2026-10-05). | Verified (source); abuse path Suspected (not attempted) | Anyone can spend the ₹950 cap, which pauses AI for every user; from 2 Nov, unregistered builds lose AI. | Register App Attest + Play Integrity, verify on store builds, enforce before 2 Nov; restrict API keys. | Owner M |
| S-02 | P1 | Privacy labels are incomplete. Firebase's own disclosure guidance lists App Check, Remote Config and AI Logic as collecting **Device ID/Identifiers + Usage Data + Diagnostics** (Apple), and Firebase Installations' FID and app/device info (Play). `PrivacyInfo.xcprivacy` and the store-copy table list only Crash Data, Other User Content and Photos. | [Firebase App Store data guide](https://firebase.google.com/docs/ios/app-store-data-collection) and [Play disclosure](https://firebase.google.com/docs/android/play-data-disclosure) (both updated 2026-10-01). | Verified (source) | Label mismatch, and a review risk. | Add the types (not linked, app functionality); update the doc and the privacy policy. | S |
| S-03 | P1 | In-app copy says label photos are "processed ephemerally and never retained". The Gemini terms say Google "logs prompts and responses for a limited period of time" for abuse detection (paid tier). | `privacy_disclosure_card.dart:59`, `privacy_policy.dart:27`; [Gemini API terms](https://ai.google.dev/gemini-api/terms) (accessed 2026-10-05). | Verified (source) | An untrue privacy claim. | "IndiFit doesn't keep them; Google may keep them briefly to prevent abuse." | S |
| S-04 | **P0** | No hosted privacy policy and no in-app link. Apple 5.1.1(i): a link is required "within the app in an easily accessible manner". Play needs a policy URL (Health Connect too). | `curl` § 3.3; no policy URL in `lib/`; [Apple guidelines](https://developer.apple.com/app-store/review/guidelines/) (accessed 2026-10-05). | Verified | Submission blocked. | Owner hosts it; code adds Settings → "Privacy policy" plus a link in the consent sheet (it says "linked in our privacy policy", shot 76). | S |
| S-05 | **P0** | `privacy@indifit.app` can't receive mail (no MX). It's used in the policy, the recovery-screen "Email support" (`database_recovery_screen.dart:53`) and the Open Food Facts user agent (`food_api_service.dart:28`). | `dig MX indifit.app` returns nothing. | Verified | Support requests and DPDP/GDPR requests bounce; store contact invalid. | Email forwarding (registrar or Cloudflare Email Routing). | Owner S |
| S-06 | P1 | Gemini tier unconfirmed. Unpaid-tier content "is used to improve Google products". | [Gemini terms](https://ai.google.dev/gemini-api/terms); memory/roadmap owner item. | Suspected | Privacy-policy mismatch if on the unpaid tier. | Owner confirms the paid tier in AI Studio/Console. | Owner S |
| S-07 | P2 | The scanner pre-permission dialog appears even after camera permission was denied (shots 84–85). The scanner fallback is good. | Live. | Verified | Minor. | Skip the rationale when permanently denied; add "Open Settings". | S |

**Strong (keep):**
- PBKDF2 600k + AES-GCM backups with authenticated headers.
- EXIF stripped in an isolate before upload (`ai_photo_sanitizer.dart`).
- Consent copy that names Google, Gemini and Firebase (shot 76).
- Offline Mode blocks online search and AI (shots 122–124).
- Nothing sensitive in logs (query length only).
- `allowBackup=false`.

### 4.4 Store compliance

| ID | Sev | Finding | Evidence | V/S | Fix | Eff |
|---|---|---|---|---|---|---|
| SC-01 | **P0** | Privacy policy URL and in-app link (= S-04) | above | Verified | S-04 | S |
| SC-02 | **P0** | Working support/privacy email (= S-05) | above | Verified | S-05 | S |
| SC-03 | **P0** | "Encrypted cloud backup – IndiFit Cloud – Back up now / Cloud history" shown in v1. It fails with "Could not complete cloud backup. Please check your connection." It contradicts the privacy policy §1 ("V1 does not provide … cloud-sync service"). A review risk under guideline 2.1 (completeness) and for misleading claims. | `data_management_section.dart:626` renders `CloudBackupCard` unconditionally; `capabilities_registry.dart:48-50` returns `DisabledCloudBackupCapability`; shots 117–118. | Verified (live + code) | Render only when the capability is enabled. | S |
| SC-04 | **P0 (owner)** | AI on in release without attestation, plus the 2 Nov enforcement deadline (= S-01) | above | Verified (source) | Register, verify, enforce; or ship with `INDIFIT_CONNECTED_AI=false` if not ready. | Owner |
| SC-05 | P1 | Unvalidated accuracy claim: "Estimates carry ±30% variance" on the photo screen (the photo eval has never run). Apple 1.4.1 requires methodology for accuracy claims. | `photo_meal_screen.dart:162`; shot 79. | Verified | Remove the number; add a visible "Beta" on the screen. | S |
| SC-06 | P1 | iPad and landscape shipped but never tested; App Review uses iPad. | `pbxproj:483`; `Info.plist` orientations. | Verified (config); layout Suspected | v1: iPhone-only (`TARGETED_DEVICE_FAMILY = 1`) and portrait lock. | S |
| SC-07 | P1 | Privacy labels incomplete (= S-02) | above | Verified | S-02 | S |
| SC-08 | P2 | `NSSupportsLiveActivities = true` with no widget extension built. | `Info.plist`; pbxproj | Verified (config) | Remove the key (and the Swift manager) for v1, or add the target. | S |
| SC-09 | P2 | Store copy says "535 Indian foods built in" (= C-09). | `doc/store_listing_copy.md` | Verified | Honest count. | S |
| SC-10 | Owner | Play Health Connect declaration, Data Safety (incl. Device IDs), content rating, 12 testers × 14 days ([Play help](https://support.google.com/googleplay/android-developer/answer/14151465), accessed 2026-10-05) | sources | Verified (source) | Owner steps | — |

### 4.5 Performance

| ID | Sev | Finding | Evidence | V/S | Fix | Eff |
|---|---|---|---|---|---|---|
| P-01 | P2 | Every cold start builds the full v10 backup JSON and SHA-256s it on the UI isolate (`auto_backup_service.dart:52-53`). It is cheap now, but grows with history. | code | Suspected | Fingerprint inside `Isolate.run`, or use a DB change counter. | S |
| P-02 | P3 | `NutritionThaliRepository.searchFoods` loads all active foods and filters in Dart (`nutrition_thali_repository.dart:77-100`). | code | Verified (code) | SQL `LIKE` plus limit. | S |
| P-03 | Owner | Measure cold start and `db_before_open` on a mid-range Android; the sim showed 55 ms on first create. | log | Partially verified | Device check | — |
| P-04 | P3 | Open Food Facts limits: "10 req/min/IP" for search and "15 req/min/IP" for product reads. Indian mobile CGNAT may share IPs. | [OFF API docs](https://openfoodfacts.github.io/openfoodfacts-server/api/) (accessed 2026-10-05) | Suspected | Cache (exists), backoff, a friendly 429 message. | S |

### 4.6 Architecture, maintainability and tests

| ID | Sev | Finding | Evidence | Fix | Eff |
|---|---|---|---|---|---|
| A-01 | P1 | Two sources of truth for nutrition facts (legacy `food_items` adapter vs canonical `nutrition_food_nutrient_facts`, lazily materialised). That is the root of C-01. | § 4.1 | One reader or a one-time materialisation, plus an invariant test that every active seeded food has current canonical energy. | M |
| A-02 | P1 | The tests that matter use synthetic fixture foods (`test/b03_thali_test.dart` `_insertFood`), so 2,653 green tests never logged a real thali. | code | A real-catalogue integration harness (seeded `AppDatabase.memory()`) for direct food, thali, recipe, AI binding and repeat. | M |
| A-03 | P2 | God files: `food_search_screen.dart` 2,585 lines / 29 `setState`; `program_author_screen` 2,220; `plan_library_screen` 2,115. | § 3.2 | Extract landing, results and actions widgets plus notifiers, post-launch. | L |
| A-04 | P2 | Test fixtures in `lib/core/fixtures` (10,105 lines, 42 production imports); 87 milestone-named files; 7 layer violations. | § 3.2 | Post-launch mechanical PRs. | M |
| A-05 | P2 | Dormant code shipped: cloud backup UI (SC-03), `lib/core/sync` 2,372 lines, legacy v8/v9 exporters. | code | Labs-gate or delete. | M |
| A-06 | P2 | Repo hygiene: `graphify-out/` 181 MB tracked (the 1 Oct audit flagged 24 MB); 710 Markdown files. | § 3.2 | `.gitignore` it; consolidate docs into a single STATUS file. | S |
| A-07 | P2 | No copy lint: internal terms reached the UI (see UX-04). | live | A test that bans a list of internal strings in `lib/**` UI text. | S |

### 4.7 Operability

| ID | Sev | Finding | Evidence | Fix |
|---|---|---|---|---|
| O-01 | P1 | `main` unprotected; CI not required. | § 3.1 | Owner: require all 6 jobs. |
| O-02 | P1 | No crash visibility: no `SENTRY_DSN` secret, and release hides the opt-in. | § 3.1 | Owner: Sentry project + secret. |
| O-03 | P1 | AI budget: ₹950/month spend cap ≈ 140 AI-active users/month at the estimated ₹6.7/user (market doc § 6.2). A public launch pauses Gemini mid-month for everyone. | estimate | Owner: raise the cap with launch (₹5–10k) and lower the per-device text cap to 15/day; alert at 50 %. |
| O-04 | P1 | AI eval stale: the last run (3 Oct) predates #54 (eggs, sabzi); label and photo cases are empty; photo is still Beta. | `tool/ai_eval/results/` | Rerun after PR-F with about 20 labels and about 30 photos (paid, owner token). |
| O-05 | P2 | No signed release pipeline or version bump (`1.0.0+1`). | pubspec, CI | Fastlane/`gh` workflow for internal track and TestFlight after keys exist. |
| O-06 | ✓ | Kill switch (`ai_enabled`, refreshed in running apps), per-feature daily caps, spend cap, per-user RPM = 10. | code, memory | Keep. |

### 4.8 UI/UX findings (live simulator is the primary evidence)

Shots live in [`docs/audit/screenshots/2026-10-05/`](screenshots/2026-10-05/). Only 20 of the 126 shots are committed, to keep the repo small (1.7 MB, not 11 MB). They are the evidence for the P0 and P1 findings: 08, 17, 24, 27, 32, 38, 42, 44, 45, 48, 54, 66, 79, 81, 102, 104, 111, 118, 124 and 125. The full set stays untracked on Ayush's Mac. The device was an iPhone 17e (390×844 pt), iOS 26.5, debug build with `INDIFIT_CONNECTED_AI=true`, no App Check token.

| ID | Sev | Screen / state (shot) | What's wrong | Why it matters | Improvement | Eff | Source |
|---|---|---|---|---|---|---|---|
| UX-01 | **P0** | Thali builder → log (37–45, 54–68) | = C-01/C-02/C-03 | The flagship Indian flow records nothing | PR-A | M–L | live |
| UX-02 | P1 | Portion sheet (24–27) | = C-05 stepper; caption lacks grams ("1 katori", not "1 katori ≈ 150 g") | The core edit control is unusable for common amounts | ½-steps; caption with the gram estimate | S | live |
| UX-03 | P1 | Today ring (111) | The donut is a full circle of macro shares (`today_nutrition_widgets.dart:388-440`), so 810 of 2,038 kcal looks almost full; the dominant orange-brown reads as a warning. | Wrong at-a-glance signal on the most-viewed screen | Ring = calories consumed ÷ target (red only above the zone); macros stay as bars | S | live + code |
| UX-04 | P1 | Internal jargon in UI | "Canonical nutrition snapshot" (diary detail, 45, 68; `nutrition_legacy_read_models.dart:296`); "bundled" on every thali-picker row (52; `food_identity_manifest.dart:1494`); "Log Snapshot (<10s)" (32; `quick_add_macros_sheet.dart:565`); "Photo Meal Estimator / AI Meal Decomposition / Review-only contract" (79); "dual-basis" (83); "QUICK MEAL ARCHETYPES" (36); "External volume" (110); "Kitchen AI" (`natural_language_meal_service.dart:35`); "Balanced macros (4-4-9 verified)" (87); "PLANNED CONTEXT" (97) | Feels unfinished and erodes trust | Plain words: "Thali (4 items)", "Log calories", "Meal photo (Beta)", "Scan a nutrition label", "Total lifted" | S | live |
| UX-05 | P1 | Rest timer (100, 102, 106) | The rest card sits below "Log set" and the muscle maps, so the countdown is off-screen while you log; the ring clips the digits ("1:06" overlaps the stroke). | Lifters rest-glance more than anything else | A sticky rest bar under the header (time, −15/+30, Skip); a bigger ring or text inset | M | live |
| UX-06 | P1 | Onboarding desync (06–09) | = R-01 | First-run dead end | — | M | live |
| UX-07 | P1 | Settings → Manage your data (117–118) | = SC-03 fake cloud backup | Misleading | — | S | live |
| UX-08 | P1 | Notifications (103–104) | = R-02/R-03 | Missed rest end | — | S | live |
| UX-09 | P2 | Thali picker (51–53, 57, 59–61) | Defaults "100 g" for roti; offers "Teaspoon"; no kcal or measure per result; can't change an item's unit after adding (tapping the row does nothing); plate labels are ~4 pt and unreadable (38c). | Slow and error-prone thali composition | Default to the food's own measure; show "85 kcal / piece"; tap a row to edit; list view by default | M | live |
| UX-10 | P2 | Photo: camera denied (81) | "Could not analyze photo… try again", but the cause is permission; Try Again can't work. | Dead end | "Camera access is off – Open Settings / Choose from gallery" | S | live |
| UX-11 | P2 | Onboarding About (04, 14) | Age 25, 170 cm, 70 kg prefilled with green "valid" ticks; "Moderately active" preselected. Defaults bias targets upward. | Wrong targets for people who just tap Next | Empty fields with placeholders; no activity default; or show "Using example values" | S | live |
| UX-12 | P2 | Onboarding number fields (06) | Decimal pad has no Done; Next is hidden under the keyboard | Friction | iOS keyboard toolbar "Done / Next" | S | live |
| UX-13 | P2 | Largest Dynamic Type (125–126) | Words break mid-word ("nutriti/on", "Consume/d", "Remaini/ng"); the "Today" pill overflows; the "Add to Dinner / Add dinner" headings fill the first screen | Low-vision users | Single-column layouts above 1.6×; drop duplicate headings | M | live |
| UX-14 | P2 | AI review / thali controls | 18/108 `IconButton`s without tooltip or label (e.g. `natural_language_meal_screen.dart:578, 606` steppers; `thali_component_picker_sheet.dart:205, 223, 409`) | VoiceOver says just "button" | Add tooltips / semantics | S | code |
| UX-15 | P2 | Thali notices (48, 55–56) | Snackbars persist and stack over the total and Log button | Hides the primary action | Short duration; inline banner instead | S | live |
| UX-16 | P2 | Diet step (15) | No Eggetarian or Jain; copy promises "AI meal suggestions" (`onboarding_screen.dart:1299`), but the diet preference isn't used by AI | Indian context and honesty | Add options; fix the copy | S | live |
| UX-17 | P2 | Offline search banner (124) | "Online results are temporarily unavailable" plus retry, when the user turned Offline Mode on | Misleading cause | "Offline Mode is on – showing foods on this phone" | S | live |
| UX-18 | P3 | Plurals | "1 servings", "1 pieces" (35, 82) | Polish | Plural helper | S | live |
| UX-19 | P3 | Food landing (20) | Triple heading "Log breakfast / Add to Breakfast / Add breakfast"; Today "Log food" lands on the diary, not search (19) | An extra tap | One heading; Today → time-of-day meal search | S | live |
| UX-20 | P3 | Onboarding payoff (16–17) | The target (the payoff) is below the fold; "139.0 g / 243.1 g / 56.6 g" false precision | Weak payoff moment | Target first; round grams | S | live |
| UX-21 | P3 | Misc | Back arrow on onboarding step 1 is inert (03); root tabs show a back arrow (89); two "Start workout" taps (96–97); "60 exercises" on a beginner plan (91); meal kcal in orange (112); macro colours differ between the portion sheet (protein orange) and the barcode sheet (protein blue) (24 vs 87) | Polish and consistency | Design-token pass | S | live |

---

## 5. Workflow-by-workflow trace

### 5.1 First launch

- **Path:** `bootstrap` → DB open (background isolate; `beforeOpen` repairs, 55 ms) → onboarding: Goal → About → Activity → Diet → payoff → Today handoff card.
- **Draft:** written per page (`flowVersion` 3) and resumed correctly after a restart (shot 10).
- **Skip:** sets `onboardingSkipped`, so the profile falls back to 2,000 kcal / 120 g protein / 74.5 kg defaults (`user_profile_provider.dart:142-151`). The skip path was code-verified only; the Pro Max run was cut short (§ 6.5).
- **Targets:** verified by hand. Male, 25, 170 cm, 69.5 kg: Mifflin-St Jeor BMR 1,637.5 × 1.55 − 500 = **2,038 kcal**; protein 2.0 g/kg; macros sum to 2,037 kcal (shot 17).
- **Failure points:**
  - R-01 page desync.
  - Biased defaults (UX-11).
  - Recovery screen links to a dead email (S-05).

### 5.2 Food logging

- **Search** (`food_search_screen.dart:326-524`): 300 ms debounce, local plus vocabulary expansion, then Open Food Facts search-a-licious POST. It is cached in `FoodSearchCache` and gated by Offline Mode (`StateError`).
- **Live:**
  - "poha" → 3 catalogue rows (C-04 visible) then Open Food Facts brands (raw poha per 100 g, so a mis-pick risk).
  - "sabzi" folds to "Sabji"; "aloo gobi" finds "Aloo Gobbi".
- **Fast add** (`_addOptionFast` :763): one tap for serving-based foods; an in-flight set de-dups double taps; a fresh command id per tap; Undo retracts the exact snapshot. Verified (shots 23, 30).
- **Portion sheet:** C-05 stepper; the katori drawing works (shots 24–27).
- **Quick add:** works (3 taps; shots 31–34). Logged as "1 pieces · 350 kcal".
- **Thali:** C-01/02/03, UX-09.
- **Repeat yesterday:** works for direct foods (shots 73–74; 2 taps from the diary).
- **Barcode:**
  - The simulator has no camera. The fallback explains itself and offers manual entry (shot 85).
  - Manual 8901058851298 → Maggi 70 g = 306 kcal from Open Food Facts, with ODbL source and editable label values (shot 87).
  - Device camera: owner check.
- **Diary totals:** correct for direct foods (580 → 810 kcal). Thali adds "— kcal".

### 5.3 AI meal tools

- **Consent:** a clear sheet before the first request (shot 76).
- **Describe meal without a token:** the App Check debug-token exchange fails, so "The AI service is unavailable right now." No Gemini call was made (log: `firebase_app_check/server-unreachable` at `exchangeDebugToken`).
- **Binding:** `bindToCatalog` (`natural_language_meal_service.dart:140-176`) makes the review card show exactly what `catalogLogQuantity` logs. Good. Weak spots are in PortionMapping (C-06).
- **Retries:** `AiMealLogSession` with per-item command ids (code).
- **Caps:** `DailyCapAiGateway` reads Remote Config (local, per device).
- **Kill switch:** refreshed for running apps (code).
- **Photo (Beta):** reachable; copy issues (UX-04, SC-05); a dead end on camera denial (UX-10). EXIF is stripped in an isolate.
- **Label scan:** reachable from "More ways" (shot 83).
- Photo and label quality are unmeasured (O-04).

### 5.4 Training

- **Plan:** "Use this plan" activates silently (R-08). The Training card then shows today's session.
- **Player:**
  - "Log set" is above the fold on 390×844.
  - Set 1: tap Weight, type 60, Log set (2 taps plus typing).
  - Sets 2–3: one tap on the row check, with values carried forward (shots 98–101).
- **Rest:** starts after each logged set; ±15/+30/Skip; resumes correctly after 60 s in the background (shot 105).
- **Notifications:** R-02 (iOS: never requested) and R-03 (Android: no fallback).
- **Finish:** "Review and finish" → summary (2 min 48 s, 3 sets, 24 reps, 1,440 kg, all correct) → milestones sheet → saved; Today shows "Workout complete today".
- **Not exercised:** process death mid-workout (`_draftWriteTail` and durable drafts in code); Live Activity (no extension target, so it can't work); history and PR views beyond the summary.

### 5.5 Progress, streaks, dashboard

- **Progress:** shows training highlights and weekly consistency (shot 113).
- **Today:** ring misleads (UX-03); meal rows show orange kcal (UX-21); hydration works.
- **Streak:** a single calculator with a perpetual freeze allowance (C-10).

### 5.6 Data safety

- **Backup format:** v10 with legacy importers v8/v9/base; restore is transactional with failure-injection tests; Restore inspects first and shows counts.
- **Recovery copies:** 3 encrypted copies under a device secret, created at cold start only (R-06).
- **Erase:** wipes tables, backups dir, secure secret and prefs, then verifies counts and FK checks.
- **Date handling:** date context uses IANA tz plus civil `localDate`. India has no DST; there's a midnight scheduler (`civil_date_revision_notifier.dart`).
- **Not tested live:** upgrades from old schemas (covered by migration tests v15–v22).

### 5.7 Settings, privacy, health

- **Offline Mode:** works (shots 121–124).
- **Crash diagnostics:** the toggle is visible in debug (the release hides it without a DSN).
- **Missing:** privacy policy, support and version rows.
- **Health Connect / HealthKit:** owner device checks.

---

## 6. Live UX walkthrough

### 6.1 Gallery (grouped by flow)

| Flow | Shots |
|---|---|
| 1 First run | 01–18 (onboarding goal, about, validation, keyboard, **desync 07–09**, resume 10, activity, diet, payoff, Today) |
| 2 Breakfast three ways | 19–34 (diary, landing, poha search + Open Food Facts, one-tap add, **portion stepper 24–27**, sabzi, aloo gobi, quick add) |
| 3 Thali + repeat | 35–74 (**preset 37–45 zero kcal**, **wrong meal/day 48–49, 64–68**, picker 51–63, repeat yesterday 69–74) |
| 4 AI tools | 75–83 (describe, consent, unavailable, meal photo, camera denied, More ways) |
| 5 Barcode | 84–88 (pre-permission, camera-off fallback, manual lookup, result) |
| 6 Workout | 89–110 (plan, player, one-tap sets, **rest card 102/106**, background 103–105, review, summary) |
| 7 Today/Progress/Settings | 111–121 (ring, meals, progress, settings, **cloud backup 117–118**, privacy, Offline Mode) |
| 8 Error, empty, a11y | 122–126 (offline search, largest text plus dark mode) |

### 6.2 Tap counts for core tasks (live, iPhone 17e)

| Task | Current | Proposed | How |
|---|---|---|---|
| Log a known food (poha) from Today | 3 taps + typing (Log food → meal + → type → Add) | **2** | Today "Log food" opens the search for the time-of-day meal |
| Re-log a recent food | 3 (Log food → meal + → recent Add) | **1** | "Add again" chips on Today's meal rows |
| Quick add calories | 3 from the diary (4 from Today) + typing | 2 | Preselect the meal by time |
| Log a usual thali | 5 (… → Indian Thali → preset → Log), **but logs 0 kcal** | **2** after PR-A | "Log your usual thali" card on the meal landing |
| Repeat yesterday's meal | 2 from the diary | 1 | Card on Today |
| Start the scheduled workout | 3 (Training → Start → Start) | 2 | Drop the preview confirmation, or "Start" on Today |
| Log a set (with values carried) | **1** (row check) | 1 | — (excellent) |
| Log the first set of a new exercise | 2 + typing | 1 | Prefill from plan/history (exists when history exists) |
| Describe a meal | 4 + typing to the review, +1 to log | 3 | "Describe" chip on Today |

### 6.3 Top 10 UX improvements, ranked by impact on the daily loop

1. **Make thali correct** (C-01/02/03), then add a one-tap "usual thali".
2. **Additive portion steps** with a gram caption (C-05).
3. **Today ring = calorie progress**; red only above the zone (UX-03).
4. **Sticky rest bar** plus a notification permission ask on the first rest (UX-05, R-02/03).
5. **Remove internal jargon**, plus a copy-lint test (UX-04).
6. **Today → search in one tap** for the current meal, with "add again" chips (§ 6.2).
7. **Fix onboarding desync** and drop the biased defaults (R-01, UX-11).
8. **Thali picker**: own-measure defaults, kcal per row, edit after adding (UX-09).
9. **AI portion conversions** (bowl, plate, grams) and a canonical dal default (C-06).
10. **Large-text layouts** and labeled icon buttons (UX-13/14).

### 6.4 Device-only checks for Ayush (the simulator can't show these)

1. Real camera barcode scanning on an Android phone and an iPhone (release build).
2. iOS lock-screen rest notification and its Skip / +30 s actions, after the R-02 fix.
3. Android 14+: rest alert when backgrounded, with and without "Alarms & reminders" (R-03).
4. Live Activity: expected *absent* (no extension target). Confirm, and remove the claim.
5. HealthKit and Health Connect permission flows and data.
6. Play Integrity and App Attest: AI works on store-signed builds.
7. Truncated-DB recovery screen.
8. Cold start and `db_before_open` on a mid-range Android.
9. A TalkBack and VoiceOver pass on: Add, the row check, rest controls, the AI steppers.
10. iPad, if `TARGETED_DEVICE_FAMILY` stays `1,2`.

### 6.5 Limits of this walkthrough (stated plainly)

- **Pro Max spot check not completed.** The app launched, but the host ran out of disk (ENOSPC) and swap, and the debug session ended before any screen was captured. SE-size (375×667) wasn't available by choice. Pro Max layouts are **unverified**.
- **No two-week realistic dataset.** Seeding wasn't attempted within the host limits, so list performance and long-history views are **unverified**.
- **AI with a real token** wasn't run (owner chose no paid calls). The AI review card and logging were verified by code and probe only.
- **VoiceOver** wasn't run live (no Accessibility Inspector session); semantics were checked in code.
- **Process death mid-workout** wasn't simulated.

---

## 7. Upgrade proposals (benefit and cost)

| Proposal | Benefit | Cost |
|---|---|---|
| **Single nutrition-fact authority** (materialise canonical facts for all seeded foods at seed/upgrade; delete the lazy path) | Removes the C-01 class; thali, recipe, AI and direct all agree | M; a migration (~535 × 18 rows) plus tests |
| **Real-catalogue integration harness** | Catches the class of bug 2,653 synthetic tests missed | M |
| **Catalogue v2** (fix measures, retire nonsense variants, gram weight per household serving) | Correct portions, honest counts, AI conversions possible | M |
| **Vessel calibration once in onboarding** ("Which katori looks like yours?") | Personal accuracy; a moat (see the market doc) | M |
| **Today as the logging hub** (time-of-day meal, add-again chips, usual thali) | Halves taps on the daily loop | M |
| **Sticky rest bar + notification ask + Android inexact fallback** | Reliable rest alerts | S–M |
| **Copy-lint test + glossary** | Stops internal terms leaking | S |
| **Labs gate** (coaching, Learn, calendar, program author, regional packs) | Focus and less review surface | S–M |
| **Split `food_search_screen`** into landing, results, actions notifiers | Fewer `setState` bugs | L (post-launch) |
| **Untrack `graphify-out`, consolidate docs** | A smaller public repo; one source of truth | S |

## 8. What's strong (don't touch)

- **Data layer:**
  - one `AppDatabase` on a background isolate;
  - immutable consumption snapshots with exact-item undo and retract;
  - transactional, failure-injected migrations and restore.
- **Backup crypto:** PBKDF2 600k + AES-GCM with header AAD, in isolates.
- **Food search:**
  - Hinglish vocabulary, sabzi fold, local-first;
  - Open Food Facts fallback with cache and attribution;
  - Offline Mode enforcement in the interceptor.
- **One-tap food add with Undo**, and double-tap protection.
- **Workout player:**
  - one-tap set rows with carried values;
  - "Log set" above the fold;
  - correct volume math;
  - clean background resume.
- **AI architecture:**
  - "AI parses, catalogue computes";
  - review card = logged values;
  - consent;
  - EXIF strip;
  - kill switch;
  - caps;
  - no fabricated fallbacks.
- **Onboarding target math** (Mifflin-St Jeor, transparent target zone).
- **CI gates:** format, analyze, generated-code diff, code-graph and empty-catch gate, Linux goldens, backend pytest.
