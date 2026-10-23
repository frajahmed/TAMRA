from django.contrib import admin

from .models import Consent, Profile


@admin.register(Profile)
class ProfileAdmin(admin.ModelAdmin):
    list_display = ("user", "goal", "kcal_target", "language", "updated_at")
    list_filter = ("goal", "language")
    search_fields = ("user__email",)
    readonly_fields = ("kcal_target", "protein_g", "carbs_g", "fat_g", "created_at", "updated_at")


@admin.register(Consent)
class ConsentAdmin(admin.ModelAdmin):
    list_display = ("user", "type", "version", "given_at", "withdrawn_at")
    list_filter = ("type",)
    search_fields = ("user__email",)
    readonly_fields = ("user", "type", "version", "given_at", "withdrawn_at")
