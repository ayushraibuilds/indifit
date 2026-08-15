# R07E Progress & Insights Review

## Baseline

- Branch: `ux/r07e-progress-insights`.
- Baseline commit: `e8e8ab4` (`Merge R07D-3 recipes and saved meals`).
- `main` also pointed at `e8e8ab4` at review start.
- Exact R07E implementation commit before this review: none found in `git log --all`, reflog, or dangling commits. The R07E implementation was uncommitted working-tree material on the expected branch.
- The review was performed in place. No merge, push, reset, checkout, or physical-device test was performed.

## Overall assessment

R07E now has a coherent, evidence-first Progress surface: the UI is backed by the canonical B02 execution/performance reads, the B03 nutrition read boundary, and the accepted B04 nutrition-goal history. Unsupported estimates and invented thresholds were removed, mixed-basis training volume fails closed, and sparse data remains useful without implying a trend that is not present.

## Findings resolved

- Removed the local Epley-style estimated-1RM calculation and all e1RM presentation from Progress.
- Removed the invented ±15% calorie-adherence threshold.
- Resolved nutrition targets independently for each historical local date instead of applying today’s target to the whole week.
- Counted calorie and protein evidence only from complete, non-estimated `known` or `knownZero` B03 facts; the UI reports the evidence denominator.
- Added one range-oriented B03 daily-total read so the dashboard does not repeatedly scan the full history for each day.
- Made canonical workout volume strict: only complete, explicit `totalExternal` load facts contribute; mixed, segmented, bodyweight, per-side, per-implement, malformed, or incomplete volume is hidden rather than guessed.
- Kept performed strength history keyed by stable exercise identity and made comparisons deterministic, same-rep, same-basis, and cross-session.
- Routed Progress strength history to the existing canonical stable-ID exercise history screen and routed both Progress and Training workout history to the shared B02 compatibility history screen.
- Aligned “this week” with Monday-through-today rather than a rolling seven-day window.
- Updated the affected R04/R05 regression expectations and goldens for the shared reviewed UI.

## Progress information architecture

The page order is Overview → Training consistency → Strength → Weight → Nutrition, followed by supporting muscle-balance and body-measurement information when evidence exists. Each section can remain visible when another section is unavailable; the page only falls back to the global retry state when the primary read has no usable facts.

## Overview

Overview metrics use stored workout, strength, weight, and nutrition evidence. Empty and partially available states explain the next useful action without showing fabricated zeros, targets, or trend claims.

## Training consistency

The weekly rail uses the canonical local Monday-through-Sunday week and marks trained days from canonical activity. Shared workout history distinguishes canonical activity from earlier legacy history rather than presenting both as one ambiguous source.

## Strength progress

Strength cards use actual performed sets grouped by stable exercise ID. The current highlight is the latest session’s heaviest comparable external set, with deterministic time/session/set ordering. History opens through the canonical exercise-performance read path using the stable exercise ID.

## Estimated 1RM authority

R07E does not calculate or display e1RM. B02-D06 keeps assistance separate and does not authorize net-resistance or assisted e1RM inference; R07E therefore reports performed load only. A future estimated-1RM feature needs a separately accepted B02 authority and evidence contract.

## Best-set / comparison semantics

“Best” means the heaviest recorded performed set when a comparable `totalExternal` basis exists; otherwise the latest performed set remains descriptive. Comparisons require the same stable exercise, the same reps, `totalExternal` for both sides, and distinct sessions. The UI says “vs previous session” and never mixes per-side, per-implement, bodyweight, or assisted semantics into an external-load comparison.

## Workout / Volume integrity

Workout summaries read canonical B02 activity/performance facts. Volume is accumulated only from complete actual load and rep facts with `totalExternal` basis. If a session contains an incompatible or incomplete attempted load fact, the session’s volume is marked untrustworthy and is excluded from volume totals while the available performed-set history remains visible.

## Body / Weight

Weight and body measurements use persisted observations, deterministic ordering, same-day presentation deduplication, and explicit sparse-data behavior: one observation is summary-only, two are a comparison, and three or more unlock the chart. The current weight goal remains the existing persisted onboarding compatibility setting because no typed B04 body-target read model was present; it is shown as a user weight reference, not as a nutrition-derived or calculated target.

## Nutrition adherence

Nutrition uses `NutritionReadModelRepository` for canonical logs, recipe/saved-meal snapshots, corrections, and retractions. Daily facts are displayed only when the B03 fact is complete and authoritative. Historical B04 nutrition goals are resolved for each local date. Adherence labels identify complete evidence days, for example “4 of 5 complete days met protein,” and do not imply calorie adherence from an arbitrary tolerance band.

## Sparse-data behavior

Zero data gives one useful starting state. One or two measurements stay summary-only. Three or more measurements enable the chart. Missing or incomplete nutrition facts are labeled as incomplete and do not become zero intake. A section-level read failure leaves other valid sections available and offers a scoped retry.

## Charts

Weight charts use actual local-day observations without interpolation. Period selectors appear only when an older range adds evidence. Chart semantics include the selected observation, dates, comparison, and goal context so the chart is not the sole carrier of meaning.

## Cross-domain failure isolation

Progress reads are isolated by section. A secondary workout, nutrition, muscle, or measurement failure does not erase valid data from other sections. Nutrition range failures surface as unavailable nutrition evidence rather than silently becoming an empty week; incomplete B03 facts remain explicitly incomplete.

## Recipe / Saved Meal nutrition integration

Recipes and saved meals remain upstream B03 inputs. Progress does not duplicate their nutrition calculations; it consumes the unified B03 read boundary, including canonical snapshot lineage and correction/retraction resolution. This keeps a recipe or saved-meal correction consistent with the rest of the food diary.

## Visual hierarchy / density

The page leads with the user’s current state and next useful action, keeps section titles and primary metrics distinct, and uses compact secondary actions for history/logging. Dense content is grouped in surfaces with consistent spacing rather than competing KPI tiles.

## Responsive / Accessibility

The reviewed states cover 320-point width, standard and 2x text, dark and light themes, sparse and populated data, and nutrition/strength/training variants. Meaningful charts and icons have semantic summaries; incomplete states use text and icon affordances rather than color alone. Focused widget tests assert no layout exceptions.

## B02 Integrity

Progress consumes canonical execution/performance contracts, exact stable exercise IDs, actual performed values, and explicit load basis. Legacy history remains distinguishable. No assisted/net-resistance/e1RM inference is introduced, and incompatible volume is fail-closed.

## B03 Integrity

Nutrition reads use the unified read model, resolve correction/retraction lineage, preserve `known`/`knownZero`/incomplete status, and support a single requested-date range read. Estimated or coverage-incomplete facts are excluded from evidence-day metrics.

## B04 Integrity

Historical nutrition targets are resolved through `activeGoalForPrimaryProfile` for each local date and timezone. No untyped body-target source was invented; the existing onboarding compatibility weight setting is documented and kept separate from nutrition-target authority.

## Goldens

R07E goldens added or reviewed:

- `test/goldens/ux_r07e_progress_zero_dark.png`
- `test/goldens/ux_r07e_progress_zero_light.png`
- `test/goldens/ux_r07e_progress_one_measurement_dark.png`
- `test/goldens/ux_r07e_progress_weight_chart_dark.png`
- `test/goldens/ux_r07e_progress_populated_dark.png`
- `test/goldens/ux_r07e_progress_populated_light.png`
- `test/goldens/ux_r07e_progress_320_dark.png`
- `test/goldens/ux_r07e_progress_2x_dark.png`
- `test/goldens/ux_r07e_progress_strength_dark.png`
- `test/goldens/ux_r07e_progress_training_dark.png`
- `test/goldens/ux_r07e_progress_nutrition_dark.png`

Shared regression goldens updated for the reviewed Progress/Training composition:

- `test/goldens/ux_r04_training_landing_dark.png`
- `test/goldens/ux_r04_training_landing_light.png`
- `test/goldens/ux_r05_progress_320_dark.png`
- `test/goldens/ux_r05_progress_populated_dark.png`
- `test/goldens/ux_r05_progress_populated_light.png`
- `test/goldens/ux_r05_progress_strength_dark.png`
- `test/goldens/ux_r05_weight_chart_dark.png`

## Tests

- Focused R07E/B02 and compatibility regression command: `flutter test test/progress_dashboard_read_repository_test.dart test/ux_r07e_progress_insights_test.dart test/ux_r05_progress_test.dart test/ux_r04_training_test.dart --reporter compact` — 58 passed.
- Full serial suite: `flutter test --reporter compact` — 1,389 passed, exit code 0. The suite emits expected captured-error and platform-plugin warning logs from existing failure-path tests; no test failed.
- Range reproducibility and mixed-load-basis regression coverage is included in `test/b03_history_reproducibility_test.dart` and `test/progress_dashboard_read_repository_test.dart`.

## Analyze / Format / Diff

- `dart format --output=none --set-exit-if-changed` on all changed R07E Dart files — clean.
- `flutter analyze` — `No issues found!`.
- `git diff --check` — clean.

## iOS Release Build

Exact command:

`flutter build ios --release --no-codesign --dart-define=INDIFIT_API_KEY=test_key`

Result: passed; built `build/ios/iphoneos/Runner.app` (59.8 MB). Codesigning was disabled as requested. Xcode reported the existing simulator-only arm64 caveat for transitive Google ML Kit targets, but the iphoneos device release build completed successfully. No physical device testing was performed.

## Deferred to R07F+

- A separately governed e1RM/estimated-strength authority, if product requirements add one.
- Readiness, recovery, training-load scores, PR badges, and richer coaching insights.
- A typed B04 body-target/body-composition read model, body-fat trend, and composition goals.
- More advanced chart annotations, segmented-load volume decomposition, and richer muscle-balance comparisons.
- Broader achievement history and cross-domain insight narratives.

## Files Changed

R07E implementation, review, tests, and visual evidence committed:

- `docs/implementation/ux/UX_R07E_PROGRESS_INSIGHTS_PLAN.md`
- `lib/data/models/progress_dashboard_models.dart`
- `lib/data/repositories/nutrition_read_model_repository.dart`
- `lib/data/repositories/progress_dashboard_read_repository.dart`
- `lib/features/progress/progress_dashboard_controller.dart`
- `lib/features/progress/progress_screen.dart`
- `lib/features/training/training_screen.dart`
- `lib/features/training/workout_history_screen.dart`
- `test/b03_history_reproducibility_test.dart`
- `test/progress_dashboard_read_repository_test.dart`
- `test/ux_r05_progress_test.dart`
- `test/ux_r07e_progress_insights_test.dart`
- R07E goldens listed above and the affected R04/R05 compatibility goldens.

Unrelated dirty changes were intentionally preserved and are not part of this review commit, including the UI reference material, old-dashboard deletions, `ios/Flutter/Release.xcconfig`, R07D test/golden edits, and `test/failures/`.

## Review Commit

`6260381` (`review(r07e): resolve progress insights findings`)

## Verdict

Ready to merge R07E
