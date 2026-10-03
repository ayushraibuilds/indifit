"""Gemini-backed AI routes for LOCAL DEVELOPMENT only.

The app talks to Gemini through Firebase AI Logic with App Check
(lib/core/ai/firebase_ai_gateway.dart). These routes back the app's
`INDIFIT_AI_GATEWAY=fastapi` development path and are mounted only when
ENABLE_AI_ROUTES=1, which no deployment sets (WS7 Phase 6).

Failures are reported as HTTP errors. There are no mock or fallback
results: a nutrition app must never show invented food.
"""

import json
import sys
from typing import Awaitable, Callable

from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    UploadFile,
    status,
)
from backend.core.config import get_gemini_api_key
from backend.core.security import enforce_rate_limit, verify_api_key
from backend.schemas.ai import (
    MealDecompositionResponse,
    NutritionLabelOcrResponse,
    TextMealRequest,
)
from backend.services import gemini_client
from backend.services.query_cache import GeminiQuotaExceededError


def _get_query_gemini_text():
    main_mod = sys.modules.get("backend.main")
    if main_mod is not None and hasattr(main_mod, "query_gemini_text"):
        return main_mod.query_gemini_text
    return gemini_client.query_gemini_text


def _get_query_gemini_vision():
    main_mod = sys.modules.get("backend.main")
    if main_mod is not None and hasattr(main_mod, "query_gemini_vision"):
        return main_mod.query_gemini_vision
    return gemini_client.query_gemini_vision


ai_router = APIRouter(
    prefix="/api/ai",
    dependencies=[
        Depends(verify_api_key),
        Depends(enforce_rate_limit),
    ],
)

_ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/jpg", "image/png", "image/webp"}


async def _read_image(image: UploadFile, max_bytes: int, limit_label: str) -> tuple[bytes, str]:
    mime_type = image.content_type or "image/jpeg"
    if mime_type not in _ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Invalid image MIME type. Allowed: JPEG, PNG, WebP.",
        )
    image_bytes = await image.read()
    if len(image_bytes) > max_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File size exceeds maximum upload limit of {limit_label}.",
        )
    return image_bytes, mime_type


async def _ask_gemini(query: Callable[[], Awaitable[str]]) -> dict:
    """Runs a Gemini query and decodes its JSON, mapping every failure to an
    HTTP error with a generic message (internal details are never echoed)."""
    if not get_gemini_api_key():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="AI is not configured on this server.",
        )
    try:
        data = json.loads(await query())
    except HTTPException:
        raise
    except GeminiQuotaExceededError:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="AI usage limit reached. Please try again later.",
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="The AI service is unavailable right now.",
        )
    if not isinstance(data, dict):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="The AI service is unavailable right now.",
        )
    return data


@ai_router.post("/meal-estimate-photo-v2", response_model=MealDecompositionResponse)
async def estimate_meal_photo_v2(image: UploadFile = File(...)):
    prompt = """
    Act as an expert Indian clinical dietitian and computer vision food analyst.
    Inspect this meal photo and decompose it into discrete individual food items with Indian portion awareness (e.g. rotis, katoris of dal/curry, bowls of rice, dry sabzis).

    For each individual food item identified:
    1. "raw_segment": description of the item in the image (e.g. "2 rotis", "1 katori dal tadka")
    2. "food_name": canonical search name (e.g. "Roti / Chapati", "Yellow Dal Tadka", "Steamed Basmati Rice")
    3. "quantity_amount": numeric portion (e.g. 2.0, 1.0)
    4. "quantity_unit": Indian standard unit ("piece", "katori (standard)", "small_katori", "bowl", "cup", "plate", "g")
    5. "estimated_calories": integer kcal
    6. "estimated_protein": float grams
    7. "estimated_carbs": float grams
    8. "estimated_fat": float grams
    9. "fiber_g": float grams or null
    10. "sodium_mg": float mg or null
    11. "confidence": "high", "medium", or "low" based on visual clarity and portion visibility
    12. "category_id": optional taxonomy category ("staple_bread", "dal_lentil", "curry_veg", "rice_grain", "dairy_solid", etc.)

    Return a JSON object with:
    - "query": "Photo Decomposition V2"
    - "items": list of food items matching the schema
    - "total_calories": sum of estimated calories across all items
    - "confidence": overall confidence ("high", "medium", or "low")
    - "disclaimer": "AI estimate carries ±30% variance. Review quantities before saving."

    Return STRICTLY valid JSON. Do not output markdown text or code fences.
    """

    image_bytes, mime_type = await _read_image(image, 1 * 1024 * 1024, "1 MB")
    return await _ask_gemini(
        lambda: _get_query_gemini_vision()(prompt, image_bytes, mime_type)
    )


@ai_router.post("/nutrition-label-ocr", response_model=NutritionLabelOcrResponse)
async def ocr_nutrition_label(image: UploadFile = File(...)):
    prompt = """
    Act as an expert computer vision system and clinical dietitian specializing in nutrition facts labels (including Indian FSSAI mandatory per 100g / per serving formats and FDA / international labels).
    Extract the following information from this nutrition facts label image:
    - "product_name": name of the food product if visible on package, else null
    - "brand_name": brand if visible, else null
    - "serving_size_amount": numeric amount for a serving if stated (e.g. 30.0), else null
    - "serving_size_unit": unit for serving size (e.g. "g", "ml", "biscuit", "pieces"), else null
    - "serving_description": full serving description if stated (e.g. "2 biscuits (30g)"), else null
    - "servings_per_container": numeric count of servings in package if stated, else null
    - "basis": "per_serving" if values in the primary nutrient column are per serving, or "per_100g" if values are per 100g/100ml. Defaults to "per_100g" for Indian labels when 100g column is present.
    - "nutrients": a dictionary of nutrient objects where each key is one of: "calories", "protein", "carbs", "fat", "fiber", "sugar", "sodium", "cholesterol", "saturated_fat", "trans_fat".
      Each nutrient object MUST have:
      - "value": numeric float (or null if not stated/unreadable)
      - "unit": string ("kcal" for calories, "mg" for sodium/cholesterol, "g" for macros)
      - "confidence": "high" if clearly legible, "medium" if partially obscured/inferred, "low" if uncertain
      - "notes": string or null
    - "raw_text": all extracted label text

    Return STRICTLY a JSON object matching this schema. Do not include markdown code fences or conversational text.
    """

    image_bytes, mime_type = await _read_image(image, 5 * 1024 * 1024, "5 MB")
    return await _ask_gemini(
        lambda: _get_query_gemini_vision()(prompt, image_bytes, mime_type)
    )


@ai_router.post("/meal-decompose", response_model=MealDecompositionResponse)
async def decompose_meal(req: TextMealRequest):
    prompt = f"""
    Act as an expert Indian nutritionist and food analyzer. Decompose the following user meal description into discrete individual food items:
    "{req.text}"

    For each individual food item identified:
    1. "raw_segment": the exact fragment from the user text (e.g. "2 rotis", "1 katori dal tadka")
    2. "food_name": canonical search term suitable for looking up in an Indian food composition database (e.g. "Roti", "Dal Tadka", "Paneer Bhurji", "Curd", "Boiled Egg")
    3. "quantity_amount": numeric amount (e.g. 2.0, 1.0, 100.0)
    4. "quantity_unit": canonical measure ("roti", "katori", "bowl", "cup", "plate", "g", "ml", "piece", "serving")
    5. "estimated_calories": integer kcal
    6. "estimated_protein": float grams
    7. "estimated_carbs": float grams
    8. "estimated_fat": float grams
    9. "confidence": "high", "medium", or "low" based on specificity of quantity and preparation

    Return a JSON object with:
    - "query": "{req.text}"
    - "items": list of food items
    - "total_calories": sum of estimated calories across all items

    Return STRICTLY a JSON object matching this schema. Do not include markdown code fences or conversational text.
    """

    return await _ask_gemini(
        lambda: _get_query_gemini_text()(prompt, json_mode=True)
    )
