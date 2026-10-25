from datetime import date

from django.db.models import QuerySet, Sum
from django.utils.translation import gettext as _
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import generics, status
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response

from core.permissions import IsOwner
from diary.views import DATE_PARAM, required_date
from tracking.models import WaterLog, WeightLog
from tracking.serializers import WaterLogSerializer, WaterSummarySerializer, WeightLogSerializer
from tracking.services import sync_profile_weight


def optional_date(request: Request, name: str) -> date | None:
    """Read an optional date parameter or answer 400 for a wrong format."""
    raw = request.query_params.get(name)
    if not raw:
        return None
    try:
        return date.fromisoformat(raw)
    except ValueError as error:
        raise ValidationError({name: [_("Use the format YYYY-MM-DD.")]}) from error


class WeightListCreateView(generics.ListCreateAPIView):
    """GET: weights (newest first), optional ?from=&to=. POST: one weight per day (update → 200)."""

    serializer_class = WeightLogSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = None

    @extend_schema(
        parameters=[
            OpenApiParameter("from", OpenApiTypes.DATE),
            OpenApiParameter("to", OpenApiTypes.DATE),
        ]
    )
    def get(self, request: Request, *args, **kwargs) -> Response:
        """The user's weights, optionally from/to a date."""
        return super().get(request, *args, **kwargs)

    def get_queryset(self) -> QuerySet[WeightLog]:
        """The user's weights in the range, newest first."""
        queryset = WeightLog.objects.filter(user=self.request.user)
        start = optional_date(self.request, "from")
        end = optional_date(self.request, "to")
        if start:
            queryset = queryset.filter(date__gte=start)
        if end:
            queryset = queryset.filter(date__lte=end)
        return queryset.order_by("-date")

    def create(self, request: Request, *args, **kwargs) -> Response:
        """Save the weight of a day; a second POST for the same day updates it (200)."""
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = request.user
        existing = WeightLog.objects.filter(
            user=user, date=serializer.validated_data["date"]
        ).first()

        if existing:
            existing.weight_kg = serializer.validated_data["weight_kg"]
            existing.save(update_fields=["weight_kg", "updated_at"])
            instance, status_code = existing, status.HTTP_200_OK
        else:
            instance, status_code = serializer.save(user=user), status.HTTP_201_CREATED

        sync_profile_weight(user)
        return Response(self.get_serializer(instance).data, status=status_code)


class WeightDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Read, change or delete one weight entry."""

    serializer_class = WeightLogSerializer
    permission_classes = [IsAuthenticated, IsOwner]

    def get_queryset(self) -> QuerySet[WeightLog]:
        """Only the user's own weights (others answer 404)."""
        return WeightLog.objects.filter(user=self.request.user)

    def perform_update(self, serializer: WeightLogSerializer) -> None:
        """Save and copy the newest weight into the profile."""
        serializer.save()
        sync_profile_weight(self.request.user)

    def perform_destroy(self, instance: WeightLog) -> None:
        """Soft delete and update the profile weight."""
        instance.soft_delete()
        sync_profile_weight(self.request.user)


class WaterListCreateView(generics.ListCreateAPIView):
    """GET: water entries of ?date= (required). POST: add a glass or bottle."""

    serializer_class = WaterLogSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = None

    @extend_schema(parameters=[DATE_PARAM])
    def get(self, request: Request, *args, **kwargs) -> Response:
        """Water entries of ?date=."""
        return super().get(request, *args, **kwargs)

    def get_queryset(self) -> QuerySet[WaterLog]:
        """The user's water entries; GET needs ?date=."""
        queryset = WaterLog.objects.filter(user=self.request.user)
        if self.request.method == "GET":
            queryset = queryset.filter(date=required_date(self.request))
        return queryset.order_by("-created_at")

    def perform_create(self, serializer: WaterLogSerializer) -> None:
        """The entry belongs to the logged-in user."""
        serializer.save(user=self.request.user)


class WaterDetailView(generics.DestroyAPIView):
    """Delete one water entry."""

    serializer_class = WaterLogSerializer
    permission_classes = [IsAuthenticated, IsOwner]

    def get_queryset(self) -> QuerySet[WaterLog]:
        """Only the user's own water entries."""
        return WaterLog.objects.filter(user=self.request.user)

    def perform_destroy(self, instance: WaterLog) -> None:
        """Soft delete."""
        instance.soft_delete()


class WaterSummaryView(generics.GenericAPIView):
    """Water total of one day."""

    serializer_class = WaterSummarySerializer
    permission_classes = [IsAuthenticated]

    @extend_schema(parameters=[DATE_PARAM])
    def get(self, request: Request) -> Response:
        """Sum of all water entries of ?date=."""
        day = required_date(request)
        total = (
            WaterLog.objects.filter(user=request.user, date=day).aggregate(total=Sum("amount_ml"))[
                "total"
            ]
            or 0
        )
        return Response(self.get_serializer({"date": day, "total_ml": total}).data)
