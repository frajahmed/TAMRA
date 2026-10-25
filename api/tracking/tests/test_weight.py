from datetime import date
from decimal import Decimal

from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.reverse import reverse
from rest_framework.test import APITestCase

from profiles.models import Profile
from tracking.models import WeightLog

User = get_user_model()


class WeightApiTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="a@example.com", password="x")
        self.other = User.objects.create_user(email="b@example.com", password="x")
        self.client.force_authenticate(self.user)
        self.list_url = reverse("weight-list")

    def test_requires_login(self):
        self.client.force_authenticate(None)
        response = self.client.get(self.list_url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_create_weight(self):
        payload = {"date": "2026-10-23", "weight_kg": "75.5"}
        response = self.client.post(self.list_url, payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["weight_kg"], "75.5")
        self.assertEqual(WeightLog.objects.count(), 1)

    def test_update_existing_weight_returns_200(self):
        WeightLog.objects.create(user=self.user, date=date(2026, 10, 23), weight_kg=75.5)
        payload = {"date": "2026-10-23", "weight_kg": "76.0"}
        response = self.client.post(self.list_url, payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["weight_kg"], "76.0")
        self.assertEqual(WeightLog.objects.count(), 1)

    def test_list_weights(self):
        WeightLog.objects.create(user=self.user, date=date(2026, 10, 23), weight_kg=75.5)
        WeightLog.objects.create(user=self.user, date=date(2026, 10, 22), weight_kg=75.0)
        response = self.client.get(self.list_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 2)
        self.assertEqual(response.data[0]["date"], "2026-10-23")

    def test_range_filter(self):
        WeightLog.objects.create(user=self.user, date=date(2026, 10, 23), weight_kg=75.5)
        WeightLog.objects.create(user=self.user, date=date(2026, 10, 22), weight_kg=75.0)
        WeightLog.objects.create(user=self.user, date=date(2026, 10, 21), weight_kg=74.5)

        response = self.client.get(self.list_url, {"from": "2026-10-22", "to": "2026-10-23"})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 2)

    def test_invalid_date_format(self):
        response = self.client.get(self.list_url, {"from": "invalid"})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("from", response.data["fields"])

    def test_detail_get(self):
        log = WeightLog.objects.create(user=self.user, date=date(2026, 10, 23), weight_kg=75.5)
        url = reverse("weight-detail", kwargs={"pk": log.pk})
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["id"], str(log.pk))

    def test_detail_patch(self):
        log = WeightLog.objects.create(user=self.user, date=date(2026, 10, 23), weight_kg=75.5)
        url = reverse("weight-detail", kwargs={"pk": log.pk})
        response = self.client.patch(url, {"weight_kg": "76.0"}, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        log.refresh_from_db()
        self.assertEqual(log.weight_kg, 76.0)

    def test_detail_delete_soft(self):
        log = WeightLog.objects.create(user=self.user, date=date(2026, 10, 23), weight_kg=75.5)
        url = reverse("weight-detail", kwargs={"pk": log.pk})
        response = self.client.delete(url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertIsNone(WeightLog.objects.filter(pk=log.pk).first())
        self.assertIsNotNone(WeightLog.all_objects.filter(pk=log.pk).first().deleted_at)

    def test_other_user_404(self):
        log = WeightLog.objects.create(user=self.other, date=date(2026, 10, 23), weight_kg=75.5)
        url = reverse("weight-detail", kwargs={"pk": log.pk})
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_sync_profile_weight_on_create(self):
        payload = {"date": "2026-10-23", "weight_kg": "75.5"}
        self.client.post(self.list_url, payload, format="json")
        profile = Profile.objects.get(user=self.user)
        self.assertEqual(profile.weight_kg, 75.5)

    def test_delete_newest_falls_back_to_previous_weight(self):
        self.client.post(self.list_url, {"date": "2026-10-22", "weight_kg": "80.0"}, format="json")
        response = self.client.post(
            self.list_url, {"date": "2026-10-23", "weight_kg": "79.0"}, format="json"
        )
        self.client.delete(reverse("weight-detail", kwargs={"pk": response.data["id"]}))
        self.assertEqual(Profile.objects.get(user=self.user).weight_kg, Decimal("80.0"))

    def test_delete_last_weight_keeps_profile_weight(self):
        response = self.client.post(
            self.list_url, {"date": "2026-10-23", "weight_kg": "75.5"}, format="json"
        )
        self.client.delete(reverse("weight-detail", kwargs={"pk": response.data["id"]}))
        self.assertEqual(Profile.objects.get(user=self.user).weight_kg, Decimal("75.5"))

    def test_new_weight_recalculates_kcal_target(self):
        Profile.objects.update_or_create(
            user=self.user,
            defaults={
                "sex": "female",
                "birth_year": 1990,
                "height_cm": 170,
                "weight_kg": Decimal("80.0"),
            },
        )
        profile = Profile.objects.get(user=self.user)
        profile.recalculate_targets()
        profile.save()
        before = profile.kcal_target

        self.client.post(self.list_url, {"date": "2026-10-23", "weight_kg": "70.0"}, format="json")

        self.assertLess(Profile.objects.get(user=self.user).kcal_target, before)

    def test_patch_onto_taken_day_is_rejected(self):
        WeightLog.objects.create(user=self.user, date=date(2026, 10, 22), weight_kg=75.0)
        log = WeightLog.objects.create(user=self.user, date=date(2026, 10, 23), weight_kg=75.5)
        url = reverse("weight-detail", kwargs={"pk": log.pk})
        response = self.client.patch(url, {"date": "2026-10-22"}, format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("date", response.data["fields"])

    def test_weight_out_of_range(self):
        for value in ("29.9", "300.1"):
            response = self.client.post(
                self.list_url, {"date": "2026-10-23", "weight_kg": value}, format="json"
            )
            self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
            self.assertIn("weight_kg", response.data["fields"])

    def test_deleted_day_can_be_logged_again(self):
        log = WeightLog.objects.create(user=self.user, date=date(2026, 10, 23), weight_kg=75.5)
        self.client.delete(reverse("weight-detail", kwargs={"pk": log.pk}))
        response = self.client.post(
            self.list_url, {"date": "2026-10-23", "weight_kg": "74.0"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_other_users_weights_are_not_listed(self):
        WeightLog.objects.create(user=self.other, date=date(2026, 10, 23), weight_kg=90)
        response = self.client.get(self.list_url)
        self.assertEqual(response.data, [])
