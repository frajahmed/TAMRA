"""Statistics over a date range, calculated in the database (one query per data type)."""

from datetime import date, timedelta
from decimal import Decimal

from django.db.models import Sum

from diary.models import DiaryEntry
from profiles.models import Profile
from tracking.models import WaterLog, WeightLog

MAX_DAYS = 31
NUTRIENTS = ("kcal", "protein", "carbs", "fat")
TWO_PLACES = Decimal("0.01")
ONE_PLACE = Decimal("0.1")


def days_between(start: date, end: date) -> list[date]:
    """Every day from start to end, both included."""
    return [start + timedelta(days=offset) for offset in range((end - start).days + 1)]


def summarize(user, start: date, end: date) -> dict:
    """Daily totals, averages over logged days, weight change and the calorie target."""
    entries = (
        DiaryEntry.objects.filter(user=user, date__range=(start, end))
        .values("date")
        .annotate(**{field: Sum(field) for field in NUTRIENTS})
    )
    nutrients_by_day = {row["date"]: row for row in entries}
    water_by_day = dict(
        WaterLog.objects.filter(user=user, date__range=(start, end))
        .values("date")
        .annotate(total=Sum("amount_ml"))
        .values_list("date", "total")
    )
    weight_by_day = dict(
        WeightLog.objects.filter(user=user, date__range=(start, end)).values_list(
            "date", "weight_kg"
        )
    )
    profile = Profile.objects.filter(user=user).first()

    days = []
    for day in days_between(start, end):
        row = nutrients_by_day.get(day, {})
        days.append(
            {
                "date": day,
                **{field: _two(row.get(field)) for field in NUTRIENTS},
                "water_ml": water_by_day.get(day) or 0,
                "weight_kg": _one(weight_by_day.get(day)),
            }
        )

    logged = [nutrients_by_day[day] for day in sorted(nutrients_by_day)]
    averages = {
        field: _two(sum((row[field] or Decimal(0)) for row in logged) / len(logged))
        if logged
        else _two(None)
        for field in NUTRIENTS
    }
    averages["logged_days"] = len(logged)

    weights = [weight_by_day[day] for day in sorted(weight_by_day)]
    change = _one(weights[-1] - weights[0]) if len(weights) >= 2 else None

    return {
        "from": start,
        "to": end,
        "kcal_target": profile.kcal_target if profile else None,
        "days": days,
        "averages": averages,
        "weight_change_kg": change,
    }


def _two(value: Decimal | None) -> str:
    """Decimal text with 2 places, like the diary totals ("0.00" for missing)."""
    return f"{(value or Decimal(0)).quantize(TWO_PLACES)}"


def _one(value: Decimal | None) -> str | None:
    """Weight text with 1 place, or None."""
    return None if value is None else f"{Decimal(value).quantize(ONE_PLACE)}"
