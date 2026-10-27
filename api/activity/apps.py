from django.apps import AppConfig


class ActivityConfig(AppConfig):
    """Activity: workouts and daily steps, entered by hand or imported from health apps."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "activity"
