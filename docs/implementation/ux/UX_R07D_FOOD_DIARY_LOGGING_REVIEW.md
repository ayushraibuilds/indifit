# R07D-1 Food Diary & Fast Logging Review

Date: 2026-08-13
Scope: Food Diary, search, fast add, multi-select logging, quantity selection, and custom foods.

## Baseline and method

- Reviewed branch `ux/r07d-food-diary-logging` at implementation commit `7063880`, with the integrated R07C baseline `687150f`.
- Read the R07D plan, B03 canonical nutrition contracts and implementation, current product references, and the available Healthify references before making changes.
- Treated B03 snapshots, serving authority, missingness, local meal/date assignment, and command idempotency as non-negotiable product constraints.

## Findings resolved

| Severity | Finding | Resolution |
| --- | --- | --- |
| High | A mass or volume fact could look like it had a safe default serving and be committed through Fast Add. | Fast Add now requires an explicit, defined, non-zero serving basis. Mass/volume facts always open quantity confirmation. |
| High | Two physical taps could enter the asynchronous fast-add path before it disabled itself. | The guard now locks before the first await and the nested control is absorbed while a command is in flight. |
| Medium | A selected historical Diary day was not carried consistently into primary logging routes. | Food Diary owns the visible day, exposes previous/next/Today controls, and passes the selected day to add, detail, and saved-recipe routes. |
| Medium | Multi-select totals could imply a numeric value when a selected fact could not be safely scaled. | Selection totals scale canonical facts and retain an em dash for unknown or unscalable values. |
| Medium | Compact layouts could make quantity actions overly dense at 320 px with 2x text. | Quantity preview and final actions reflow; actions stack into full-width controls when space or text scale requires it. |
| Medium | The custom-food editor exposed low-confidence metadata inputs that were not persisted, and made missing nutrients hard to distinguish. | The editor now follows a consumer hierarchy, removes unpersisted fields, uses an explicit serving default, and preserves optional nutrient missingness. |
| Medium | One existing quantity golden was captured during a transient animation. | The R03 capture now settles before comparison, producing a stable intentional benchmark. |

## Product decisions retained

- Search ranking and catalog coverage stay authoritative to the existing catalog; this review does not invent results or conversions.
- Food lines continue to route through B03 commands rather than direct diary mutation.
- Recent/frequent, barcode, photo/AI entry, recipe redesign, and per-line batch editing remain outside R07D-1.
- Meal detail, edit, delete, and undo retain their canonical B03 behaviour; the review exercises the entry paths rather than redesigning those flows.

## B03 canonical integrity assessment

- Food identity, frozen nutrition snapshots, provenance, and evidence-backed serving definitions are unchanged.
- Missing nutrient evidence remains missing; known zero remains a genuine zero. The UI does not manufacture totals from absent values.
- Serving conversions require explicit authority. A `100 g` or volume basis cannot masquerade as `1 serving`.
- All additions preserve the exact selected local day and meal assignment.
- Fast Add and batch add are guarded against duplicate in-flight submission; selection is cleared only after a successful batch command.

## Responsive and accessibility coverage

- Added targeted checks at 320 px / 2x text for the quantity flow and 430 px / 1.5x text for the populated Diary.
- Retained the normal 390 px benchmark for multi-select and populated Diary presentation.
- Action labels, selection state, row quantity/remove labels, and diary date navigation expose descriptive semantics.
- Controls wrap or stack where needed without changing the standard-width hierarchy.

## Visual regression coverage

- `ux_r03_food_quantity_review_dark.png` — settled quantity review benchmark.
- `ux_r07a_custom_food_light.png` — simplified custom-food hierarchy.
- `ux_r07d_multiselect_light.png` — selected rows, aggregate, and batch action.
- `ux_r07d_diary_populated_light.png` — populated meal rows and date header.
- `ux_r07d_quantity_compact_2x_light.png` — compact large-text quantity action layout.
- `ux_r07d_diary_430_1_5_light.png` — large-text Diary presentation.

## Validation

- `flutter test test/ux_r07d_food_diary_logging_test.dart --reporter compact` — 9 passed.
- R01/R03/R07A presentation suite — 40 passed.
- Relevant B03/B04/B05 canonical suite — 109 passed.
- `flutter analyze` — no issues found.
- `dart format` — clean.
- `git diff --check` — clean.
- `flutter test --concurrency=1 --reporter compact` — 1,347 passed.
- `flutter build ios --release --no-codesign` — passed; build-only validation, with no device deployment attempted.

## Review commit

Created as the scoped local R07D-1 review commit after this record was added. No merge or push is part of this review.
