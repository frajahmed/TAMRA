import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/core/nutrition/nutrition.dart';

void main() {
  group('NutritionPer100g.forGrams', () {
    const food = NutritionPer100g(kcal: 200, protein: 10, carbs: 30, fat: 5, sugar: 12);

    test('scales all values by grams / 100', () {
      final amounts = food.forGrams(150);
      expect(amounts.kcal, closeTo(300, 1e-9));
      expect(amounts.protein, closeTo(15, 1e-9));
      expect(amounts.carbs, closeTo(45, 1e-9));
      expect(amounts.fat, closeTo(7.5, 1e-9));
      expect(amounts.sugar, closeTo(18, 1e-9));
    });

    test('zero grams gives zero', () {
      expect(food.forGrams(0).kcal, 0);
    });

    test('negative grams are rejected', () {
      expect(() => food.forGrams(-1), throwsArgumentError);
    });
  });

  test('NutrientAmounts.sum adds all entries', () {
    final total = NutrientAmounts.sum(const [
      NutrientAmounts(kcal: 100, carbs: 10),
      NutrientAmounts(kcal: 250.5, carbs: 20, protein: 5),
    ]);
    expect(total.kcal, closeTo(350.5, 1e-9));
    expect(total.carbs, closeTo(30, 1e-9));
    expect(total.protein, closeTo(5, 1e-9));
  });

  group('basalMetabolicRate (Mifflin-St Jeor)', () {
    test('female', () {
      final bmr = basalMetabolicRate(
        sex: Sex.female,
        weightKg: 70,
        heightCm: 170,
        ageYears: 30,
      );
      expect(bmr, closeTo(1451.5, 1e-9));
    });

    test('male', () {
      final bmr = basalMetabolicRate(
        sex: Sex.male,
        weightKg: 70,
        heightCm: 170,
        ageYears: 30,
      );
      expect(bmr, closeTo(1617.5, 1e-9));
    });
  });

  group('dailyCalorieTarget', () {
    test('maintain = BMR × activity factor', () {
      final target = dailyCalorieTarget(
        sex: Sex.female,
        weightKg: 70,
        heightCm: 170,
        ageYears: 30,
        activity: ActivityLevel.sedentary,
        goal: WeightGoal.maintain,
      );
      expect(target, 1742);
    });

    test('lose = maintenance − 500', () {
      final target = dailyCalorieTarget(
        sex: Sex.male,
        weightKg: 80,
        heightCm: 180,
        ageYears: 40,
        activity: ActivityLevel.moderate,
        goal: WeightGoal.lose,
      );
      expect(target, 2182);
    });

    test('never below BMR or safe minimum', () {
      final target = dailyCalorieTarget(
        sex: Sex.female,
        weightKg: 70,
        heightCm: 170,
        ageYears: 30,
        activity: ActivityLevel.sedentary,
        goal: WeightGoal.lose,
      );
      expect(target, 1452);
    });

    test('gain = maintenance + 300', () {
      final target = dailyCalorieTarget(
        sex: Sex.female,
        weightKg: 70,
        heightCm: 170,
        ageYears: 30,
        activity: ActivityLevel.light,
        goal: WeightGoal.gain,
      );
      expect(target, 2296);
    });
  });

  test('unit conversions', () {
    expect(Units.kgToLb(1), closeTo(2.20462, 1e-5));
    expect(Units.lbToKg(Units.kgToLb(80)), closeTo(80, 1e-9));
    expect(Units.kcalToKj(100), closeTo(418.4, 1e-9));
    expect(Units.kjToKcal(418.4), closeTo(100, 1e-9));
  });
}
