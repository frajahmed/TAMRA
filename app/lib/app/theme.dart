import 'package:flutter/material.dart';

/// TAMRA colour tokens for light and dark mode (see docs/DESIGN.md).
///
/// Brand: date brown for buttons and identity. Progress (calorie arc, charts): blue.
/// Macros always use the same colours so users recognise them on every screen.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  /// Creates a full set of tokens; use [light] or [dark].
  const AppColors({
    required this.background,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.brand,
    required this.progress,
    required this.carbs,
    required this.fat,
    required this.protein,
  });

  /// Page background behind the cards.
  final Color background;

  /// Cards, sheets and the navigation dock.
  final Color surface;

  /// Thin card border and dividers (replaces shadows in dark mode).
  final Color border;

  /// Main text.
  final Color textPrimary;

  /// Labels, hints and secondary numbers.
  final Color textSecondary;

  /// TAMRA date brown: primary buttons, logo, selected navigation item.
  final Color brand;

  /// Progress blue: calorie arc, charts, goal lines.
  final Color progress;

  /// Carbohydrates in rings, bars and labels.
  final Color carbs;

  /// Fat in rings, bars and labels.
  final Color fat;

  /// Protein in rings, bars and labels.
  final Color protein;

  /// Tokens for light mode.
  static const light = AppColors(
    background: Color(0xFFF4F6F9),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE5E7EB),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF6B7280),
    brand: Color(0xFF7A4B2A),
    progress: Color(0xFF2563EB),
    carbs: Color(0xFFF97316),
    fat: Color(0xFF84CC16),
    protein: Color(0xFF3B82F6),
  );

  /// Tokens for dark mode: no pure black, slightly brighter accents.
  static const dark = AppColors(
    background: Color(0xFF0F1117),
    surface: Color(0xFF1A1D26),
    border: Color(0xFF2D313E),
    textPrimary: Color(0xFFF9FAFB),
    textSecondary: Color(0xFF9CA3AF),
    brand: Color(0xFFC08A5B),
    progress: Color(0xFF3B82F6),
    carbs: Color(0xFFFB923C),
    fat: Color(0xFFA3E635),
    protein: Color(0xFF60A5FA),
  );

  /// The tokens of the current theme.
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? brand,
    Color? progress,
    Color? carbs,
    Color? fat,
    Color? protein,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      brand: brand ?? this.brand,
      progress: progress ?? this.progress,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      protein: protein ?? this.protein,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      progress: Color.lerp(progress, other.progress, t)!,
      carbs: Color.lerp(carbs, other.carbs, t)!,
      fat: Color.lerp(fat, other.fat, t)!,
      protein: Color.lerp(protein, other.protein, t)!,
    );
  }
}

/// Material 3 themes built from [AppColors]; the app follows the phone's light/dark setting.
abstract final class AppTheme {
  /// Brand seed colour (date brown).
  static const Color seed = Color(0xFF7A4B2A);

  /// Light theme: soft grey-blue background, white cards with a light border.
  static ThemeData light() => _build(AppColors.light, Brightness.light);

  /// Dark theme: deep background, charcoal cards with a subtle border instead of shadows.
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness).copyWith(
      primary: colors.brand,
      secondary: colors.progress,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      outlineVariant: colors.border,
    );
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: colors.border),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: brightness == Brightness.light ? 1 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        surfaceTintColor: Colors.transparent,
        shape: cardShape,
        margin: EdgeInsetsDirectional.zero,
      ),
      dividerTheme: DividerThemeData(color: colors.border, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.brand,
          foregroundColor: Colors.white,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.border),
        ),
      ),
    );
  }
}
