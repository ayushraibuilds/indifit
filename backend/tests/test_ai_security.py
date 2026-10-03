import os
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch

os.environ.setdefault("INDIFIT_API_KEY", "backend-test-secret")

from fastapi import HTTPException
from fastapi.routing import APIRoute
from fastapi.testclient import TestClient

from backend import main


class AiRouteSecurityTests(unittest.TestCase):
    api_key = "backend-test-secret"

    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(main.app)

    def setUp(self):
        main.INDIFIT_API_KEY = self.api_key
        main.GEMINI_API_KEY = ""
        main.IP_REQUEST_LOGS.clear()
        main.MAX_REQUESTS_PER_WINDOW = 30
        main.RATE_LIMIT_WINDOW = 3600

    def tearDown(self):
        main.IP_REQUEST_LOGS.clear()

    @property
    def valid_headers(self):
        return {"x-indifit-key": self.api_key}

    @staticmethod
    def _ai_requests():
        return {
            "/api/ai/nutrition-label-ocr": {
                "files": {
                    "image": ("label.jpg", b"test-label-image", "image/jpeg"),
                },
            },
            "/api/ai/meal-decompose": {
                "json": {"text": "2 rotis and 1 katori dal tadka"},
            },
            "/api/ai/meal-estimate-photo-v2": {
                "files": {
                    "image": ("meal.jpg", b"test-image", "image/jpeg"),
                },
            },
        }

    def test_ai_routes_are_not_mounted_by_default(self):
        with patch.dict(os.environ, {"ENABLE_AI_ROUTES": ""}):
            application = main.create_app()
        self.assertFalse(
            any(
                isinstance(route, APIRoute) and route.path.startswith("/api/ai/")
                for route in application.routes
            )
        )

    def test_health_and_root_are_public(self):
        health_response = self.client.get("/health")
        root_response = self.client.get("/")

        self.assertEqual(health_response.status_code, 200)
        self.assertEqual(health_response.json()["status"], "ok")
        self.assertEqual(root_response.status_code, 200)

    def test_every_ai_route_has_shared_security_dependencies(self):
        ai_routes = [
            route
            for route in main.app.routes
            if isinstance(route, APIRoute) and route.path.startswith("/api/ai/")
        ]

        self.assertEqual(
            {route.path for route in ai_routes},
            set(self._ai_requests()),
        )
        for route in ai_routes:
            dependency_calls = {
                dependency.call
                for dependency in route.dependant.dependencies
            }
            self.assertIn(main.verify_api_key, dependency_calls, route.path)
            self.assertIn(main.enforce_rate_limit, dependency_calls, route.path)

    def test_every_ai_route_rejects_missing_credentials(self):
        for path, request_kwargs in self._ai_requests().items():
            with self.subTest(path=path):
                response = self.client.post(path, **request_kwargs)
                self.assertEqual(response.status_code, 401)

    def test_every_ai_route_rejects_invalid_credentials(self):
        for path, request_kwargs in self._ai_requests().items():
            with self.subTest(path=path):
                response = self.client.post(
                    path,
                    headers={"x-indifit-key": "incorrect"},
                    **request_kwargs,
                )
                self.assertEqual(response.status_code, 401)

    def test_valid_credentials_allow_handler_to_proceed(self):
        # With no Gemini key configured, reaching the handler means a 503
        # (never an invented result).
        for path, request_kwargs in self._ai_requests().items():
            with self.subTest(path=path):
                response = self.client.post(
                    path,
                    headers=self.valid_headers,
                    **request_kwargs,
                )
                self.assertEqual(response.status_code, 503)

    def test_auth_rejection_does_not_call_gemini(self):
        main.GEMINI_API_KEY = "configured-for-test"
        with patch.object(
            main,
            "query_gemini_text",
            new=AsyncMock(),
        ) as gemini:
            response = self.client.post(
                "/api/ai/meal-decompose",
                json={"text": "one roti"},
            )

        self.assertEqual(response.status_code, 401)
        self.assertEqual(main.IP_REQUEST_LOGS, {})
        gemini.assert_not_awaited()

    def test_request_beyond_limit_returns_429(self):
        main.MAX_REQUESTS_PER_WINDOW = 2

        responses = [
            self.client.post(
                "/api/ai/meal-decompose",
                headers=self.valid_headers,
                json={"text": "one roti"},
            )
            for _ in range(3)
        ]

        self.assertEqual(
            [response.status_code for response in responses],
            [503, 503, 429],
        )

    def test_rate_limit_rejection_does_not_call_gemini(self):
        main.GEMINI_API_KEY = "configured-for-test"
        main.MAX_REQUESTS_PER_WINDOW = 1
        result = '{"query": "one roti", "items": [], "total_calories": 80}'

        with patch.object(
            main,
            "query_gemini_text",
            new=AsyncMock(return_value=result),
        ) as gemini:
            allowed = self.client.post(
                "/api/ai/meal-decompose",
                headers=self.valid_headers,
                json={"text": "one roti"},
            )
            rejected = self.client.post(
                "/api/ai/meal-decompose",
                headers=self.valid_headers,
                json={"text": "one roti"},
            )

        self.assertEqual(allowed.status_code, 200)
        self.assertEqual(rejected.status_code, 429)
        self.assertEqual(gemini.await_count, 1)

    def test_upload_validation_preserves_http_statuses(self):
        invalid_type = self.client.post(
            "/api/ai/nutrition-label-ocr",
            headers=self.valid_headers,
            files={
                "image": ("meal.txt", b"not-an-image", "text/plain"),
            },
        )
        oversized = self.client.post(
            "/api/ai/nutrition-label-ocr",
            headers=self.valid_headers,
            files={
                "image": (
                    "meal.jpg",
                    b"x" * (5 * 1024 * 1024 + 1),
                    "image/jpeg",
                ),
            },
        )

        self.assertEqual(invalid_type.status_code, 415)
        self.assertEqual(oversized.status_code, 413)

    def test_handler_http_exception_passes_through(self):
        main.GEMINI_API_KEY = "configured-for-test"
        with patch.object(
            main,
            "query_gemini_text",
            new=AsyncMock(
                side_effect=HTTPException(
                    status_code=503,
                    detail="Upstream unavailable",
                ),
            ),
        ):
            response = self.client.post(
                "/api/ai/meal-decompose",
                headers=self.valid_headers,
                json={"text": "one roti"},
            )

        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json()["detail"], "Upstream unavailable")

    def test_missing_server_credential_fails_at_startup(self):
        repository_root = Path(__file__).resolve().parents[2]
        environment = os.environ.copy()
        environment.pop("INDIFIT_API_KEY", None)
        import_without_dotenv = (
            "from unittest.mock import patch\n"
            "with patch('dotenv.load_dotenv', return_value=False):\n"
            "    import backend.main\n"
        )

        result = subprocess.run(
            [sys.executable, "-c", import_without_dotenv],
            cwd=repository_root,
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "INDIFIT_API_KEY environment variable must be set",
            result.stderr,
        )


    def test_nutrition_label_ocr_features(self):
        invalid_type = self.client.post(
            "/api/ai/nutrition-label-ocr",
            headers=self.valid_headers,
            files={"image": ("label.pdf", b"pdf-content", "application/pdf")},
        )
        self.assertEqual(invalid_type.status_code, 415)

        oversized = self.client.post(
            "/api/ai/nutrition-label-ocr",
            headers=self.valid_headers,
            files={"image": ("label.jpg", b"x" * (5 * 1024 * 1024 + 1), "image/jpeg")},
        )
        self.assertEqual(oversized.status_code, 413)

        unconfigured = self.client.post(
            "/api/ai/nutrition-label-ocr",
            headers=self.valid_headers,
            files={"image": ("label.png", b"png-bytes", "image/png")},
        )
        self.assertEqual(unconfigured.status_code, 503)
        self.assertNotIn("nutrients", unconfigured.json())

        main.GEMINI_API_KEY = "configured-for-test"
        reading = (
            '{"basis": "per_100g", "nutrients": {"calories": '
            '{"value": 454, "unit": "kcal", "confidence": "high"}}}'
        )
        with patch.object(
            main, "query_gemini_vision", new=AsyncMock(return_value=reading)
        ):
            success = self.client.post(
                "/api/ai/nutrition-label-ocr",
                headers=self.valid_headers,
                files={"image": ("label.png", b"png-bytes-2", "image/png")},
            )
        self.assertEqual(success.status_code, 200)
        self.assertEqual(success.json()["nutrients"]["calories"]["value"], 454)

    def test_meal_decompose_features(self):
        empty = self.client.post(
            "/api/ai/meal-decompose",
            headers=self.valid_headers,
            json={"text": "   "},
        )
        self.assertEqual(empty.status_code, 422)

        oversized = self.client.post(
            "/api/ai/meal-decompose",
            headers=self.valid_headers,
            json={"text": "a" * 501},
        )
        self.assertEqual(oversized.status_code, 422)

        unconfigured = self.client.post(
            "/api/ai/meal-decompose",
            headers=self.valid_headers,
            json={"text": "2 rotis and 1 katori dal tadka"},
        )
        self.assertEqual(unconfigured.status_code, 503)
        self.assertNotIn("items", unconfigured.json())

        main.GEMINI_API_KEY = "configured-for-test"
        parsed = (
            '{"query": "2 rotis", "total_calories": 170, "items": [{'
            '"raw_segment": "2 rotis", "food_name": "Roti", '
            '"quantity_amount": 2, "quantity_unit": "roti", '
            '"estimated_calories": 170, "estimated_protein": 6, '
            '"estimated_carbs": 36, "estimated_fat": 1, "confidence": "high"}]}'
        )
        with patch.object(
            main, "query_gemini_text", new=AsyncMock(return_value=parsed)
        ):
            success = self.client.post(
                "/api/ai/meal-decompose",
                headers=self.valid_headers,
                json={"text": "2 rotis"},
            )
        self.assertEqual(success.status_code, 200)
        data = success.json()
        first_item = data["items"][0]
        self.assertIn("food_name", first_item)
        self.assertIn("quantity_amount", first_item)
        self.assertIn("quantity_unit", first_item)
        self.assertIn("estimated_calories", first_item)
        self.assertIn("confidence", first_item)

    def test_gemini_client_header_auth(self):
        import asyncio
        import httpx
        from backend.services.gemini_client import query_gemini_text

        main.GEMINI_API_KEY = "test-secret-key-12345"

        mock_resp = unittest.mock.MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {
            "candidates": [{"content": {"parts": [{"text": "Hello world"}]}}]
        }
        captured_requests = []

        async def fake_post(url, headers=None, json=None):
            captured_requests.append({"url": url, "headers": headers, "json": json})
            return mock_resp

        with unittest.mock.patch.object(httpx.AsyncClient, "post", side_effect=fake_post):
            result = asyncio.run(query_gemini_text("unique-test-prompt-header-auth"))
            self.assertEqual(result, "Hello world")
            self.assertEqual(len(captured_requests), 1)
            req = captured_requests[0]
            # Key MUST NOT be in URL query parameters
            self.assertNotIn("key=", req["url"])
            self.assertNotIn("test-secret-key-12345", req["url"])
            # Key MUST be in headers
            self.assertIn("x-goog-api-key", req["headers"])
            self.assertEqual(req["headers"]["x-goog-api-key"], "test-secret-key-12345")

    def test_upstream_errors_are_not_leaked(self):
        main.GEMINI_API_KEY = "dummy-key-for-sanitization"

        async def throwing_query(*args, **kwargs):
            raise RuntimeError("Database connection string leaked: postgres://user:secret@db.internal/prod")

        with unittest.mock.patch("backend.routers.ai._get_query_gemini_text", return_value=throwing_query):
            res = self.client.post(
                "/api/ai/meal-decompose",
                headers=self.valid_headers,
                json={"text": "2 rotis"},
            )
            self.assertEqual(res.status_code, 503)
            # The response MUST NOT leak the internal exception string
            self.assertNotIn("postgres", res.text)
            self.assertNotIn("secret", res.text)


if __name__ == "__main__":
    unittest.main()
