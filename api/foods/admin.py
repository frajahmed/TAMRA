from django.contrib import admin

from .models import Food


@admin.register(Food)
class FoodAdmin(admin.ModelAdmin):
    list_display = ("name", "brand", "barcode", "source", "kcal", "updated_at")
    list_filter = ("source",)
    search_fields = ("name", "brand", "barcode")
    readonly_fields = ("created_by", "created_at", "updated_at", "off_last_modified")
    exclude = ("deleted_at",)
