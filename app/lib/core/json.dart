/// Reading values from API JSON. DRF sends decimals as text ("52.00"), so numbers may
/// arrive as `String`, `int` or `double`.
library;

/// A number as double, or null when missing or not a number.
double? jsonDouble(Object? value) => switch (value) {
      final num number => number.toDouble(),
      final String text => double.tryParse(text),
      _ => null,
    };

/// A number as int (decimals are rounded), or null when missing or not a number.
int? jsonInt(Object? value) => switch (value) {
      final int number => number,
      final num number => number.round(),
      final String text => int.tryParse(text) ?? double.tryParse(text)?.round(),
      _ => null,
    };

/// A day as the API writes it: `YYYY-MM-DD` (the user's local day, no time zone).
String dateKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${_twoDigits(day.month)}-${_twoDigits(day.day)}';

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// Only the calendar day of [moment] (time set to midnight, local time).
DateTime dateOnly(DateTime moment) => DateTime(moment.year, moment.month, moment.day);

/// A number typed by the user: accepts "3.5" and "3,5"; null for empty or invalid text.
double? parseAmount(String? text) {
  final value = (text ?? '').trim().replaceAll(',', '.');
  if (value.isEmpty) return null;
  return double.tryParse(value);
}

/// [value] without a useless ".0" (100.0 → "100", 12.5 → "12.5").
String formatAmount(double value) =>
    value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1);
