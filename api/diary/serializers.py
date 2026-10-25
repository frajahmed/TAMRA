import uuid
from decimal import Decimal

from django.utils.translation import gettext_lazy as _
from rest_framework import serializers

from foods.models import Food
from foods.views import visible_foods

from .models import SNAPSHOT_FIELDS, DiaryEntry


class FoodSummarySerializer(serializers.ModelSerializer):
    """Short food info shown inside a diary entry."""

    class Meta:
        model = Food
        fields = ["id", "name", "brand"]


class DiaryEntrySerializer(serializers.ModelSerializer):
    """A diary entry; nutrients are calculated by the server, never sent by the app."""

    id = serializers.UUIDField(required=False)
    food = serializers.PrimaryKeyRelatedField(queryset=Food.objects.none())
    food_detail = FoodSummarySerializer(source="food", read_only=True)
    amount_g = serializers.DecimalField(
        max_digits=7, decimal_places=2, min_value=Decimal("0.01"), max_value=Decimal(5000)
    )

    class Meta:
        model = DiaryEntry
        fields = [
            "id",
            "date",
            "meal",
            "food",
            "food_detail",
            "amount_g",
            "unit_label",
            *SNAPSHOT_FIELDS,
            "created_at",
            "updated_at",
        ]
        read_only_fields = [*SNAPSHOT_FIELDS, "created_at", "updated_at"]

    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        user = getattr(request, "user", None)
        if user is not None and user.is_authenticated:
            # Only foods the user may see (shared foods and own custom foods).
            self.fields["food"].queryset = visible_foods(request.user)

    def validate_id(self, value: uuid.UUID) -> uuid.UUID:
        """The app may choose the id (offline creation), but it must not exist yet."""
        if self.instance is None and DiaryEntry.all_objects.filter(pk=value).exists():
            raise serializers.ValidationError(_("This id is already used."))
        return value

    def create(self, validated_data: dict) -> DiaryEntry:
        """Create the entry and store the nutrient snapshot for the amount."""
        entry = DiaryEntry(**validated_data)
        entry.apply_snapshot()
        entry.save()
        return entry

    def update(self, instance: DiaryEntry, validated_data: dict) -> DiaryEntry:
        """Update the entry; a new food or amount recalculates the snapshot."""
        validated_data.pop("id", None)
        validated_data.pop("food", None)  # change the food = delete and add a new entry
        for field, value in validated_data.items():
            setattr(instance, field, value)
        instance.apply_snapshot()
        instance.save()
        return instance


class DiaryCopySerializer(serializers.Serializer):
    """Body of POST /diary/copy/: copy a day or one meal to another day."""

    from_date = serializers.DateField()
    to_date = serializers.DateField()
    meal = serializers.ChoiceField(choices=DiaryEntry.Meal.choices, required=False)

    def validate(self, attrs: dict) -> dict:
        """Source and target day must differ (copying onto itself would double the entries)."""
        if attrs["from_date"] == attrs["to_date"]:
            raise serializers.ValidationError(
                {"to_date": [_("Choose a different day than the source day.")]}
            )
        return attrs
