from datetime import date

from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.reverse import reverse
from rest_framework.test import APITestCase

from tracking.models import WaterLog

User = get_user_model()


class WaterApiTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="a@example.com", password="x")
        self.other = User.objects.create_user(email="b@example.com", password="x")
        self.client.force_authenticate(self.user)
        self.list_url = reverse("water-list")
        self.summary_url = reverse("water-summary")

    def test_requires_login(self):
        self.client.force_authenticate(None)
        response = self.client.get(self.list_url, {"date": "2026-10-23"})
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_list_requires_date(self):
        response = self.client.get(self.list_url)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("date", response.data["fields"])

    def test_create_water(self):
        payload = {"date": "2026-10-23", "amount_ml": 250}
        response = self.client.post(self.list_url, payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["amount_ml"], 250)

    def test_multiple_entries_same_day(self):
        self.client.post(self.list_url, {"date": "2026-10-23", "amount_ml": 250}, format="json")
        self.client.post(self.list_url, {"date": "2026-10-23", "amount_ml": 300}, format="json")
        response = self.client.get(self.list_url, {"date": "2026-10-23"})
        self.assertEqual(len(response.data), 2)

    def test_summary(self):
        self.client.post(self.list_url, {"date": "2026-10-23", "amount_ml": 250}, format="json")
        self.client.post(self.list_url, {"date": "2026-10-23", "amount_ml": 300}, format="json")
        response = self.client.get(self.summary_url, {"date": "2026-10-23"})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["total_ml"], 550)
        self.assertEqual(response.data["date"], "2026-10-23")

    def test_summary_requires_date(self):
        response = self.client.get(self.summary_url)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("date", response.data["fields"])

    def test_detail_delete(self):
        log = WaterLog.objects.create(user=self.user, date=date(2026, 10, 23), amount_ml=250)
        url = reverse("water-detail", kwargs={"pk": log.pk})
        response = self.client.delete(url)
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertIsNone(WaterLog.objects.filter(pk=log.pk).first())

    def test_other_user_404(self):
        log = WaterLog.objects.create(user=self.other, date=date(2026, 10, 23), amount_ml=250)
        url = reverse("water-detail", kwargs={"pk": log.pk})
        response = self.client.delete(url)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_other_users_water_is_not_listed_or_counted(self):
        WaterLog.objects.create(user=self.other, date=date(2026, 10, 23), amount_ml=500)
        response = self.client.get(self.list_url, {"date": "2026-10-23"})
        self.assertEqual(response.data, [])
        response = self.client.get(self.summary_url, {"date": "2026-10-23"})
        self.assertEqual(response.data["total_ml"], 0)

    def test_deleted_water_is_not_counted(self):
        log = WaterLog.objects.create(user=self.user, date=date(2026, 10, 23), amount_ml=250)
        self.client.delete(reverse("water-detail", kwargs={"pk": log.pk}))
        response = self.client.get(self.summary_url, {"date": "2026-10-23"})
        self.assertEqual(response.data["total_ml"], 0)

    def test_validation_amount(self):
        payload = {"date": "2026-10-23", "amount_ml": 0}
        response = self.client.post(self.list_url, payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("amount_ml", response.data["fields"])

        payload = {"date": "2026-10-23", "amount_ml": 5001}
        response = self.client.post(self.list_url, payload, format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("amount_ml", response.data["fields"])
