"""Statistics over a date range, calculated in the database (one query per data type).

Calorie balance (see docs/ARCHITECTURE.md "Activity and calorie balance"):
budget = kcal_target + burned_kcal (only when the profile counts sport), balance = eaten - budget.
Steps are shown but never added: the activity level of the target already covers daily life.
"""

from collections.abc import Callable, Iterable
from datetime import date, timedelta
from decimal import Decimal

from django.db.models import Sum

from activity.models import Activity, StepDay
from diary.models import DiaryEntry
from profiles.models import Profile
from tracking.models import WaterLog, WeightLog

MAX_DAYS = {"day": 31, "week": 366, "month": 366}
NUTRIENTS = ("kcal", "protein", "carbs", "fat")
TWO_PLACES = Decimal("0.01")
ONE_PLACE = Decimal("0.1")
ZERO = Decimal(0)


def days_between(start: date, end: date) -> list[date]:
    """Every day from start to end, both included."""
    return [start + timedelta(days=offset) for offset in range((end - start).days + 1)]


def budget_for(target: int | None, burned: Decimal, count_activity: bool) -> Decimal | None:
    """The day's calorie budget: target plus sport (when counted); None without a target."""
    if target is None:
        return None
    return Decimal(target) + (burned if count_activity else ZERO)


def daily_values(user, start: date, end: date) -> tuple[list[dict], Profile | None]:
    """Raw values of every day in the range (Decimals, not yet formatted)."""
    span = (start, end)
    nutrients = {
        row["date"]: row
        for row in DiaryEntry.objects.filter(user=user, date__range=span)
        .values("date")
        .annotate(**{field: Sum(field) for field in NUTRIENTS})
    }
    water = _sum_by_day(WaterLog.objects.filter(user=user, date__range=span), "amount_ml")
    burned = _sum_by_day(Activity.objects.filter(user=user, date__range=span), "kcal")
    steps = dict(StepDay.objects.filter(user=user, date__range=span).values_list("date", "steps"))
    weights = dict(
        WeightLog.objects.filter(user=user, date__range=span).values_list("date", "weight_kg")
    )
    profile = Profile.objects.filter(user=user).first()
    target = profile.kcal_target if profile else None
    count_activity = profile.count_activity_kcal if profile else True

    rows = []
    for day in days_between(start, end):
        eaten = nutrients.get(day, {})
        burned_kcal = burned.get(day) or ZERO
        budget = budget_for(target, burned_kcal, count_activity)
        kcal = eaten.get("kcal") or ZERO
        rows.append(
            {
                "date": day,
                "logged": day in nutrients,
                **{field: eaten.get(field) or ZERO for field in NUTRIENTS},
                "water_ml": water.get(day) or 0,
                "weight_kg": weights.get(day),
                "burned_kcal": burned_kcal,
                "steps": steps.get(day, 0),
                "budget": budget,
                "balance": None if budget is None else kcal - budget,
            }
        )
    return rows, profile


def summarize(user, start: date, end: date, group: str = "day") -> dict:
    """Totals per day (or averages per ISO week / month), averages and the weight change."""
    rows, profile = daily_values(user, start, end)
    logged = [row for row in rows if row["logged"]]
    averages = {field: _two(_average(logged, field)) for field in NUTRIENTS}
    averages["burned_kcal"] = _two(_average(logged, "burned_kcal"))
    averages["logged_days"] = len(logged)

    weights = [row["weight_kg"] for row in rows if row["weight_kg"] is not None]
    change = _one(weights[-1] - weights[0]) if len(weights) >= 2 else None

    periods = rows if group == "day" else _group(rows, _period_key(group))
    return {
        "from": start,
        "to": end,
        "group": group,
        "kcal_target": profile.kcal_target if profile else None,
        "count_activity_kcal": profile.count_activity_kcal if profile else True,
        "days": [_format(period) for period in periods],
        "averages": averages,
        "weight_change_kg": change,
    }


def day_balance(user, day: date) -> dict:
    """Everything the diary header needs for one day: eaten, sport, budget and what is left."""
    row = daily_values(user, day, day)[0][0]
    budget = row["budget"]
    return {
        "date": day,
        "eaten_kcal": _two(row["kcal"]),
        "burned_kcal": _two(row["burned_kcal"]),
        "budget": None if budget is None else _two(budget),
        "remaining": None if budget is None else _two(budget - row["kcal"]),
        "protein": _two(row["protein"]),
        "carbs": _two(row["carbs"]),
        "fat": _two(row["fat"]),
        "steps": row["steps"],
    }


def _period_key(group: str) -> Callable[[date], date]:
    """First day of the ISO week or of the month of a day."""
    if group == "week":
        return lambda day: day - timedelta(days=day.weekday())
    return lambda day: day.replace(day=1)


def _group(rows: list[dict], key: Callable[[date], date]) -> list[dict]:
    """Merge days into periods: averages over logged days, the period's last weight."""
    periods: dict[date, list[dict]] = {}
    for row in rows:
        periods.setdefault(key(row["date"]), []).append(row)

    merged = []
    for start, days in periods.items():
        logged = [day for day in days if day["logged"]]
        weights = [day["weight_kg"] for day in days if day["weight_kg"] is not None]
        budgets = [day["budget"] for day in logged if day["budget"] is not None]
        balances = [day["balance"] for day in logged if day["balance"] is not None]
        with_steps = [day for day in days if day["steps"]]
        with_water = [day for day in days if day["water_ml"]]
        merged.append(
            {
                "date": start,
                **{field: _average(logged, field) for field in NUTRIENTS},
                "water_ml": round(_average(with_water, "water_ml")),
                "weight_kg": weights[-1] if weights else None,
                "burned_kcal": _average(logged, "burned_kcal"),
                "steps": round(_average(with_steps, "steps")),
                "budget": sum(budgets) / len(budgets) if budgets else None,
                "balance": sum(balances) / len(balances) if balances else None,
                "logged_days": len(logged),
            }
        )
    return merged


def _format(row: dict) -> dict:
    """API format: decimal text with 2 places, weight with 1 place."""
    formatted = {
        "date": row["date"],
        **{field: _two(row[field]) for field in NUTRIENTS},
        "water_ml": row["water_ml"],
        "weight_kg": _one(row["weight_kg"]),
        "burned_kcal": _two(row["burned_kcal"]),
        "steps": row["steps"],
        "budget": None if row["budget"] is None else _two(row["budget"]),
        "balance": None if row["balance"] is None else _two(row["balance"]),
    }
    if "logged_days" in row:
        formatted["logged_days"] = row["logged_days"]
    return formatted


def _sum_by_day(queryset, field: str) -> dict[date, Decimal | int]:
    return dict(queryset.values("date").annotate(total=Sum(field)).values_list("date", "total"))


def _average(rows: Iterable[dict], field: str) -> Decimal:
    values = [Decimal(row[field]) for row in rows]
    return sum(values, ZERO) / len(values) if values else ZERO


def _two(value: Decimal | None) -> str:
    """Decimal text with 2 places ("0.00" for missing)."""
    return f"{(value or ZERO).quantize(TWO_PLACES)}"


def _one(value: Decimal | None) -> str | None:
    """Weight text with 1 place, or None."""
    return None if value is None else f"{Decimal(value).quantize(ONE_PLACE)}"
