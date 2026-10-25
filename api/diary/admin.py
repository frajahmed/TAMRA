from django.contrib import admin

from .models import DiaryEntry


@admin.register(DiaryEntry)
class DiaryEntryAdmin(admin.ModelAdmin):
    """Support view only: health data, so read-only and searchable by email."""

    list_display = ("user", "date", "meal", "food", "amount_g", "kcal")
    list_filter = ("meal",)
    search_fields = ("user__email",)
    date_hierarchy = "date"
    raw_id_fields = ("user", "food")

    def has_change_permission(self, request, obj=None) -> bool:
        """Diary entries are read-only in the admin (they are the user's data)."""
        return False
