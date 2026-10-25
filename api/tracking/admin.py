from django.contrib import admin

from tracking.models import WaterLog, WeightLog


@admin.register(WeightLog)
class WeightLogAdmin(admin.ModelAdmin):
    list_display = ("user", "date", "weight_kg", "created_at")
    list_filter = ("date",)
    search_fields = ("user__email",)


@admin.register(WaterLog)
class WaterLogAdmin(admin.ModelAdmin):
    list_display = ("user", "date", "amount_ml", "created_at")
    list_filter = ("date",)
    search_fields = ("user__email",)
