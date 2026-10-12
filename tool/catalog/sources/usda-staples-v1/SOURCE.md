# USDA staples v1

| | |
|---|---|
| **Files** | `foods.csv` (124 foods), built by `generate.py` from `usda_extract.json` |
| **URL** | USDA FoodData Central, SR Legacy (April 2018 release): https://fdc.nal.usda.gov/download-datasets |
| **Licence** | Public domain (CC0 1.0). USDA asks that FoodData Central be cited. |
| **Date** | Generated 2026-10-12 |
| **Pack source id** | `usda-staples-v1`, `review: unreviewed`, first in pack 3 |

## What it is

Everyday foods missing from the IndiFit catalogue, found by the food search
launch check (`docs/audit/food-search-2026-10-12/`): fruit, nuts and seeds,
sweets, breads, rice dishes, plain proteins, drinks, fast food and generic
packaged foods.

- **Single foods** (60) are SR Legacy foods as they are. Where USDA has no
  exact match, the row says which food stands in (lotus seeds for makhana,
  defatted soy flour for soya chunks, peanut brittle for chikki).
- **Dishes** (64) are recipes of SR Legacy ingredients: raw grams for a batch,
  the cooked weight and the oil absorbed in frying, scaled per 100 g. Each
  row's `usda_basis` gives the recipe; `fdc_ids` lists the foods used. Khoa and
  chhena, which USDA lacks, come from whole milk by mass balance (see
  `generate.py`).
- **Carbohydrate** is total carbohydrate, fibre included, as in the rest of the
  catalogue.

Values are per 100 g (per 100 ml for drinks). Each serving states its own
weight ("1 piece, 118 g"), marked `grams_basis: source-stated`.

## Not used for values

IFCT 2017 and Indian pack labels (Open Food Facts) may not ship in packs
(NUTRITION_CATALOGUE_PACKS_PLAN.md § 3). The IFCT-based figure from the
12 Oct review stays in `ifct_check_kcal` (kcal per serving) so a reviewer
can see where Indian foods differ: guava, papaya and pear are lower in IFCT;
Indian broiler chicken and goat are fattier.

Left out for want of a CC0 source: amla. Brand names (Maggi, Parle-G,
Kurkure, Lays, Haldiram's, Bournvita) are search aliases only.

## Rebuild

    python3 generate.py --sr <sr.json>   # refresh the extract from a full SR dump
    python3 generate.py                  # rebuild foods.csv from the extract
    python3 ../../build.py && python3 ../../validate.py
