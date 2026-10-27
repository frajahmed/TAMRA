from decimal import Decimal

from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.reverse import reverse
from rest_framework.test import APITestCase

from activity.models import Activity, StepDay

User = get_user_model()
DAY = "2026-10-26"


def workout(**overrides) -> dict:
    data = {
        "date": DAY,
        "kind": "running",
        "duration_min": 30,
        "kcal": "320.0",
        "distance_m": 5000,
        "source": "health_connect",
        "external_id": "hc-1",
    }
    data.update(overrides)
    return data


class ActivityTestCase(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="a@example.com", password="x")
        self.other = User.objects.create_user(email="b@example.com", password="x")
        self.client.force_authenticate(self.user)

    def import_(self, activities=None, steps=None):
        body = {"activities": activities or [], "steps": steps or []}
        return self.client.post(reverse("activity-import"), body, format="json")


class ManualActivityTests(ActivityTestCase):
    def test_requires_login(self):
        self.client.force_authenticate(None)
        self.assertEqual(self.client.get(reverse("activity-list")).status_code, 401)

    def test_create_manual_ignores_source_and_external_id(self):
        body = {
            "date": DAY,
            "kind": "cycling",
            "duration_min": 45,
            "kcal": "350",
            "source": "strava",
            "external_id": "x",
        }
        response = self.client.post(reverse("activity-list"), body, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["source"], "manual")
        self.assertEqual(response.data["external_id"], "")
        self.assertFalse(response.data["is_imported"])

    def test_validation(self):
        for field, value in (("duration_min", 0), ("duration_min", 1441), ("kcal", "10000.1")):
            body = {"date": DAY, "kind": "yoga", "duration_min": 30, "kcal": "100", field: value}
            response = self.client.post(reverse("activity-list"), body, format="json")
            self.assertEqual(response.status_code, 400, field)
            self.assertIn(field, response.data["fields"])

    def test_list_by_date_and_range(self):
        Activity.objects.create(user=self.user, date=DAY, duration_min=10, kcal=50)
        Activity.objects.create(user=self.user, date="2026-10-20", duration_min=20, kcal=80)
        Activity.objects.create(user=self.other, date=DAY, duration_min=10, kcal=50)

        response = self.client.get(reverse("activity-list"), {"date": DAY})
        self.assertEqual(len(response.data), 1)
        response = self.client.get(reverse("activity-list"), {"from": "2026-10-01", "to": DAY})
        self.assertEqual(len(response.data), 2)
        self.assertEqual(len(self.client.get(reverse("activity-list")).data), 2)

    def test_range_limits(self):
        for params, field in (
            ({"from": "2025-01-01", "to": "2026-10-26"}, "to"),
            ({"from": "2026-10-26", "to": "2026-10-01"}, "to"),
            ({"from": "2026-10-01"}, "to"),
            ({"date": "26.10.2026"}, "date"),
        ):
            response = self.client.get(reverse("activity-list"), params)
            self.assertEqual(response.status_code, 400, params)
            self.assertIn(field, response.data["fields"], params)

    def test_patch_manual_works_and_imported_is_refused(self):
        manual = Activity.objects.create(user=self.user, date=DAY, duration_min=10, kcal=50)
        imported = Activity.objects.create(
            user=self.user, date=DAY, duration_min=10, kcal=50, source="strava", external_id="s1"
        )
        url = reverse("activity-detail", kwargs={"pk": manual.pk})
        self.assertEqual(
            self.client.patch(url, {"duration_min": 20}, format="json").status_code, 200
        )

        url = reverse("activity-detail", kwargs={"pk": imported.pk})
        response = self.client.patch(url, {"duration_min": 20}, format="json")
        self.assertEqual(response.status_code, 400)
        self.assertIn("source", response.data["fields"])

    def test_delete_is_soft_and_other_users_get_404(self):
        mine = Activity.objects.create(user=self.user, date=DAY, duration_min=10, kcal=50)
        theirs = Activity.objects.create(user=self.other, date=DAY, duration_min=10, kcal=50)
        self.assertEqual(
            self.client.delete(reverse("activity-detail", kwargs={"pk": theirs.pk})).status_code,
            404,
        )
        self.assertEqual(
            self.client.delete(reverse("activity-detail", kwargs={"pk": mine.pk})).status_code,
            204,
        )
        self.assertIsNotNone(Activity.all_objects.get(pk=mine.pk).deleted_at)


class ImportTests(ActivityTestCase):
    def test_import_twice_creates_no_duplicates(self):
        first = self.import_([workout()])
        self.assertEqual(first.data, {"created": 1, "updated": 0, "skipped": 0})
        second = self.import_([workout(kcal="330.0")])
        self.assertEqual(second.data, {"created": 0, "updated": 1, "skipped": 0})
        self.assertEqual(Activity.objects.count(), 1)
        self.assertEqual(Activity.objects.get().kcal, Decimal("330.0"))

    def test_same_external_id_from_another_source_is_another_workout(self):
        self.import_([workout(), workout(source="apple_health")])
        self.assertEqual(Activity.objects.count(), 2)

    def test_deleted_import_stays_deleted(self):
        self.import_([workout()])
        activity = Activity.objects.get()
        self.client.delete(reverse("activity-detail", kwargs={"pk": activity.pk}))

        response = self.import_([workout()])
        self.assertEqual(response.data["skipped"], 1)
        self.assertEqual(Activity.objects.count(), 0)

    def test_import_needs_a_non_manual_source_and_external_id(self):
        response = self.import_([workout(source="manual")])
        self.assertEqual(response.status_code, 400)
        response = self.import_([workout(external_id="")])
        self.assertEqual(response.status_code, 400)

    def test_import_limit(self):
        many = [workout(external_id=f"hc-{index}") for index in range(501)]
        response = self.import_(many)
        self.assertEqual(response.status_code, 400)
        self.assertIn("activities", response.data["fields"])

    def test_steps_keep_the_higher_value(self):
        first = self.import_(steps=[{"date": DAY, "steps": 4000, "source": "health_connect"}])
        self.assertEqual(first.data["created"], 1)
        lower = self.import_(steps=[{"date": DAY, "steps": 3000, "source": "health_connect"}])
        self.assertEqual(lower.data["skipped"], 1)
        higher = self.import_(steps=[{"date": DAY, "steps": 9000, "source": "apple_health"}])
        self.assertEqual(higher.data["updated"], 1)
        self.assertEqual(StepDay.objects.get().steps, 9000)

    def test_steps_maximum(self):
        response = self.import_(steps=[{"date": DAY, "steps": 200_001, "source": "health_connect"}])
        self.assertEqual(response.status_code, 400)

    def test_imported_data_belongs_to_the_user(self):
        self.import_([workout()])
        self.client.force_authenticate(self.other)
        self.assertEqual(self.client.get(reverse("activity-list")).data, [])


class SummaryTests(ActivityTestCase):
    def test_day_totals(self):
        self.import_(
            [workout(), workout(external_id="hc-2", kcal="80.5", duration_min=15)],
            [{"date": DAY, "steps": 8500, "source": "health_connect"}],
        )
        Activity.objects.create(user=self.other, date=DAY, duration_min=60, kcal=500)

        response = self.client.get(reverse("activity-summary"), {"date": DAY})
        self.assertEqual(
            response.data,
            {"date": DAY, "burned_kcal": "400.5", "minutes": 45, "steps": 8500},
        )

    def test_empty_day(self):
        response = self.client.get(reverse("activity-summary"), {"date": DAY})
        self.assertEqual(response.data["burned_kcal"], "0.0")
        self.assertEqual(response.data["steps"], 0)
