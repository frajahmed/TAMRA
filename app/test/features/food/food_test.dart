import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/features/food/domain/food.dart';
import 'package:tamra_app/features/food/presentation/custom_food_screen.dart';

void main() {
  test('Food.fromJson reads DRF decimal strings and missing values', () {
    final food = Food.fromJson({
      'id': 'f1',
      'name': 'Apfelsaft',
      'brand': 'Hohes C',
      'barcode': '4000417025005',
      'is_custom': false,
      'kcal': '45.00',
      'protein': '0.10',
      'carbs': 10.4,
      'fat': 0,
      'sugar': '10.20',
      'fiber': null,
      'salt': '0.01',
      'serving_size_g': '200.00',
      'serving_label': '1 Glas',
    });

    expect(food.id, 'f1');
    expect(food.name, 'Apfelsaft');
    expect(food.brand, 'Hohes C');
    expect(food.barcode, '4000417025005');
    expect(food.isCustom, isFalse);
    expect(food.per100g.kcal, 45);
    expect(food.per100g.protein, 0.1);
    expect(food.per100g.carbs, 10.4);
    expect(food.per100g.fat, 0);
    expect(food.per100g.fiber, 0);
    expect(food.servingSizeG, 200);
    expect(food.servingLabel, '1 Glas');
  });

  test('Food.fromJson handles an empty barcode, no brand and own foods', () {
    final food = Food.fromJson({
      'id': 'f2',
      'name': 'Omas Kuchen',
      'brand': '',
      'barcode': '',
      'is_custom': true,
      'kcal': '380.00',
    });
    expect(food.barcode, isNull);
    expect(food.brand, isEmpty);
    expect(food.isCustom, isTrue);
    expect(food.servingSizeG, isNull);
  });

  test('CustomFoodInput.toJson leaves out empty optional fields', () {
    const input = CustomFoodInput(name: 'Brot', kcal: 250, protein: 8);
    final json = input.toJson();
    expect(json['name'], 'Brot');
    expect(json['kcal'], 250);
    expect(json['protein'], 8);
    expect(json.containsKey('barcode'), isFalse);
    expect(json.containsKey('serving_size_g'), isFalse);
  });

  test('parseAmount accepts comma and dot, rejects text', () {
    expect(parseAmount('3,5'), 3.5);
    expect(parseAmount(' 12.25 '), 12.25);
    expect(parseAmount(''), isNull);
    expect(parseAmount(null), isNull);
    expect(parseAmount('abc'), isNull);
  });
}
