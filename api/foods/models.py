from decimal import Decimal

from django.conf import settings
from django.contrib.postgres.indexes import GinIndex
from django.contrib.postgres.search import SearchVector, SearchVectorField
from django.db import models
from django.db.models import Q

from core.models import TimeStampedModel

NUTRIENT_FIELDS = (
    "kcal",
    "protein",
    "carbs",
    "sugar",
    "fat",
    "saturated_fat",
    "fiber",
    "salt",
    "alcohol",
)


def _nutrient() -> models.DecimalField:
    return models.DecimalField(max_digits=7, decimal_places=2, default=Decimal("0"))


class Food(TimeStampedModel):
    """A food with nutrients per 100 g (Open Food Facts, TAMRA or user-created)."""

    class Source(models.TextChoices):
        OFF = "off", "Open Food Facts"
        USER = "user", "User"
        TAMRA = "tamra", "TAMRA"

    name = models.CharField(max_length=255, db_index=True)
    brand = models.CharField(max_length=255, blank=True)
    # NULL (not "") so the unique constraint ignores foods without a barcode.
    barcode = models.CharField(max_length=32, null=True, blank=True, db_index=True)  # noqa: DJ001
    source = models.CharField(max_length=10, choices=Source.choices, default=Source.USER)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
    )
    language = models.CharField(max_length=5, blank=True)
    countries = models.CharField(
        max_length=255, blank=True, help_text="Comma-separated ISO codes, e.g. de,fr"
    )

    kcal = _nutrient()
    protein = _nutrient()
    carbs = _nutrient()
    sugar = _nutrient()
    fat = _nutrient()
    saturated_fat = _nutrient()
    fiber = _nutrient()
    salt = _nutrient()
    alcohol = _nutrient()

    serving_size_g = models.DecimalField(max_digits=7, decimal_places=2, null=True, blank=True)
    serving_label = models.CharField(max_length=100, blank=True)
    image_url = models.URLField(blank=True, max_length=500)
    off_last_modified = models.DateTimeField(null=True, blank=True)

    # Maintained by PostgreSQL itself (generated column), so bulk imports stay in sync.
    search_vector = models.GeneratedField(
        expression=SearchVector("name", weight="A", config="simple")
        + SearchVector("brand", weight="B", config="simple"),
        output_field=SearchVectorField(),
        db_persist=True,
    )

    class Meta:
        indexes = [
            GinIndex(fields=["search_vector"], name="food_search_vector_gin"),
            # Trigram indexes make substring search fast ("saft" finds "Apfelsaft").
            GinIndex(fields=["name"], opclasses=["gin_trgm_ops"], name="food_name_trgm"),
            GinIndex(fields=["brand"], opclasses=["gin_trgm_ops"], name="food_brand_trgm"),
        ]
        constraints = [
            # Shared foods have one row per barcode; users may add their own copy.
            models.UniqueConstraint(
                fields=["barcode"],
                condition=Q(barcode__isnull=False) & ~Q(source="user"),
                name="unique_shared_food_barcode",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.name} ({self.brand})" if self.brand else self.name

    def nutrients_for(self, grams: Decimal) -> dict[str, Decimal]:
        """Nutrients for an amount in grams: value per 100 g × grams / 100 (not rounded)."""
        grams = Decimal(grams)
        return {field: getattr(self, field) * grams / Decimal(100) for field in NUTRIENT_FIELDS}
