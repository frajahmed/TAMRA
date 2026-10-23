from django.urls import path

from .views import FoodBarcodeView, FoodDetailView, FoodListCreateView

urlpatterns = [
    path("", FoodListCreateView.as_view(), name="food-list"),
    path("barcode/<str:barcode>/", FoodBarcodeView.as_view(), name="food-barcode"),
    path("<uuid:pk>/", FoodDetailView.as_view(), name="food-detail"),
]
