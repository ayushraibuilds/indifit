# IndiFit Implementation Tracker

Last updated: 2026-10-07 (PR-N: workout summary payoff, motion and haptics, TP-6 and TP-7)
Current schema: v24 (`catalog_state`, bundled food pack v1, PR-A)
Current backup format: v10
Current focus: **V1 launch readiness**. Read [LAUNCH_ROADMAP_FINAL.md § 0](LAUNCH_ROADMAP_FINAL.md) first (fixed clocks, hard rules, no calendar dates). Work from [LAUNCH_ROADMAP_FINAL.md](LAUNCH_ROADMAP_FINAL.md) (fix batches PR-A…T, plans P0-1…P1-13, owner tasks, decisions). Evidence is in [FINAL_LAUNCH_AUDIT_2026-10-05.md](../audit/FINAL_LAUNCH_AUDIT_2026-10-05.md). Nutrition-data work is tracked in [NUTRITION_CATALOGUE_PACKS_PLAN.md](NUTRITION_CATALOGUE_PACKS_PLAN.md) § 0 (CAT-1…CAT-13); training and progress polish in [TRAINING_PROGRESS_PREMIUM_PLAN.md](TRAINING_PROGRESS_PREMIUM_PLAN.md) § 0 (TP-1…TP-14). The earlier plans ([P0](P0_REMEDIATION_PLAN.md), [P1](P1_REMEDIATION_PLAN.md), [audit 2026-10-01](../audit/INDEPENDENT_AUDIT_2026-10-01.md)) are kept for history.

Batches B01–B05 and the post-v1 and R07/R08 tracks are merged into `main`. Their plans and evidence are kept in `batches/`, `post-v1/`, `r08/` and `ux/` for history; they no longer describe current work.

## What ships in v1

| Area | State |
|:-----|:------|
| Training, workout player, progress | Shipping. Added for v1 (decided 2026-10-06): factual "New best" sets (PR-L), a weekly training goal instead of a daily streak (PR-M), and a summary payoff with motion and haptics (PR-N). They ship as soon as they merge ([training plan](TRAINING_PROGRESS_PREMIUM_PLAN.md)). **PR-M done (TP-4, TP-5):** "2 of 3 workouts this week · 4 weeks in a row" on Training, Progress and the workout summary; Today's chip reads "days logged". The goal and its per-week history live in SharedPreferences (no schema change) and are included in backups. |
| Nutrition: catalogue (base + optional regional packs), Circular Thali, diary, targets | Shipping. 38 catalogue entries (18 duplicates and 20 nonsense dairy variants) were retired on 2026-10-03; they are deprecated, not deleted, and leave search. **P0 open:** every thali logs 0 kcal for bundled foods (audit C-01). The fix is PR-A, which ships the catalogue as bundled pack v1 with one read path ([packs plan](NUTRITION_CATALOGUE_PACKS_PLAN.md) CAT-1…4). |
| Barcode lookup (Open Food Facts) | Shipping when Offline Mode is off. Uses Apple Vision on iOS. |
| AI meal tools: describe a meal, meal photo, label scan | **Shipping in v1** (decided 2026-10-05): on in release builds, off in debug unless `INDIFIT_CONNECTED_AI=true`. Uses Firebase AI Logic with App Check and needs consent. Meal photo is Beta until its eval runs. Needs Play Integrity and App Attest registered before release. |
| AI coaching wording | Not in v1 |
| Cloud backup and sync | Not in v1. Backend routes are unmounted unless `ENABLE_CLOUD_SYNC=1`. |
| Devices and orientation | iPhone only, portrait only (decided 2026-10-06, audit SC-06). PR-G sets `TARGETED_DEVICE_FAMILY = 1`, limits `Info.plist` to portrait, and locks portrait at boot, which also holds Android phones upright. iPads run the app in iPhone compatibility mode. |
| Supporter tip jar (Settings → Support IndiFit) | **Code done in PR-T:** 3 consumable tips (`indifit_tip_small/medium/large`, suggested ₹49 / ₹99 / ₹199) via `in_app_purchase`; unlock nothing; store contacted only when the tip screen opens and never in Offline Mode; every transaction is completed. Until the products exist the screen says tips aren't set up yet. **Owner:** Apple Paid Applications agreement (bank and tax), Play payments profile, and the three products in both stores. |

## P0 definition of done

| Item | State |
|:-----|:------|
| `main` CI green on all jobs | Goldens still fail until they are regenerated on Linux (`update-goldens.yml`) |
| `main` requires CI before merging | **Owner:** add the branch-protection rule |
| Full local `flutter test` passes, no hang | Done: 2,504 tests, goldens excluded |
| Backend tests | Done: 73 tests |
| AI: consent, no fabricated results, eval bar | Done for meal text: catalogue match 100 %, wrong auto-match 0 %. Label and photo eval need real images. |
| AI: App Check enforced on store builds | **Owner:** Play Integrity needs a Play Console app and an upload keystore; App Attest needs the Apple Developer Program |
| Barcode scanning on real Android and iPhone | Code done; **owner** to verify on devices |
| iOS entitlements and privacy manifest; Organizer validation | Entitlements per configuration and `PrivacyInfo.xcprivacy` are present. PR-B adds the Firebase types (Device ID, Product Interaction, Other Diagnostic Data; not linked, app functionality; audit S-02). Validation needs the Apple Developer Program |
| Live Activity works on device or isn't claimed | Not claimed in v1: there is no widget-extension target, so PR-B removes `NSSupportsLiveActivities` from `Info.plist` (audit SC-08; the Swift manager stays for TP-14). The lock-screen rest timer comes later as TP-14 (PR-S). |
| Backend: current model, key in header, no error leakage, bounded memory, trusted proxy hops | Done |
| Store honesty (PR-B) | In PR-B: no cloud backup card in v1 (SC-03); Settings → Privacy policy, Contact support and Version, plus a policy link in the AI consent sheet (S-04 code; **owner** hosts `indifit.app/privacy` and the `support@`/`privacy@` mailboxes first); "never retained" and "±30%" removed (S-03, SC-05); UX-04 jargon replaced; `test/copy_lint_test.dart` guards it (A-07) |
| Rest alerts (PR-D) | In PR-D: the first rest explains rest alerts once, then asks for notification permission (iOS and Android 13+; R-02); without Android exact alarms the rest alert is scheduled inexactly instead of not at all, with a one-time "Allow precise rest alerts" offer (R-03); a rest bar under the player header shows time left, −15 / +30 and Skip, and the ring digits no longer touch the stroke (UX-05). **Owner:** check the lock-screen alert on an iPhone and on Android 14+ with and without "Alarms & reminders" |
| Factual bests (PR-L, TP-1…TP-3) | In PR-L: "New best" is derived on read from logged working sets ("Heaviest", or "Most reps" at that weight or more, 0.1 kg tolerance); the first session is the baseline; assisted, tempo, paused and drop sets never count. Nothing is stored and there's no schema change. The player shows a "New best" chip on the saved set row with one `success()` haptic instead of the usual one, and "Best 62.5 kg × 8" under Sets; the saved summary lists the top 3 bests; the share card adds one line; exercise history gets a "Best ever" card. The performance read now fills technique fields, so the existing "Heaviest working set" no longer counts assisted or segmented sets. **Owner:** feel the best-set haptic on one iPhone and one Android phone |
| Workout payoff, motion and haptics (PR-N, TP-6, TP-7) | In PR-N: the saved summary leads with "Workout complete" and one line of numbers ("1,440 kg lifted · 3 sets · 2 min 48 sec"), then one moment (the new bests, or the week goal when this workout met it), "Vs last time" per exercise ("Leg press: +2.5 kg on top set", "same as last time", "first time logged"), the week line, then the tiles ("External volume" is now "Total lifted"). The moment is celebrated once per saved workout with the existing confetti and `success()`; the session id goes into `training_bests_celebrated_v1` (last 200, not backed up) before it shows, and an achievement sheet takes the burst when one opens. New `restEnd()` haptic (two light pulses): `RestPresenceService` fires it once per rest, after the controller saves the rest's end, never on Skip; the sticky rest bar no longer adds its own `confirmation()`. Set rows tick and fill in (`fastDuration`), summary numbers count up (`completionDuration`), the week ring animates old to new; all through `B05MotionPolicy`, instant with reduce motion. **Owner:** feel the rest-end and week-goal haptics on one iPhone and one Android phone |

## Quality baseline (2026-10-03)

| Check | Result |
|:------|:-------|
| Flutter analyze | No issues |
| Flutter tests (goldens excluded) | 2,504 passed |
| Backend tests (pytest) | 73 passed |
| iOS release build | Unsigned app produced (51.3 MB) |
| Generated Drift output and code graph | Drift output is reproducible and CI checks it. The code graph is no longer committed: CI runs the architecture gate (`--ci`) and uploads the graph as an artifact. |
| AI eval (`gemini-3.8-flash`, 64 meals) | Recall 100 %, catalogue match 100 %, auto-matched 93.2 %, wrong auto-match 0 %, kcal error 3.4 %. Results: [`tool/ai_eval/results/`](../../tool/ai_eval/results/). |

## P1 status (2026-10-04)

All P1 PRs (#24–#49) are merged. Code work is done; the definition of done in [P1_REMEDIATION_PLAN.md §3](P1_REMEDIATION_PLAN.md#3-definition-of-done-all-p1s) lists what is still open:

| Item | State |
|:-----|:------|
| Crash reporting DSN | **Owner:** add the `SENTRY_DSN` secret; until then release builds hide the opt-in |
| Launch repair cost on a mid-range Android phone | **Owner** to measure (desktop: ~6 ms warm) |
| Manual device passes: truncated DB, notification Skip mid-rest | **Owner** |
| Recovery-screen support email carries the app version | Done in #52 (`package_info_plus`) |
| Single owner for the live workout (WS-D part 2, step 4) | After launch |
