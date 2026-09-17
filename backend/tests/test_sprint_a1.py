import os
import unittest
from unittest.mock import AsyncMock, MagicMock, patch

os.environ.setdefault("INDIFIT_API_KEY", "backend-test-secret")

from fastapi.testclient import TestClient
import httpx
from backend import main
from backend.services.query_cache import (
    clear_cache,
    get_daily_request_count,
    reset_daily_stats,
    set_daily_budget,
)


class SprintA1TestSuite(unittest.TestCase):
    api_key = "backend-test-secret"

    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(main.app)

    def setUp(self):
        main.INDIFIT_API_KEY = self.api_key
        main.GEMINI_API_KEY = ""
        main.IP_REQUEST_LOGS.clear()
        main.MAX_REQUESTS_PER_WINDOW = 100
        main.RATE_LIMIT_WINDOW = 3600
        clear_cache()
        reset_daily_stats(budget=500)

    def tearDown(self):
        main.IP_REQUEST_LOGS.clear()
        clear_cache()
        reset_daily_stats(budget=500)

    @property
    def headers(self):
        return {"x-indifit-key": self.api_key}

    # =========================================================================
    # A1.1: Backend Pydantic Validation on RoutineRequest
    # =========================================================================
    def test_routine_rejects_invalid_days_per_week(self):
        invalid_days = [-1, 0, 8, 999]
        for days in invalid_days:
            with self.subTest(days=days):
                payload = {
                    "goal": "strength",
                    "equipment": "barbell",
                    "days_per_week": days,
                    "experience": "intermediate",
                    "injuries": "",
                }
                res = self.client.post("/api/ai/routine", headers=self.headers, json=payload)
                self.assertEqual(res.status_code, 422, f"Expected 422 for days_per_week={days}")

    def test_routine_rejects_invalid_experience(self):
        payload = {
            "goal": "hypertrophy",
            "equipment": "gym",
            "days_per_week": 4,
            "experience": "expert_ninja",
            "injuries": "",
        }
        res = self.client.post("/api/ai/routine", headers=self.headers, json=payload)
        self.assertEqual(res.status_code, 422)

    def test_routine_rejects_empty_goal_or_equipment(self):
        for field in ["goal", "equipment"]:
            with self.subTest(empty_field=field):
                payload = {
                    "goal": "strength",
                    "equipment": "dumbbells",
                    "days_per_week": 3,
                    "experience": "beginner",
                    "injuries": "",
                }
                payload[field] = "   "
                res = self.client.post("/api/ai/routine", headers=self.headers, json=payload)
                self.assertEqual(res.status_code, 422)

    def test_routine_accepts_valid_payload_with_normalized_experience(self):
        payload = {
            "goal": "strength",
            "equipment": "gym",
            "days_per_week": 3,
            "experience": "Beginner",
            "injuries": "  knee tendinitis  ",
        }
        res = self.client.post("/api/ai/routine", headers=self.headers, json=payload)
        self.assertEqual(res.status_code, 200)

    # =========================================================================
    # A1.2: Strip Hardcoded Defaults (MealPlanRequest & WeeklyReportRequest)
    # =========================================================================
    def test_meal_plan_rejects_empty_payload(self):
        res = self.client.post("/api/ai/meal-plan", headers=self.headers, json={})
        self.assertEqual(res.status_code, 422)

    def test_meal_plan_rejects_missing_required_fields(self):
        full_valid = {"calorie_goal": 2200, "diet_preference": "veg", "days": 7}
        for field in full_valid.keys():
            with self.subTest(missing_field=field):
                partial = {k: v for k, v in full_valid.items() if k != field}
                res = self.client.post("/api/ai/meal-plan", headers=self.headers, json=partial)
                self.assertEqual(res.status_code, 422)

    def test_weekly_report_rejects_empty_payload(self):
        res = self.client.post("/api/ai/weekly-report", headers=self.headers, json={})
        self.assertEqual(res.status_code, 422)

    def test_weekly_report_rejects_missing_required_metrics(self):
        required_fields = [
            "total_calories_logged",
            "calorie_goal",
            "workout_sessions_count",
            "total_volume_kg",
            "prs_count",
            "adherence_score",
        ]
        base_payload = {
            "total_calories_logged": 14000,
            "calorie_goal": 14000,
            "workout_sessions_count": 4,
            "total_volume_kg": 12000.0,
            "prs_count": 2,
            "adherence_score": 85.0,
        }
        for field in required_fields:
            with self.subTest(missing_field=field):
                partial = {k: v for k, v in base_payload.items() if k != field}
                res = self.client.post("/api/ai/weekly-report", headers=self.headers, json=partial)
                self.assertEqual(res.status_code, 422)

    # =========================================================================
    # A1.5: In-Memory Query Cache (TTLCache deduplication)
    # =========================================================================
    def test_identical_text_query_served_from_cache(self):
        main.GEMINI_API_KEY = "dummy-key-for-cache-test"

        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {
            "candidates": [{
                "content": {"parts": [{"text": '{"name": "Moong Dal", "calories": 150, "protein": 9.0, "carbs": 24.0, "fat": 1.5, "serving_size": 1.0, "serving_unit": "katori"}'}]}
            }]
        }
        mock_post = AsyncMock(return_value=mock_resp)

        with patch.object(httpx.AsyncClient, "post", mock_post):
            # Call 1: Cache miss -> hits upstream HTTP
            res1 = self.client.post(
                "/api/ai/meal-estimate-text",
                headers=self.headers,
                json={"text": "1 katori moong dal"},
            )
            self.assertEqual(res1.status_code, 200)
            self.assertEqual(mock_post.call_count, 1)

            # Call 2: Cache hit -> upstream not called again
            res2 = self.client.post(
                "/api/ai/meal-estimate-text",
                headers=self.headers,
                json={"text": "1 katori moong dal"},
            )
            self.assertEqual(res2.status_code, 200)
            self.assertEqual(mock_post.call_count, 1)
            self.assertEqual(res1.json(), res2.json())

    def test_vision_query_differentiates_distinct_images(self):
        main.GEMINI_API_KEY = "dummy-key-for-vision-test"

        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {
            "candidates": [{
                "content": {"parts": [{"text": '{"product_name": "Paneer", "brand_name": "Amul", "serving_size_amount": 100.0, "serving_size_unit": "g", "basis": "per_100g", "nutrients": {}}'}]}
            }]
        }
        mock_post = AsyncMock(return_value=mock_resp)

        with patch.object(httpx.AsyncClient, "post", mock_post):
            # Image 1
            res1 = self.client.post(
                "/api/ai/nutrition-label-ocr",
                headers=self.headers,
                files={"image": ("label1.jpg", b"image-payload-alpha", "image/jpeg")},
            )
            self.assertEqual(res1.status_code, 200)
            self.assertEqual(mock_post.call_count, 1)

            # Image 2 (different bytes -> separate cache key)
            res2 = self.client.post(
                "/api/ai/nutrition-label-ocr",
                headers=self.headers,
                files={"image": ("label2.jpg", b"image-payload-beta", "image/jpeg")},
            )
            self.assertEqual(res2.status_code, 200)
            self.assertEqual(mock_post.call_count, 2)

            # Image 1 repeat (identical bytes -> cache hit)
            res3 = self.client.post(
                "/api/ai/nutrition-label-ocr",
                headers=self.headers,
                files={"image": ("label1.jpg", b"image-payload-alpha", "image/jpeg")},
            )
            self.assertEqual(res3.status_code, 200)
            self.assertEqual(mock_post.call_count, 2)

    # =========================================================================
    # A1.5: Daily Gemini Spend / Quota Ceiling
    # =========================================================================
    def test_quota_exhaustion_returns_fallback(self):
        main.GEMINI_API_KEY = "dummy-key-for-quota-test"
        # Set budget to 0 so quota is immediately exhausted
        set_daily_budget(0)

        res = self.client.post(
            "/api/ai/meal-estimate-text",
            headers=self.headers,
            json={"text": "2 rotis and curd"},
        )
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data.get("is_fallback"), "Expected is_fallback: true on exhausted budget")
        self.assertIn("quota", data.get("fallback_reason", "").lower())

    def test_budget_counter_increments_on_calls(self):
        main.GEMINI_API_KEY = "dummy-key-for-counter-test"
        reset_daily_stats(budget=5)
        self.assertEqual(get_daily_request_count(), 0)

        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {
            "candidates": [{
                "content": {"parts": [{"text": '{"name": "Poha", "calories": 250, "protein": 4.0, "carbs": 40.0, "fat": 6.0, "serving_size": 1.0, "serving_unit": "plate"}'}]}
            }]
        }
        mock_post = AsyncMock(return_value=mock_resp)

        with patch.object(httpx.AsyncClient, "post", mock_post):
            # Query 1
            self.client.post(
                "/api/ai/meal-estimate-text",
                headers=self.headers,
                json={"text": "bowl of poha"},
            )
            self.assertEqual(get_daily_request_count(), 1)

            # Query 2 (different text -> cache miss -> increments)
            self.client.post(
                "/api/ai/meal-estimate-text",
                headers=self.headers,
                json={"text": "bowl of upma"},
            )
            self.assertEqual(get_daily_request_count(), 2)

            # Repeat Query 1 (cache hit -> does not increment budget)
            self.client.post(
                "/api/ai/meal-estimate-text",
                headers=self.headers,
                json={"text": "bowl of poha"},
            )
            self.assertEqual(get_daily_request_count(), 2)


if __name__ == "__main__":
    unittest.main()
