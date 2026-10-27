"""Tests for tool/catalog/build.py and validate.py (CAT-5, CAT-6).

Run: python3 -m unittest discover -s tool/catalog/tests
"""

import contextlib
import copy
import hashlib
import io
import sys
import tempfile
import unittest
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import build  # noqa: E402
import validate  # noqa: E402

# Audit C-04 (FINAL_LAUNCH_AUDIT_2026-10-05): 6 rows store grams as katori
# (or servings), and 29 "Double serving/healthy bowl" and "Small side bowl"
# rows say "1 katori" at twice or half the base's kcal.
GRAM_AS_HOUSEHOLD = {
    "Basmati White Rice (Cooked) (Mini)",
    "Brown Rice (Cooked) (Mini)",
    "Jeera Rice (Mini)",
    "Saffron Rice / Pulao (Mini)",
    "Roasted Chana (with skin) (Small side bowl)",
    "Onion Pakora (4-5 pieces) (Mini size)",
}
PACK_V1_SHA256 = "6d5cc651078172f89f4ff412b48200a8de2fbb29718391527133ab03de266a9c"


def _rules(violations, rule):
    return [v for v in violations if v.rule == rule]


class BaselineTest(unittest.TestCase):
    """validate.py on today's data reports the known C-04 violations."""

    @classmethod
    def setUpClass(cls):
        cls.violations = validate.validate_baseline()

    def test_the_six_gram_as_household_rows(self):
        names = {v.name for v in _rules(self.violations, "household-amount")}
        self.assertEqual(names, GRAM_AS_HOUSEHOLD)

    def test_the_29_double_and_small_side_bowl_rows(self):
        flagged = {v.name for v in _rules(self.violations, "variant-ratio")}
        known = {
            row["name"]
            for row in build.load_source_rows()
            if row["name"].endswith(("(Double serving)", "(Double healthy bowl)", "(Small side bowl)"))
            and row["name"] not in GRAM_AS_HOUSEHOLD
        }
        self.assertEqual(len(known), 29)
        self.assertLessEqual(known, flagged)

    def test_the_cli_fails_on_todays_data(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(validate.main(["--baseline"]), 1)
        self.assertIn("101 violations", out.getvalue())


class BuiltPacksTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.outputs, cls.packs = build.build_outputs()

    def test_the_built_packs_have_no_violations(self):
        self.assertEqual(validate.validate_built(), [])

    def test_pack_1_is_frozen_byte_for_byte(self):
        data = self.outputs[build.PACKS / "v1/1.json.gz"]
        self.assertEqual(hashlib.sha256(data).hexdigest(), PACK_V1_SHA256)

    def test_no_id_changes_or_disappears(self):
        v1 = {food["id"]: food for food in self.packs[1]["foods"]}
        v2 = {food["id"]: food for food in self.packs[2]["foods"]}
        self.assertEqual(set(v1), set(v2))
        for food_id, food in v2.items():
            self.assertEqual(food["source_ref"], v1[food_id]["source_ref"])

    def test_the_delta_on_pack_1_equals_pack_2(self):
        delta = build.decode(self.outputs[build.PACKS / "v2/2-from-1.json.gz"])
        self.assertEqual(delta["kind"], "delta")
        self.assertEqual(delta["base"], 1)
        self.assertEqual(validate.check_delta(self.packs[1], delta, self.packs[2]), [])

    def test_c04_measures(self):
        foods = {food["display_name"]: food for food in self.packs[2]["foods"]}

        def serving(name):
            s = foods[name]["servings"][0]
            return s["amount"], s["unit"], s.get("grams")

        self.assertEqual(serving("Toor Dal / Yellow Dal Tadka (Double serving)"), (2, "katori", 300))
        self.assertEqual(serving("Poha (Flattened Rice) (Small side bowl)"), (0.5, "katori", 75))
        self.assertEqual(serving("Basmati White Rice (Cooked) (Mini)"), (60, "g", 60))
        self.assertEqual(serving("Whole Wheat Roti / Chapati (Double)"), (2, "piece", None))
        rice = foods["Basmati White Rice (Cooked) (Mini)"]["facts"]
        self.assertEqual(rice["basis"], "per_100_grams")
        self.assertEqual(rice["values"]["energy"], 130.0)  # 78 kcal in 60 g

    def test_gram_weights_only_where_derivable(self):
        bases = set()
        for food in self.packs[2]["foods"]:
            serving = food["servings"][0]
            if serving.get("grams") is None:
                self.assertIn(serving["unit"], {"piece", "glass", "cup", "plate", "serving", "thali", "tiffin", "katori"})
                continue
            bases.add(serving["grams_basis"])
        self.assertEqual(bases, {"stated-grams", "app-katori-150g", "app-bowl-300g"})

    def test_c09_retirements_point_at_active_base_foods(self):
        pack = self.packs[2]
        foods = {food["id"]: food for food in pack["foods"]}
        retired = {entry["id"]: entry["replaced_by"] for entry in pack["retire"]}
        self.assertEqual(len(retired), 38 + 37)
        for food_id, replacement in retired.items():
            self.assertEqual(foods[food_id]["lifecycle"], "deprecated")
            self.assertEqual(foods[replacement]["lifecycle"], "active")
        names = {foods[food_id]["display_name"] for food_id in retired}
        self.assertIn("Idli with Sambar (2 Idlis) (With extra cheese / butter)", names)
        self.assertIn("Pani Puri / Golgappa (6 pieces) (With extra cheese / butter)", names)

    def test_aliases_come_from_the_synonyms_and_name_one_food(self):
        owners = {}
        for food in self.packs[2]["foods"]:
            for alias in food["aliases"]:
                key = (alias["text"].lower(), alias["locale"])
                self.assertNotIn(key, owners)
                owners[key] = food["display_name"]
        self.assertEqual(owners[("arhar dal / yellow dal tadka", "hi-Latn")], "Toor Dal / Yellow Dal Tadka")
        self.assertEqual(owners[("whole wheat phulka / chapati", "hi-Latn")], "Whole Wheat Roti / Chapati")

    def test_pack_3_adds_the_usda_staples_and_changes_nothing_else(self):
        v2 = {food["id"]: food for food in self.packs[2]["foods"]}
        v3 = {food["id"]: food for food in self.packs[3]["foods"]}
        self.assertEqual({k: v for k, v in v3.items() if k in v2}, v2)
        staples = [food for food in v3.values() if food["id"] not in v2]
        self.assertEqual(len(staples), 124)
        self.assertTrue(all(f["source_id"] == "usda-staples-v1" for f in staples))
        self.assertTrue(all(f["id"].startswith("food-usda-") for f in staples))
        self.assertEqual(self.packs[3]["retire"], self.packs[2]["retire"])
        source = {s["id"]: s for s in self.packs[3]["sources"]}["usda-staples-v1"]
        self.assertEqual(source["licence"], "CC0-1.0")

    def test_the_delta_on_pack_2_equals_pack_3(self):
        delta = build.decode(self.outputs[build.PACKS / "v3/3-from-2.json.gz"])
        self.assertEqual(delta["base"], 2)
        self.assertEqual(validate.check_delta(self.packs[2], delta, self.packs[3]), [])

    def test_staple_servings_state_their_grams(self):
        foods = {food["display_name"]: food for food in self.packs[3]["foods"]}

        def serving(name):
            s = foods[name]["servings"][0]
            return s["amount"], s["unit"], s.get("grams"), s.get("grams_basis")

        self.assertEqual(serving("Banana"), (1, "piece", 118, "source-stated"))
        self.assertEqual(serving("Khichdi"), (1, "serving", 200, "source-stated"))
        self.assertEqual(serving("Kheer"), (1, "katori", 150, "source-stated"))
        self.assertEqual(serving("Tea with Milk and Sugar"), (150, "ml", None, None))
        self.assertEqual(foods["Banana"]["facts"]["basis"], "per_100_grams")
        self.assertEqual(foods["Banana"]["facts"]["values"]["energy"], 89.0)

    def test_staple_aliases_name_one_food(self):
        owners = {}
        for food in self.packs[3]["foods"]:
            for alias in food["aliases"]:
                key = (alias["text"].lower(), alias["locale"])
                self.assertNotIn(key, owners)
                owners[key] = food["display_name"]
        self.assertEqual(owners[("केला", "hi")], "Banana")
        self.assertEqual(owners[("kela", "hi-Latn")], "Banana")
        self.assertNotIn(("laddu", "hi-Latn"), owners)  # two ladoos share it

    def test_pack_5_links_the_bracketed_variants(self):
        # UR-06: 47 dhaba and 14 diet-prep variants gain variant_of.
        v4 = {food["id"]: food for food in self.packs[4]["foods"]}
        v5 = {food["id"]: food for food in self.packs[5]["foods"]}
        linked = {
            fid: food
            for fid, food in v5.items()
            if food["variant_of"] and fid in v4 and not v4[fid]["variant_of"]
        }
        labels = Counter(food["variant_label"] for food in linked.values())
        self.assertEqual(labels["Dhaba Style (High oil)"], 48)  # 47 active + 1 retired
        self.assertEqual(labels["Diet prep (Low oil / breast only)"], 14)
        self.assertEqual(sum(labels.values()), 62)
        for food in linked.values():
            self.assertEqual(food["tags"], ["oil"])
            self.assertEqual(food["kind"], "variant")
            base = v5[food["variant_of"]]
            self.assertEqual(
                food["display_name"], f"{base['display_name']} ({food['variant_label']})"
            )
        # Nothing else about those foods changed, except that, as variants,
        # they no longer carry synonym aliases (search finds their dish).
        for fid, food in linked.items():
            self.assertEqual(food["aliases"], [])
            before = dict(v4[fid], variant_of=None, variant_label=None, tags=[], kind="canonical", aliases=[])
            after = dict(food, variant_of=None, variant_label=None, tags=[], kind="canonical")
            after["lifecycle"] = before["lifecycle"]
            self.assertEqual(after, before)

    def test_pack_5_retires_nonsense_and_duplicate_variants(self):
        # UR-07: "breast only" on eggs, fish and mutton; "Medium cup / Glass"
        # copies with their dish's kcal. Retired, never deleted.
        v5 = {food["id"]: food for food in self.packs[5]["foods"]}
        before = {r["id"] for r in self.packs[4]["retire"]}
        new = [r for r in self.packs[5]["retire"] if r["id"] not in before]
        self.assertEqual(len(new), 17)
        names = sorted(v5[r["id"]]["display_name"] for r in new)
        self.assertEqual(sum("Medium cup / Glass" in n for n in names), 9)
        self.assertEqual(sum("breast only" in n for n in names), 8)
        for entry in new:
            self.assertEqual(v5[entry["id"]]["lifecycle"], "deprecated")
            self.assertEqual(v5[entry["replaced_by"]]["lifecycle"], "active")
            self.assertEqual(v5[entry["id"]]["variant_of"], entry["replaced_by"])
        kept = [n for n in (f["display_name"] for f in v5.values() if f["lifecycle"] == "active") if "breast only" in n]
        self.assertTrue(kept)
        self.assertTrue(all("Chicken" in n for n in kept))

    def test_pack_5_adds_the_gap_dishes_from_usda_recipes(self):
        v4 = {food["id"] for food in self.packs[4]["foods"]}
        dishes = [f for f in self.packs[5]["foods"] if f["id"] not in v4]
        self.assertEqual(len(dishes), 31)
        self.assertTrue(all(f["source_id"] == "usda-dishes-v1" for f in dishes))
        source = {s["id"]: s for s in self.packs[5]["sources"]}["usda-dishes-v1"]
        self.assertEqual((source["licence"], source["review"]), ("CC0-1.0", "unreviewed"))
        by_name = {f["display_name"]: f for f in dishes}
        aliases = {a["text"] for a in by_name["Papad (Roasted)"]["aliases"]}
        self.assertIn("papad", aliases)
        self.assertIn("achar", {a["text"] for a in by_name["Mango Pickle (Achar)"]["aliases"]})
        papad = by_name["Papad (Roasted)"]["servings"][0]
        self.assertEqual((papad["amount"], papad["unit"], papad["grams"]), (1, "piece", 12))

    def test_the_delta_on_pack_4_equals_pack_5(self):
        delta = build.decode(self.outputs[build.PACKS / "v5/5-from-4.json.gz"])
        self.assertEqual(validate.check_delta(self.packs[4], delta, self.packs[5]), [])

    def test_pack_5_servings_hold_the_app_rows_kcal(self):
        # UR-08: the app shows legacy rows with the pack serving.
        self.assertEqual(validate.check_legacy_servings(self.packs[5], build.load_source_rows()), [])
        foods = {f["display_name"]: f for f in self.packs[5]["foods"]}
        poha = foods["Poha (Flattened Rice) (Double healthy bowl)"]["servings"][0]
        chana = foods["Roasted Chana (with skin) (Small side bowl)"]["servings"][0]
        self.assertEqual((poha["amount"], poha["unit"]), (2, "katori"))
        self.assertEqual((chana["amount"], chana["unit"]), (25, "g"))

    def test_a_wrong_legacy_serving_is_caught(self):
        pack = copy.deepcopy(self.packs[5])
        food = next(f for f in pack["foods"] if f["display_name"] == "Poha (Flattened Rice) (Double healthy bowl)")
        food["facts"]["values"]["energy"] = 230.0
        found = validate.check_legacy_servings(pack, build.load_source_rows())
        self.assertEqual([v.food_id for v in found], [food["id"]])

    def test_spotcheck_has_50_active_foods(self):
        rows = self.outputs[build.SPOTCHECK].decode().strip().split("\n")
        self.assertEqual(len(rows), 51)


def _food(food_id, name, energy=100.0, unit="katori", amount=1, grams=None, **extra):
    serving = {"id": "default", "default": True, "unit": unit, "amount": amount, "grams": grams}
    return {
        "id": food_id,
        "display_name": name,
        "source_id": "s",
        "lifecycle": "active",
        "facts": {
            "basis": "per_serving",
            "values": {"energy": energy, "protein": 5.0, "carbohydrate": 15.0, "fat": 2.0},
        },
        "servings": [serving],
        **extra,
    }


def _pack(foods, retire=()):
    return {
        "format": 1,
        "version": 3,
        "kind": "full",
        "sources": [{"id": "s"}],
        "foods": foods,
        "retire": list(retire),
    }


class InvariantsTest(unittest.TestCase):
    """Each invariant catches its violation on a synthetic pack."""

    def rules(self, pack, **kwargs):
        return {v.rule for v in validate.check_pack(pack, **kwargs)}

    def test_a_clean_pack_passes(self):
        self.assertEqual(self.rules(_pack([_food("a", "Dal")])), set())

    def test_unique_ids(self):
        self.assertIn("unique-id", self.rules(_pack([_food("a", "Dal"), _food("a", "Rice")])))

    def test_an_id_never_disappears_without_a_retirement(self):
        previous = _pack([_food("a", "Dal"), _food("b", "Rice")])
        self.assertIn("id-disappeared", self.rules(_pack([_food("a", "Dal")]), previous=previous))

    def test_energy_is_required(self):
        food = _food("a", "Dal")
        del food["facts"]["values"]["energy"]
        self.assertIn("energy", self.rules(_pack([food])))

    def test_atwater(self):
        self.assertIn("atwater", self.rules(_pack([_food("a", "Dal", energy=400)])))

    def test_grams_are_positive(self):
        self.assertIn("serving-grams", self.rules(_pack([_food("a", "Dal", grams=0)])))

    def test_household_amount(self):
        self.assertIn("household-amount", self.rules(_pack([_food("a", "Rice", amount=60)])))

    def test_household_grams_follow_the_rule(self):
        rules = {"katori": {"grams_per_unit": 150}}
        pack = _pack([_food("a", "Dal", grams=100)])
        self.assertIn("household-grams", self.rules(pack, gram_rules=rules))
        pack = _pack([_food("a", "Dal", grams=150)])
        self.assertNotIn("household-grams", self.rules(pack, gram_rules=rules))

    def test_variant_ratio_unless_size_or_oil(self):
        base = _food("a", "Dal")
        double = _food("b", "Dal (Double serving)", energy=200, variant_of="a", tags=[])
        self.assertIn("variant-ratio", self.rules(_pack([base, double])))
        fixed = copy.deepcopy(double)
        fixed["servings"][0]["amount"] = 2
        self.assertNotIn("variant-ratio", self.rules(_pack([base, fixed])))
        oily = _food("c", "Dal (Extra ghee)", energy=200, variant_of="a", tags=["oil"])
        self.assertNotIn("variant-ratio", self.rules(_pack([base, oily])))

    def test_retired_names_never_return(self):
        retired = dict(_food("b", "Dal (Extra cheese)"), lifecycle="deprecated")
        revived = _food("c", "dal (extra cheese)")
        pack = _pack([_food("a", "Dal"), retired, revived], [{"id": "b", "replaced_by": "a"}])
        self.assertIn("retired-name", self.rules(pack))
        self.assertIn("retired-name", self.rules(_pack([_food("a", "Dal"), revived]), retired_names={"dal (extra cheese)"}))

    def test_a_replacement_must_be_active(self):
        retired = dict(_food("b", "Rice"), lifecycle="deprecated")
        pack = _pack([_food("a", "Dal"), retired], [{"id": "b", "replaced_by": "missing"}])
        self.assertIn("retirement", self.rules(pack))


class OverlayGuardsTest(unittest.TestCase):
    def test_an_overlay_cannot_drift_onto_another_food(self):
        with tempfile.TemporaryDirectory() as directory:
            for path in build.OVERLAYS.glob("*.yaml"):
                text = path.read_text(encoding="utf-8")
                if path.name.startswith("0002"):
                    text = text.replace('"Whole Wheat Roti / Chapati (Double)"', '"Some Other Food"', 1)
                (Path(directory) / path.name).write_text(text, encoding="utf-8")
            with self.assertRaisesRegex(build.BuildError, "Some Other Food"):
                build.build_catalogue(2, overlay_dir=directory)


if __name__ == "__main__":
    unittest.main()


class KeyIngredientsTest(unittest.TestCase):
    """Pack 8: key_ingredients (TF-2 C) and the vrat foods."""

    @classmethod
    def setUpClass(cls):
        cls.pack = build.build_pack(8)
        cls.by_name = {food["display_name"]: food for food in cls.pack["foods"]}
        cls.vocabulary = build.load_yaml(build.KEY_INGREDIENTS)["vocabulary"]

    def test_recipe_words_drop_pantry_and_sort_by_weight(self):
        words = build.recipe_key_ingredients(
            "recipe: paneer 200 g; oil 25 g; capsicum 60 g; onion 70 g; "
            "green_chilli 5 g; cooked 380 g (note)"
        )
        self.assertEqual(words, ["paneer", "onion", "capsicum"])

    def test_single_foods_and_one_ingredient_recipes_have_none(self):
        self.assertIsNone(build.recipe_key_ingredients("SR Legacy 173944 Bananas, raw"))
        self.assertIsNone(build.recipe_key_ingredients("recipe: urad 12 g; cooked 12 g"))

    def test_authored_and_derived_dishes(self):
        self.assertEqual(
            self.by_name["Kadai Paneer"]["key_ingredients"],
            ["paneer", "capsicum", "onion", "tomato"],
        )
        self.assertEqual(
            self.by_name["Sabudana Khichdi"]["key_ingredients"],
            ["sabudana", "potato", "peanuts"],
        )
        self.assertNotIn("key_ingredients", self.by_name["Jeera Aloo"])

    def test_earlier_packs_have_no_key_ingredients(self):
        pack = build.build_pack(7)
        self.assertFalse(any("key_ingredients" in food for food in pack["foods"]))

    def test_vrat_foods_are_sourced(self):
        for name in ("Kuttu Atta (Buckwheat Flour)", "Kuttu Puri", "Vrat Aloo (Sendha Namak)"):
            self.assertEqual(self.by_name[name]["source_id"], "usda-vrat-v1")
        self.assertNotIn("Samak Rice (Barnyard Millet)", self.by_name)

    def test_validator_rejects_bad_words(self):
        pack = copy.deepcopy(self.pack)
        foods = {food["display_name"]: food for food in pack["foods"]}
        foods["Kadai Paneer"]["key_ingredients"] = ["Paneer", "capsicum"]
        foods["Palak Paneer"]["key_ingredients"] = ["spinach"]
        foods["Rajma Masala (Red Kidney Beans)"]["key_ingredients"] = ["rajma", "unicorn"]
        details = [
            v.detail for v in validate.check_key_ingredients(pack, self.vocabulary)
        ]
        self.assertEqual(len(details), 3, details)
        self.assertTrue(any("not lowercase" in d for d in details))
        self.assertTrue(any("needs 2-6" in d for d in details))
        self.assertTrue(any("'unicorn' is not in" in d for d in details))

    def test_vocabulary_names_map_to_one_word(self):
        self.assertEqual(validate.check_key_ingredients({"foods": []}, self.vocabulary), [])
