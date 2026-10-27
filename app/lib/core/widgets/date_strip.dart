import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_strings.dart';
import '../json.dart';

/// One week as a row of days; tap a day to select it, arrows switch weeks.
///
/// The week starts on the locale's first weekday (Monday in Germany, Sunday in the US,
/// Saturday in many Arabic countries).
class DateStrip extends StatelessWidget {
  /// Creates the strip around [selected]; [today] can be fixed in tests.
  const DateStrip({super.key, required this.selected, required this.onSelected, this.today});

  /// The selected day.
  final DateTime selected;

  /// Called with the newly chosen day.
  final ValueChanged<DateTime> onSelected;

  /// Today's date (defaults to the current day).
  final DateTime? today;

  /// First day of the week that contains [day] for the given locale start index (0 = Sunday).
  static DateTime weekStart(DateTime day, int firstDayOfWeekIndex) {
    final sundayBased = day.weekday % 7;
    final offset = (sundayBased - firstDayOfWeekIndex + 7) % 7;
    return DateTime(day.year, day.month, day.day - offset);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final strings = AppStrings.of(context);
    final colors = AppColors.of(context);
    final now = dateOnly(today ?? DateTime.now());
    final start = weekStart(selected, localizations.firstDayOfWeekIndex);

    return Row(
      children: [
        IconButton(
          key: const Key('week-previous'),
          tooltip: strings.previousWeek,
          icon: const Icon(Icons.chevron_left),
          onPressed: () =>
              onSelected(DateTime(selected.year, selected.month, selected.day - 7)),
        ),
        for (var index = 0; index < 7; index++)
          Expanded(
            child: _DayCell(
              day: DateTime(start.year, start.month, start.day + index),
              weekdayLabel: localizations
                  .narrowWeekdays[(localizations.firstDayOfWeekIndex + index) % 7],
              selected: selected,
              today: now,
              colors: colors,
              onTap: onSelected,
            ),
          ),
        IconButton(
          key: const Key('week-next'),
          tooltip: strings.nextWeek,
          icon: const Icon(Icons.chevron_right),
          onPressed: () =>
              onSelected(DateTime(selected.year, selected.month, selected.day + 7)),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.weekdayLabel,
    required this.selected,
    required this.today,
    required this.colors,
    required this.onTap,
  });

  final DateTime day;
  final String weekdayLabel;
  final DateTime selected;
  final DateTime today;
  final AppColors colors;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = DateUtils.isSameDay(day, selected);
    final isToday = DateUtils.isSameDay(day, today);
    final textColor = isSelected ? colors.onBrand : colors.textPrimary;

    // Screen readers hear the full date ("Wednesday, 28 October 2026"), not "W 28".
    return Semantics(
      button: true,
      selected: isSelected,
      label: MaterialLocalizations.of(context).formatFullDate(day),
      excludeSemantics: true,
      child: InkWell(
      key: Key('day-${dateKey(day)}'),
      borderRadius: BorderRadius.circular(14),
      onTap: () => onTap(day),
      child: Container(
        margin: const EdgeInsetsDirectional.symmetric(horizontal: 2),
        padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isToday && !isSelected ? Border.all(color: colors.brand) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              weekdayLabel,
              style: TextStyle(color: isSelected ? colors.onBrand : colors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              '${day.day}',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
