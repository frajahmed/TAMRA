from decimal import Decimal

from django.contrib.auth import get_user_model
from rest_framework.reverse import reverse
from rest_framework.test import APITestCase

from activity.models import Activity, StepDay
from diary.models import DiaryEntry
from foods.models import Food
from profiles.models import Profile
from tracking.models import WeightLog

User = get_user_model()


class BalanceTestCase(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="a@example.com", password="x")
        self.client.force_authenticate(self.user)
        self.food = Food.objects.create(name="Test", source="off", kcal=Decimal("100"))
        self.profile = Profile.objects.create(user=self.user, kcal_target=2000)

    def eat(self, day: str, kcal: int) -> None:
        entry = DiaryEntry(user=self.user, date=day, meal="lunch", food=self.food, amount_g=kcal)
        entry.apply_snapshot()
        entry.save()

    def sport(self, day: str, kcal: int) -> None:
        Activity.objects.create(user=self.user, date=day, duration_min=30, kcal=kcal)


class DayBalanceTests(BalanceTestCase):
    def get(self, day: str):
        return self.client.get(reverse("stats-day"), {"date": day}).data

    def test_budget_includes_sport(self):
        self.eat("2026-10-26", 1500)
        self.sport("2026-10-26", 300)
        StepDay.objects.create(user=self.user, date="2026-10-26", steps=9000)

        data = self.get("2026-10-26")
        self.assertEqual(data["eaten_kcal"], "1500.00")
        self.assertEqual(data["burned_kcal"], "300.00")
        self.assertEqual(data["budget"], "2300.00")
        self.assertEqual(data["remaining"], "800.00")
        self.assertEqual(data["steps"], 9000)
        self.assertEqual(len(data["activities"]), 1)

    def test_sport_not_counted_when_switched_off(self):
        self.profile.count_activity_kcal = False
        self.profile.save()
        self.eat("2026-10-26", 1500)
        self.sport("2026-10-26", 300)

        data = self.get("2026-10-26")
        self.assertEqual(data["budget"], "2000.00")
        self.assertEqual(data["remaining"], "500.00")

    def test_steps_are_never_added(self):
        StepDay.objects.create(user=self.user, date="2026-10-26", steps=20000)
        self.assertEqual(self.get("2026-10-26")["budget"], "2000.00")

    def test_without_target_there_is_no_budget(self):
        self.profile.kcal_target = None
        self.profile.save()
        data = self.get("2026-10-26")
        self.assertIsNone(data["budget"])
        self.assertIsNone(data["remaining"])

    def test_switch_can_be_changed_in_the_profile(self):
        response = self.client.patch(
            reverse("me-profile"), {"count_activity_kcal": False}, format="json"
        )
        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.data["count_activity_kcal"])


class GroupedSummaryTests(BalanceTestCase):
    def get(self, start: str, end: str, group: str):
        return self.client.get(reverse("stats-summary"), {"from": start, "to": end, "group": group})

    def test_daily_rows_have_sport_budget_and_balance(self):
        self.eat("2026-10-26", 2100)
        self.sport("2026-10-26", 400)
        day = self.get("2026-10-26", "2026-10-26", "day").data["days"][0]
        self.assertEqual(day["burned_kcal"], "400.00")
        self.assertEqual(day["budget"], "2400.00")
        self.assertEqual(day["balance"], "-300.00")

    def test_weeks_average_over_logged_days(self):
        # ISO week of Mon 2026-10-19: two logged days; week of 2026-10-26: one logged day
        self.eat("2026-10-19", 1000)
        self.eat("2026-10-21", 2000)
        self.eat("2026-10-26", 1800)
        WeightLog.objects.create(user=self.user, date="2026-10-20", weight_kg=Decimal("80.0"))
        WeightLog.objects.create(user=self.user, date="2026-10-22", weight_kg=Decimal("79.5"))

        data = self.get("2026-10-19", "2026-11-01", "week").data
        weeks = data["days"]
        self.assertEqual([week["date"] for week in weeks], ["2026-10-19", "2026-10-26"])
        self.assertEqual(weeks[0]["kcal"], "1500.00")
        self.assertEqual(weeks[0]["logged_days"], 2)
        self.assertEqual(weeks[0]["weight_kg"], "79.5")
        self.assertEqual(weeks[0]["balance"], "-500.00")
        self.assertEqual(weeks[1]["kcal"], "1800.00")
        self.assertIsNone(weeks[1]["weight_kg"])

    def test_months_group_by_calendar_month(self):
        self.eat("2026-09-30", 1000)
        self.eat("2026-10-01", 3000)
        months = self.get("2026-09-01", "2026-10-31", "month").data["days"]
        self.assertEqual([month["date"] for month in months], ["2026-09-01", "2026-10-01"])
        self.assertEqual(months[1]["kcal"], "3000.00")

    def test_limits_per_group(self):
        self.assertEqual(self.get("2026-01-01", "2026-12-31", "week").status_code, 200)
        self.assertEqual(self.get("2026-01-01", "2026-02-15", "day").status_code, 400)
        self.assertEqual(self.get("2025-01-01", "2026-12-31", "month").status_code, 400)
        response = self.get("2026-10-01", "2026-10-02", "year")
        self.assertEqual(response.status_code, 400)
        self.assertIn("group", response.data["fields"])
