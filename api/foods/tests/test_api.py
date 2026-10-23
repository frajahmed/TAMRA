import json
from decimal import Decimal
from pathlib import Path
from unittest import mock

from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.reverse import reverse
from rest_framework.test import APITestCase

from foods.models import Food

User = get_user_model()
FIXTURE = json.loads((Path(__file__).parent / "fixtures" / "off_product.json").read_text())


class FoodApiTestCase(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="a@example.com", password="x")
        self.other = User.objects.create_user(email="b@example.com", password="x")
        self.client.force_authenticate(self.user)
        self.apple = Food.objects.create(
            name="Apfel", brand="Bio Farm", source="off", barcode="40000001", countries="de"
        )
        self.apple_juice = Food.objects.create(
            name="Apfelsaft naturtrüb", brand="Hohes C", source="off", countries="de,at"
        )
        self.us_apple = Food.objects.create(
            name="Apple Pie", brand="Grandma", source="off", countries="us"
        )
        self.banana = Food.objects.create(name="Banane", brand="Chiquita", source="off")
        self.own = Food.objects.create(name="Omas Apfelkuchen", source="user", created_by=self.user)
        self.foreign = Food.objects.create(
            name="Fremder Apfelkuchen", source="user", created_by=self.other
        )

    def search(self, q: str, **params):
        return self.client.get(reverse("food-list"), {"q": q, **params})

    def names(self, response) -> list[str]:
        return [row["name"] for row in response.data["results"]]


class FoodSearchTests(FoodApiTestCase):
    def test_requires_login(self):
        self.client.force_authenticate(None)
        self.assertEqual(self.search("apfel").status_code, status.HTTP_401_UNAUTHORIZED)

    def test_prefix_match_case_insensitive(self):
        response = self.search("APF")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("Apfel", self.names(response))
        self.assertIn("Apfelsaft naturtrüb", self.names(response))
        self.assertNotIn("Banane", self.names(response))

    def test_brand_match(self):
        self.assertEqual(self.names(self.search("chiquita")), ["Banane"])

    def test_all_words_must_match(self):
        self.assertEqual(self.names(self.search("apfel saft")), ["Apfelsaft naturtrüb"])

    def test_own_custom_food_first_others_hidden(self):
        names = self.names(self.search("apfelkuchen"))
        self.assertEqual(names, ["Omas Apfelkuchen"])
        self.assertTrue(self.search("apfelkuchen").data["results"][0]["is_custom"])

    def test_compound_words_are_found(self):
        self.assertEqual(self.names(self.search("saft")), ["Apfelsaft naturtrüb"])

    def test_country_comes_first_after_own_foods(self):
        names = self.names(self.search("ap", country="us"))
        self.assertEqual(names[:2], ["Omas Apfelkuchen", "Apple Pie"])
        names_de = self.names(self.search("ap", country="de"))
        self.assertEqual(names_de[-1], "Apple Pie")

    def test_name_hit_ranks_above_brand_hit(self):
        Food.objects.create(name="Müsli", brand="Apfelhof", source="off")
        names = self.names(self.search("apfel"))
        self.assertLess(names.index("Apfel"), names.index("Müsli"))

    def test_query_too_short_or_empty(self):
        for q in ["", "a", "  ", "!!"]:
            response = self.search(q)
            self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST, q)
            self.assertIn("q", response.data["fields"])

    def test_invalid_country(self):
        response = self.search("apfel", country="germany")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_hostile_input_is_safe(self):
        for q in ["' & | ! : * ()", "'; DROP TABLE foods_food; --", "apfel:* | banane"]:
            self.assertIn(self.search(q).status_code, (200, 400), q)
        self.assertEqual(Food.objects.count(), 6)

    def test_soft_deleted_foods_are_hidden(self):
        self.apple.soft_delete()
        self.assertNotIn("Apfel", self.names(self.search("apfel")))

    def test_pagination(self):
        Food.objects.bulk_create(
            [Food(name=f"Testfood {index:02d}", source="off") for index in range(55)]
        )
        response = self.search("testfood")
        self.assertEqual(response.data["count"], 55)
        self.assertEqual(len(response.data["results"]), 50)
        self.assertIsNotNone(response.data["next"])


class CustomFoodTests(FoodApiTestCase):
    def test_create_custom_food(self):
        response = self.client.post(
            reverse("food-list"),
            {"name": "Mein Müsli", "kcal": "380", "protein": "12", "barcode": "12345670"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        food = Food.objects.get(pk=response.data["id"])
        self.assertEqual(food.source, "user")
        self.assertEqual(food.created_by, self.user)
        self.assertTrue(response.data["is_custom"])
        self.assertEqual(self.names(self.search("müsli")), ["Mein Müsli"])

        self.client.force_authenticate(self.other)
        self.assertEqual(self.names(self.search("müsli")), [])

    def test_client_cannot_set_source(self):
        response = self.client.post(
            reverse("food-list"), {"name": "X", "kcal": "10", "source": "off"}, format="json"
        )
        self.assertEqual(Food.objects.get(pk=response.data["id"]).source, "user")

    def test_validation(self):
        cases = [
            ({"name": "X"}, "kcal"),
            ({"name": "X", "kcal": "950"}, "kcal"),
            ({"name": "X", "kcal": "100", "fat": "120"}, "fat"),
            ({"name": "X", "kcal": "100", "protein": "-1"}, "protein"),
            ({"name": "X", "kcal": "100", "barcode": "12ab"}, "barcode"),
            (
                {"name": "X", "kcal": "100", "protein": "50", "carbs": "40", "fat": "20"},
                "non_field_errors",
            ),
        ]
        for body, field in cases:
            response = self.client.post(reverse("food-list"), body, format="json")
            self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST, body)
            self.assertIn(field, response.data["fields"], body)


class FoodDetailTests(FoodApiTestCase):
    def test_detail_of_shared_and_own_food(self):
        for food in (self.apple, self.own):
            response = self.client.get(reverse("food-detail", kwargs={"pk": food.pk}))
            self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_other_users_custom_food_is_404(self):
        response = self.client.get(reverse("food-detail", kwargs={"pk": self.foreign.pk}))
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)


class BarcodeTests(FoodApiTestCase):
    def lookup(self, barcode: str):
        return self.client.get(reverse("food-barcode", kwargs={"barcode": barcode}))

    @mock.patch("foods.views.fetch_off_product")
    def test_local_hit_does_not_call_off(self, fetch):
        response = self.lookup("40000001")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["name"], "Apfel")
        fetch.assert_not_called()

    @mock.patch("foods.views.fetch_off_product")
    def test_own_custom_food_wins(self, fetch):
        Food.objects.create(
            name="Mein Apfel", barcode="40000001", source="user", created_by=self.user
        )
        self.assertEqual(self.lookup("40000001").data["name"], "Mein Apfel")

    @mock.patch("foods.views.fetch_off_product", return_value=FIXTURE)
    def test_remote_hit_is_saved(self, fetch):
        response = self.lookup("4008400401621")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["kcal"], "372.00")
        self.assertEqual(response.data["source"], "off")
        self.assertTrue(Food.objects.filter(barcode="4008400401621").exists())

    @mock.patch("foods.views.fetch_off_product", return_value=None)
    def test_not_found(self, fetch):
        response = self.lookup("99999999")
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertEqual(response.data["code"], "not_found")

    @mock.patch("foods.views.fetch_off_product", return_value={**FIXTURE, "nutriments": {}})
    def test_remote_product_without_nutrients_is_404(self, fetch):
        self.assertEqual(self.lookup("4008400401621").status_code, status.HTTP_404_NOT_FOUND)

    def test_invalid_barcode(self):
        for barcode in ["123", "abcdefgh", "123456789012345"]:
            self.assertEqual(self.lookup(barcode).status_code, status.HTTP_400_BAD_REQUEST)

    def test_requires_login(self):
        self.client.force_authenticate(None)
        self.assertEqual(self.lookup("40000001").status_code, status.HTTP_401_UNAUTHORIZED)

    def test_decimal_values_in_response(self):
        self.assertEqual(Decimal(self.lookup("40000001").data["kcal"]), Decimal("0"))
