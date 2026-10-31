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

  /// Total of several amounts (e.g. all entries of a day).
  static NutrientAmounts sum(Iterable<NutrientAmounts> items) =>
      items.fold(const NutrientAmounts(), (total, item) => total + item);
}

/// Body type used by the Mifflin-St Jeor formula.
enum Sex { female, male }

/// Activity in daily life (without sport) with its PAL factor.
enum ActivityLevel {
  sedentary(1.2),
  light(1.375),
  moderate(1.55),
  active(1.725),
  veryActive(1.9);

  const ActivityLevel(this.factor);
  final double factor;
}

/// The user's goal; changes the daily calorie target.
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

/// Energy burned by a workout: MET × body weight (kg) × hours.
///
/// MET (metabolic equivalent) says how many times more energy an activity uses than
/// sitting still; e.g. running ≈ 9.8, walking ≈ 3.5. The result is a suggestion the
/// user can change.
double activityKcal(
    {required double met, required double weightKg, required int minutes}) {
  if (met < 0 || weightKg < 0 || minutes < 0) {
    throw ArgumentError('MET, weight and minutes must not be negative');
  }
  return met * weightKg * minutes / 60;
}

/// How energy is shown (stored is always kcal); the user chooses it in the profile.
enum EnergyUnit {
  /// Kilocalories (default).
  kcal,

  /// Kilojoules.
  kj;

  /// The unit from the API value `kcal` or `kj`; unknown values fall back to kcal.
  static EnergyUnit fromApi(Object? value) =>
      value == 'kj' ? EnergyUnit.kj : EnergyUnit.kcal;
}

/// How body weight is shown (stored is always kg).
enum WeightUnit {
  /// Kilograms (default).
  kg,

  /// Pounds.
  lb;

  /// The unit from the API value `kg` or `lb`; unknown values fall back to kg.
  static WeightUnit fromApi(Object? value) =>
      value == 'lb' ? WeightUnit.lb : WeightUnit.kg;

  /// [kg] converted to this unit for display.
  double fromKg(double kg) => this == WeightUnit.lb ? Units.kgToLb(kg) : kg;

  /// A value typed in this unit converted to kg for storing.
  double toKg(double value) =>
      this == WeightUnit.lb ? Units.lbToKg(value) : value;
}

/// Unit conversions for display only.
abstract final class Units {
  static const double _kgPerLb = 0.45359237;
  static const double _kjPerKcal = 4.184;

  /// Kilograms to pounds.
  static double kgToLb(double kg) => kg / _kgPerLb;

  /// Pounds to kilograms (stored value).
  static double lbToKg(double lb) => lb * _kgPerLb;

  /// Kilocalories to kilojoules (EU labels show both).
  static double kcalToKj(double kcal) => kcal * _kjPerKcal;

  /// Kilojoules to kilocalories (stored value).
  static double kjToKcal(double kj) => kj / _kjPerKcal;
}
