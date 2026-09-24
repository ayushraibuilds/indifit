import io
import json
import os
import unittest
from unittest.mock import AsyncMock, patch

os.environ.setdefault("INDIFIT_API_KEY", "backend-test-secret")

from fastapi.testclient import TestClient
from backend import main


class TestAiPhotoV2(unittest.TestCase):
    api_key = "backend-test-secret"

    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(main.app)

    def setUp(self):
        main.INDIFIT_API_KEY = self.api_key
        main.GEMINI_API_KEY = ""
        main.IP_REQUEST_LOGS.clear()
        main.DEVICE_PHOTO_LOGS.clear()
        main.PHOTO_V2_WINDOW = 86400
        main.PHOTO_V2_MAX_REQUESTS = 10

    def tearDown(self):
        main.IP_REQUEST_LOGS.clear()
        main.DEVICE_PHOTO_LOGS.clear()

    @property
    def valid_headers(self):
        return {
            "x-indifit-key": self.api_key,
            "x-device-uuid": "device-uuid-abc-123",
        }

    def _dummy_image(self, size_bytes=1024):
        return ("test_meal.jpg", io.BytesIO(b"\xFF\xD8\xFF\xE0" + b"\x00" * (size_bytes - 4)), "image/jpeg")

    def test_auth_required(self):
        response = self.client.post(
            "/api/ai/meal-estimate-photo-v2",
            files={"image": self._dummy_image()},
        )
        self.assertEqual(response.status_code, 401)

    def test_invalid_mime_type(self):
        bad_file = ("document.pdf", io.BytesIO(b"%PDF-1.4\n..."), "application/pdf")
        response = self.client.post(
            "/api/ai/meal-estimate-photo-v2",
            headers=self.valid_headers,
            files={"image": bad_file},
        )
        self.assertEqual(response.status_code, 415)
        self.assertIn("Invalid image MIME type", response.json()["detail"])

    def test_file_size_limit_1mb(self):
        # 1MB + 10 bytes -> rejected with 413
        oversized = self._dummy_image(size_bytes=1024 * 1024 + 10)
        response = self.client.post(
            "/api/ai/meal-estimate-photo-v2",
            headers=self.valid_headers,
            files={"image": oversized},
        )
        self.assertEqual(response.status_code, 413)
        self.assertIn("exceeds maximum upload limit of 1 MB", response.json()["detail"])

    def test_mock_fallback_structure(self):
        response = self.client.post(
            "/api/ai/meal-estimate-photo-v2",
            headers=self.valid_headers,
            files={"image": self._dummy_image()},
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertTrue(data.get("is_fallback"))
        self.assertIn("items", data)
        self.assertGreaterEqual(len(data["items"]), 2)
        
        # Verify Indian decomposition items
        item_names = [item["food_name"] for item in data["items"]]
        self.assertIn("Roti / Chapati", item_names)
        self.assertIn("Yellow Dal Tadka", item_names)
        
        for item in data["items"]:
            self.assertIn("quantity_amount", item)
            self.assertIn("quantity_unit", item)
            self.assertIn("estimated_calories", item)
            self.assertIn("estimated_protein", item)
            self.assertIn("estimated_carbs", item)
            self.assertIn("estimated_fat", item)
            self.assertIn("confidence", item)

        self.assertIn("total_calories", data)
        self.assertGreater(data["total_calories"], 0)
        self.assertIn("disclaimer", data)
        self.assertIn("±30%", data["disclaimer"])

    def test_gemini_vision_success(self):
        main.GEMINI_API_KEY = "mock-gemini-key"
        gemini_result = {
            "query": "Photo Decomposition V2",
            "items": [
                {
                    "raw_segment": "3 rotis",
                    "food_name": "Roti / Chapati",
                    "quantity_amount": 3.0,
                    "quantity_unit": "piece",
                    "estimated_calories": 240,
                    "estimated_protein": 7.8,
                    "estimated_carbs": 48.0,
                    "estimated_fat": 1.5,
                    "confidence": "high",
                    "category_id": "staple_bread",
                    "fiber_g": 6.0,
                    "sodium_mg": 15.0,
                }
            ],
            "total_calories": 240,
            "confidence": "high",
            "disclaimer": "AI estimate carries ±30% variance. Review quantities before saving.",
        }

        with patch.object(
            main,
            "query_gemini_vision",
            new=AsyncMock(return_value=json.dumps(gemini_result)),
        ):
            response = self.client.post(
                "/api/ai/meal-estimate-photo-v2",
                headers=self.valid_headers,
                files={"image": self._dummy_image()},
            )
            self.assertEqual(response.status_code, 200)
            data = response.json()
            self.assertFalse(data.get("is_fallback"))
            self.assertEqual(data["total_calories"], 240)
            self.assertEqual(len(data["items"]), 1)
            self.assertEqual(data["items"][0]["food_name"], "Roti / Chapati")

    def test_device_uuid_rate_limiting_10_per_day(self):
        headers = {
            "x-indifit-key": self.api_key,
            "x-device-uuid": "device-quota-test",
        }

        # First 10 requests should succeed
        for i in range(10):
            res = self.client.post(
                "/api/ai/meal-estimate-photo-v2",
                headers=headers,
                files={"image": self._dummy_image()},
            )
            self.assertEqual(res.status_code, 200, f"Request {i+1} should succeed")

        # 11th request must fail with 429
        rejected = self.client.post(
            "/api/ai/meal-estimate-photo-v2",
            headers=headers,
            files={"image": self._dummy_image()},
        )
        self.assertEqual(rejected.status_code, 429)
        self.assertIn("Maximum 10 photo meal scans per 24 hours allowed per device", rejected.json()["detail"])

    def test_device_rate_limit_isolation(self):
        # Exhaust quota for device A
        headers_a = {
            "x-indifit-key": self.api_key,
            "x-device-uuid": "device-isolated-a",
        }
        for _ in range(10):
            res = self.client.post(
                "/api/ai/meal-estimate-photo-v2",
                headers=headers_a,
                files={"image": self._dummy_image()},
            )
            self.assertEqual(res.status_code, 200)

        # Device A is now blocked
        res_a_blocked = self.client.post(
            "/api/ai/meal-estimate-photo-v2",
            headers=headers_a,
            files={"image": self._dummy_image()},
        )
        self.assertEqual(res_a_blocked.status_code, 429)

        # Device B should NOT be blocked (CGNAT protection)
        headers_b = {
            "x-indifit-key": self.api_key,
            "x-device-uuid": "device-isolated-b",
        }
        res_b = self.client.post(
            "/api/ai/meal-estimate-photo-v2",
            headers=headers_b,
            files={"image": self._dummy_image()},
        )
        self.assertEqual(res_b.status_code, 200)

    def test_rate_limit_fallback_to_ip(self):
        headers_no_uuid = {
            "x-indifit-key": self.api_key,
        }
        for i in range(10):
            res = self.client.post(
                "/api/ai/meal-estimate-photo-v2",
                headers=headers_no_uuid,
                files={"image": self._dummy_image()},
            )
            self.assertEqual(res.status_code, 200)

        res_blocked = self.client.post(
            "/api/ai/meal-estimate-photo-v2",
            headers=headers_no_uuid,
            files={"image": self._dummy_image()},
        )
        self.assertEqual(res_blocked.status_code, 429)
