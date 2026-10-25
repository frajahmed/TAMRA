from django.apps import AppConfig


class ProfilesConfig(AppConfig):
    """Profiles: body data, calorie targets, settings and consents."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "profiles"
