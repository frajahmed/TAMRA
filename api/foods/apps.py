from django.apps import AppConfig


class FoodsConfig(AppConfig):
    """Foods: food database, search, barcode lookup and the user's own foods."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "foods"
