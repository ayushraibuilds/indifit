#!/usr/bin/env python3
"""Generates foods.csv for the usda-dishes-v1 catalogue source (pack 5).

The dishes of the 17 Oct user-readiness review (§ 3.4) that have an honest
source: recipes of USDA FoodData Central SR Legacy ingredients (public domain,
CC0), the method of usda-staples-v1. IFCT 2017, INDB and Open Food Facts are
not used for values (NUTRITION_CATALOGUE_PACKS_PLAN § 3).

Ingredients come from two extracts: usda-staples-v1's (the pack 3 ones) and
this folder's usda_extract.json (the ten new ones, fetched from the FDC API on
2026-10-17; carbs_g there is available carbohydrate, total minus fibre, as in
the staples extract).

    python3 generate.py   # rebuild foods.csv
"""

import csv
import importlib.util
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
STAPLES = HERE.parent / "usda-staples-v1"
OUT = HERE / "foods.csv"
FIRST_ID = 201

_spec = importlib.util.spec_from_file_location("staples", STAPLES / "generate.py")
staples = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(staples)
KEYS = staples.KEYS

ING = {
    **staples.ING,
    "soy_sauce": "174277", "cornflour": "169698", "green_chilli": "170497",
    "garlic": "169230", "coriander": "169997", "sweet_corn": "169998",
    "jowar": "168943", "jaggery": "168833", "sesame_oil": "171016",
    "bulgur": "170688", "banana": "173944", "mango": "169910",
}

# Where an ingredient stands in for another, the recipe note says so.
# name: (hindi, category, aliases, unit, amount, serving grams,
#        [(ingredient, raw g)], cooked batch g, note)
DISHES = [
    # Indo-Chinese
    ("Chilli Paneer", "चिली पनीर", "Snacks & Street Food", "chili paneer|paneer chilli|chilli paneer dry", "katori", 1, 150,
     [("paneer", 200), ("cornflour", 20), ("maida", 10), ("oil", 25), ("capsicum", 60), ("onion", 60), ("soy_sauce", 15), ("garlic", 8), ("green_chilli", 5)], 380,
     "paneer by the chhena mass balance; 25 g oil for frying and tossing"),
    ("Veg Manchurian", "वेज मंचूरियन", "Snacks & Street Food", "manchurian|veg manchurian gravy|vegetable manchurian", "katori", 1, 150,
     [("cabbage", 150), ("carrot", 50), ("maida", 30), ("cornflour", 25), ("oil", 30), ("onion", 30), ("capsicum", 20), ("garlic", 8), ("soy_sauce", 15)], 420,
     "fried vegetable balls (25 g oil absorbed) in a cornflour gravy"),
    ("Chicken Manchurian", "चिकन मंचूरियन", "Non-Veg", "chicken manchurian gravy", "katori", 1, 150,
     [("chicken_thigh", 250), ("cornflour", 25), ("maida", 15), ("egg", 25), ("oil", 30), ("onion", 40), ("capsicum", 30), ("garlic", 8), ("soy_sauce", 15)], 420,
     "battered, fried chicken in a cornflour gravy"),
    ("Chilli Chicken", "चिली चिकन", "Non-Veg", "chili chicken|hakka chilli chicken|chilli chicken dry", "katori", 1, 150,
     [("chicken_thigh", 250), ("cornflour", 25), ("maida", 10), ("egg", 25), ("oil", 30), ("capsicum", 60), ("onion", 60), ("garlic", 8), ("green_chilli", 8), ("soy_sauce", 15)], 400,
     "battered, fried chicken tossed with peppers"),
    ("Schezwan Fried Rice", "शेज़वान फ्राइड राइस", "Rice & Rice Dishes", "szechuan fried rice|schezwan rice|shezwan fried rice", "plate", 1, 380,
     [("rice", 80), ("oil", 18), ("carrot", 30), ("cabbage", 30), ("capsicum", 20), ("onion", 20), ("garlic", 6), ("green_chilli", 8), ("soy_sauce", 8)], 380,
     "veg fried rice with a chilli-garlic sauce; red chilli taken as green chilli"),
    ("Egg Fried Rice", "एग फ्राइड राइस", "Rice & Rice Dishes", "egg rice|anda fried rice", "plate", 1, 390,
     [("rice", 80), ("egg", 100), ("oil", 15), ("onion", 20), ("cabbage", 20), ("carrot", 20), ("soy_sauce", 6)], 390,
     "2 eggs"),
    # Sides
    ("Papad (Roasted)", "पापड़", "Snacks & Street Food", "papad|papadum|poppadom|appalam|roasted papad", "piece", 1, 12,
     [("urad", 12)], 12, "urad flour dough, dried; salt carries no energy"),
    ("Papad (Fried)", "तला पापड़", "Snacks & Street Food", "fried papad|tala papad", "piece", 1, 15,
     [("urad", 12), ("oil", 3)], 15, "3 g oil absorbed in frying"),
    ("Mango Pickle (Achar)", "आम का अचार", "Snacks & Street Food", "achar|aam ka achar|mango achar|pickle|aachar", "tbsp", 1, 15,
     [("mango", 100), ("mustard_oil", 30)], 145, "raw mango taken as ripe mango; 15 g salt and spices, no energy"),
    ("Coconut Chutney", "नारियल चटनी", "Snacks & Street Food", "nariyal chutney|thengai chutney", "tbsp", 2, 30,
     [("coconut", 100), ("chickpeas", 20), ("green_chilli", 5), ("oil", 5)], 205,
     "roasted chana dal taken as chickpeas; ground with 75 g water"),
    ("Green Chutney", "हरी चटनी", "Snacks & Street Food", "hari chutney|pudina chutney|dhaniya chutney|mint chutney|coriander chutney", "tbsp", 1, 15,
     [("coriander", 75), ("green_chilli", 5), ("lemon_juice", 10)], 110,
     "coriander and mint, mint taken as coriander leaves; ground with 20 g water"),
    ("Onion Salad (Laccha)", "प्याज़ सलाद", "Healthy & Salads", "laccha pyaz|pyaz salad|onion salad|kanda salad", "serving", 1, 50,
     [("onion", 100), ("lemon_juice", 10)], 110, ""),
    # Snacks
    ("Khakhra", "खाखरा", "Snacks & Street Food", "khakra|methi khakhra", "piece", 1, 20,
     [("atta", 100), ("oil", 10)], 105, "roasted dry"),
    ("Chakli (Murukku)", "चकली", "Snacks & Street Food", "murukku|chakri|chakkuli", "piece", 1, 15,
     [("rice_flour", 100), ("urad", 25), ("butter", 10), ("oil", 30)], 170, "30 g oil absorbed in frying"),
    ("Mathri", "मठरी", "Snacks & Street Food", "mathiya|mathi|matri", "piece", 1, 18,
     [("maida", 100), ("ghee", 25), ("oil", 20)], 150, "8 pieces; 20 g oil absorbed in frying"),
    ("Dahi Bhalla", "दही भल्ला", "Snacks & Street Food", "dahi vada|dahi bhalle|dahi vade|dahi wada", "plate", 1, 165,
     [("urad", 50), ("oil", 15), ("curd", 200), ("sugar", 10)], 330, "4 fried vadas (15 g oil absorbed) in sweetened curd"),
    ("Sabudana Vada", "साबूदाना वड़ा", "Snacks & Street Food", "sago vada|sabudana wada", "piece", 1, 50,
     [("sago", 60), ("potato", 100), ("peanut", 20), ("oil", 25)], 200, "4 vadas; 25 g oil absorbed in frying"),
    ("Besan Chilla", "बेसन चीला", "Grains & Breads", "besan cheela|chilla|cheela|pudla|besan ka chilla", "piece", 1, 80,
     [("besan", 50), ("onion", 20), ("tomato", 20), ("green_chilli", 3), ("coriander", 5), ("oil", 6)], 160, "2 chillas"),
    # Regional and festive
    ("Puliyogare (Tamarind Rice)", "पुलियोगरे", "Rice & Rice Dishes", "puliyogare|tamarind rice|puli sadam|pulihora|puliodarai", "katori", 1, 150,
     [("rice", 60), ("tamarind", 15), ("sesame_oil", 12), ("peanut", 10), ("jaggery", 5)], 220, "jaggery taken as brown sugar"),
    ("Modak (Steamed)", "मोदक", "Sweets & Desserts", "ukadiche modak|modak", "piece", 1, 34,
     [("rice_flour", 100), ("ghee", 5), ("coconut", 100), ("jaggery", 60)], 340, "10 modaks; jaggery taken as brown sugar"),
    ("Soan Papdi", "सोन पापड़ी", "Sweets & Desserts", "son papdi|patisa|soan papri", "piece", 1, 25,
     [("besan", 50), ("maida", 50), ("ghee", 60), ("sugar", 120)], 270, ""),
    ("Puran Poli", "पूरन पोली", "Sweets & Desserts", "holige|obbattu|puranpoli", "piece", 1, 75,
     [("chickpeas", 100), ("jaggery", 100), ("maida", 100), ("oil", 10), ("ghee", 20)], 450,
     "6 polis; chana dal taken as chickpeas, jaggery as brown sugar"),
    # Drinks and soups
    ("Banana Shake", "केला शेक", "Beverages", "banana milkshake|kela shake", "ml", 300, None,
     [("banana", 120), ("milk", 200), ("sugar", 10)], 330, "1 glass"),
    ("Mango Shake", "मैंगो शेक", "Beverages", "mango milkshake|aam shake", "ml", 300, None,
     [("mango", 120), ("milk", 200), ("sugar", 15)], 335, "1 glass"),
    ("Tomato Soup", "टमाटर सूप", "Soups & Beverages", "tamatar soup|cream of tomato", "ml", 200, None,
     [("tomato", 300), ("butter", 8), ("cornflour", 8), ("sugar", 5), ("onion", 20)], 400, "simmered with water and strained"),
    ("Sweet Corn Soup", "स्वीट कॉर्न सूप", "Soups & Beverages", "corn soup|veg sweet corn soup", "ml", 200, None,
     [("sweet_corn", 80), ("cornflour", 10), ("carrot", 15), ("cabbage", 15), ("oil", 5), ("sugar", 3)], 400, "made with water"),
    ("Vegetable Dalia", "वेज दलिया", "Grains & Breads", "dalia|daliya|namkeen dalia|broken wheat upma|veg daliya", "katori", 1, 150,
     [("bulgur", 50), ("peas", 20), ("carrot", 20), ("onion", 15), ("oil", 5)], 300, "broken wheat taken as bulgur"),
    ("Sweet Dalia (with Milk)", "मीठा दलिया", "Grains & Breads", "meetha dalia|dalia with milk|doodh dalia", "katori", 1, 150,
     [("bulgur", 40), ("milk", 200), ("sugar", 15)], 300, "broken wheat taken as bulgur"),
    # Combos
    ("Chole Bhature", "छोले भटूरे", "Snacks & Street Food", "chole bhatura|chhole bhature|chola bhatura", "plate", 1, 300,
     [("chickpeas", 40), ("onion", 20), ("tomato", 30), ("oil", 8), ("maida", 90), ("curd", 20), ("oil", 25)], 300,
     "1 katori chole and 2 bhature (25 g oil in dough and frying)"),
    ("Puri Bhaji", "पूरी भाजी", "Grains & Breads", "poori bhaji|puri sabzi|poori aloo|puri aloo", "plate", 1, 228,
     [("atta", 60), ("oil", 18), ("potato", 130), ("onion", 15), ("tomato", 10), ("oil", 8)], 228,
     "3 puris and 1 katori aloo bhaji"),
    ("Kadhi Chawal", "कढ़ी चावल", "Rice & Rice Dishes", "kadhi rice|kadi chawal", "plate", 1, 300,
     [("curd", 100), ("besan", 15), ("oil", 6), ("rice", 50)], 300, "1 katori kadhi and 1 katori rice"),
]

# § 3.4 foods with no honest source: left out of the pack.
EXCLUDED = {
    "Ragi Mudde": "no CC0/OGL value for finger millet (USDA's millet is proso)",
    "Lime Pickle": "no whole-lime value in the extract (only lemon juice)",
    "Protein Bar": "no generic SR Legacy food; brands differ widely",
}


def main():
    sr = {}
    for path in (STAPLES / "usda_extract.json", HERE / "usda_extract.json"):
        for k, v in json.loads(path.read_text()).items():
            sr[k] = {**v, **{key: float(v[key]) for key in KEYS}}

    def ing(name):
        if name == "paneer":
            return staples.derived("chhena", sr)
        return sr[ING[name]]

    out = []
    for i, (name, hindi, category, aliases, unit, amount, grams, ings, cooked, note) in enumerate(DISHES):
        tot = {k: sum(ing(n)[k] * g / 100 for n, g in ings) for k in KEYS}
        per100 = {k: tot[k] * 100 / cooked for k in KEYS}
        merged = {}
        for n, g in ings:
            merged[n] = merged.get(n, 0) + g
        basis = "recipe: " + "; ".join(f"{n} {g:g} g" for n, g in merged.items())
        basis += f"; cooked {cooked:g} g" + (f" ({note})" if note else "")
        fdc = sorted({ING[n] for n in merged if ING.get(n)} | ({ING["milk"]} if "paneer" in merged else set()))
        out.append({
            "id": f"food-usda-{FIRST_ID + i:04d}",
            "name": name,
            "name_hindi": hindi,
            "category": category,
            "basis": "per_100_millilitres" if unit == "ml" else "per_100_grams",
            "serving_unit": unit,
            "serving_amount": f"{amount:g}",
            "serving_grams": "" if grams is None else f"{grams:g}",
            # Total carbohydrate, fibre included, as in the rest of the catalogue.
            **{k: f"{per100[k] + (per100['fibre_g'] if k == 'carbs_g' else 0):.2f}" for k in KEYS},
            "aliases": aliases,
            "usda_basis": basis,
            "fdc_ids": " ".join(fdc),
        })
    with OUT.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(out[0]))
        w.writeheader()
        w.writerows(out)
    print(f"{len(out)} dishes -> {OUT.relative_to(ROOT)}; excluded {sorted(EXCLUDED)}")


if __name__ == "__main__":
    main()
