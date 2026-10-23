from django.utils import timezone
from drf_spectacular.utils import extend_schema, inline_serializer
from rest_framework import generics, serializers, status
from rest_framework.exceptions import ValidationError
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Consent, Profile
from .serializers import ConsentSerializer, ProfileSerializer


class ProfileView(generics.RetrieveUpdateAPIView):
    """The logged-in user's profile. Created on first access."""

    serializer_class = ProfileSerializer
    http_method_names = ["get", "patch", "options", "head"]

    def get_object(self) -> Profile:
        profile, _created = Profile.objects.get_or_create(user=self.request.user)
        return profile


class ConsentListCreateView(generics.ListCreateAPIView):
    serializer_class = ConsentSerializer
    pagination_class = None

    def get_queryset(self):
        return Consent.objects.filter(user=self.request.user)

    def perform_create(self, serializer: ConsentSerializer) -> None:
        serializer.save(user=self.request.user)


class ConsentWithdrawView(APIView):
    @extend_schema(
        request=None,
        responses=inline_serializer("WithdrawResult", {"withdrawn": serializers.IntegerField()}),
    )
    def post(self, request: Request, consent_type: str) -> Response:
        if consent_type not in Consent.Type.values:
            raise ValidationError({"type": [f"Unknown consent type: {consent_type}"]})
        count = Consent.objects.filter(
            user=request.user, type=consent_type, withdrawn_at__isnull=True
        ).update(withdrawn_at=timezone.now(), updated_at=timezone.now())
        return Response({"withdrawn": count}, status=status.HTTP_200_OK)
