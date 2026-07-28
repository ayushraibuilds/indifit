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
            "/api/ai/routine": {
                "json": {
                    "goal": "strength",
                    "equipment": "gym",
                    "days_per_week": 3,
                    "experience": "beginner",
                    "injuries": "",
                },
            },
            "/api/ai/meal-estimate-text": {
                "json": {"text": "one roti"},
            },
            "/api/ai/meal-estimate-photo": {
                "files": {
                    "image": ("meal.jpg", b"test-image", "image/jpeg"),
                },
            },
            "/api/ai/meal-plan": {
                "json": {
                    "calorie_goal": 2000,
                    "diet_preference": "veg",
                    "days": 7,
                },
            },
            "/api/ai/weekly-report": {
                "json": {
                    "total_calories_logged": 14000,
                    "calorie_goal": 14000,
                    "workout_sessions_count": 4,
                    "total_volume_kg": 12000,
                    "prs_count": 2,
                    "adherence_score": 85,
                },
            },
        }

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
        for path, request_kwargs in self._ai_requests().items():
            with self.subTest(path=path):
                response = self.client.post(
                    path,
                    headers=self.valid_headers,
                    **request_kwargs,
                )
                self.assertEqual(response.status_code, 200)

    def test_auth_rejection_does_not_call_gemini(self):
        main.GEMINI_API_KEY = "configured-for-test"
        with patch.object(
            main,
            "query_gemini_text",
            new=AsyncMock(),
        ) as gemini:
            response = self.client.post(
                "/api/ai/meal-estimate-text",
                json={"text": "one roti"},
            )

        self.assertEqual(response.status_code, 401)
        self.assertEqual(main.IP_REQUEST_LOGS, {})
        gemini.assert_not_awaited()

    def test_request_beyond_limit_returns_429(self):
        main.MAX_REQUESTS_PER_WINDOW = 2

        responses = [
            self.client.post(
                "/api/ai/meal-estimate-text",
                headers=self.valid_headers,
                json={"text": "one roti"},
            )
            for _ in range(3)
        ]

        self.assertEqual(
            [response.status_code for response in responses],
            [200, 200, 429],
        )

    def test_rate_limit_rejection_does_not_call_gemini(self):
        main.GEMINI_API_KEY = "configured-for-test"
        main.MAX_REQUESTS_PER_WINDOW = 1
        result = (
            '{"name":"Roti","calories":80,"protein":3,"carbs":15,'
            '"fat":1,"serving_size":1,"serving_unit":"piece"}'
        )

        with patch.object(
            main,
            "query_gemini_text",
            new=AsyncMock(return_value=result),
        ) as gemini:
            allowed = self.client.post(
                "/api/ai/meal-estimate-text",
                headers=self.valid_headers,
                json={"text": "one roti"},
            )
            rejected = self.client.post(
                "/api/ai/meal-estimate-text",
                headers=self.valid_headers,
                json={"text": "one roti"},
            )

        self.assertEqual(allowed.status_code, 200)
        self.assertEqual(rejected.status_code, 429)
        self.assertEqual(gemini.await_count, 1)

    def test_upload_validation_preserves_http_statuses(self):
        invalid_type = self.client.post(
            "/api/ai/meal-estimate-photo",
            headers=self.valid_headers,
            files={
                "image": ("meal.txt", b"not-an-image", "text/plain"),
            },
        )
        oversized = self.client.post(
            "/api/ai/meal-estimate-photo",
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

    def test_handler_http_exception_is_not_converted_to_fallback(self):
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
                "/api/ai/meal-estimate-text",
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


    def test_weekly_report_structured_parameters(self):
        response = self.client.post(
            "/api/ai/weekly-report",
            headers=self.valid_headers,
            json={
                "total_calories_logged": 14000,
                "calorie_goal": 14000,
                "workout_sessions_count": 4,
                "total_volume_kg": 12000.0,
                "prs_count": 2,
                "adherence_score": 85.0,
                "date_range": "2026-07-22 to 2026-07-28",
                "nutrition_days_logged": 5,
                "calorie_adherence_pct": 90.0,
                "protein_adherence_pct": 85.0,
                "hydration_days_at_goal": 6,
                "completed_workouts": 4,
                "planned_workouts": 4,
            },
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("headline", data)
        self.assertIn("summary", data)
        self.assertIn("coaching_tip", data)
        self.assertTrue(data.get("is_fallback"))
        self.assertIn("2026-07-22 to 2026-07-28", data["summary"])


if __name__ == "__main__":
    unittest.main()
