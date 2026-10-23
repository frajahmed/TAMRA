import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/l10n/app_strings.dart';
import 'package:tamra_app/l10n/translations.dart';

void main() {
  test('every supported language has a translation table', () {
    for (final locale in AppStrings.supportedLocales) {
      expect(translations.containsKey(locale.languageCode), isTrue,
          reason: 'Missing language ${locale.languageCode}');
    }
  });

  test('every language has exactly the same keys as English, none empty', () {
    final englishKeys = translations['en']!.keys.toSet();
    translations.forEach((language, table) {
      expect(table.keys.toSet(), englishKeys, reason: 'Keys differ in "$language"');
      table.forEach((key, value) {
        expect(value.trim(), isNotEmpty, reason: 'Empty text "$key" in "$language"');
      });
    });
  });

  test('resolveLocale picks a supported device language', () {
    expect(
      AppStrings.resolveLocale(const Locale('ar', 'SA'), AppStrings.supportedLocales),
      const Locale('ar'),
    );
    expect(
      AppStrings.resolveLocale(const Locale('de', 'AT'), AppStrings.supportedLocales),
      const Locale('de'),
    );
  });

  test('resolveLocale falls back to English', () {
    expect(
      AppStrings.resolveLocale(const Locale('ja'), AppStrings.supportedLocales),
      AppStrings.fallbackLocale,
    );
    expect(
      AppStrings.resolveLocale(null, AppStrings.supportedLocales),
      AppStrings.fallbackLocale,
    );
  });

  test('getters return the right language', () {
    expect(AppStrings(const Locale('de')).homeTitle, 'Willkommen bei TAMRA');
    expect(AppStrings(const Locale('ar')).appName, 'تمرة');
  });
}
