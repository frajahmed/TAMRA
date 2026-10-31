from datetime import date, timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import SimpleTestCase
from rest_framework import status
from rest_framework.reverse import reverse
from rest_framework.test import APITestCase

from diary.models import DiaryEntry
from foods.models import Food
from stats.streaks import BADGE_DAYS, compute_streak

User = get_user_model()


class ComputeStreakTests(SimpleTestCase):
    def test_no_entries(self):
        result = compute_streak([], date(2026, 11, 2))

        self.assertEqual(result.current_days, 0)
        self.assertEqual(result.longest_days, 0)
        self.assertFalse(result.logged_today)
        self.assertEqual([badge.days for badge in result.badges], list(BADGE_DAYS))
        self.assertTrue(all(not badge.earned for badge in result.badges))
        self.assertTrue(all(badge.earned_on is None for badge in result.badges))

    def test_run_through_yesterday_is_still_current(self):
        today = date(2026, 11, 2)
        result = compute_streak([today - timedelta(days=offset) for offset in (1, 2, 3)], today)

        self.assertEqual(result.current_days, 3)
        self.assertFalse(result.logged_today)

    def test_today_and_yesterday_form_current_run(self):
        today = date(2026, 11, 2)
        result = compute_streak([today - timedelta(days=1), today], today)

        self.assertEqual(result.current_days, 2)
        self.assertTrue(result.logged_today)

    def test_gap_breaks_current_run_but_keeps_longest_run(self):
        today = date(2026, 11, 10)
        older_run = [date(2026, 11, day) for day in range(1, 5)]
        result = compute_streak([*older_run, date(2026, 11, 9), today], today)

        self.assertEqual(result.current_days, 2)
        self.assertEqual(result.longest_days, 4)

    def test_badges_use_first_date_a_run_reaches_the_milestone(self):
        start = date(2026, 1, 1)
        days = [start + timedelta(days=offset) for offset in range(30)]
        result = compute_streak(days, days[-1])

        badges = {badge.days: badge for badge in result.badges}
        self.assertEqual(result.longest_days, 30)
        self.assertTrue(badges[7].earned)
        self.assertEqual(badges[7].earned_on, date(2026, 1, 7))
        self.assertTrue(badges[30].earned)
        self.assertEqual(badges[30].earned_on, date(2026, 1, 30))
        self.assertFalse(badges[100].earned)
        self.assertIsNone(badges[100].earned_on)


class StreakApiTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="a@example.com", password="x")
        self.other_user = User.objects.create_user(email="b@example.com", password="x")
        self.food = Food.objects.create(name="Test", source="off", kcal=Decimal("100"))
        self.url = reverse("stats-streak")
        self.client.force_authenticate(self.user)

    def add_entry(self, user, day: date) -> DiaryEntry:
        return DiaryEntry.objects.create(
            user=user,
            date=day,
            meal=DiaryEntry.Meal.LUNCH,
            food=self.food,
            amount_g=Decimal("100"),
        )

    def get(self, day: str):
        return self.client.get(self.url, {"date": day})

    def test_no_entries_returns_empty_streak_and_badges(self):
        response = self.get("2026-11-02")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            response.data,
            {
                "date": "2026-11-02",
                "current_days": 0,
                "longest_days": 0,
                "logged_today": False,
                "badges": [
                    {"days": 7, "earned": False, "earned_on": None},
                    {"days": 30, "earned": False, "earned_on": None},
                    {"days": 100, "earned": False, "earned_on": None},
                ],
            },
        )

    def test_two_entries_on_one_day_count_once_and_use_one_query(self):
        day = date(2026, 11, 2)
        self.add_entry(self.user, day)
        self.add_entry(self.user, day)

        with self.assertNumQueries(1):
            response = self.get(day.isoformat())

        self.assertEqual(response.data["current_days"], 1)
        self.assertEqual(response.data["longest_days"], 1)

    def test_soft_deleted_entry_does_not_count(self):
        day = date(2026, 11, 2)
        entry = self.add_entry(self.user, day)
        entry.soft_delete()

        response = self.get(day.isoformat())

        self.assertEqual(response.data["current_days"], 0)
        self.assertFalse(response.data["logged_today"])

    def test_other_users_entries_do_not_count(self):
        day = date(2026, 11, 2)
        self.add_entry(self.other_user, day)

        response = self.get(day.isoformat())

        self.assertEqual(response.data["current_days"], 0)
        self.assertFalse(response.data["logged_today"])

    def test_entries_after_requested_date_are_ignored(self):
        requested = date(2026, 11, 2)
        self.add_entry(self.user, requested + timedelta(days=1))

        response = self.get(requested.isoformat())

        self.assertEqual(response.data["current_days"], 0)
        self.assertEqual(response.data["longest_days"], 0)

    def test_date_is_required_and_must_be_iso_format(self):
        missing = self.client.get(self.url)
        wrong = self.get("02.11.2026")

        self.assertEqual(missing.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("date", missing.data["fields"])
        self.assertEqual(wrong.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("date", wrong.data["fields"])

    def test_authentication_is_required(self):
        self.client.force_authenticate(user=None)

        response = self.get("2026-11-02")

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
