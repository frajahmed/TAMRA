/// Pure nutrition math. No Flutter imports, fully unit-tested.
///
/// Rules:
/// - Values are stored per 100 g and in metric units / kcal.
/// - Round only for display, never before storing.
library;

/// Nutrient values per 100 g of a food.
class NutritionPer100g {
  const NutritionPer100g({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.sugar = 0,
    this.fiber = 0,
    this.salt = 0,
  });

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;
  final double fiber;
  final double salt;

  /// Nutrients for [grams] of this food: value_per_100g × grams / 100.
  NutrientAmounts forGrams(double grams) {
    if (grams < 0) {
      throw ArgumentError.value(grams, 'grams', 'must not be negative');
    }
    final factor = grams / 100;
    return NutrientAmounts(
      kcal: kcal * factor,
      protein: protein * factor,
      carbs: carbs * factor,
      fat: fat * factor,
      sugar: sugar * factor,
      fiber: fiber * factor,
      salt: salt * factor,
    );
  }
}

/// Absolute nutrient amounts (for one diary entry or a day total).
class NutrientAmounts {
  const NutrientAmounts({
    this.kcal = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.sugar = 0,
    this.fiber = 0,
    this.salt = 0,
  });

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;
  final double fiber;
  final double salt;

  NutrientAmounts operator +(NutrientAmounts other) => NutrientAmounts(
        kcal: kcal + other.kcal,
        protein: protein + other.protein,
        carbs: carbs + other.carbs,
        fat: fat + other.fat,
        sugar: sugar + other.sugar,
        fiber: fiber + other.fiber,
        salt: salt + other.salt,
      );

  static NutrientAmounts sum(Iterable<NutrientAmounts> items) =>
      items.fold(const NutrientAmounts(), (total, item) => total + item);
}

enum Sex { female, male }

enum ActivityLevel {
  sedentary(1.2),
  light(1.375),
  moderate(1.55),
  active(1.725),
  veryActive(1.9);

  const ActivityLevel(this.factor);
  final double factor;
}

enum WeightGoal { lose, maintain, gain }

/// Basal metabolic rate (kcal/day) by Mifflin-St Jeor.
double basalMetabolicRate({
  required Sex sex,
  required double weightKg,
  required double heightCm,
  required int ageYears,
}) {
  final base = 10 * weightKg + 6.25 * heightCm - 5 * ageYears;
  return sex == Sex.male ? base + 5 : base - 161;
}

/// Daily calorie target (kcal), rounded to whole kcal.
///
/// lose: −500 kcal, gain: +300 kcal. Never below a safe minimum
/// (1200 kcal female, 1500 kcal male) and never below the BMR.
int dailyCalorieTarget({
  required Sex sex,
  required double weightKg,
  required double heightCm,
  required int ageYears,
  required ActivityLevel activity,
  required WeightGoal goal,
}) {
  final bmr = basalMetabolicRate(
    sex: sex,
    weightKg: weightKg,
    heightCm: heightCm,
    ageYears: ageYears,
  );
  final maintenance = bmr * activity.factor;
  final adjusted = switch (goal) {
    WeightGoal.lose => maintenance - 500,
    WeightGoal.maintain => maintenance,
    WeightGoal.gain => maintenance + 300,
  };
  final minimum = sex == Sex.male ? 1500.0 : 1200.0;
  final floor = bmr > minimum ? bmr : minimum;
  return (adjusted < floor ? floor : adjusted).round();
}

/// Carbohydrate units used by people with diabetes.
abstract final class CarbUnits {
  /// KE (Kohlenhydrateinheit) = 10 g carbohydrates.
  static double toKE(double carbsGrams) => carbsGrams / 10;

  /// BE (Broteinheit) = 12 g carbohydrates.
  static double toBE(double carbsGrams) => carbsGrams / 12;

  /// US "carb choice" = 15 g carbohydrates.
  static double toCarbChoices(double carbsGrams) => carbsGrams / 15;
}

/// Unit conversions for display only.
abstract final class Units {
  static const double _kgPerLb = 0.45359237;
  static const double _kjPerKcal = 4.184;
  static const double _mgDlPerMmolL = 18.0;

  static double kgToLb(double kg) => kg / _kgPerLb;
  static double lbToKg(double lb) => lb * _kgPerLb;
  static double kcalToKj(double kcal) => kcal * _kjPerKcal;
  static double kjToKcal(double kj) => kj / _kjPerKcal;
  static double mgDlToMmolL(double mgDl) => mgDl / _mgDlPerMmolL;
  static double mmolLToMgDl(double mmolL) => mmolL * _mgDlPerMmolL;
}
