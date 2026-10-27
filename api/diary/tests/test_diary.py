import uuid
from decimal import Decimal

from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.reverse import reverse
from rest_framework.test import APITestCase

from diary.models import DiaryEntry
from foods.models import Food
from profiles.models import Profile

User = get_user_model()
DAY = "2026-10-23"
NEXT_DAY = "2026-10-24"


class DiaryTestCase(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="a@example.com", password="x")
        self.other = User.objects.create_user(email="b@example.com", password="x")
        self.client.force_authenticate(self.user)
        self.oats = Food.objects.create(
            name="Haferflocken",
            source="off",
            kcal=Decimal("372"),
            protein=Decimal("13.5"),
            carbs=Decimal("58.7"),
            sugar=Decimal("0.7"),
            fat=Decimal("7"),
            fiber=Decimal("10"),
            salt=Decimal("0.02"),
        )
        self.milk = Food.objects.create(
            name="Milch", source="off", kcal=Decimal("64"), carbs=Decimal("4.8")
        )
        self.foreign_food = Food.objects.create(
            name="Fremdes Rezept", source="user", created_by=self.other, kcal=Decimal("100")
        )

    def add(self, food=None, amount="50", meal="breakfast", day=DAY, **extra):
        body = {
            "date": day,
            "meal": meal,
            "food": str((food or self.oats).pk),
            "amount_g": amount,
            **extra,
        }
        return self.client.post(reverse("diary-list"), body, format="json")

    def detail(self, entry_id) -> str:
        return reverse("diary-detail", kwargs={"pk": entry_id})


class CreateAndListTests(DiaryTestCase):
    def test_requires_login(self):
        self.client.force_authenticate(None)
        response = self.client.get(reverse("diary-list"), {"date": DAY})
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_create_stores_nutrient_snapshot(self):
        response = self.add(amount="50")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["kcal"], "186.00")
        self.assertEqual(response.data["protein"], "6.75")
        self.assertEqual(response.data["carbs"], "29.35")
        self.assertEqual(response.data["salt"], "0.01")
        self.assertEqual(response.data["food_detail"]["name"], "Haferflocken")

    def test_snapshot_values_from_client_are_ignored(self):
        response = self.add(kcal="1")
        self.assertEqual(response.data["kcal"], "186.00")

    def test_client_may_choose_the_id_for_offline_use(self):
        entry_id = uuid.uuid4()
        response = self.add(id=str(entry_id))
        self.assertEqual(response.data["id"], str(entry_id))
        again = self.add(id=str(entry_id))
        self.assertEqual(again.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("id", again.data["fields"])

    def test_list_is_ordered_by_meal(self):
        self.add(meal="dinner")
        self.add(meal="breakfast")
        self.add(meal="snack")
        self.add(meal="lunch")
        self.add(day=NEXT_DAY)
        response = self.client.get(reverse("diary-list"), {"date": DAY})
        self.assertEqual(
            [row["meal"] for row in response.data], ["breakfast", "lunch", "dinner", "snack"]
        )

    def test_date_is_required(self):
        for params in ({}, {"date": "23.10.2026"}):
            response = self.client.get(reverse("diary-list"), params)
            self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
            self.assertIn("date", response.data["fields"])

    def test_invalid_values(self):
        for amount in ("0", "-5", "6000"):
            response = self.add(amount=amount)
            self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST, amount)
            self.assertIn("amount_g", response.data["fields"])
        self.assertIn("meal", self.add(meal="brunch").data["fields"])

    def test_other_users_custom_food_cannot_be_used(self):
        response = self.add(food=self.foreign_food)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("food", response.data["fields"])


class UpdateDeleteTests(DiaryTestCase):
    def test_patch_amount_recalculates(self):
        entry_id = self.add(amount="50").data["id"]
        response = self.client.patch(self.detail(entry_id), {"amount_g": "100"}, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["kcal"], "372.00")

    def test_patch_cannot_change_food(self):
        entry_id = self.add().data["id"]
        response = self.client.patch(
            self.detail(entry_id), {"food": str(self.milk.pk)}, format="json"
        )
        self.assertEqual(response.data["food"], self.oats.pk)

    def test_put_not_allowed(self):
        entry_id = self.add().data["id"]
        response = self.client.put(self.detail(entry_id), {}, format="json")
        self.assertEqual(response.status_code, status.HTTP_405_METHOD_NOT_ALLOWED)

    def test_delete_is_soft(self):
        entry_id = self.add().data["id"]
        response = self.client.delete(self.detail(entry_id))
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(DiaryEntry.objects.filter(pk=entry_id).exists())
        self.assertTrue(DiaryEntry.all_objects.filter(pk=entry_id).exists())
        listed = self.client.get(reverse("diary-list"), {"date": DAY})
        self.assertEqual(listed.data, [])

    def test_other_user_gets_404(self):
        entry_id = self.add().data["id"]
        self.client.force_authenticate(self.other)
        self.assertEqual(self.client.get(self.detail(entry_id)).status_code, 404)
        patch = self.client.patch(self.detail(entry_id), {"amount_g": "1"}, format="json")
        self.assertEqual(patch.status_code, 404)
        self.assertEqual(self.client.delete(self.detail(entry_id)).status_code, 404)
        self.assertEqual(self.client.get(reverse("diary-list"), {"date": DAY}).data, [])


class SummaryTests(DiaryTestCase):
    def test_totals_per_day_and_meal_with_targets(self):
        Profile.objects.create(
            user=self.user, kcal_target=2000, protein_g=150, carbs_g=200, fat_g=67
        )
        self.add(amount="50", meal="breakfast")
        self.add(food=self.milk, amount="200", meal="breakfast")
        self.add(amount="100", meal="snack")
        deleted = self.add(amount="100", meal="dinner").data["id"]
        self.client.delete(self.detail(deleted))
        self.add(amount="100", day=NEXT_DAY)

        response = self.client.get(reverse("diary-summary"), {"date": DAY})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.data
        self.assertEqual(data["totals"]["kcal"], "686.00")  # 186 + 128 + 372
        self.assertEqual(data["meals"]["breakfast"]["kcal"], "314.00")
        self.assertEqual(data["meals"]["dinner"]["kcal"], "0.00")
        self.assertEqual(data["meals"]["snack"]["carbs"], "58.70")
        self.assertEqual(
            data["targets"], {"kcal": 2000, "protein_g": 150, "carbs_g": 200, "fat_g": 67}
        )
        self.assertEqual(data["energy_unit"], "kcal")
        self.assertEqual(data["burned_kcal"], "0.0")
        self.assertEqual(data["steps"], 0)
        self.assertTrue(data["count_activity_kcal"])

    def test_empty_day_without_profile(self):
        response = self.client.get(reverse("diary-summary"), {"date": DAY})
        self.assertEqual(response.data["totals"]["kcal"], "0.00")
        self.assertIsNone(response.data["targets"]["kcal"])
        self.assertEqual(response.data["energy_unit"], "kcal")

    def test_summary_reports_kilojoules_when_chosen(self):
        Profile.objects.update_or_create(user=self.user, defaults={"energy_unit": "kj"})
        response = self.client.get(reverse("diary-summary"), {"date": DAY})
        self.assertEqual(response.data["energy_unit"], "kj")

    def test_summary_needs_date(self):
        self.assertEqual(self.client.get(reverse("diary-summary")).status_code, 400)

    def test_other_users_entries_are_not_counted(self):
        self.add(amount="100")
        self.client.force_authenticate(self.other)
        response = self.client.get(reverse("diary-summary"), {"date": DAY})
        self.assertEqual(response.data["totals"]["kcal"], "0.00")


class CopyTests(DiaryTestCase):
    def copy(self, **body):
        return self.client.post(reverse("diary-copy"), body, format="json")

    def test_copy_whole_day(self):
        self.add(meal="breakfast")
        self.add(meal="lunch", amount="100")
        response = self.copy(from_date=DAY, to_date=NEXT_DAY)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data, {"copied": 2})
        copied = DiaryEntry.objects.filter(user=self.user, date=NEXT_DAY)
        self.assertEqual(copied.count(), 2)
        self.assertEqual({entry.kcal for entry in copied}, {Decimal("186.00"), Decimal("372.00")})

    def test_copy_one_meal(self):
        self.add(meal="breakfast")
        self.add(meal="lunch")
        self.assertEqual(
            self.copy(from_date=DAY, to_date=NEXT_DAY, meal="lunch").data, {"copied": 1}
        )
        self.assertEqual(DiaryEntry.objects.get(date=NEXT_DAY).meal, "lunch")

    def test_nothing_to_copy(self):
        self.assertEqual(self.copy(from_date=DAY, to_date=NEXT_DAY).data, {"copied": 0})

    def test_never_copies_other_users_entries(self):
        self.add()
        self.client.force_authenticate(self.other)
        self.assertEqual(self.copy(from_date=DAY, to_date=NEXT_DAY).data, {"copied": 0})

    def test_same_day_is_rejected(self):
        response = self.copy(from_date=DAY, to_date=DAY)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("to_date", response.data["fields"])
