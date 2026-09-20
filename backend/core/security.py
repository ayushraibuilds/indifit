import hashlib
import secrets
import sys
import time
from typing import Dict, List, Optional
from fastapi import Header, HTTPException, Request, status
from backend.core.config import get_indifit_api_key

IP_REQUEST_LOGS: Dict[str, List[float]] = {}
RATE_LIMIT_WINDOW = 3600  # 1 hour
MAX_REQUESTS_PER_WINDOW = 30


def get_rate_limit_window() -> int:
    main_mod = sys.modules.get("backend.main")
    if main_mod is not None and hasattr(main_mod, "RATE_LIMIT_WINDOW"):
        return main_mod.RATE_LIMIT_WINDOW
    return RATE_LIMIT_WINDOW


def get_max_requests_per_window() -> int:
    main_mod = sys.modules.get("backend.main")
    if main_mod is not None and hasattr(main_mod, "MAX_REQUESTS_PER_WINDOW"):
        return main_mod.MAX_REQUESTS_PER_WINDOW
    return MAX_REQUESTS_PER_WINDOW


async def verify_api_key(x_indifit_key: Optional[str] = Header(None)):
    indifit_key = get_indifit_api_key()
    if not indifit_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Server authentication is not configured",
        )
    if x_indifit_key is None or not secrets.compare_digest(
        x_indifit_key,
        indifit_key,
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing x-indifit-key authentication header",
        )
    return x_indifit_key


async def enforce_rate_limit(request: Request):
    client_ip = request.client.host if request.client else "unknown"
    now = time.time()
    timestamps = IP_REQUEST_LOGS.get(client_ip, [])
    window = get_rate_limit_window()
    max_requests = get_max_requests_per_window()
    timestamps = [t for t in timestamps if now - t < window]

    if len(timestamps) >= max_requests:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Rate limit exceeded. Maximum 30 AI requests per hour per IP allowed.",
        )

    timestamps.append(now)
    IP_REQUEST_LOGS[client_ip] = timestamps


def _get_backup_user_id(
    authorization: Optional[str] = Header(None),
    x_indifit_key: Optional[str] = Header(None),
) -> str:
    if authorization and authorization.startswith("Bearer "):
        token = authorization.split("Bearer ", 1)[1].strip()
        if token:
            return hashlib.sha256(token.encode("utf-8")).hexdigest()[:16]
    indifit_key = get_indifit_api_key()
    if x_indifit_key and indifit_key and secrets.compare_digest(x_indifit_key, indifit_key):
        return "default_api_user"
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Missing or invalid authentication: provide Authorization Bearer token or valid x-indifit-key.",
    )
