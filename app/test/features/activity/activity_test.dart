import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/core/json.dart';
import 'package:tamra_app/core/nutrition/nutrition.dart';
import 'package:tamra_app/features/activity/domain/activity.dart';
import 'package:tamra_app/features/diary/domain/diary.dart';
import 'package:tamra_app/features/onboarding/domain/profile.dart';

import '../../helpers/fakes.dart';

final _today = dateOnly(DateTime.now());

Future<void> _pumpApp(
  WidgetTester tester, {
  FakeActivityRepository? activity,
  FakeDiaryRepository? diary,
  FakeProfileRepository? profile,
}) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testApp(
      activity: activity,
      diary: diary,
      profile:
          profile ?? FakeProfileRepository(result: const Profile(weightKg: 80)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openAdd(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('nav-activity')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('activity-add')));
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller?.text ?? '';

void main() {
  test('MET formula: MET × kg × hours', () {
    expect(
        activityKcal(met: 9.8, weightKg: 70, minutes: 30), closeTo(343, 1e-9));
    expect(activityKcal(met: 3.5, weightKg: 80, minutes: 60), 280);
    expect(() => activityKcal(met: 1, weightKg: 70, minutes: -1),
        throwsArgumentError);
  });

  test('Activity.fromJson and the API names', () {
    final activity = Activity.fromJson({
      'id': 'a1',
      'date': '2026-10-26',
      'kind': 'team_sport',
      'title': 'Fußball',
      'duration_min': 90,
      'kcal': '650.0',
      'distance_m': null,
      'source': 'health_connect',
    });
    expect(activity.kind, ActivityKind.teamSport);
    expect(activity.kcal, 650);
    expect(activity.isImported, isTrue);
    expect(ActivityKind.teamSport.apiValue, 'team_sport');
    expect(ActivitySource.fromApi('manual'), ActivitySource.manual);
    expect(ActivityKind.fromApi('parkour'), ActivityKind.other);
  });

  testWidgets('kcal are suggested from type, duration and weight',
      (tester) async {
    await _pumpApp(tester);
    await _openAdd(tester);

    // walking 3.5 MET × 80 kg × 0.5 h = 140
    expect(_fieldText(tester, 'activity-kcal'), '140');

    await tester.tap(find.byKey(const Key('kind-running')));
    await tester.pump();
    expect(_fieldText(tester, 'activity-kcal'), '392'); // 9.8 × 80 × 0.5

    await tester.enterText(find.byKey(const Key('activity-minutes')), '60');
    await tester.pump();
    expect(_fieldText(tester, 'activity-kcal'), '784');
  });

  testWidgets('own kcal are kept when the duration changes', (tester) async {
    final activity = FakeActivityRepository();
    await _pumpApp(tester, activity: activity);
    await _openAdd(tester);

    await tester.enterText(find.byKey(const Key('activity-kcal')), '250');
    await tester.enterText(find.byKey(const Key('activity-minutes')), '45');
    await tester.pump();
    expect(_fieldText(tester, 'activity-kcal'), '250');

    await tester.enterText(find.byKey(const Key('activity-distance')), '5,5');
    await tester.tap(find.byKey(const Key('activity-save')));
    await tester.pumpAndSettle();

    final added = activity.added.single;
    expect(added.kcal, 250);
    expect(added.durationMin, 45);
    expect(added.distanceM, 5500);
    expect(added.kind, ActivityKind.walking);
    expect(find.text('Walking'), findsOneWidget); // back on the activity list
  });

  testWidgets('a duration of 0 minutes is refused', (tester) async {
    final activity = FakeActivityRepository();
    await _pumpApp(tester, activity: activity);
    await _openAdd(tester);

    await tester.enterText(find.byKey(const Key('activity-minutes')), '0');
    await tester.tap(find.byKey(const Key('activity-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activity-error')), findsOneWidget);
    expect(activity.added, isEmpty);
  });

  testWidgets('imported workouts show the hint and can be deleted',
      (tester) async {
    final activity = FakeActivityRepository()
      ..activities.add(
        Activity(
          id: 'imp1',
          date: _today,
          kind: ActivityKind.running,
          durationMin: 30,
          kcal: 300,
          source: ActivitySource.healthConnect,
        ),
      )
      ..stepsByDay[dateKey(_today)] = 8500;
    await _pumpApp(tester, activity: activity);
    await tester.tap(find.byKey(const Key('nav-activity')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Imported'), findsOneWidget);
    expect(find.text('8500 steps'), findsOneWidget);
    expect(find.text('300 kcal burned'), findsOneWidget);

    await tester.tap(find.byKey(const Key('activity-delete-imp1')));
    await tester.pumpAndSettle();

    expect(activity.deleted, ['imp1']);
    expect(find.byKey(const Key('activity-empty')), findsOneWidget);
  });

  group('diary balance', () {
    FakeDiaryRepository diary({required double sport, bool count = true}) =>
        _BalanceDiary(
          burned: sport,
          count: count,
          entries: [
            diaryEntry(
                id: 'e1',
                date: _today,
                meal: Meal.lunch,
                name: 'Reis',
                grams: 300,
                kcal: 1500),
          ],
        );

    testWidgets('sport is added to the budget and shown in the formula',
        (tester) async {
      await _pumpApp(tester, diary: diary(sport: 300));

      expect(
        tester.widget<Text>(find.byKey(const Key('calorie-formula'))).data,
        'Target 2000 kcal + sport 300 kcal − eaten 1500 kcal = 800 kcal',
      );
      expect(tester.widget<Text>(find.byKey(const Key('calorie-value'))).data,
          '800 kcal');
      expect(find.byKey(const Key('diary-sport')), findsOneWidget);
    });

    testWidgets('with the switch off sport is shown but not added',
        (tester) async {
      await _pumpApp(tester, diary: diary(sport: 300, count: false));

      expect(tester.widget<Text>(find.byKey(const Key('calorie-value'))).data,
          '500 kcal');
      expect(
        tester.widget<Text>(find.byKey(const Key('calorie-formula'))).data,
        'Target 2000 kcal − eaten 1500 kcal = 500 kcal',
      );
    });
  });

  testWidgets('the profile switch saves count_activity_kcal', (tester) async {
    final profile = FakeProfileRepository(result: const Profile(weightKg: 80));
    await _pumpApp(tester, profile: profile);
    await tester.tap(find.byKey(const Key('nav-profile')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('count-sport')));
    await tester.pumpAndSettle();

    expect(profile.settingsChanges.single, {'count_activity_kcal': false});
  });
}

/// Diary fake whose days carry sport kcal and the profile switch.
class _BalanceDiary extends FakeDiaryRepository {
  _BalanceDiary({required this.burned, required this.count, super.entries});

  final double burned;
  final bool count;

  @override
  Future<DiaryDay> day(DateTime date) async {
    final base = await super.day(date);
    return DiaryDay(
      date: base.date,
      entries: base.entries,
      targets: base.targets,
      energyUnit: base.energyUnit,
      burnedKcal: burned,
      countActivityKcal: count,
    );
  }
}
