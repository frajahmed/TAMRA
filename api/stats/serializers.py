from rest_framework import serializers

from activity.serializers import ActivitySerializer


class StreakBadgeSerializer(serializers.Serializer):
    """One consecutive-day badge and the first date it was earned."""

    days = serializers.IntegerField()
    earned = serializers.BooleanField()
    earned_on = serializers.DateField(allow_null=True)


class StreakSerializer(serializers.Serializer):
    """Current and longest diary streaks for the user's local date."""

    date = serializers.DateField()
    current_days = serializers.IntegerField()
    longest_days = serializers.IntegerField()
    logged_today = serializers.BooleanField()
    badges = StreakBadgeSerializer(many=True)


class StatsDaySerializer(serializers.Serializer):
    """Totals of one day (or averages of a week / month); decimals as text."""

    date = serializers.DateField(help_text="The day, or the first day of the week / month")
    kcal = serializers.CharField()
    protein = serializers.CharField()
    carbs = serializers.CharField()
    fat = serializers.CharField()
    water_ml = serializers.IntegerField()
    weight_kg = serializers.CharField(allow_null=True)
    burned_kcal = serializers.CharField()
    steps = serializers.IntegerField()
    budget = serializers.CharField(allow_null=True)
    balance = serializers.CharField(allow_null=True, help_text="eaten - budget")
    logged_days = serializers.IntegerField(required=False, help_text="Only for week / month")


class StatsAveragesSerializer(serializers.Serializer):
    """Averages over the days that have at least one diary entry."""

    kcal = serializers.CharField()
    protein = serializers.CharField()
    carbs = serializers.CharField()
    fat = serializers.CharField()
    burned_kcal = serializers.CharField()
    logged_days = serializers.IntegerField()


class StatsSummarySerializer(serializers.Serializer):
    """Answer of GET /api/v1/stats/summary/."""

    to = serializers.DateField()
    group = serializers.CharField()
    kcal_target = serializers.IntegerField(allow_null=True)
    count_activity_kcal = serializers.BooleanField()
    days = StatsDaySerializer(many=True)
    averages = StatsAveragesSerializer()
    weight_change_kg = serializers.CharField(allow_null=True)

    def get_fields(self) -> dict:
        """Add the field `from` (a Python keyword, so it cannot be a class attribute)."""
        fields = super().get_fields()
        fields["from"] = serializers.DateField()
        return fields


class StatsDayBalanceSerializer(serializers.Serializer):
    """Answer of GET /api/v1/stats/day/: the calorie balance of one day."""

    date = serializers.DateField()
    eaten_kcal = serializers.CharField()
    burned_kcal = serializers.CharField()
    budget = serializers.CharField(allow_null=True)
    remaining = serializers.CharField(allow_null=True)
    protein = serializers.CharField()
    carbs = serializers.CharField()
    fat = serializers.CharField()
    steps = serializers.IntegerField()
    activities = ActivitySerializer(many=True)
