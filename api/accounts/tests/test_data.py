import json
from decimal import Decimal

from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.reverse import reverse
from rest_framework.test import APITestCase

from activity.models import Activity, StepDay
from diary.models import DiaryEntry
from foods.models import Food
from profiles.models import Consent, Profile
from tracking.models import WaterLog, WeightLog

User = get_user_model()
PASSWORD = "Sicheres-Passwort-123"


class PersonalDataTestCase(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="a@example.com", password=PASSWORD)
        self.other = User.objects.create_user(email="b@example.com", password=PASSWORD)
        self.shared = Food.objects.create(name="Apfel", source="off", kcal=Decimal("52"))
        self.mine = Food.objects.create(
            name="Omas Kuchen", source="user", created_by=self.user, kcal=Decimal("400")
        )
        for user in (self.user, self.other):
            Profile.objects.create(user=user, sex="female", weight_kg=Decimal("70"))
            Consent.objects.create(user=user, type="health_data", version="2026-10")
        entry = DiaryEntry(
            user=self.user, date="2026-10-23", meal="snack", food=self.mine, amount_g=50
        )
        entry.apply_snapshot()
        entry.save()
        deleted = DiaryEntry(
            user=self.user, date="2026-10-22", meal="lunch", food=self.shared, amount_g=100
        )
        deleted.apply_snapshot()
        deleted.save()
        deleted.soft_delete()
        other_entry = DiaryEntry(
            user=self.other, date="2026-10-23", meal="lunch", food=self.mine, amount_g=10
        )
        other_entry.apply_snapshot()
        other_entry.save()
        for user in (self.user, self.other):
            WeightLog.objects.create(user=user, date="2026-10-23", weight_kg=Decimal("70.0"))
            WaterLog.objects.create(user=user, date="2026-10-23", amount_ml=250)
            Activity.objects.create(user=user, date="2026-10-23", duration_min=30, kcal=200)
            StepDay.objects.create(user=user, date="2026-10-23", steps=8000)


class ExportTests(PersonalDataTestCase):
    def test_requires_login(self):
        self.assertEqual(self.client.get(reverse("me-export")).status_code, 401)

    def test_export_contains_all_own_data_only(self):
        self.client.force_authenticate(self.user)
        response = self.client.get(reverse("me-export"))
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("attachment", response["Content-Disposition"])
        self.assertEqual(response["Cache-Control"], "no-store")

        data = json.loads(response.content)
        self.assertEqual(data["account"]["email"], "a@example.com")
        self.assertEqual(data["profile"][0]["weight_kg"], "70.0")
        self.assertEqual(data["consents"][0]["type"], "health_data")
        self.assertEqual([food["name"] for food in data["custom_foods"]], ["Omas Kuchen"])
        # soft-deleted entries are still stored, so they are exported too
        self.assertEqual(len(data["diary_entries"]), 2)
        self.assertEqual(data["diary_entries"][1]["food__name"], "Omas Kuchen")
        self.assertEqual(data["diary_entries"][1]["kcal"], "200.00")
        self.assertEqual(data["weight_logs"][0]["weight_kg"], "70.0")
        self.assertEqual(data["water_logs"][0]["amount_ml"], 250)
        self.assertEqual(len(data["weight_logs"]), 1)
        self.assertEqual(data["activities"][0]["kcal"], "200.0")
        self.assertEqual(data["step_days"][0]["steps"], 8000)
        self.assertNotIn("b@example.com", response.content.decode())


class DeleteAccountTests(PersonalDataTestCase):
    def login_tokens(self) -> dict:
        response = self.client.post(
            reverse("auth-login"), {"email": "a@example.com", "password": PASSWORD}, format="json"
        )
        return response.data

    def test_wrong_or_missing_password_keeps_everything(self):
        self.client.force_authenticate(self.user)
        for body in ({}, {"password": "wrong"}):
            response = self.client.delete(reverse("me-delete"), body, format="json")
            self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
            self.assertIn("password", response.data["fields"])
        self.assertTrue(User.objects.filter(pk=self.user.pk).exists())

    def test_delete_removes_all_personal_data(self):
        tokens = self.login_tokens()
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
        response = self.client.delete(reverse("me-delete"), {"password": PASSWORD}, format="json")
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)

        self.assertFalse(User.objects.filter(pk=self.user.pk).exists())
        self.assertFalse(DiaryEntry.all_objects.filter(user_id=self.user.pk).exists())
        self.assertFalse(Profile.all_objects.filter(user_id=self.user.pk).exists())
        self.assertFalse(Consent.all_objects.filter(user_id=self.user.pk).exists())
        self.assertFalse(WeightLog.all_objects.filter(user_id=self.user.pk).exists())
        self.assertFalse(WaterLog.all_objects.filter(user_id=self.user.pk).exists())
        self.assertEqual(WeightLog.objects.filter(user=self.other).count(), 1)
        self.assertFalse(Activity.all_objects.filter(user_id=self.user.pk).exists())
        self.assertFalse(StepDay.all_objects.filter(user_id=self.user.pk).exists())
        self.assertEqual(Activity.objects.filter(user=self.other).count(), 1)
        # still used by the other user's diary → kept, but no longer linked to the account
        self.assertIsNone(Food.all_objects.get(pk=self.mine.pk).created_by)

        # shared foods and the other user's data stay
        self.assertTrue(Food.objects.filter(pk=self.shared.pk).exists())
        self.assertTrue(User.objects.filter(pk=self.other.pk).exists())
        self.assertEqual(DiaryEntry.objects.filter(user=self.other).count(), 1)

        # old tokens no longer work
        self.client.credentials()
        refresh = self.client.post(
            reverse("auth-refresh"), {"refresh": tokens["refresh"]}, format="json"
        )
        self.assertEqual(refresh.status_code, status.HTTP_401_UNAUTHORIZED)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
        self.assertEqual(self.client.get(reverse("me-profile")).status_code, 401)

    def test_unused_custom_food_is_deleted(self):
        unused = Food.objects.create(name="Mein Brot", source="user", created_by=self.user)
        self.client.force_authenticate(self.user)
        self.client.delete(reverse("me-delete"), {"password": PASSWORD}, format="json")
        self.assertFalse(Food.all_objects.filter(pk=unused.pk).exists())

    def test_requires_login(self):
        response = self.client.delete(reverse("me-delete"), {"password": PASSWORD}, format="json")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
