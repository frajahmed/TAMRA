import '../../../core/json.dart';
import '../../../core/nutrition/nutrition.dart';

/// Totals of one day in the statistics.
class StatsDay {
  /// Creates the totals of [date].
  const StatsDay({
    required this.date,
    required this.nutrients,
    this.waterMl = 0,
    this.weightKg,
  });

  /// The day.
  final DateTime date;

  /// Eaten kcal and macros of the day.
  final NutrientAmounts nutrients;

  /// Water of the day in ml.
  final int waterMl;

  /// Weight of the day, if logged.
  final double? weightKg;

  /// Reads one item of `days`.
  factory StatsDay.fromJson(Map<String, dynamic> json) => StatsDay(
        date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime(1970),
        nutrients: _nutrients(json),
        waterMl: jsonInt(json['water_ml']) ?? 0,
        weightKg: jsonDouble(json['weight_kg']),
      );
}

/// Statistics of a date range as returned by GET /api/v1/stats/summary/.
class StatsSummary {
  /// Creates a summary.
  const StatsSummary({
    required this.days,
    required this.averages,
    this.loggedDays = 0,
    this.kcalTarget,
    this.weightChangeKg,
  });

  /// Every day of the range in order, also days without entries.
  final List<StatsDay> days;

  /// Averages over the days with at least one diary entry.
  final NutrientAmounts averages;

  /// Number of days with at least one diary entry.
  final int loggedDays;

  /// Daily calorie target from the profile.
  final int? kcalTarget;

  /// Last minus first weight of the range; null with fewer than two weights.
  final double? weightChangeKg;

  /// Reads the API answer.
  factory StatsSummary.fromJson(Map<String, dynamic> json) {
    final days = json['days'];
    final averages = json['averages'];
    final averagesMap = averages is Map<String, dynamic> ? averages : const <String, dynamic>{};
    return StatsSummary(
      days: [
        if (days is List)
          for (final day in days)
            if (day is Map<String, dynamic>) StatsDay.fromJson(day),
      ],
      averages: _nutrients(averagesMap),
      loggedDays: jsonInt(averagesMap['logged_days']) ?? 0,
      kcalTarget: jsonInt(json['kcal_target']),
      weightChangeKg: jsonDouble(json['weight_change_kg']),
    );
  }
}

NutrientAmounts _nutrients(Map<String, dynamic> json) => NutrientAmounts(
      kcal: jsonDouble(json['kcal']) ?? 0,
      protein: jsonDouble(json['protein']) ?? 0,
      carbs: jsonDouble(json['carbs']) ?? 0,
      fat: jsonDouble(json['fat']) ?? 0,
    );
