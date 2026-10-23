import re

from django.contrib.postgres.search import SearchQuery, SearchRank
from django.db.models import Case, F, IntegerField, Q, QuerySet, Value, When
from django.shortcuts import get_object_or_404
from django.utils.translation import gettext as _
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import generics, status
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Food
from .off import fetch_off_product, map_off_product, upsert_food
from .serializers import CustomFoodSerializer, FoodSerializer

BARCODE_RE = re.compile(r"^\d{8,14}$")
COUNTRY_RE = re.compile(r"^[a-z]{2}$")
MAX_TOKENS = 6


def visible_foods(user) -> QuerySet[Food]:
    """Shared foods plus the user's own custom foods (never other users' custom foods)."""
    return Food.objects.filter(~Q(source=Food.Source.USER) | Q(created_by=user))


def search_tokens(text: str) -> list[str]:
    """Words of the query, letters and digits only (no tsquery operators can get through)."""
    return re.findall(r"[^\W_]+", text.casefold())[:MAX_TOKENS]


def build_rank_query(tokens: list[str]) -> SearchQuery:
    """Prefix full-text query used for ranking: word starts in the name rank highest."""
    query = SearchQuery(f"{tokens[0]}:*", search_type="raw", config="simple")
    for token in tokens[1:]:
        query |= SearchQuery(f"{token}:*", search_type="raw", config="simple")
    return query


def match_all_tokens(tokens: list[str]) -> Q:
    """Every word must appear somewhere in name or brand (also inside compounds)."""
    condition = Q()
    for token in tokens:
        condition &= Q(name__icontains=token) | Q(brand__icontains=token)
    return condition


class FoodListCreateView(generics.ListCreateAPIView):
    """GET: search foods by name or brand. POST: create a custom food."""

    def get_serializer_class(self):
        return CustomFoodSerializer if self.request.method == "POST" else FoodSerializer

    @extend_schema(
        parameters=[
            OpenApiParameter("q", OpenApiTypes.STR, required=True, description="min. 2 letters"),
            OpenApiParameter(
                "country", OpenApiTypes.STR, description="ISO code; these foods come first"
            ),
        ]
    )
    def get(self, request: Request, *args, **kwargs) -> Response:
        return super().get(request, *args, **kwargs)

    def get_queryset(self) -> QuerySet[Food]:
        text = self.request.query_params.get("q", "").strip()
        tokens = search_tokens(text)
        if len("".join(tokens)) < 2:
            raise ValidationError({"q": [_("Enter at least 2 letters.")]})

        country = self.request.query_params.get("country", "").strip().lower()
        if country and not COUNTRY_RE.match(country):
            raise ValidationError({"country": [_("Use a two-letter country code.")]})

        queryset = (
            visible_foods(self.request.user)
            .filter(match_all_tokens(tokens))
            .annotate(
                rank=SearchRank(F("search_vector"), build_rank_query(tokens)),
                own=Case(
                    When(created_by=self.request.user, then=Value(1)),
                    default=Value(0),
                    output_field=IntegerField(),
                ),
                in_country=Case(
                    When(countries__regex=rf"(^|,){country}(,|$)", then=Value(1)),
                    default=Value(0),
                    output_field=IntegerField(),
                )
                if country
                else Value(0, output_field=IntegerField()),
            )
        )
        return queryset.order_by("-own", "-in_country", "-rank", "name")

    def perform_create(self, serializer: CustomFoodSerializer) -> None:
        serializer.save(source=Food.Source.USER, created_by=self.request.user)


class FoodDetailView(generics.RetrieveAPIView):
    serializer_class = FoodSerializer

    def get_queryset(self) -> QuerySet[Food]:
        return visible_foods(self.request.user)


class FoodBarcodeView(APIView):
    """Find a food by barcode: own custom food, then local database, then Open Food Facts."""

    throttle_scope = "barcode"

    @extend_schema(responses=FoodSerializer)
    def get(self, request: Request, barcode: str) -> Response:
        if not BARCODE_RE.match(barcode):
            raise ValidationError({"barcode": [_("A barcode has 8 to 14 digits.")]})

        candidates = visible_foods(request.user).filter(barcode=barcode)
        food = candidates.filter(created_by=request.user).first() or candidates.first()
        if food is None:
            product = fetch_off_product(barcode)
            data = map_off_product(product) if product else None
            if data is None:
                raise NotFound(_("No food found for this barcode."))
            food = upsert_food(data)

        serializer = FoodSerializer(food, context={"request": request})
        return Response(serializer.data, status=status.HTTP_200_OK)


def get_visible_food(user, food_id) -> Food:
    """Used by other apps (e.g. the diary) to load a food the user may see."""
    return get_object_or_404(visible_foods(user), pk=food_id)
