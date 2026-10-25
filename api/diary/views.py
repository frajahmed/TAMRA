from datetime import date
from decimal import Decimal

from django.db import transaction
from django.db.models import Case, IntegerField, QuerySet, Sum, Value, When
from django.utils.translation import gettext as _
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema, inline_serializer
from rest_framework import generics, serializers, status
from rest_framework.exceptions import ValidationError
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from profiles.models import Profile

from .models import SNAPSHOT_FIELDS, DiaryEntry
from .serializers import DiaryCopySerializer, DiaryEntrySerializer

DATE_PARAM = OpenApiParameter(
    "date", OpenApiTypes.DATE, required=True, description="The user's local day (YYYY-MM-DD)"
)


def required_date(request: Request, name: str = "date") -> date:
    """Read a required ?date=YYYY-MM-DD parameter or answer 400."""
    raw = request.query_params.get(name, "")
    try:
        return date.fromisoformat(raw)
    except ValueError as error:
        raise ValidationError({name: [_("Use the format YYYY-MM-DD.")]}) from error


def meal_order() -> Case:
    """Sort expression: breakfast, lunch, dinner, snack."""
    return Case(
        *[When(meal=meal, then=Value(index)) for index, meal in enumerate(DiaryEntry.MEAL_ORDER)],
        output_field=IntegerField(),
    )


def own_entries(user) -> QuerySet[DiaryEntry]:
    """The logged-in user's diary entries with their food (one query)."""
    return DiaryEntry.objects.filter(user=user).select_related("food")


def as_decimal_text(value: Decimal | None) -> str:
    """Decimal → string with 2 places, like DRF's DecimalField output."""
    return f"{(value or Decimal(0)).quantize(Decimal('0.01'))}"


def totals(queryset: QuerySet[DiaryEntry]) -> dict[str, str]:
    """Sum of every nutrient of the entries, as decimal text."""
    sums = queryset.aggregate(**{field: Sum(field) for field in SNAPSHOT_FIELDS})
    return {field: as_decimal_text(sums[field]) for field in SNAPSHOT_FIELDS}


class DiaryListCreateView(generics.ListCreateAPIView):
    """GET: entries of one day. POST: add an entry."""

    serializer_class = DiaryEntrySerializer
    pagination_class = None

    @extend_schema(parameters=[DATE_PARAM])
    def get(self, request: Request, *args, **kwargs) -> Response:
        """Entries of ?date=, sorted by meal."""
        return super().get(request, *args, **kwargs)

    def get_queryset(self) -> QuerySet[DiaryEntry]:
        """Only the user's entries of the requested day."""
        day = required_date(self.request)
        return own_entries(self.request.user).filter(date=day).order_by(meal_order(), "created_at")

    def perform_create(self, serializer: DiaryEntrySerializer) -> None:
        """The entry always belongs to the logged-in user."""
        serializer.save(user=self.request.user)


class DiaryDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Read, change or delete one diary entry."""

    serializer_class = DiaryEntrySerializer
    http_method_names = ["get", "patch", "delete", "options", "head"]

    def get_queryset(self) -> QuerySet[DiaryEntry]:
        """Only the user's own entries (others answer 404)."""
        return own_entries(self.request.user)

    def perform_destroy(self, instance: DiaryEntry) -> None:
        """Soft delete, so the sync can tell other devices."""
        instance.soft_delete()


class DiarySummaryView(APIView):
    """Totals of one day: overall and per meal."""

    @extend_schema(
        parameters=[DATE_PARAM],
        responses=inline_serializer(
            "DiarySummary",
            {
                "date": serializers.DateField(),
                "totals": serializers.DictField(child=serializers.CharField()),
                "meals": serializers.DictField(child=serializers.DictField()),
                "targets": serializers.DictField(allow_null=True),
            },
        ),
    )
    def get(self, request: Request) -> Response:
        """Totals of ?date= overall and per meal (meals without entries are 0) plus the targets."""
        day = required_date(request)
        entries = own_entries(request.user).filter(date=day)
        profile = Profile.objects.filter(user=request.user).first()
        return Response(
            {
                "date": day.isoformat(),
                "totals": totals(entries),
                "meals": {
                    meal: totals(entries.filter(meal=meal)) for meal in DiaryEntry.MEAL_ORDER
                },
                "targets": {
                    "kcal": profile.kcal_target if profile else None,
                    "protein_g": profile.protein_g if profile else None,
                    "carbs_g": profile.carbs_g if profile else None,
                    "fat_g": profile.fat_g if profile else None,
                },
            }
        )


class DiaryCopyView(APIView):
    """Copy all entries of a day (or one meal) to another day, with fresh nutrient values."""

    @extend_schema(
        request=DiaryCopySerializer,
        responses=inline_serializer("DiaryCopyResult", {"copied": serializers.IntegerField()}),
    )
    def post(self, request: Request) -> Response:
        """Copy all entries of a day (or one meal) to another day."""
        serializer = DiaryCopySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        source = own_entries(request.user).filter(date=data["from_date"])
        if "meal" in data:
            source = source.filter(meal=data["meal"])

        copies = []
        for entry in source.order_by(meal_order(), "created_at"):
            copy = DiaryEntry(
                user=request.user,
                date=data["to_date"],
                meal=entry.meal,
                food=entry.food,
                amount_g=entry.amount_g,
                unit_label=entry.unit_label,
            )
            copy.apply_snapshot()
            copies.append(copy)

        with transaction.atomic():
            DiaryEntry.objects.bulk_create(copies)
        return Response({"copied": len(copies)}, status=status.HTTP_201_CREATED)
