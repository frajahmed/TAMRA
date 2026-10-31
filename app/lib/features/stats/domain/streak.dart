import '../../../core/json.dart';

/// One consecutive-day milestone and the first day on which it was earned.
class StreakBadge {
  /// Creates a streak badge.
  const StreakBadge({
    required this.days,
    required this.earned,
    this.earnedOn,
  });

  /// Required consecutive days for this badge.
  final int days;

  /// Whether the user has reached this milestone.
  final bool earned;

  /// The first day a run reached [days], or null while the badge is open.
  final DateTime? earnedOn;

  /// Reads one badge from the streak API.
  factory StreakBadge.fromJson(Map<String, dynamic> json) => StreakBadge(
        days: jsonInt(json['days']) ?? 0,
        earned: json['earned'] == true,
        earnedOn: DateTime.tryParse(json['earned_on']?.toString() ?? ''),
      );
}

/// Current and longest diary-entry streaks with their milestone badges.
class Streak {
  /// Creates a streak result for [date].
  const Streak({
    required this.date,
    required this.currentDays,
    required this.longestDays,
    required this.loggedToday,
    required this.badges,
  });

  /// The user's local day used for the calculation.
  final DateTime date;

  /// Consecutive logged days ending today or yesterday.
  final int currentDays;

  /// Longest consecutive run up to [date].
  final int longestDays;

  /// Whether [date] already has a diary entry.
  final bool loggedToday;

  /// The fixed 7-, 30-, and 100-day milestones.
  final List<StreakBadge> badges;

  /// Reads the streak API response without unchecked JSON casts.
  factory Streak.fromJson(Map<String, dynamic> json) {
    final badges = json['badges'];
    return Streak(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime(1970),
      currentDays: jsonInt(json['current_days']) ?? 0,
      longestDays: jsonInt(json['longest_days']) ?? 0,
      loggedToday: json['logged_today'] == true,
      badges: [
        if (badges is List)
          for (final badge in badges)
            if (badge is Map<String, dynamic>) StreakBadge.fromJson(badge),
      ],
    );
  }
}
