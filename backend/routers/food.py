import json
import re
import time
from collections import Counter, deque
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends

from backend.core.security import enforce_rate_limit, verify_api_key
from backend.schemas.food import FoodItem, FoodSearchRequest, FoodSearchResponse

food_router = APIRouter(
    prefix="/api/food",
    tags=["food"],
    dependencies=[Depends(verify_api_key), Depends(enforce_rate_limit)],
)

# Static category text to canonical taxonomy category_id mapping
CATEGORY_TEXT_TO_ID: Dict[str, str] = {
    "Grains & Breads": "staple_bread",
    "Dals & Curries": "dal_lentil",
    "Dals & Legumes": "dal_lentil",
    "Pulses & Legumes": "dal_lentil",
    "Vegetables & Sabji": "dry_sabzi",
    "Vegetables & Sabjis": "dry_sabzi",
    "Curries & Gravies": "gravy_curry",
    "Paneer & Dairy": "dairy_liquid",
    "Beverages": "dairy_liquid",
    "Soups & Beverages": "dairy_liquid",
    "Snacks & Street Food": "snack_street",
    "Healthy & Salads": "dry_sabzi",
    "Non-Veg": "gravy_curry",
    "Rice Dishes": "staple_rice",
    "Rice & Biryani": "staple_rice",
    "Sweets & Desserts": "sweet_dessert",
    "Oils & Fats": "oil_fat",
}

# Indian dialect and Hinglish transliteration dictionary
TRANSLITERATION_MAP: Dict[str, str] = {
    "arhar": "toor",
    "toor": "arhar",
    "tuvar": "toor",
    "chapati": "roti",
    "phulka": "roti",
    "dahi": "curd",
    "curd": "dahi",
    "paneer": "cottage cheese",
    "chawal": "rice",
    "dal": "lentil",
    "anda": "egg",
    "murgh": "chicken",
    "sabzi": "vegetable",
    "subzi": "vegetable",
    "chana": "chickpeas",
    "chole": "chickpeas",
}

# Anonymous zero-result ring buffer (max 500 items).
# Stored items: {"query": str, "timestamp_utc": float}. IP addresses and user identities are NEVER logged.
MISSED_SEARCHES: deque = deque(maxlen=500)

# In-process search hit counter for the Frequent tier
SEARCH_HIT_COUNTER: Counter = Counter()

# Cached dataset
_LOADED_FOODS: Optional[List[Dict[str, Any]]] = None


def _resolve_data_path() -> Path:
    base_dir = Path(__file__).resolve().parent.parent  # backend/
    candidates = [
        base_dir / "data" / "indian_foods.json",
        base_dir.parent / "assets" / "data" / "indian_foods.json",
        Path.cwd() / "backend" / "data" / "indian_foods.json",
        Path.cwd() / "assets" / "data" / "indian_foods.json",
    ]
    for p in candidates:
        if p.is_file():
            return p
    return candidates[0]


def load_curated_foods() -> List[Dict[str, Any]]:
    global _LOADED_FOODS
    if _LOADED_FOODS is not None:
        return _LOADED_FOODS

    path = _resolve_data_path()
    if path.is_file():
        with open(path, "r", encoding="utf-8") as f:
            _LOADED_FOODS = json.load(f)
    else:
        _LOADED_FOODS = []
    return _LOADED_FOODS


def _resolve_category_id(food_name: str, category_text: Optional[str]) -> str:
    name_lower = food_name.lower()
    if any(k in name_lower for k in ["biryani", "pulao", "rice", "khichdi"]):
        return "staple_rice"
    if any(k in name_lower for k in ["roti", "chapati", "paratha", "naan", "kulcha", "puri"]):
        return "staple_bread"
    if any(k in name_lower for k in ["dal", "sambar", "lentil", "chana", "rajma", "choor"]):
        return "dal_lentil"
    if any(k in name_lower for k in ["curry", "gravy", "korma", "masala"]):
        return "gravy_curry"
    if any(k in name_lower for k in ["sabzi", "bhindi", "gobi", "aloo", "baingan", "palak"]):
        return "dry_sabzi"
    if any(k in name_lower for k in ["lassi", "chaas", "milk", "dahi", "curd"]):
        return "dairy_liquid"
    if any(k in name_lower for k in ["ladoo", "halwa", "kheer", "gulab jamun", "jalebi"]):
        return "sweet_dessert"
    if any(k in name_lower for k in ["ghee", "butter", "oil"]):
        return "oil_fat"
    if category_text and category_text in CATEGORY_TEXT_TO_ID:
        return CATEGORY_TEXT_TO_ID[category_text]
    return "general"


def _calculate_score(
    item_name: str,
    item_hindi: Optional[str],
    query: str,
    transliterated: Optional[str],
) -> float:
    name_lower = item_name.lower()
    hindi_lower = (item_hindi or "").lower()
    q = query.lower()
    t = (transliterated or "").lower()

    # Exact Match (100)
    if name_lower == q or hindi_lower == q:
        return 100.0

    # Transliterated exact match (95)
    if t and (name_lower == t or hindi_lower == t):
        return 95.0

    # Exact word boundary match / starts with (80)
    words = re.findall(r"\w+", name_lower)
    if q in words or name_lower.startswith(q):
        return 80.0
    if t and (t in words or name_lower.startswith(t)):
        return 75.0

    # Frequent queries bonus / Catalog Verified (60)
    if SEARCH_HIT_COUNTER[name_lower] >= 3:
        if q in name_lower or (t and t in name_lower):
            return 60.0

    # Substring match (40)
    if q in name_lower or (hindi_lower and q in hindi_lower):
        return 40.0
    if t and (t in name_lower or (hindi_lower and t in hindi_lower)):
        return 35.0

    # Fuzzy/token overlap (20)
    q_tokens = set(re.findall(r"\w+", q))
    if t:
        q_tokens.update(re.findall(r"\w+", t))
    item_tokens = set(words)
    if q_tokens & item_tokens:
        return 20.0

    return 0.0


@food_router.post("/search", response_model=FoodSearchResponse)
async def search_food(request: FoodSearchRequest) -> FoodSearchResponse:
    q = request.query.strip().lower()

    # Determine transliteration if applicable
    transliterated: Optional[str] = None
    for k, v in TRANSLITERATION_MAP.items():
        if k in q:
            transliterated = q.replace(k, v)
            break

    curated = load_curated_foods()
    scored_results: List[FoodItem] = []

    for entry in curated:
        name = entry.get("name", "")
        name_hindi = entry.get("name_hindi")
        score = _calculate_score(name, name_hindi, q, transliterated)
        if score > 0.0:
            category_text = entry.get("category")
            category_id = _resolve_category_id(name, category_text)

            # Record frequency hit
            SEARCH_HIT_COUNTER[name.lower()] += 1

            food_item = FoodItem(
                name=name,
                name_hindi=name_hindi,
                category=category_text,
                category_id=category_id,
                calories=float(entry.get("calories", 0.0)),
                protein_g=float(entry.get("protein_g", 0.0)),
                carbs_g=float(entry.get("carbs_g", 0.0)),
                fat_g=float(entry.get("fat_g", 0.0)),
                fiber_g=float(entry["fiber_g"]) if entry.get("fiber_g") is not None else None,
                # Truth Contract: Missing sodium must be null, never 0.0
                sodium_mg=float(entry["sodium_mg"]) if entry.get("sodium_mg") is not None else None,
                serving_size=float(entry.get("serving_size", 1.0)),
                serving_unit=str(entry.get("serving_unit", "serving")),
                score=score,
                source="curated",
            )
            scored_results.append(food_item)

    # Sort descending by score, then ascending by name
    scored_results.sort(key=lambda item: (-item.score, item.name))
    limited_results = scored_results[: request.limit]

    # If zero results, log to anonymous missed_searches deque
    if not limited_results:
        MISSED_SEARCHES.append({"query": q, "timestamp_utc": time.time()})

    return FoodSearchResponse(
        results=limited_results,
        count=len(limited_results),
        query=request.query,
        transliterated_query=transliterated,
    )


def get_missed_searches() -> List[Dict[str, Any]]:
    return list(MISSED_SEARCHES)


def clear_missed_searches() -> None:
    MISSED_SEARCHES.clear()
