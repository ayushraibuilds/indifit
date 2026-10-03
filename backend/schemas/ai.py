from typing import Dict, List, Literal, Optional
from pydantic import BaseModel, Field, field_validator


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
    category_id: Optional[str] = None
    fiber_g: Optional[float] = None
    sodium_mg: Optional[float] = None


class MealDecompositionResponse(BaseModel):
    query: str = ""
    items: List[MealDecompositionItem] = Field(default_factory=list)
    total_calories: int = 0
    confidence: Optional[ConfidenceLevel] = "medium"
    disclaimer: Optional[str] = (
        "AI estimate carries ±30% variance. Review quantities before saving."
    )
