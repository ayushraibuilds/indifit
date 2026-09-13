from typing import Dict, List, Literal, Optional
from pydantic import BaseModel, Field, field_validator


class RoutineRequest(BaseModel):
    goal: str
    equipment: str
    days_per_week: int
    experience: str
    injuries: str


class TextMealRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=500)

    @field_validator("text")
    @classmethod
    def validate_not_empty(cls, v: str) -> str:
        s = v.strip()
        if not s:
            raise ValueError("Meal text cannot be empty or whitespace.")
        return s


ConfidenceLevel = Literal["high", "medium", "low"]
NutritionBasis = Literal["per_serving", "per_100g"]


class NutrientOcrField(BaseModel):
    value: Optional[float] = None
    unit: str = "g"
    confidence: ConfidenceLevel = "medium"
    notes: Optional[str] = None


class NutritionLabelOcrResponse(BaseModel):
    product_name: Optional[str] = None
    brand_name: Optional[str] = None
    serving_size_amount: Optional[float] = None
    serving_size_unit: Optional[str] = None
    serving_description: Optional[str] = None
    servings_per_container: Optional[float] = None
    basis: NutritionBasis = "per_100g"
    nutrients: Dict[str, NutrientOcrField] = Field(default_factory=dict)
    raw_text: Optional[str] = None
    is_fallback: bool = False
    fallback_reason: Optional[str] = None


class MealDecompositionItem(BaseModel):
    raw_segment: str
    food_name: str
    quantity_amount: float
    quantity_unit: str
    estimated_calories: int
    estimated_protein: float
    estimated_carbs: float
    estimated_fat: float
    confidence: ConfidenceLevel = "medium"


class MealDecompositionResponse(BaseModel):
    query: str
    items: List[MealDecompositionItem] = Field(default_factory=list)
    total_calories: int = 0
    is_fallback: bool = False
    fallback_reason: Optional[str] = None


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
