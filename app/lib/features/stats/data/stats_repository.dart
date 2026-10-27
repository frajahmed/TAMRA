import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/json.dart';
import '../domain/stats.dart';

/// Number of days the free statistics show.
const freeStatsDays = 7;

/// Statistics of the logged-in user from the TAMRA API.
class StatsRepository {
  /// Creates the repository on top of [ApiClient].
  StatsRepository(this._api);

  final ApiClient _api;

  /// Totals per day and averages from [from] to [to] (both included, at most 31 days).
  Future<StatsSummary> summary(DateTime from, DateTime to) async =>
      StatsSummary.fromJson(await _api.statsSummary(dateKey(from), dateKey(to)));
}

/// The [StatsRepository] used by the statistics screen (replaced by a fake in tests).
final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(ref.watch(apiClientProvider));
});

/// The last [freeStatsDays] days including today.
final weekStatsProvider = FutureProvider.autoDispose<StatsSummary>((ref) {
  final today = dateOnly(DateTime.now());
  final from = DateTime(today.year, today.month, today.day - (freeStatsDays - 1));
  return ref.watch(statsRepositoryProvider).summary(from, today);
});
