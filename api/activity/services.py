"""Import of workouts and steps (idempotent) and daily activity totals."""

from dataclasses import dataclass
from datetime import date
from decimal import Decimal

from django.db import transaction
from django.db.models import Sum

from .models import Activity, StepDay

ONE_PLACE = Decimal("0.1")


@dataclass
class ImportResult:
    """Counts of one import."""

    created: int = 0
    updated: int = 0
    skipped: int = 0


@transaction.atomic
def import_activity_data(user, activities: list[dict], steps: list[dict]) -> ImportResult:
    """Insert or update imported workouts and steps.

    - The same `source + external_id` updates the workout instead of creating a duplicate,
      so the app can send the same data again safely.
    - A workout the user deleted stays deleted (it was removed on purpose).
    - Steps: one value per day; the higher value wins (apps count during the day).
    """
    result = ImportResult()
    for data in activities:
        existing = Activity.all_objects.filter(
            user=user, source=data["source"], external_id=data["external_id"]
        ).first()
        if existing is None:
            Activity.objects.create(user=user, **data)
            result.created += 1
        elif existing.deleted_at is not None:
            result.skipped += 1
        else:
            for field, value in data.items():
                setattr(existing, field, value)
            existing.save()
            result.updated += 1

    for data in steps:
        existing = StepDay.objects.filter(user=user, date=data["date"]).first()
        if existing is None:
            StepDay.objects.create(user=user, **data)
            result.created += 1
        elif data["steps"] > existing.steps:
            existing.steps = data["steps"]
            existing.source = data["source"]
            existing.save(update_fields=["steps", "source", "updated_at"])
            result.updated += 1
        else:
            result.skipped += 1
    return result


def day_totals(user, day: date) -> dict:
    """Burned kcal, minutes and steps of one day (zeros when nothing was logged)."""
    sums = Activity.objects.filter(user=user, date=day).aggregate(
        kcal=Sum("kcal"), minutes=Sum("duration_min")
    )
    step_day = StepDay.objects.filter(user=user, date=day).first()
    return {
        "date": day,
        "burned_kcal": f"{(sums['kcal'] or Decimal(0)).quantize(ONE_PLACE)}",
        "minutes": sums["minutes"] or 0,
        "steps": step_day.steps if step_day else 0,
    }
