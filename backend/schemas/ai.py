from typing import Dict, List, Literal, Optional
from pydantic import BaseModel, Field, field_validator


ExperienceLevel = Literal["beginner", "intermediate", "advanced"]


class RoutineRequest(BaseModel):
    goal: str = Field(..., min_length=1)
    equipment: str = Field(..., min_length=1)
    days_per_week: int = Field(..., ge=1, le=7)
    experience: ExperienceLevel
    injuries: str = Field(default="")

    @field_validator("goal", "equipment")
    @classmethod
    def validate_not_empty(cls, v: str) -> str:
        s = v.strip()
        if not s:
            raise ValueError("Field cannot be empty or whitespace.")
        return s

    @field_validator("experience", mode="before")
    @classmethod
    def normalize_experience(cls, v: str) -> str:
        if isinstance(v, str):
            v_clean = v.strip().lower()
            if v_clean in {"beginner", "intermediate", "advanced"}:
                return v_clean
        raise ValueError("experience must be one of: beginner, intermediate, advanced.")

    @field_validator("injuries")
    @classmethod
    def strip_injuries(cls, v: str) -> str:
        return v.strip()


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
    calorie_goal: int = Field(..., ge=500, le=10000)
    diet_preference: str = Field(..., min_length=1)
    days: int = Field(..., ge=1, le=7)

    @field_validator("diet_preference")
    @classmethod
    def validate_diet_preference(cls, v: str) -> str:
        s = v.strip()
        if not s:
            raise ValueError("diet_preference cannot be empty or whitespace.")
        return s


class WeeklyReportRequest(BaseModel):
    total_calories_logged: int = Field(..., ge=0)
    calorie_goal: int = Field(..., ge=500, le=70000)
    workout_sessions_count: int = Field(..., ge=0)
    total_volume_kg: float = Field(..., ge=0.0)
    prs_count: int = Field(..., ge=0)
    adherence_score: float = Field(..., ge=0.0, le=100.0)
    date_range: Optional[str] = None
    nutrition_days_logged: Optional[int] = None
    calorie_adherence_pct: Optional[float] = None
    protein_adherence_pct: Optional[float] = None
    hydration_days_at_goal: Optional[int] = None
    completed_workouts: Optional[int] = None
    planned_workouts: Optional[int] = None
