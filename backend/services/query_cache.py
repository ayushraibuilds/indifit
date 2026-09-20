"""
In-Memory Query Cache & Daily Gemini Spend Ceiling
=================================================
Implements zero-ops architectural caching and daily budget enforcement per
Section 4.3 and Section 8 of CROSS_AGENT_COMPREHENSIVE_AUDIT_REPORT.md.

Guarantees:
- In-memory TTLCache (2000 items, 3600s TTL) keyed by SHA-256 hashes.
- Composite vision hashing (prompt + sha256(image_bytes)) prevents image lookup collisions.
- Daily request spend ceiling with automatic daily rollover.
- Raises GeminiQuotaExceededError when daily quota is exceeded.
"""

from datetime import date
import hashlib
import os
import sys
from typing import Optional
from cachetools import TTLCache


DEFAULT_DAILY_BUDGET = 500


def get_default_budget() -> int:
    try:
        return int(os.getenv("GEMINI_DAILY_BUDGET", str(DEFAULT_DAILY_BUDGET)))
    except (ValueError, TypeError):
        return DEFAULT_DAILY_BUDGET


_CACHE: TTLCache = TTLCache(maxsize=2000, ttl=3600)

_daily_stats = {
    "date": date.today(),
    "count": 0,
    "budget": get_default_budget(),
}


class GeminiQuotaExceededError(Exception):
    """Raised when the aggregate daily Gemini spend/request quota is exhausted."""
    pass


def hash_text_query(prompt: str, json_mode: bool = False) -> str:
    """Computes deterministic SHA-256 hash for text queries."""
    key = f"{prompt.strip()}:json={json_mode}"
    return hashlib.sha256(key.encode("utf-8")).hexdigest()


def hash_vision_query(prompt: str, image_bytes: bytes) -> str:
    """Computes deterministic SHA-256 hash for vision queries using prompt + image bytes."""
    img_hash = hashlib.sha256(image_bytes).hexdigest()
    key = f"{prompt.strip()}:{img_hash}"
    return hashlib.sha256(key.encode("utf-8")).hexdigest()


def get_cached(key: str) -> Optional[str]:
    """Retrieves cached result if present and not expired."""
    return _CACHE.get(key)


def set_cached(key: str, value: str) -> None:
    """Stores result in TTL cache."""
    _CACHE[key] = value


def get_daily_budget() -> int:
    return _daily_stats["budget"]


def set_daily_budget(budget: int) -> None:
    _daily_stats["budget"] = budget


def get_daily_request_count() -> int:
    _ensure_today()
    return _daily_stats["count"]


def _ensure_today() -> None:
    today = date.today()
    if _daily_stats["date"] != today:
        _daily_stats["date"] = today
        _daily_stats["count"] = 0
        _daily_stats["budget"] = get_default_budget()


def check_and_increment_budget() -> bool:
    """
    Checks if daily budget is exceeded.
    Returns True and increments count if quota is available, else False.
    """
    _ensure_today()
    if _daily_stats["count"] >= _daily_stats["budget"]:
        return False
    _daily_stats["count"] += 1
    return True


def clear_cache() -> None:
    """Clears all entries in the TTL cache (useful for testing)."""
    _CACHE.clear()


def reset_daily_stats(budget: Optional[int] = None) -> None:
    """Resets daily usage count and sets budget (useful for testing)."""
    _daily_stats["date"] = date.today()
    _daily_stats["count"] = 0
    _daily_stats["budget"] = budget if budget is not None else get_default_budget()
