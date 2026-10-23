from django.utils import timezone
from django.utils.translation import gettext_lazy as _
from rest_framework import serializers

from .models import Consent, Profile


class ProfileSerializer(serializers.ModelSerializer):
    is_complete = serializers.BooleanField(read_only=True)
    height_cm = serializers.DecimalField(
        max_digits=5,
        decimal_places=1,
        min_value=100,
        max_value=250,
        required=False,
        allow_null=True,
    )
    weight_kg = serializers.DecimalField(
        max_digits=5, decimal_places=1, min_value=30, max_value=300, required=False, allow_null=True
    )

    class Meta:
        model = Profile
        fields = [
            "sex",
            "birth_year",
            "height_cm",
            "weight_kg",
            "activity_level",
            "goal",
            "kcal_target",
            "protein_g",
            "carbs_g",
            "fat_g",
            "weight_unit",
            "energy_unit",
            "carb_unit",
            "language",
            "is_complete",
            "updated_at",
        ]
        read_only_fields = ["kcal_target", "protein_g", "carbs_g", "fat_g", "updated_at"]

    def validate_birth_year(self, value: int | None) -> int | None:
        if value is None:
            return value
        year = timezone.now().year
        if not (year - 100 <= value <= year - 16):
            raise serializers.ValidationError(
                _("Birth year must be between %(low)s and %(high)s.")
                % {"low": year - 100, "high": year - 16}
            )
        return value

    def update(self, instance: Profile, validated_data: dict) -> Profile:
        for field, value in validated_data.items():
            setattr(instance, field, value)
        instance.recalculate_targets()
        instance.save()
        return instance


class ConsentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Consent
        fields = ["id", "type", "version", "given_at", "withdrawn_at"]
        read_only_fields = ["id", "given_at", "withdrawn_at"]
