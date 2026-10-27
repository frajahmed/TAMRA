import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/core/json.dart';
import 'package:tamra_app/core/nutrition/nutrition.dart';
import 'package:tamra_app/core/widgets/date_strip.dart';
import 'package:tamra_app/features/diary/domain/diary.dart';
import 'package:tamra_app/l10n/app_strings.dart';

import '../../helpers/fakes.dart';

void main() {
  test('DiaryEntry.fromJson reads the API format with decimal strings', () {
    final entry = DiaryEntry.fromJson({
      'id': 'e1',
      'date': '2026-10-26',
      'meal': 'lunch',
      'food': 'f1',
      'food_detail': {'id': 'f1', 'name': 'Reis', 'brand': 'Uncle'},
      'amount_g': '150.00',
      'unit_label': '',
      'kcal': '195.00',
      'protein': '4.05',
      'carbs': '42.00',
      'fat': '0.45',
    });

    expect(entry.meal, Meal.lunch);
    expect(entry.foodName, 'Reis');
    expect(entry.foodBrand, 'Uncle');
    expect(entry.amountG, 150);
    expect(entry.nutrients.kcal, 195);
    expect(dateKey(entry.date), '2026-10-26');
    expect(entry.per100g.kcal, closeTo(130, 1e-9));
  });

  test('DiaryDay sums the day and each meal and can hide entries', () {
    final day = DateTime(2026, 10, 26);
    final diary = DiaryDay(
      date: day,
      entries: [
        diaryEntry(id: 'a', date: day, meal: Meal.breakfast, name: 'A', grams: 50, kcal: 200),
        diaryEntry(id: 'b', date: day, meal: Meal.breakfast, name: 'B', grams: 50, kcal: 100),
        diaryEntry(id: 'c', date: day, meal: Meal.dinner, name: 'C', grams: 50, kcal: 400),
      ],
    );

    expect(diary.totals.kcal, 700);
    expect(diary.totalsOf(Meal.breakfast).kcal, 300);
    expect(diary.entriesOf(Meal.lunch), isEmpty);
    expect(diary.without({'a'}).totals.kcal, 500);
    expect(identical(diary.without({}), diary), isTrue);
  });

  test('NewDiaryEntry.toJson uses the API field names', () {
    final json = NewDiaryEntry(
      id: 'e1',
      date: DateTime(2026, 1, 5),
      meal: Meal.snack,
      foodId: 'f1',
      amountG: 12.5,
    ).toJson();
    expect(json, {
      'id': 'e1',
      'date': '2026-01-05',
      'meal': 'snack',
      'food': 'f1',
      'amount_g': '12.50',
    });
    final generated = NewDiaryEntry(date: DateTime(2026), meal: Meal.lunch, foodId: 'f', amountG: 1);
    expect(generated.id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
  });

  test('DayTargets and Meal handle missing or unknown values', () {
    expect(DayTargets.fromJson(null).kcal, isNull);
    expect(DayTargets.fromJson({'kcal': 1850, 'protein_g': '120'}).proteinG, 120);
    expect(Meal.fromApi('brunch'), Meal.snack);
    expect(EnergyUnit.fromApi('kj'), EnergyUnit.kj);
    expect(EnergyUnit.fromApi(null), EnergyUnit.kcal);
  });

  test('json helpers', () {
    expect(jsonInt('170.0'), 170);
    expect(jsonDouble('52.40'), 52.4);
    expect(jsonDouble(null), isNull);
    expect(formatAmount(100), '100');
    expect(formatAmount(12.5), '12.5');
    expect(parseAmount('3,5'), 3.5);
  });

  test('energy text in kcal and kJ, meal names in German', () {
    final strings = AppStrings(const Locale('de'));
    expect(strings.energy(520.4, EnergyUnit.kcal), '520 kcal');
    expect(strings.energy(100, EnergyUnit.kj), '418 kJ');
    expect(strings.meal(Meal.breakfast), 'Frühstück');
  });

  test('week start follows the locale (Sunday, Monday or Saturday)', () {
    final wednesday = DateTime(2026, 10, 28);
    expect(DateStrip.weekStart(wednesday, 0), DateTime(2026, 10, 25)); // Sunday
    expect(DateStrip.weekStart(wednesday, 1), DateTime(2026, 10, 26)); // Monday
    expect(DateStrip.weekStart(wednesday, 6), DateTime(2026, 10, 24)); // Saturday
  });
}
