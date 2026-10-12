#!/usr/bin/env python3
"""Generates foods.csv for the usda-staples-v1 catalogue source.

Every value comes from USDA FoodData Central SR Legacy (public domain, CC0):
single foods directly, dishes as recipes of SR Legacy ingredients. IFCT 2017
and Indian pack labels are not used for values (NUTRITION_CATALOGUE_PACKS_PLAN
§ 3); the IFCT-based figure from the 12 Oct staples review is kept beside each
row as `ifct_check_kcal` so reviewers can see where Indian ingredients differ.

    python3 generate.py --sr <sr.json>   # refresh usda_extract.json from a full SR dump
    python3 generate.py                  # rebuild foods.csv from usda_extract.json

<sr.json> is {fdc_id: {desc, kcal, protein_g, fat_g, carbs_g, fibre_g}} built
from FoodData_Central_sr_legacy_food_csv_2018-04 (carbs_g there is available
carbohydrate: total by difference minus fibre). foods.csv writes total
carbohydrate, fibre included, as the rest of the catalogue does.
"""

import csv
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
DRAFT = ROOT / "docs/audit/food-search-2026-10-12/staples_draft.csv"
EXTRACT = HERE / "usda_extract.json"
OUT = HERE / "foods.csv"
KEYS = ["kcal", "protein_g", "carbs_g", "fat_g", "fibre_g"]

# Single foods: draft name -> SR Legacy fdc id.
SINGLE = {
    "Banana": "173944", "Apple": "171688", "Mango": "169910", "Orange": "169097",
    "Papaya": "169926", "Watermelon": "167765", "Guava": "173044", "Pomegranate": "169134",
    "Grapes": "174683", "Pineapple": "169124", "Chikoo": "167759", "Pear": "167776",
    "Muskmelon": "169092", "Strawberries": "167762", "Kiwi": "168153", "Dates": "171726",
    "Raisins": "168165", "Jamun": "168150",
    "Almonds": "170567", "Cashews": "170162", "Walnuts": "170187", "Peanuts (Roasted)": "174262",
    "Pistachios": "170184", "Makhana (Roasted)": "170149", "Peanut Butter": "174266",
    "Chia Seeds": "170554", "Flax Seeds": "169414", "Pumpkin Seeds": "170556",
    "Sunflower Seeds": "170562", "Coconut (Fresh, Grated)": "170169",
    "Vanilla Ice Cream": "167575", "Dark Chocolate": "170273", "Milk Chocolate": "167587",
    "White Bread": "174924", "Brown Bread (Whole Wheat)": "172688", "Multigrain Bread": "168013",
    "Pav": "172793", "Rusk": "174981", "Cornflakes": "174648", "Oats (Dry)": "173904",
    "Granola": "171646", "Whole Egg (Boiled)": "173424", "Egg White (Boiled)": "172183",
    "Tofu": "172475", "Soya Chunks (Dry)": "174275", "Sattu": "174288",
    "Whey Protein": "173177", "Cheese Slice": "171290", "Butter": "173410",
    "Mozzarella Cheese": "170845", "Cola": "174852", "Masala Noodles (Instant)": "171177",
    "Popcorn (Salted)": "170247", "Glucose Biscuits": "168014", "Marie Biscuits": "171867",
    "Potato Chips (Salted)": "169677", "Corn Puffs (Masala)": "167949", "Banana Chips": "168849",
    "Peanut Chikki": "169586", "Malted Milk Drink Powder": "173220",
}
# Where the USDA food is a stand-in, say so in the row.
PROXY = {
    "Makhana (Roasted)": "dried lotus seeds, dry-roasted without oil",
    "Soya Chunks (Dry)": "defatted soy flour (soya chunks are extruded defatted soy)",
    "Sattu": "chickpea flour (besan); sattu is roasted chickpea flour",
    "Glucose Biscuits": "USDA animal crackers / tea biscuits",
    "Corn Puffs (Masala)": "USDA cheese-flavour corn puffs",
    "Peanut Chikki": "USDA peanut brittle",
    "Masala Noodles (Instant)": "USDA ramen noodles, any flavour, dry",
    "Pav": "USDA plain dinner rolls",
    "Cheese Slice": "USDA pasteurised process cheese",
    "Egg White (Boiled)": "raw egg white (boiling changes little)",
    "Cornflakes": "USDA corn flakes (Ralston)",
    "Granola": "USDA homemade granola",
}

# Recipe ingredients: name -> SR Legacy fdc id, or a derived ingredient below.
ING = {
    "rice": "169756", "rice_flour": "169714", "atta": "168893", "maida": "169761",
    "semolina": "168933", "besan": "174288", "chickpeas": "173756", "moong": "174256",
    "toor": "172436", "urad": "174259", "rajma": "173744", "milk": "171265",
    "curd": "171284", "hung_curd": "171304", "ghee": "173412", "oil": "171410",
    "mustard_oil": "172337", "sugar": "169655", "cashew": "170162", "almond": "170567",
    "peanut": "172430", "coconut": "170169", "carrot": "170393", "cabbage": "169975",
    "capsicum": "170427", "peas": "170419", "potato": "170026", "onion": "170000",
    "tomato": "170457", "cucumber": "168409", "lemon_juice": "167747", "tamarind": "167763",
    "spinach": "168462", "chicken_breast": "171077", "chicken_thigh": "173627",
    "carp": "171952", "shrimp": "175179", "goat": "175303", "egg": "171287",
    "orange": "169097", "sago": "169717", "mayonnaise": "171009", "ketchup": "168556",
    "butter": "173410", "mozzarella": "170845", "dry_milk": "170876", "oats": "173904",
    "cornflakes": "174648", "raisins": "168165", "rice_flakes": None, "white_bread": "174924",
    "dinner_roll": "172793",
}


def derived(name, sr):
    """Ingredients USDA lacks, by mass balance from USDA ones."""
    if name == "khoa":  # whole milk dried to 25% moisture: dry whole milk diluted to 75% solids
        dry = sr[ING["dry_milk"]]
        return {k: dry[k] * 0.769 for k in KEYS}
    if name == "chhena":  # 1 kg whole milk -> 180 g chhena; keeps 75% of protein, 90% of fat, 10% of lactose
        milk = sr[ING["milk"]]
        p, f, c = milk["protein_g"] * 10 * 0.75, milk["fat_g"] * 10 * 0.90, milk["carbs_g"] * 10 * 0.10
        per = {"protein_g": p / 1.8, "fat_g": f / 1.8, "carbs_g": c / 1.8, "fibre_g": 0.0}
        per["kcal"] = 4 * per["protein_g"] + 9 * per["fat_g"] + 4 * per["carbs_g"]
        return per
    raise KeyError(name)


# name: ([(ingredient, raw grams)], cooked batch grams, note). Same recipes as
# the 12 Oct review (docs/audit/food-search-2026-10-12/method/recipes.py).
RECIPES = {
    "Gulab Jamun": ([("khoa", 200), ("maida", 30), ("ghee", 40), ("sugar", 130)], 400, "10 pieces; 40 g ghee absorbed in frying; syrup sugar absorbed"),
    "Jalebi": ([("maida", 100), ("curd", 20), ("oil", 35), ("sugar", 120)], 300, "fried (35 g oil absorbed), soaked in sugar syrup"),
    "Rasgulla": ([("chhena", 100), ("sugar", 60)], 160, "4 pieces with syrup"),
    "Rasmalai": ([("chhena", 100), ("sugar", 55), ("milk", 300)], 240, "chhena balls in rabri (300 g milk reduced by half)"),
    "Besan Ladoo": ([("besan", 100), ("ghee", 50), ("sugar", 80)], 230, ""),
    "Motichoor Ladoo": ([("besan", 100), ("oil", 40), ("sugar", 110)], 260, "fried boondi (40 g oil absorbed) in syrup"),
    "Kaju Katli": ([("cashew", 100), ("sugar", 70), ("ghee", 5)], 180, ""),
    "Milk Barfi": ([("khoa", 200), ("sugar", 60), ("ghee", 5)], 265, ""),
    "Kheer": ([("milk", 1000), ("rice", 50), ("sugar", 70)], 600, "milk reduced to 600 g with rice"),
    "Gajar Halwa": ([("carrot", 500), ("milk", 500), ("sugar", 100), ("ghee", 40), ("khoa", 50)], 600, ""),
    "Suji Halwa": ([("semolina", 100), ("ghee", 60), ("sugar", 100)], 450, "cooked with 300 g water"),
    "Peda": ([("khoa", 200), ("sugar", 70)], 260, ""),
    "Sandesh": ([("chhena", 200), ("sugar", 50)], 240, ""),
    "Shrikhand": ([("hung_curd", 250), ("sugar", 80)], 330, "strained whole-milk curd and sugar"),
    "Mysore Pak": ([("besan", 100), ("ghee", 120), ("sugar", 200)], 400, ""),
    "Puri": ([("atta", 100), ("oil", 30)], 130, "5 g oil in dough, 25 g absorbed in frying"),
    "Thepla": ([("atta", 100), ("besan", 15), ("spinach", 30), ("curd", 30), ("oil", 15)], 200, "methi leaves taken as spinach (USDA has no fenugreek leaves)"),
    "Luchi": ([("maida", 100), ("ghee", 10), ("oil", 25)], 130, "25 g oil absorbed in frying"),
    "Litti": ([("atta", 150), ("besan", 60), ("onion", 20), ("ghee", 35)], 330, "sattu filling taken as besan; 4 pieces"),
    "Appam": ([("rice_flour", 100), ("coconut", 30), ("sugar", 5), ("oil", 3)], 250, ""),
    "Uttapam": ([("rice", 75), ("urad", 25), ("onion", 30), ("tomato", 20), ("oil", 8)], 300, "2 uttapams"),
    "Puttu": ([("rice_flour", 100), ("coconut", 25)], 180, "steamed"),
    "Khichdi": ([("rice", 60), ("moong", 40), ("ghee", 10)], 400, ""),
    "Curd Rice": ([("rice", 50), ("curd", 150), ("oil", 5)], 305, ""),
    "Lemon Rice": ([("rice", 60), ("oil", 10), ("peanut", 10), ("lemon_juice", 15)], 215, ""),
    "Veg Fried Rice": ([("rice", 80), ("oil", 15), ("carrot", 30), ("cabbage", 30), ("capsicum", 20), ("peas", 20)], 355, ""),
    "Chicken Fried Rice": ([("rice", 80), ("chicken_breast", 60), ("egg", 25), ("oil", 15), ("cabbage", 20), ("carrot", 20)], 400, ""),
    "Ven Pongal": ([("rice", 60), ("moong", 30), ("ghee", 15), ("cashew", 5)], 400, ""),
    "Bisi Bele Bath": ([("rice", 50), ("toor", 30), ("carrot", 20), ("peas", 20), ("potato", 20), ("tamarind", 5), ("ghee", 12)], 400, ""),
    "Sabudana Khichdi": ([("sago", 60), ("peanut", 20), ("potato", 40), ("oil", 10)], 170, ""),
    "Rajma Chawal": ([("rajma", 40), ("onion", 30), ("tomato", 40), ("oil", 8), ("rice", 50)], 300, "one plate"),
    "Dal Chawal": ([("toor", 30), ("oil", 5), ("rice", 50)], 300, "one plate"),
    "Chicken Breast (Cooked)": ([("chicken_breast", 133)], 100, "grilled, no oil; 25% cooking loss"),
    "Chicken Thigh (Cooked)": ([("chicken_thigh", 133)], 100, "grilled, no oil; 25% cooking loss"),
    "Fish Fillet (Cooked)": ([("carp", 125), ("oil", 3)], 100, "carp (rohu is a carp), pan-cooked; 20% cooking loss"),
    "Machher Jhol": ([("carp", 100), ("potato", 40), ("mustard_oil", 15), ("onion", 20), ("tomato", 20)], 250, ""),
    "Prawns (Cooked)": ([("shrimp", 125)], 100, "boiled; 20% cooking loss"),
    "Mutton Curry": ([("goat", 150), ("onion", 60), ("tomato", 50), ("oil", 20), ("curd", 30)], 330, ""),
    "Chicken Shawarma Roll": ([("chicken_thigh", 130), ("maida", 70), ("mayonnaise", 20), ("onion", 20), ("cabbage", 20), ("oil", 5)], 250, ""),
    "Chicken Momos": ([("maida", 50), ("chicken_thigh", 90), ("onion", 20), ("cabbage", 15), ("oil", 5)], 200, "6 steamed pieces"),
    "Veg Momos": ([("maida", 50), ("cabbage", 50), ("carrot", 25), ("onion", 20), ("oil", 6)], 180, "6 steamed pieces"),
    "Moong Sprouts": ([("moong", 40)], 104, "40 g dry whole moong sprouted to 104 g"),
    "Tea with Milk and Sugar": ([("milk", 50), ("sugar", 8)], 150, ""),
    "Coffee with Milk and Sugar": ([("milk", 100), ("sugar", 8)], 150, ""),
    "Cold Coffee": ([("milk", 200), ("sugar", 20)], 250, ""),
    "Badam Milk": ([("milk", 200), ("almond", 10), ("sugar", 15)], 200, ""),
    "Orange Juice (Fresh)": ([("orange", 200)], 200, "orange flesh with 20% of its fibre"),
    "Pizza (Margherita)": ([("maida", 45), ("oil", 6), ("mozzarella", 30), ("tomato", 30)], 107, "one slice of a 4-slice pizza"),
    "Veg Burger": ([("dinner_roll", 55), ("potato", 55), ("peas", 8), ("maida", 8), ("oil", 8), ("mayonnaise", 8), ("tomato", 10), ("onion", 5)], 150, ""),
    "Chicken Burger": ([("dinner_roll", 60), ("chicken_thigh", 80), ("maida", 10), ("oil", 10), ("mayonnaise", 12), ("tomato", 10), ("cabbage", 10)], 170, ""),
    "French Fries": ([("potato", 234), ("oil", 17.5)], 117, "fries weigh about half the raw potato; 15% oil"),
    "Pasta (Red Sauce)": ([("semolina", 80), ("tomato", 60), ("onion", 15), ("oil", 10), ("mozzarella", 5)], 290, ""),
    "Pasta (White Sauce)": ([("semolina", 80), ("milk", 100), ("butter", 10), ("maida", 8), ("mozzarella", 15), ("capsicum", 20)], 330, ""),
    "Veg Spring Roll": ([("maida", 15), ("cabbage", 20), ("carrot", 10), ("oil", 9)], 60, "deep fried"),
    "Veg Frankie": ([("maida", 60), ("potato", 80), ("onion", 20), ("oil", 10), ("ketchup", 10)], 200, ""),
    "Kachori": ([("maida", 30), ("moong", 12), ("oil", 15)], 60, ""),
    "Bread Butter Toast": ([("white_bread", 25), ("butter", 5)], 30, ""),
    "Oats Porridge with Milk": ([("oats", 40), ("milk", 200), ("sugar", 8)], 250, ""),
    "Veg Sandwich": ([("white_bread", 50), ("butter", 6), ("tomato", 30), ("cucumber", 30), ("potato", 30)], 150, ""),
    "Cheese Sandwich": ([("white_bread", 50), ("mozzarella", 40), ("butter", 8), ("tomato", 20), ("cucumber", 12)], 130, "grilled"),
    "Bread Omelette": ([("white_bread", 50), ("egg", 100), ("oil", 6), ("onion", 10), ("tomato", 10)], 150, "2 eggs"),
    "Muesli": ([("oats", 60), ("cornflakes", 15), ("raisins", 10), ("almond", 10), ("sugar", 5)], 100, "dry mix"),
    "Aloo Bhujia": ([("besan", 50), ("potato", 60), ("oil", 40)], 100, "besan-potato sev, fried; 40% oil by fried weight"),
    "Namkeen Mixture": ([("besan", 40), ("peanut", 15), ("rice", 15), ("oil", 32)], 100, "sev, peanuts and fried rice flakes (taken as rice)"),
}

# Rows with no CC0 source: left out of the pack, to Open Food Facts lookup.
EXCLUDED = {"Amla": "no USDA entry for Indian gooseberry"}


def unit_for(row, grams):
    text = row["serving"].lower()
    amount = float(row["quantity"])
    if "ml)" in text:
        return "ml", float(re.search(r"\(([\d.]+) ml", text).group(1))
    word = text.split(" (")[0].strip()
    unit = {
        "medium": "piece", "piece": "piece", "pieces": "piece", "egg": "piece", "egg white": "piece",
        "roll": "piece", "burger": "piece", "sandwich": "piece", "whole": "piece",
        "cup": "cup", "cups": "cup", "cup sliced": "cup", "cup arils": "cup", "tbsp": "tbsp", "tsp": "tsp",
        "slice": "slice", "scoop": "scoop", "handful": "handful", "small bar": "bar",
        "biscuits": "biscuit", "small pack": "pack", "pack cooked": "pack", "plate": "plate",
        "katori": "katori", "serving": "serving",
    }.get(word, "serving")
    if unit == "katori" and abs(grams / amount - 150) > 0.5:
        unit = "serving"  # katori means 150 g in the app; other bowls are servings
    if amount > 6:  # validator's household maximum
        unit, amount = "serving", 1.0
    return unit, amount


def main(argv):
    if "--sr" in argv:
        sr_all = json.loads(Path(argv[argv.index("--sr") + 1]).read_text())
        ids = {v for v in SINGLE.values()} | {v for v in ING.values() if v}
        EXTRACT.write_text(json.dumps({i: sr_all[i] for i in sorted(ids)}, indent=1) + "\n")
    sr = {k: {**v, **{key: float(v[key]) for key in KEYS}} for k, v in json.loads(EXTRACT.read_text()).items()}

    def ing(name):
        return derived(name, sr) if name in ("khoa", "chhena") else sr[ING[name]]

    rows = list(csv.DictReader(DRAFT.open()))
    out = []
    for i, row in enumerate(rows, start=1):
        name = row["name"]
        if name in EXCLUDED:
            continue
        m = re.search(r"\(([\d.]+) (g|ml)", row["serving"])
        grams = float(m.group(1)) if m else 70.0  # "pack cooked (70 g dry)"
        if name in RECIPES:
            ings, cooked, note = RECIPES[name]
            tot = {k: sum(ing(n)[k] * g / 100 for n, g in ings) for k in KEYS}
            per100 = {k: tot[k] * 100 / cooked for k in KEYS}
            if name == "Orange Juice (Fresh)":
                removed = per100["fibre_g"] * 0.8
                per100["fibre_g"] -= removed
                per100["kcal"] -= 2 * removed
            basis = "recipe: " + "; ".join(f"{n} {g:g} g" for n, g in ings) + f"; cooked {cooked:g} g"
            basis += f" ({note})" if note else ""
            fdc = sorted({ING[n] for n, _ in ings if ING.get(n)} | ({ING["dry_milk"]} if any(n == "khoa" for n, _ in ings) else set()) | ({ING["milk"]} if any(n == "chhena" for n, _ in ings) else set()))
        elif name in SINGLE:
            per100 = {k: sr[SINGLE[name]][k] for k in KEYS}
            basis = f"SR Legacy {SINGLE[name]} {sr[SINGLE[name]]['desc']}"
            basis += f" — stand-in: {PROXY[name]}" if name in PROXY else ""
            fdc = [SINGLE[name]]
        else:
            raise SystemExit(f"No USDA basis for {name}")
        unit, amount = unit_for(row, grams)
        aliases = [a.strip() for a in row["aliases"].split(",") if a.strip()]
        out.append({
            "id": f"food-usda-{i:04d}",
            "name": name,
            "name_hindi": row["name_hindi"],
            "category": row["category"],
            "basis": "per_100_millilitres" if unit == "ml" else "per_100_grams",
            "serving_unit": unit,
            "serving_amount": f"{amount:g}",
            "serving_grams": "" if unit == "ml" else f"{grams:g}",
            # The catalogue's carbohydrate is total carbohydrate, fibre
            # included (validate.py's energy check reads it that way).
            **{k: f"{per100[k] + (per100['fibre_g'] if k == 'carbs_g' else 0):.2f}" for k in KEYS},
            "aliases": "|".join(aliases),
            "usda_basis": basis,
            "fdc_ids": " ".join(fdc),
            "ifct_check_kcal": row["kcal"],
        })
    with OUT.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(out[0]))
        w.writeheader()
        w.writerows(out)
    print(f"{len(out)} foods -> {OUT.relative_to(ROOT)}; excluded {sorted(EXCLUDED)}")


if __name__ == "__main__":
    main(sys.argv[1:])
