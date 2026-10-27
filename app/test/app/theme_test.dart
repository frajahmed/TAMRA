import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/app/theme.dart';

void main() {
  test('light and dark theme carry the TAMRA colour tokens', () {
    final light = AppTheme.light().extension<AppColors>()!;
    final dark = AppTheme.dark().extension<AppColors>()!;

    expect(light.background, const Color(0xFFF4F6F9));
    expect(dark.background, const Color(0xFF0F1117));
    expect(dark.surface, isNot(const Color(0xFF000000)));
    expect(light.brand, AppTheme.seed);
    expect(light.progress, const Color(0xFF2563EB));
  });

  test('macro colours differ from each other in both modes', () {
    for (final colors in [AppColors.light, AppColors.dark]) {
      expect({colors.carbs, colors.fat, colors.protein}, hasLength(3));
    }
  });

  test('lerp between light and dark ends at dark', () {
    final result = AppColors.light.lerp(AppColors.dark, 1);
    expect(result.surface, AppColors.dark.surface);
    expect(result.carbs, AppColors.dark.carbs);
  });

  testWidgets('AppColors.of reads the tokens from the theme', (tester) async {
    late AppColors found;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) {
            found = AppColors.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(found.surface, AppColors.dark.surface);
  });

  group('contrast (WCAG 2.1)', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final light = la > lb ? la : lb;
      final dark = la > lb ? lb : la;
      return (light + 0.05) / (dark + 0.05);
    }

    for (final (name, colors) in [('light', AppColors.light), ('dark', AppColors.dark)]) {
      test('$name: text needs 4.5:1 on background and cards', () {
        for (final text in [colors.textPrimary, colors.textSecondary]) {
          for (final back in [colors.background, colors.surface]) {
            expect(contrast(text, back), greaterThanOrEqualTo(4.5));
          }
        }
        expect(contrast(colors.onBrand, colors.brand), greaterThanOrEqualTo(4.5));
      });

      test('$name: macro, progress and brand colours need 3:1 on cards (graphics)', () {
        for (final graphic in [
          colors.carbs,
          colors.fat,
          colors.protein,
          colors.progress,
          colors.brand,
        ]) {
          expect(contrast(graphic, colors.surface), greaterThanOrEqualTo(3.0));
        }
      });
    }
  });
}
