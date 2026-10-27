import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/json.dart';
import '../domain/activity.dart';

/// Workouts and steps of the logged-in user from the TAMRA API.
class ActivityRepository {
  /// Creates the repository on top of [ApiClient].
  ActivityRepository(this._api);

  final ApiClient _api;

  /// Workouts and steps of [date].
  Future<ActivityDay> day(DateTime date) async {
    final key = dateKey(date);
    final items = await _api.listActivities(key);
    final summary = await _api.activitySummary(key);
    return ActivityDay(
      date: dateOnly(date),
      activities: [for (final item in items) Activity.fromJson(item)],
      steps: jsonInt(summary['steps']) ?? 0,
    );
  }

  /// Saves a workout entered by hand.
  Future<Activity> add(NewActivity activity) async =>
      Activity.fromJson(await _api.createActivity(activity.toJson()));

  /// Deletes a workout (an imported one is not imported again).
  Future<void> delete(String id) => _api.deleteActivity(id);

  /// Sends workouts and daily steps from a health app; returns how many rows were new.
  Future<int> importData({
    required List<Map<String, dynamic>> activities,
    required List<Map<String, dynamic>> steps,
  }) async {
    final result = await _api.importActivities({'activities': activities, 'steps': steps});
    return jsonInt(result['created']) ?? 0;
  }
}

/// The [ActivityRepository] used by the activity screens (replaced by a fake in tests).
final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository(ref.watch(apiClientProvider));
});

/// Workouts and steps of one day.
final activityDayProvider = FutureProvider.autoDispose.family<ActivityDay, DateTime>((ref, day) {
  return ref.watch(activityRepositoryProvider).day(day);
});
