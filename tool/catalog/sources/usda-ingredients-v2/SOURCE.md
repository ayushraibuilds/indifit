# USDA ingredients v2

| | |
|---|---|
| **Files** | `foods.csv` (1 food), written by hand from the FDC API |
| **URL** | USDA FoodData Central, SR Legacy (April 2018 release): https://fdc.nal.usda.gov/ (read from the FDC API, `dataType=SR Legacy`, 2026-10-25) |
| **Licence** | Public domain (CC0 1.0). USDA asks that FoodData Central be cited. |
| **Date** | 2026-10-25 |
| **Pack source id** | `usda-ingredients-v2`, `review: unreviewed`, first in pack 7 |

## What it is

Black tea, so "My chai" can be set to "No milk (black tea)" and a cup with
no milk and no sugar logs black tea's own facts (UF-2 follow-up).

| id | Food | FDC | Note |
|---|---|---|---|
| food-usda-0306 | Black Tea (no milk, no sugar) | 173227 Beverages, tea, black, brewed, prepared with tap water | default serving is SR Legacy's "1 cup (8 fl oz)" = 237 g |

Per 100 g as published: energy 1 kcal, protein 0.0 g, total lipid 0.0 g,
carbohydrate (by difference) 0.3 g, fibre 0.0 g. Read per 100 ml taking 1 g
as 1 ml, as usda-ingredients-v1 does for milk.

## Looked for and not added

| Food | Why not |
|---|---|
| Ragi mudde | SR Legacy's millet (168871 "Millet, cooked", 169702 "Millet, raw") is proso millet, not finger millet (ragi). No CC0 finger-millet entry; IFCT and INDB can't ship in packs. |
| Lime pickle | No SR Legacy entry; the pickles are cucumber, eggplant and relishes. |
| Protein bar | SR Legacy has only single US brands (173158 SOUTH BEACH, 174786 SNICKERS MARATHON, 173137 POWER BAR); none stands for the bars sold in India. Open Food Facts can't ship in packs. |
