import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/food.dart';

/// Foods from the TAMRA API (Open Food Facts plus the user's own foods).
class FoodRepository {
  FoodRepository(this._api);

  final ApiClient _api;

  /// Foods matching [query] (name or brand); [country] ranks local products first.
  Future<List<Food>> search(String query, {String? country}) async {
    final items = await _api.searchFoods(query, country: country);
    return [for (final item in items) Food.fromJson(item)];
  }

  /// Throws [ApiError] with statusCode 404 when the barcode is unknown.
  Future<Food> byBarcode(String barcode) async =>
      Food.fromJson(await _api.foodByBarcode(barcode));

  /// One food by its id.
  Future<Food> byId(String id) async => Food.fromJson(await _api.foodById(id));

  /// Saves an own food and returns it with its new id.
  Future<Food> createCustom(CustomFoodInput input) async =>
      Food.fromJson(await _api.createFood(input.toJson()));
}

/// The [FoodRepository] used by the food screens (replaced by a fake in tests).
final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  return FoodRepository(ref.watch(apiClientProvider));
});
