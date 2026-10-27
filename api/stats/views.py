from datetime import date

from django.utils.translation import gettext as _
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework.exceptions import ValidationError
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from diary.views import required_date

from .serializers import StatsSummarySerializer
from .services import MAX_DAYS, summarize


def date_range(request: Request) -> tuple[date, date]:
    """Read ?from= and ?to=; both required, from <= to, at most MAX_DAYS days."""
    start = required_date(request, "from")
    end = required_date(request, "to")
    if end < start:
        raise ValidationError({"to": [_("The end must not be before the start.")]})
    if (end - start).days + 1 > MAX_DAYS:
        raise ValidationError({"to": [_("At most %(days)s days at once.") % {"days": MAX_DAYS}]})
    return start, end


class StatsSummaryView(APIView):
    """Daily totals, averages and weight change of the logged-in user over a date range."""

    @extend_schema(
        parameters=[
            OpenApiParameter("from", OpenApiTypes.DATE, required=True),
            OpenApiParameter("to", OpenApiTypes.DATE, required=True),
        ],
        responses=StatsSummarySerializer,
    )
    def get(self, request: Request) -> Response:
        """Statistics from ?from= to ?to= (every day listed, empty days as zeros)."""
        start, end = date_range(request)
        return Response(StatsSummarySerializer(summarize(request.user, start, end)).data)
