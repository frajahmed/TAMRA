import '../../../core/nutrition/nutrition.dart';

/// Converts DRF decimals ("170.0"), ints and doubles to double.
double? _toDouble(Object? value) => switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text),
      _ => null,
    };

int? _toInt(Object? value) => switch (value) {
      int number => number,
      num number => number.round(),
      String text => int.tryParse(text),
      _ => null,
    };

/// The user's profile as returned by GET /api/v1/me/profile/.
class Profile {
  const Profile({
    this.sex,
    this.birthYear,
    this.heightCm,
    this.weightKg,
    this.activityLevel = 'sedentary',
    this.goal = 'maintain',
    this.kcalTarget,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.isComplete = false,
  });

  final String? sex;
  final int? birthYear;
  final double? heightCm;
  final double? weightKg;
  final String activityLevel;
  final String goal;
  final int? kcalTarget;
  final int? proteinG;
  final int? carbsG;
  final int? fatG;
  final bool isComplete;

  factory Profile.fromJson(Map<String, dynamic> json) {
    final sex = json['sex'] as String?;
    return Profile(
      sex: (sex == null || sex.isEmpty) ? null : sex,
      birthYear: _toInt(json['birth_year']),
      heightCm: _toDouble(json['height_cm']),
      weightKg: _toDouble(json['weight_kg']),
      activityLevel: (json['activity_level'] as String?) ?? 'sedentary',
      goal: (json['goal'] as String?) ?? 'maintain',
      kcalTarget: _toInt(json['kcal_target']),
      proteinG: _toInt(json['protein_g']),
      carbsG: _toInt(json['carbs_g']),
      fatG: _toInt(json['fat_g']),
      isComplete: json['is_complete'] == true,
    );
  }
}

/// The answers collected by the onboarding screen.
class OnboardingAnswers {
  const OnboardingAnswers({
    required this.goal,
    required this.sex,
    required this.birthYear,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
  });

  final WeightGoal goal;
  final Sex sex;
  final int birthYear;
  final double heightCm;
  final double weightKg;
  final ActivityLevel activityLevel;

  /// API value for an activity level (`veryActive` → `very_active`).
  static String activityToApi(ActivityLevel level) => switch (level) {
        ActivityLevel.sedentary => 'sedentary',
        ActivityLevel.light => 'light',
        ActivityLevel.moderate => 'moderate',
        ActivityLevel.active => 'active',
        ActivityLevel.veryActive => 'very_active',
      };

  Map<String, dynamic> toJson() => {
        'goal': goal.name,
        'sex': sex.name,
        'birth_year': birthYear,
        'height_cm': heightCm.toStringAsFixed(1),
        'weight_kg': weightKg.toStringAsFixed(1),
        'activity_level': activityToApi(activityLevel),
      };

  /// Local preview with the same formula as the server.
  int localCalorieTarget(int currentYear) => dailyCalorieTarget(
        sex: sex,
        weightKg: weightKg,
        heightCm: heightCm,
        ageYears: currentYear - birthYear,
        activity: activityLevel,
        goal: goal,
      );
}

/// Allowed input ranges (same as the API).
abstract final class ProfileLimits {
  static const minHeightCm = 100;
  static const maxHeightCm = 250;
  static const minWeightKg = 30;
  static const maxWeightKg = 300;
  static const minAge = 16;
  static const maxAge = 100;
}
