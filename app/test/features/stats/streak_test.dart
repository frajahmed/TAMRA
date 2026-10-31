import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/core/json.dart';
import 'package:tamra_app/features/diary/data/diary_repository.dart';
import 'package:tamra_app/features/stats/domain/streak.dart';

import '../../helpers/fakes.dart';

Streak _streak({
  int currentDays = 5,
  int longestDays = 12,
  bool loggedToday = false,
  List<StreakBadge>? badges,
}) =>
    Streak(
      date: dateOnly(DateTime.now()),
      currentDays: currentDays,
      longestDays: longestDays,
      loggedToday: loggedToday,
      badges: badges ??
          const [
            StreakBadge(days: 7, earned: false),
            StreakBadge(days: 30, earned: false),
            StreakBadge(days: 100, earned: false),
          ],
    );

Future<void> _pump(
  WidgetTester tester, {
  required FakeStatsRepository stats,
  Locale locale = const Locale('en'),
  DateTime? selectedDay,
}) async {
  useTallView(tester);
  await tester.pumpWidget(
    testApp(
      locale: locale,
      stats: stats,
      overrides: [
        if (selectedDay != null)
          selectedDayProvider.overrideWith(
            () => _FixedSelectedDay(selectedDay),
          ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

class _FixedSelectedDay extends SelectedDay {
  _FixedSelectedDay(this.day);

  final DateTime day;

  @override
  DateTime build() => dateOnly(day);
}

void main() {
  test('Streak.fromJson reads the API format', () {
    final streak = Streak.fromJson({
      'date': '2026-11-02',
      'current_days': 5,
      'longest_days': 12,
      'logged_today': false,
      'badges': [
        {'days': 7, 'earned': true, 'earned_on': '2026-10-15'},
        {'days': 30, 'earned': false, 'earned_on': null},
        {'days': 100, 'earned': false, 'earned_on': null},
      ],
    });

    expect(streak.date, DateTime(2026, 11, 2));
    expect(streak.currentDays, 5);
    expect(streak.longestDays, 12);
    expect(streak.loggedToday, isFalse);
    expect(streak.badges, hasLength(3));
    expect(streak.badges.first.earned, isTrue);
    expect(streak.badges.first.earnedOn, DateTime(2026, 10, 15));
    expect(streak.badges[1].earnedOn, isNull);
  });

  testWidgets('diary shows the current streak and keep-going hint',
      (tester) async {
    final stats = FakeStatsRepository()..streakResult = _streak();

    await _pump(tester, stats: stats);

    expect(find.byKey(const Key('streak-chip')), findsOneWidget);
    expect(find.text('5 days in a row'), findsOneWidget);
    expect(find.text('Log today to keep it going'), findsOneWidget);
    expect(find.text('Best: 12 days'), findsOneWidget);
  });

  testWidgets('logged today hides the keep-going hint', (tester) async {
    final stats = FakeStatsRepository()
      ..streakResult = _streak(loggedToday: true);

    await _pump(tester, stats: stats);

    expect(find.byKey(const Key('streak-chip')), findsOneWidget);
    expect(find.text('Log today to keep it going'), findsNothing);
  });

  testWidgets('zero current days invites the user to start', (tester) async {
    final stats = FakeStatsRepository()
      ..streakResult = _streak(currentDays: 0, longestDays: 0);

    await _pump(tester, stats: stats);

    expect(find.text('Log something today to start a streak'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department), findsNothing);
  });

  testWidgets('repository errors hide the streak without an error message',
      (tester) async {
    final stats = FakeStatsRepository()..streakError = Exception('offline');

    await _pump(tester, stats: stats);

    expect(find.byKey(const Key('streak-chip')), findsNothing);
    expect(find.text('Something went wrong. Please try again.'), findsNothing);
  });

  testWidgets('streak is hidden when another diary day is selected',
      (tester) async {
    final stats = FakeStatsRepository()..streakResult = _streak();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    await _pump(tester, stats: stats, selectedDay: yesterday);

    expect(find.byKey(const Key('streak-chip')), findsNothing);
    expect(stats.streakCalls, isEmpty);
  });

  testWidgets('statistics show earned and open badges', (tester) async {
    final stats = FakeStatsRepository()
      ..streakResult = _streak(
        currentDays: 7,
        longestDays: 7,
        loggedToday: true,
        badges: [
          StreakBadge(
            days: 7,
            earned: true,
            earnedOn: DateTime(2026, 10, 15),
          ),
          const StreakBadge(days: 30, earned: false),
          const StreakBadge(days: 100, earned: false),
        ],
      );

    await _pump(tester, stats: stats);
    await tester.tap(find.byKey(const Key('nav-stats')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('badge-7')), findsOneWidget);
    final badgeContext = tester.element(find.byKey(const Key('badge-7')));
    final earnedDate = MaterialLocalizations.of(badgeContext)
        .formatMediumDate(DateTime(2026, 10, 15));
    expect(find.text('Earned $earnedDate'), findsOneWidget);
    expect(find.byKey(const Key('badge-30')), findsOneWidget);
    expect(find.text('23 days to go'), findsOneWidget);
  });

  testWidgets('Arabic streak renders right-to-left without exceptions',
      (tester) async {
    final stats = FakeStatsRepository()..streakResult = _streak();

    await _pump(tester, stats: stats, locale: const Locale('ar'));

    expect(find.byKey(const Key('streak-chip')), findsOneWidget);
    expect(find.text('أيام متتالية: 5'), findsOneWidget);
    final chipContext = tester.element(find.byKey(const Key('streak-chip')));
    expect(Directionality.of(chipContext), TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });
}
