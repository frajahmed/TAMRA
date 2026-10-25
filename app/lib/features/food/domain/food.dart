import '../../../core/nutrition/nutrition.dart';

/// Converts DRF decimals ("52.00"), ints and doubles to double.
double? _toDouble(Object? value) => switch (value) {
      final num number => number.toDouble(),
      final String text => double.tryParse(text),
      _ => null,
    };

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
        kcal: _toDouble(json['kcal']) ?? 0,
        protein: _toDouble(json['protein']) ?? 0,
        carbs: _toDouble(json['carbs']) ?? 0,
        fat: _toDouble(json['fat']) ?? 0,
        sugar: _toDouble(json['sugar']) ?? 0,
        fiber: _toDouble(json['fiber']) ?? 0,
        salt: _toDouble(json['salt']) ?? 0,
      ),
      servingSizeG: _toDouble(json['serving_size_g']),
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
