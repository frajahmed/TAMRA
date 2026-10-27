from decimal import Decimal

from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.db.models import Q

from core.models import OwnedModel


class Source(models.TextChoices):
    """Where an activity or a step count comes from."""

    MANUAL = "manual"
    APPLE_HEALTH = "apple_health"
    HEALTH_CONNECT = "health_connect"
    STRAVA = "strava"
    GARMIN = "garmin"
    FITBIT = "fitbit"
    POLAR = "polar"


class Activity(OwnedModel):
    """One workout. Imported workouts are identified by source + external_id (no duplicates)."""

    class Kind(models.TextChoices):
        """Type of sport; decides the icon and the MET value for manual entries."""

        WALKING = "walking"
        RUNNING = "running"
        CYCLING = "cycling"
        SWIMMING = "swimming"
        STRENGTH = "strength"
        YOGA = "yoga"
        HIIT = "hiit"
        TEAM_SPORT = "team_sport"
        HIKING = "hiking"
        DANCING = "dancing"
        OTHER = "other"

    date = models.DateField(db_index=True, help_text="The user's local day of the start")
    started_at = models.DateTimeField(null=True, blank=True)
    kind = models.CharField(max_length=20, choices=Kind.choices, default=Kind.OTHER)
    title = models.CharField(max_length=100, blank=True)
    duration_min = models.PositiveIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(1440)]
    )
    kcal = models.DecimalField(
        max_digits=7,
        decimal_places=1,
        validators=[MinValueValidator(Decimal(0)), MaxValueValidator(Decimal(10000))],
        help_text="Active energy burned by the workout",
    )
    distance_m = models.PositiveIntegerField(null=True, blank=True)
    source = models.CharField(max_length=20, choices=Source.choices, default=Source.MANUAL)
    external_id = models.CharField(max_length=200, blank=True)

    class Meta:
        ordering = ["date", "started_at", "created_at"]
        indexes = [models.Index(fields=["user", "date"], name="activity_user_date")]
        constraints = [
            models.UniqueConstraint(
                fields=["user", "source", "external_id"],
                condition=~Q(external_id="") & Q(deleted_at__isnull=True),
                name="uniq_active_import_per_source",
            ),
        ]
        verbose_name_plural = "activities"

    def __str__(self) -> str:
        return f"{self.date} {self.kind} {self.duration_min} min"

    @property
    def is_imported(self) -> bool:
        """True for workouts that came from another app (they can only be deleted)."""
        return self.source != Source.MANUAL


class StepDay(OwnedModel):
    """Steps of one day (one value per day; imports keep the higher value)."""

    date = models.DateField(db_index=True)
    steps = models.PositiveIntegerField(validators=[MaxValueValidator(200_000)])
    source = models.CharField(max_length=20, choices=Source.choices, default=Source.MANUAL)

    class Meta:
        ordering = ["date"]
        constraints = [
            models.UniqueConstraint(
                fields=["user", "date"],
                condition=Q(deleted_at__isnull=True),
                name="uniq_active_steps_per_day",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.date} {self.steps} steps"
