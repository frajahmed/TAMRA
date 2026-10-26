from django.conf import settings
from django.db import models
from django.utils import timezone

from core.models import OwnedModel, TimeStampedModel

from .calculations import daily_calorie_target, macro_targets


class Profile(TimeStampedModel):
    """Body data, goal, calculated targets and settings of one user."""

    class Sex(models.TextChoices):
        FEMALE = "female"
        MALE = "male"

    class ActivityLevel(models.TextChoices):
        SEDENTARY = "sedentary"
        LIGHT = "light"
        MODERATE = "moderate"
        ACTIVE = "active"
        VERY_ACTIVE = "very_active"

    class Goal(models.TextChoices):
        LOSE = "lose"
        MAINTAIN = "maintain"
        GAIN = "gain"

    class WeightUnit(models.TextChoices):
        KG = "kg"
        LB = "lb"

    class EnergyUnit(models.TextChoices):
        KCAL = "kcal"
        KJ = "kj"

    class Language(models.TextChoices):
        DE = "de"
        EN = "en"
        FR = "fr"
        IT = "it"
        AR = "ar"

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="profile"
    )
    sex = models.CharField(max_length=10, choices=Sex.choices, blank=True)
    birth_year = models.PositiveSmallIntegerField(null=True, blank=True)
    height_cm = models.DecimalField(max_digits=5, decimal_places=1, null=True, blank=True)
    weight_kg = models.DecimalField(max_digits=5, decimal_places=1, null=True, blank=True)
    activity_level = models.CharField(
        max_length=20, choices=ActivityLevel.choices, default=ActivityLevel.SEDENTARY
    )
    goal = models.CharField(max_length=10, choices=Goal.choices, default=Goal.MAINTAIN)
    kcal_target = models.PositiveIntegerField(null=True, blank=True)
    protein_g = models.PositiveIntegerField(null=True, blank=True)
    carbs_g = models.PositiveIntegerField(null=True, blank=True)
    fat_g = models.PositiveIntegerField(null=True, blank=True)
    weight_unit = models.CharField(max_length=2, choices=WeightUnit.choices, default=WeightUnit.KG)
    energy_unit = models.CharField(
        max_length=4, choices=EnergyUnit.choices, default=EnergyUnit.KCAL
    )
    language = models.CharField(max_length=2, choices=Language.choices, default=Language.EN)

    def __str__(self) -> str:
        return f"Profile of {self.user_id}"

    @property
    def is_complete(self) -> bool:
        """True when all data for the calorie calculation is present."""
        return bool(self.sex and self.birth_year and self.height_cm and self.weight_kg)

    def recalculate_targets(self) -> None:
        """Fill kcal and macro targets when all body data is present."""
        if not self.is_complete:
            return
        kcal = daily_calorie_target(
            sex=self.sex,
            weight_kg=float(self.weight_kg),
            height_cm=float(self.height_cm),
            age_years=timezone.now().year - self.birth_year,
            activity_level=self.activity_level,
            goal=self.goal,
        )
        self.kcal_target = kcal
        macros = macro_targets(kcal)
        self.protein_g = macros["protein_g"]
        self.carbs_g = macros["carbs_g"]
        self.fat_g = macros["fat_g"]


class Consent(OwnedModel):
    """Proof of a user's consent (GDPR). Never deleted, only withdrawn."""

    class Type(models.TextChoices):
        HEALTH_DATA = "health_data"
        TERMS = "terms"
        PRIVACY = "privacy"
        ANALYTICS = "analytics"

    type = models.CharField(max_length=20, choices=Type.choices)
    version = models.CharField(max_length=20)
    given_at = models.DateTimeField(default=timezone.now)
    withdrawn_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-given_at"]

    def __str__(self) -> str:
        return f"{self.type} {self.version}"
