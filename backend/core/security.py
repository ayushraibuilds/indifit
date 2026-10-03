import hashlib
import os
import secrets
import sys
import time
from typing import Dict, List, Optional
from fastapi import Header, HTTPException, Request, status
from backend.core.config import get_indifit_api_key

from cachetools import TTLCache

RATE_LIMIT_WINDOW = 3600  # 1 hour
MAX_REQUESTS_PER_WINDOW = 30
IP_REQUEST_LOGS: TTLCache = TTLCache(maxsize=50_000, ttl=RATE_LIMIT_WINDOW)

PHOTO_V2_WINDOW = 86400  # 24 hours
PHOTO_V2_MAX_REQUESTS = 10  # 10 requests per 24 hours per device
DEVICE_PHOTO_LOGS: TTLCache = TTLCache(maxsize=50_000, ttl=PHOTO_V2_WINDOW)


def get_trusted_proxy_hops() -> int:
    """How many proxies in front of the app append to X-Forwarded-For.

    0 (default, local development): use the TCP peer address and ignore the
    header. Render's load balancer appends the address it received the
    connection from, so production sets 1. Add one per extra proxy (e.g. a
    CDN) in front of Render.
    """
    main_mod = sys.modules.get("backend.main")
    if main_mod is not None and hasattr(main_mod, "TRUSTED_PROXY_HOPS"):
        return main_mod.TRUSTED_PROXY_HOPS
    try:
        return max(0, int(os.getenv("TRUSTED_PROXY_HOPS", "0")))
    except ValueError:
        return 0


def client_ip(request: Request) -> str:
    """The caller's address for rate limiting.

    X-Forwarded-For is "client, proxy1, proxy2" and anyone can send a fake
    one: proxies append to it rather than replace it. Only the entries our own
    proxies added, counted from the right, are trustworthy, so the client is
    the entry TRUSTED_PROXY_HOPS from the end. Trusting the left-most entry
    (uvicorn's --forwarded-allow-ips='*') let any caller pick a fresh IP per
    request and bypass the rate limits.
    """
    peer = request.client.host if request.client else "unknown"
    hops = get_trusted_proxy_hops()
    if hops == 0:
        return peer
    forwarded = [
        part.strip()
        for part in request.headers.get("x-forwarded-for", "").split(",")
        if part.strip()
    ]
    if len(forwarded) < hops:
        # Fewer entries than proxies: the request didn't come through them.
        return peer
    return forwarded[-hops]


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


def get_photo_v2_window() -> int:
    main_mod = sys.modules.get("backend.main")
    if main_mod is not None and hasattr(main_mod, "PHOTO_V2_WINDOW"):
        return main_mod.PHOTO_V2_WINDOW
    return PHOTO_V2_WINDOW


def get_photo_v2_max_requests() -> int:
    main_mod = sys.modules.get("backend.main")
    if main_mod is not None and hasattr(main_mod, "PHOTO_V2_MAX_REQUESTS"):
        return main_mod.PHOTO_V2_MAX_REQUESTS
    return PHOTO_V2_MAX_REQUESTS


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
    caller_ip = client_ip(request)
    now = time.time()

    # Per-device rate limiting for Photo Meal Estimator V2 (CGNAT protection)
    if request.url.path.endswith("/meal-estimate-photo-v2"):
        device_uuid = request.headers.get("x-device-uuid") or request.headers.get("X-Device-UUID")
        key = f"device:{device_uuid.strip()}" if device_uuid and device_uuid.strip() else f"ip:{caller_ip}"
        window = get_photo_v2_window()
        max_requests = get_photo_v2_max_requests()
        timestamps = DEVICE_PHOTO_LOGS.get(key, [])
        timestamps = [t for t in timestamps if now - t < window]

        if len(timestamps) >= max_requests:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Rate limit exceeded. Maximum {max_requests} photo meal scans per 24 hours allowed per device.",
            )

        timestamps.append(now)
        DEVICE_PHOTO_LOGS[key] = timestamps
        return

    timestamps = IP_REQUEST_LOGS.get(caller_ip, [])
    window = get_rate_limit_window()
    max_requests = get_max_requests_per_window()
    timestamps = [t for t in timestamps if now - t < window]

    if len(timestamps) >= max_requests:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Rate limit exceeded. Maximum 30 AI requests per hour per IP allowed.",
        )

    timestamps.append(now)
    IP_REQUEST_LOGS[caller_ip] = timestamps


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
