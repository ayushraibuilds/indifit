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
