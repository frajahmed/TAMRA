from django.urls import path

from .views import (
    ActivityDetailView,
    ActivityImportView,
    ActivityListCreateView,
    ActivitySummaryView,
)

urlpatterns = [
    path("", ActivityListCreateView.as_view(), name="activity-list"),
    path("import/", ActivityImportView.as_view(), name="activity-import"),
    path("summary/", ActivitySummaryView.as_view(), name="activity-summary"),
    path("<uuid:pk>/", ActivityDetailView.as_view(), name="activity-detail"),
]
