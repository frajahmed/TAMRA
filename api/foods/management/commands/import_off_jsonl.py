"""Import an Open Food Facts JSONL dump (optionally .gz) line by line.

Example:
    python manage.py import_off_jsonl openfoodfacts-products.jsonl.gz --countries de,fr,it,be
"""

import gzip
import json
from pathlib import Path
from typing import IO

from django.core.management.base import BaseCommand, CommandError

from foods.off import country_codes, map_off_product, upsert_food


class Command(BaseCommand):
    help = "Import foods from an Open Food Facts JSONL dump."

    def add_arguments(self, parser) -> None:
        parser.add_argument("path", type=Path)
        parser.add_argument("--countries", default="de,fr,it,be", help="ISO codes, comma-separated")
        parser.add_argument("--limit", type=int, default=0, help="stop after N imported foods")

    def handle(self, *args, path: Path, countries: str, limit: int, **options) -> None:
        if not path.exists():
            raise CommandError(f"File not found: {path}")
        wanted = {code.strip().lower() for code in countries.split(",") if code.strip()}
        imported = skipped = 0

        opener = gzip.open if path.suffix == ".gz" else open
        with opener(path, "rt", encoding="utf-8") as handle:  # type: ignore[operator]
            for line in self._lines(handle):
                try:
                    product = json.loads(line)
                except json.JSONDecodeError:
                    skipped += 1
                    continue
                sold_in = set(country_codes(product.get("countries_tags")))
                data = map_off_product(product) if sold_in & wanted else None
                if data is None:
                    skipped += 1
                    continue
                upsert_food(data)
                imported += 1
                if limit and imported >= limit:
                    break

        self.stdout.write(self.style.SUCCESS(f"Imported {imported} foods, skipped {skipped}."))

    @staticmethod
    def _lines(handle: IO[str]):
        for line in handle:
            line = line.strip()
            if line:
                yield line
