from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin
from django.contrib.auth.forms import BaseUserCreationForm, UserChangeForm
from django.utils.translation import gettext_lazy as _

from .models import User


class TamraUserCreationForm(BaseUserCreationForm):
    """Admin form for new users: email instead of a username."""

    class Meta:
        model = User
        fields = ("email",)


class TamraUserChangeForm(UserChangeForm):
    """Admin form for editing users: email instead of a username."""

    class Meta:
        model = User
        fields = "__all__"


@admin.register(User)
class UserAdmin(DjangoUserAdmin):
    """User admin for the email-based user model (no username field)."""

    form = TamraUserChangeForm
    add_form = TamraUserCreationForm
    ordering = ("email",)
    list_display = ("email", "is_active", "is_staff", "date_joined")
    search_fields = ("email",)
    fieldsets = (
        (None, {"fields": ("email", "password")}),
        (
            _("Permissions"),
            {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")},
        ),
        (_("Dates"), {"fields": ("last_login", "date_joined")}),
    )
    add_fieldsets = ((None, {"classes": ("wide",), "fields": ("email", "password1", "password2")}),)
