from unittest import mock

from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import check_password, make_password
from django.core.cache import cache
from django.test import override_settings
from rest_framework import status
from rest_framework.reverse import reverse
from rest_framework.test import APITestCase
from rest_framework.throttling import ScopedRateThrottle

from config.settings import base

User = get_user_model()
PASSWORD = "Sicheres-Passwort-123"
PRODUCTION_HASHERS = base.PASSWORD_HASHERS


class PasswordHashingTests(APITestCase):
    def test_production_uses_argon2id_first(self):
        self.assertEqual(PRODUCTION_HASHERS[0], "django.contrib.auth.hashers.Argon2PasswordHasher")

    @override_settings(PASSWORD_HASHERS=PRODUCTION_HASHERS)
    def test_hash_is_one_way_salted_argon2id(self):
        first = make_password(PASSWORD)
        second = make_password(PASSWORD)
        self.assertTrue(first.startswith("argon2$argon2id$"))
        self.assertNotIn(PASSWORD, first)
        self.assertNotEqual(first, second)  # random salt per hash → same password, other hash
        self.assertTrue(check_password(PASSWORD, first))
        self.assertFalse(check_password("wrong-password", first))

    @override_settings(PASSWORD_HASHERS=PRODUCTION_HASHERS)
    def test_old_pbkdf2_hash_is_upgraded_at_login(self):
        user = User.objects.create_user(email="old@example.com")
        user.password = make_password(PASSWORD, hasher="pbkdf2_sha256")
        user.save()

        response = self.client.post(
            reverse("auth-login"), {"email": "old@example.com", "password": PASSWORD}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        user.refresh_from_db()
        self.assertTrue(user.password.startswith("argon2$"))

    def test_minimum_length_is_ten(self):
        response = self.client.post(
            reverse("auth-register"),
            {"email": "kurz@example.com", "password": "Ab3$xyz9"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("password", response.data["fields"])


class LoginThrottleTests(APITestCase):
    def setUp(self):
        cache.clear()
        User.objects.create_user(email="a@example.com", password=PASSWORD)

    def tearDown(self):
        cache.clear()

    def test_password_guessing_is_blocked(self):
        rates = {**settings.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"], "login": "3/min"}
        with mock.patch.object(ScopedRateThrottle, "THROTTLE_RATES", rates):
            codes = [
                self.client.post(
                    reverse("auth-login"),
                    {"email": "a@example.com", "password": f"guess-{index}"},
                    format="json",
                ).status_code
                for index in range(4)
            ]
        self.assertEqual(codes[:3], [401, 401, 401])
        self.assertEqual(codes[3], status.HTTP_429_TOO_MANY_REQUESTS)
