import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/json.dart';
import '../domain/tracking.dart';

/// How many days the weight history shows.
const weightHistoryDays = 90;

/// Weight and water of the logged-in user from the TAMRA API.
class TrackingRepository {
  /// Creates the repository on top of [ApiClient].
  TrackingRepository(this._api);

  final ApiClient _api;

  /// Weights from [from] until today, oldest first (for charts and lists).
  Future<List<WeightLog>> weights({required DateTime from}) async {
    final items = await _api.listWeights(from: dateKey(from));
    final logs = [for (final item in items) WeightLog.fromJson(item)];
    logs.sort((a, b) => a.date.compareTo(b.date));
    return logs;
  }

  /// Saves the weight of [date] in kg; an existing weight of that day is replaced.
  Future<WeightLog> saveWeight(DateTime date, double weightKg) async =>
      WeightLog.fromJson(await _api.saveWeight(dateKey(date), weightKg));

  /// Deletes a weight entry.
  Future<void> deleteWeight(String id) => _api.deleteWeight(id);

  /// Water of [date].
  Future<WaterDay> water(DateTime date) async {
    final items = await _api.listWater(dateKey(date));
    return WaterDay(date: dateOnly(date), entries: [for (final i in items) WaterLog.fromJson(i)]);
  }

  /// Adds [amountMl] (default one glass) to [date].
  Future<void> addWater(DateTime date, {int amountMl = glassMl}) =>
      _api.addWater(dateKey(date), amountMl);

  /// Removes one entry (the newest, so a mistaken tap is undone first).
  Future<void> removeWater(String id) => _api.deleteWater(id);
}

/// The [TrackingRepository] used by weight and water screens (replaced by a fake in tests).
final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  return TrackingRepository(ref.watch(apiClientProvider));
});

/// Weights of the last [weightHistoryDays] days, oldest first.
final weightsProvider = FutureProvider.autoDispose<List<WeightLog>>((ref) {
  final today = dateOnly(DateTime.now());
  final from = DateTime(today.year, today.month, today.day - weightHistoryDays);
  return ref.watch(trackingRepositoryProvider).weights(from: from);
});

/// Water of one day.
final waterDayProvider = FutureProvider.autoDispose.family<WaterDay, DateTime>((ref, day) {
  return ref.watch(trackingRepositoryProvider).water(day);
});
