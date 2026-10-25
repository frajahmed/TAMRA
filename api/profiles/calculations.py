"""Calorie and macro targets.

Must give the same numbers as app/lib/core/nutrition/nutrition.dart.
"""

from decimal import ROUND_HALF_UP, Decimal

ACTIVITY_FACTORS: dict[str, float] = {
    "sedentary": 1.2,
    "light": 1.375,
    "moderate": 1.55,
    "active": 1.725,
    "very_active": 1.9,
}
GOAL_ADJUSTMENT: dict[str, float] = {"lose": -500.0, "maintain": 0.0, "gain": 300.0}
MINIMUM_KCAL: dict[str, float] = {"female": 1200.0, "male": 1500.0}


def round_half_up(value: float) -> int:
    """Round like Dart's double.round(): .5 goes away from zero."""
    return int(Decimal(str(value)).quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def basal_metabolic_rate(sex: str, weight_kg: float, height_cm: float, age_years: int) -> float:
    """Mifflin-St Jeor, kcal per day."""
    base = 10 * weight_kg + 6.25 * height_cm - 5 * age_years
    return base + 5 if sex == "male" else base - 161


def daily_calorie_target(
    sex: str,
    weight_kg: float,
    height_cm: float,
    age_years: int,
    activity_level: str,
    goal: str,
) -> int:
    """Daily calorie target: Mifflin-St Jeor x activity, adjusted for the goal, never below a safe minimum."""
    bmr = basal_metabolic_rate(sex, weight_kg, height_cm, age_years)
    adjusted = bmr * ACTIVITY_FACTORS[activity_level] + GOAL_ADJUSTMENT[goal]
    floor = max(bmr, MINIMUM_KCAL[sex])
    return round_half_up(max(adjusted, floor))


def macro_targets(kcal: int) -> dict[str, int]:
    """Protein 30 %, carbs 40 %, fat 30 % of energy (4 / 4 / 9 kcal per g)."""
    return {
        "protein_g": round_half_up(kcal * 0.30 / 4),
        "carbs_g": round_half_up(kcal * 0.40 / 4),
        "fat_g": round_half_up(kcal * 0.30 / 9),
    }
