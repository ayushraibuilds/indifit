import os
import sys
from dotenv import load_dotenv

load_dotenv()

ALLOWED_ORIGINS = os.getenv(
    "ALLOWED_ORIGINS",
    "http://localhost,http://127.0.0.1,http://10.0.2.2,https://indifit.app",
).split(",")

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
AI_MODEL = os.getenv("AI_MODEL", "gemini-1.5-flash")

INDIFIT_API_KEY = os.getenv("INDIFIT_API_KEY")
if not INDIFIT_API_KEY:
    raise RuntimeError(
        "INDIFIT_API_KEY environment variable must be set (no default is "
        "provided for security reasons). Set it in your deployment "
        "environment, e.g. the Render dashboard."
    )


def get_indifit_api_key() -> str:
    main_mod = sys.modules.get("backend.main")
    if main_mod is not None and hasattr(main_mod, "INDIFIT_API_KEY"):
        return main_mod.INDIFIT_API_KEY
    return INDIFIT_API_KEY


def get_gemini_api_key() -> str:
    main_mod = sys.modules.get("backend.main")
    if main_mod is not None and hasattr(main_mod, "GEMINI_API_KEY"):
        return main_mod.GEMINI_API_KEY
    return GEMINI_API_KEY
