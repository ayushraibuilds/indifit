# Food search launch check, 12 Oct 2026

- `queries.txt`: 144 everyday queries (category | query | text a good top result contains).
- `on_device_results.json`: top five on-device results per query before the fixes.
- `online_off_sample.txt`: Open Food Facts results for the 46 queries the phone could not answer.
- `staples_draft.csv`: 125 generic foods missing from the catalogue, for review before they go into a catalogue pack.

## Staples draft: how to read it

Values are per serving, as a first draft from standard references (IFCT 2017 and
USDA FoodData Central for single foods; typical home recipes for dishes). They
are not reviewed. Before import, each row needs:

1. The kcal and macros checked against IFCT 2017 (or USDA where IFCT has no entry),
   and the serving weight confirmed.
2. The new category names are in the app (`FoodCategoryTaxonomy.catalogueCategories`):
   Fruits (1 fruit, katori), Nuts & Seeds (handful, tbsp), Breakfast Cereals (bowl),
   Supplements (scoop); Sweets & Desserts, Rice & Rice Dishes, Western & Fast Food
   and Packaged Snacks reuse the sweet, rice and snack serving groups. Catalogue
   foods carry no category today, so names also place foods in the new groups.
3. Brand words (Maggi, Parle-G, Kurkure, Lays, Haldiram's, Bournvita) kept as
   search aliases only, never in the food's name.

Six foods were dropped from the draft because the catalogue already has them:
roasted chana, Greek yogurt, black coffee, green tea, sugarcane juice and veg hakka noodles.
