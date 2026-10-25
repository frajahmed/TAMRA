from django.urls import path

from .views import TrialView

urlpatterns = [
    path("trial/", TrialView.as_view(), name="me-trial"),
]
