from rest_framework import generics, permissions

from .serializers import RegisterSerializer


class RegisterView(generics.CreateAPIView):
    """Create an account and return JWT tokens (the user is logged in directly)."""

    serializer_class = RegisterSerializer
    authentication_classes: list = []
    permission_classes = [permissions.AllowAny]
    throttle_scope = "register"
