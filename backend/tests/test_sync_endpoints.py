import os
import time
import pytest

os.environ.setdefault("INDIFIT_API_KEY", "backend-test-secret")

from fastapi.testclient import TestClient
from backend import main

client = TestClient(main.app)

@pytest.fixture(autouse=True)
def reset_sync_state():
    main.USER_MUTATIONS.clear()
    yield
    main.USER_MUTATIONS.clear()

def test_push_and_pull_mutations():
    now_millis = int(time.time() * 1000)

    mutation_1 = {
        "entity_id": "weight-101",
        "domain": "weights",
        "type": "insert",
        "hlc": {"millis": now_millis - 1000, "counter": 0, "node_id": "device-A"},
        "payload": {"weight_kg": 75.5},
    }
    mutation_2 = {
        "entity_id": "workout-202",
        "domain": "workouts",
        "type": "insert",
        "hlc": {"millis": now_millis - 500, "counter": 0, "node_id": "device-B"},
        "payload": {"exercise": "Squat"},
    }

    # 1. Push batch
    resp = client.post(
        "/v1/sync/mutations",
        headers={"Authorization": "Bearer test-user-1"},
        json={"mutations": [mutation_1, mutation_2]},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["accepted_count"] == 2
    assert data["server_received_hlc"]["node_id"] == "device-B"

    # 2. Pull deltas from beginning
    resp_pull = client.get(
        "/v1/sync/deltas",
        headers={"Authorization": "Bearer test-user-1"},
        params={"since_millis": 0, "since_counter": 0, "since_node_id": ""},
    )
    assert resp_pull.status_code == 200
    pull_data = resp_pull.json()
    assert len(pull_data["mutations"]) == 2
    assert pull_data["mutations"][0]["entity_id"] == "weight-101"
    assert pull_data["mutations"][1]["entity_id"] == "workout-202"
    assert pull_data["has_more"] is False

def test_push_deduplication_is_idempotent():
    now_millis = int(time.time() * 1000)

    mutation = {
        "entity_id": "weight-101",
        "domain": "weights",
        "type": "insert",
        "hlc": {"millis": now_millis - 1000, "counter": 0, "node_id": "device-A"},
        "payload": {"weight_kg": 75.5},
    }

    # Push 1
    resp1 = client.post(
        "/v1/sync/mutations",
        headers={"Authorization": "Bearer test-user-1"},
        json={"mutations": [mutation]},
    )
    assert resp1.status_code == 200
    assert resp1.json()["accepted_count"] == 1

    # Push 2 (exact duplicate)
    resp2 = client.post(
        "/v1/sync/mutations",
        headers={"Authorization": "Bearer test-user-1"},
        json={"mutations": [mutation]},
    )
    assert resp2.status_code == 200
    assert resp2.json()["accepted_count"] == 0

def test_clock_skew_rejection():
    now_millis = int(time.time() * 1000)

    future_mutation = {
        "entity_id": "skewed-item",
        "domain": "weights",
        "type": "insert",
        "hlc": {"millis": now_millis + 7200000, "counter": 0, "node_id": "skewed-clock-device"},
        "payload": {},
    }

    resp = client.post(
        "/v1/sync/mutations",
        headers={"Authorization": "Bearer test-user-1"},
        json={"mutations": [future_mutation]},
    )
    assert resp.status_code == 400
    assert "Clock skew exceeded" in resp.json()["detail"]

def test_pull_deltas_pagination_and_domain_filtering():
    now_millis = int(time.time() * 1000)

    mutations = [
        {
            "entity_id": f"item-{i}",
            "domain": "workouts" if i % 2 == 0 else "weights",
            "type": "insert",
            "hlc": {"millis": now_millis - 1000 + i, "counter": 0, "node_id": "node-1"},
            "payload": {"index": i},
        }
        for i in range(5)
    ]

    client.post(
        "/v1/sync/mutations",
        headers={"Authorization": "Bearer test-user-1"},
        json={"mutations": mutations},
    )

    # Pull with limit=2
    resp = client.get(
        "/v1/sync/deltas",
        headers={"Authorization": "Bearer test-user-1"},
        params={"limit": 2},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["mutations"]) == 2
    assert data["has_more"] is True

    # Pull with domain filter
    resp_domain = client.get(
        "/v1/sync/deltas",
        headers={"Authorization": "Bearer test-user-1"},
        params={"domain": "workouts"},
    )
    assert resp_domain.status_code == 200
    domain_data = resp_domain.json()
    assert all(m["domain"] == "workouts" for m in domain_data["mutations"])
    assert len(domain_data["mutations"]) == 3  # items 0, 2, 4

def test_sync_requires_authentication():
    resp = client.post("/v1/sync/mutations", json={"mutations": []})
    assert resp.status_code == 401
    resp2 = client.get("/v1/sync/deltas")
    assert resp2.status_code == 401

def test_push_is_atomic_on_clock_skew():
    import time as _time
    now_millis = int(_time.time() * 1000)
    good = {
        "entity_id": "good-item",
        "domain": "weights",
        "type": "insert",
        "hlc": {"millis": now_millis - 1000, "counter": 0, "node_id": "device-A"},
        "payload": {},
    }
    bad = {
        "entity_id": "skewed-item",
        "domain": "weights",
        "type": "insert",
        "hlc": {"millis": now_millis + 7200000, "counter": 0, "node_id": "device-A"},
        "payload": {},
    }
    resp = client.post(
        "/v1/sync/mutations",
        headers={"Authorization": "Bearer test-user-atomic"},
        json={"mutations": [good, bad]},
    )
    assert resp.status_code == 400
    pulled = client.get(
        "/v1/sync/deltas",
        headers={"Authorization": "Bearer test-user-atomic"},
        params={"since_millis": 0, "since_counter": 0, "since_node_id": ""},
    )
    assert pulled.status_code == 200
    assert pulled.json()["mutations"] == []


def test_push_oversize_encrypted_envelope_returns_413():
    import base64 as _b64
    import time as _time
    now_millis = int(_time.time() * 1000)
    oversize_raw = b"\x00" * (262144 + 1)
    mutation = {
        "entity_id": "enc-oversize-1",
        "domain": "weights",
        "type": "insert",
        "hlc": {"millis": now_millis - 1000, "counter": 0, "node_id": "device-A"},
        "payload": {"weight_kg": 75.5},
        "encrypted_envelope": {
            "mutation_id": "enc-oversize-1",
            "ciphertext_base64": _b64.b64encode(oversize_raw).decode("utf-8"),
            "wrapped_key_base64": _b64.b64encode(b"k" * 32).decode("utf-8"),
            "sha256_checksum": "deadbeef",
        },
    }
    resp = client.post(
        "/v1/sync/mutations",
        headers={"Authorization": "Bearer test-user-enc-oversize"},
        json={"mutations": [mutation]},
    )
    assert resp.status_code == 413


def test_push_malformed_encrypted_envelope_returns_400():
    import time as _time
    now_millis = int(_time.time() * 1000)

    def _base_mutation(envelope):
        return {
            "entity_id": "enc-malformed-1",
            "domain": "weights",
            "type": "insert",
            "hlc": {"millis": now_millis - 1000, "counter": 0, "node_id": "device-A"},
            "payload": {},
            "encrypted_envelope": envelope,
        }

    # Missing keys (no wrapped_key_base64 / sha256_checksum).
    resp_missing = client.post(
        "/v1/sync/mutations",
        headers={"Authorization": "Bearer test-user-enc-malformed"},
        json={"mutations": [_base_mutation({"ciphertext_base64": "aGVsbG8="})]},
    )
    assert resp_missing.status_code == 400

    # Bad base64 in both crypto fields.
    resp_bad_b64 = client.post(
        "/v1/sync/mutations",
        headers={"Authorization": "Bearer test-user-enc-malformed"},
        json={
            "mutations": [
                _base_mutation(
                    {
                        "mutation_id": "enc-malformed-1",
                        "ciphertext_base64": "!!!not-base64!!!",
                        "wrapped_key_base64": "%%%also-bad%%%",
                        "sha256_checksum": "deadbeef",
                    }
                )
            ]
        },
    )
    assert resp_bad_b64.status_code == 400


def test_encrypted_envelope_round_trip_is_byte_identical():
    import base64 as _b64
    import time as _time
    now_millis = int(_time.time() * 1000)
    envelope = {
        "mutation_id": "enc-roundtrip-1",
        "ciphertext_base64": _b64.b64encode(b"ciphertext-bytes-123").decode("utf-8"),
        "wrapped_key_base64": _b64.b64encode(b"wrapped-key-456").decode("utf-8"),
        "sha256_checksum": "abc123",
    }
    mutation = {
        "entity_id": "enc-roundtrip-1",
        "domain": "weights",
        "type": "insert",
        "hlc": {"millis": now_millis - 1000, "counter": 0, "node_id": "device-A"},
        "payload": {"weight_kg": 80.0},
        "encrypted_envelope": envelope,
    }
    resp = client.post(
        "/v1/sync/mutations",
        headers={"Authorization": "Bearer test-user-enc-roundtrip"},
        json={"mutations": [mutation]},
    )
    assert resp.status_code == 200
    assert resp.json()["accepted_count"] == 1

    pulled = client.get(
        "/v1/sync/deltas",
        headers={"Authorization": "Bearer test-user-enc-roundtrip"},
        params={"since_millis": 0, "since_counter": 0, "since_node_id": ""},
    )
    assert pulled.status_code == 200
    mutations = pulled.json()["mutations"]
    assert len(mutations) == 1
    assert mutations[0]["encrypted_envelope"] == envelope


def test_mixed_plaintext_and_encrypted_batch_accepted():
    import base64 as _b64
    import time as _time
    now_millis = int(_time.time() * 1000)
    plaintext = {
        "entity_id": "mixed-plain-1",
        "domain": "weights",
        "type": "insert",
        "hlc": {"millis": now_millis - 1000, "counter": 0, "node_id": "device-A"},
        "payload": {"weight_kg": 70.0},
    }
    encrypted = {
        "entity_id": "mixed-enc-1",
        "domain": "workouts",
        "type": "insert",
        "hlc": {"millis": now_millis - 500, "counter": 0, "node_id": "device-A"},
        "payload": {"exercise": "Squat"},
        "encrypted_envelope": {
            "mutation_id": "mixed-enc-1",
            "ciphertext_base64": _b64.b64encode(b"ct").decode("utf-8"),
            "wrapped_key_base64": _b64.b64encode(b"wk").decode("utf-8"),
            "sha256_checksum": "checksum-1",
        },
    }
    resp = client.post(
        "/v1/sync/mutations",
        headers={"Authorization": "Bearer test-user-enc-mixed"},
        json={"mutations": [plaintext, encrypted]},
    )
    assert resp.status_code == 200
    assert resp.json()["accepted_count"] == 2


def test_duplicate_encrypted_push_dedups():
    import base64 as _b64
    import time as _time
    now_millis = int(_time.time() * 1000)
    mutation = {
        "entity_id": "enc-dedup-1",
        "domain": "weights",
        "type": "insert",
        "hlc": {"millis": now_millis - 1000, "counter": 0, "node_id": "device-A"},
        "payload": {"weight_kg": 72.0},
        "encrypted_envelope": {
            "mutation_id": "enc-dedup-1",
            "ciphertext_base64": _b64.b64encode(b"ct-dedup").decode("utf-8"),
            "wrapped_key_base64": _b64.b64encode(b"wk-dedup").decode("utf-8"),
            "sha256_checksum": "checksum-dedup",
        },
    }
    headers = {"Authorization": "Bearer test-user-enc-dedup"}
    first = client.post(
        "/v1/sync/mutations", headers=headers, json={"mutations": [mutation]}
    )
    assert first.status_code == 200
    assert first.json()["accepted_count"] == 1
    replay = client.post(
        "/v1/sync/mutations", headers=headers, json={"mutations": [mutation]}
    )
    assert replay.status_code == 200
    assert replay.json()["accepted_count"] == 0
