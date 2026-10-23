from django.urls import path

from .views import DeleteAccountView, ExportView

urlpatterns = [
    path("", DeleteAccountView.as_view(), name="me-delete"),
    path("export/", ExportView.as_view(), name="me-export"),
]
