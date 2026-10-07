# IndiFit catalogue v1

| | |
|---|---|
| **Files** | `assets/data/indian_foods.json` (573 rows), ids from `assets/data/nutrition_food_identity_manifest.json` |
| **URL** | In this repository (no external source) |
| **Licence** | Proprietary (IndiFit's own catalogue) |
| **Date** | Rows last changed 2026-09-24; read by `build.py` on every build |
| **Pack source id** | `indifit-catalogue-v1`, `review: unreviewed` |

## Provenance

The provenance of the values is **not recorded**: no row has a `source` field
(NUTRITION_CATALOGUE_PACKS_PLAN.md § 3). The app labels them "IndiFit
estimate" until they are checked against a reference. `spotcheck_50.csv` is
the first sample for that check.

About 312 rows are templated variants ("<dish> (<label>)", such as "Mini",
"Double serving", "Low Oil cooking") whose values are the base dish's values
times a fixed factor. Overlays tag them (`0004_variant_tags.yaml`), correct
their measures (`0002_measures_c04.yaml`) and retire the nonsense ones
(`0003_retire_c09.yaml`). No value is changed by hand; a value only changes
basis when its serving becomes grams (78 kcal in 60 g is 130 kcal per 100 g).

The file is read in place rather than copied here, because the app still
seeds legacy `food_items` from it.
