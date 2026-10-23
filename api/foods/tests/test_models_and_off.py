import gzip
import json
import tempfile
from decimal import Decimal
from io import StringIO
from pathlib import Path
from unittest import mock

import requests
from django.core.management import CommandError, call_command
from django.db import IntegrityError
from django.test import TestCase, override_settings

from foods.models import Food
from foods.off import country_codes, fetch_off_product, map_off_product, upsert_food

FIXTURE = json.loads((Path(__file__).parent / "fixtures" / "off_product.json").read_text())


class FoodModelTests(TestCase):
    def test_nutrients_for_amount(self):
        food = Food.objects.create(name="Reis", kcal=Decimal("350"), carbs=Decimal("78"))
        nutrients = food.nutrients_for(Decimal("150"))
        self.assertEqual(nutrients["kcal"], Decimal("525"))
        self.assertEqual(nutrients["carbs"], Decimal("117"))
        self.assertEqual(nutrients["fat"], Decimal("0"))

    def test_str(self):
        self.assertEqual(str(Food(name="Hafer", brand="Kölln")), "Hafer (Kölln)")
        self.assertEqual(str(Food(name="Apfel")), "Apfel")

    def test_search_vector_is_maintained_by_the_database(self):
        Food.objects.bulk_create([Food(name="Apfelmus", brand="Bio Farm")])
        food = Food.objects.get(name="Apfelmus")
        self.assertIn("apfelmus", food.search_vector)
        Food.objects.filter(pk=food.pk).update(name="Birne")
        food.refresh_from_db()
        self.assertIn("birne", food.search_vector)

    def test_shared_barcode_is_unique_but_users_may_copy_it(self):
        Food.objects.create(name="A", barcode="12345678", source=Food.Source.OFF)
        Food.objects.create(name="Mine", barcode="12345678", source=Food.Source.USER)
        with self.assertRaises(IntegrityError):
            Food.objects.create(name="B", barcode="12345678", source=Food.Source.TAMRA)


class OpenFoodFactsMappingTests(TestCase):
    def test_maps_all_fields(self):
        data = map_off_product(FIXTURE)
        self.assertEqual(data["barcode"], "4008400401621")
        self.assertEqual(data["name"], "Kernige Haferflocken")  # language-specific name wins
        self.assertEqual(data["brand"], "Kölln")
        self.assertEqual(data["countries"], "de,at")
        self.assertEqual(data["kcal"], Decimal("372.00"))
        self.assertEqual(data["protein"], Decimal("13.50"))
        self.assertEqual(data["alcohol"], Decimal("0"))  # missing → 0
        self.assertEqual(data["off_last_modified"].year, 2025)

    def test_missing_kcal_or_name_is_skipped(self):
        without_kcal = {**FIXTURE, "nutriments": {"proteins_100g": 3}}
        self.assertIsNone(map_off_product(without_kcal))
        self.assertIsNone(map_off_product({**FIXTURE, "product_name": "", "product_name_de": ""}))
        self.assertIsNone(map_off_product({**FIXTURE, "code": ""}))

    def test_absurd_values_are_skipped(self):
        broken = {**FIXTURE, "nutriments": {**FIXTURE["nutriments"], "fat_100g": 250}}
        self.assertIsNone(map_off_product(broken))
        negative = {**FIXTURE, "nutriments": {**FIXTURE["nutriments"], "energy-kcal_100g": -5}}
        self.assertIsNone(map_off_product(negative))
        text = {**FIXTURE, "nutriments": {**FIXTURE["nutriments"], "energy-kcal_100g": "n/a"}}
        self.assertIsNone(map_off_product(text))

    def test_country_codes(self):
        self.assertEqual(
            country_codes(["en:saudi-arabia", "en:united-arab-emirates", "en:egypt", "en:egypt"]),
            ["sa", "ae", "eg"],
        )
        self.assertEqual(country_codes(None), [])

    def test_upsert_updates_existing_and_restores_deleted(self):
        food = upsert_food(map_off_product(FIXTURE))
        food.soft_delete()
        again = upsert_food({**map_off_product(FIXTURE), "kcal": Decimal("370")})
        self.assertEqual(again.pk, food.pk)
        self.assertEqual(again.kcal, Decimal("370"))
        self.assertIsNone(again.deleted_at)
        self.assertEqual(Food.all_objects.count(), 1)


@override_settings(OFF_BASE_URL="https://off.test", OFF_USER_AGENT="TAMRA/test (t@example.com)")
class FetchOffProductTests(TestCase):
    def _response(self, payload):
        response = mock.Mock()
        response.json.return_value = payload
        response.raise_for_status.return_value = None
        return response

    @mock.patch("foods.off.requests.get")
    def test_found(self, get):
        get.return_value = self._response({"status": 1, "product": FIXTURE})
        self.assertEqual(fetch_off_product("4008400401621"), FIXTURE)
        url = get.call_args.args[0]
        self.assertEqual(url, "https://off.test/api/v2/product/4008400401621.json")
        self.assertEqual(
            get.call_args.kwargs["headers"]["User-Agent"], "TAMRA/test (t@example.com)"
        )
        self.assertEqual(get.call_args.kwargs["timeout"], 5)

    @mock.patch("foods.off.requests.get")
    def test_not_found(self, get):
        get.return_value = self._response({"status": 0})
        self.assertIsNone(fetch_off_product("12345678"))

    @mock.patch("foods.off.requests.get", side_effect=requests.ConnectionError("down"))
    def test_network_error(self, get):
        with self.assertLogs("foods.off", level="WARNING"):
            self.assertIsNone(fetch_off_product("12345678"))


class ImportCommandTests(TestCase):
    def _write(self, lines: list[str], gz: bool = False) -> Path:
        directory = Path(tempfile.mkdtemp())
        path = directory / ("dump.jsonl.gz" if gz else "dump.jsonl")
        content = "\n".join(lines) + "\n"
        if gz:
            with gzip.open(path, "wt", encoding="utf-8") as handle:
                handle.write(content)
        else:
            path.write_text(content, encoding="utf-8")
        return path

    def test_imports_only_wanted_countries_and_valid_products(self):
        us_only = {**FIXTURE, "code": "11111111", "countries_tags": ["en:united-states"]}
        no_kcal = {**FIXTURE, "code": "22222222", "nutriments": {}}
        path = self._write(
            [json.dumps(FIXTURE), json.dumps(no_kcal), json.dumps(us_only), "not json", ""]
        )
        out = StringIO()
        call_command("import_off_jsonl", str(path), "--countries", "de", stdout=out)
        self.assertEqual(Food.objects.count(), 1)
        self.assertIn("Imported 1 foods, skipped 3", out.getvalue())

    def test_gzip_and_limit(self):
        second = {**FIXTURE, "code": "33333333"}
        path = self._write([json.dumps(FIXTURE), json.dumps(second)], gz=True)
        call_command("import_off_jsonl", str(path), "--limit", "1", stdout=StringIO())
        self.assertEqual(Food.objects.count(), 1)

    def test_missing_file(self):
        with self.assertRaises(CommandError):
            call_command("import_off_jsonl", "/does/not/exist.jsonl")
