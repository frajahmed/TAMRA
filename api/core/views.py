from django.http import JsonResponse
from drf_spectacular.utils import extend_schema
from rest_framework import permissions, serializers
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView


class HealthSerializer(serializers.Serializer):
    """Answer of the health check."""

    status = serializers.CharField()


class HealthView(APIView):
    """Liveness check for load balancers and the app."""

    authentication_classes: list = []
    permission_classes = [permissions.AllowAny]

    @extend_schema(responses=HealthSerializer)
    def get(self, request: Request) -> Response:
        """Report that the API is running (used by Docker and monitoring)."""
        return Response({"status": "ok"})


def not_found(request, exception=None) -> JsonResponse:
    """JSON 404 in the uniform error format (instead of Django's HTML page)."""
    return JsonResponse({"code": "not_found", "message": "Not found.", "fields": {}}, status=404)


def server_error(request) -> JsonResponse:
    """JSON 500 in the uniform error format, without internal details."""
    return JsonResponse(
        {"code": "server_error", "message": "Internal server error.", "fields": {}}, status=500
    )
