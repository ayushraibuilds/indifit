import asyncio
import hashlib
import json
import logging
import re
import time
from collections import Counter, deque
from pathlib import Path
from typing import Any, Dict, List, Optional

import httpx
from cachetools import TTLCache
from fastapi import APIRouter, Depends, HTTPException, status

from backend.core.security import enforce_rate_limit, verify_api_key
from backend.schemas.food import (
    FoodBarcodeResponse,
    FoodItem,
    FoodSearchRequest,
    FoodSearchResponse,
)

logger = logging.getLogger(__name__)

food_router = APIRouter(
    prefix="/api/food",
    tags=["food"],
    dependencies=[Depends(verify_api_key), Depends(enforce_rate_limit)],
)

# Open Food Facts Proxy Threshold: Proxy out only when curated hits are below this threshold
OFF_PROXY_MIN_HITS_THRESHOLD = 3

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

# Anonymous zero-result ring buffer (max 1000 items, hash-only without PII).
# Stored items: {"query_hash": str, "timestamp_utc": float}
MISSED_SEARCHES: deque = deque(maxlen=1000)

# In-process search hit counter for the Frequent tier
SEARCH_HIT_COUNTER: Counter = Counter()

# In-memory TTLCache: 2,000 search entries (1 hour TTL), 1,000 barcode entries (24 hour TTL)
SEARCH_CACHE: TTLCache = TTLCache(maxsize=2000, ttl=3600)
BARCODE_CACHE: TTLCache = TTLCache(maxsize=1000, ttl=86400)

# Cached datasets in memory
_LOADED_FOODS: Optional[List[Dict[str, Any]]] = None
_LOADED_FMCG: Optional[List[Dict[str, Any]]] = None
_FMCG_BARCODE_INDEX: Optional[Dict[str, Dict[str, Any]]] = None
_LOADED_SYNONYMS: Optional[Dict[str, str]] = None


def _resolve_data_dir() -> Path:
    base_dir = Path(__file__).resolve().parent.parent  # backend/
    candidates = [
        base_dir / "data",
        base_dir.parent / "assets" / "data",
        Path.cwd() / "backend" / "data",
        Path.cwd() / "assets" / "data",
    ]
    for p in candidates:
        if p.is_dir():
            return p
    return candidates[0]


def load_synonyms() -> Dict[str, str]:
    global _LOADED_SYNONYMS
    if _LOADED_SYNONYMS is not None:
        return _LOADED_SYNONYMS

    synonym_path = _resolve_data_dir() / "indian_synonyms.json"
    if synonym_path.is_file():
        try:
            with open(synonym_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                _LOADED_SYNONYMS = data.get("synonyms", {})
        except Exception as e:
            logger.warning("Failed to load indian_synonyms.json: %s", e)
            _LOADED_SYNONYMS = {}
    else:
        _LOADED_SYNONYMS = {
            "arhar": "toor",
            "tuvar": "toor",
            "chapati": "roti",
            "phulka": "roti",
            "dahi": "curd",
            "paneer": "cottage cheese",
            "chawal": "rice",
            "chana": "chickpeas",
            "chole": "chana",
        }
    return _LOADED_SYNONYMS


def load_curated_fmcg() -> List[Dict[str, Any]]:
    global _LOADED_FMCG, _FMCG_BARCODE_INDEX
    if _LOADED_FMCG is not None:
        return _LOADED_FMCG

    fmcg_path = _resolve_data_dir() / "curated_fmcg_manifest.json"
    if fmcg_path.is_file():
        try:
            with open(fmcg_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                _LOADED_FMCG = data.get("items", [])
        except Exception as e:
            logger.warning("Failed to load curated_fmcg_manifest.json: %s", e)
            _LOADED_FMCG = []
    else:
        _LOADED_FMCG = []

    _FMCG_BARCODE_INDEX = {item["barcode"]: item for item in _LOADED_FMCG if "barcode" in item}
    return _LOADED_FMCG


def load_curated_foods() -> List[Dict[str, Any]]:
    global _LOADED_FOODS
    if _LOADED_FOODS is not None:
        return _LOADED_FOODS

    food_path = _resolve_data_dir() / "indian_foods.json"
    if food_path.is_file():
        try:
            with open(food_path, "r", encoding="utf-8") as f:
                _LOADED_FOODS = json.load(f)
        except Exception as e:
            logger.warning("Failed to load indian_foods.json: %s", e)
            _LOADED_FOODS = []
    else:
        _LOADED_FOODS = []
    return _LOADED_FOODS


def _resolve_category_id(food_name: str, category_text: Optional[str]) -> str:
    name_lower = food_name.lower()
    if any(k in name_lower for k in ["biryani", "pulao", "rice", "khichdi", "khichuri", "poha"]):
        return "staple_rice"
    if any(k in name_lower for k in ["roti", "chapati", "paratha", "naan", "kulcha", "puri", "phulka"]):
        return "staple_bread"
    if any(k in name_lower for k in ["dal", "sambar", "lentil", "chana", "rajma", "choor", "toor", "moong", "urad", "besan"]):
        return "dal_lentil"
    if any(k in name_lower for k in ["curry", "gravy", "korma", "masala"]):
        return "gravy_curry"
    if any(k in name_lower for k in ["sabzi", "subzi", "bhindi", "gobi", "aloo", "baingan", "palak", "poriyal"]):
        return "dry_sabzi"
    if any(k in name_lower for k in ["lassi", "chaas", "milk", "dahi", "curd", "paneer", "yogurt"]):
        return "dairy_liquid"
    if any(k in name_lower for k in ["ladoo", "halwa", "kheer", "gulab jamun", "jalebi", "sweet", "mithai"]):
        return "sweet_dessert"
    if any(k in name_lower for k in ["ghee", "butter", "oil", "peanut butter"]):
        return "oil_fat"
    if category_text and category_text in CATEGORY_TEXT_TO_ID:
        return CATEGORY_TEXT_TO_ID[category_text]
    return "general"


def _build_serving_options(category_id: str, default_serving_size: float = 1.0, default_unit: str = "serving") -> List[Dict[str, Any]]:
    if category_id == "staple_bread":
        return [
            {"unit": default_unit if default_unit in ("piece", "roti") else "piece", "gram_weight": 40.0, "is_default": True},
            {"unit": "100g", "gram_weight": 100.0, "is_default": False},
        ]
    elif category_id == "dal_lentil":
        return [
            {"unit": "katori (standard)", "gram_weight": 150.0, "is_default": True},
            {"unit": "small_katori", "gram_weight": 100.0, "is_default": False},
            {"unit": "large_katori", "gram_weight": 250.0, "is_default": False},
            {"unit": "100g", "gram_weight": 100.0, "is_default": False},
        ]
    elif category_id in ("staple_rice", "dry_sabzi", "gravy_curry"):
        return [
            {"unit": "katori (standard)", "gram_weight": 150.0, "is_default": True},
            {"unit": "plate", "gram_weight": 250.0, "is_default": False},
            {"unit": "100g", "gram_weight": 100.0, "is_default": False},
        ]
    elif category_id == "dairy_liquid":
        return [
            {"unit": "glass (200ml)", "gram_weight": 206.0, "is_default": True},
            {"unit": "100ml", "gram_weight": 103.0, "is_default": False},
        ]
    elif category_id == "oil_fat":
        return [
            {"unit": "tablespoon (15ml)", "gram_weight": 14.0, "is_default": True},
            {"unit": "teaspoon (5ml)", "gram_weight": 4.6, "is_default": False},
        ]
    return [
        {"unit": f"{default_unit} ({default_serving_size:g})", "gram_weight": 100.0, "is_default": True},
        {"unit": "100g", "gram_weight": 100.0, "is_default": False},
    ]


def transliterate_query(query: str) -> Optional[str]:
    synonyms = load_synonyms()
    q_lower = query.strip().lower()
    result = q_lower
    # Sort keys by length descending so multi-word keys replace first
    for key, val in sorted(synonyms.items(), key=lambda x: len(x[0]), reverse=True):
        pattern = r"\b" + re.escape(key) + r"\b"
        result = re.sub(pattern, val, result)
    return result if result != q_lower else None


def _calculate_score(entry_name: str, name_hindi: Optional[str], q_norm: str, transliterated: Optional[str]) -> float:
    name_lower = entry_name.lower()
    hindi_lower = (name_hindi or "").lower()

    # Exact match: 100
    if q_norm == name_lower or q_norm == hindi_lower:
        return 100.0

    # Exact prefix match: 95
    if name_lower.startswith(q_norm) or hindi_lower.startswith(q_norm):
        return 95.0

    # Word-boundary exact match: 80
    if re.search(r"\b" + re.escape(q_norm) + r"\b", name_lower):
        return 80.0

    # Word-boundary prefix match: 75
    if re.search(r"\b" + re.escape(q_norm), name_lower):
        return 75.0

    # Substring match: 60
    if q_norm in name_lower or (name_hindi and q_norm in hindi_lower):
        return 60.0

    # Transliterated match: 40
    if transliterated:
        trans_norm = transliterated.lower()
        if trans_norm == name_lower:
            return 80.0
        if trans_norm in name_lower:
            return 40.0
        if re.search(r"\b" + re.escape(trans_norm) + r"\b", name_lower):
            return 40.0

    return 0.0


def _log_missed_search(query: str, transliterated: Optional[str] = None) -> None:
    now = time.time()
    query_hash = hashlib.sha256(query.encode("utf-8")).hexdigest()
    # Primary Sink: Structured log to stdout for Render log drains (hash only - zero PII)
    logger.info(
        "event=missed_search query_hash=%s hits=0 timestamp_utc=%f",
        query_hash,
        now,
    )
    # Secondary Sink: Local in-memory ring buffer (hash-only, zero raw query or PII)
    MISSED_SEARCHES.append({
        "query_hash": query_hash,
        "timestamp_utc": now,
    })


def flush_missed_searches(retention_limit: int = 1000) -> None:
    """Flush pending missed searches to disk for local debug with retention limit."""
    if not MISSED_SEARCHES:
        return
    try:
        data_dir = _resolve_data_dir()
        out_file = data_dir / "missed_searches.jsonl"
        items = list(MISSED_SEARCHES)

        existing = []
        if out_file.exists():
            try:
                with open(out_file, "r", encoding="utf-8") as f:
                    existing = [line.strip() for line in f if line.strip()]
            except Exception:
                existing = []

        for item in items:
            existing.append(json.dumps(item, ensure_ascii=False))

        if len(existing) > retention_limit:
            existing = existing[-retention_limit:]

        with open(out_file, "w", encoding="utf-8") as f:
            for line in existing:
                f.write(line + "\n")
        logger.info("Flushed %d missed searches to %s (retention capped at %d)", len(items), out_file, retention_limit)
    except Exception as e:
        logger.warning("Could not flush missed searches to disk: %s", e)


async def periodic_missed_searches_flusher() -> None:
    """Background asyncio task to flush missed searches hourly."""
    while True:
        try:
            await asyncio.sleep(3600)
            flush_missed_searches()
        except asyncio.CancelledError:
            flush_missed_searches()
            break
        except Exception as e:
            logger.warning("Error in periodic_missed_searches_flusher: %s", e)


async def _proxy_open_food_facts(query: str, limit: int = 10) -> List[FoodItem]:
    """Proxies search to Open Food Facts Search-a-licious with 4-second timeout."""
    try:
        url = "https://search.openfoodfacts.org/search"
        payload = {
            "q": query.strip(),
            "page_size": min(limit, 20),
            "page": 1,
            "langs": ["en"],
            "fields": [
                "code",
                "brands",
                "product_name",
                "quantity",
                "nutriments",
                "serving_quantity",
                "serving_quantity_unit",
            ],
        }
        headers = {
            "User-Agent": "IndiFit/1.0.0 (https://indifit.app)",
            "Content-Type": "application/json",
        }
        async with httpx.AsyncClient(timeout=4.0) as client:
            resp = await client.post(url, json=payload, headers=headers)
            if resp.status_code == 200:
                data = resp.json()
                hits = data.get("hits", [])
                results: List[FoodItem] = []
                for p in hits:
                    name = (p.get("product_name") or "").strip()
                    if not name:
                        continue
                    nutriments = p.get("nutriments") or {}
                    calories_raw = nutriments.get("energy-kcal_100g") or nutriments.get("energy-kcal")
                    if calories_raw is None:
                        continue
                    try:
                        calories = float(calories_raw)
                    except (ValueError, TypeError):
                        continue

                    def _num(val: Any) -> Optional[float]:
                        try:
                            return float(val) if val is not None else None
                        except (ValueError, TypeError):
                            return None

                    protein = _num(nutriments.get("proteins_100g")) or 0.0
                    carbs = _num(nutriments.get("carbohydrates_100g")) or 0.0
                    fat = _num(nutriments.get("fat_100g")) or 0.0
                    fiber = _num(nutriments.get("fiber_100g"))
                    sodium_g = _num(nutriments.get("sodium_100g"))
                    sodium_mg = (sodium_g * 1000.0) if sodium_g is not None else _num(nutriments.get("sodium_mg_100g"))

                    cat_id = _resolve_category_id(name, None)
                    results.append(
                        FoodItem(
                            id=str(p.get("code") or p.get("id") or ""),
                            name=name,
                            brand=p.get("brands"),
                            category_id=cat_id,
                            calories=calories,
                            protein_g=protein,
                            carbs_g=carbs,
                            fat_g=fat,
                            fiber_g=fiber,
                            sodium_mg=sodium_mg,
                            serving_size=100.0,
                            serving_unit="g",
                            serving_options=_build_serving_options(cat_id),
                            score=35.0,
                            source="openfoodfacts",
                            provenance="openfoodfacts_search",
                            confidence="medium",
                        )
                    )
                return results
    except Exception as e:
        logger.warning("Open Food Facts search proxy error: %s", e)
    return []


async def _proxy_off_product_barcode(barcode: str) -> Optional[FoodItem]:
    """Proxies barcode lookup to Open Food Facts v2 product API with 4-second timeout."""
    try:
        url = f"https://world.openfoodfacts.org/api/v2/product/{barcode}.json"
        headers = {"User-Agent": "IndiFit/1.0.0 (https://indifit.app)"}
        async with httpx.AsyncClient(timeout=4.0) as client:
            resp = await client.get(url, headers=headers)
            if resp.status_code == 200:
                data = resp.json()
                if data.get("status") == 1 and data.get("product"):
                    p = data["product"]
                    nutriments = p.get("nutriments") or {}
                    name = (p.get("product_name") or "Unknown Product").strip()
                    calories_raw = nutriments.get("energy-kcal_100g") or nutriments.get("energy-kcal")
                    calories = float(calories_raw) if calories_raw is not None else 0.0

                    def _num(val: Any) -> Optional[float]:
                        try:
                            return float(val) if val is not None else None
                        except (ValueError, TypeError):
                            return None

                    protein = _num(nutriments.get("proteins_100g")) or 0.0
                    carbs = _num(nutriments.get("carbohydrates_100g")) or 0.0
                    fat = _num(nutriments.get("fat_100g")) or 0.0
                    fiber = _num(nutriments.get("fiber_100g"))
                    sodium_g = _num(nutriments.get("sodium_100g"))
                    sodium_mg = (sodium_g * 1000.0) if sodium_g is not None else _num(nutriments.get("sodium_mg_100g"))

                    serving_qty_text = str(p.get("serving_quantity") or "100")
                    try:
                        serving_size = float(serving_qty_text)
                    except ValueError:
                        serving_size = 100.0
                    serving_unit = p.get("serving_quantity_unit") or "g"
                    cat_id = _resolve_category_id(name, None)

                    return FoodItem(
                        id=barcode,
                        name=name,
                        brand=p.get("brands"),
                        category_id=cat_id,
                        calories=calories,
                        protein_g=protein,
                        carbs_g=carbs,
                        fat_g=fat,
                        fiber_g=fiber,
                        sodium_mg=sodium_mg,
                        serving_size=serving_size,
                        serving_unit=serving_unit,
                        serving_options=_build_serving_options(cat_id, serving_size, serving_unit),
                        score=95.0,
                        source="openfoodfacts",
                        provenance="openfoodfacts_v2",
                        confidence="high",
                    )
    except Exception as e:
        logger.warning("Open Food Facts barcode proxy error: %s", e)
    return None


@food_router.post("/search", response_model=FoodSearchResponse)
async def search_foods(request: FoodSearchRequest):
    q = request.query.strip()
    language = request.language.strip()
    page = request.page
    limit = request.limit

    # 1. Query Hash & TTLCache Check
    cache_key = hashlib.sha256(f"{q.lower()}_{language.lower()}_{page}_{limit}".encode("utf-8")).hexdigest()
    if cache_key in SEARCH_CACHE:
        return SEARCH_CACHE[cache_key]

    # Track hit for frequent counter
    SEARCH_HIT_COUNTER[q.lower()] += 1

    transliterated = transliterate_query(q)
    q_norm = q.lower()
    curated_foods = load_curated_foods()
    curated_fmcg = load_curated_fmcg()

    scored_results: List[FoodItem] = []
    seen_ids = set()

    # 2. Score Curated FMCG Items
    for item in curated_fmcg:
        name = item.get("name", "")
        brand = item.get("brand")
        barcode = item.get("barcode")
        score = _calculate_score(name, None, q_norm, transliterated)
        if score > 0:
            cat_id = item.get("category_id", "general")
            food_item = FoodItem(
                id=barcode,
                name=name,
                brand=brand,
                category=cat_id,
                category_id=cat_id,
                calories=float(item.get("calories", 0.0)),
                protein_g=float(item.get("protein_g", 0.0)),
                carbs_g=float(item.get("carbs_g", 0.0)),
                fat_g=float(item.get("fat_g", 0.0)),
                fiber_g=float(item["fiber_g"]) if item.get("fiber_g") is not None else None,
                sodium_mg=float(item["sodium_mg"]) if item.get("sodium_mg") is not None else None,
                serving_size=float(item.get("serving_size", 100.0)),
                serving_unit=str(item.get("serving_unit", "g")),
                serving_options=item.get("serving_options") or _build_serving_options(cat_id),
                score=score,
                source="curated",
                provenance="verified_fmcg",
                confidence="high",
            )
            scored_results.append(food_item)
            seen_ids.add(name.lower())

    # 3. Score Standard Curated Indian Foods
    for entry in curated_foods:
        name = entry.get("name", "")
        name_hindi = entry.get("name_hindi")
        if name.lower() in seen_ids:
            continue

        score = _calculate_score(name, name_hindi, q_norm, transliterated)
        if score > 0:
            category_text = entry.get("category")
            category_id = _resolve_category_id(name, category_text)
            serving_size = float(entry.get("serving_size", 1.0))
            serving_unit = str(entry.get("serving_unit", "serving"))
            food_item = FoodItem(
                id=None,
                name=name,
                name_hindi=name_hindi,
                category=category_text,
                category_id=category_id,
                calories=float(entry.get("calories", 0.0)),
                protein_g=float(entry.get("protein_g", 0.0)),
                carbs_g=float(entry.get("carbs_g", 0.0)),
                fat_g=float(entry.get("fat_g", 0.0)),
                fiber_g=float(entry["fiber_g"]) if entry.get("fiber_g") is not None else None,
                sodium_mg=float(entry["sodium_mg"]) if entry.get("sodium_mg") is not None else None,
                serving_size=serving_size,
                serving_unit=serving_unit,
                serving_options=_build_serving_options(category_id, serving_size, serving_unit),
                score=score,
                source="curated",
                provenance="curated",
                confidence="high",
            )
            scored_results.append(food_item)
            seen_ids.add(name.lower())

    # 4. Proxy to Open Food Facts if hits are below threshold and provider is included
    if len(scored_results) < OFF_PROXY_MIN_HITS_THRESHOLD and request.include_provider:
        off_results = await _proxy_open_food_facts(q, limit=limit)
        for off_item in off_results:
            if off_item.name.lower() not in seen_ids:
                scored_results.append(off_item)
                seen_ids.add(off_item.name.lower())

    # Sort descending by score, then ascending by name
    scored_results.sort(key=lambda item: (-item.score, item.name))

    total_hits = len(scored_results)
    start_idx = (page - 1) * limit
    end_idx = start_idx + limit
    paginated_results = scored_results[start_idx:end_idx]
    has_more = end_idx < total_hits

    # 5. Anonymous zero-result logging to dual-sink
    if total_hits == 0:
        _log_missed_search(q, transliterated)

    response = FoodSearchResponse(
        results=paginated_results,
        count=len(paginated_results),
        total_hits=total_hits,
        has_more=has_more,
        query=request.query,
        transliterated_query=transliterated,
    )

    # Store in TTLCache
    SEARCH_CACHE[cache_key] = response
    return response


@food_router.get("/barcode/{code}", response_model=FoodBarcodeResponse)
async def get_food_by_barcode(code: str):
    code = code.strip()
    if not code.isdigit() or len(code) not in (8, 12, 13, 14):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Invalid barcode format. Expected 8, 12, 13, or 14 digits.",
        )

    # 1. Check in-memory TTLCache
    if code in BARCODE_CACHE:
        return FoodBarcodeResponse(barcode=code, candidate=BARCODE_CACHE[code])

    # 2. Check curated FMCG manifest
    load_curated_fmcg()
    if _FMCG_BARCODE_INDEX and code in _FMCG_BARCODE_INDEX:
        raw = _FMCG_BARCODE_INDEX[code]
        cat_id = raw.get("category_id", "general")
        candidate = FoodItem(
            id=code,
            name=raw.get("name", "Unknown Product"),
            brand=raw.get("brand"),
            category_id=cat_id,
            calories=float(raw.get("calories", 0.0)),
            protein_g=float(raw.get("protein_g", 0.0)),
            carbs_g=float(raw.get("carbs_g", 0.0)),
            fat_g=float(raw.get("fat_g", 0.0)),
            fiber_g=float(raw["fiber_g"]) if raw.get("fiber_g") is not None else None,
            sodium_mg=float(raw["sodium_mg"]) if raw.get("sodium_mg") is not None else None,
            serving_size=float(raw.get("serving_size", 100.0)),
            serving_unit=str(raw.get("serving_unit", "g")),
            serving_options=raw.get("serving_options") or _build_serving_options(cat_id),
            score=100.0,
            source="curated",
            provenance="verified_fmcg",
            confidence="high",
        )
        BARCODE_CACHE[code] = candidate
        return FoodBarcodeResponse(barcode=code, candidate=candidate)

    # 3. Fallback: Proxy to Open Food Facts v2
    candidate = await _proxy_off_product_barcode(code)
    if candidate:
        BARCODE_CACHE[code] = candidate
        return FoodBarcodeResponse(barcode=code, candidate=candidate)

    # 4. Missed search log & 404
    _log_missed_search(f"barcode:{code}")
    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=f"Barcode {code} not found in catalog or provider database.",
    )


def get_missed_searches() -> List[Dict[str, Any]]:
    return list(MISSED_SEARCHES)


def clear_missed_searches() -> None:
    MISSED_SEARCHES.clear()


def get_search_hit_stats(top_n: int = 50) -> Dict[str, int]:
    return dict(SEARCH_HIT_COUNTER.most_common(top_n))


def clear_search_hit_stats() -> None:
    SEARCH_HIT_COUNTER.clear()
