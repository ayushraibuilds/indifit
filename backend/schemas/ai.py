from typing import Optional
from pydantic import BaseModel


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
