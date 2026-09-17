from typing import List, Optional
from pydantic import BaseModel, Field, field_validator


class FoodSearchRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=100)
    limit: int = Field(default=20, ge=1, le=50)
    include_provider: bool = Field(default=False)

    @field_validator("query")
    @classmethod
    def validate_query(cls, v: str) -> str:
        s = v.strip()
        if not s:
            raise ValueError("Search query cannot be empty or whitespace.")
        return s


class FoodItem(BaseModel):
    name: str
    name_hindi: Optional[str] = None
    category: Optional[str] = None
    category_id: str = "general"
    calories: float
    protein_g: float
    carbs_g: float
    fat_g: float
    fiber_g: Optional[float] = None
    # Truth Contract: Missing sodium in seed data must be null, never 0.0
    sodium_mg: Optional[float] = None
    serving_size: float = 1.0
    serving_unit: str = "serving"
    score: float = 0.0
    source: str = "curated"


class FoodSearchResponse(BaseModel):
    results: List[FoodItem]
    count: int
    query: str
    transliterated_query: Optional[str] = None
