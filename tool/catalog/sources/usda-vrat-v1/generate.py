#!/usr/bin/env python3
"""Generates foods.csv for the usda-vrat-v1 catalogue source (pack 8).

Vrat (fasting) foods with an honest source: buckwheat flour as a single food
and recipes of USDA FoodData Central SR Legacy ingredients (public domain,
CC0), the method of usda-dishes-v1. IFCT 2017, INDB and Open Food Facts are
not used for values (NUTRITION_CATALOGUE_PACKS_PLAN § 3).

Ingredients come from three extracts: usda-staples-v1's, usda-dishes-v1's
and this folder's usda_extract.json (buckwheat flour, amaranth grain and
sweet potato, fetched from the FDC API on 2026-10-27; carbs_g there is
available carbohydrate, total minus fibre, as in the other extracts).

    python3 generate.py   # rebuild foods.csv
"""

import csv
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
STAPLES = HERE.parent / "usda-staples-v1"
DISHES_DIR = HERE.parent / "usda-dishes-v1"
OUT = HERE / "foods.csv"
FIRST_ID = 307


def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


staples = _load("staples", STAPLES / "generate.py")
dishes = _load("dishes", DISHES_DIR / "generate.py")
KEYS = staples.KEYS

ING = {
    **dishes.ING,
    "buckwheat_flour": "170687", "amaranth": "170682", "sweet_potato": "168482",
    "makhana": "170149",
}

# Single foods: name -> (hindi, category, aliases, unit, amount, serving g, fdc id).
SINGLE = {
    "Kuttu Atta (Buckwheat Flour)": ("कुट्टू का आटा", "Grains & Breads", "kuttu atta|kuttu ka atta|buckwheat flour|kuttu flour", "g", 50, 50, "170687"),
}

# Where an ingredient stands in for another, the recipe note says so. Sendha
# namak (rock salt), cumin and chaat masala carry no energy; where a recipe
# has them, they are in the cooked weight only.
# name: (hindi, category, aliases, unit, amount, serving grams,
#        [(ingredient, raw g)], cooked batch g, note)
RECIPES = [
    ("Kuttu Puri", "कुट्टू की पूरी", "Grains & Breads", "kuttu poori|kuttu ki puri|buckwheat puri|vrat puri", "piece", 1, 25,
     [("buckwheat_flour", 100), ("potato", 50), ("oil", 30)], 175,
     "boiled potato binds the dough; 5 g oil in dough, 25 g absorbed in frying"),
    ("Kuttu Roti", "कुट्टू की रोटी", "Grains & Breads", "kuttu ki roti|buckwheat roti|vrat roti", "piece", 1, 45,
     [("buckwheat_flour", 100), ("potato", 40), ("ghee", 5)], 180,
     "4 rotis; boiled potato binds the dough; ghee on the tawa"),
    ("Rajgira Roti", "राजगिरा रोटी", "Grains & Breads", "rajgira ki roti|amaranth roti|ramdana roti", "piece", 1, 45,
     [("amaranth", 100), ("potato", 40), ("ghee", 5)], 180,
     "4 rotis; amaranth flour taken as amaranth grain; boiled potato binds the dough"),
    ("Rajgira Ladoo", "राजगिरा लड्डू", "Sweets & Desserts", "rajgira laddu|ramdana ladoo|amaranth ladoo", "piece", 1, 25,
     [("amaranth", 100), ("jaggery", 70), ("ghee", 10)], 175,
     "popped amaranth taken as amaranth grain; jaggery taken as brown sugar"),
    ("Vrat Aloo (Sendha Namak)", "व्रत के आलू", "Vegetables & Sabjis", "vrat ke aloo|vrat aloo|upvas batata bhaji|farali aloo", "katori", 1, 150,
     [("potato", 400), ("ghee", 15), ("peanut", 20), ("green_chilli", 5), ("coriander", 5)], 420,
     "boiled potatoes tossed in ghee with cumin, crushed peanuts and sendha namak"),
    ("Shakarkandi Chaat", "शकरकंदी चाट", "Snacks & Street Food", "sweet potato chaat|shakarkand chaat|vrat chaat", "katori", 1, 150,
     [("sweet_potato", 300), ("lemon_juice", 15)], 300,
     "boiled sweet potato with lemon, chaat masala and sendha namak; boiled weight taken as raw"),
    ("Makhana Kheer", "मखाना खीर", "Sweets & Desserts", "makhane ki kheer|phool makhana kheer|lotus seed kheer", "katori", 1, 150,
     [("milk", 1000), ("makhana", 40), ("sugar", 70)], 600,
     "milk reduced to 600 g with makhana, as Kheer"),
]

# Asked for in the vrat brief and left out of the pack: no honest source.
EXCLUDED = {
    "Singhara Atta (Water Chestnut Flour)": "SR Legacy's only water chestnut (170066) is the Chinese water chestnut, Eleocharis dulcis; singhara is the water caltrop, Trapa natans. No CC0/OGL entry for it.",
    "Samak Rice (Barnyard Millet)": "SR Legacy's millet (169702, 168871, 172023) is proso millet; no CC0/OGL barnyard millet entry.",
}


def _row(i, name, hindi, category, aliases, unit, amount, grams, per100, basis, fdc):
    return {
        "id": f"food-usda-{FIRST_ID + i:04d}",
        "name": name,
        "name_hindi": hindi,
        "category": category,
        "basis": "per_100_grams",
        "serving_unit": unit,
        "serving_amount": f"{amount:g}",
        "serving_grams": f"{grams:g}",
        # Total carbohydrate, fibre included, as in the rest of the catalogue.
        **{k: f"{per100[k] + (per100['fibre_g'] if k == 'carbs_g' else 0):.2f}" for k in KEYS},
        "aliases": aliases,
        "usda_basis": basis,
        "fdc_ids": " ".join(fdc),
    }


def main():
    sr = {}
    for path in (STAPLES / "usda_extract.json", DISHES_DIR / "usda_extract.json", HERE / "usda_extract.json"):
        for k, v in json.loads(path.read_text()).items():
            sr[k] = {**v, **{key: float(v[key]) for key in KEYS}}

    out = []
    for name, (hindi, category, aliases, unit, amount, grams, fdc) in SINGLE.items():
        per100 = {k: sr[fdc][k] for k in KEYS}
        out.append(_row(len(out), name, hindi, category, aliases, unit, amount, grams,
                        per100, f"SR Legacy {fdc} {sr[fdc]['desc']}", [fdc]))
    for name, hindi, category, aliases, unit, amount, grams, ings, cooked, note in RECIPES:
        tot = {k: sum(sr[ING[n]][k] * g / 100 for n, g in ings) for k in KEYS}
        per100 = {k: tot[k] * 100 / cooked for k in KEYS}
        basis = "recipe: " + "; ".join(f"{n} {g:g} g" for n, g in ings)
        basis += f"; cooked {cooked:g} g" + (f" ({note})" if note else "")
        fdc = sorted({ING[n] for n, _ in ings})
        out.append(_row(len(out), name, hindi, category, aliases, unit, amount, grams, per100, basis, fdc))
    with OUT.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(out[0]))
        w.writeheader()
        w.writerows(out)
    print(f"{len(out)} foods -> {OUT.relative_to(ROOT)}; excluded {sorted(EXCLUDED)}")


if __name__ == "__main__":
    main()
