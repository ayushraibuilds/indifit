# USDA dishes v1

| | |
|---|---|
| **Files** | `foods.csv` (31 dishes), built by `generate.py` from this folder's `usda_extract.json` and usda-staples-v1's |
| **URL** | USDA FoodData Central, SR Legacy (April 2018 release): https://fdc.nal.usda.gov/ (new ingredients read from the FDC API, `dataType=SR Legacy`, 2026-10-17) |
| **Licence** | Public domain (CC0 1.0). USDA asks that FoodData Central be cited. |
| **Date** | Generated 2026-10-17 |
| **Pack source id** | `usda-dishes-v1`, `review: unreviewed`, first in pack 5 |

## What it is

The catalogue gaps from the 17 Oct user-readiness search test
(`docs/audit/USER_READINESS_REVIEW_2026-10-17.md` § 3.4): Indo-Chinese, sides,
snacks, regional and festive dishes, shakes and soups, and plate combos.

Every dish is a recipe of SR Legacy ingredients, written down in
`generate.py`: raw grams for a batch, the cooked weight and the oil absorbed
in frying, scaled per 100 g (per 100 ml for drinks). Each row's `usda_basis`
repeats the recipe; `fdc_ids` lists the foods used. Carbohydrate is total
carbohydrate, fibre included, as in the rest of the catalogue.

New ingredients (`usda_extract.json`): soy sauce (174277), cornstarch
(169698), green chilli (170497), garlic (169230), coriander leaves (169997),
sweet corn (169998), whole-grain sorghum flour (168943), brown sugar
(168833), sesame oil (171016), bulgur (170688).

Stand-ins, each stated in its recipe:
- paneer: chhena by usda-staples-v1's whole-milk mass balance;
- jaggery: brown sugar; chana dal and roasted chana dal: chickpeas;
- raw mango: ripe mango; mint: coriander leaves; red chilli: green chilli;
- broken wheat (dalia): bulgur.

Salt and whole spices carry no energy; where a recipe has them, they are in
the cooked weight only.

## Left out (no honest source)

- **Ragi mudde**: no CC0/OGL value for finger millet (USDA's millet is proso).
- **Lime pickle**: no whole-lime value in the extract yet (only lemon juice).
- **Protein bar**: no generic SR Legacy food; brands differ widely.

IFCT 2017, INDB and Open Food Facts were not used for values
(NUTRITION_CATALOGUE_PACKS_PLAN.md § 3).

## Rebuild

    python3 generate.py
    python3 ../../build.py && python3 ../../validate.py
