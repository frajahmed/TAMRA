from django.urls import path

from tracking.views import (
    WaterDetailView,
    WaterListCreateView,
    WaterSummaryView,
    WeightDetailView,
    WeightListCreateView,
)

urlpatterns = [
    path("weight/", WeightListCreateView.as_view(), name="weight-list"),
    path("weight/<uuid:pk>/", WeightDetailView.as_view(), name="weight-detail"),
    path("water/", WaterListCreateView.as_view(), name="water-list"),
    path("water/<uuid:pk>/", WaterDetailView.as_view(), name="water-detail"),
    path("water/summary/", WaterSummaryView.as_view(), name="water-summary"),
]
