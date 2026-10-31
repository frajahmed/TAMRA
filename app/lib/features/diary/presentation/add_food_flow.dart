import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/nutrition/nutrition.dart';
import '../../food/domain/food.dart';
import '../data/diary_repository.dart';
import '../domain/diary.dart';
import 'entry_editor_screen.dart';

/// The meal that fits the time of day (used when food is added from the scan button).
Meal mealForTime(DateTime time) => switch (time.hour) {
      < 10 => Meal.breakfast,
      < 15 => Meal.lunch,
      < 21 => Meal.dinner,
      _ => Meal.snack,
    };

/// Opens the entry editor for [food] on the day shown in the diary and reloads the day
/// after saving. Returns true when the entry was saved.
Future<bool> addFoodToDiary(
  BuildContext context,
  WidgetRef ref, {
  required Food food,
  required Meal meal,
}) async {
  final day = ref.read(selectedDayProvider);
  final unit = ref.read(diaryDayProvider(day)).valueOrNull?.energyUnit ??
      EnergyUnit.kcal;
  final saved = await context.push<bool>(
    AppRoutes.diaryEntry,
    extra: EntryEditorArgs.add(
        food: food, meal: meal, date: day, energyUnit: unit),
  );
  if (saved == true) ref.invalidate(diaryDayProvider(day));
  return saved == true;
}
