import os
import json
import base64
import secrets
import time
import hashlib
from typing import List, Optional, Dict, Any
from fastapi import (
    APIRouter,
    Depends,
    FastAPI,
    File,
    Form,
    Header,
    HTTPException,
    Request,
    Response,
    UploadFile,
    status,
)
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import httpx
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="IndiFit AI Backend")

# Enable CORS for local app testing with restricted origins in production
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "http://localhost,http://127.0.0.1,http://10.0.2.2,https://indifit.app").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
AI_MODEL = os.getenv("AI_MODEL", "gemini-1.5-flash")

# No fallback here on purpose: the old default ("indifit_secret_key_v1") was
# shipped inside every APK, so anyone could decompile the app and hit this
# backend directly. Failing closed at startup instead of silently falling
# back to an empty/known key (verify_api_key below treats a falsy key as
# "auth disabled", so a quiet default would have made things worse, not
# better).
INDIFIT_API_KEY = os.getenv("INDIFIT_API_KEY")
if not INDIFIT_API_KEY:
    raise RuntimeError(
        "INDIFIT_API_KEY environment variable must be set (no default is "
        "provided for security reasons). Set it in your deployment "
        "environment, e.g. the Render dashboard."
    )

# In-memory 24h TTL cache & per-IP rate limiter
RESPONSE_CACHE: Dict[str, dict] = {}
CACHE_TTL_SECONDS = 86400

# This limiter is process-local and volatile. It is appropriate for the current
# single-process deployment, but it is not a global quota across workers or
# horizontally scaled instances.
IP_REQUEST_LOGS: Dict[str, List[float]] = {}
RATE_LIMIT_WINDOW = 3600  # 1 hour
MAX_REQUESTS_PER_WINDOW = 30

async def verify_api_key(x_indifit_key: Optional[str] = Header(None)):
    if not INDIFIT_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Server authentication is not configured",
        )
    if x_indifit_key is None or not secrets.compare_digest(
        x_indifit_key,
        INDIFIT_API_KEY,
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
    timestamps = [t for t in timestamps if now - t < RATE_LIMIT_WINDOW]
    
    if len(timestamps) >= MAX_REQUESTS_PER_WINDOW:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Rate limit exceeded. Maximum 30 AI requests per hour per IP allowed.",
        )
    
    timestamps.append(now)
    IP_REQUEST_LOGS[client_ip] = timestamps

ai_router = APIRouter(
    prefix="/api/ai",
    dependencies=[
        Depends(verify_api_key),
        Depends(enforce_rate_limit),
    ],
)

@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "gemini_configured": bool(GEMINI_API_KEY),
        "model": AI_MODEL,
        "timestamp": time.time()
    }

# Schema definitions
class RoutineRequest(BaseModel):
    goal: str
    equipment: str
    days_per_week: int
    experience: str
    injuries: str

class TextMealRequest(BaseModel):
    text: str

class MealPlanRequest(BaseModel):
    calorie_goal: int = 2000
    diet_preference: str = "veg"
    days: int = 7

# Helper to execute Gemini requests
async def query_gemini_text(prompt: str, json_mode: bool = False) -> str:
    if not GEMINI_API_KEY:
        raise ValueError("Missing GEMINI_API_KEY env variable")
        
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{AI_MODEL}:generateContent?key={GEMINI_API_KEY}"
    
    headers = {"Content-Type": "application/json"}
    payload: Dict[str, Any] = {
        "contents": [{"parts": [{"text": prompt}]}],
    }
    
    if json_mode:
        payload["generationConfig"] = {
            "responseMimeType": "application/json"
        }
        
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(url, headers=headers, json=payload)
        if response.status_code != 200:
            raise HTTPException(status_code=500, detail=f"Gemini API Error: {response.text}")
            
        data = response.json()
        try:
            return data["candidates"][0]["content"]["parts"][0]["text"]
        except (KeyError, IndexError):
            raise HTTPException(status_code=500, detail="Malformed response from Gemini API")

async def query_gemini_vision(prompt: str, image_bytes: bytes, mime_type: str) -> str:
    if not GEMINI_API_KEY:
        raise ValueError("Missing GEMINI_API_KEY env variable")
        
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{AI_MODEL}:generateContent?key={GEMINI_API_KEY}"
    
    headers = {"Content-Type": "application/json"}
    
    # Format image to inline data
    base64_image = base64.b64encode(image_bytes).decode("utf-8")
    
    payload: Dict[str, Any] = {
        "contents": [
            {
                "parts": [
                    {"text": prompt},
                    {
                        "inlineData": {
                            "mimeType": mime_type,
                            "data": base64_image
                        }
                    }
                ]
            }
        ],
        "generationConfig": {
            "responseMimeType": "application/json"
        }
    }
    
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(url, headers=headers, json=payload)
        if response.status_code != 200:
            raise HTTPException(status_code=500, detail=f"Gemini API Error: {response.text}")
            
        data = response.json()
        try:
            return data["candidates"][0]["content"]["parts"][0]["text"]
        except (KeyError, IndexError):
            raise HTTPException(status_code=500, detail="Malformed response from Gemini API")


@app.get("/")
def home():
    return {"status": "online", "message": "IndiFit AI Backend Running"}


@ai_router.post("/routine")
async def generate_routine(req: RoutineRequest):
    prompt = f"""
    Act as a professional fitness coach. Generate a structured weekly training program matching these parameters:
    Goal: {req.goal} (hypertrophy / strength / weight_loss)
    Equipment available: {req.equipment} (gym / dumbbells / bodyweight)
    Training frequency: {req.days_per_week} days per week
    Experience level: {req.experience} (beginner / intermediate / advanced)
    Injuries or constraints: {req.injuries}
    
    You must output a JSON object containing:
    1. "name": String (e.g. "AI Hypertrophy Split")
    2. "notes": String (coaching tips, injury workarounds, volume suggestions)
    3. "days": List of daily schedules, each day having:
       - "name": String (e.g. "Day 1: Chest & Shoulders")
       - "day_of_week": Integer (1 for Monday, 7 for Sunday)
       - "is_rest_day": Boolean
       - "exercises": List of exercises (if not rest day), each having:
         - "name": String (exercise name)
         - "sets": Integer (count of sets)
         - "reps": String (reps range, e.g. "8-12" or "5")
         
    Format the response strictly as valid JSON matching this schema. Do not output any markdown text.
    """
    
    try:
        if not GEMINI_API_KEY:
            return _mock_routine(req, reason="Missing GEMINI_API_KEY env variable")
            
        result = await query_gemini_text(prompt, json_mode=True)
        data = json.loads(result)
        data["is_fallback"] = False
        return data
    except HTTPException:
        raise
    except Exception as e:
        return _mock_routine(req, notes=f"Fallback Mock: {str(e)}", reason=str(e))


@ai_router.post("/meal-estimate-text")
async def estimate_meal_text(req: TextMealRequest):
    prompt = f"""
    Act as a professional clinical dietitian. Estimate the nutritional parameters (calories and macronutrients) for this food intake:
    Description: "{req.text}"
    
    You must output a JSON object containing:
    - "name": String (Common name of the food logged)
    - "calories": Integer (Total kcal)
    - "protein": Float (g)
    - "carbs": Float (g)
    - "fat": Float (g)
    - "serving_size": Float (relative multiplier e.g. 1.0)
    - "serving_unit": String (e.g., "serving", "plate", "pieces")
    
    For popular Indian food items, balance macros according to standard cooked yields (e.g., 1 roti = 70-80 kcal, 2.5g protein, 15g carbs).
    Format the response strictly as valid JSON. Do not output markdown text.
    """
    
    try:
        if not GEMINI_API_KEY:
            return _mock_meal_estimate(req.text, reason="Missing GEMINI_API_KEY env variable")
            
        result = await query_gemini_text(prompt, json_mode=True)
        data = json.loads(result)
        data["is_fallback"] = False
        return data
    except HTTPException:
        raise
    except Exception as e:
        return _mock_meal_estimate(req.text, name=f"Estimated: {req.text[:20]}", reason=str(e))


@ai_router.post("/meal-estimate-photo")
async def estimate_meal_photo(image: UploadFile = File(...)):
    prompt = """
    Act as a professional clinical dietitian. Inspect this food photo and estimate the nutritional parameters (calories and macronutrients).
    
    You must output a JSON object containing:
    - "name": String (Identified food items)
    - "calories": Integer (Total estimated kcal)
    - "protein": Float (g)
    - "carbs": Float (g)
    - "fat": Float (g)
    - "serving_size": Float (serving multiplier, e.g. 1.0)
    - "serving_unit": String (e.g., "serving", "bowl", "plate")
    
    Format the response strictly as valid JSON. Do not output markdown text.
    """
    
    try:
        mime_type = image.content_type or "image/jpeg"
        if mime_type not in {"image/jpeg", "image/jpg", "image/png", "image/webp"}:
            raise HTTPException(
                status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                detail="Invalid image MIME type. Allowed: JPEG, PNG, WebP.",
            )

        image_bytes = await image.read()
        if len(image_bytes) > 5 * 1024 * 1024:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail="File size exceeds maximum upload limit of 5 MB.",
            )
        
        if not GEMINI_API_KEY:
            return _mock_meal_estimate("Photo Upload", reason="Missing GEMINI_API_KEY env variable")
            
        result = await query_gemini_vision(prompt, image_bytes, mime_type)
        data = json.loads(result)
        data["is_fallback"] = False
        return data
    except HTTPException:
        raise
    except Exception as e:
        return _mock_meal_estimate("Photo Estimate Fallback", reason=str(e))


@ai_router.post("/meal-plan")
async def generate_meal_plan(req: MealPlanRequest):
    prompt = f"""
    Act as an expert Indian clinical dietitian. Generate a structured 7-day weekly meal plan tailored for:
    Daily Calorie Target: {req.calorie_goal} kcal
    Dietary Preference: {req.diet_preference} (veg / non-veg / vegan)
    
    Output a single JSON object containing:
    1. "days": List of 7 daily meal plans (Monday to Sunday), each day having:
       - "day": String (e.g. "Monday")
       - "breakfast": String (description with kcal and protein e.g. "Oats Upma - 350 kcal | P: 12g")
       - "lunch": String (description with kcal and protein)
       - "dinner": String (description with kcal and protein)
       - "snacks": String (description with kcal and protein)
    2. "grocery_list": List of Strings (aggregated ingredients needed for the 7-day plan)
    
    Format the response strictly as valid JSON matching this schema. Do not include markdown text.
    """
    
    try:
        if not GEMINI_API_KEY:
            return _mock_meal_plan(req, reason="Missing GEMINI_API_KEY env variable")
            
        result = await query_gemini_text(prompt, json_mode=True)
        data = json.loads(result)
        data["is_fallback"] = False
        return data
    except HTTPException:
        raise
    except Exception as e:
        return _mock_meal_plan(req, reason=str(e))


def _mock_meal_plan(req: MealPlanRequest, reason: str = ""):
    days = [
        {
            "day": "Monday",
            "breakfast": "Oats Upma (1 bowl) with almonds (10 pcs) - 350 kcal | P: 12g",
            "lunch": "Paneer Bhurji (150g) with 2 Chapatis & Curd - 550 kcal | P: 28g",
            "dinner": "Yellow Dal Tadka (1 bowl) with Mixed Veg & 2 Chapatis - 480 kcal | P: 18g",
            "snacks": "Roasted Chana (50g) & Green Tea - 180 kcal | P: 9g",
        },
        {
            "day": "Tuesday",
            "breakfast": "Paneer Stuffed Paratha (1 pc) with curd - 380 kcal | P: 14g",
            "lunch": "Soya Chunks Curry (1 bowl) with Jeera Rice - 520 kcal | P: 26g",
            "dinner": "Moong Dal Khichdi (1 plate) with ghee - 440 kcal | P: 12g",
            "snacks": "Whey Protein Shake with 1 banana - 250 kcal | P: 26g",
        },
        {
            "day": "Wednesday",
            "breakfast": "Besan Cheela (2 pcs) with mint chutney - 320 kcal | P: 12g",
            "lunch": "Chickpea (Chole) Salad with cucumber & tomatoes - 480 kcal | P: 18g",
            "dinner": "Tofu Stir-fry (150g) with brown rice (1 cup) - 510 kcal | P: 22g",
            "snacks": "Mixed seeds (1 handful) & Green Tea - 190 kcal | P: 6g",
        },
        {
            "day": "Thursday",
            "breakfast": "Sprouted Moong Salad (1 bowl) - 280 kcal | P: 14g",
            "lunch": "Dal Makhani (1 bowl) with Jeera Rice & Veg Salad - 540 kcal | P: 16g",
            "dinner": "Paneer Tikka (150g) with Grilled Bell Peppers - 460 kcal | P: 24g",
            "snacks": "Roasted Makhana (1 bowl) - 150 kcal | P: 3g",
        },
        {
            "day": "Friday",
            "breakfast": "Idli (3 pcs) with Sambhar - 310 kcal | P: 8g",
            "lunch": "Palak Paneer (150g) with 2 Chapatis - 520 kcal | P: 24g",
            "dinner": "Black Eyed Peas (Lobia) Curry with brown rice - 490 kcal | P: 18g",
            "snacks": "Boiled Peanut Salad (50g) - 200 kcal | P: 8g",
        },
        {
            "day": "Saturday",
            "breakfast": "Oats Porridge with 1 scoop Whey Protein - 360 kcal | P: 30g",
            "lunch": "Rajma Masala (1 bowl) with Jeera Rice - 540 kcal | P: 18g",
            "dinner": "Paneer Kathi Roll (1 pc) - 480 kcal | P: 20g",
            "snacks": "Buttermilk (1 glass) & Roasted Chana - 160 kcal | P: 7g",
        },
        {
            "day": "Sunday",
            "breakfast": "Vegetable Poha (1 bowl) with peanuts - 290 kcal | P: 7g",
            "lunch": "Mix Dal Khichdi (1 plate) with Curd - 480 kcal | P: 16g",
            "dinner": "Paneer Bhurji (150g) with 2 multigrain rotis - 530 kcal | P: 28g",
            "snacks": "Fruit Salad (Papaya, Apple) - 120 kcal | P: 1g",
        },
    ]
    grocery_list = [
        "Rolled Oats (1 kg)",
        "Paneer (500g)",
        "Moong Dal & Toor Dal (1 kg each)",
        "Soya Chunks (200g)",
        "Mixed Vegetables (Onion, Tomato, Spinach, Bell Pepper)",
        "Whole Wheat Atta & Rice",
        "Roasted Chana & Makhana",
        "Almonds & Mixed Seeds",
        "Curd / Yogurt (1 kg)",
        "Fruits (Apples, Papaya, Bananas)",
    ]
    return {
        "days": days,
        "grocery_list": grocery_list,
        "is_fallback": True,
        "fallback_reason": reason,
    }


def _mock_routine(req: RoutineRequest, notes: str = "", reason: str = ""):
    # High-quality offline fallback constructor for development testing
    name = f"AI {req.experience.title()} {req.goal.title()} Split"
    notes = notes or f"Custom compiled program for {req.equipment} training. Standard tempo: 2-0-2-0. Rest 90s between sets."
    
    days = []
    if req.days_per_week == 3:
        days.append({
            "name": "Day 1: Chest & Shoulders (Push)",
            "day_of_week": 1,
            "is_rest_day": False,
            "exercises": [
                {"name": "Flat Barbell Bench Press", "sets": 4, "reps": "8-12"},
                {"name": "Dumbbell Shoulder Press", "sets": 3, "reps": "10-12"},
                {"name": "Incline Dumbbell Press", "sets": 3, "reps": "10"},
                {"name": "Tricep Pushdown", "sets": 3, "reps": "12-15"}
            ]
        })
        days.append({"name": "Rest Day", "day_of_week": 2, "is_rest_day": True, "exercises": []})
        days.append({
            "name": "Day 2: Back & Biceps (Pull)",
            "day_of_week": 3,
            "is_rest_day": False,
            "exercises": [
                {"name": "Lat Pulldown", "sets": 4, "reps": "10-12"},
                {"name": "Bicep Dumbbell Curl", "sets": 3, "reps": "12"},
                {"name": "Romanian Deadlift (RDL)", "sets": 3, "reps": "8-10"}
            ]
        })
        days.append({"name": "Rest Day", "day_of_week": 4, "is_rest_day": True, "exercises": []})
        days.append({
            "name": "Day 3: Lower Body (Legs)",
            "day_of_week": 5,
            "is_rest_day": False,
            "exercises": [
                {"name": "Barbell Squat", "sets": 4, "reps": "8-10"},
                {"name": "Romanian Deadlift (RDL)", "sets": 3, "reps": "10-12"}
            ]
        })
        days.append({"name": "Rest Day", "day_of_week": 6, "is_rest_day": True, "exercises": []})
        days.append({"name": "Rest Day", "day_of_week": 7, "is_rest_day": True, "exercises": []})
    else:
        # 4/5 days splits
        days.append({
            "name": "Day 1: Upper Body A",
            "day_of_week": 1,
            "is_rest_day": False,
            "exercises": [
                {"name": "Flat Barbell Bench Press", "sets": 4, "reps": "8-10"},
                {"name": "Lat Pulldown", "sets": 4, "reps": "10"},
                {"name": "Dumbbell Shoulder Press", "sets": 3, "reps": "12"},
                {"name": "Bicep Dumbbell Curl", "sets": 3, "reps": "12"}
            ]
        })
        days.append({
            "name": "Day 2: Lower Body A",
            "day_of_week": 2,
            "is_rest_day": False,
            "exercises": [
                {"name": "Barbell Squat", "sets": 4, "reps": "8-10"},
                {"name": "Romanian Deadlift (RDL)", "sets": 4, "reps": "10"}
            ]
        })
        days.append({"name": "Rest Day", "day_of_week": 3, "is_rest_day": True, "exercises": []})
        days.append({
            "name": "Day 3: Upper Body B",
            "day_of_week": 4,
            "is_rest_day": False,
            "exercises": [
                {"name": "Incline Dumbbell Press", "sets": 4, "reps": "10"},
                {"name": "Lat Pulldown", "sets": 3, "reps": "12"},
                {"name": "Tricep Pushdown", "sets": 3, "reps": "12-15"}
            ]
        })
        days.append({
            "name": "Day 4: Lower Body B",
            "day_of_week": 5,
            "is_rest_day": False,
            "exercises": [
                {"name": "Barbell Squat", "sets": 3, "reps": "12"},
                {"name": "Romanian Deadlift (RDL)", "sets": 3, "reps": "12"}
            ]
        })
        days.append({"name": "Rest Day", "day_of_week": 6, "is_rest_day": True, "exercises": []})
        days.append({"name": "Rest Day", "day_of_week": 7, "is_rest_day": True, "exercises": []})

    return {
        "name": name,
        "notes": notes,
        "days": days,
        "is_fallback": True,
        "fallback_reason": reason
    }


def _mock_meal_estimate(text: str, name: str = "", reason: str = ""):
    # Heuristics based local mock estimator
    text_lower = text.lower()
    if "roti" in text_lower or "chapati" in text_lower:
        meal = {
            "name": name or "Roti with Dal & Veg",
            "calories": 380,
            "protein": 12.5,
            "carbs": 58.0,
            "fat": 8.0,
            "serving_size": 1.0,
            "serving_unit": "plate"
        }
    elif "chicken" in text_lower or "egg" in text_lower:
        meal = {
            "name": name or "High Protein Chicken Salad",
            "calories": 420,
            "protein": 38.0,
            "carbs": 12.0,
            "fat": 16.0,
            "serving_size": 1.0,
            "serving_unit": "bowl"
        }
    else:
        meal = {
            "name": name or "Mixed Indian Dish",
            "calories": 350,
            "protein": 8.0,
            "carbs": 48.0,
            "fat": 10.0,
            "serving_size": 1.0,
            "serving_unit": "serving"
        }
    meal["is_fallback"] = True
    meal["fallback_reason"] = reason
    return meal


class WeeklyReportRequest(BaseModel):
    total_calories_logged: int = 14000
    calorie_goal: int = 14000
    workout_sessions_count: int = 4
    total_volume_kg: float = 12500.0
    prs_count: int = 2
    adherence_score: float = 85.0
    date_range: Optional[str] = None
    nutrition_days_logged: Optional[int] = 0
    calorie_adherence_pct: Optional[float] = None
    protein_adherence_pct: Optional[float] = None
    hydration_days_at_goal: Optional[int] = 0
    completed_workouts: Optional[int] = 0
    planned_workouts: Optional[int] = 0

def _mock_weekly_report(req: WeeklyReportRequest, reason: str = ""):
    date_context = f"For the period {req.date_range}: " if req.date_range else ""
    summary_parts = []
    if req.nutrition_days_logged and req.nutrition_days_logged > 0:
        summary_parts.append(
            f"Logged nutrition on {req.nutrition_days_logged} out of 7 days ({req.total_calories_logged} total kcal)."
        )
    else:
        summary_parts.append(f"Logged {req.total_calories_logged} total kcal.")

    if req.planned_workouts and req.planned_workouts > 0:
        summary_parts.append(
            f"Completed {req.workout_sessions_count} of {req.planned_workouts} planned workouts ({req.total_volume_kg:.0f} kg volume lifted)."
        )
    else:
        summary_parts.append(
            f"Completed {req.workout_sessions_count} workouts ({req.total_volume_kg:.0f} kg volume lifted)."
        )

    return {
        "headline": "Weekly Progress Summary",
        "adherence_score": req.adherence_score,
        "summary": date_context + " ".join(summary_parts),
        "coaching_tip": "Focus on progressive overload and maintain daily protein and hydration consistency.",
        "top_prs": [f"{req.prs_count} PRs Hit This Week"] if req.prs_count > 0 else ["Consistent Weekly Effort"],
        "is_fallback": True,
        "fallback_reason": reason,
    }

@ai_router.post("/weekly-report")
async def generate_weekly_report(req: WeeklyReportRequest):
    if not GEMINI_API_KEY:
        return _mock_weekly_report(req, "Gemini API key not configured")

    prompt = f"""
    Act as a professional fitness and nutrition coach. Analyze this user's real 7-day metrics:
    - Date Range: {req.date_range or "Past 7 days"}
    - Nutrition Days Logged: {req.nutrition_days_logged or 0} / 7 days
    - Calories Logged: {req.total_calories_logged} kcal (Goal: {req.calorie_goal} kcal, Calorie Adherence: {req.calorie_adherence_pct or 0:.1f}%)
    - Protein Adherence: {req.protein_adherence_pct or 0:.1f}%
    - Hydration Days at Goal: {req.hydration_days_at_goal or 0} / 7 days
    - Workouts Completed: {req.workout_sessions_count} / {req.planned_workouts or 0} planned
    - Total Volume Lifted: {req.total_volume_kg:.0f} kg
    - Personal Records Hit: {req.prs_count} PRs
    - Overall Adherence Score: {req.adherence_score:.1f}%

    Return a JSON response with keys:
    - headline: short encouraging summary title
    - adherence_score: float
    - summary: paragraph reviewing nutrition & workout volume progress
    - coaching_tip: actionable training/nutrition advice for next week
    - top_prs: list of string achievements
    """

    try:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{AI_MODEL}:generateContent?key={GEMINI_API_KEY}"
        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"response_mime_type": "application/json"}
        }

        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(url, json=payload)

        if response.status_code != 200:
            return _mock_weekly_report(req, f"API HTTP {response.status_code}")

        data = response.json()
        raw_json = data['candidates'][0]['content']['parts'][0]['text']
        parsed = json.loads(raw_json)
        parsed['is_fallback'] = False
        return parsed
    except HTTPException:
        raise
    except Exception as e:
        return _mock_weekly_report(req, str(e))


app.include_router(ai_router)

# ---------------------------------------------------------------------------
# Cloud Backup Route Family (/v1/backup)
# ---------------------------------------------------------------------------

USER_BACKUPS: Dict[str, List[Dict[str, Any]]] = {}
BACKUP_BLOBS: Dict[tuple, Dict[str, Any]] = {}

class BackupSnapshotUploadRequest(BaseModel):
    snapshotId: str
    ciphertextBase64: str
    wrappedKeyBase64: str
    sha256Checksum: str
    byteSize: int
    schemaVersion: int
    backupFormatVersion: int
    deviceName: str
    isWeeklyMilestone: bool = False

def _get_backup_user_id(
    authorization: Optional[str] = Header(None),
    x_indifit_key: Optional[str] = Header(None),
) -> str:
    if authorization and authorization.startswith("Bearer "):
        token = authorization.split("Bearer ", 1)[1].strip()
        if token:
            return hashlib.sha256(token.encode("utf-8")).hexdigest()[:16]
    if x_indifit_key and INDIFIT_API_KEY and secrets.compare_digest(x_indifit_key, INDIFIT_API_KEY):
        return "default_api_user"
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Missing or invalid authentication: provide Authorization Bearer token or valid x-indifit-key.",
    )

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
    # --- Field validation (fail closed with 400/422, never 500) ---
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

    # Idempotent upsert by snapshotId: retrying the same snapshot must not
    # create unbounded duplicates.
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

app.include_router(backup_router)

# ==============================================================================
# Multi-Device Sync Relay API (PV1-SYNC-01B)
# ==============================================================================

class HlcModel(BaseModel):
    millis: int
    counter: int
    node_id: str

class SyncMutationModel(BaseModel):
    entity_id: str
    domain: str
    type: str  # insert, update, delete
    hlc: HlcModel
    payload: Optional[Dict[str, Any]] = None
    encrypted_envelope: Optional[Dict[str, Any]] = None

class SyncPushRequestModel(BaseModel):
    mutations: List[SyncMutationModel]

class SyncPushResponseModel(BaseModel):
    accepted_count: int
    server_received_hlc: HlcModel

class SyncPullResponseModel(BaseModel):
    mutations: List[SyncMutationModel]
    has_more: bool
    latest_hlc: Optional[HlcModel] = None

sync_router = APIRouter(prefix="/v1/sync", tags=["sync"])

USER_MUTATIONS: Dict[str, List[dict]] = {}

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
        # Encrypted-envelope validation (blind relay by construction: the relay
        # stores opaque dicts and indexes metadata only — it never decrypts and
        # never inspects envelope contents beyond these structural checks).
        # Fail closed with 400/413, never 500.
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

app.include_router(sync_router)
