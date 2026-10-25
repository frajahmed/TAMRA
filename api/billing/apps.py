from django.apps import AppConfig


class BillingConfig(AppConfig):
    """Billing: free-trial abuse protection; subscriptions follow in phase 2."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "billing"
