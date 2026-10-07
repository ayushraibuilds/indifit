#!/usr/bin/env python3
"""Builds the food catalogue packs (CAT-5).

    sources/ + overlays/ -> packs/v{N}/{N}.json.gz      full pack N
                            packs/v{N}/{N}-from-{N-1}.json.gz   delta
                            packs/manifest.json         what Hosting serves
                            assets/catalog/             the bundled pack

The format is CAT-1 (docs/implementation/NUTRITION_CATALOGUE_PACKS_PLAN.md
§ 4.1), parsed by lib/data/catalog/catalog_pack.dart. Pack 1 is today's
catalogue as it shipped in PR-A and is frozen byte for byte; every later
version applies the overlays whose `version` is at or below it.

Usage:
    python3 tool/catalog/build.py          # write packs/ and assets/catalog/
    python3 tool/catalog/build.py --check  # fail if any output is stale

`packs/` is the directory to deploy to Firebase Hosting as /catalog/v1/
(CAT-8, owner): manifest URLs are relative to it.
"""

import copy
import csv
import gzip
import hashlib
import io
import json
import random
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "tool/catalog"
OVERLAYS = CATALOG / "overlays"
PACKS = CATALOG / "packs"
ASSETS = ROOT / "assets/catalog"
FOODS = ROOT / "assets/data/indian_foods.json"
MANIFEST = ROOT / "assets/data/nutrition_food_identity_manifest.json"
REGISTRY = ROOT / "assets/data/nutrient_registry.json"
SPOTCHECK = CATALOG / "spotcheck_50.csv"
SPOTCHECK_SEED = 20261007

FORMAT = 1
LATEST = 2
MIN_APP_BUILD = 1
SOURCE_ID = "indifit-catalogue-v1"

GRAM_UNITS = {"g": 1.0, "gram": 1.0, "grams": 1.0, "kg": 1000.0}
MILLILITRE_UNITS = {"ml": 1.0, "millilitre": 1.0, "l": 1000.0, "litre": 1000.0}
VARIANT_NAME = re.compile(r"^(.*) \(([^()]*)\)$")


class BuildError(Exception):
    pass


def _round(value):
    # Values are bounded to 6 decimals, as the legacy adapter did, so pack
    # facts equal the facts the app wrote before packs existed.
    return float(f"{value:.6f}")


def _number(value):
    """2.0 -> 2, so amounts read the same in JSON as in the overlays."""
    value = float(value)
    return int(value) if value.is_integer() else value


def load_yaml(path):
    with open(path, encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


def load_overlays(version, overlay_dir=OVERLAYS):
    """Every overlay whose `version` is at or below [version], in file order."""
    overlays = []
    for path in sorted(Path(overlay_dir).glob("*.yaml")):
        data = load_yaml(path)
        if not isinstance(data.get("version"), int):
            raise BuildError(f"{path.name}: needs an integer `version`")
        if data["version"] <= version:
            overlays.append((path.name, data))
    return overlays


def load_source_rows(foods_path=FOODS, manifest_path=MANIFEST):
    """Today's catalogue rows, each with its stable manifest id."""
    foods = json.loads(Path(foods_path).read_text(encoding="utf-8"))
    manifest = json.loads(Path(manifest_path).read_text(encoding="utf-8"))
    by_source = {m["source_key"]: m["target_id"] for m in manifest["legacy_mappings"]}
    entries = {e["id"] for e in manifest["entries"]}
    rows = []
    seen = set()
    for row in foods:
        key = "asset:base:" + row["name"].lower()
        food_id = by_source.get(key)
        if food_id is None or food_id not in entries:
            raise BuildError(f"No manifest identity for {row['name']!r}")
        if food_id in seen:
            raise BuildError(f"Two catalogue rows map to {food_id}")
        seen.add(food_id)
        rows.append({**row, "id": food_id})
    return rows


def _registry_version():
    return str(json.loads(REGISTRY.read_text(encoding="utf-8"))["registry_version"])


def _facts_and_serving(row, unit, amount):
    """CAT-1 facts and default serving for a row measured as amount x unit."""
    values = {
        "energy": float(row["calories"]),
        "protein": float(row["protein_g"]),
        "carbohydrate": float(row["carbs_g"]),
        "fat": float(row["fat_g"]),
        "fibre": float(row["fiber_g"]),
    }
    if unit in GRAM_UNITS:
        grams = amount * GRAM_UNITS[unit]
        values = {k: _round(v * 100 / grams) for k, v in values.items()}
        return {"basis": "per_100_grams", "values": values}, {
            "unit": "g",
            "amount": grams,
            "grams": grams,
        }
    if unit in MILLILITRE_UNITS:
        millilitres = amount * MILLILITRE_UNITS[unit]
        values = {k: _round(v * 100 / millilitres) for k, v in values.items()}
        return {"basis": "per_100_millilitres", "values": values}, {
            "unit": "ml",
            "amount": millilitres,
            "grams": None,
        }
    values = {k: _round(v) for k, v in values.items()}
    return {"basis": "per_serving", "values": values}, {
        "unit": unit,
        "amount": amount,
        "grams": None,
    }


# --------------------------------------------------------------------------
# Pack 1: frozen. Byte-identical to assets/catalog/pack-1.json.gz from PR-A.
# --------------------------------------------------------------------------


def _v1_food(row):
    unit = row["serving_unit"].strip().lower()
    facts, serving = _facts_and_serving(row, unit, float(row["serving_size"]))
    return {
        "id": row["id"],
        "display_name": row["name"],
        "source_ref": "asset:base:" + row["name"].lower(),
        "category": row["category"],
        "source_id": SOURCE_ID,
        "facts": facts,
        "servings": [{"id": "default", "default": True, **serving}],
    }


def build_pack_v1(rows):
    foods = sorted((_v1_food(row) for row in rows), key=lambda food: food["id"])
    return {
        "format": FORMAT,
        "version": 1,
        "base": None,
        "kind": "full",
        "min_app_build": 1,
        "registry_version": _registry_version(),
        "sources": [
            {
                "id": SOURCE_ID,
                "licence": "proprietary",
                "attribution": None,
                "review": "unreviewed",
            }
        ],
        "foods": foods,
        "retire": [],
    }


# --------------------------------------------------------------------------
# Pack 2+: sources + overlays.
# --------------------------------------------------------------------------


def variant_relations(rows, labels):
    """{variant id: (base id, label)} for rows named "<base> (<label>)"."""
    by_name = {row["name"]: row for row in rows}
    relations = {}
    for row in rows:
        match = VARIANT_NAME.match(row["name"])
        if not match or match.group(1) not in by_name:
            continue
        label = match.group(2)
        if label not in labels:
            raise BuildError(
                f"{row['name']!r}: variant label {label!r} has no entry in "
                "overlays/*variant_tags.yaml"
            )
        relations[row["id"]] = (by_name[match.group(1)]["id"], label)
    return relations


def _whole_word(term):
    return re.compile(r"(?<![a-z])" + re.escape(term) + r"(?![a-z])", re.IGNORECASE)


def alias_candidates(foods, config):
    """{food id: [alias text]} from the synonym clusters (see 0006_aliases)."""
    path = ROOT / config["source"]
    synonyms = json.loads(path.read_text(encoding="utf-8"))["synonyms"]
    skip = set((config.get("skip_clusters") or {}).keys())
    clusters = {}
    for term, canonical in synonyms.items():
        if canonical in skip:
            continue
        clusters.setdefault(canonical, {canonical}).add(term)

    names = {food["display_name"].lower() for food in foods}
    proposed = {}
    for food in foods:
        if food["lifecycle"] != "active" or food["variant_of"] is not None:
            continue
        name = food["display_name"]
        for canonical in sorted(clusters):
            members = clusters[canonical]
            for term in sorted(members):
                pattern = _whole_word(term)
                if not pattern.search(name):
                    continue
                for other in sorted(members - {term}):
                    alias = pattern.sub(other.title(), name)
                    proposed.setdefault(alias.lower(), {})[food["id"]] = alias
    result = {}
    for normalized, targets in proposed.items():
        if len(targets) != 1 or normalized in names:
            continue  # ambiguous, or another food's own name
        ((food_id, text),) = targets.items()
        result.setdefault(food_id, []).append(text)
    return {food_id: sorted(texts, key=str.lower) for food_id, texts in result.items()}


def build_catalogue(version, rows=None, overlay_dir=OVERLAYS, apply_fixes=True):
    """The foods and retirements of pack [version] (>= 2).

    With apply_fixes=False only the descriptive overlays (variant tags, gram
    weights, aliases) and the retirements already live in the app
    (`already_applied: true`) apply: the catalogue as it is today, described
    in the pack format, which the validator checks to show the invariants
    bite (CAT-5).
    """
    rows = load_source_rows() if rows is None else rows
    overlays = load_overlays(version, overlay_dir)
    labels = {}
    gram_rules = {}
    measures = {}
    retire = {}
    alias_config = None
    for name, data in overlays:
        labels.update(data.get("labels") or {})
        for rule in data.get("rules") or []:
            gram_rules[rule["unit"]] = rule
        if "source" in data and "locale" in data:
            alias_config = data
        if not apply_fixes and not data.get("already_applied"):
            continue
        for entry in data.get("measures") or []:
            measures[entry["id"]] = (name, entry)
        for entry in data.get("retire") or []:
            if entry["id"] in retire:
                raise BuildError(f"{name}: {entry['id']} is retired twice")
            retire[entry["id"]] = (name, entry)

    by_id = {row["id"]: row for row in rows}
    checked = list(measures.values()) + list(retire.values())
    checked += [
        ("gram rule " + rule["id"], entry)
        for rule in gram_rules.values()
        for entry in rule.get("exclude") or []
    ]
    for overlay_name, entry in checked:
        row = by_id.get(entry["id"])
        if row is None:
            raise BuildError(f"{overlay_name}: unknown id {entry['id']}")
        if row["name"] != entry["name"]:
            raise BuildError(
                f"{overlay_name}: {entry['id']} is {row['name']!r}, "
                f"not {entry['name']!r}"
            )

    relations = variant_relations(rows, labels)
    foods = []
    for row in rows:
        unit = row["serving_unit"].strip().lower()
        amount = float(row["serving_size"])
        if row["id"] in measures:
            serving = measures[row["id"]][1]["serving"]
            unit, amount = serving["unit"].strip().lower(), float(serving["amount"])
        facts, serving = _facts_and_serving(row, unit, amount)
        rule = gram_rules.get(serving["unit"])
        excluded = {e["id"] for e in (rule or {}).get("exclude") or []}
        if rule is not None and row["id"] not in excluded:
            serving["grams"] = _number(serving["amount"] * rule["grams_per_unit"])
            serving["grams_basis"] = rule["id"]
        serving["amount"] = _number(serving["amount"])
        relation = relations.get(row["id"])
        foods.append(
            {
                "id": row["id"],
                "display_name": row["name"],
                "kind": "variant" if relation else "canonical",
                "variant_of": relation[0] if relation else None,
                "variant_label": relation[1] if relation else None,
                "tags": sorted(labels[relation[1]]) if relation else [],
                "lifecycle": "deprecated" if row["id"] in retire else "active",
                "source_ref": "asset:base:" + row["name"].lower(),
                "category": row["category"],
                "source_id": SOURCE_ID,
                "facts": facts,
                "servings": [{"id": "default", "default": True, **serving}],
                "aliases": [],
            }
        )
    if alias_config is not None:
        aliases = alias_candidates(foods, alias_config)
        for food in foods:
            food["aliases"] = [
                {"text": text, "locale": alias_config["locale"]}
                for text in aliases.get(food["id"], [])
            ]
    foods.sort(key=lambda food: food["id"])
    retirements = sorted(
        (
            {"id": entry["id"], "replaced_by": entry["replaced_by"]}
            for _, entry in retire.values()
        ),
        key=lambda entry: entry["id"],
    )
    return foods, retirements


def build_pack(version, rows=None, overlay_dir=OVERLAYS, apply_fixes=True):
    rows = load_source_rows() if rows is None else rows
    if version == 1:
        return build_pack_v1(rows)
    foods, retirements = build_catalogue(version, rows, overlay_dir, apply_fixes)
    return {
        "format": FORMAT,
        "version": version,
        "base": None,
        "kind": "full",
        "min_app_build": MIN_APP_BUILD,
        "registry_version": _registry_version(),
        "sources": [
            {
                "id": SOURCE_ID,
                "licence": "proprietary",
                "attribution": None,
                "review": "unreviewed",
            }
        ],
        "foods": foods,
        "retire": retirements,
    }


def build_delta(previous, current):
    """The foods that changed since [previous], plus the new retirements."""
    before = {food["id"]: food for food in previous["foods"]}
    retired_before = {entry["id"] for entry in previous["retire"]}
    delta = copy.deepcopy(current)
    delta["kind"] = "delta"
    delta["base"] = previous["version"]
    delta["foods"] = [f for f in current["foods"] if before.get(f["id"]) != f]
    delta["retire"] = [r for r in current["retire"] if r["id"] not in retired_before]
    return delta


def encode(pack):
    """Deterministic gzip JSON bytes."""
    raw = json.dumps(pack, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    buffer = io.BytesIO()
    with gzip.GzipFile(fileobj=buffer, mode="wb", mtime=0, filename="") as handle:
        handle.write(raw.encode("utf-8"))
    return buffer.getvalue()


def decode(data):
    return json.loads(gzip.decompress(data).decode("utf-8"))


def _entry(pack, url, data):
    entry = {
        "version": pack["version"],
        "kind": pack["kind"],
        "url": url,
        "sha256": hashlib.sha256(data).hexdigest(),
        "bytes": len(data),
    }
    if pack["kind"] == "delta":
        entry["base"] = pack["base"]
    return entry


def _manifest_text(latest, entries):
    manifest = {
        "format": FORMAT,
        "latest": latest,
        "min_app_build": MIN_APP_BUILD,
        "packs": entries,
    }
    return json.dumps(manifest, indent=2, sort_keys=True) + "\n"


def spotcheck_csv(pack, count=50, seed=SPOTCHECK_SEED):
    """[count] random active foods per serving, for a check against a reference.

    The values are IndiFit estimates; the empty columns are for the reviewer.
    """
    retired = {entry["id"] for entry in pack["retire"]}
    active = [food for food in pack["foods"] if food["id"] not in retired]
    sample = sorted(random.Random(seed).sample(active, count), key=lambda f: f["id"])
    buffer = io.StringIO()
    writer = csv.writer(buffer, lineterminator="\n")
    writer.writerow(
        [
            "id",
            "food",
            "serving",
            "grams_per_serving",
            "grams_basis",
            "kcal",
            "protein_g",
            "carbs_g",
            "fat_g",
            "fibre_g",
            "values",
            "reference_source",
            "reference_kcal",
            "reference_protein_g",
            "reference_carbs_g",
            "reference_fat_g",
            "verdict",
            "notes",
        ]
    )
    for food in sample:
        serving = food["servings"][0]
        values = food["facts"]["values"]
        scale = serving["grams"] / 100 if food["facts"]["basis"] == "per_100_grams" else 1
        unit = serving["unit"]
        writer.writerow(
            [
                food["id"],
                food["display_name"],
                f"{serving['amount']:g} {unit}",
                "" if serving.get("grams") is None else f"{serving['grams']:g}",
                serving.get("grams_basis", ""),
                *(
                    f"{values.get(key, 0) * scale:.1f}".rstrip("0").rstrip(".")
                    for key in ("energy", "protein", "carbohydrate", "fat", "fibre")
                ),
                "IndiFit estimate (unreviewed)",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
            ]
        )
    return buffer.getvalue()


def build_outputs():
    """{path: bytes} for every file this script owns, plus the packs."""
    rows = load_source_rows()
    packs = {version: build_pack(version, rows) for version in range(1, LATEST + 1)}
    outputs = {}
    hosted = []
    for version, pack in packs.items():
        data = encode(pack)
        url = f"v{version}/{version}.json.gz"
        outputs[PACKS / url] = data
        hosted.append(_entry(pack, url, data))
        if version > 1:
            delta = build_delta(packs[version - 1], pack)
            delta_data = encode(delta)
            delta_url = f"v{version}/{version}-from-{version - 1}.json.gz"
            outputs[PACKS / delta_url] = delta_data
            hosted.append(_entry(delta, delta_url, delta_data))
    hosted.sort(key=lambda e: (-e["version"], e["kind"] != "full", e.get("base", 0)))
    outputs[PACKS / "manifest.json"] = _manifest_text(LATEST, hosted).encode()

    bundled = outputs[PACKS / f"v{LATEST}/{LATEST}.json.gz"]
    bundled_url = f"pack-{LATEST}.json.gz"
    outputs[ASSETS / bundled_url] = bundled
    outputs[ASSETS / "manifest.json"] = _manifest_text(
        LATEST, [_entry(packs[LATEST], bundled_url, bundled)]
    ).encode()
    outputs[SPOTCHECK] = spotcheck_csv(packs[LATEST]).encode()
    return outputs, packs


def stale_outputs(outputs):
    stale = [p for p, data in outputs.items() if not p.exists() or p.read_bytes() != data]
    owned = set(outputs)
    extra = [
        p
        for directory in (PACKS, ASSETS)
        if directory.exists()
        for p in directory.rglob("*")
        if p.is_file() and p not in owned
    ]
    return stale, extra


def main(argv):
    outputs, packs = build_outputs()
    if "--check" in argv:
        stale, extra = stale_outputs(outputs)
        for path in stale:
            print(f"stale: {path.relative_to(ROOT)}")
        for path in extra:
            print(f"not built by build.py: {path.relative_to(ROOT)}")
        if stale or extra:
            print("Catalogue packs are stale; run python3 tool/catalog/build.py")
            return 1
        print(f"Catalogue packs are current (latest v{LATEST}).")
        return 0
    _, extra = stale_outputs(outputs)
    for path in extra:
        path.unlink()
    for path, data in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    for path in sorted(outputs):
        print(f"wrote {path.relative_to(ROOT)} ({len(outputs[path])} bytes)")
    latest = packs[LATEST]
    active = sum(1 for food in latest["foods"] if food["lifecycle"] == "active")
    print(f"pack v{LATEST}: {len(latest['foods'])} foods, {active} active")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except BuildError as error:
        sys.exit(f"build.py: {error}")
