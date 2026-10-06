# IndiFit Implementation Tracker

Last updated: 2026-10-06 (final launch audit; nutrition catalogue packs and training premium plan decided)
Current schema: v23 on `main`; v24 (`catalog_state`, bundled food pack v1) in PR-A
Current backup format: v10
Current focus: **V1 launch readiness**. Read [LAUNCH_ROADMAP_FINAL.md § 0](LAUNCH_ROADMAP_FINAL.md) first (fixed clocks, hard rules, no calendar dates). Work from [LAUNCH_ROADMAP_FINAL.md](LAUNCH_ROADMAP_FINAL.md) (fix batches PR-A…T, plans P0-1…P1-13, owner tasks, decisions). Evidence is in [FINAL_LAUNCH_AUDIT_2026-10-05.md](../audit/FINAL_LAUNCH_AUDIT_2026-10-05.md). Nutrition-data work is tracked in [NUTRITION_CATALOGUE_PACKS_PLAN.md](NUTRITION_CATALOGUE_PACKS_PLAN.md) § 0 (CAT-1…CAT-13); training and progress polish in [TRAINING_PROGRESS_PREMIUM_PLAN.md](TRAINING_PROGRESS_PREMIUM_PLAN.md) § 0 (TP-1…TP-14). The earlier plans ([P0](P0_REMEDIATION_PLAN.md), [P1](P1_REMEDIATION_PLAN.md), [audit 2026-10-01](../audit/INDEPENDENT_AUDIT_2026-10-01.md)) are kept for history.

Batches B01–B05 and the post-v1 and R07/R08 tracks are merged into `main`. Their plans and evidence are kept in `batches/`, `post-v1/`, `r08/` and `ux/` for history; they no longer describe current work.

## What ships in v1

| Area | State |
|:-----|:------|
| Training, workout player, progress | Shipping. Added for v1 (decided 2026-10-06): factual "New best" sets (PR-L), a weekly training goal instead of a daily streak (PR-M), and a summary payoff with motion and haptics (PR-N). They ship as soon as they merge ([training plan](TRAINING_PROGRESS_PREMIUM_PLAN.md)). |
| Nutrition: catalogue (base + optional regional packs), Circular Thali, diary, targets | Shipping. 38 catalogue entries (18 duplicates and 20 nonsense dairy variants) were retired on 2026-10-03; they are deprecated, not deleted, and leave search. **P0 open:** every thali logs 0 kcal for bundled foods (audit C-01). The fix is PR-A, which ships the catalogue as bundled pack v1 with one read path ([packs plan](NUTRITION_CATALOGUE_PACKS_PLAN.md) CAT-1…4). |
| Barcode lookup (Open Food Facts) | Shipping when Offline Mode is off. Uses Apple Vision on iOS. |
| AI meal tools: describe a meal, meal photo, label scan | **Shipping in v1** (decided 2026-10-05): on in release builds, off in debug unless `INDIFIT_CONNECTED_AI=true`. Uses Firebase AI Logic with App Check and needs consent. Meal photo is Beta until its eval runs. Needs Play Integrity and App Attest registered before release. |
| AI coaching wording | Not in v1 |
| Cloud backup and sync | Not in v1. Backend routes are unmounted unless `ENABLE_CLOUD_SYNC=1`. |

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
| iOS entitlements and privacy manifest; Organizer validation | Entitlements per configuration and `PrivacyInfo.xcprivacy` are present; validation needs the Apple Developer Program |
| Live Activity works on device or isn't claimed | Not claimed in v1: there is no widget-extension target, so PR-B removes `NSSupportsLiveActivities` (audit SC-08). The lock-screen rest timer comes later as TP-14 (PR-S). |
| Backend: current model, key in header, no error leakage, bounded memory, trusted proxy hops | Done |

## Quality baseline (2026-10-03)

| Check | Result |
|:------|:-------|
| Flutter analyze | No issues |
| Flutter tests (goldens excluded) | 2,504 passed |
| Backend tests (pytest) | 73 passed |
| iOS release build | Unsigned app produced (51.3 MB) |
| Generated Drift output and code graph | Reproducible; CI checks both |
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
