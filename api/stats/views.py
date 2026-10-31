from datetime import date

from django.utils.translation import gettext as _
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework.exceptions import ValidationError
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from activity.models import Activity
from activity.serializers import ActivitySerializer
from diary.models import DiaryEntry
from diary.views import DATE_PARAM, required_date

from .serializers import StatsDayBalanceSerializer, StatsSummarySerializer, StreakSerializer
from .services import MAX_DAYS, day_balance, summarize
from .streaks import compute_streak


def date_range(request: Request, group: str) -> tuple[date, date]:
    """Read ?from= and ?to=; both required, from <= to, at most MAX_DAYS[group] days."""
    start = required_date(request, "from")
    end = required_date(request, "to")
    if end < start:
        raise ValidationError({"to": [_("The end must not be before the start.")]})
    if (end - start).days + 1 > MAX_DAYS[group]:
        raise ValidationError(
            {"to": [_("At most %(days)s days at once.") % {"days": MAX_DAYS[group]}]}
        )
    return start, end


class StatsSummaryView(APIView):
    """Totals per day, ISO week or month with sport, budget and balance; averages and trends."""

    @extend_schema(
        parameters=[
            OpenApiParameter("from", OpenApiTypes.DATE, required=True),
            OpenApiParameter("to", OpenApiTypes.DATE, required=True),
            OpenApiParameter(
                "group",
                OpenApiTypes.STR,
                enum=list(MAX_DAYS),
                description="day (max 31 days) or week / month (max 366 days)",
            ),
        ],
        responses=StatsSummarySerializer,
    )
    def get(self, request: Request) -> Response:
        """Statistics from ?from= to ?to= (every period listed, empty ones as zeros)."""
        group = request.query_params.get("group", "day")
        if group not in MAX_DAYS:
            raise ValidationError({"group": [_("Use day, week or month.")]})
        start, end = date_range(request, group)
        return Response(StatsSummarySerializer(summarize(request.user, start, end, group)).data)


class StatsDayView(APIView):
    """Calorie balance of one day: target + sport - eaten, with the day's workouts."""

    @extend_schema(parameters=[DATE_PARAM], responses=StatsDayBalanceSerializer)
    def get(self, request: Request) -> Response:
        """Balance of ?date= including the list of workouts."""
        day = required_date(request)
        data = day_balance(request.user, day)
        activities = Activity.objects.filter(user=request.user, date=day)
        data["activities"] = ActivitySerializer(activities, many=True).data
        return Response(StatsDayBalanceSerializer(data).data)


class StatsStreakView(APIView):
    """Diary-entry streak and fixed milestones up to the user's local date."""

    @extend_schema(parameters=[DATE_PARAM], responses=StreakSerializer)
    def get(self, request: Request) -> Response:
        """Return streaks for ?date= using one query for distinct logged diary days."""
        day = required_date(request)
        logged_days = list(
            DiaryEntry.objects.filter(user=request.user, date__lte=day)
            .values_list("date", flat=True)
            .distinct()
            .order_by("date")
        )
        return Response(StreakSerializer(compute_streak(logged_days, day)).data)
