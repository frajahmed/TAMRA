from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import status
from rest_framework.reverse import reverse
from rest_framework.test import APITestCase

from profiles.models import Profile

User = get_user_model()


class ProfileApiTests(APITestCase):
    url = reverse("me-profile")

    def setUp(self):
        self.user = User.objects.create_user(email="a@example.com", password="x")
        self.client.force_authenticate(self.user)

    def body_data(self) -> dict:
        return {
            "sex": "female",
            "birth_year": timezone.now().year - 30,
            "height_cm": "170.0",
            "weight_kg": "70.0",
            "activity_level": "sedentary",
            "goal": "maintain",
        }

    def test_requires_login(self):
        self.client.force_authenticate(None)
        self.assertEqual(self.client.get(self.url).status_code, status.HTTP_401_UNAUTHORIZED)

    def test_first_get_creates_defaults(self):
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["goal"], "maintain")
        self.assertEqual(response.data["weight_unit"], "kg")
        self.assertFalse(response.data["is_complete"])
        self.assertIsNone(response.data["kcal_target"])
        self.assertTrue(Profile.objects.filter(user=self.user).exists())

    def test_patch_complete_data_calculates_targets(self):
        response = self.client.patch(self.url, self.body_data(), format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data["is_complete"])
        self.assertEqual(response.data["kcal_target"], 1742)
        self.assertEqual(response.data["protein_g"], 131)
        self.assertEqual(response.data["carbs_g"], 174)
        self.assertEqual(response.data["fat_g"], 58)

    def test_goal_change_recalculates(self):
        self.client.patch(self.url, self.body_data(), format="json")
        response = self.client.patch(self.url, {"goal": "lose"}, format="json")
        self.assertEqual(response.data["kcal_target"], 1452)

    def test_partial_data_keeps_target_empty(self):
        response = self.client.patch(self.url, {"sex": "male"}, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIsNone(response.data["kcal_target"])

    def test_invalid_values(self):
        for field, value in [
            ("height_cm", 50),
            ("weight_kg", 500),
            ("birth_year", timezone.now().year - 5),
            ("goal", "fly"),
        ]:
            response = self.client.patch(self.url, {field: value}, format="json")
            self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST, field)
            self.assertIn(field, response.data["fields"])

    def test_targets_cannot_be_set_by_client(self):
        self.client.patch(self.url, self.body_data(), format="json")
        response = self.client.patch(self.url, {"kcal_target": 9999}, format="json")
        self.assertEqual(response.data["kcal_target"], 1742)

    def test_put_not_allowed(self):
        response = self.client.put(self.url, self.body_data(), format="json")
        self.assertEqual(response.status_code, status.HTTP_405_METHOD_NOT_ALLOWED)

    def test_each_user_has_own_profile(self):
        self.client.patch(self.url, {"language": "ar"}, format="json")
        other = User.objects.create_user(email="b@example.com", password="x")
        self.client.force_authenticate(other)
        response = self.client.get(self.url)
        self.assertEqual(response.data["language"], "en")
        self.assertEqual(Profile.objects.count(), 2)
