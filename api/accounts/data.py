"""Personal data of one user: export (GDPR Art. 15/20) and deletion (Art. 17).

Every app that stores user data must be added to EXPORTERS and to delete_account().
"""

from collections.abc import Callable
from typing import Any

from django.db import transaction
from django.utils import timezone
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken

from diary.models import DiaryEntry
from foods.models import Food
from profiles.models import Consent, Profile


def _rows(queryset, fields: list[str]) -> list[dict[str, Any]]:
    return [
        {field: _plain(value) for field, value in row.items()} for row in queryset.values(*fields)
    ]


def _plain(value: Any) -> Any:
    """JSON-friendly values (UUID, Decimal and dates as text)."""
    if value is None or isinstance(value, bool | int | float | str):
        return value
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return str(value)


def _account(user) -> dict[str, Any]:
    return {
        "id": str(user.id),
        "email": user.email,
        "date_joined": user.date_joined.isoformat(),
        "last_login": user.last_login.isoformat() if user.last_login else None,
    }


def _profile(user) -> list[dict[str, Any]]:
    fields = [
        "sex",
        "birth_year",
        "height_cm",
        "weight_kg",
        "activity_level",
        "goal",
        "kcal_target",
        "protein_g",
        "carbs_g",
        "fat_g",
        "weight_unit",
        "energy_unit",
        "carb_unit",
        "language",
        "updated_at",
    ]
    return _rows(Profile.all_objects.filter(user=user), fields)


def _consents(user) -> list[dict[str, Any]]:
    fields = ["type", "version", "given_at", "withdrawn_at"]
    return _rows(Consent.all_objects.filter(user=user).order_by("given_at"), fields)


def _custom_foods(user) -> list[dict[str, Any]]:
    fields = [
        "id",
        "name",
        "brand",
        "barcode",
        "kcal",
        "protein",
        "carbs",
        "sugar",
        "fat",
        "saturated_fat",
        "fiber",
        "salt",
        "alcohol",
        "serving_size_g",
        "serving_label",
        "created_at",
        "deleted_at",
    ]
    return _rows(Food.all_objects.filter(created_by=user, source=Food.Source.USER), fields)


def _diary(user) -> list[dict[str, Any]]:
    fields = [
        "id",
        "date",
        "meal",
        "food__name",
        "food__brand",
        "amount_g",
        "unit_label",
        "kcal",
        "protein",
        "carbs",
        "sugar",
        "fat",
        "fiber",
        "salt",
        "created_at",
        "deleted_at",
    ]
    return _rows(DiaryEntry.all_objects.filter(user=user).order_by("date", "created_at"), fields)


EXPORTERS: dict[str, Callable[[Any], Any]] = {
    "account": _account,
    "profile": _profile,
    "consents": _consents,
    "custom_foods": _custom_foods,
    "diary_entries": _diary,
}


def export_user_data(user) -> dict[str, Any]:
    """All personal data stored for this user, including soft-deleted rows."""
    return {
        "exported_at": timezone.now().isoformat(),
        "format_version": 1,
        **{name: exporter(user) for name, exporter in EXPORTERS.items()},
    }


@transaction.atomic
def delete_account(user) -> None:
    """Delete the user and every row that belongs to them, for real (no soft delete)."""
    for token in OutstandingToken.objects.filter(user=user):
        BlacklistedToken.objects.get_or_create(token=token)
    # Diary entries first: they protect the foods they point to.
    DiaryEntry.all_objects.filter(user=user).delete()
    custom_foods = Food.all_objects.filter(created_by=user, source=Food.Source.USER)
    # A custom food still used by someone else's diary is kept but no longer linked to the user.
    used_by_others = DiaryEntry.all_objects.filter(food__in=custom_foods).values("food_id")
    custom_foods.filter(pk__in=used_by_others).update(created_by=None)
    custom_foods.exclude(pk__in=used_by_others).delete()
    Consent.all_objects.filter(user=user).delete()
    Profile.all_objects.filter(user=user).delete()
    user.delete()
