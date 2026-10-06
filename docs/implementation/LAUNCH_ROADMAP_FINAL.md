# IndiFit: Final Launch Roadmap and Fix Plans

Written 2026-10-05 against `main` @ `25195e6`.

- Findings referenced by ID: [FINAL_LAUNCH_AUDIT_2026-10-05.md](../audit/FINAL_LAUNCH_AUDIT_2026-10-05.md)
- Market and revenue: [MARKET_MOAT_REVENUE_2026-10-05.md](../strategy/MARKET_MOAT_REVENUE_2026-10-05.md)
- **Nutrition catalogue (decided 2026-10-06):** [NUTRITION_CATALOGUE_PACKS_PLAN.md](NUTRITION_CATALOGUE_PACKS_PLAN.md).
  - Nutrition data becomes online-sourced and locally served: versioned packs, local search, no search server.
  - It re-scopes PR-A, PR-E and PR-F and adds PR-H to PR-K.
  - Track its work items (CAT-1 … CAT-13) in that plan's § 0.
- **Training and progress (decided 2026-10-06):** [TRAINING_PROGRESS_PREMIUM_PLAN.md](TRAINING_PROGRESS_PREMIUM_PLAN.md).
  - Factual best-ever sets ship in v1. They are derived from logged sets and never estimated.
  - Training gets a weekly goal instead of a daily streak.
  - A summary payoff, motion and haptics pass.
  - Adds PR-L, M and N to v1; PR-O to PR-S join the ready queue (§ 2.5).
  - Track its work items (TP-1 … TP-14) in that plan's § 0.

---

## 0. How to use these docs (solo developer + AI agents)

**Updated 2026-10-06.** IndiFit is built by one person with AI agents, so code is not the bottleneck: review time and outside clocks are. These docs give **order and gates, not calendar dates**. Pull any item forward as soon as its dependencies are met.

**Fixed clocks.** Speed doesn't shorten these; details in § 1.
- Play's closed test: 12 testers opted in for 14 days.
- App Check becomes mandatory for AI on 2 Nov 2026.
- Apple Developer Program enrolment and App Review.
- The INDB authors' reply.
- This Mac runs one full test suite at a time (8 GB RAM).

**Hard rules.** These are the only things that are not negotiable:
1. **Truth:**
   - no invented numbers (no e1RM, no estimated calories presented as fact);
   - honest store claims;
   - never paywall what was free.
2. **CI green before merge, one PR per topic, and the tracker updated in the same PR** (plan § 0 tables).
3. **Agents ask before every push, merge, console or billing change, and paid AI call.**
4. **Run the full suite in a scratchpad worktree,** never in the main checkout.
5. **Freeze bigger changes about 3 days before a store submission build.** Fixes are fine; new features wait for the next build. That way testers' last days cover what actually ships.

**Everything else is guidance:** sizes, the order inside a queue, and the recommendations. When an agent starts an item, it reads the item's plan section, does the work, and updates the tracker row. It needs nothing else.

## 1. Hard dates (the critical path)

| Date | Constraint | Source |
|---|---|---|
| **Closed test start + 14 days** | Play: personal accounts created after 13 Nov 2023 need **≥ 12 testers opted in continuously for 14 days** before applying for production. | [Play help](https://support.google.com/googleplay/android-developer/answer/14151465) (accessed 2026-10-05) |
| **2 Nov 2026** | "Starting November 2, 2026, Firebase App Check enforcement will be **required** to use Firebase AI Logic." Release builds have AI on, so App Attest and Play Integrity must work on store-signed builds before this date. | [Firebase docs](https://firebase.google.com/docs/ai-logic/app-check) (updated 2026-10-01) |
| Apple enrolment lead time | Needed for App Attest, TestFlight and Organizer validation. Start immediately. | — |
| 31 Dec 2026 | Gemini 3.8 Flash paid price is stated "through Dec 31, 2026". Re-check the AI budget. | [Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing) |

**Critical path:**
1. PR-A (thali) merged.
2. Signed build on the Play closed track.
3. 12 testers × 14 days.
4. Production access.

**In parallel:**
- Apple enrolment, then TestFlight, then App Attest verified.
- Both attestations verified by **25 Oct**, then enforcement on.
- If attestation slips past 30 Oct, ship v1 with `--dart-define=INDIFIT_CONNECTED_AI=false` and the AI-free store copy, and turn AI on in 1.0.1.

## 2. Launch sequence: gates, not dates

Each step starts when the previous gate is met. The code in each step is a suggested order; agents can work ahead on anything whose dependencies are met (§ 2.5).

### Step 0: unblock (start now)

| Owner-only | Code (agents) |
|---|---|
| Host the privacy policy at `https://indifit.app/privacy` (text: `doc/privacy_policy.md`, updated by PR-B). Today the domain is a Hostinger parked page. | **PR-A** `fix/catalogue-pack-v1-thali` (P0 C-01 via CAT-1…4: pack format, importer, bundled pack v1, single fact source; plus C-02, C-03, R-04, A-02 real-catalogue harness) |
| Email the INDB authors for permission to use its data (CAT-10) | **PR-B** `fix/store-honesty` (P0 SC-03, S-04 code; P1 S-02, S-03, SC-05, SC-08, UX-04 jargon + copy lint) |
| Email forwarding for `privacy@` and `support@indifit.app` (no MX record today) | **PR-C** `fix/daily-loop-correctness`, **PR-G** `chore/iphone-portrait-v1` |
| Play Console app + closed-test track + 12–15 testers recruited | **PR-L** factual bests, **PR-M** weekly goal, **PR-N** summary payoff (training plan) |
| Apple Developer Program enrolment; start Apple's Paid Applications agreement (tip jar) | **PR-D** `fix/rest-alerts`, **PR-T** tip jar |
| Real Android upload keystore (replace `dummy.keystore`); keep an offline backup | — |
| Branch protection on `main` requiring all 6 CI jobs | — |
| Sentry project + `SENTRY_DSN` secret | — |
| Confirm the Gemini **paid** tier; restrict the Firebase API keys | — |

**Gate:** PR-A and PR-B merged, the policy URL is live, email works, and the Play app exists. The other v1 PRs don't block this gate; they ship in whichever tester build they're ready for.

### Step 1: first real builds

| Owner-only | Code |
|---|---|
| Upload a signed AAB to internal testing, then the closed track; register **Play Integrity** (upload key SHA-256) in App Check | Keep merging the v1 PRs from Step 0 |
| Fill in Data Safety (with Device IDs, PR-B), content rating, Health Connect declaration | — |
| **Start the closed test** (day 0 of 14) | — |

**Gate:** testers can log a thali with correct kcal on a store-signed build.

### Step 2: closed test (14 days; the ready queue keeps running)

| Owner-only | Code |
|---|---|
| TestFlight build; register **App Attest**; verify AI on TestFlight and Play builds | Fix tester reports first |
| Device passes (audit § 6.4); feel the set, rest-end, best and week-goal haptics on one iPhone and one Android phone (TP-7) | **PR-E** `feat/catalogue-pipeline-v2` (CAT-5, CAT-6: C-04, C-09, gram weights, store count) |
| About 20 label photos, about 30 meal photos; paid eval run after PR-F | **PR-F** `fix/ai-portion-conversions` (C-06 via CAT-12), then the eval |
| Raise the Gemini spend cap for launch (O-03); lower the text cap to 15/day in Remote Config | **PR-H** `feat/catalogue-updates` (CAT-7). If it merges during the test, testers get pack v2 over the air. |
| Publish packs on Firebase Hosting (CAT-8; agents prepare the config, you deploy) | Anything else from the ready queue (§ 2.5) |
| Ask testers whether "New best" or the week goal made them want to train again | Store screenshots from the simulator |
| **Enable App Check enforcement** once both providers pass. Aim for about a week before 2 Nov. | — |

**Gate:** 14 days complete, crash-free, the eval bar is met for text (and photo, if it stays outside Beta).

### Step 3: submit (before 2 Nov if AI ships on)

| Owner-only | Code |
|---|---|
| Apply for Play production; App Store submission (privacy labels per PR-B, export compliance, Organizer validation) | Release notes; version `1.0.0+N` bump; feature freeze about 3 days before this build |
| For the tip jar (PR-T): finish Apple's Paid Applications agreement with bank and tax details; set up the Play payments profile; create the tip products in both stores | — |
| Final listing (honest catalogue count, AI lines) | — |

**Fallback:** if attestation isn't working about 3 days before 2 Nov, ship with `INDIFIT_CONNECTED_AI=false` and turn AI on in an update.

### 2.5 Ready queue (any order once dependencies are met)

Agents pull from the top. A queue item can go into a tester build during the closed test, or into any update after launch.

| Group | Items | Notes |
|---|---|---|
| **v1 core** | A, B, C, G, D, L, M, N, T, then E, F, H | A and B gate the first tester build. The rest ship as soon as they're merged. |
| **Next** | O player rows, Q specific reminders, I local search, K "couldn't find it" feedback, "usual thali" one-tap from Today, vessel calibration step | No fixed release number |
| **Plus-gated** | P progress visuals (the TP-9 muscle map and heatmap ship behind the Plus switch; TP-10/11 are free), Plus entitlement and paywall (subscription + lifetime) | Start whenever you choose to launch Plus. Market § 6.4 gates are advice, not rules. |
| **Needs something outside code** | J catalogue growth (the INDB reply, or the CC0/OGL path), S lock-screen rest timer (Apple Developer Program), R home widget (new native targets) | Start when the blocker clears |
| **Maintainability** | Split `food_search_screen`; untrack `graphify-out` (566 files still tracked); delete the old v8/v9 backup exporters but keep their importers (1 Oct audit § 7); docs into one STATUS; remove `percent_indicator` (TP-11); rename `b0x_`/`r0x_`; move fixtures to `test/`; single live-workout owner (WS-D part 2) | Good filler between features; each in its own PR |
| **Long-term** | Health Connect / HealthKit write-back; top-100 lift media; E2E-encrypted sync in Plus (backend WS6 part B) | — |

---

## 3. PR grouping and order

| PR | Contents | Depends on | Size |
|---|---|---|---|
| **A** `fix/catalogue-pack-v1-thali` | CAT-1…4 (pack format, schema v24, importer, bundled pack v1, single fact source; fixes C-01, C-07), C-02, C-03, R-04, A-02 harness | — | L |
| **B** `fix/store-honesty` | SC-03, S-04 (code), S-02, S-03, SC-05, SC-08, UX-04 + copy lint; data-source attributions (CAT-10) | — | M |
| **C** `fix/daily-loop-correctness` | C-05, UX-03, R-01, UX-12; carried from the 1 Oct audit § 6: move the macro "(partial)" labels to the info icon (re-check after PR-A, which may clear them) and shrink the date bar | — | M |
| **D** `fix/rest-alerts` | R-02, R-03, UX-05 | — | M |
| **E** `feat/catalogue-pipeline-v2` | CAT-5 (`tool/catalog` build + validator + CI), CAT-6 overlay (C-04, C-09, gram weights, store count) | A | M |
| **F** `fix/ai-portion-conversions` | C-06 via CAT-12 | E (gram weights) | M |
| **G** `chore/iphone-portrait-v1` | SC-06 | — | S |
| **H** `feat/catalogue-updates` | CAT-7 update service + Settings → Food database (needs CAT-8 hosting) | A | M |
| **I** `feat/catalogue-fts-search` | CAT-9 local FTS5 search; remove the legacy search path | A | M |
| **J** `data/catalogue-growth` | CAT-11 content (INDB if permitted, else recipe-built) | E, CAT-10 | L (mostly data) |
| **K** `feat/missed-search-feedback` | CAT-13 opt-in feedback | H | S |
| **L** `feat/factual-bests` | TP-1 bests engine (fills technique fields in the performance read), TP-2 player chip and haptic, TP-3 summary, share card, exercise history | D (rebase onto it if D merges first) | M–L |
| **M** `feat/weekly-training-goal` | TP-4 goal source, goal history, weekly streak; TP-5 Training, Progress and summary UI; Today chip reads "days logged" | — | M |
| **N** `feat/workout-payoff-motion` | TP-6 summary payoff and one celebration; TP-7 `success()` and `restEnd()` haptics, motion via `B05MotionPolicy` | L, M | M |
| **O** `feat/player-set-rows` | TP-8 sets as rows, full workout title | D | M |
| **P** `feat/progress-visuals` | TP-9 muscles-this-week map, heatmap, recent bests; TP-10 `animations`; TP-11 housekeeping | L, M | M–L |
| **Q** `feat/specific-reminders` | TP-12 | L, M | S |
| **R** `feat/home-widget` | TP-13 | M | L (native targets) |
| **S** `feat/rest-live-activity` | TP-14 | D; Apple Developer Program | L (native targets) |
| **T** `feat/tip-jar` (v1) | Supporter tip jar: 3 consumable IAPs (e.g. ₹49 / ₹99 / ₹199), Settings → "Support IndiFit", a thank-you screen, no unlock; `in_app_purchase`; privacy labels add "Purchases" | — (owner: store products and agreements) | S–M |

Every PR runs:

```bash
dart format lib test tool
flutter analyze
flutter test --exclude-tags golden --timeout 120s
python3 tool/generate_code_graph.py
```

- Every new test is shown to fail on the old `lib/` (`git stash push -- lib`, run the test, `git stash pop`).
- Golden refreshes go through `update-goldens.yml`.

---

## 4. Plans per P0 and P1 finding

### P0-1 · C-01 Thali (and recipe) nutrition for bundled foods  (PR-A)

**Updated 2026-10-06:** steps 1–2 are now delivered as catalogue pack v1. See [NUTRITION_CATALOGUE_PACKS_PLAN.md](NUTRITION_CATALOGUE_PACKS_PLAN.md) CAT-1 to CAT-4 for the format, importer, migration and tests. The guard, UI and tests below are unchanged.

**Change**
1. **One fact source.**
   - Every catalogue food's facts, servings and household conversions are written into the canonical tables by `CatalogPackImporter` from a bundled pack (CAT-2, CAT-3).
   - `NutritionRecipeLogCoordinator._readCurrentFacts` (`nutrition_recipe_log_coordinator.dart:556`) and the thali repository read only canonical facts.
   - The lazy `ensureLegacyFood` writes are removed from search (`nutrition_food_catalog_repository.dart:385-396`).
2. **Persist those facts once.** The bundled pack is applied in the v24 migration and on create. Snapshots stay immutable and reproducible.
3. **Finalize guard.** `NutritionThaliRepository.finalize` refuses when aggregate energy is unknown (error code `thali_nutrition_unknown`), unless the user acknowledges "Log without calories".
4. **UI.** `thali_nutrition_summary_bar.dart:107-109` shows a failure message (not "Calculating…") when `status == failure`; Log Thali is disabled until the preview is ready or acknowledged.

**Files:** `nutrition_recipe_log_coordinator.dart`, `nutrition_thali_repository.dart`, `nutrition_food_catalog_repository.dart`, `app_database.dart` (seed hook), `thali_nutrition_summary_bar.dart`, `thali_builder_screen.dart`.

**Tests (all fail on `25195e6`)**
1. `thali_real_catalogue_test.dart` with a seeded `AppDatabase.memory()`, Whole Wheat Roti × 2 servings: energy == 170 and no unresolved inputs. Today: NULL, 18 unresolved.
2. Each `ThaliPresets.all` preset previews with non-null energy.
3. Finalize with unknown energy throws `thali_nutrition_unknown`.
4. A recipe with two catalogue ingredients previews with energy (C-07).
5. Widget: the failure status renders the error text, and Log is disabled.

**Risks**
- The materialisation writes ~535 × 18 rows on upgrade. It is idempotent and guarded; measure `beforeOpen`.
- Existing thali logs stay 0 kcal: offer "Recalculate" on affected snapshots, or leave them (no production users yet).

**Verify:** the commands above, plus a live simulator thali (North Indian) showing kcal and the diary total increasing.

### P0-2 · C-02 Thali opens with the wrong meal and day  (PR-A)

**Change:** `food_search_screen.dart:1583` → `context.push(_aiRoute('/food/thali'))`, the same helper as the AI routes (#53), passing `meal=` and `date=`. The route (`nutrition_routes.dart:62-74`) defaults to the time-of-day meal, not `'lunch'`.

**Test:** the widget test "Indian Thali chip on 'Log dinner · yesterday' pushes `/food/thali?meal=dinner&date=<yesterday>`" fails today (it pushes the bare path). A repository test checks that finalize writes `localDate` = the selected date.

**Risk:** low.

### P0-3 · SC-03 Fake cloud-backup card  (PR-B)

**Change:** render `CloudBackupCard` (`data_management_section.dart:626`) only when `cloudBackupCapabilityProvider` is not `DisabledCloudBackupCapability` (or `getStatus() != disabled`).

**Test:** the Manage-data screen with the default providers has no "Encrypted cloud backup" text. It fails today (shot 117).

**Risk:** none.

### P0-4 · S-04/SC-01 Privacy policy link in the app  (PR-B code + owner hosting)

**Change**
- `AppLinks.privacyPolicy = 'https://indifit.app/privacy'` and `AppLinks.support = 'mailto:support@indifit.app'`.
- Settings → About: "Privacy policy", "Contact support", "Version 1.0.0 (N)".
- The consent sheet gets a "Privacy policy" link (it already says "linked in our privacy policy").

**Test:** the Settings widget shows a "Privacy policy" row that launches the URL (fake url_launcher). It fails today.

**Risk:** the link must not ship before the page is live; the owner hosts first.

### P0-5 · S-05 Email (owner)

- Add MX/forwarding for `indifit.app` (registrar or Cloudflare Email Routing).
- Verify by sending to `privacy@` and `support@`.
- Then keep `privacy@` in `database_recovery_screen.dart:53` and the Open Food Facts user agent.

### P0-6 · S-01/SC-04 App Check attestation before 2 Nov (owner)

1. Play Integrity: register with the upload key and the Play app-signing SHA-256.
2. App Attest: register with the Team ID after enrolment.
3. Verify a describe-meal call on a Play internal build and on TestFlight.
4. Turn on enforcement for AI Logic.
5. Restrict API keys to the bundle id and package.

**Fallback:** a build with `INDIFIT_CONNECTED_AI=false`, plus the AI-free store copy.

---

### P1-1 · C-03 Presets pick the wrong foods  (PR-A)

**Change:** `ThaliPresetItemDefinition` gets a `foodIdentityKey` (`asset:base:<name>`) and uses the food's own serving quantity, with no substring search. `loadPreset` (`nutrition_thali_controller.dart:669`) resolves by identity.

**Test:** each preset resolves to its intended display names (Whole Wheat Roti, Toor Dal Tadka, a mixed sabji, Basmati rice, Plain curd, Boiled eggs, chicken curry). It fails today (Bajra Roti, Chana Dal Palak, Home Thali, eggplant).

### P1-2 · C-05 Portion stepper  (PR-C)

**Change:** `food_portion_bottom_sheet.dart:553`. Step = ½ for serving and household measures (¼ when the amount is ≤ 1), 10 g or 10 ml for mass and volume. Round the display to the step. Add the gram estimate to the caption.

**Test:** from 1 katori, + gives 1.5, + gives 2; − from 1 gives 0.75. It fails today (1.25, then 1.5625).

### P1-3 · C-04/C-09 Catalogue data v2  (PR-E)

**Updated 2026-10-06:** these fixes are written as pack overlays (CAT-6) and enforced by `tool/catalog/validate.py` (CAT-5). They ship as pack v2, over the air via PR-H or bundled. Since ids never change, the "never rename" risk below goes away: display names can be corrected in a pack.

**Change**
- Fix `serving_size` for the 21 "Double…" (→ 2), 8 "Small side bowl" (→ 0.5) and 6 gram-as-katori rows (→ grams with unit `g`).
- Retire nonsense variants ("With extra cheese / butter" on idli, dosa, dhokla, pani puri, samosa…) via `kRetiredCatalogueFoods`.
- Add a gram weight per household serving.
- Upgrade path: rows match by name, and logs are immutable snapshots.

**Tests**
- Invariant: no household-unit row has `serving_size > 6`.
- A variant's kcal per unit is within ±25 % of its base unless the name implies size or oil.
- Retired variants don't appear in search.
- Today: 6 + 29 violations.

**Risk:** identity keys depend on names (the Aloo Gobbi lesson). Change only `serving_size` and retire, never rename.

### P1-4 · C-06 AI portion conversions  (PR-F)

**Change:** `PortionMapping.map` (`meal_item_resolver.dart:363`).
- bowl = 2 katori and plate = 2 katori (or the user's calibrated vessels);
- grams ↔ serving via the gram weights from PR-E;
- "katori" on a per-100 g food → 150 g.
- `genericDefaults`: "dal" → Toor Dal / Yellow Dal Tadka; "banana" → raw-fruit banana if present.
- `decide`: exclude templated variants from `choices`.

**Tests:** the probe cases in audit § 3.4 become assertions. "1 bowl dal tadka" → 2 katori; "1 plate poha" → 2 katori; "150 g rice" → 1 katori when the katori weighs 150 g; "1 katori dal" auto-matches Toor Dal. Each fails today.

**Then:** paid eval rerun (owner token) with label and photo cases.

### P1-5 · R-01 Onboarding page desync  (PR-C)

**Change**
- Give the `PageView` a `PageStorageKey` and keep `_currentPage` derived from `controller.page`.
- On any validation failure on About, `jumpToPage(_aboutPage)` first.
- Hide the Back button on page 0.

**Test:** a widget test on About focuses the weight field, sets `tester.view.viewInsets` (keyboard) then clears it, and expects the About title visible with the "2 of 5" indicator. Today: the Goal title is shown (shots 07–09). Confirm the reproduction first; adjust if the trigger turns out to be different.

### P1-6 · R-02 iOS notification permission  (PR-D)

**Change:** on the first rest of the first workout, a short rationale sheet, then `NotificationService.requestPermissions()`. Store "asked". On Android 13+, request `POST_NOTIFICATIONS` the same way.

**Test:** a fake permission requester is called exactly once on the first `beginRest`. Today: 0 calls.

### P1-7 · R-03 Android exact-alarm fallback  (PR-D)

**Change:** `rest_presence_service.dart:273-277`. When `canScheduleExactNotifications()` is false, schedule with `AndroidScheduleMode.inexactAllowWhileIdle`. Offer "Allow precise rest alerts" (deep-link to the exact-alarm setting) once.

**Test:** with a driver fake returning `canExact=false`, `zonedSchedule` is called with inexact mode. Today: not called.

### P1-8 · UX-05 Rest visibility  (PR-D)

**Change:** a sticky rest bar under the player header (time left, −15 / +30, Skip) while a rest is open; fix the ring's text inset.

**Test:** after Log set at 390×844, the rest time is visible without scrolling. Plus a golden.

### P1-9 · UX-03 Today ring  (PR-C)

**Change:** `CalorieRing` (`today_nutrition_widgets.dart:358-440`) draws consumed ÷ target (`CalorieRingPainter` exists, :576), red only above the target zone. Macros stay as the bars below.

**Test:** with 810 of 2,038 kcal the ring progress is ≈ 0.40. Today it's a full macro pie.

### P1-10 · S-02/S-03/SC-05/UX-04 Store honesty  (PR-B)

**Change**
- `PrivacyInfo.xcprivacy`: add Device ID (Identifiers) and Diagnostics (not linked, app functionality); update the store-copy table and the privacy policy (Firebase App Check / Remote Config / Installations identifiers).
- Replace "never retained" (`privacy_disclosure_card.dart:59`, `privacy_policy.dart:27`).
- Remove "±30% variance" (`photo_meal_screen.dart:162`) and title the screen "Meal photo (Beta)".
- Jargon list (audit UX-04) → plain words.
- New `test/copy_lint_test.dart` bans `Canonical`, `snapshot`, `contract`, `archetype`, `dual-basis`, `bundled`, `Kitchen AI` and `(<10s)` in UI strings under `lib/features/**`.
- Remove `NSSupportsLiveActivities` (SC-08) for v1.

**Tests:** the copy lint fails today; a privacy-manifest test asserts the new types.

### P1-11 · SC-06 iPhone-only and portrait for v1  (PR-G)

**Change:** `TARGETED_DEVICE_FAMILY = 1`; iPhone orientations portrait only; `SystemChrome.setPreferredOrientations([portraitUp])` at boot.

**Test:** a script or test parses `project.pbxproj` and `Info.plist`.

**Risk:** iPad users can still run it in iPhone compatibility mode (acceptable).

### P1-12 · A-02 Real-catalogue harness  (PR-A)

**Change:** `test/support/real_catalogue.dart` builds the seeded DB, registry and all repositories in one call. It is used by P0-1, P1-1, P1-3 and P1-4.

### P1-13 · Owner P1s

- Branch protection (O-01).
- Sentry DSN (O-02).
- Spend cap sizing (O-03): set it from market doc § 6.2 after measuring tokens in the eval.
- Eval rerun with photos and labels (O-04).
- Gemini paid tier (S-06).
- Health Connect declaration (SC-10).

## 5. Decisions only Ayush can make (with recommendations)

1. **Hold the closed test until PR-A lands?** **Decided 2026-10-06: yes.** Indian testers will open the thali first, and a 0-kcal thali wastes the 14 days that count.
2. **Ship AI on in v1 given the 2 Nov enforcement date?** **Decided 2026-10-06: yes, conditionally.** It stays on only if both attestations pass on store builds by 25 Oct; otherwise build with `INDIFIT_CONNECTED_AI=false` and turn AI on in 1.0.1.
3. **AI budget for launch.** **Open; Ayush is investigating.** Idea: a cheaper model as a fallback, e.g. when spend nears the cap. The model is already a Remote Config key (`ai_model`), so switching needs no release. A candidate must pass the text eval first (0 % wrong auto-match, kcal error within the current 3.4 %), with `usageMetadata` logged for cost. Until then, *recommend* a spend cap of about ₹5,000/month at public launch, a text cap of 15/day and a 50 % alert.
4. **iPad in v1?** **Decided 2026-10-06: iPhone-only and portrait for now** (PR-G).
5. **Catalogue in the store listing.** **Decided 2026-10-06: grow the catalogue before the listing.** Open timing:
   - (a) build dishes from CC0/OGL ingredient data in October (tight);
   - (b) launch with an honest "260+ dishes" and grow monthly through packs (*recommended*: that's what packs are for);
   - (c) delay the listing.

   Either way the count must stay honest (no templated variants counted as dishes).
6. **Labs gate for v1** (coaching, Learn, calendar, program author, regional packs). **Decided 2026-10-06: yes.**
7. **Revenue path.** **Decided 2026-10-06** ([market doc](../strategy/MARKET_MOAT_REVENUE_2026-10-05.md) § 6.5):
   - **Supporter tip jar at launch** (PR-T): "Buy a chai" in-app purchases that unlock nothing.
   - **IndiFit Plus whenever you choose to launch it** (about Feb 2027 was the suggestion): ₹99/mo · ₹699/yr, **plus a lifetime option** at about 3× the annual price.
   - **Always free:** logging, thali, bests, weekly goal, reminders, home widget, backups.
   - **Plus:** photo and label AI, unlimited describe, the TP-9 progress visuals (muscle map, heatmap) and period comparison, program builder, encrypted sync.
   - Nothing shipped free is ever moved to Plus.
8. **Commit the audit screenshots (11 MB)?** **Done 2026-10-06:** the audit docs and a curated 20-shot subset (1.7 MB) are in PR #60; the rest stays out of git.
9. **Decided 2026-10-06:** nutrition is online-sourced and locally served (catalogue packs, local search, no search server). Training stays offline-first. Open sub-decisions are listed in [NUTRITION_CATALOGUE_PACKS_PLAN.md](NUTRITION_CATALOGUE_PACKS_PLAN.md) § 11: the INDB permission email, Wi-Fi-only downloads, pack v2 over the air during the closed test, and a dietitian review.
10. **Decided 2026-10-06:** factual best-ever sets ship in v1 (PR-L). They are derived only from logged sets, with no e1RM and no stored PR flag. This amends R08_0 § 546–548.
11. **Decided 2026-10-06:** training uses a weekly goal ("2 of 3 this week · 4 weeks in a row") instead of a daily streak (PR-M). The daily streak stays on Today as "days logged".
12. **Decided 2026-10-06:** part of the training polish goes into v1: PR-L, M and N. The 20 Oct cut line was dropped the same day (§ 0). Open sub-decisions are in [TRAINING_PROGRESS_PREMIUM_PLAN.md](TRAINING_PROGRESS_PREMIUM_PLAN.md) § 13: weekly badges, goal override with a plan, and a tester question.
