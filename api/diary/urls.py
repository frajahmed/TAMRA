from django.urls import path

from .views import DiaryCopyView, DiaryDetailView, DiaryListCreateView, DiarySummaryView

urlpatterns = [
    path("", DiaryListCreateView.as_view(), name="diary-list"),
    path("summary/", DiarySummaryView.as_view(), name="diary-summary"),
    path("copy/", DiaryCopyView.as_view(), name="diary-copy"),
    path("<uuid:pk>/", DiaryDetailView.as_view(), name="diary-detail"),
]
