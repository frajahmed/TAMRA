from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models

from core.models import OwnedModel


class WeightLog(OwnedModel):
    """Daily weight entry. One per user and day."""

    date = models.DateField(db_index=True)
    weight_kg = models.DecimalField(
        max_digits=5,
        decimal_places=1,
        validators=[MinValueValidator(30), MaxValueValidator(300)],
    )

    class Meta:
        ordering = ["-date"]
        constraints = [
            models.UniqueConstraint(
                fields=["user", "date"],
                condition=models.Q(deleted_at__isnull=True),
                name="uniq_active_weight_per_user_day",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.user_id} {self.date} {self.weight_kg}kg"


class WaterLog(OwnedModel):
    """Water intake entry. Multiple entries per day allowed."""

    date = models.DateField(db_index=True)
    amount_ml = models.PositiveIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5000)]
    )

    class Meta:
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return f"{self.user_id} {self.date} {self.amount_ml}ml"
