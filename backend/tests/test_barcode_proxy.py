import hashlib
import os
import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("INDIFIT_API_KEY", "backend-test-secret")

from backend.main import create_app
from backend.core.config import get_indifit_api_key
from backend.routers.food import BARCODE_CACHE, clear_missed_searches, get_missed_searches


@pytest.fixture
def client():
    app = create_app()
    return TestClient(app)


def _auth_headers():
    return {"X-IndiFit-Key": get_indifit_api_key()}


def test_barcode_lookup_requires_authentication(client):
    res = client.get("/api/food/barcode/8901262010053")
    assert res.status_code in (401, 403)


def test_barcode_lookup_rejects_invalid_format(client):
    headers = _auth_headers()
    # Non-digit
    res = client.get("/api/food/barcode/notadigit123", headers=headers)
    assert res.status_code == 422

    # Too short (< 8 digits)
    res = client.get("/api/food/barcode/12345", headers=headers)
    assert res.status_code == 422

    # Too long (> 14 digits)
    res = client.get("/api/food/barcode/1234567890123456", headers=headers)
    assert res.status_code == 422


def test_barcode_lookup_matches_curated_fmcg_item(client):
    headers = _auth_headers()
    # 8901262010053 is Amul High Protein Lassi
    res = client.get("/api/food/barcode/8901262010053", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["barcode"] == "8901262010053"
    candidate = data["candidate"]
    assert candidate is not None
    assert "Amul High Protein Lassi" in candidate["name"]
    assert candidate["brand"] == "Amul"
    assert candidate["category_id"] == "dairy_liquid"
    assert candidate["calories"] == 65.0
    assert candidate["protein_g"] == 7.5
    assert candidate["provenance"] == "verified_fmcg"
    assert candidate["serving_options"] is not None
    assert len(candidate["serving_options"]) > 0


def test_barcode_lookup_in_memory_ttl_cache(client):
    headers = _auth_headers()
    code = "8906059630018"  # Epigamia Greek Yogurt (Natural)
    # 1st call
    res1 = client.get(f"/api/food/barcode/{code}", headers=headers)
    assert res1.status_code == 200
    data1 = res1.json()

    # Verify populated in BARCODE_CACHE
    assert code in BARCODE_CACHE

    # 2nd call hits cache
    res2 = client.get(f"/api/food/barcode/{code}", headers=headers)
    assert res2.status_code == 200
    data2 = res2.json()
    assert data1 == data2


def test_barcode_lookup_not_found_logs_missed_search_and_404(client):
    headers = _auth_headers()
    clear_missed_searches()
    # Barcode that definitely does not exist
    code = "0000000000000"
    res = client.get(f"/api/food/barcode/{code}", headers=headers)
    assert res.status_code == 404

    # Assert logged to missed searches ring buffer (hash-only)
    missed = get_missed_searches()
    assert len(missed) > 0
    expected_hash = hashlib.sha256(f"barcode:{code}".encode("utf-8")).hexdigest()
    assert any(m.get("query_hash") == expected_hash for m in missed)
