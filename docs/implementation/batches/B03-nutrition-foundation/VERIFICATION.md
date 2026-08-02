# B03 Verification — Nutrition Foundation and Food Context

Status: Planning gates defined; execution pending B02 final Sol approval and
merge.

## Required evidence

| Gate | Evidence | Pass condition |
|:--|:--|:--|
| Contract fixtures | Canonical identity, typed quantity, nutrient completeness, estimate, conversion and constraint fixtures | Every accepted rule has a deterministic fixture, including unknown and invalid cases. |
| Recipe lifecycle | Create, edit, duplicate, save, scale and consume recipe tests | New version is immutable; historical snapshot is unchanged after edits. |
| Quantity safety | Mass/volume/count/serving/household tests and incompatible-unit rejection | No implicit dimension loss or global cooked multiplier. |
| Conversion | Directional raw/cooked and preparation-specific fixtures | Approved conversions are reproducible; unsupported conversions remain unknown. |
| Household measures | Catalogue-reviewed measure and user-vessel calibration fixtures | Food context, calibration owner, rule version and uncertainty survive round-trip. |
| Thali | Portion graph, add/remove/scale/recalculate/log/restore tests | Nutrition derives from canonical portions and one immutable consumption snapshot. |
| Nutrient semantics | Known zero, missing, not-applicable and partial-total tests | Missing is never coerced to zero; UI discloses incomplete totals. |
| Estimates | User/photo/AI/heuristic provenance and range tests | Point, lower, upper, confidence, source and rule/model version persist. |
| Protein guidance | Meal distribution and leucine-quality fixtures | Measured values and heuristics are visibly distinguished. |
| Constraints | Allergy, intolerance, religious, ethical, dislike and incomplete-composition fixtures | Types remain distinct; filtering exposes uncertainty and makes no medical-safety claim. |
| Compatibility | Existing v16 database and legacy food-log fixtures | Existing records remain readable and are not rewritten. |
| Migration | Real on-disk accepted B02 fixture through the B03 schema transition | Upgrade is transactional, preserves B02/B01 data and rolls back on injected failure. |
| Backup | v5/v6/v7 imports and new-format export/restore fixture | Older supported backups import; all B03 user-owned records round-trip; invalid references roll back. |
| Offline | Cold-start/local catalogue and calculation tests with network unavailable | Required local data supports search and calculation offline. |
| Release | Flutter analyze/tests, generated-code check, Android and iOS release builds | All supported checks pass with no new analyzer issues. |
| Sol High | Final architecture, migration, backup, uncertainty and platform review | Reviewer accepts exit criteria and records no unresolved critical risk. |

## Regression suite

Retain and rerun the B01/B02 migration, backup, history, generated-code,
platform and release suites. Add B03 tests for every new table, codec,
repository and calculator. Include a real database fixture rather than only
in-memory object tests for migration and restore.

## Manual platform matrix

Android and iOS must each verify recipe create/edit/versioning, household
measure selection, vessel calibration, thali logging, unknown nutrient display,
estimate-range display, dietary-constraint uncertainty and backup export/import.
Test compact layouts, text scaling, accessibility labels, offline mode and
locale-sensitive household labels.

## Release evidence checklist

- `flutter analyze` passes.
- Full Flutter test suite and B03 matrix pass.
- Drift/generated output is clean and reproducible.
- Android release build succeeds.
- iOS supported release build succeeds.
- Backup fixtures include previous supported versions and B03 round-trip.
- Final Sol High sign-off is recorded before any B04 implementation starts.

