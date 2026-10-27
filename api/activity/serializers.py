from django.utils.translation import gettext_lazy as _
from rest_framework import serializers

from .models import Activity, Source, StepDay

MAX_IMPORT_ACTIVITIES = 500
MAX_IMPORT_STEP_DAYS = 400
IMPORT_SOURCES = [choice for choice in Source.choices if choice[0] != Source.MANUAL]


class ActivitySerializer(serializers.ModelSerializer):
    """A workout; source and external id are set by the server (manual) or the import."""

    is_imported = serializers.BooleanField(read_only=True)

    class Meta:
        model = Activity
        fields = [
            "id",
            "date",
            "started_at",
            "kind",
            "title",
            "duration_min",
            "kcal",
            "distance_m",
            "source",
            "external_id",
            "is_imported",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "source", "external_id", "created_at", "updated_at"]


class ImportActivitySerializer(serializers.ModelSerializer):
    """One workout from a health app; `external_id` is the id in that app."""

    source = serializers.ChoiceField(choices=IMPORT_SOURCES)
    external_id = serializers.CharField(max_length=200)

    class Meta:
        model = Activity
        fields = [
            "date",
            "started_at",
            "kind",
            "title",
            "duration_min",
            "kcal",
            "distance_m",
            "source",
            "external_id",
        ]


class ImportStepsSerializer(serializers.ModelSerializer):
    """Steps of one day from a health app."""

    source = serializers.ChoiceField(choices=IMPORT_SOURCES)

    class Meta:
        model = StepDay
        fields = ["date", "steps", "source"]
        # The one-per-day rule is applied by the import (higher value wins), not here.
        validators = []


class ImportSerializer(serializers.Serializer):
    """Body of POST /activities/import/: workouts and daily steps from Apple Health or Health Connect."""

    activities = ImportActivitySerializer(many=True, required=False, default=list)
    steps = ImportStepsSerializer(many=True, required=False, default=list)

    def validate_activities(self, value: list) -> list:
        """At most MAX_IMPORT_ACTIVITIES per request (the app sends bigger syncs in pages)."""
        if len(value) > MAX_IMPORT_ACTIVITIES:
            raise serializers.ValidationError(
                _("At most %(count)s activities per request.") % {"count": MAX_IMPORT_ACTIVITIES}
            )
        return value

    def validate_steps(self, value: list) -> list:
        """At most MAX_IMPORT_STEP_DAYS days of steps per request."""
        if len(value) > MAX_IMPORT_STEP_DAYS:
            raise serializers.ValidationError(
                _("At most %(count)s days of steps per request.") % {"count": MAX_IMPORT_STEP_DAYS}
            )
        return value


class ImportResultSerializer(serializers.Serializer):
    """How many rows the import created, updated or skipped."""

    created = serializers.IntegerField()
    updated = serializers.IntegerField()
    skipped = serializers.IntegerField()


class ActivitySummarySerializer(serializers.Serializer):
    """Sport of one day: burned kcal, minutes and steps."""

    date = serializers.DateField()
    burned_kcal = serializers.CharField()
    minutes = serializers.IntegerField()
    steps = serializers.IntegerField()
