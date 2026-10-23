from django.http import JsonResponse
from drf_spectacular.utils import extend_schema
from rest_framework import permissions, serializers
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView


class HealthSerializer(serializers.Serializer):
    status = serializers.CharField()


class HealthView(APIView):
    """Liveness check for load balancers and the app."""

    authentication_classes: list = []
    permission_classes = [permissions.AllowAny]

    @extend_schema(responses=HealthSerializer)
    def get(self, request: Request) -> Response:
        return Response({"status": "ok"})


def not_found(request, exception=None) -> JsonResponse:
    return JsonResponse({"code": "not_found", "message": "Not found.", "fields": {}}, status=404)


def server_error(request) -> JsonResponse:
    return JsonResponse(
        {"code": "server_error", "message": "Internal server error.", "fields": {}}, status=500
    )
