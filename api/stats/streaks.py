"""Pure diary-entry streak and badge calculation.

A logged day has at least one non-deleted diary entry; water, weight and sport do not count.
Days after the supplied local today are ignored. The current streak ends today when today is
logged, otherwise it may end yesterday because today is not over yet. Badges are earned by the
longest run, on the first date when a run reaches the badge length.
"""

from dataclasses import dataclass
from datetime import date, timedelta

BADGE_DAYS = (7, 30, 100)


@dataclass(frozen=True)
class StreakBadge:
    """Whether a consecutive-day milestone was earned and when it was first reached."""

    days: int
    earned: bool
    earned_on: date | None


@dataclass(frozen=True)
class StreakResult:
    """Current and longest diary streaks with the fixed badge milestones."""

    date: date
    current_days: int
    longest_days: int
    logged_today: bool
    badges: tuple[StreakBadge, ...]


def compute_streak(days: list[date], today: date) -> StreakResult:
    """Calculate streaks from distinct diary dates up to the user's local today.

    A missing today keeps a run through yesterday current. Any older gap makes the current run
    zero, while the longest run and the first date each badge was reached remain available.
    """
    ordered_days = sorted({day for day in days if day <= today})
    logged_days = set(ordered_days)
    first_badge_dates: dict[int, date] = {}
    longest_days = 0
    run_days = 0
    previous: date | None = None

    for day in ordered_days:
        run_days = (
            run_days + 1 if previous is not None and day == previous + timedelta(days=1) else 1
        )
        longest_days = max(longest_days, run_days)
        for badge_days in BADGE_DAYS:
            if run_days == badge_days and badge_days not in first_badge_dates:
                first_badge_dates[badge_days] = day
        previous = day

    logged_today = today in logged_days
    current_day = today if logged_today else today - timedelta(days=1)
    current_days = 0
    while current_day in logged_days:
        current_days += 1
        current_day -= timedelta(days=1)

    badges = tuple(
        StreakBadge(
            days=badge_days,
            earned=longest_days >= badge_days,
            earned_on=first_badge_dates.get(badge_days),
        )
        for badge_days in BADGE_DAYS
    )
    return StreakResult(
        date=today,
        current_days=current_days,
        longest_days=longest_days,
        logged_today=logged_today,
        badges=badges,
    )
