import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/core/json.dart';
import 'package:tamra_app/features/activity/data/health_sync.dart';
import 'package:tamra_app/features/activity/domain/activity.dart';

import '../../helpers/fakes.dart';

final _now = DateTime(2026, 10, 28, 9, 30);

HealthImport _data() => HealthImport(
      workouts: [
        HealthWorkout(
          externalId: 'hc-1',
          start: DateTime(2026, 10, 27, 18),
          minutes: 45,
          kcal: 410.4,
          distanceM: 7200,
          kind: ActivityKind.running,
          title: 'Garmin Connect',
        ),
      ],
      stepsByDay: {DateTime(2026, 10, 27): 11200, DateTime(2026, 10, 28): 2500},
    );

HealthSync _sync(FakeHealthSource source, FakeActivityRepository repository,
        MemoryHealthSettingsStorage storage) =>
    HealthSync(source: source, repository: repository, storage: storage, clock: () => _now);

void main() {
  group('HealthSync', () {
    test('connect asks for access, then reads the last 30 days and imports', () async {
      final source = FakeHealthSource(data: _data());
      final repository = FakeActivityRepository();
      final storage = MemoryHealthSettingsStorage();

      expect(await _sync(source, repository, storage).connect(), isTrue);

      expect(source.permissionRequests, 1);
      expect(source.reads, ['2026-09-28..2026-10-28']);
      expect(storage.connected, isTrue);
      expect(storage.last, _now);
      final sent = repository.imported.single;
      final workout = (sent['activities'] as List).single as Map<String, dynamic>;
      expect(workout['external_id'], 'hc-1');
      expect(workout['source'], 'health_connect');
      expect(workout['date'], '2026-10-27');
      expect(workout['kind'], 'running');
      expect(workout['kcal'], '410.4');
      final steps = sent['steps'] as List;
      expect(steps, hasLength(2));
      expect((steps.first as Map)['steps'], 11200);
    });

    test('refused access keeps the hub disconnected', () async {
      final source = FakeHealthSource(grant: false);
      final storage = MemoryHealthSettingsStorage();
      expect(await _sync(source, FakeActivityRepository(), storage).connect(), isFalse);
      expect(storage.connected, isFalse);
      expect(source.reads, isEmpty);
    });

    test('later syncs start at the last sync', () async {
      final source = FakeHealthSource();
      final storage = MemoryHealthSettingsStorage()
        ..connected = true
        ..last = DateTime(2026, 10, 27, 20);
      await _sync(source, FakeActivityRepository(), storage).sync();
      expect(source.reads, ['2026-10-27..2026-10-28']);
    });

    test('many workouts are sent in pages of 500, steps only once', () async {
      final source = FakeHealthSource(
        data: HealthImport(
          workouts: [
            for (var index = 0; index < 1200; index++)
              HealthWorkout(
                externalId: 'w$index',
                start: DateTime(2026, 10, 1),
                minutes: 20,
                kcal: 100,
                kind: ActivityKind.walking,
              ),
          ],
          stepsByDay: {DateTime(2026, 10, 1): 5000},
        ),
      );
      final repository = FakeActivityRepository();
      final created = await _sync(source, repository, MemoryHealthSettingsStorage()).sync();

      expect(repository.imported.map((page) => (page['activities'] as List).length), [500, 500, 200]);
      expect(repository.imported.map((page) => (page['steps'] as List).length), [1, 0, 0]);
      expect(created, 1201);
    });

    test('disconnect forgets the connection and the last sync', () async {
      final storage = MemoryHealthSettingsStorage()
        ..connected = true
        ..last = _now;
      await _sync(FakeHealthSource(), FakeActivityRepository(), storage).disconnect();
      expect(storage.connected, isFalse);
      expect(storage.last, isNull);
    });

    test('import values stay within the API limits', () {
      final json = HealthWorkout(
        externalId: 'x',
        start: DateTime(2026, 10, 1),
        minutes: 3000,
        kcal: 20000,
        kind: ActivityKind.other,
        title: 'x' * 150,
      ).toImportJson('apple_health');
      expect(json['duration_min'], 1440);
      expect(json['kcal'], '10000.0');
      expect((json['title'] as String).length, 100);
    });
  });

  test('health workout types map to TAMRA types', () {
    expect(activityKindFromHealth('RUNNING'), ActivityKind.running);
    expect(activityKindFromHealth('HIKING'), ActivityKind.hiking);
    expect(activityKindFromHealth('WALKING'), ActivityKind.walking);
    expect(activityKindFromHealth('BIKING_STATIONARY'), ActivityKind.cycling);
    expect(activityKindFromHealth('TRADITIONAL_STRENGTH_TRAINING'), ActivityKind.strength);
    expect(activityKindFromHealth('HIGH_INTENSITY_INTERVAL_TRAINING'), ActivityKind.hiit);
    expect(activityKindFromHealth('soccer'), ActivityKind.teamSport);
    expect(activityKindFromHealth('ARCHERY'), ActivityKind.other);
  });

  group('health card', () {
    Future<void> openActivity(WidgetTester tester, {
      required FakeHealthSource health,
      required MemoryHealthSettingsStorage storage,
      FakeActivityRepository? activity,
    }) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testApp(health: health, healthStorage: storage, activity: activity),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-activity')));
      await tester.pumpAndSettle();
    }

    testWidgets('connect imports and then offers sync and disconnect', (tester) async {
      final activity = FakeActivityRepository();
      final storage = MemoryHealthSettingsStorage();
      await openActivity(
        tester,
        health: FakeHealthSource(data: _data()),
        storage: storage,
        activity: activity,
      );

      await tester.tap(find.byKey(const Key('health-connect')));
      await tester.pumpAndSettle();

      expect(storage.connected, isTrue);
      expect(activity.imported, hasLength(1));
      expect(find.byKey(const Key('health-sync')), findsOneWidget);
      expect(find.byKey(const Key('health-last-sync')), findsOneWidget);

      await tester.tap(find.byKey(const Key('health-disconnect')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('health-connect')), findsOneWidget);
    });

    testWidgets('refused access shows a hint', (tester) async {
      await openActivity(
        tester,
        health: FakeHealthSource(grant: false),
        storage: MemoryHealthSettingsStorage(),
      );
      await tester.tap(find.byKey(const Key('health-connect')));
      await tester.pumpAndSettle();
      expect(find.textContaining('No access'), findsOneWidget);
    });

    testWidgets('devices without a health hub say so', (tester) async {
      await openActivity(
        tester,
        health: FakeHealthSource(supported: false),
        storage: MemoryHealthSettingsStorage(),
      );
      expect(find.byKey(const Key('health-unsupported')), findsOneWidget);
    });

    testWidgets('a connected hub syncs once when the app opens', (tester) async {
      final activity = FakeActivityRepository();
      final storage = MemoryHealthSettingsStorage()..connected = true;
      await openActivity(
        tester,
        health: FakeHealthSource(data: _data()),
        storage: storage,
        activity: activity,
      );
      expect(activity.imported, hasLength(1));
      expect(dateKey(storage.last!), dateKey(DateTime.now()));
    });
  });
}
