from decimal import Decimal

from django.db import models

from core.models import OwnedModel
from foods.models import Food

SNAPSHOT_FIELDS = ("kcal", "protein", "carbs", "sugar", "fat", "fiber", "salt")


def _snapshot() -> models.DecimalField:
    return models.DecimalField(max_digits=8, decimal_places=2, default=Decimal("0"))


class DiaryEntry(OwnedModel):
    """One food eaten in one meal on one day.

    The nutrient values are a snapshot for this amount, so later corrections of the
    food (e.g. a new Open Food Facts import) never change past days.
    """

    class Meal(models.TextChoices):
        BREAKFAST = "breakfast"
        LUNCH = "lunch"
        DINNER = "dinner"
        SNACK = "snack"

    MEAL_ORDER = (Meal.BREAKFAST, Meal.LUNCH, Meal.DINNER, Meal.SNACK)

    date = models.DateField(db_index=True, help_text="The user's local day")
    meal = models.CharField(max_length=10, choices=Meal.choices)
    food = models.ForeignKey(Food, on_delete=models.PROTECT, related_name="+")
    amount_g = models.DecimalField(max_digits=7, decimal_places=2)
    unit_label = models.CharField(max_length=50, blank=True)

    kcal = _snapshot()
    protein = _snapshot()
    carbs = _snapshot()
    sugar = _snapshot()
    fat = _snapshot()
    fiber = _snapshot()
    salt = _snapshot()

    class Meta:
        indexes = [models.Index(fields=["user", "date"], name="diary_user_date")]
        verbose_name_plural = "diary entries"

    def __str__(self) -> str:
        return f"{self.date} {self.meal}"

    def apply_snapshot(self) -> None:
        """Copy the food's nutrients for this amount into the entry (2 decimals)."""
        nutrients = self.food.nutrients_for(self.amount_g)
        for field in SNAPSHOT_FIELDS:
            setattr(self, field, nutrients[field].quantize(Decimal("0.01")))
