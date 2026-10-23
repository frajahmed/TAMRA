from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.reverse import reverse
from rest_framework.test import APITestCase

User = get_user_model()
PASSWORD = "Sicheres-Passwort-123"


class UserModelTests(APITestCase):
    def test_email_is_normalized_and_used_as_login(self):
        user = User.objects.create_user(email="Test@Example.COM", password=PASSWORD)
        self.assertEqual(user.email, "test@example.com")
        self.assertTrue(user.check_password(PASSWORD))
        self.assertEqual(User.USERNAME_FIELD, "email")

    def test_superuser(self):
        admin = User.objects.create_superuser(email="admin@example.com", password=PASSWORD)
        self.assertTrue(admin.is_staff)
        self.assertTrue(admin.is_superuser)

    def test_email_required(self):
        with self.assertRaises(ValueError):
            User.objects.create_user(email="", password=PASSWORD)


class JwtFlowTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="user@example.com", password=PASSWORD)

    def login(self, password: str = PASSWORD):
        return self.client.post(
            reverse("auth-login"),
            {"email": "user@example.com", "password": password},
            format="json",
        )

    def test_login_returns_tokens(self):
        response = self.login()
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("access", response.data)
        self.assertIn("refresh", response.data)

    def test_wrong_password_is_401_in_error_format(self):
        response = self.login("wrong")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertIn("code", response.data)

    def test_refresh_rotates_and_logout_blacklists(self):
        refresh = self.login().data["refresh"]
        rotated = self.client.post(reverse("auth-refresh"), {"refresh": refresh}, format="json")
        self.assertEqual(rotated.status_code, status.HTTP_200_OK)
        new_refresh = rotated.data["refresh"]

        reuse = self.client.post(reverse("auth-refresh"), {"refresh": refresh}, format="json")
        self.assertEqual(reuse.status_code, status.HTTP_401_UNAUTHORIZED)

        logout = self.client.post(reverse("auth-logout"), {"refresh": new_refresh}, format="json")
        self.assertEqual(logout.status_code, status.HTTP_200_OK)
        after = self.client.post(reverse("auth-refresh"), {"refresh": new_refresh}, format="json")
        self.assertEqual(after.status_code, status.HTTP_401_UNAUTHORIZED)


class AdminTests(APITestCase):
    def test_admin_user_pages_load(self):
        admin = User.objects.create_superuser(email="admin@example.com", password=PASSWORD)
        self.client.force_login(admin)
        self.assertEqual(self.client.get("/admin/accounts/user/add/").status_code, 200)
        self.assertEqual(
            self.client.get(f"/admin/accounts/user/{admin.pk}/change/").status_code, 200
        )
