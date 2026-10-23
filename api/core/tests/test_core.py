from rest_framework import status
from rest_framework.exceptions import NotAuthenticated, ValidationError
from rest_framework.reverse import reverse
from rest_framework.test import APITestCase

from core.exceptions import api_exception_handler
from core.sentry import FILTERED, before_send


class HealthTests(APITestCase):
    def test_health_is_public_and_ok(self):
        response = self.client.get(reverse("health"))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.json(), {"status": "ok"})

    def test_unknown_url_returns_json_404(self):
        response = self.client.get("/api/v1/does-not-exist/")
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertEqual(response.json()["code"], "not_found")

    def test_schema_is_available(self):
        response = self.client.get(reverse("schema"))
        self.assertEqual(response.status_code, status.HTTP_200_OK)


class ErrorFormatTests(APITestCase):
    def test_validation_error_format(self):
        response = api_exception_handler(ValidationError({"email": ["Required."]}), {})
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data["code"], "validation_error")
        self.assertEqual(response.data["fields"], {"email": ["Required."]})

    def test_validation_error_list_goes_to_non_field_errors(self):
        response = api_exception_handler(ValidationError(["Bad."]), {})
        self.assertIn("non_field_errors", response.data["fields"])

    def test_auth_error_format(self):
        response = api_exception_handler(NotAuthenticated(), {})
        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.data["code"], "not_authenticated")
        self.assertEqual(response.data["fields"], {})

    def test_unknown_exception_is_left_to_django(self):
        self.assertIsNone(api_exception_handler(RuntimeError("boom"), {}))


class SentryFilterTests(APITestCase):
    def test_sensitive_fields_are_removed(self):
        event = {
            "request": {"data": {"weight_kg": 80}, "cookies": {"a": "b"}, "url": "/x"},
            "user": {"email": "a@b.de"},
            "extra": {"kcal": 500, "diary_entries": [1, 2], "screen": "home"},
            "breadcrumbs": [{"data": {"access_token": "abc", "count": 3}}],
        }
        cleaned = before_send(event, {})
        self.assertNotIn("data", cleaned["request"])
        self.assertNotIn("cookies", cleaned["request"])
        self.assertNotIn("user", cleaned)
        self.assertEqual(cleaned["extra"]["kcal"], FILTERED)
        self.assertEqual(cleaned["extra"]["diary_entries"], FILTERED)
        self.assertEqual(cleaned["extra"]["screen"], "home")
        self.assertEqual(cleaned["breadcrumbs"][0]["data"]["access_token"], FILTERED)
        self.assertEqual(cleaned["breadcrumbs"][0]["data"]["count"], 3)
