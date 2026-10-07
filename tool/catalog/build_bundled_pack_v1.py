#!/usr/bin/env python3
"""Builds catalogue pack v1 from today's bundled food assets (CAT-3).

Pack v1 is the current catalogue as it is: the same values that the legacy
`food_items` adapter used, with every food keyed by its stable manifest id.
Data fixes (audit C-04, C-09) and gram weights arrive later as pack v2 from
the CAT-5 pipeline; this script only exists to produce the first pack.

Usage:
    python3 tool/catalog/build_bundled_pack_v1.py          # write the pack
    python3 tool/catalog/build_bundled_pack_v1.py --check  # fail if stale

Outputs (both committed):
    assets/catalog/pack-1.json.gz   gzip JSON, deterministic bytes
    assets/catalog/manifest.json    the bundled manifest (version, sha256)
"""

import gzip
import hashlib
import io
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FOODS = ROOT / "assets/data/indian_foods.json"
MANIFEST = ROOT / "assets/data/nutrition_food_identity_manifest.json"
REGISTRY = ROOT / "assets/data/nutrient_registry.json"
OUT_DIR = ROOT / "assets/catalog"
PACK_VERSION = 1
SOURCE_ID = "indifit-catalogue-v1"

GRAM_UNITS = {"g": 1.0, "gram": 1.0, "grams": 1.0, "kg": 1000.0}
MILLILITRE_UNITS = {"ml": 1.0, "millilitre": 1.0, "l": 1000.0, "litre": 1000.0}


def _round(value):
    # Mirrors the legacy adapter: values are bounded to 6 decimals before they
    # enter the exact decimal contract, so pack facts equal the facts the app
    # wrote lazily before packs existed.
    return float(f"{value:.6f}")


def _food(row, food_id):
    unit = row["serving_unit"].strip().lower()
    size = float(row["serving_size"])
    values = {
        "energy": float(row["calories"]),
        "protein": float(row["protein_g"]),
        "carbohydrate": float(row["carbs_g"]),
        "fat": float(row["fat_g"]),
        "fibre": float(row["fiber_g"]),
    }
    if unit in GRAM_UNITS:
        grams = size * GRAM_UNITS[unit]
        basis = "per_100_grams"
        values = {k: _round(v * 100 / grams) for k, v in values.items()}
        serving = {"unit": "g", "amount": grams, "grams": grams}
    elif unit in MILLILITRE_UNITS:
        millilitres = size * MILLILITRE_UNITS[unit]
        basis = "per_100_millilitres"
        values = {k: _round(v * 100 / millilitres) for k, v in values.items()}
        serving = {"unit": "ml", "amount": millilitres, "grams": None}
    else:
        basis = "per_serving"
        values = {k: _round(v) for k, v in values.items()}
        serving = {"unit": unit, "amount": size, "grams": None}
    return {
        "id": food_id,
        "display_name": row["name"],
        "source_ref": "asset:base:" + row["name"].lower(),
        "category": row["category"],
        "source_id": SOURCE_ID,
        "facts": {"basis": basis, "values": values},
        "servings": [{"id": "default", "default": True, **serving}],
    }


def build():
    foods = json.loads(FOODS.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    by_source = {m["source_key"]: m["target_id"] for m in manifest["legacy_mappings"]}
    entries = {e["id"] for e in manifest["entries"]}

    pack_foods = []
    seen = set()
    for row in foods:
        key = "asset:base:" + row["name"].lower()
        food_id = by_source.get(key)
        if food_id is None or food_id not in entries:
            sys.exit(f"No manifest identity for {row['name']!r}")
        if food_id in seen:
            sys.exit(f"Two catalogue rows map to {food_id}")
        seen.add(food_id)
        pack_foods.append(_food(row, food_id))
    pack_foods.sort(key=lambda food: food["id"])

    pack = {
        "format": 1,
        "version": PACK_VERSION,
        "base": None,
        "kind": "full",
        "min_app_build": 1,
        "registry_version": str(registry["registry_version"]),
        "sources": [
            {
                "id": SOURCE_ID,
                "licence": "proprietary",
                "attribution": None,
                "review": "unreviewed",
            }
        ],
        "foods": pack_foods,
        "retire": [],
    }
    raw = json.dumps(pack, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    buffer = io.BytesIO()
    with gzip.GzipFile(fileobj=buffer, mode="wb", mtime=0, filename="") as handle:
        handle.write(raw.encode("utf-8"))
    pack_bytes = buffer.getvalue()
    bundled_manifest = {
        "format": 1,
        "latest": PACK_VERSION,
        "min_app_build": 1,
        "packs": [
            {
                "version": PACK_VERSION,
                "kind": "full",
                "url": f"pack-{PACK_VERSION}.json.gz",
                "sha256": hashlib.sha256(pack_bytes).hexdigest(),
                "bytes": len(pack_bytes),
            }
        ],
    }
    manifest_text = json.dumps(bundled_manifest, indent=2, sort_keys=True) + "\n"
    return pack_bytes, manifest_text, len(pack_foods)


def main():
    pack_bytes, manifest_text, count = build()
    pack_path = OUT_DIR / f"pack-{PACK_VERSION}.json.gz"
    manifest_path = OUT_DIR / "manifest.json"
    if "--check" in sys.argv:
        stale = (
            not pack_path.exists()
            or pack_path.read_bytes() != pack_bytes
            or not manifest_path.exists()
            or manifest_path.read_text(encoding="utf-8") != manifest_text
        )
        if stale:
            sys.exit("Bundled catalogue pack is stale; run build_bundled_pack_v1.py")
        print(f"Bundled pack v{PACK_VERSION} is current ({count} foods).")
        return
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    pack_path.write_bytes(pack_bytes)
    manifest_path.write_text(manifest_text, encoding="utf-8")
    print(f"Wrote {pack_path.relative_to(ROOT)} ({len(pack_bytes)} bytes, {count} foods)")


if __name__ == "__main__":
    main()
