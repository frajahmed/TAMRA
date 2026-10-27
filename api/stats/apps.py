from django.apps import AppConfig


class StatsConfig(AppConfig):
    """Stats: daily totals, averages and trends over a date range (read-only, no tables)."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "stats"
