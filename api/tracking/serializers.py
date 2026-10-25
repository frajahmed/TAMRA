from django.utils.translation import gettext as _
from rest_framework import serializers

from tracking.models import WaterLog, WeightLog


class WeightLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = WeightLog
        fields = ["id", "date", "weight_kg", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at"]

    def validate_date(self, value):
        """PATCH may not move a weight onto a day that already has one (one per day)."""
        if self.instance is not None:
            taken = (
                WeightLog.objects.filter(user=self.instance.user, date=value)
                .exclude(pk=self.instance.pk)
                .exists()
            )
            if taken:
                raise serializers.ValidationError(_("There is already a weight for this day."))
        return value


class WaterLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = WaterLog
        fields = ["id", "date", "amount_ml", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at"]


class WaterSummarySerializer(serializers.Serializer):
    date = serializers.DateField()
    total_ml = serializers.IntegerField()
