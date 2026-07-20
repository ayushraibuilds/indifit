import os
import json
import base64
import time
import hashlib
from typing import List, Optional, Dict, Any
from fastapi import FastAPI, HTTPException, UploadFile, File, Form, Header, Depends, status
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
INDIFIT_API_KEY = os.getenv("INDIFIT_API_KEY", "indifit_secret_key_v1")
AI_MODEL = os.getenv("AI_MODEL", "gemini-1.5-flash")

# In-memory 24h TTL cache
RESPONSE_CACHE: Dict[str, dict] = {}
CACHE_TTL_SECONDS = 86400

async def verify_api_key(x_indifit_key: Optional[str] = Header(None)):
    if INDIFIT_API_KEY and x_indifit_key != INDIFIT_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing x-indifit-key authentication header",
        )
    return x_indifit_key

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
        
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={GEMINI_API_KEY}"
    
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
        
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={GEMINI_API_KEY}"
    
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


@app.post("/api/ai/routine")
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
    except Exception as e:
        return _mock_routine(req, notes=f"Fallback Mock: {str(e)}", reason=str(e))


@app.post("/api/ai/meal-estimate-text")
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
    except Exception as e:
        return _mock_meal_estimate(req.text, name=f"Estimated: {req.text[:20]}", reason=str(e))


@app.post("/api/ai/meal-estimate-photo")
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
        image_bytes = await image.read()
        mime_type = image.content_type or "image/jpeg"
        
        if not GEMINI_API_KEY:
            return _mock_meal_estimate("Photo Upload", reason="Missing GEMINI_API_KEY env variable")
            
        result = await query_gemini_vision(prompt, image_bytes, mime_type)
        data = json.loads(result)
        data["is_fallback"] = False
        return data
    except Exception as e:
        return _mock_meal_estimate("Photo Estimate Fallback", reason=str(e))


@app.post("/api/ai/meal-plan")
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

def _mock_weekly_report(req: WeeklyReportRequest, reason: str = ""):
    return {
        "headline": "Outstanding Consistency This Week!",
        "adherence_score": req.adherence_score,
        "summary": f"You completed {req.workout_sessions_count} workouts and hit {req.prs_count} Personal Records with {req.total_volume_kg:.0f} kg total volume lifted.",
        "coaching_tip": "Maintain your protein intake post-workout and prioritize 7-8 hours of sleep for optimal recovery.",
        "top_prs": ["Bench Press 80kg x 5", "Barbell Squat 100kg x 3"],
        "is_fallback": True,
        "fallback_reason": reason
    }

@app.post("/api/ai/weekly-report")
async def generate_weekly_report(req: WeeklyReportRequest):
    if not GEMINI_API_KEY:
        return _mock_weekly_report(req, "Gemini API key not configured")

    prompt = f"""
    Analyze this user's fitness progress over the past 7 days:
    - Calories Logged: {req.total_calories_logged} kcal (Goal: {req.calorie_goal} kcal)
    - Workouts Completed: {req.workout_sessions_count} sessions
    - Total Volume Lifted: {req.total_volume_kg} kg
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
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={GEMINI_API_KEY}"
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
    except Exception as e:
        return _mock_weekly_report(req, str(e))

