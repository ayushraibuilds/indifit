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
        headers={"x-indifit-user-id": "test-user-1"},
        json={"mutations": [mutation_1, mutation_2]},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["accepted_count"] == 2
    assert data["server_received_hlc"]["node_id"] == "device-B"

    # 2. Pull deltas from beginning
    resp_pull = client.get(
        "/v1/sync/deltas",
        headers={"x-indifit-user-id": "test-user-1"},
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
        headers={"x-indifit-user-id": "test-user-1"},
        json={"mutations": [mutation]},
    )
    assert resp1.status_code == 200
    assert resp1.json()["accepted_count"] == 1

    # Push 2 (exact duplicate)
    resp2 = client.post(
        "/v1/sync/mutations",
        headers={"x-indifit-user-id": "test-user-1"},
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
        headers={"x-indifit-user-id": "test-user-1"},
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
        headers={"x-indifit-user-id": "test-user-1"},
        json={"mutations": mutations},
    )

    # Pull with limit=2
    resp = client.get(
        "/v1/sync/deltas",
        headers={"x-indifit-user-id": "test-user-1"},
        params={"limit": 2},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["mutations"]) == 2
    assert data["has_more"] is True

    # Pull with domain filter
    resp_domain = client.get(
        "/v1/sync/deltas",
        headers={"x-indifit-user-id": "test-user-1"},
        params={"domain": "workouts"},
    )
    assert resp_domain.status_code == 200
    domain_data = resp_domain.json()
    assert all(m["domain"] == "workouts" for m in domain_data["mutations"])
    assert len(domain_data["mutations"]) == 3  # items 0, 2, 4
