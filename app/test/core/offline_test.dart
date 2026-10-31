import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/core/api/api_client.dart';
import 'package:tamra_app/core/json.dart';
import 'package:tamra_app/core/nutrition/nutrition.dart';
import 'package:tamra_app/core/offline/local_store.dart';
import 'package:tamra_app/core/offline/outbox.dart';
import 'package:tamra_app/features/diary/data/offline_diary_repository.dart';
import 'package:tamra_app/features/diary/domain/diary.dart';

import '../helpers/fakes.dart';

const _offline = ApiError(code: 'network_error', message: 'offline');

/// Remote diary that can be switched offline; ids already sent answer like the server.
class _SwitchableRemote extends FakeDiaryRepository {
  bool online = true;
  final Set<String> knownIds = {};

  void _check() {
    if (!online) throw _offline;
  }

  @override
  Future<DiaryDay> day(DateTime date) async {
    _check();
    return super.day(date);
  }

  @override
  Future<DiaryEntry> add(NewDiaryEntry entry) async {
    _check();
    if (!knownIds.add(entry.id)) {
      throw const ApiError(
          code: 'validation_error', message: 'id used', statusCode: 400);
    }
    final saved = entry.toLocalEntry();
    entries.add(saved);
    added.add(entry);
    return saved;
  }

  @override
  Future<DiaryEntry> update(String id, {double? amountG, Meal? meal}) async {
    _check();
    return super.update(id, amountG: amountG, meal: meal);
  }

  @override
  Future<void> delete(String id) async {
    _check();
    if (!entries.any((entry) => entry.id == id)) {
      throw const ApiError(
          code: 'not_found', message: 'Not found.', statusCode: 404);
    }
    return super.delete(id);
  }
}

final _today = dateOnly(DateTime.now());
const _apple = NutritionPer100g(kcal: 52, protein: 0.3, carbs: 14, fat: 0.2);

NewDiaryEntry _newApple({double grams = 200}) => NewDiaryEntry(
      date: _today,
      meal: Meal.snack,
      foodId: 'f1',
      amountG: grams,
      foodName: 'Apfel',
      per100g: _apple,
    );

void main() {
  late _SwitchableRemote remote;
  late MemoryLocalStore store;
  late Outbox outbox;
  late OfflineDiaryRepository diary;

  setUp(() {
    remote = _SwitchableRemote();
    store = MemoryLocalStore();
    outbox = Outbox(store);
    diary =
        OfflineDiaryRepository(remote: remote, store: store, outbox: outbox);
  });

  test('a loaded day is cached and shown offline', () async {
    await diary.add(_newApple());
    expect((await diary.day(_today)).offline, isFalse);

    remote.online = false;
    final cached = await diary.day(_today);
    expect(cached.offline, isTrue);
    expect(cached.entries.single.foodName, 'Apfel');
  });

  test('without cache and without internet the error is shown', () async {
    remote.online = false;
    await expectLater(diary.day(_today), throwsA(isA<ApiError>()));
  });

  test('adding offline shows the entry at once and sends it later', () async {
    remote.online = false;
    final local = await diary.add(_newApple());
    expect(local.nutrients.kcal, 104); // 200 g × 52 kcal / 100 g
    expect(await outbox.length, 1);
    expect((await diary.day(_today)).entries.single.id, local.id);

    remote.online = true;
    final day = await diary.day(_today);
    expect(await outbox.length, 0);
    expect(remote.added.single.id, local.id);
    expect(day.entries.single.id, local.id);
  });

  test('sending twice is harmless (id already used)', () async {
    remote.online = false;
    final entry = _newApple();
    await diary.add(entry);
    remote.knownIds.add(entry.id); // the first try reached the server after all

    remote.online = true;
    await diary.flush();

    expect(await outbox.length, 0);
    expect(remote.added, isEmpty);
  });

  test('changes and deletes made offline are replayed in order', () async {
    final saved = await diary.add(_newApple());
    await diary.day(_today);

    remote.online = false;
    final changed =
        await diary.update(saved.id, amountG: 100, meal: Meal.lunch);
    expect(changed.nutrients.kcal, 52);
    expect(changed.meal, Meal.lunch);
    await diary.delete(saved.id);
    expect((await diary.day(_today)).entries, isEmpty);
    expect(await outbox.length, 2);

    remote.online = true;
    await diary.flush();
    expect(await outbox.length, 0);
    expect(remote.updated, ['${saved.id}:100.0:lunch']);
    expect(remote.deleted, [saved.id]);
  });

  test('flush stops at the first network error and keeps the rest', () async {
    remote.online = false;
    await diary.add(_newApple());
    await diary.add(_newApple(grams: 50));
    await diary.flush();
    expect(await outbox.length, 2);
  });

  test('server errors that are not network errors are shown, not queued',
      () async {
    final entry = _newApple();
    remote.knownIds.add(entry.id);
    await expectLater(
      diary.add(entry),
      throwsA(isA<ApiError>()
          .having((error) => error.statusCode, 'statusCode', 400)),
    );
    expect(await outbox.length, 0);
  });

  test('the outbox survives as a stored document', () async {
    await outbox
        .add(const OutboxOperation(kind: 'diary.delete', payload: {'id': 'x'}));
    final again = Outbox(store);
    expect((await again.all()).single.payload['id'], 'x');
    await again.removeFirst();
    expect(await again.length, 0);
  });

  test('clear removes all documents', () async {
    await diary.add(_newApple());
    expect(store.documents, isNotEmpty);
    await store.clear();
    expect(store.documents, isEmpty);
  });
}
