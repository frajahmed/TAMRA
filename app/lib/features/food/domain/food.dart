import '../../../core/json.dart';
import '../../../core/nutrition/nutrition.dart';

/// A food as returned by /api/v1/foods/. Nutrients are per 100 g.
class Food {
  const Food({
    required this.id,
    required this.name,
    required this.per100g,
    this.brand = '',
    this.barcode,
    this.isCustom = false,
    this.servingSizeG,
    this.servingLabel = '',
  });

  final String id;
  final String name;
  final String brand;
  final String? barcode;
  final bool isCustom;
  final NutritionPer100g per100g;
  final double? servingSizeG;
  final String servingLabel;

  factory Food.fromJson(Map<String, dynamic> json) {
    final barcode = json['barcode'];
    return Food(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      barcode: barcode == null || barcode.toString().isEmpty ? null : barcode.toString(),
      isCustom: json['is_custom'] == true,
      per100g: NutritionPer100g(
        kcal: jsonDouble(json['kcal']) ?? 0,
        protein: jsonDouble(json['protein']) ?? 0,
        carbs: jsonDouble(json['carbs']) ?? 0,
        fat: jsonDouble(json['fat']) ?? 0,
        sugar: jsonDouble(json['sugar']) ?? 0,
        fiber: jsonDouble(json['fiber']) ?? 0,
        salt: jsonDouble(json['salt']) ?? 0,
      ),
      servingSizeG: jsonDouble(json['serving_size_g']),
      servingLabel: json['serving_label']?.toString() ?? '',
    );
  }
}

/// What the user typed into the "own food" form.
class CustomFoodInput {
  const CustomFoodInput({
    required this.name,
    required this.kcal,
    this.brand = '',
    this.barcode,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.sugar = 0,
    this.fiber = 0,
    this.salt = 0,
    this.servingSizeG,
  });

  final String name;
  final String brand;
  final String? barcode;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;
  final double fiber;
  final double salt;
  final double? servingSizeG;

  /// Body for POST /api/v1/foods/; empty optional fields are left out.
  Map<String, dynamic> toJson() => {
        'name': name,
        'brand': brand,
        if (barcode != null) 'barcode': barcode,
        'kcal': kcal,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'sugar': sugar,
        'fiber': fiber,
        'salt': salt,
        if (servingSizeG != null) 'serving_size_g': servingSizeG,
      };
}

/// Values to prefill the "own food" form (e.g. the search text or a scanned barcode).
class CustomFoodPrefill {
  const CustomFoodPrefill({this.name = '', this.barcode});

  final String name;
  final String? barcode;
}
