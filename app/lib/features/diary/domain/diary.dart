import '../../../core/json.dart';
import '../../../core/nutrition/nutrition.dart';

/// The four meals of a day, in display order.
enum Meal {
  /// Breakfast.
  breakfast,

  /// Lunch.
  lunch,

  /// Dinner.
  dinner,

  /// Snacks during the day.
  snack;

  /// The meal from the API value (`breakfast`, `lunch`, `dinner`, `snack`); unknown → snack.
  static Meal fromApi(Object? value) =>
      Meal.values.firstWhere((meal) => meal.name == value, orElse: () => Meal.snack);
}

/// One food eaten in one meal on one day, as returned by /api/v1/diary/.
///
/// The nutrients are the server's snapshot for [amountG]; they never change when the
/// food is corrected later.
class DiaryEntry {
  /// Creates an entry; usually built with [DiaryEntry.fromJson].
  const DiaryEntry({
    required this.id,
    required this.date,
    required this.meal,
    required this.foodId,
    required this.foodName,
    required this.amountG,
    required this.nutrients,
    this.foodBrand = '',
    this.unitLabel = '',
  });

  /// Entry id (UUID).
  final String id;

  /// The user's local day.
  final DateTime date;

  /// Meal the entry belongs to.
  final Meal meal;

  /// Id of the food.
  final String foodId;

  /// Food name at the time of reading.
  final String foodName;

  /// Brand of the food, empty when unknown.
  final String foodBrand;

  /// Eaten amount in grams.
  final double amountG;

  /// Optional label such as "1 slice".
  final String unitLabel;

  /// Nutrients for [amountG].
  final NutrientAmounts nutrients;

  /// Nutrients per 100 g, derived from the snapshot (for the live preview when editing).
  NutritionPer100g get per100g {
    final factor = amountG > 0 ? 100 / amountG : 0.0;
    return NutritionPer100g(
      kcal: nutrients.kcal * factor,
      protein: nutrients.protein * factor,
      carbs: nutrients.carbs * factor,
      fat: nutrients.fat * factor,
      sugar: nutrients.sugar * factor,
      fiber: nutrients.fiber * factor,
      salt: nutrients.salt * factor,
    );
  }

  /// Reads one entry of GET /api/v1/diary/.
  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    final food = json['food_detail'];
    final foodMap = food is Map<String, dynamic> ? food : const <String, dynamic>{};
    return DiaryEntry(
      id: json['id'].toString(),
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime(1970),
      meal: Meal.fromApi(json['meal']),
      foodId: json['food']?.toString() ?? foodMap['id']?.toString() ?? '',
      foodName: foodMap['name']?.toString() ?? '',
      foodBrand: foodMap['brand']?.toString() ?? '',
      amountG: jsonDouble(json['amount_g']) ?? 0,
      unitLabel: json['unit_label']?.toString() ?? '',
      nutrients: NutrientAmounts(
        kcal: jsonDouble(json['kcal']) ?? 0,
        protein: jsonDouble(json['protein']) ?? 0,
        carbs: jsonDouble(json['carbs']) ?? 0,
        fat: jsonDouble(json['fat']) ?? 0,
        sugar: jsonDouble(json['sugar']) ?? 0,
        fiber: jsonDouble(json['fiber']) ?? 0,
        salt: jsonDouble(json['salt']) ?? 0,
      ),
    );
  }
}

/// Daily targets from the profile; null when the profile is not complete yet.
class DayTargets {
  /// Creates targets; all values may be null.
  const DayTargets({this.kcal, this.proteinG, this.carbsG, this.fatG});

  /// Calorie target in kcal.
  final int? kcal;

  /// Protein target in grams.
  final int? proteinG;

  /// Carbohydrate target in grams.
  final int? carbsG;

  /// Fat target in grams.
  final int? fatG;

  /// Reads `targets` of GET /api/v1/diary/summary/.
  factory DayTargets.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return const DayTargets();
    return DayTargets(
      kcal: jsonInt(json['kcal']),
      proteinG: jsonInt(json['protein_g']),
      carbsG: jsonInt(json['carbs_g']),
      fatG: jsonInt(json['fat_g']),
    );
  }
}

/// Everything the diary screen shows for one day.
class DiaryDay {
  /// Creates a day; totals are calculated from [entries].
  const DiaryDay({
    required this.date,
    required this.entries,
    this.targets = const DayTargets(),
    this.energyUnit = EnergyUnit.kcal,
  });

  /// The day.
  final DateTime date;

  /// All entries of the day.
  final List<DiaryEntry> entries;

  /// Targets from the profile.
  final DayTargets targets;

  /// kcal or kJ, as chosen in the profile.
  final EnergyUnit energyUnit;

  /// Entries of one meal, in the order the server sent them.
  List<DiaryEntry> entriesOf(Meal meal) =>
      [for (final entry in entries) if (entry.meal == meal) entry];

  /// Sum of all entries of the day.
  NutrientAmounts get totals => NutrientAmounts.sum(entries.map((entry) => entry.nutrients));

  /// Sum of one meal.
  NutrientAmounts totalsOf(Meal meal) =>
      NutrientAmounts.sum(entriesOf(meal).map((entry) => entry.nutrients));

  /// The same day without the entries in [ids] (hidden while a delete can still be undone).
  DiaryDay without(Set<String> ids) => ids.isEmpty
      ? this
      : DiaryDay(
          date: date,
          entries: [for (final entry in entries) if (!ids.contains(entry.id)) entry],
          targets: targets,
          energyUnit: energyUnit,
        );
}

/// A new diary entry; the server calculates the nutrients.
class NewDiaryEntry {
  /// Creates the data for POST /api/v1/diary/.
  const NewDiaryEntry({
    required this.date,
    required this.meal,
    required this.foodId,
    required this.amountG,
  });

  /// The day the food was eaten.
  final DateTime date;

  /// The meal.
  final Meal meal;

  /// Id of the chosen food.
  final String foodId;

  /// Amount in grams.
  final double amountG;

  /// Body for POST /api/v1/diary/.
  Map<String, dynamic> toJson() => {
        'date': dateKey(date),
        'meal': meal.name,
        'food': foodId,
        'amount_g': amountG.toStringAsFixed(2),
      };
}
