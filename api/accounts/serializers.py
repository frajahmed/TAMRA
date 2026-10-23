from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.utils.translation import gettext_lazy as _
from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken

User = get_user_model()


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, trim_whitespace=False)
    access = serializers.CharField(read_only=True)
    refresh = serializers.CharField(read_only=True)

    class Meta:
        model = User
        fields = ["id", "email", "password", "access", "refresh"]
        read_only_fields = ["id"]
        extra_kwargs = {"email": {"validators": []}}  # uniqueness checked case-insensitively below

    def validate_email(self, value: str) -> str:
        email = value.strip().lower()
        if User.objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError(_("An account with this email already exists."))
        return email

    def validate(self, attrs: dict) -> dict:
        candidate = User(email=attrs.get("email", ""))
        try:
            validate_password(attrs["password"], user=candidate)
        except Exception as error:  # django.core.exceptions.ValidationError
            raise serializers.ValidationError({"password": list(error.messages)}) from error
        return attrs

    def create(self, validated_data: dict):
        return User.objects.create_user(
            email=validated_data["email"], password=validated_data["password"]
        )

    def to_representation(self, instance) -> dict:
        refresh = RefreshToken.for_user(instance)
        return {
            "id": str(instance.id),
            "email": instance.email,
            "access": str(refresh.access_token),
            "refresh": str(refresh),
        }
