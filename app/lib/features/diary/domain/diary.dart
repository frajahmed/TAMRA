import '../../../core/ids.dart';
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

  /// The entry in the API format (used for the offline cache).
  Map<String, dynamic> toJson() => {
        'id': id,
        'date': dateKey(date),
        'meal': meal.name,
        'food': foodId,
        'food_detail': {'id': foodId, 'name': foodName, 'brand': foodBrand},
        'amount_g': amountG.toStringAsFixed(2),
        'unit_label': unitLabel,
        'kcal': nutrients.kcal.toStringAsFixed(2),
        'protein': nutrients.protein.toStringAsFixed(2),
        'carbs': nutrients.carbs.toStringAsFixed(2),
        'fat': nutrients.fat.toStringAsFixed(2),
        'sugar': nutrients.sugar.toStringAsFixed(2),
        'fiber': nutrients.fiber.toStringAsFixed(2),
        'salt': nutrients.salt.toStringAsFixed(2),
      };

  /// The same entry with another amount and/or meal; nutrients scale with the amount.
  DiaryEntry changed({double? amountG, Meal? meal}) {
    final amount = amountG ?? this.amountG;
    return DiaryEntry(
      id: id,
      date: date,
      meal: meal ?? this.meal,
      foodId: foodId,
      foodName: foodName,
      foodBrand: foodBrand,
      unitLabel: unitLabel,
      amountG: amount,
      nutrients: per100g.forGrams(amount),
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

  /// The targets in the API format (used for the offline cache).
  Map<String, dynamic> toJson() =>
      {'kcal': kcal, 'protein_g': proteinG, 'carbs_g': carbsG, 'fat_g': fatG};

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
    this.burnedKcal = 0,
    this.steps = 0,
    this.countActivityKcal = true,
    this.offline = false,
  });

  /// The day.
  final DateTime date;

  /// True when the day comes from the phone's cache because the server was not reached.
  final bool offline;

  /// All entries of the day.
  final List<DiaryEntry> entries;

  /// Targets from the profile.
  final DayTargets targets;

  /// kcal or kJ, as chosen in the profile.
  final EnergyUnit energyUnit;

  /// Active kcal of the day's workouts.
  final double burnedKcal;

  /// Steps of the day (shown only, never added).
  final int steps;

  /// Whether workouts are added to the budget (profile switch).
  final bool countActivityKcal;

  /// Sport that counts for the budget: [burnedKcal] or 0 when switched off.
  double get countedSportKcal => countActivityKcal ? burnedKcal : 0;

  /// The day's budget: target plus counted sport; null without a target.
  double? get budget {
    final target = targets.kcal;
    return target == null ? null : target + countedSportKcal;
  }

  /// Entries of one meal, in the order the server sent them.
  List<DiaryEntry> entriesOf(Meal meal) =>
      [for (final entry in entries) if (entry.meal == meal) entry];

  /// Sum of all entries of the day.
  NutrientAmounts get totals => NutrientAmounts.sum(entries.map((entry) => entry.nutrients));

  /// Sum of one meal.
  NutrientAmounts totalsOf(Meal meal) =>
      NutrientAmounts.sum(entriesOf(meal).map((entry) => entry.nutrients));

  /// The day in a stored form (offline cache): entries plus the summary fields.
  Map<String, dynamic> toJson() => {
        'date': dateKey(date),
        'entries': [for (final entry in entries) entry.toJson()],
        'targets': targets.toJson(),
        'energy_unit': energyUnit.name,
        'burned_kcal': burnedKcal,
        'steps': steps,
        'count_activity_kcal': countActivityKcal,
      };

  /// Reads the stored form; [offline] marks it as coming from the cache.
  factory DiaryDay.fromJson(Map<String, dynamic> json, {bool offline = false}) {
    final entries = json['entries'];
    return DiaryDay(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime(1970),
      entries: [
        if (entries is List)
          for (final entry in entries)
            if (entry is Map<String, dynamic>) DiaryEntry.fromJson(entry),
      ],
      targets: DayTargets.fromJson(json['targets']),
      energyUnit: EnergyUnit.fromApi(json['energy_unit']),
      burnedKcal: jsonDouble(json['burned_kcal']) ?? 0,
      steps: jsonInt(json['steps']) ?? 0,
      countActivityKcal: json['count_activity_kcal'] != false,
      offline: offline,
    );
  }

  /// The same day with other entries (e.g. after an offline change).
  DiaryDay withEntries(List<DiaryEntry> entries) => DiaryDay(
        date: date,
        entries: entries,
        targets: targets,
        energyUnit: energyUnit,
        burnedKcal: burnedKcal,
        steps: steps,
        countActivityKcal: countActivityKcal,
        offline: offline,
      );

  /// The same day without the entries in [ids] (hidden while a delete can still be undone).
  DiaryDay without(Set<String> ids) => ids.isEmpty
      ? this
      : DiaryDay(
          date: date,
          entries: [for (final entry in entries) if (!ids.contains(entry.id)) entry],
          targets: targets,
          energyUnit: energyUnit,
          burnedKcal: burnedKcal,
          steps: steps,
          countActivityKcal: countActivityKcal,
          offline: offline,
        );
}

/// A new diary entry; the server calculates the nutrients.
class NewDiaryEntry {
  /// Creates the data for POST /api/v1/diary/. [id] is made on the phone so the entry keeps
  /// it when it is saved offline and sent later; [foodName] and [per100g] let the app show
  /// the entry before the server has answered.
  NewDiaryEntry({
    required this.date,
    required this.meal,
    required this.foodId,
    required this.amountG,
    String? id,
    this.foodName = '',
    this.per100g,
  }) : id = id ?? newUuid();

  /// Entry id (UUID made on the phone).
  final String id;

  /// Name of the food (for showing the entry offline).
  final String foodName;

  /// Nutrients of the food per 100 g (for showing the entry offline).
  final NutritionPer100g? per100g;

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
        'id': id,
        'date': dateKey(date),
        'meal': meal.name,
        'food': foodId,
        'amount_g': amountG.toStringAsFixed(2),
      };

  /// The entry as the app shows it before the server answered (nutrients from [per100g]).
  DiaryEntry toLocalEntry() => DiaryEntry(
        id: id,
        date: date,
        meal: meal,
        foodId: foodId,
        foodName: foodName,
        amountG: amountG,
        nutrients: (per100g ?? const NutritionPer100g(kcal: 0, protein: 0, carbs: 0, fat: 0))
            .forGrams(amountG),
      );
}
