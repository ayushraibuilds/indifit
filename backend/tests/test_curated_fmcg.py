import json
from pathlib import Path
import pytest


def _load_fmcg_manifest():
    manifest_path = Path(__file__).resolve().parent.parent / "data" / "curated_fmcg_manifest.json"
    assert manifest_path.is_file(), f"FMCG manifest not found at {manifest_path}"
    with open(manifest_path, "r", encoding="utf-8") as f:
        return json.load(f)


def test_fmcg_manifest_metadata_and_odbl_license():
    data = _load_fmcg_manifest()
    assert "_metadata" in data, "Missing _metadata section in FMCG manifest"
    meta = data["_metadata"]
    assert "license" in meta and "ODbL" in meta["license"]
    assert "attribution" in meta and "Open Food Facts" in meta["attribution"]
    assert len(data.get("items", [])) >= 35, "Manifest must contain at least 35 curated items"


def test_fmcg_manifest_atwater_4_4_9_consistency():
    """
    Every item in the curated FMCG seed must satisfy Atwater 4-4-9 rules:
    1. Sum of macronutrients (protein + carbs + fat) <= 105g per 100g (allowing moisture/analytical variance)
    2. Declared energy must match 4*P + 4*C + 9*F within 20% tolerance
    """
    data = _load_fmcg_manifest()
    items = data["items"]
    assert len(items) >= 35

    violations = []
    for item in items:
        name = item.get("name", "Unknown")
        barcode = item.get("barcode", "No barcode")
        protein = float(item.get("protein_g", 0.0))
        carbs = float(item.get("carbs_g", 0.0))
        fat = float(item.get("fat_g", 0.0))
        calories = float(item.get("calories", 0.0))

        # 1. Total macro check
        total_macros = protein + carbs + fat
        if total_macros > 105.0:
            violations.append(
                f"{name} ({barcode}): Total macros {total_macros:.1f}g exceeds 105g/100g ceiling"
            )

        # 2. Atwater energy check
        expected_cals = (4.0 * protein) + (4.0 * carbs) + (9.0 * fat)
        if calories > 0:
            diff = abs(expected_cals - calories) / calories
            if diff > 0.20:
                violations.append(
                    f"{name} ({barcode}): Calorie deviation {diff:.1%} exceeds 20% (expected {expected_cals:.1f}, declared {calories:.1f})"
                )

        # 3. Barcode and serving options
        assert barcode and len(barcode) in (8, 12, 13, 14), f"Invalid GTIN barcode {barcode} for {name}"
        assert "serving_options" in item and len(item["serving_options"]) > 0, f"Missing serving_options for {name}"
        assert any(opt.get("is_default") is True for opt in item["serving_options"]), f"No default serving option for {name}"

    assert not violations, "Atwater 4-4-9 violations found:\n" + "\n".join(violations)
