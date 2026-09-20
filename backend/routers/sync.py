import base64
import time
from typing import Dict, List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from backend.core.security import _get_backup_user_id
from backend.schemas.sync import (
    SyncPushRequestModel,
    SyncPushResponseModel,
    SyncPullResponseModel,
)

USER_MUTATIONS: Dict[str, List[dict]] = {}

sync_router = APIRouter(prefix="/v1/sync", tags=["sync"])


def _compare_hlc(a: dict, b: dict) -> int:
    if a["millis"] != b["millis"]:
        return -1 if a["millis"] < b["millis"] else 1
    if a["counter"] != b["counter"]:
        return -1 if a["counter"] < b["counter"] else 1
    if a["node_id"] != b["node_id"]:
        return -1 if a["node_id"] < b["node_id"] else 1
    return 0


@sync_router.post("/mutations", status_code=status.HTTP_200_OK, response_model=SyncPushResponseModel)
async def push_mutations(
    req: SyncPushRequestModel,
    user_id: str = Depends(_get_backup_user_id),
):
    now_millis = int(time.time() * 1000)
    accepted = 0
    latest_hlc = {"millis": 0, "counter": 0, "node_id": "server"}

    if user_id not in USER_MUTATIONS:
        USER_MUTATIONS[user_id] = []

    user_stream = USER_MUTATIONS[user_id]

    if len(req.mutations) > 500:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Too many mutations in one batch (max 500).",
        )

    # Validate everything BEFORE mutating server state so a skewed batch
    # cannot partially append and leave the client in retry ambiguity.
    for m in req.mutations:
        m_dict = m.model_dump()
        hlc = m_dict["hlc"]
        if not m_dict.get("entity_id") or len(m_dict["entity_id"]) > 128:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid entity_id: must be 1-128 characters.",
            )
        if m_dict.get("domain") not in {
            "weights", "workouts", "nutritionLogs",
            "nutritionRecipes", "programs", "preferences",
        }:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid domain: {m_dict.get('domain')}.",
            )
        if m_dict.get("type") not in {"insert", "update", "delete"}:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid type: {m_dict.get('type')}.",
            )
        # Clock skew validation: reject physical timestamps > 1 hour in the future
        if hlc["millis"] > now_millis + 3600000:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Clock skew exceeded: {hlc['millis']} vs server {now_millis}",
            )
        # Encrypted-envelope validation (blind relay by construction)
        envelope = m_dict.get("encrypted_envelope")
        if envelope is not None:
            if not isinstance(envelope, dict):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Invalid encrypted_envelope: must be an object.",
                )
            for _key in ("ciphertext_base64", "wrapped_key_base64", "sha256_checksum"):
                _val = envelope.get(_key)
                if not isinstance(_val, str) or not _val:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"Invalid encrypted_envelope: '{_key}' must be a non-empty string.",
                    )
            try:
                _ciphertext_bytes = base64.b64decode(
                    envelope["ciphertext_base64"], validate=True
                )
            except Exception:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Invalid encrypted_envelope: ciphertext_base64 is not valid base64.",
                )
            try:
                base64.b64decode(envelope["wrapped_key_base64"], validate=True)
            except Exception:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Invalid encrypted_envelope: wrapped_key_base64 is not valid base64.",
                )
            if len(_ciphertext_bytes) > 262144:
                raise HTTPException(
                    status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    detail="Encrypted envelope ciphertext exceeds 256 KB per-mutation limit.",
                )

    for m in req.mutations:
        m_dict = m.model_dump()
        hlc = m_dict["hlc"]

        # Deduplicate on (domain, entity_id, hlc)
        exists = any(
            x["entity_id"] == m_dict["entity_id"]
            and x["domain"] == m_dict["domain"]
            and _compare_hlc(x["hlc"], hlc) == 0
            for x in user_stream
        )
        if not exists:
            user_stream.append(m_dict)
            accepted += 1

        if _compare_hlc(hlc, latest_hlc) > 0:
            latest_hlc = hlc

    # Sort stream strictly by HLC
    user_stream.sort(key=lambda x: (x["hlc"]["millis"], x["hlc"]["counter"], x["hlc"]["node_id"]))

    return {
        "accepted_count": accepted,
        "server_received_hlc": latest_hlc,
    }


@sync_router.get("/deltas", status_code=status.HTTP_200_OK, response_model=SyncPullResponseModel)
async def pull_deltas(
    since_millis: int = 0,
    since_counter: int = 0,
    since_node_id: str = "",
    domain: Optional[str] = None,
    limit: int = 100,
    user_id: str = Depends(_get_backup_user_id),
):
    if limit < 1 or limit > 500:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid limit: must be 1-500.",
        )
    if domain is not None and domain not in {
        "weights", "workouts", "nutritionLogs",
        "nutritionRecipes", "programs", "preferences",
    }:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid domain filter: {domain}.",
        )
    user_stream = USER_MUTATIONS.get(user_id, [])
    since_hlc = {"millis": since_millis, "counter": since_counter, "node_id": since_node_id}

    eligible = []
    for m in user_stream:
        if _compare_hlc(m["hlc"], since_hlc) <= 0:
            continue
        if domain and m["domain"] != domain:
            continue
        eligible.append(m)

    slice_mutations = eligible[:limit]
    has_more = len(eligible) > limit
    latest_hlc = slice_mutations[-1]["hlc"] if slice_mutations else None

    return {
        "mutations": slice_mutations,
        "has_more": has_more,
        "latest_hlc": latest_hlc,
    }
