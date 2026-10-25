from django.apps import AppConfig


class DiaryConfig(AppConfig):
    """Diary: what the user ate per day and meal, with daily totals."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "diary"
