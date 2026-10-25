from django.apps import AppConfig


class CoreConfig(AppConfig):
    """Core: base models, permissions, error format and health check shared by all apps."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "core"
