import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/food.dart';

/// Foods from the TAMRA API (Open Food Facts plus the user's own foods).
class FoodRepository {
  FoodRepository(this._api);

  final ApiClient _api;

  Future<List<Food>> search(String query, {String? country}) async {
    final items = await _api.searchFoods(query, country: country);
    return [for (final item in items) Food.fromJson(item)];
  }

  /// Throws [ApiError] with statusCode 404 when the barcode is unknown.
  Future<Food> byBarcode(String barcode) async =>
      Food.fromJson(await _api.foodByBarcode(barcode));

  Future<Food> byId(String id) async => Food.fromJson(await _api.foodById(id));

  Future<Food> createCustom(CustomFoodInput input) async =>
      Food.fromJson(await _api.createFood(input.toJson()));
}

final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  return FoodRepository(ref.watch(apiClientProvider));
});
