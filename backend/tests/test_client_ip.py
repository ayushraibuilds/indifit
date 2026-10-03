import os
import unittest
from unittest.mock import patch

os.environ.setdefault("INDIFIT_API_KEY", "backend-test-secret")

from fastapi.testclient import TestClient
from starlette.requests import Request

from backend import main
from backend.core.security import client_ip


def _request(peer: str, forwarded: str | None) -> Request:
    headers = [] if forwarded is None else [(b"x-forwarded-for", forwarded.encode())]
    return Request({"type": "http", "client": (peer, 1234), "headers": headers})


class ClientIpTests(unittest.TestCase):
    def setUp(self):
        self._limits = (main.MAX_REQUESTS_PER_WINDOW, main.RATE_LIMIT_WINDOW)

    def tearDown(self):
        main.MAX_REQUESTS_PER_WINDOW, main.RATE_LIMIT_WINDOW = self._limits
        if hasattr(main, "TRUSTED_PROXY_HOPS"):
            del main.TRUSTED_PROXY_HOPS
        main.IP_REQUEST_LOGS.clear()

    def test_without_trusted_proxies_the_header_is_ignored(self):
        main.TRUSTED_PROXY_HOPS = 0
        self.assertEqual(client_ip(_request("10.0.0.5", "6.6.6.6")), "10.0.0.5")

    def test_behind_one_proxy_the_right_most_entry_is_the_client(self):
        main.TRUSTED_PROXY_HOPS = 1
        # The caller sent "6.6.6.6"; Render appended the real 203.0.113.9.
        request = _request("10.0.0.5", "6.6.6.6, 203.0.113.9")
        self.assertEqual(client_ip(request), "203.0.113.9")

    def test_extra_hops_count_from_the_right(self):
        main.TRUSTED_PROXY_HOPS = 2
        request = _request("10.0.0.5", "6.6.6.6, 203.0.113.9, 198.51.100.1")
        self.assertEqual(client_ip(request), "203.0.113.9")

    def test_a_missing_header_falls_back_to_the_peer(self):
        main.TRUSTED_PROXY_HOPS = 1
        self.assertEqual(client_ip(_request("10.0.0.5", None)), "10.0.0.5")

    def test_trusted_hops_come_from_the_environment(self):
        with patch.dict(os.environ, {"TRUSTED_PROXY_HOPS": "1"}):
            self.assertEqual(
                client_ip(_request("10.0.0.5", "6.6.6.6, 203.0.113.9")),
                "203.0.113.9",
            )

    def test_spoofed_headers_cannot_dodge_the_rate_limit(self):
        main.TRUSTED_PROXY_HOPS = 1
        main.INDIFIT_API_KEY = "backend-test-secret"
        main.GEMINI_API_KEY = ""
        main.MAX_REQUESTS_PER_WINDOW = 2
        main.RATE_LIMIT_WINDOW = 3600
        client = TestClient(main.app)
        statuses = [
            client.post(
                "/api/ai/meal-decompose",
                headers={
                    "x-indifit-key": "backend-test-secret",
                    # A different fake IP each time, same real client.
                    "x-forwarded-for": f"6.6.6.{n}, 203.0.113.9",
                },
                json={"text": "one roti"},
            ).status_code
            for n in range(3)
        ]
        self.assertEqual(statuses[-1], 429)


if __name__ == "__main__":
    unittest.main()
