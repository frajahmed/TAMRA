import '../../../core/json.dart';

/// Daily water goal in ml (shown as 8 glasses of 250 ml).
const waterGoalMl = 2000;

/// One glass of water in ml.
const glassMl = 250;

/// The weight of one day.
class WeightLog {
  /// Creates a weight entry.
  const WeightLog(
      {required this.id, required this.date, required this.weightKg});

  /// Entry id (UUID).
  final String id;

  /// The day of the weighing.
  final DateTime date;

  /// Weight in kg.
  final double weightKg;

  /// Reads one entry of GET /api/v1/weight/.
  factory WeightLog.fromJson(Map<String, dynamic> json) => WeightLog(
        id: json['id'].toString(),
        date:
            DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime(1970),
        weightKg: jsonDouble(json['weight_kg']) ?? 0,
      );
}

/// One water entry (a glass or a bottle).
class WaterLog {
  /// Creates a water entry.
  const WaterLog({required this.id, required this.amountMl});

  /// Entry id (UUID).
  final String id;

  /// Amount in ml.
  final int amountMl;

  /// Reads one entry of GET /api/v1/water/.
  factory WaterLog.fromJson(Map<String, dynamic> json) => WaterLog(
        id: json['id'].toString(),
        amountMl: jsonInt(json['amount_ml']) ?? 0,
      );
}

/// All water of one day; the newest entry comes first.
class WaterDay {
  /// Creates the water of [date].
  const WaterDay({required this.date, required this.entries});

  /// The day.
  final DateTime date;

  /// Entries, newest first (as the API sends them).
  final List<WaterLog> entries;

  /// Sum of the day in ml.
  int get totalMl => entries.fold(0, (sum, entry) => sum + entry.amountMl);

  /// Number of full glasses for the glass display (never more than the goal shows).
  int get glasses => (totalMl ~/ glassMl).clamp(0, waterGoalMl ~/ glassMl);
}
