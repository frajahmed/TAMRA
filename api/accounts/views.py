import json

from django.http import HttpResponse
from django.utils.translation import gettext as _
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema, inline_serializer
from rest_framework import generics, permissions, serializers, status
from rest_framework.exceptions import ValidationError
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenObtainPairView

from .data import delete_account, export_user_data
from .serializers import RegisterSerializer


class RegisterView(generics.CreateAPIView):
    """Create an account and return JWT tokens (the user is logged in directly)."""

    serializer_class = RegisterSerializer
    authentication_classes: list = []
    permission_classes = [permissions.AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "register"


class LoginView(TokenObtainPairView):
    """Email + password → JWT. Limited per IP address against password guessing."""

    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "login"


class ExportView(APIView):
    """Download all personal data as a JSON file (GDPR Art. 15 and 20)."""

    throttle_scope = "export"

    @extend_schema(responses={(200, "application/json"): OpenApiTypes.OBJECT})
    def get(self, request: Request) -> HttpResponse:
        """Download all personal data as a JSON file (GDPR Art. 15 and 20)."""
        body = json.dumps(export_user_data(request.user), ensure_ascii=False, indent=2)
        response = HttpResponse(body, content_type="application/json; charset=utf-8")
        response["Content-Disposition"] = 'attachment; filename="tamra-export.json"'
        response["Cache-Control"] = "no-store"
        return response


class DeleteAccountView(APIView):
    """Delete the account and all data. The password must be entered again."""

    @extend_schema(
        request=inline_serializer("DeleteAccount", {"password": serializers.CharField()}),
        responses={204: None},
    )
    def delete(self, request: Request) -> Response:
        """Delete the account and all personal data for real after checking the password (Art. 17)."""
        password = request.data.get("password", "")
        if not password or not request.user.check_password(password):
            raise ValidationError({"password": [_("The password is not correct.")]})
        delete_account(request.user)
        return Response(status=status.HTTP_204_NO_CONTENT)
