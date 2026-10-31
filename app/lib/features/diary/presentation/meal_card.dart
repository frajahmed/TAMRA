import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_strings.dart';
import '../domain/diary.dart';

/// Card of one meal: name, energy of the meal, quick-add button and the entries.
class MealCard extends StatelessWidget {
  /// Creates the card for [meal]; [children] are the entry tiles.
  const MealCard({
    super.key,
    required this.meal,
    required this.energyText,
    required this.onAdd,
    this.onCopyFromYesterday,
    this.children = const [],
  });

  /// The meal shown.
  final Meal meal;

  /// Formatted energy of all entries of the meal.
  final String energyText;

  /// Opens the food search for this meal.
  final VoidCallback onAdd;

  /// Copies this meal from the day before; shown only while the meal is empty.
  final VoidCallback? onCopyFromYesterday;

  /// Entry tiles of the meal.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = AppColors.of(context);

    return Card(
      key: Key('meal-${meal.name}'),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(strings.meal(meal),
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Text(energyText, style: TextStyle(color: colors.textSecondary)),
                IconButton(
                  key: Key('add-${meal.name}'),
                  tooltip: strings.addFood,
                  color: colors.brand,
                  icon: const Icon(Icons.add_circle),
                  onPressed: onAdd,
                ),
              ],
            ),
            ...children,
            if (children.isEmpty && onCopyFromYesterday != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: Key('copy-${meal.name}'),
                  icon: const Icon(Icons.content_copy, size: 18),
                  label: Text(strings.copyMealFromYesterday),
                  onPressed: onCopyFromYesterday,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
