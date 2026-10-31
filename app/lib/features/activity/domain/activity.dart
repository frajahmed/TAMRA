import '../../../core/json.dart';

/// Body weight used for kcal suggestions when the profile has none yet.
const defaultWeightKg = 70.0;

/// Type of sport with its MET value (Compendium of Physical Activities, rounded).
enum ActivityKind {
  /// Walking at a normal pace.
  walking(3.5),

  /// Running / jogging.
  running(9.8),

  /// Cycling at a moderate pace.
  cycling(7.5),

  /// Swimming laps.
  swimming(6.0),

  /// Strength training.
  strength(5.0),

  /// Yoga / stretching.
  yoga(2.5),

  /// High-intensity interval training.
  hiit(8.0),

  /// Football, basketball and other team sports.
  teamSport(7.0),

  /// Hiking.
  hiking(6.0),

  /// Dancing.
  dancing(5.0),

  /// Anything else.
  other(4.0);

  const ActivityKind(this.met);

  /// Metabolic equivalent of the activity.
  final double met;

  /// The value the API uses (`team_sport` for [teamSport]).
  String get apiValue => this == ActivityKind.teamSport ? 'team_sport' : name;

  /// The kind from the API value; unknown → [other].
  static ActivityKind fromApi(Object? value) => ActivityKind.values.firstWhere(
        (kind) => kind.apiValue == value,
        orElse: () => ActivityKind.other,
      );
}

/// Where a workout comes from.
enum ActivitySource {
  /// Entered in TAMRA.
  manual,

  /// Apple Health (iPhone).
  appleHealth,

  /// Health Connect (Android).
  healthConnect,

  /// Strava, Garmin, Fitbit or Polar (later, direct connections).
  other;

  /// The value the API uses.
  String get apiValue => switch (this) {
        ActivitySource.appleHealth => 'apple_health',
        ActivitySource.healthConnect => 'health_connect',
        _ => name,
      };

  /// The source from the API value.
  static ActivitySource fromApi(Object? value) => switch (value) {
        'manual' => ActivitySource.manual,
        'apple_health' => ActivitySource.appleHealth,
        'health_connect' => ActivitySource.healthConnect,
        _ => ActivitySource.other,
      };
}

/// One workout as returned by /api/v1/activities/.
class Activity {
  /// Creates a workout.
  const Activity({
    required this.id,
    required this.date,
    required this.kind,
    required this.durationMin,
    required this.kcal,
    this.title = '',
    this.distanceM,
    this.source = ActivitySource.manual,
  });

  /// Entry id (UUID).
  final String id;

  /// The user's local day of the start.
  final DateTime date;

  /// Type of sport.
  final ActivityKind kind;

  /// Optional title from the other app ("Morning run").
  final String title;

  /// Duration in minutes.
  final int durationMin;

  /// Active energy burned in kcal.
  final double kcal;

  /// Distance in metres, if known.
  final int? distanceM;

  /// Where the workout comes from.
  final ActivitySource source;

  /// Imported workouts can only be deleted (they are corrected in their own app).
  bool get isImported => source != ActivitySource.manual;

  /// Reads one workout of the API.
  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        id: json['id'].toString(),
        date:
            DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime(1970),
        kind: ActivityKind.fromApi(json['kind']),
        title: json['title']?.toString() ?? '',
        durationMin: jsonInt(json['duration_min']) ?? 0,
        kcal: jsonDouble(json['kcal']) ?? 0,
        distanceM: jsonInt(json['distance_m']),
        source: ActivitySource.fromApi(json['source']),
      );
}

/// A workout entered by hand; the server sets source `manual`.
class NewActivity {
  /// Creates the data for POST /api/v1/activities/.
  const NewActivity({
    required this.date,
    required this.kind,
    required this.durationMin,
    required this.kcal,
    this.distanceM,
  });

  /// The day of the workout.
  final DateTime date;

  /// Type of sport.
  final ActivityKind kind;

  /// Duration in minutes.
  final int durationMin;

  /// Burned kcal (suggested from MET, may be changed by the user).
  final double kcal;

  /// Distance in metres, if entered.
  final int? distanceM;

  /// Body for POST /api/v1/activities/.
  Map<String, dynamic> toJson() => {
        'date': dateKey(date),
        'kind': kind.apiValue,
        'duration_min': durationMin,
        'kcal': kcal.toStringAsFixed(1),
        if (distanceM != null) 'distance_m': distanceM,
      };
}

/// Sport of one day.
class ActivityDay {
  /// Creates the sport of [date].
  const ActivityDay(
      {required this.date, required this.activities, this.steps = 0});

  /// The day.
  final DateTime date;

  /// Workouts of the day.
  final List<Activity> activities;

  /// Steps of the day (shown only, never added to the budget).
  final int steps;

  /// Sum of burned kcal.
  double get burnedKcal =>
      activities.fold(0, (sum, activity) => sum + activity.kcal);

  /// Sum of sport minutes.
  int get minutes =>
      activities.fold(0, (sum, activity) => sum + activity.durationMin);
}

/// One workout read from Apple Health or Health Connect.
class HealthWorkout {
  /// Creates a workout; [externalId] is its id in the health app (prevents duplicates).
  const HealthWorkout({
    required this.externalId,
    required this.start,
    required this.minutes,
    required this.kcal,
    required this.kind,
    this.distanceM,
    this.title = '',
  });

  /// Id of the workout in the health app.
  final String externalId;

  /// Start time (local).
  final DateTime start;

  /// Duration in minutes.
  final int minutes;

  /// Active energy in kcal.
  final double kcal;

  /// Type of sport (mapped from the health app's type).
  final ActivityKind kind;

  /// Distance in metres, if known.
  final int? distanceM;

  /// App or device that recorded it ("Garmin Connect").
  final String title;

  /// Body for POST /api/v1/activities/import/; values are clamped to the API limits.
  Map<String, dynamic> toImportJson(String source) => {
        'date': dateKey(start),
        'started_at': start.toUtc().toIso8601String(),
        'kind': kind.apiValue,
        'title': title.length > 100 ? title.substring(0, 100) : title,
        'duration_min': minutes.clamp(1, 1440),
        'kcal': kcal.clamp(0, 10000).toStringAsFixed(1),
        if (distanceM != null) 'distance_m': distanceM,
        'source': source,
        'external_id': externalId,
      };
}

/// What a health app delivered for a time span.
class HealthImport {
  /// Creates the data of one read.
  const HealthImport({this.workouts = const [], this.stepsByDay = const {}});

  /// Workouts in the time span.
  final List<HealthWorkout> workouts;

  /// Steps per local day.
  final Map<DateTime, int> stepsByDay;
}

/// Maps a workout type name of HealthKit / Health Connect (e.g. `TRADITIONAL_STRENGTH_TRAINING`)
/// to a TAMRA type. Works on the name so new types in the health package never break the app.
ActivityKind activityKindFromHealth(String typeName) {
  final name = typeName.toUpperCase();
  for (final (words, kind) in _healthKinds) {
    if (words.any(name.contains)) return kind;
  }
  return ActivityKind.other;
}

/// Parts of health-app type names and the TAMRA type they mean; the first match wins
/// (so `HIKING` is not read as walking and `STRENGTH` before `WEIGHT`).
const _healthKinds = <(List<String>, ActivityKind)>[
  (['RUN', 'JOG'], ActivityKind.running),
  (['HIK'], ActivityKind.hiking),
  (['WALK'], ActivityKind.walking),
  (['BIK', 'CYCL'], ActivityKind.cycling),
  (['SWIM'], ActivityKind.swimming),
  (['HIGH_INTENSITY', 'HIIT'], ActivityKind.hiit),
  (['STRENGTH', 'WEIGHT', 'FUNCTIONAL'], ActivityKind.strength),
  (['YOGA', 'PILATES', 'STRETCH'], ActivityKind.yoga),
  (['DANC'], ActivityKind.dancing),
  (
    [
      'SOCCER',
      'FOOTBALL',
      'BASKETBALL',
      'VOLLEYBALL',
      'HANDBALL',
      'HOCKEY',
      'RUGBY'
    ],
    ActivityKind.teamSport
  ),
];
