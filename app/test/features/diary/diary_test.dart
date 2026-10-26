import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/core/api/api_client.dart';
import 'package:tamra_app/core/json.dart';
import 'package:tamra_app/core/nutrition/nutrition.dart';
import 'package:tamra_app/features/diary/domain/diary.dart';
import 'package:tamra_app/features/food/data/food_repository.dart';
import 'package:tamra_app/features/food/presentation/food_search_screen.dart';

import '../../helpers/fakes.dart';
import '../food/food_fakes.dart';

final _today = dateOnly(DateTime.now());

/// Two entries today: breakfast 300 kcal, lunch 260 kcal (total 560).
FakeDiaryRepository _diaryWithTwoEntries({
  DayTargets targets = const DayTargets(kcal: 2000, proteinG: 150, carbsG: 200, fatG: 67),
  EnergyUnit unit = EnergyUnit.kcal,
}) {
  return FakeDiaryRepository(
    targets: targets,
    energyUnit: unit,
    entries: [
      diaryEntry(
        id: 'b1',
        date: _today,
        meal: Meal.breakfast,
        name: 'Haferflocken',
        grams: 80,
        kcal: 300,
      ),
      diaryEntry(id: 'l1', date: _today, meal: Meal.lunch, name: 'Reis', grams: 200, kcal: 260),
    ],
  );
}

Future<void> _openDiary(
  WidgetTester tester,
  FakeDiaryRepository diary, {
  Locale locale = const Locale('en'),
  FakeFoodRepository? foods,
}) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testApp(
      locale: locale,
      diary: diary,
      overrides: [
        if (foods != null) foodRepositoryProvider.overrideWithValue(foods),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data ?? '';

void main() {
  testWidgets('shows remaining calories, the formula, macros and the meals', (tester) async {
    await _openDiary(tester, _diaryWithTwoEntries());

    expect(_text(tester, 'calorie-value'), '1440 kcal');
    expect(find.text('left'), findsOneWidget);
    expect(_text(tester, 'calorie-formula'), 'Target 2000 kcal − eaten 560 kcal = 1440 kcal');
    expect(find.text('70 / 200 g'), findsOneWidget); // carbs = 560 / 8
    expect(find.text('Haferflocken'), findsOneWidget);
    expect(find.text('80 g'), findsOneWidget);
    expect(find.text('Reis'), findsOneWidget);
    for (final meal in Meal.values) {
      expect(find.byKey(Key('meal-${meal.name}')), findsOneWidget);
    }
  });

  testWidgets('shows kilojoules when the profile says kJ', (tester) async {
    await _openDiary(tester, _diaryWithTwoEntries(unit: EnergyUnit.kj));

    expect(_text(tester, 'calorie-value'), '6025 kJ'); // 1440 kcal × 4.184
  });

  testWidgets('going over the target says "over" without alarm', (tester) async {
    await _openDiary(tester, _diaryWithTwoEntries(targets: const DayTargets(kcal: 500)));

    expect(_text(tester, 'calorie-value'), '60 kcal');
    expect(find.text('over'), findsOneWidget);
  });

  testWidgets('without targets only the eaten calories are shown', (tester) async {
    await _openDiary(tester, _diaryWithTwoEntries(targets: const DayTargets()));

    expect(_text(tester, 'calorie-value'), '560 kcal');
    expect(find.byKey(const Key('calorie-formula')), findsNothing);
  });

  testWidgets('German and Arabic render the diary', (tester) async {
    await _openDiary(tester, _diaryWithTwoEntries(), locale: const Locale('de'));
    expect(find.text('Mittagessen'), findsOneWidget);
    expect(find.text('übrig'), findsOneWidget);

    await _openDiary(tester, _diaryWithTwoEntries(), locale: const Locale('ar'));
    expect(find.text('الغداء'), findsOneWidget);
    expect(find.text('متبقية'), findsOneWidget);
  });

  testWidgets('add flow: + → search → amount → saved and shown', (tester) async {
    final diary = FakeDiaryRepository();
    await _openDiary(tester, diary, foods: FakeFoodRepository()..results = [apple]);

    await tester.tap(find.byKey(const Key('add-lunch')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('food-search-field')), 'apfel');
    await tester.pump(searchDebounce);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('food-result-f1')));
    await tester.pumpAndSettle();

    expect(find.text('Add to diary'), findsOneWidget);
    expect(_text(tester, 'entry-preview-kcal'), '52 kcal'); // 100 g by default
    await tester.enterText(find.byKey(const Key('entry-amount')), '150');
    await tester.pump();
    expect(_text(tester, 'entry-preview-kcal'), '79 kcal');

    await tester.tap(find.byKey(const Key('entry-save')));
    await tester.pumpAndSettle();

    final added = diary.added.single;
    expect(added.meal, Meal.lunch);
    expect(added.foodId, 'f1');
    expect(added.amountG, 150);
    expect(dateKey(added.date), dateKey(_today));
    expect(find.text('Added'), findsOneWidget);
  });

  testWidgets('an invalid amount is not saved', (tester) async {
    final diary = FakeDiaryRepository();
    await _openDiary(tester, diary, foods: FakeFoodRepository()..results = [apple]);
    await tester.tap(find.byKey(const Key('add-snack')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('food-search-field')), 'apfel');
    await tester.pump(searchDebounce);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('food-result-f1')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('entry-amount')), '0');
    await tester.tap(find.byKey(const Key('entry-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('entry-error')), findsOneWidget);
    expect(diary.added, isEmpty);
  });

  testWidgets('tap an entry to change amount and meal', (tester) async {
    final diary = _diaryWithTwoEntries();
    await _openDiary(tester, diary);

    await tester.tap(find.byKey(const Key('entry-b1')));
    await tester.pumpAndSettle();
    expect(find.text('Edit entry'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('entry-amount')), '40');
    await tester.tap(find.byKey(const Key('entry-meal')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Snacks').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('entry-save')));
    await tester.pumpAndSettle();

    expect(diary.updated, ['b1:40.0:snack']);
  });

  testWidgets('swipe deletes; undo keeps the entry and calls no DELETE', (tester) async {
    final diary = _diaryWithTwoEntries();
    await _openDiary(tester, diary);

    await tester.drag(find.byKey(const Key('entry-b1')), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Haferflocken'), findsNothing);
    expect(find.text('Entry deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('Haferflocken'), findsOneWidget);
    expect(diary.deleted, isEmpty);
  });

  testWidgets('swipe without undo deletes on the server after 4 seconds', (tester) async {
    final diary = _diaryWithTwoEntries();
    await _openDiary(tester, diary);

    await tester.drag(find.byKey(const Key('entry-b1')), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(diary.deleted, isEmpty);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(diary.deleted, ['b1']);
    expect(find.text('Haferflocken'), findsNothing);
    expect(_text(tester, 'calorie-value'), '1740 kcal');
  });

  testWidgets('the week arrows load another day', (tester) async {
    final diary = _diaryWithTwoEntries();
    await _openDiary(tester, diary);

    await tester.tap(find.byKey(const Key('week-previous')));
    await tester.pumpAndSettle();

    final lastWeek = DateTime(_today.year, _today.month, _today.day - 7);
    expect(diary.requestedDays.last, lastWeek);
    expect(find.text('Today'), findsNothing);
    expect(find.text('Haferflocken'), findsNothing);
  });

  testWidgets('a loading error offers retry', (tester) async {
    final diary = _diaryWithTwoEntries()
      ..dayError = const ApiError(code: 'network_error', message: 'offline');
    await _openDiary(tester, diary);
    expect(find.byKey(const Key('diary-error')), findsOneWidget);

    diary.dayError = null;
    await tester.tap(find.byKey(const Key('diary-retry')));
    await tester.pumpAndSettle();

    expect(find.text('Haferflocken'), findsOneWidget);
  });
}
