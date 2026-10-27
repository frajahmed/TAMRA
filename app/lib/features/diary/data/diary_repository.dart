import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/json.dart';
import '../../../core/offline/local_store.dart';
import '../../../core/offline/outbox.dart';
import '../../../core/nutrition/nutrition.dart';
import '../domain/diary.dart';
import 'offline_diary_repository.dart';

/// Diary entries of the logged-in user from the TAMRA API.
class DiaryRepository {
  /// Creates the repository on top of [ApiClient].
  DiaryRepository(this._api);

  final ApiClient _api;

  /// Entries, targets and energy unit of [date]. Errors arrive as [ApiError].
  Future<DiaryDay> day(DateTime date) async {
    final key = dateKey(date);
    final entries = await _api.listDiary(key);
    final summary = await _api.diarySummary(key);
    return DiaryDay(
      date: dateOnly(date),
      entries: [for (final item in entries) DiaryEntry.fromJson(item)],
      targets: DayTargets.fromJson(summary['targets']),
      energyUnit: EnergyUnit.fromApi(summary['energy_unit']),
      burnedKcal: jsonDouble(summary['burned_kcal']) ?? 0,
      steps: jsonInt(summary['steps']) ?? 0,
      countActivityKcal: summary['count_activity_kcal'] != false,
    );
  }

  /// Saves a new entry and returns it with the nutrients calculated by the server.
  Future<DiaryEntry> add(NewDiaryEntry entry) async =>
      DiaryEntry.fromJson(await _api.createDiaryEntry(entry.toJson()));

  /// Changes amount and/or meal of an entry.
  Future<DiaryEntry> update(String id, {double? amountG, Meal? meal}) async =>
      DiaryEntry.fromJson(
        await _api.updateDiaryEntry(id, {
          if (amountG != null) 'amount_g': amountG.toStringAsFixed(2),
          if (meal != null) 'meal': meal.name,
        }),
      );

  /// Deletes an entry.
  Future<void> delete(String id) => _api.deleteDiaryEntry(id);

  /// Copies the entries of [from] (only [meal] when given) to [to]; returns how many.
  Future<int> copy({required DateTime from, required DateTime to, Meal? meal}) =>
      _api.copyDiary({
        'from_date': dateKey(from),
        'to_date': dateKey(to),
        if (meal != null) 'meal': meal.name,
      });
}

/// The diary used by the screens: online with an offline cache and outbox
/// (replaced by a fake in tests).
final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  final store = ref.watch(localStoreProvider);
  return OfflineDiaryRepository(
    remote: DiaryRepository(ref.watch(apiClientProvider)),
    store: store,
    outbox: Outbox(store),
  );
});

/// The day shown in the diary (starts with today).
class SelectedDay extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(DateTime.now());

  /// Shows [day] in the diary.
  void select(DateTime day) => state = dateOnly(day);
}

/// The day shown in the diary.
final selectedDayProvider = NotifierProvider<SelectedDay, DateTime>(SelectedDay.new);

/// Entries and targets of one day; invalidate it after a change to reload.
final diaryDayProvider = FutureProvider.autoDispose.family<DiaryDay, DateTime>((ref, day) {
  return ref.watch(diaryRepositoryProvider).day(day);
});
