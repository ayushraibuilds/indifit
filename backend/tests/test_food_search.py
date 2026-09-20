import os
import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("INDIFIT_API_KEY", "backend-test-secret")

from backend.main import create_app
from backend.core.config import get_indifit_api_key
from backend.routers.food import clear_missed_searches, get_missed_searches


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


def test_food_search_logs_zero_results_anonymously_without_pii(client):
    headers = _auth_headers()
    clear_missed_searches()

    res = client.post(
        "/api/food/search",
        json={"query": "xylophonemealunknownxyz123"},
        headers=headers,
    )
    assert res.status_code == 200
    data = res.json()
    assert data["count"] == 0

    missed = get_missed_searches()
    assert len(missed) > 0
    latest = missed[-1]
    assert latest["query"] == "xylophonemealunknownxyz123"
    assert "timestamp_utc" in latest
    # Verify no IP address or personal user info was captured
    assert "ip" not in latest
    assert "user_id" not in latest
    assert "client_ip" not in latest
