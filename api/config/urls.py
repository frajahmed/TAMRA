from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/v1/", include("core.urls")),
    path("api/v1/auth/", include("accounts.urls")),
    path("api/v1/me/", include("profiles.urls")),
    path("api/v1/me/", include("accounts.me_urls")),
    path("api/v1/foods/", include("foods.urls")),
    path("api/v1/diary/", include("diary.urls")),
    path("api/v1/schema/", SpectacularAPIView.as_view(), name="schema"),
]

handler404 = "core.views.not_found"
handler500 = "core.views.server_error"
