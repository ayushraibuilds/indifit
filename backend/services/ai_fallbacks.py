from backend.schemas.ai import (
    MealPlanRequest,
    RoutineRequest,
    WeeklyReportRequest,
)


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
                {"name": "Tricep Pushdown", "sets": 3, "reps": "12-15"},
            ],
        })
        days.append({"name": "Rest Day", "day_of_week": 2, "is_rest_day": True, "exercises": []})
        days.append({
            "name": "Day 2: Back & Biceps (Pull)",
            "day_of_week": 3,
            "is_rest_day": False,
            "exercises": [
                {"name": "Lat Pulldown", "sets": 4, "reps": "10-12"},
                {"name": "Bicep Dumbbell Curl", "sets": 3, "reps": "12"},
                {"name": "Romanian Deadlift (RDL)", "sets": 3, "reps": "8-10"},
            ],
        })
        days.append({"name": "Rest Day", "day_of_week": 4, "is_rest_day": True, "exercises": []})
        days.append({
            "name": "Day 3: Lower Body (Legs)",
            "day_of_week": 5,
            "is_rest_day": False,
            "exercises": [
                {"name": "Barbell Squat", "sets": 4, "reps": "8-10"},
                {"name": "Romanian Deadlift (RDL)", "sets": 3, "reps": "10-12"},
            ],
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
                {"name": "Bicep Dumbbell Curl", "sets": 3, "reps": "12"},
            ],
        })
        days.append({
            "name": "Day 2: Lower Body A",
            "day_of_week": 2,
            "is_rest_day": False,
            "exercises": [
                {"name": "Barbell Squat", "sets": 4, "reps": "8-10"},
                {"name": "Romanian Deadlift (RDL)", "sets": 4, "reps": "10"},
            ],
        })
        days.append({"name": "Rest Day", "day_of_week": 3, "is_rest_day": True, "exercises": []})
        days.append({
            "name": "Day 3: Upper Body B",
            "day_of_week": 4,
            "is_rest_day": False,
            "exercises": [
                {"name": "Incline Dumbbell Press", "sets": 4, "reps": "10"},
                {"name": "Lat Pulldown", "sets": 3, "reps": "12"},
                {"name": "Tricep Pushdown", "sets": 3, "reps": "12-15"},
            ],
        })
        days.append({
            "name": "Day 4: Lower Body B",
            "day_of_week": 5,
            "is_rest_day": False,
            "exercises": [
                {"name": "Barbell Squat", "sets": 3, "reps": "12"},
                {"name": "Romanian Deadlift (RDL)", "sets": 3, "reps": "12"},
            ],
        })
        days.append({"name": "Rest Day", "day_of_week": 6, "is_rest_day": True, "exercises": []})
        days.append({"name": "Rest Day", "day_of_week": 7, "is_rest_day": True, "exercises": []})

    return {
        "name": name,
        "notes": notes,
        "days": days,
        "is_fallback": True,
        "fallback_reason": reason,
    }


def _mock_meal_estimate(text: str, name: str = "", reason: str = ""):
    text_lower = text.lower()
    if "roti" in text_lower or "chapati" in text_lower:
        meal = {
            "name": name or "Roti with Dal & Veg",
            "calories": 380,
            "protein": 12.5,
            "carbs": 58.0,
            "fat": 8.0,
            "serving_size": 1.0,
            "serving_unit": "plate",
        }
    elif "chicken" in text_lower or "egg" in text_lower:
        meal = {
            "name": name or "High Protein Chicken Salad",
            "calories": 420,
            "protein": 38.0,
            "carbs": 12.0,
            "fat": 16.0,
            "serving_size": 1.0,
            "serving_unit": "bowl",
        }
    else:
        meal = {
            "name": name or "Mixed Indian Dish",
            "calories": 350,
            "protein": 8.0,
            "carbs": 48.0,
            "fat": 10.0,
            "serving_size": 1.0,
            "serving_unit": "serving",
        }
    meal["is_fallback"] = True
    meal["fallback_reason"] = reason
    return meal


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


def _mock_nutrition_label_ocr(reason: str = ""):
    return {
        "product_name": "Rolled Oats",
        "brand_name": "True Elements",
        "serving_size_amount": 40.0,
        "serving_size_unit": "g",
        "serving_description": "1/2 cup (40g)",
        "servings_per_container": 12.5,
        "basis": "per_100g",
        "nutrients": {
            "calories": {
                "value": 389.0,
                "unit": "kcal",
                "confidence": "high",
                "notes": "Energy",
            },
            "protein": {
                "value": 13.5,
                "unit": "g",
                "confidence": "high",
                "notes": "Protein",
            },
            "carbs": {
                "value": 66.3,
                "unit": "g",
                "confidence": "high",
                "notes": "Carbohydrates",
            },
            "fat": {
                "value": 6.9,
                "unit": "g",
                "confidence": "high",
                "notes": "Total Fat",
            },
            "fiber": {
                "value": 10.0,
                "unit": "g",
                "confidence": "medium",
                "notes": "Dietary Fiber",
            },
            "sodium": {
                "value": 4.0,
                "unit": "mg",
                "confidence": "medium",
                "notes": "Sodium",
            },
        },
        "raw_text": "Nutrition Facts Per 100g: Energy 389 kcal, Protein 13.5g, Carbs 66.3g, Fat 6.9g",
        "is_fallback": True,
        "fallback_reason": reason,
    }


def _mock_meal_decomposition(text: str, reason: str = ""):
    text_lower = text.lower()
    items = []

    if "roti" in text_lower or "chapati" in text_lower:
        items.append({
            "raw_segment": "2 rotis" if "2" in text_lower else "1 roti",
            "food_name": "Whole Wheat Roti",
            "quantity_amount": 2.0 if "2" in text_lower else 1.0,
            "quantity_unit": "roti",
            "estimated_calories": 160 if "2" in text_lower else 80,
            "estimated_protein": 5.0 if "2" in text_lower else 2.5,
            "estimated_carbs": 30.0 if "2" in text_lower else 15.0,
            "estimated_fat": 1.6 if "2" in text_lower else 0.8,
            "confidence": "high",
        })

    if "dal" in text_lower or "tadka" in text_lower:
        items.append({
            "raw_segment": "1 katori dal tadka",
            "food_name": "Yellow Dal Tadka",
            "quantity_amount": 1.0,
            "quantity_unit": "katori",
            "estimated_calories": 150,
            "estimated_protein": 7.5,
            "estimated_carbs": 21.0,
            "estimated_fat": 4.2,
            "confidence": "high",
        })

    if "paneer" in text_lower:
        items.append({
            "raw_segment": "100g paneer bhurji",
            "food_name": "Paneer Bhurji",
            "quantity_amount": 100.0,
            "quantity_unit": "g",
            "estimated_calories": 215,
            "estimated_protein": 13.8,
            "estimated_carbs": 4.5,
            "estimated_fat": 16.2,
            "confidence": "high",
        })

    if "curd" in text_lower or "dahi" in text_lower:
        items.append({
            "raw_segment": "1 small bowl curd",
            "food_name": "Plain Curd (Dahi)",
            "quantity_amount": 1.0,
            "quantity_unit": "bowl",
            "estimated_calories": 90,
            "estimated_protein": 4.2,
            "estimated_carbs": 5.8,
            "estimated_fat": 5.0,
            "confidence": "high",
        })

    if not items:
        items.append({
            "raw_segment": text.strip(),
            "food_name": text.strip().title(),
            "quantity_amount": 1.0,
            "quantity_unit": "serving",
            "estimated_calories": 320,
            "estimated_protein": 8.0,
            "estimated_carbs": 42.0,
            "estimated_fat": 9.0,
            "confidence": "medium",
        })

    total_cals = sum(item["estimated_calories"] for item in items)
    return {
        "query": text,
        "items": items,
        "total_calories": total_cals,
        "is_fallback": True,
        "fallback_reason": reason,
    }
