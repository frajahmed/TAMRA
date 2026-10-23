"""Open Food Facts: map products to Food rows and fetch single barcodes.

Data licence: Open Database License (ODbL), contents DbCL, images CC BY-SA.
The app must show "Data: Open Food Facts" where these foods are displayed.
"""

import logging
from datetime import UTC, datetime
from decimal import Decimal, InvalidOperation
from typing import Any

import requests
from django.conf import settings

from .models import Food

logger = logging.getLogger(__name__)

COUNTRY_CODES = {
    "germany": "de",
    "france": "fr",
    "italy": "it",
    "belgium": "be",
    "austria": "at",
    "switzerland": "ch",
    "united-kingdom": "gb",
    "spain": "es",
    "netherlands": "nl",
    "united-states": "us",
    "canada": "ca",
    "saudi-arabia": "sa",
    "united-arab-emirates": "ae",
    "egypt": "eg",
    "morocco": "ma",
    "tunisia": "tn",
}

NUTRIMENT_KEYS = {
    "kcal": "energy-kcal_100g",
    "protein": "proteins_100g",
    "carbs": "carbohydrates_100g",
    "sugar": "sugars_100g",
    "fat": "fat_100g",
    "saturated_fat": "saturated-fat_100g",
    "fiber": "fiber_100g",
    "salt": "salt_100g",
    "alcohol": "alcohol_100g",
}

MAX_KCAL = Decimal(1000)
MAX_GRAMS = Decimal(100)


def _decimal(value: Any) -> Decimal | None:
    if value is None or value == "":
        return None
    try:
        return Decimal(str(value)).quantize(Decimal("0.01"))
    except (InvalidOperation, ValueError):
        return None


def country_codes(tags: list[str] | None) -> list[str]:
    """`["en:germany", "en:france"]` → `["de", "fr"]` (unknown countries are skipped)."""
    codes = []
    for tag in tags or []:
        code = COUNTRY_CODES.get(tag.split(":", 1)[-1])
        if code and code not in codes:
            codes.append(code)
    return codes


def map_off_product(product: dict[str, Any]) -> dict[str, Any] | None:
    """Turn an Open Food Facts product into Food field values, or None if unusable."""
    barcode = str(product.get("code") or "").strip()
    language = str(product.get("lang") or "")[:5]
    name = (product.get(f"product_name_{language}") or product.get("product_name") or "").strip()
    nutriments = product.get("nutriments") or {}
    kcal = _decimal(nutriments.get("energy-kcal_100g"))
    if not barcode or not name or kcal is None:
        return None

    values: dict[str, Any] = {}
    for field, key in NUTRIMENT_KEYS.items():
        value = _decimal(nutriments.get(key)) or Decimal("0")
        limit = MAX_KCAL if field == "kcal" else MAX_GRAMS
        if value < 0 or value > limit:
            return None
        values[field] = value

    modified = product.get("last_modified_t")
    brands = str(product.get("brands") or "")
    return {
        "barcode": barcode[:32],
        "name": name[:255],
        "brand": brands.split(",")[0].strip()[:255],
        "language": language,
        "countries": ",".join(country_codes(product.get("countries_tags"))),
        "image_url": str(product.get("image_front_url") or "")[:500],
        "off_last_modified": datetime.fromtimestamp(int(modified), tz=UTC) if modified else None,
        **values,
    }


def upsert_food(data: dict[str, Any]) -> Food:
    """Create or update the shared Open Food Facts row for this barcode."""
    fields = {key: value for key, value in data.items() if key != "barcode"}
    food, _created = Food.all_objects.update_or_create(
        barcode=data["barcode"],
        source=Food.Source.OFF,
        defaults={**fields, "deleted_at": None},
    )
    return food


def fetch_off_product(barcode: str) -> dict[str, Any] | None:
    """Fetch one product from the Open Food Facts API; None if not found or unreachable."""
    url = f"{settings.OFF_BASE_URL}/api/v2/product/{barcode}.json"
    try:
        response = requests.get(url, headers={"User-Agent": settings.OFF_USER_AGENT}, timeout=5)
        response.raise_for_status()
        data = response.json()
    except (requests.RequestException, ValueError):
        logger.warning("Open Food Facts lookup failed")
        return None
    if data.get("status") != 1:
        return None
    product = data.get("product")
    return product if isinstance(product, dict) else None
