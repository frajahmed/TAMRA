from django.contrib import admin

from .models import Activity, StepDay


@admin.register(Activity)
class ActivityAdmin(admin.ModelAdmin):
    """Support view of workouts: read-only (health data of the user)."""

    list_display = ("user", "date", "kind", "duration_min", "kcal", "source")
    list_filter = ("kind", "source")
    search_fields = ("user__email",)
    raw_id_fields = ("user",)

    def has_change_permission(self, request, obj=None) -> bool:
        """Workouts belong to the user and are never changed in the admin."""
        return False


@admin.register(StepDay)
class StepDayAdmin(admin.ModelAdmin):
    """Support view of daily steps: read-only."""

    list_display = ("user", "date", "steps", "source")
    search_fields = ("user__email",)
    raw_id_fields = ("user",)

    def has_change_permission(self, request, obj=None) -> bool:
        """Steps belong to the user and are never changed in the admin."""
        return False
