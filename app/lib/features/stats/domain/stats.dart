import '../../../core/json.dart';
import '../../../core/nutrition/nutrition.dart';

/// Totals of one day (or averages of a week / month) in the statistics.
class StatsDay {
  /// Creates the totals of [date].
  const StatsDay({
    required this.date,
    required this.nutrients,
    this.waterMl = 0,
    this.weightKg,
    this.burnedKcal = 0,
    this.steps = 0,
    this.budget,
    this.balance,
  });

  /// The day.
  final DateTime date;

  /// Eaten kcal and macros of the day.
  final NutrientAmounts nutrients;

  /// Water of the day in ml.
  final int waterMl;

  /// Weight of the day, if logged (last weight of a week / month).
  final double? weightKg;

  /// Active kcal of workouts (average per logged day for weeks / months).
  final double burnedKcal;

  /// Steps of the day (average for weeks / months).
  final int steps;

  /// Target plus counted sport; null without a target.
  final double? budget;

  /// Eaten minus budget (negative = below budget); null without a target.
  final double? balance;

  /// Reads one item of `days`.
  factory StatsDay.fromJson(Map<String, dynamic> json) => StatsDay(
        date:
            DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime(1970),
        nutrients: _nutrients(json),
        waterMl: jsonInt(json['water_ml']) ?? 0,
        weightKg: jsonDouble(json['weight_kg']),
        burnedKcal: jsonDouble(json['burned_kcal']) ?? 0,
        steps: jsonInt(json['steps']) ?? 0,
        budget: jsonDouble(json['budget']),
        balance: jsonDouble(json['balance']),
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
    this.averageBurnedKcal = 0,
  });

  /// Every day (or week / month) of the range in order, also empty ones.
  final List<StatsDay> days;

  /// Averages over the days with at least one diary entry.
  final NutrientAmounts averages;

  /// Number of days with at least one diary entry.
  final int loggedDays;

  /// Daily calorie target from the profile.
  final int? kcalTarget;

  /// Last minus first weight of the range; null with fewer than two weights.
  final double? weightChangeKg;

  /// Average sport kcal per logged day.
  final double averageBurnedKcal;

  /// Reads the API answer.
  factory StatsSummary.fromJson(Map<String, dynamic> json) {
    final days = json['days'];
    final averages = json['averages'];
    final averagesMap =
        averages is Map<String, dynamic> ? averages : const <String, dynamic>{};
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
      averageBurnedKcal: jsonDouble(averagesMap['burned_kcal']) ?? 0,
    );
  }
}

NutrientAmounts _nutrients(Map<String, dynamic> json) => NutrientAmounts(
      kcal: jsonDouble(json['kcal']) ?? 0,
      protein: jsonDouble(json['protein']) ?? 0,
      carbs: jsonDouble(json['carbs']) ?? 0,
      fat: jsonDouble(json['fat']) ?? 0,
    );

/// The ranges of the statistics screen.
enum StatsRange {
  /// The last 7 days, one bar per day.
  days7('day'),

  /// The last 4 weeks, one bar per ISO week.
  weeks4('week'),

  /// The last 12 months, one bar per month (later part of PRO).
  months12('month');

  const StatsRange(this.group);

  /// The `group` parameter of the API.
  final String group;

  /// First day of the range that ends with [today].
  DateTime start(DateTime today) => switch (this) {
        StatsRange.days7 => DateTime(today.year, today.month, today.day - 6),
        StatsRange.weeks4 => DateTime(
            today.year, today.month, today.day - (today.weekday - 1) - 21),
        StatsRange.months12 => DateTime(today.year, today.month - 11),
      };
}
