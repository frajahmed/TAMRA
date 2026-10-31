import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/core/nutrition/nutrition.dart';
import 'package:tamra_app/features/diary/domain/diary.dart';
import 'package:tamra_app/features/diary/presentation/add_food_flow.dart';
import 'package:tamra_app/features/food/data/food_repository.dart';
import 'package:tamra_app/features/food/presentation/food_search_screen.dart';
import 'package:tamra_app/features/stats/domain/stats.dart';

import '../../helpers/fakes.dart';
import '../food/food_fakes.dart';

StatsSummary _week({double? change}) {
  final today = DateTime.now();
  return StatsSummary(
    days: [
      for (var offset = 6; offset >= 0; offset--)
        StatsDay(
          date: DateTime(today.year, today.month, today.day - offset),
          nutrients: NutrientAmounts(kcal: offset.isEven ? 1800 : 0),
        ),
    ],
    averages: const NutrientAmounts(kcal: 1800, protein: 90, carbs: 200, fat: 60),
    loggedDays: 4,
    kcalTarget: 2000,
    weightChangeKg: change,
  );
}

Future<void> _pumpApp(WidgetTester tester, {FakeStatsRepository? stats, FakeDiaryRepository? diary, FakeFoodRepository? foods}) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testApp(
      stats: stats,
      diary: diary,
      overrides: [if (foods != null) foodRepositoryProvider.overrideWithValue(foods)],
    ),
  );
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data ?? '';

void main() {
  testWidgets('statistics show the week, averages and the weight change', (tester) async {
    final stats = FakeStatsRepository(_week(change: -0.6));
    await _pumpApp(tester, stats: stats);

    await tester.tap(find.byKey(const Key('nav-stats')));
    await tester.pumpAndSettle();

    expect(stats.calls, hasLength(1));
    expect(find.byKey(const Key('stats-kcal-chart')), findsOneWidget);
    expect(find.text('Target: 2000 kcal'), findsOneWidget);
    expect(_text(tester, 'stats-average-kcal'), '1800 kcal');
    expect(_text(tester, 'stats-logged-days'), '4 of 7 days logged');
    expect(_text(tester, 'stats-weight-change'), '-0.6 kg');
  });

  testWidgets('without two weights the screen explains what is needed', (tester) async {
    await _pumpApp(tester, stats: FakeStatsRepository(_week()));
    await tester.tap(find.byKey(const Key('nav-stats')));
    await tester.pumpAndSettle();

    expect(_text(tester, 'stats-weight-change'), 'Log your weight on two days to see a change.');

    await tester.tap(find.byKey(const Key('open-weight')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('weight-empty')), findsOneWidget);
  });

  testWidgets('the request covers the last 7 days including today', (tester) async {
    final stats = FakeStatsRepository();
    await _pumpApp(tester, stats: stats);
    await tester.tap(find.byKey(const Key('nav-stats')));
    await tester.pumpAndSettle();

    final call = stats.calls.single;
    expect(call, endsWith(':day'));
    final range = call.split(':').first.split('..');
    final from = DateTime.parse(range[0]);
    final to = DateTime.parse(range[1]);
    expect(to.difference(from).inDays, 6);
  });

  testWidgets('range switch stays visible when statistics fail', (tester) async {
    final stats = FakeStatsRepository()..error = Exception('failed');
    await _pumpApp(tester, stats: stats);
    await tester.tap(find.byKey(const Key('nav-stats')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stats-retry')), findsOneWidget);
    expect(find.byKey(const Key('stats-range')), findsOneWidget);
  });

  test('StatsSummary.fromJson reads the API format', () {
    final summary = StatsSummary.fromJson({
      'from': '2026-10-20',
      'to': '2026-10-21',
      'kcal_target': 1850,
      'days': [
        {'date': '2026-10-20', 'kcal': '1720.50', 'protein': '95.00', 'carbs': '180.25',
         'fat': '60.00', 'water_ml': 1500, 'weight_kg': '75.5'},
        {'date': '2026-10-21', 'kcal': '0.00', 'protein': '0.00', 'carbs': '0.00',
         'fat': '0.00', 'water_ml': 0, 'weight_kg': null},
      ],
      'averages': {'kcal': '1720.50', 'protein': '95.00', 'carbs': '180.25', 'fat': '60.00',
                   'logged_days': 1},
      'weight_change_kg': null,
    });
    expect(summary.days, hasLength(2));
    expect(summary.days.first.nutrients.kcal, 1720.5);
    expect(summary.days.first.weightKg, 75.5);
    expect(summary.days.last.weightKg, isNull);
    expect(summary.loggedDays, 1);
    expect(summary.kcalTarget, 1850);
    expect(summary.weightChangeKg, isNull);
  });

  group('navigation dock', () {
    testWidgets('tabs switch between diary, statistics, activity and profile', (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.byKey(const Key('nav-activity')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('activity-coming')), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav-profile')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile-logout')), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav-diary')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-title')), findsOneWidget);
    });

    testWidgets('the centre button adds food to the meal of the time of day', (tester) async {
      final diary = FakeDiaryRepository();
      await _pumpApp(tester, diary: diary, foods: FakeFoodRepository()..results = [apple]);
      await tester.tap(find.byKey(const Key('nav-stats')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nav-scan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sheet-search')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('food-search-field')), 'apfel');
      await tester.pump(searchDebounce);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('food-result-f1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('entry-save')));
      await tester.pumpAndSettle();

      expect(diary.added.single.meal, mealForTime(DateTime.now()));
      expect(find.byKey(const Key('home-title')), findsOneWidget);
    });

    test('meal for the time of day', () {
      expect(mealForTime(DateTime(2026, 1, 1, 7)), Meal.breakfast);
      expect(mealForTime(DateTime(2026, 1, 1, 12)), Meal.lunch);
      expect(mealForTime(DateTime(2026, 1, 1, 19)), Meal.dinner);
      expect(mealForTime(DateTime(2026, 1, 1, 23)), Meal.snack);
    });
  });

  group('ranges', () {
    testWidgets('4 weeks and 12 months ask for weekly and monthly groups', (tester) async {
      final stats = FakeStatsRepository();
      await _pumpApp(tester, stats: stats);
      await tester.tap(find.byKey(const Key('nav-stats')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('4 weeks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12 months'));
      await tester.pumpAndSettle();

      expect(stats.calls.map((call) => call.split(':').last), ['day', 'week', 'month']);
    });

    test('range starts: 7 days, Monday 3 weeks back, first of the month 11 months back', () {
      final wednesday = DateTime(2026, 10, 28);
      expect(StatsRange.days7.start(wednesday), DateTime(2026, 10, 22));
      expect(StatsRange.weeks4.start(wednesday), DateTime(2026, 10, 5));
      expect(StatsRange.months12.start(wednesday), DateTime(2025, 11));
    });
  });
}
