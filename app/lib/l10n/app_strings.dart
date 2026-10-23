import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'translations.dart';

/// All user-facing texts of the app.
///
/// Rule: never write user-facing text directly in a widget.
/// Add a key to every language in `translations.dart`, then add a getter here.
class AppStrings {
  AppStrings(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = [
    Locale('de'),
    Locale('en'),
    Locale('fr'),
    Locale('it'),
    Locale('ar'),
  ];

  static const fallbackLocale = Locale('en');

  static const LocalizationsDelegate<AppStrings> delegate = _AppStringsDelegate();

  static AppStrings of(BuildContext context) {
    final strings = Localizations.of<AppStrings>(context, AppStrings);
    assert(strings != null, 'AppStrings not found. Is AppStrings.delegate registered?');
    return strings!;
  }

  /// Picks the device language if supported, otherwise English.
  static Locale resolveLocale(Locale? deviceLocale, Iterable<Locale> supported) {
    if (deviceLocale == null) return fallbackLocale;
    for (final locale in supported) {
      if (locale.languageCode == deviceLocale.languageCode) return locale;
    }
    return fallbackLocale;
  }

  @visibleForTesting
  String text(String key) {
    final value = translations[locale.languageCode]?[key] ??
        translations[fallbackLocale.languageCode]?[key];
    assert(value != null, 'Missing translation key: $key');
    return value ?? key;
  }

  String get appName => text('appName');
  String get homeTitle => text('homeTitle');
  String get homeSubtitle => text('homeSubtitle');
  String get debugTitle => text('debugTitle');
  String get checkServer => text('checkServer');
  String get serverOk => text('serverOk');
  String get serverError => text('serverError');
  String get loading => text('loading');
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => AppStrings.supportedLocales
      .any((supported) => supported.languageCode == locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) => SynchronousFuture(AppStrings(locale));

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
