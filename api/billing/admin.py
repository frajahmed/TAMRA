from django.contrib import admin

from .models import TrialClaim


@admin.register(TrialClaim)
class TrialClaimAdmin(admin.ModelAdmin):
    """Read-only: the hashes reveal nothing; support can only remove a claim."""

    list_display = ("kind", "identity_hash", "created_at")
    list_filter = ("kind",)
    readonly_fields = ("kind", "identity_hash", "created_at")

    def has_add_permission(self, request) -> bool:
        return False
