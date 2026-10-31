from django.urls import path

from .views import StatsDayView, StatsStreakView, StatsSummaryView

urlpatterns = [
    path("summary/", StatsSummaryView.as_view(), name="stats-summary"),
    path("day/", StatsDayView.as_view(), name="stats-day"),
    path("streak/", StatsStreakView.as_view(), name="stats-streak"),
]
