from decimal import Decimal

from django.utils.translation import gettext_lazy as _
from rest_framework import serializers

from .models import NUTRIENT_FIELDS, Food


class FoodSerializer(serializers.ModelSerializer):
    is_custom = serializers.SerializerMethodField()

    class Meta:
        model = Food
        fields = [
            "id",
            "name",
            "brand",
            "barcode",
            "source",
            "is_custom",
            "countries",
            *NUTRIENT_FIELDS,
            "serving_size_g",
            "serving_label",
            "image_url",
            "updated_at",
        ]
        read_only_fields = ["id", "source", "countries", "image_url", "updated_at"]

    def get_is_custom(self, food: Food) -> bool:
        request = self.context.get("request")
        return bool(request and food.created_by_id == getattr(request.user, "id", None))


class CustomFoodSerializer(FoodSerializer):
    """A food the user creates when it is missing (e.g. after a barcode scan)."""

    name = serializers.CharField(max_length=255)
    kcal = serializers.DecimalField(
        max_digits=7, decimal_places=2, min_value=Decimal(0), max_value=Decimal(900)
    )
    serving_size_g = serializers.DecimalField(
        max_digits=7,
        decimal_places=2,
        min_value=Decimal("0.1"),
        max_value=Decimal(5000),
        required=False,
        allow_null=True,
    )

    class Meta(FoodSerializer.Meta):
        extra_kwargs = {
            field: {"min_value": Decimal(0), "max_value": Decimal(100), "required": False}
            for field in NUTRIENT_FIELDS
            if field != "kcal"
        }

    def validate_barcode(self, value: str | None) -> str | None:
        if value and (not value.isdigit() or not 8 <= len(value) <= 14):
            raise serializers.ValidationError(_("A barcode has 8 to 14 digits."))
        return value or None

    def validate(self, attrs: dict) -> dict:
        grams = sum(attrs.get(field, Decimal(0)) for field in ("protein", "carbs", "fat"))
        if grams > 100:
            raise serializers.ValidationError(
                {"non_field_errors": [_("Protein, carbs and fat cannot exceed 100 g.")]}
            )
        return attrs
