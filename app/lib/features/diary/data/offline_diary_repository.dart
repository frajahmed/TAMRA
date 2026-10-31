import '../../../core/api/api_client.dart';
import '../../../core/json.dart';
import '../../../core/offline/local_store.dart';
import '../../../core/offline/outbox.dart';
import '../domain/diary.dart';
import 'diary_repository.dart';

/// The diary that keeps working without internet.
///
/// - Every loaded day is cached on the phone; without a connection the cached day is shown
///   (marked `offline`).
/// - Adding, changing or deleting without a connection changes the cached day at once and
///   puts the request into the [Outbox]. The outbox is sent in order as soon as the server
///   answers again (before every load and after every successful change).
/// - Ids are made on the phone, so a request sent twice is harmless: "id already used"
///   (400) and "not found" (404) count as already done.
/// Conflicts: the server keeps the newest change (last write wins on `updated_at`).
class OfflineDiaryRepository implements DiaryRepository {
  /// Wraps [remote] (the API) with a cache in [store] and an [outbox].
  OfflineDiaryRepository(
      {required this.remote, required this.store, required this.outbox});

  /// The online diary (the API).
  final DiaryRepository remote;

  /// Where days are cached.
  final LocalStore store;

  /// Offline changes waiting for the server.
  final Outbox outbox;

  static String _key(DateTime date) => 'diary-${dateKey(date)}';

  @override
  Future<DiaryDay> day(DateTime date) async {
    try {
      await flush();
      final day = await remote.day(date);
      await store.write(_key(date), day.toJson());
      return day;
    } on ApiError catch (error) {
      if (!error.isNetworkError) rethrow;
      final cached = await store.read(_key(date));
      if (cached == null) rethrow;
      return DiaryDay.fromJson(cached, offline: true);
    }
  }

  @override
  Future<DiaryEntry> add(NewDiaryEntry entry) async {
    try {
      final saved = await remote.add(entry);
      await _changeCachedDay(entry.date, (entries) => [...entries, saved]);
      await flush();
      return saved;
    } on ApiError catch (error) {
      if (!error.isNetworkError) rethrow;
      final local = entry.toLocalEntry();
      await _changeCachedDay(entry.date, (entries) => [...entries, local]);
      await outbox
          .add(OutboxOperation(kind: 'diary.create', payload: entry.toJson()));
      return local;
    }
  }

  @override
  Future<DiaryEntry> update(String id, {double? amountG, Meal? meal}) async {
    try {
      final saved = await remote.update(id, amountG: amountG, meal: meal);
      await _replaceCachedEntry(saved.date, id, (_) => saved);
      return saved;
    } on ApiError catch (error) {
      if (!error.isNetworkError) rethrow;
      final changed = await _findCachedEntry(id);
      if (changed == null) rethrow;
      final local = changed.changed(amountG: amountG, meal: meal);
      await _replaceCachedEntry(local.date, id, (_) => local);
      await outbox.add(
        OutboxOperation(
          kind: 'diary.update',
          payload: {
            'id': id,
            if (amountG != null) 'amount_g': amountG,
            if (meal != null) 'meal': meal.name,
          },
        ),
      );
      return local;
    }
  }

  @override
  Future<void> delete(String id) async {
    final cached = await _findCachedEntry(id);
    try {
      await remote.delete(id);
    } on ApiError catch (error) {
      if (!error.isNetworkError) rethrow;
      await outbox
          .add(OutboxOperation(kind: 'diary.delete', payload: {'id': id}));
    }
    if (cached != null) {
      await _changeCachedDay(
        cached.date,
        (entries) => [
          for (final entry in entries)
            if (entry.id != id) entry
        ],
      );
    }
  }

  @override
  Future<int> copy(
          {required DateTime from, required DateTime to, Meal? meal}) =>
      // Copying needs the server (it calculates fresh nutrients); it works online only.
      remote.copy(from: from, to: to, meal: meal);

  /// Sends waiting offline changes in order; stops at the first network error.
  Future<void> flush() async {
    for (final operation in await outbox.all()) {
      try {
        await _send(operation);
      } on ApiError catch (error) {
        if (error.isNetworkError)
          return; // still offline: keep the rest for later
        // 400 "id already used" / 404 "not found": already done or no longer possible.
      }
      await outbox.removeFirst();
    }
  }

  Future<void> _send(OutboxOperation operation) async {
    final payload = operation.payload;
    final id = payload['id']?.toString() ?? '';
    switch (operation.kind) {
      case 'diary.create':
        await remote.add(
          NewDiaryEntry(
            id: id,
            date: DateTime.parse(payload['date'].toString()),
            meal: Meal.fromApi(payload['meal']),
            foodId: payload['food'].toString(),
            amountG: jsonDouble(payload['amount_g']) ?? 0,
          ),
        );
      case 'diary.update':
        await remote.update(
          id,
          amountG: jsonDouble(payload['amount_g']),
          meal: payload['meal'] == null ? null : Meal.fromApi(payload['meal']),
        );
      case 'diary.delete':
        await remote.delete(id);
    }
  }

  Future<void> _changeCachedDay(
    DateTime date,
    List<DiaryEntry> Function(List<DiaryEntry> entries) change,
  ) async {
    final cached = await store.read(_key(date));
    final day = cached == null
        ? DiaryDay(date: dateOnly(date), entries: const [])
        : DiaryDay.fromJson(cached);
    await store.write(
        _key(date), day.withEntries(change(day.entries)).toJson());
  }

  Future<void> _replaceCachedEntry(
    DateTime date,
    String id,
    DiaryEntry Function(DiaryEntry old) replace,
  ) =>
      _changeCachedDay(
        date,
        (entries) => [
          for (final entry in entries) entry.id == id ? replace(entry) : entry
        ],
      );

  /// Looks for [id] in the cached days of the last weeks (entries are edited near today).
  Future<DiaryEntry?> _findCachedEntry(String id) async {
    final today = dateOnly(DateTime.now());
    for (var offset = 0; offset <= 60; offset++) {
      final cached = await store
          .read(_key(DateTime(today.year, today.month, today.day - offset)));
      if (cached == null) continue;
      for (final entry in DiaryDay.fromJson(cached).entries) {
        if (entry.id == id) return entry;
      }
    }
    return null;
  }
}
