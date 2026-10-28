# USDA vrat v1

| | |
|---|---|
| **Files** | `foods.csv` (8 foods), built by `generate.py` from this folder's `usda_extract.json` and the usda-staples-v1 and usda-dishes-v1 extracts |
| **URL** | USDA FoodData Central, SR Legacy (April 2018 release): https://fdc.nal.usda.gov/ (new ingredients read from the FDC API, `dataType=SR Legacy`, 2026-10-27) |
| **Licence** | Public domain (CC0 1.0). USDA asks that FoodData Central be cited. |
| **Date** | Generated 2026-10-27 |
| **Pack source id** | `usda-vrat-v1`, `review: unreviewed`, first in pack 8 |

## What it is

Vrat (fasting) foods. Kuttu atta is a single food (170687 Buckwheat flour,
whole-groat); the rest are recipes of SR Legacy ingredients written down in
`generate.py`, by the usda-dishes-v1 method: raw grams for a batch, the
cooked weight and the oil absorbed in frying, scaled per 100 g. Each row's
`usda_basis` repeats the recipe; `fdc_ids` lists the foods used.

| id | Food |
|---|---|
| food-usda-0307 | Kuttu Atta (Buckwheat Flour) |
| food-usda-0308 | Kuttu Puri |
| food-usda-0309 | Kuttu Roti |
| food-usda-0310 | Rajgira Roti |
| food-usda-0311 | Rajgira Ladoo |
| food-usda-0312 | Vrat Aloo (Sendha Namak) |
| food-usda-0313 | Shakarkandi Chaat |
| food-usda-0314 | Makhana Kheer |

New ingredients (`usda_extract.json`): buckwheat flour, whole-groat
(170687), amaranth grain, uncooked (170682), sweet potato, raw (168482).
Makhana is usda-staples-v1's dried lotus seeds (170149).

Stand-ins, each stated in its recipe: amaranth flour and popped amaranth are
taken as amaranth grain; jaggery as brown sugar; boiled sweet potato by its
raw weight. Sendha namak (rock salt), cumin and chaat masala carry no
energy; they are in the cooked weight only.

## Left out (no honest source)

- **Singhara atta (water chestnut flour)**: SR Legacy's only water chestnut
  (170066) is the Chinese water chestnut, *Eleocharis dulcis*; singhara is
  the water caltrop, *Trapa natans*.
- **Samak rice (barnyard millet)**: SR Legacy's millet (169702, 168871,
  172023) is proso millet.

IFCT 2017, INDB and Open Food Facts were not used for values
(NUTRITION_CATALOGUE_PACKS_PLAN.md § 3).

## Rebuild

    python3 generate.py
    python3 ../../build.py && python3 ../../validate.py
