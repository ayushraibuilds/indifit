# USDA ingredients v1

| | |
|---|---|
| **Files** | `foods.csv` (5 foods), written by hand from the FDC API |
| **URL** | USDA FoodData Central, SR Legacy (April 2018 release): https://fdc.nal.usda.gov/ (read from the FDC API, `dataType=SR Legacy`, 2026-10-18) |
| **Licence** | Public domain (CC0 1.0). USDA asks that FoodData Central be cited. |
| **Date** | 2026-10-18 |
| **Pack source id** | `usda-ingredients-v1`, `review: unreviewed`, first in pack 6 |

## What it is

The ingredients "My chai" (UF-2) is computed from: sugar by the teaspoon and
milk by the millilitre. The catalogue's milks are counted per glass with no
stated volume, so nothing honest scales them to a cup of chai.

| id | Food | FDC | Note |
|---|---|---|---|
| food-usda-0301 | Sugar | 169655 Sugars, granulated | 1 tsp = 4.2 g is SR Legacy's own portion |
| food-usda-0302 | Milk (Full Cream) | 171280 Milk, indian buffalo, fluid | stand-in for 6 % full cream |
| food-usda-0303 | Milk (Toned) | 171265 Milk, whole, 3.25 % | stand-in for 3 % toned |
| food-usda-0304 | Milk (Double Toned) | 171267 Milk, reduced fat, 2 % | stand-in for 1.5 % double toned |
| food-usda-0305 | Milk (Skimmed) | 171269 Milk, nonfat, fluid | |

Values are per 100 g as published; milk is read per 100 ml taking 1 g as
1 ml, as usda-staples-v1 and usda-dishes-v1 do for drinks. Carbohydrate is by
difference; fibre is 0 for all five.
