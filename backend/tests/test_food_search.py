import hashlib
import json
import logging
import os
import pytest
from pathlib import Path
from fastapi.testclient import TestClient

os.environ.setdefault("INDIFIT_API_KEY", "backend-test-secret")

from backend.main import create_app
from backend.core.config import get_indifit_api_key
from backend.routers.food import (
    RETIRED_FOOD_NAMES,
    SEARCH_CACHE,
    clear_missed_searches,
    flush_missed_searches,
    get_missed_searches,
)


@pytest.fixture
def client():
    app = create_app()
    return TestClient(app)


def _auth_headers():
    return {"X-IndiFit-Key": get_indifit_api_key()}


def test_food_search_requires_authentication(client):
    res = client.post("/api/food/search", json={"query": "roti"})
    assert res.status_code in (401, 403)


def test_food_search_rejects_empty_or_whitespace_query(client):
    headers = _auth_headers()
    res = client.post("/api/food/search", json={"query": "   "}, headers=headers)
    assert res.status_code == 422


def test_food_search_rejects_invalid_page_and_limit(client):
    headers = _auth_headers()
    # page < 1
    res = client.post("/api/food/search", json={"query": "dal", "page": 0}, headers=headers)
    assert res.status_code == 422

    # limit < 1
    res = client.post("/api/food/search", json={"query": "dal", "limit": 0}, headers=headers)
    assert res.status_code == 422

    # limit > 50
    res = client.post("/api/food/search", json={"query": "dal", "limit": 51}, headers=headers)
    assert res.status_code == 422


def test_food_search_returns_ranked_results_for_exact_match(client):
    headers = _auth_headers()
    res = client.post("/api/food/search", json={"query": "Whole Wheat Roti / Chapati"}, headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["count"] > 0
    assert len(data["results"]) > 0
    first = data["results"][0]
    assert "roti" in first["name"].lower() or "chapati" in first["name"].lower()
    assert first["score"] == 100.0
    assert first["category_id"] == "staple_bread"
    assert first["calories"] > 0
    assert first["source"] == "curated"
    assert first["serving_options"] is not None
    assert len(first["serving_options"]) > 0


def test_food_search_total_hits_and_has_more(client):
    headers = _auth_headers()
    res = client.post("/api/food/search", json={"query": "dal", "limit": 2}, headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert len(data["results"]) == 2
    assert data["count"] == 2
    assert data["total_hits"] > 2
    assert data["has_more"] is True


def test_food_search_hinglish_transliteration_arhar_to_toor(client):
    headers = _auth_headers()
    # "arhar" is transliterated to "toor"
    res = client.post("/api/food/search", json={"query": "arhar"}, headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["transliterated_query"] == "toor"
    assert data["count"] > 0
    names = [r["name"].lower() for r in data["results"]]
    assert any("toor" in n or "arhar" in n or "dal" in n for n in names)
    first = data["results"][0]
    assert first["category_id"] == "dal_lentil"


def test_food_search_canonical_synonyms_tuvar_to_toor(client):
    headers = _auth_headers()
    res = client.post("/api/food/search", json={"query": "tuvar"}, headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["transliterated_query"] == "toor"
    assert data["count"] > 0


def test_food_search_in_memory_ttl_cache(client):
    headers = _auth_headers()
    query = "Toor Dal / Arhar Dal (Cooked)"
    # First call: populates cache
    res1 = client.post("/api/food/search", json={"query": query}, headers=headers)
    assert res1.status_code == 200
    data1 = res1.json()

    # Second call: must hit cache
    res2 = client.post("/api/food/search", json={"query": query}, headers=headers)
    assert res2.status_code == 200
    data2 = res2.json()

    assert data1 == data2
    assert len(SEARCH_CACHE) > 0


def test_food_search_curated_fmcg_discovery(client):
    headers = _auth_headers()
    res = client.post("/api/food/search", json={"query": "Epigamia Greek Yogurt"}, headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["count"] > 0
    epigamia_items = [r for r in data["results"] if r.get("brand") == "Epigamia"]
    assert len(epigamia_items) > 0
    first = epigamia_items[0]
    assert first["provenance"] == "verified_fmcg"
    assert first["serving_options"] is not None
    assert any(opt.get("is_default") is True for opt in first["serving_options"])


def test_food_search_truth_contract_missing_sodium_is_null(client):
    headers = _auth_headers()
    res = client.post("/api/food/search", json={"query": "roti"}, headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert len(data["results"]) > 0
    # Seed data doesn't have sodium_mg; verify it is None (null in JSON), NOT 0.0
    first = data["results"][0]
    assert first["sodium_mg"] is None


def test_food_search_pagination_limit(client):
    headers = _auth_headers()
    res = client.post("/api/food/search", json={"query": "dal", "limit": 3}, headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert len(data["results"]) <= 3
    assert data["count"] <= 3


def test_retired_food_names_match_the_app_manifest():
    manifest_path = Path(__file__).resolve().parents[2] / "assets/data/nutrition_food_identity_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    deprecated = {
        entry["display_name"]
        for entry in manifest["entries"]
        if entry["deprecated"] and entry["id"].startswith("food-seed-")
    }
    assert RETIRED_FOOD_NAMES == deprecated


def test_food_search_excludes_retired_foods(client):
    headers = _auth_headers()
    for query, kept in [
        ("Toned Milk", "Toned Milk (1 Glass)"),
        ("Lassi", "Masala Lassi (Sweet)"),
        ("Paneer", "Amul Fresh Paneer (Raw)"),
        ("Dal Tadka", "Toor Dal / Yellow Dal Tadka"),
    ]:
        res = client.post("/api/food/search", json={"query": query, "limit": 50}, headers=headers)
        assert res.status_code == 200
        names = {r["name"] for r in res.json()["results"]}
        assert kept in names, query
        assert names.isdisjoint(RETIRED_FOOD_NAMES), f"{query!r}: {names & RETIRED_FOOD_NAMES}"


def test_food_search_logs_zero_results_anonymously_without_pii(client, caplog):
    headers = _auth_headers()
    clear_missed_searches()

    with caplog.at_level(logging.INFO):
        res = client.post(
            "/api/food/search",
            json={"query": "xylophonemealunknownxyz123"},
            headers=headers,
        )
    assert res.status_code == 200
    data = res.json()
    assert data["count"] == 0
    assert data["total_hits"] == 0

    # Verify structured stdout log for Render log drains (hash only)
    assert any("event=missed_search" in record.message for record in caplog.records)
    expected_hash = hashlib.sha256("xylophonemealunknownxyz123".encode("utf-8")).hexdigest()
    assert any(f"query_hash={expected_hash}" in record.message for record in caplog.records)
    assert not any("xylophonemealunknownxyz123" in record.message for record in caplog.records)

    missed = get_missed_searches()
    assert len(missed) > 0
    latest = missed[-1]
    assert latest["query_hash"] == expected_hash
    assert "query" not in latest
    assert "transliterated" not in latest
    assert "timestamp_utc" in latest
    # Verify no IP address or personal user info was captured
    assert "ip" not in latest
    assert "user_id" not in latest
    assert "client_ip" not in latest

    # Verify flush to disk (hash only, zero raw queries), clean up test file
    data_dir = Path(__file__).resolve().parent.parent / "data"
    missed_file = data_dir / "missed_searches.jsonl"
    try:
        flush_missed_searches()
        assert missed_file.is_file()
        content = missed_file.read_text(encoding="utf-8")
        assert expected_hash in content
        assert "xylophonemealunknownxyz123" not in content
    finally:
        if missed_file.exists():
            missed_file.unlink()
