import sys
import time
from pathlib import Path
from typing import Dict
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Ensure backend package resolution when run directly or in containers
_backend_dir = Path(__file__).resolve().parent
_parent_dir = str(_backend_dir.parent)
if _parent_dir not in sys.path:
    sys.path.insert(0, _parent_dir)
if "backend" not in sys.modules:
    try:
        import backend  # noqa: F401
    except ImportError:
        import types
        pkg = types.ModuleType("backend")
        pkg.__path__ = [str(_backend_dir)]
        sys.modules["backend"] = pkg

from backend.core.config import (  # noqa: E402
    ALLOWED_ORIGINS,
    AI_MODEL,
    INDIFIT_API_KEY,
    GEMINI_API_KEY,
    get_indifit_api_key,
    get_gemini_api_key,
)
from backend.core.security import (  # noqa: E402
    verify_api_key,
    enforce_rate_limit,
    _get_backup_user_id,
    IP_REQUEST_LOGS,
    RATE_LIMIT_WINDOW,
    MAX_REQUESTS_PER_WINDOW,
)
from backend.routers.ai import ai_router  # noqa: E402
from backend.routers.backup import backup_router, USER_BACKUPS, BACKUP_BLOBS  # noqa: E402
from backend.routers.sync import sync_router, USER_MUTATIONS  # noqa: E402
from backend.services.gemini_client import (  # noqa: E402
    query_gemini_text,
    query_gemini_vision,
    GEMINI_CACHE,
    GeminiQuotaExceededError,
    clear_cache,
    set_daily_budget,
    reset_daily_stats,
    get_daily_budget,
    get_daily_request_count,
)


def create_app() -> FastAPI:
    application = FastAPI(title="IndiFit AI Backend")
    application.add_middleware(
        CORSMiddleware,
        allow_origins=ALLOWED_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @application.get("/health")
    async def health_check():
        return {
            "status": "ok",
            "gemini_configured": bool(get_gemini_api_key()),
            "model": AI_MODEL,
            "timestamp": time.time(),
        }

    @application.get("/")
    def home():
        return {"status": "online", "message": "IndiFit AI Backend Running"}

    application.include_router(ai_router)
    application.include_router(backup_router)
    application.include_router(sync_router)
    return application


app = create_app()
