from drf_spectacular.utils import extend_schema, inline_serializer
from rest_framework import serializers, status
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from .trial import check_trial, claim_trial

TrialResult = inline_serializer(
    "TrialResult",
    {"eligible": serializers.BooleanField(), "reason": serializers.CharField()},
)


class TrialRequestSerializer(serializers.Serializer):
    """Body of POST /me/trial/: the optional device id of the phone."""

    device_id = serializers.CharField(max_length=200, required=False, allow_blank=True)


class TrialView(APIView):
    """GET: may this user start a free trial? POST: start it (marks it as used).

    The app sends a stable device id (iOS identifierForVendor, Android ANDROID_ID),
    which is only stored as a keyed hash.
    """

    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "trial"

    def _device_id(self, request: Request, data) -> str | None:
        serializer = TrialRequestSerializer(data=data)
        serializer.is_valid(raise_exception=True)
        return serializer.validated_data.get("device_id") or None

    @extend_schema(responses=TrialResult)
    def get(self, request: Request) -> Response:
        """Tell the app whether the logged-in user may start a free trial."""
        result = check_trial(request.user.email, self._device_id(request, request.query_params))
        return Response({"eligible": result.eligible, "reason": result.reason})

    @extend_schema(request=TrialRequestSerializer, responses={201: TrialResult, 409: TrialResult})
    def post(self, request: Request) -> Response:
        """Start the free trial once per email and device (409 when already used)."""
        result = claim_trial(request.user.email, self._device_id(request, request.data))
        code = status.HTTP_201_CREATED if result.eligible else status.HTTP_409_CONFLICT
        return Response({"eligible": result.eligible, "reason": result.reason}, status=code)
