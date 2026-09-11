import json
import sys
from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    UploadFile,
    status,
)
import httpx
from backend.core.config import AI_MODEL, get_gemini_api_key
from backend.core.security import enforce_rate_limit, verify_api_key
from backend.schemas.ai import (
    MealPlanRequest,
    RoutineRequest,
    TextMealRequest,
    WeeklyReportRequest,
)
from backend.services import gemini_client
from backend.services.ai_fallbacks import (
    _mock_meal_estimate,
    _mock_meal_plan,
    _mock_routine,
    _mock_weekly_report,
)


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
        if not get_gemini_api_key():
            return _mock_routine(req, reason="Missing GEMINI_API_KEY env variable")

        query_text = _get_query_gemini_text()
        result = await query_text(prompt, json_mode=True)
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
        if not get_gemini_api_key():
            return _mock_meal_estimate(req.text, reason="Missing GEMINI_API_KEY env variable")

        query_text = _get_query_gemini_text()
        result = await query_text(prompt, json_mode=True)
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

        if not get_gemini_api_key():
            return _mock_meal_estimate("Photo Upload", reason="Missing GEMINI_API_KEY env variable")

        query_vision = _get_query_gemini_vision()
        result = await query_vision(prompt, image_bytes, mime_type)
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
        if not get_gemini_api_key():
            return _mock_meal_plan(req, reason="Missing GEMINI_API_KEY env variable")

        query_text = _get_query_gemini_text()
        result = await query_text(prompt, json_mode=True)
        data = json.loads(result)
        data["is_fallback"] = False
        return data
    except HTTPException:
        raise
    except Exception as e:
        return _mock_meal_plan(req, reason=str(e))


@ai_router.post("/weekly-report")
async def generate_weekly_report(req: WeeklyReportRequest):
    gemini_key = get_gemini_api_key()
    if not gemini_key:
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
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{AI_MODEL}:generateContent?key={gemini_key}"
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
