from rest_framework import serializers


class StatsDaySerializer(serializers.Serializer):
    """Totals of one day; nutrients as decimal text, weight null when not logged."""

    date = serializers.DateField()
    kcal = serializers.CharField()
    protein = serializers.CharField()
    carbs = serializers.CharField()
    fat = serializers.CharField()
    water_ml = serializers.IntegerField()
    weight_kg = serializers.CharField(allow_null=True)


class StatsAveragesSerializer(serializers.Serializer):
    """Averages over the days that have at least one diary entry."""

    kcal = serializers.CharField()
    protein = serializers.CharField()
    carbs = serializers.CharField()
    fat = serializers.CharField()
    logged_days = serializers.IntegerField()


class StatsSummarySerializer(serializers.Serializer):
    """Answer of GET /api/v1/stats/summary/."""

    to = serializers.DateField()
    kcal_target = serializers.IntegerField(allow_null=True)
    days = StatsDaySerializer(many=True)
    averages = StatsAveragesSerializer()
    weight_change_kg = serializers.CharField(allow_null=True)

    def get_fields(self) -> dict:
        """Add the field `from` (a Python keyword, so it cannot be a class attribute)."""
        fields = super().get_fields()
        fields["from"] = serializers.DateField()
        return fields
