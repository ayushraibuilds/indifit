import base64
import hashlib
import time
from typing import Any, Dict, List
from fastapi import APIRouter, Depends, HTTPException, Response, status
from backend.core.security import _get_backup_user_id
from backend.schemas.backup import BackupSnapshotUploadRequest

USER_BACKUPS: Dict[str, List[Dict[str, Any]]] = {}
BACKUP_BLOBS: Dict[tuple, Dict[str, Any]] = {}

backup_router = APIRouter(prefix="/v1/backup", tags=["Cloud Backup"])


def _prune_user_snapshots(user_id: str):
    snapshots = USER_BACKUPS.get(user_id, [])
    dailies = [s for s in snapshots if not s.get("isWeeklyMilestone")]
    weeklies = [s for s in snapshots if s.get("isWeeklyMilestone")]
    to_prune = set()

    if len(dailies) > 5:
        to_prune.update(s["snapshotId"] for s in dailies[5:])
    if len(weeklies) > 3:
        to_prune.update(s["snapshotId"] for s in weeklies[3:])

    if to_prune:
        USER_BACKUPS[user_id] = [s for s in snapshots if s["snapshotId"] not in to_prune]
        for snap_id in to_prune:
            BACKUP_BLOBS.pop((user_id, snap_id), None)


@backup_router.post("/snapshots", status_code=status.HTTP_201_CREATED)
async def upload_backup_snapshot(
    req: BackupSnapshotUploadRequest,
    response: Response,
    user_id: str = Depends(_get_backup_user_id),
):
    # Field validation (fail closed with 400/422, never 500)
    snapshot_id = (req.snapshotId or "").strip()
    if not snapshot_id or len(snapshot_id) > 128:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid snapshotId: must be 1-128 characters.",
        )
    if not req.deviceName or len(req.deviceName) > 128:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid deviceName: must be 1-128 characters.",
        )
    if req.schemaVersion < 1 or req.schemaVersion > 99:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid schemaVersion: must be 1-99.",
        )
    if req.backupFormatVersion < 1 or req.backupFormatVersion > 20:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid backupFormatVersion: must be 1-20.",
        )
    if req.byteSize <= 0 or req.byteSize > 5 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Invalid byteSize: must be 1-5242880 bytes (5 MB max).",
        )
    try:
        ciphertext_bytes = base64.b64decode(req.ciphertextBase64, validate=True)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid ciphertextBase64: not valid base64.",
        )
    try:
        base64.b64decode(req.wrappedKeyBase64, validate=True)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid wrappedKeyBase64: not valid base64.",
        )
    if len(ciphertext_bytes) > 5 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Backup blob exceeds maximum upload limit of 5 MB.",
        )
    if req.byteSize != len(ciphertext_bytes):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="byteSize does not match decoded ciphertext length.",
        )
    # Verify SHA-256 integrity
    computed_hash = hashlib.sha256(ciphertext_bytes).hexdigest()
    if req.sha256Checksum and computed_hash != req.sha256Checksum:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Payload checksum mismatch. The uploaded blob is corrupted.",
        )

    if user_id not in USER_BACKUPS:
        USER_BACKUPS[user_id] = []

    # Idempotent upsert by snapshotId
    for existing in USER_BACKUPS[user_id]:
        if existing["snapshotId"] == snapshot_id:
            existing_blob = BACKUP_BLOBS.get((user_id, snapshot_id))
            if existing_blob is not None and existing_blob.get("sha256Checksum") != req.sha256Checksum:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Snapshot '{snapshot_id}' already exists with different content.",
                )
            response.status_code = status.HTTP_200_OK
            return existing

    now_iso = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    summary = {
        "snapshotId": snapshot_id,
        "createdAtUtc": now_iso,
        "byteSize": req.byteSize,
        "schemaVersion": req.schemaVersion,
        "backupFormatVersion": req.backupFormatVersion,
        "deviceName": req.deviceName,
        "isWeeklyMilestone": req.isWeeklyMilestone,
    }

    # Insert newest at front
    USER_BACKUPS[user_id].insert(0, summary)
    BACKUP_BLOBS[(user_id, snapshot_id)] = {
        "ciphertextBase64": req.ciphertextBase64,
        "wrappedKeyBase64": req.wrappedKeyBase64,
        "sha256Checksum": req.sha256Checksum,
    }

    # Apply 5+3 retention pruning
    _prune_user_snapshots(user_id)

    return summary


@backup_router.get("/snapshots")
async def list_backup_snapshots(user_id: str = Depends(_get_backup_user_id)):
    snapshots = USER_BACKUPS.get(user_id, [])
    total_bytes = sum(s.get("byteSize", 0) for s in snapshots)
    return {
        "snapshots": snapshots,
        "totalCount": len(snapshots),
        "totalStorageBytes": total_bytes,
    }


@backup_router.get("/snapshots/{snapshot_id}")
async def download_backup_snapshot(
    snapshot_id: str,
    user_id: str = Depends(_get_backup_user_id),
):
    blob = BACKUP_BLOBS.get((user_id, snapshot_id))
    if not blob:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Backup snapshot '{snapshot_id}' not found.",
        )
    return blob


@backup_router.delete("/snapshots/{snapshot_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_backup_snapshot(
    snapshot_id: str,
    user_id: str = Depends(_get_backup_user_id),
):
    USER_BACKUPS[user_id] = [
        s for s in USER_BACKUPS.get(user_id, []) if s["snapshotId"] != snapshot_id
    ]
    BACKUP_BLOBS.pop((user_id, snapshot_id), None)
    return None


@backup_router.delete("/snapshots", status_code=status.HTTP_204_NO_CONTENT)
async def delete_all_backup_snapshots(user_id: str = Depends(_get_backup_user_id)):
    snapshots = USER_BACKUPS.pop(user_id, [])
    for s in snapshots:
        BACKUP_BLOBS.pop((user_id, s["snapshotId"]), None)
    return None
