from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field, field_validator


class FoodSearchRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=100)
    language: str = Field(default="hinglish")
    page: int = Field(default=1, ge=1)
    limit: int = Field(default=20, ge=1, le=50)
    include_provider: bool = Field(default=True)

    @field_validator("query")
    @classmethod
    def validate_query(cls, v: str) -> str:
        s = v.strip()
        if not s:
            raise ValueError("Search query cannot be empty or whitespace.")
        return s


class FoodItem(BaseModel):
    id: Optional[str] = None
    name: str
    name_hindi: Optional[str] = None
    brand: Optional[str] = None
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
    serving_options: Optional[List[Dict[str, Any]]] = None
    score: float = 0.0
    source: str = "curated"
    provenance: Optional[str] = None
    confidence: Optional[str] = "high"


class FoodSearchResponse(BaseModel):
    results: List[FoodItem]
    count: int
    total_hits: int = 0
    has_more: bool = False
    query: str
    transliterated_query: Optional[str] = None


class FoodBarcodeResponse(BaseModel):
    barcode: str
    candidate: Optional[FoodItem] = None
