import 'package:flutter/material.dart';

/// TAMRA colours: date brown as seed, Material 3.
abstract final class AppTheme {
  static const Color seed = Color(0xFF7A4B2A);

  /// Light theme (default during the day).
  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
      );

  /// Dark theme, used when the phone is in dark mode.
  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
      );
}
