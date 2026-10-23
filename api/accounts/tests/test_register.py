from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.reverse import reverse
from rest_framework.test import APITestCase

User = get_user_model()
PASSWORD = "Sicheres-Passwort-123"


class RegisterTests(APITestCase):
    url = reverse("auth-register")

    def register(self, email: str = "neu@example.com", password: str = PASSWORD):
        return self.client.post(self.url, {"email": email, "password": password}, format="json")

    def test_register_returns_user_and_tokens(self):
        response = self.register()
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(set(response.data), {"id", "email", "access", "refresh"})
        user = User.objects.get(email="neu@example.com")
        self.assertEqual(response.data["id"], str(user.id))
        self.assertNotEqual(user.password, PASSWORD)
        self.assertTrue(user.check_password(PASSWORD))

    def test_email_is_lowercased(self):
        response = self.register(email="Test@Example.COM")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["email"], "test@example.com")

    def test_duplicate_email_case_insensitive(self):
        self.register(email="dup@example.com")
        response = self.register(email="DUP@example.com")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.data["code"], "validation_error")
        self.assertIn("email", response.data["fields"])

    def test_weak_password(self):
        response = self.register(password="123")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("password", response.data["fields"])

    def test_missing_email(self):
        response = self.client.post(self.url, {"password": PASSWORD}, format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("email", response.data["fields"])

    def test_invalid_email(self):
        response = self.register(email="not-an-email")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_returned_tokens_work(self):
        response = self.register()
        refreshed = self.client.post(
            reverse("auth-refresh"), {"refresh": response.data["refresh"]}, format="json"
        )
        self.assertEqual(refreshed.status_code, status.HTTP_200_OK)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {response.data['access']}")
        login = self.client.post(
            reverse("auth-login"),
            {"email": "neu@example.com", "password": PASSWORD},
            format="json",
        )
        self.assertEqual(login.status_code, status.HTTP_200_OK)
