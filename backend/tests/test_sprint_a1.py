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
    # A1.5: In-Memory Query Cache (TTLCache deduplication)
    # =========================================================================
    def test_identical_text_query_served_from_cache(self):
        main.GEMINI_API_KEY = "dummy-key-for-cache-test"

        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {
            "candidates": [{
                "content": {"parts": [{"text": '{"query": "1 katori moong dal", "items": [], "total_calories": 150}'}]}
            }]
        }
        mock_post = AsyncMock(return_value=mock_resp)

        with patch.object(httpx.AsyncClient, "post", mock_post):
            # Call 1: Cache miss -> hits upstream HTTP
            res1 = self.client.post(
                "/api/ai/meal-decompose",
                headers=self.headers,
                json={"text": "1 katori moong dal"},
            )
            self.assertEqual(res1.status_code, 200)
            self.assertEqual(mock_post.call_count, 1)

            # Call 2: Cache hit -> upstream not called again
            res2 = self.client.post(
                "/api/ai/meal-decompose",
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
    def test_quota_exhaustion_returns_429_without_invented_food(self):
        main.GEMINI_API_KEY = "dummy-key-for-quota-test"
        # Set budget to 0 so quota is immediately exhausted
        set_daily_budget(0)

        res = self.client.post(
            "/api/ai/meal-decompose",
            headers=self.headers,
            json={"text": "2 rotis and curd"},
        )
        self.assertEqual(res.status_code, 429)
        self.assertNotIn("items", res.json())

    def test_budget_counter_increments_on_calls(self):
        main.GEMINI_API_KEY = "dummy-key-for-counter-test"
        reset_daily_stats(budget=5)
        self.assertEqual(get_daily_request_count(), 0)

        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {
            "candidates": [{
                "content": {"parts": [{"text": '{"query": "poha", "items": [], "total_calories": 250}'}]}
            }]
        }
        mock_post = AsyncMock(return_value=mock_resp)

        with patch.object(httpx.AsyncClient, "post", mock_post):
            # Query 1
            self.client.post(
                "/api/ai/meal-decompose",
                headers=self.headers,
                json={"text": "bowl of poha"},
            )
            self.assertEqual(get_daily_request_count(), 1)

            # Query 2 (different text -> cache miss -> increments)
            self.client.post(
                "/api/ai/meal-decompose",
                headers=self.headers,
                json={"text": "bowl of upma"},
            )
            self.assertEqual(get_daily_request_count(), 2)

            # Repeat Query 1 (cache hit -> does not increment budget)
            self.client.post(
                "/api/ai/meal-decompose",
                headers=self.headers,
                json={"text": "bowl of poha"},
            )
            self.assertEqual(get_daily_request_count(), 2)


if __name__ == "__main__":
    unittest.main()
