from datetime import date

from django.db.models import QuerySet
from django.utils.translation import gettext as _
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import generics, status
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from core.permissions import IsOwner
from diary.views import DATE_PARAM, required_date
from tracking.views import optional_date

from .models import Activity, Source
from .serializers import (
    ActivitySerializer,
    ActivitySummarySerializer,
    ImportResultSerializer,
    ImportSerializer,
)
from .services import day_totals, import_activity_data

MAX_RANGE_DAYS = 366


def activity_range(request: Request) -> tuple[date, date] | None:
    """?date= (one day) or ?from=&to= (at most MAX_RANGE_DAYS days); None for all."""
    if "date" in request.query_params:
        day = required_date(request)
        return day, day
    start = optional_date(request, "from")
    end = optional_date(request, "to")
    if start is None and end is None:
        return None
    if start is None or end is None:
        raise ValidationError({"from" if start is None else "to": [_("This field is required.")]})
    if end < start:
        raise ValidationError({"to": [_("The end must not be before the start.")]})
    if (end - start).days + 1 > MAX_RANGE_DAYS:
        raise ValidationError(
            {"to": [_("At most %(days)s days at once.") % {"days": MAX_RANGE_DAYS}]}
        )
    return start, end


class ActivityListCreateView(generics.ListCreateAPIView):
    """GET: the user's workouts (?date= or ?from=&to=). POST: a workout entered by hand."""

    serializer_class = ActivitySerializer
    permission_classes = [IsAuthenticated]
    pagination_class = None

    @extend_schema(
        parameters=[
            OpenApiParameter("date", OpenApiTypes.DATE),
            OpenApiParameter("from", OpenApiTypes.DATE),
            OpenApiParameter("to", OpenApiTypes.DATE),
        ]
    )
    def get(self, request: Request, *args, **kwargs) -> Response:
        """Workouts of one day or a range, oldest first."""
        return super().get(request, *args, **kwargs)

    def get_queryset(self) -> QuerySet[Activity]:
        """Only the user's workouts, filtered by the requested days."""
        queryset = Activity.objects.filter(user=self.request.user)
        if self.request.method == "GET":
            days = activity_range(self.request)
            if days is not None:
                queryset = queryset.filter(date__range=days)
        return queryset

    def perform_create(self, serializer: ActivitySerializer) -> None:
        """Entries made in TAMRA are always manual."""
        serializer.save(user=self.request.user, source=Source.MANUAL, external_id="")


class ActivityDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Read, change (manual workouts only) or delete one workout."""

    serializer_class = ActivitySerializer
    permission_classes = [IsAuthenticated, IsOwner]

    def get_queryset(self) -> QuerySet[Activity]:
        """Only the user's own workouts (others answer 404)."""
        return Activity.objects.filter(user=self.request.user)

    def perform_update(self, serializer: ActivitySerializer) -> None:
        """Imported workouts come from another app and are corrected there, not here."""
        if serializer.instance.is_imported:
            raise ValidationError(
                {"source": [_("Imported activities can only be deleted, not changed.")]}
            )
        serializer.save()

    def perform_destroy(self, instance: Activity) -> None:
        """Soft delete; a deleted import is not imported again."""
        instance.soft_delete()


class ActivityImportView(APIView):
    """Import workouts and steps from Apple Health / Health Connect (safe to repeat)."""

    @extend_schema(request=ImportSerializer, responses=ImportResultSerializer)
    def post(self, request: Request) -> Response:
        """Insert or update the sent data; answers how many rows were created, updated, skipped."""
        serializer = ImportSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        result = import_activity_data(
            request.user,
            serializer.validated_data["activities"],
            serializer.validated_data["steps"],
        )
        return Response(ImportResultSerializer(result).data, status=status.HTTP_200_OK)


class ActivitySummaryView(APIView):
    """Burned kcal, sport minutes and steps of one day."""

    @extend_schema(parameters=[DATE_PARAM], responses=ActivitySummarySerializer)
    def get(self, request: Request) -> Response:
        """Totals of ?date=."""
        totals = day_totals(request.user, required_date(request))
        return Response(ActivitySummarySerializer(totals).data)
