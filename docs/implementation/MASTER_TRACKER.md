# IndiFit Implementation Tracker

Last updated: 2026-10-04 (after PR #49)
Current schema: v23
Current backup format: v10
Current focus: **V1 launch readiness** — see [P0_REMEDIATION_PLAN.md](P0_REMEDIATION_PLAN.md) (WS1–WS7), [P1_REMEDIATION_PLAN.md](P1_REMEDIATION_PLAN.md) and the audit in [docs/audit/INDEPENDENT_AUDIT_2026-10-01.md](../audit/INDEPENDENT_AUDIT_2026-10-01.md).

Batches B01–B05 and the post-v1 and R07/R08 tracks are merged into `main`. Their plans and evidence are kept in `batches/`, `post-v1/`, `r08/` and `ux/` for history; they no longer describe current work.

## What ships in v1

| Area | State |
|:-----|:------|
| Training, workout player, progress | Shipping |
| Nutrition: catalogue (base + optional regional packs), Circular Thali, diary, targets | Shipping. 38 catalogue entries (18 duplicates and 20 nonsense dairy variants) were retired on 2026-10-03; they are deprecated, not deleted, and leave search. |
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
| Live Activity works on device or isn't claimed | **Owner** to verify on an iPhone |
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
| Recovery-screen support email carries the app version | Not done: needs a version source such as `package_info_plus` |
| Single owner for the live workout (WS-D part 2, step 4) | After launch |
