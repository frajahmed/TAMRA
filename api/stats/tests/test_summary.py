from decimal import Decimal

from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.reverse import reverse
from rest_framework.test import APITestCase

from diary.models import DiaryEntry
from foods.models import Food
from profiles.models import Profile
from tracking.models import WaterLog, WeightLog

User = get_user_model()
URL = "stats-summary"


class StatsSummaryTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="a@example.com", password="x")
        self.other = User.objects.create_user(email="b@example.com", password="x")
        self.client.force_authenticate(self.user)
        # 100 kcal, 10 g protein, 20 g carbs, 5 g fat per 100 g → easy sums
        self.food = Food.objects.create(
            name="Test",
            source="off",
            kcal=Decimal("100"),
            protein=Decimal("10"),
            carbs=Decimal("20"),
            fat=Decimal("5"),
        )

    def eat(self, day: str, grams: int, user=None) -> DiaryEntry:
        entry = DiaryEntry(
            user=user or self.user, date=day, meal="lunch", food=self.food, amount_g=grams
        )
        entry.apply_snapshot()
        entry.save()
        return entry

    def get(self, start: str, end: str):
        return self.client.get(reverse(URL), {"from": start, "to": end})

    def test_requires_login(self):
        self.client.force_authenticate(None)
        self.assertEqual(self.get("2026-10-20", "2026-10-26").status_code, 401)

    def test_invalid_ranges(self):
        cases = [
            ({"to": "2026-10-26"}, "from"),
            ({"from": "2026-10-20"}, "to"),
            ({"from": "20.10.2026", "to": "2026-10-26"}, "from"),
            ({"from": "2026-10-26", "to": "2026-10-20"}, "to"),
            ({"from": "2026-10-01", "to": "2026-11-01"}, "to"),  # 32 days
        ]
        for params, field in cases:
            response = self.client.get(reverse(URL), params)
            self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST, params)
            self.assertIn(field, response.data["fields"], params)

    def test_31_days_are_allowed(self):
        response = self.get("2026-10-01", "2026-10-31")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["days"]), 31)

    def test_sums_per_day_and_empty_days(self):
        self.eat("2026-10-20", 100)
        self.eat("2026-10-20", 200)
        self.eat("2026-10-22", 50)

        data = self.get("2026-10-20", "2026-10-22").data
        days = data["days"]
        self.assertEqual([day["date"] for day in days], ["2026-10-20", "2026-10-21", "2026-10-22"])
        self.assertEqual(days[0]["kcal"], "300.00")
        self.assertEqual(days[0]["protein"], "30.00")
        self.assertEqual(days[1]["kcal"], "0.00")
        self.assertEqual(days[1]["water_ml"], 0)
        self.assertIsNone(days[1]["weight_kg"])
        self.assertEqual(days[2]["fat"], "2.50")

    def test_averages_only_over_logged_days(self):
        self.eat("2026-10-20", 300)
        self.eat("2026-10-22", 100)

        averages = self.get("2026-10-20", "2026-10-26").data["averages"]
        self.assertEqual(averages["logged_days"], 2)
        self.assertEqual(averages["kcal"], "200.00")
        self.assertEqual(averages["carbs"], "40.00")

    def test_no_entries_gives_zero_averages(self):
        averages = self.get("2026-10-20", "2026-10-26").data["averages"]
        self.assertEqual(
            averages,
            {
                "kcal": "0.00",
                "protein": "0.00",
                "carbs": "0.00",
                "fat": "0.00",
                "burned_kcal": "0.00",
                "logged_days": 0,
            },
        )

    def test_water_and_weight(self):
        WaterLog.objects.create(user=self.user, date="2026-10-20", amount_ml=250)
        WaterLog.objects.create(user=self.user, date="2026-10-20", amount_ml=500)
        WeightLog.objects.create(user=self.user, date="2026-10-20", weight_kg=Decimal("80.0"))
        WeightLog.objects.create(user=self.user, date="2026-10-24", weight_kg=Decimal("79.4"))

        data = self.get("2026-10-20", "2026-10-26").data
        self.assertEqual(data["days"][0]["water_ml"], 750)
        self.assertEqual(data["days"][0]["weight_kg"], "80.0")
        self.assertEqual(data["weight_change_kg"], "-0.6")

    def test_weight_change_needs_two_weights(self):
        WeightLog.objects.create(user=self.user, date="2026-10-20", weight_kg=Decimal("80.0"))
        self.assertIsNone(self.get("2026-10-20", "2026-10-26").data["weight_change_kg"])

    def test_other_users_and_deleted_entries_are_not_counted(self):
        self.eat("2026-10-20", 100, user=self.other)
        WaterLog.objects.create(user=self.other, date="2026-10-20", amount_ml=999)
        self.eat("2026-10-20", 100).soft_delete()

        day = self.get("2026-10-20", "2026-10-20").data["days"][0]
        self.assertEqual(day["kcal"], "0.00")
        self.assertEqual(day["water_ml"], 0)

    def test_kcal_target(self):
        self.assertIsNone(self.get("2026-10-20", "2026-10-20").data["kcal_target"])
        Profile.objects.create(user=self.user, kcal_target=1850)
        data = self.get("2026-10-20", "2026-10-20").data
        self.assertEqual(data["kcal_target"], 1850)
        self.assertEqual(data["from"], "2026-10-20")
        self.assertEqual(data["to"], "2026-10-20")
