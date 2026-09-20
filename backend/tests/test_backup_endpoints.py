import base64
import hashlib
import os
import unittest

os.environ.setdefault("INDIFIT_API_KEY", "backend-test-secret")

from fastapi.testclient import TestClient
from backend import main


class CloudBackupEndpointTests(unittest.TestCase):
    api_key = "backend-test-secret"

    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(main.app)

    def setUp(self):
        main.INDIFIT_API_KEY = self.api_key
        main.USER_BACKUPS.clear()
        main.BACKUP_BLOBS.clear()

    def test_upload_and_list_backup_snapshot(self):
        payload_bytes = b"encrypted-blob-data-v10"
        payload_b64 = base64.b64encode(payload_bytes).decode("ascii")
        checksum = hashlib.sha256(payload_bytes).hexdigest()

        upload_req = {
            "snapshotId": "snap-test-01",
            "ciphertextBase64": payload_b64,
            "wrappedKeyBase64": "d3JhcHBlZC1rZXk=",
            "sha256Checksum": checksum,
            "byteSize": len(payload_bytes),
            "schemaVersion": 20,
            "backupFormatVersion": 10,
            "deviceName": "iPhone 15 Pro",
            "isWeeklyMilestone": False,
        }

        # Upload snapshot
        res = self.client.post(
            "/v1/backup/snapshots",
            json=upload_req,
            headers={"Authorization": "Bearer test-user-token-123"},
        )
        self.assertEqual(res.status_code, 201)
        data = res.json()
        self.assertEqual(data["snapshotId"], "snap-test-01")
        self.assertEqual(data["schemaVersion"], 20)

        # List snapshots
        list_res = self.client.get(
            "/v1/backup/snapshots",
            headers={"Authorization": "Bearer test-user-token-123"},
        )
        self.assertEqual(list_res.status_code, 200)
        list_data = list_res.json()
        self.assertEqual(list_data["totalCount"], 1)
        self.assertEqual(list_data["snapshots"][0]["snapshotId"], "snap-test-01")

        # Download snapshot
        dl_res = self.client.get(
            "/v1/backup/snapshots/snap-test-01",
            headers={"Authorization": "Bearer test-user-token-123"},
        )
        self.assertEqual(dl_res.status_code, 200)
        self.assertEqual(dl_res.json()["ciphertextBase64"], payload_b64)

    def test_upload_rejects_corrupted_checksum(self):
        payload_bytes = b"authentic-data"
        payload_b64 = base64.b64encode(payload_bytes).decode("ascii")

        upload_req = {
            "snapshotId": "snap-corrupt",
            "ciphertextBase64": payload_b64,
            "wrappedKeyBase64": "d3JhcHBlZA==",
            "sha256Checksum": "invalid-wrong-checksum",
            "byteSize": len(payload_bytes),
            "schemaVersion": 20,
            "backupFormatVersion": 10,
            "deviceName": "Pixel 8",
        }

        res = self.client.post(
            "/v1/backup/snapshots",
            json=upload_req,
            headers={"Authorization": "Bearer test-user-corrupt"},
        )
        self.assertEqual(res.status_code, 400)
        self.assertIn("checksum mismatch", res.json()["detail"].lower())

    def test_upload_requires_authentication(self):
        payload_bytes = b"auth-required"
        payload_b64 = base64.b64encode(payload_bytes).decode("ascii")
        checksum = hashlib.sha256(payload_bytes).hexdigest()
        upload_req = {
            "snapshotId": "snap-noauth",
            "ciphertextBase64": payload_b64,
            "wrappedKeyBase64": "d3JhcA==",
            "sha256Checksum": checksum,
            "byteSize": len(payload_bytes),
            "schemaVersion": 20,
            "backupFormatVersion": 10,
            "deviceName": "Device",
        }
        res = self.client.post("/v1/backup/snapshots", json=upload_req)
        self.assertEqual(res.status_code, 401)

    def test_upload_is_idempotent_on_retry(self):
        token = "Bearer test-user-idempotent"
        data = b"idempotent-blob"
        b64 = base64.b64encode(data).decode("ascii")
        h = hashlib.sha256(data).hexdigest()
        req = {
            "snapshotId": "snap-idem-01",
            "ciphertextBase64": b64,
            "wrappedKeyBase64": "d3JhcA==",
            "sha256Checksum": h,
            "byteSize": len(data),
            "schemaVersion": 20,
            "backupFormatVersion": 10,
            "deviceName": "Device",
        }
        first = self.client.post("/v1/backup/snapshots", json=req, headers={"Authorization": token})
        self.assertIn(first.status_code, (200, 201))
        second = self.client.post("/v1/backup/snapshots", json=req, headers={"Authorization": token})
        self.assertEqual(second.status_code, 200)
        listed = self.client.get("/v1/backup/snapshots", headers={"Authorization": token}).json()
        self.assertEqual(listed["totalCount"], 1)

    def test_pruning_caps_daily_snapshots_at_five(self):
        token = "Bearer test-user-retention"
        for i in range(8):
            data = f"blob-{i}".encode("utf-8")
            b64 = base64.b64encode(data).decode("ascii")
            h = hashlib.sha256(data).hexdigest()
            req = {
                "snapshotId": f"snap-{i}",
                "ciphertextBase64": b64,
                "wrappedKeyBase64": "d3JhcA==",
                "sha256Checksum": h,
                "byteSize": len(data),
                "schemaVersion": 20,
                "backupFormatVersion": 10,
                "deviceName": "Test Device",
                "isWeeklyMilestone": False,
            }
            res = self.client.post("/v1/backup/snapshots", json=req, headers={"Authorization": token})
            self.assertEqual(res.status_code, 201)

        # After uploading 8 daily snapshots, server should retain only newest 5!
        list_res = self.client.get("/v1/backup/snapshots", headers={"Authorization": token})
        self.assertEqual(list_res.status_code, 200)
        snapshots = list_res.json()["snapshots"]
        self.assertEqual(len(snapshots), 5)
        # Newest should be snap-7, snap-6, snap-5, snap-4, snap-3
        ids = [s["snapshotId"] for s in snapshots]
        self.assertEqual(ids, ["snap-7", "snap-6", "snap-5", "snap-4", "snap-3"])

    def test_delete_single_snapshot_keeps_siblings(self):
        token = "Bearer test-user-single-delete"

        def upload(snap_id):
            data = f"blob-{snap_id}".encode("utf-8")
            b64 = base64.b64encode(data).decode("ascii")
            return {
                "snapshotId": snap_id,
                "ciphertextBase64": b64,
                "wrappedKeyBase64": "d3JhcA==",
                "sha256Checksum": hashlib.sha256(data).hexdigest(),
                "byteSize": len(data),
                "schemaVersion": 20,
                "backupFormatVersion": 10,
                "deviceName": "Device",
            }

        self.client.post("/v1/backup/snapshots", json=upload("snap-a"), headers={"Authorization": token})
        self.client.post("/v1/backup/snapshots", json=upload("snap-b"), headers={"Authorization": token})

        # Exact-vs-param routing: single delete must not match the bulk route.
        del_res = self.client.delete("/v1/backup/snapshots/snap-a", headers={"Authorization": token})
        self.assertEqual(del_res.status_code, 204)

        remaining = self.client.get("/v1/backup/snapshots", headers={"Authorization": token}).json()
        self.assertEqual([s["snapshotId"] for s in remaining["snapshots"]], ["snap-b"])

        # Deleting a missing id is still a no-op success.
        missing = self.client.delete("/v1/backup/snapshots/nope", headers={"Authorization": token})
        self.assertEqual(missing.status_code, 204)

    def test_delete_all_cloud_backups(self):
        token = "Bearer test-user-delete"
        data = b"sample"
        b64 = base64.b64encode(data).decode("ascii")
        h = hashlib.sha256(data).hexdigest()
        req = {
            "snapshotId": "snap-delete-me",
            "ciphertextBase64": b64,
            "wrappedKeyBase64": "d3JhcA==",
            "sha256Checksum": h,
            "byteSize": len(data),
            "schemaVersion": 20,
            "backupFormatVersion": 10,
            "deviceName": "Device",
        }
        self.client.post("/v1/backup/snapshots", json=req, headers={"Authorization": token})
        self.assertEqual(len(self.client.get("/v1/backup/snapshots", headers={"Authorization": token}).json()["snapshots"]), 1)

        # Purge all
        del_res = self.client.delete("/v1/backup/snapshots", headers={"Authorization": token})
        self.assertEqual(del_res.status_code, 204)
        self.assertEqual(len(self.client.get("/v1/backup/snapshots", headers={"Authorization": token}).json()["snapshots"]), 0)


if __name__ == "__main__":
    unittest.main()
