from django.urls import path

from .views import ConsentListCreateView, ConsentWithdrawView, ProfileView

urlpatterns = [
    path("profile/", ProfileView.as_view(), name="me-profile"),
    path("consents/", ConsentListCreateView.as_view(), name="me-consents"),
    path(
        "consents/<str:consent_type>/withdraw/",
        ConsentWithdrawView.as_view(),
        name="me-consent-withdraw",
    ),
]
