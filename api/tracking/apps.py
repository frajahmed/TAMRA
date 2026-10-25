from django.apps import AppConfig


class TrackingConfig(AppConfig):
    """Tracking: weight and water logs."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "tracking"
