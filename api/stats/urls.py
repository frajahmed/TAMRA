from django.urls import path

from .views import StatsSummaryView

urlpatterns = [
    path("summary/", StatsSummaryView.as_view(), name="stats-summary"),
]
