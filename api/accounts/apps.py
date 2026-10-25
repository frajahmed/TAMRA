from django.apps import AppConfig


class AccountsConfig(AppConfig):
    """Accounts: the user model, login, registration and personal data (export, delete)."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "accounts"
