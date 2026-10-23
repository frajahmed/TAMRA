import 'package:flutter/material.dart';

/// TAMRA colours: date brown as seed, Material 3.
abstract final class AppTheme {
  static const Color seed = Color(0xFF7A4B2A);

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
      );
}
