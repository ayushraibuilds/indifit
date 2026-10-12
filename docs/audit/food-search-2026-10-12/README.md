# Food search launch check, 12 Oct 2026

- `queries.txt`: 144 everyday queries (category | query | text a good top result contains).
- `on_device_results.json`: top five on-device results per query before the fixes.
- `online_off_sample.txt`: Open Food Facts results for the 46 queries the phone could not answer.
- `staples_draft.csv`: 125 generic foods missing from the catalogue, for review before they go into a catalogue pack.

## IFCT 2017 check (12 Oct)

Checked against the IFCT 2017 composition table (machine-readable copy at
github.com/ifct2017/compositions, per 100 g edible portion, energy in kJ
converted at 4.184 kJ/kcal). IFCT covers 542 raw foods, so only 27 of the 125
rows have an entry: the fruits, nuts and seeds, coconut, and boiled egg and egg
white. Those rows now carry IFCT values scaled to the serving and an IFCT code
in `source`. Every row has a `status`.

What changed and why:

- Carbohydrate is IFCT's available carbohydrate (fibre excluded); the first
  draft used USDA total carbohydrate. Fruit carbs fell by a third to a half.
- Indian fruit varieties measure lower in energy than the USDA ones: papaya 62 → 35 kcal
  a cup, guava 37 → 18, pear 101 → 67. Banana and apple went up (105 → 124,
  95 → 114).
- IFCT fibre is higher for most fruit (pear 5.5 → 8.0 g, pineapple 2.3 → 5.7 g).
- Nuts and seeds kept their energy within 15%; their carbs fell for the same
  reason.

Still to do before import:

- 97 rows have no IFCT entry: cooked dishes, sweets, breads, cereals, packaged
  foods, cooked meats and drinks. They need a recipe calculation from IFCT
  ingredients (with cooking yields) or the pack label. Until then they are
  estimates.
- Jamun is unmatched: IFCT's "Black berry" and "Jambu fruit" names are unclear.
- Kiwi is not in IFCT; its row is a USDA estimate.
- Cooked chicken breast is a USDA value (31 g protein, 3.6 g fat per 100 g).
  IFCT's raw Indian chicken breast has 21.8 g protein and 9 g fat per 100 g, so
  a recipe calculation from IFCT may land well above the draft's fat.
- The app's nutrient registry does not say whether "carbohydrate" means total
  or available. The catalogue should say so, and use one throughout.

## Staples draft: how to read it

Values are per serving. Rows marked `verified (IFCT)` use IFCT 2017; the rest
are first-draft estimates (USDA FoodData Central, typical home recipes). Before
import, each row needs:

1. The kcal and macros confirmed (see the IFCT check above), and the serving
   weight confirmed.
2. The new category names are in the app (`FoodCategoryTaxonomy.catalogueCategories`):
   Fruits (1 fruit, katori), Nuts & Seeds (handful, tbsp), Breakfast Cereals (bowl),
   Supplements (scoop); Sweets & Desserts, Rice & Rice Dishes, Western & Fast Food
   and Packaged Snacks reuse the sweet, rice and snack serving groups. Catalogue
   foods carry no category today, so names also place foods in the new groups.
3. Brand words (Maggi, Parle-G, Kurkure, Lays, Haldiram's, Bournvita) kept as
   search aliases only, never in the food's name.

Six foods were dropped from the draft because the catalogue already has them:
roasted chana, Greek yogurt, black coffee, green tea, sugarcane juice and veg hakka noodles.
