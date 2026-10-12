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

## Recipe calculations (12 Oct)

The 98 rows without an IFCT entry now have values from one of three sources,
named in each row's `source` and `status`:

| Status | Rows | How |
|---|---|---|
| calculated (IFCT recipe) | 62 | Raw IFCT 2017 ingredients for a batch, the cooked batch weight and any frying oil absorbed, scaled to the serving. Recipe and assumptions are in `source`. |
| label (Indian pack) | 27 | The Indian product on Open Food Facts nearest the median energy of its group, after dropping labels whose energy does not match their macros. Product and barcode in `source`. |
| USDA (not in IFCT 2017) | 8 | USDA SR Legacy, carbohydrate converted to available (total minus fibre): kiwi, chia, pumpkin seeds, butter, mozzarella, firm tofu, popcorn, multigrain bread. |

Ingredients IFCT lacks come from USDA: sugar, cream, mayonnaise, sago, ketchup,
cornflour. Curd is taken as the cow milk it sets from; chhena as IFCT paneer;
hung curd as curd strained to half its weight. Oils and ghee are 9 kcal per g.
Spices under 2 g a serving are left out.

`method/recipes.py` reproduces the numbers (`python3 recipes.py <dir with
IFCT comp.csv> staples_draft.csv`), with `labels.json` and `usda.json` as its
inputs. The IFCT table itself is not copied here: get `compositions/index.csv` from
github.com/ifct2017/compositions.

Largest changes from the first draft, and why:

- Cooked chicken breast 165 → 224 kcal per 100 g: IFCT's raw Indian broiler breast
  has 9% fat, against USDA's 3.6%.
- Moong sprouts 31 → 117 kcal a cup: the draft used watery Chinese bean sprouts;
  Indian sprouts are 40 g dry moong grown to about 104 g.
- Tofu 76 → 144: firm tofu, not silken.
- Badam milk, oats porridge and kheer rose 40–50%: the draft under-counted
  whole milk and sugar.
- Chicken momos and shawarma rose by a third: Indian chicken thigh is fatty and
  shawarma carries 20 g of mayonnaise.

Still open before import:

- Recipes are typical home or street versions. A reviewer should confirm the
  portions (for example 8 g of flour per momo wrapper, 15% oil in fries).
- Jamun uses IFCT E013 "Black berry", which lists jamun's local names but the
  Latin name Rubus sp. It is marked low confidence.
- Makhana (Roasted) is a packaged, oil-roasted product (154 kcal a cup). Plain
  dry-roasted makhana would be about a third lower and has no Indian source here.
- Chikoo keeps IFCT's published energy (73 kcal a serving) though its macros add
  up to about 90 kcal; IFCT's figure stands.
- The catalogue should state that carbohydrate means available carbohydrate.

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
