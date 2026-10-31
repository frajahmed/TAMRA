import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/json.dart';
import '../domain/stats.dart';

/// Statistics of the logged-in user from the TAMRA API.
class StatsRepository {
  /// Creates the repository on top of [ApiClient].
  StatsRepository(this._api);

  final ApiClient _api;

  /// Totals per day / week / month and averages from [from] to [to] (both included).
  Future<StatsSummary> summary(DateTime from, DateTime to,
          {String group = 'day'}) async =>
      StatsSummary.fromJson(
          await _api.statsSummary(dateKey(from), dateKey(to), group: group));
}

/// The [StatsRepository] used by the statistics screen (replaced by a fake in tests).
final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(ref.watch(apiClientProvider));
});

/// The range chosen on the statistics screen.
class SelectedStatsRange extends Notifier<StatsRange> {
  @override
  StatsRange build() => StatsRange.days7;

  /// Shows [range].
  void select(StatsRange range) => state = range;
}

/// The range chosen on the statistics screen (7 days by default).
final statsRangeProvider =
    NotifierProvider<SelectedStatsRange, StatsRange>(SelectedStatsRange.new);

/// Statistics of the chosen range up to today.
final statsProvider = FutureProvider.autoDispose<StatsSummary>((ref) {
  final range = ref.watch(statsRangeProvider);
  final today = dateOnly(DateTime.now());
  return ref
      .watch(statsRepositoryProvider)
      .summary(range.start(today), today, group: range.group);
});
