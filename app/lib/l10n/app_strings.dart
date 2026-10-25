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

  /// The texts for the current language of [context].
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

  /// Text of [key] in the current language, English as fallback.
  @visibleForTesting
  String text(String key) {
    final value = translations[locale.languageCode]?[key] ??
        translations[fallbackLocale.languageCode]?[key];
    assert(value != null, 'Missing translation key: $key');
    return value ?? key;
  }

  /// Replaces {name} placeholders.
  String _fill(String key, Map<String, Object> values) {
    var result = text(key);
    values.forEach((name, value) => result = result.replaceAll('{$name}', '$value'));
    return result;
  }

  String get appName => text('appName');
  String get homeTitle => text('homeTitle');
  String get homeSubtitle => text('homeSubtitle');
  String get debugTitle => text('debugTitle');
  String get checkServer => text('checkServer');
  String get serverOk => text('serverOk');
  String get serverError => text('serverError');
  String get loading => text('loading');

  // Auth
  String get login => text('login');
  String get register => text('register');
  String get email => text('email');
  String get password => text('password');
  String get noAccount => text('noAccount');
  String get haveAccount => text('haveAccount');
  String get logout => text('logout');
  String get genericError => text('genericError');
  String get emailInvalid => text('emailInvalid');
  String get passwordTooShort => text('passwordTooShort');
  String get fieldRequired => text('fieldRequired');

  // Consent and onboarding
  String get consentTitle => text('consentTitle');
  String get consentText => text('consentText');
  String get consentCheckbox => text('consentCheckbox');
  String get continueButton => text('continueButton');
  String get onboardingTitle => text('onboardingTitle');
  /// "Step 2 of 6" in the onboarding.
  String stepOf(int current, int total) =>
      _fill('stepOf', {'current': current, 'total': total});
  String get goalQuestion => text('goalQuestion');
  String get goalLose => text('goalLose');
  String get goalMaintain => text('goalMaintain');
  String get goalGain => text('goalGain');
  String get sexQuestion => text('sexQuestion');
  String get sexFemale => text('sexFemale');
  String get sexMale => text('sexMale');
  String get birthYearQuestion => text('birthYearQuestion');
  String get heightQuestion => text('heightQuestion');
  String get weightQuestion => text('weightQuestion');
  String get activityQuestion => text('activityQuestion');
  String get activitySedentary => text('activitySedentary');
  String get activityLight => text('activityLight');
  String get activityModerate => text('activityModerate');
  String get activityActive => text('activityActive');
  String get activityVeryActive => text('activityVeryActive');
  String get next => text('next');
  String get back => text('back');
  String get save => text('save');
  String invalidRange(num min, num max) => _fill('invalidRange', {'min': min, 'max': max});
  String get resultTitle => text('resultTitle');
  String resultKcal(int kcal) => _fill('resultKcal', {'kcal': kcal});
  String get resultFormula => text('resultFormula');
  String get protein => text('protein');
  String get carbs => text('carbs');
  String get fat => text('fat');
  String get startButton => text('startButton');

  // --- Food search and own food ---------------------------------------------
  String get foodSearchTitle => text('foodSearchTitle');
  String get foodSearchHint => text('foodSearchHint');
  String get foodSearchMinChars => text('foodSearchMinChars');
  String foodNoResults(String query) => _fill('foodNoResults', {'query': query});
  String get foodCreateCustom => text('foodCreateCustom');
  String get retry => text('retry');
  String kcalPer100g(int kcal) => _fill('kcalPer100g', {'kcal': kcal});
  String get customFoodTitle => text('customFoodTitle');
  String get foodName => text('foodName');
  String get foodBrand => text('foodBrand');
  String get barcodeOptional => text('barcodeOptional');
  String get barcodeInvalid => text('barcodeInvalid');
  String get per100gHeading => text('per100gHeading');
  String get kcalLabel => text('kcalLabel');
  String gramsLabel(String name) => _fill('gramsLabel', {'name': name});
  String get sugar => text('sugar');
  String get fiber => text('fiber');
  String get salt => text('salt');
  String get servingSize => text('servingSize');
  String get invalidNumber => text('invalidNumber');
  String get macrosTooHigh => text('macrosTooHigh');

  // --- Barcode scan ---------------------------------------------------------
  String get scanTitle => text('scanTitle');
  String get scanHint => text('scanHint');
  String get scanNotFoundTitle => text('scanNotFoundTitle');
  String scanNotFoundText(String code) => _fill('scanNotFoundText', {'code': code});
  String get scanAgain => text('scanAgain');
  String get cameraDeniedText => text('cameraDeniedText');
  String get openSettings => text('openSettings');
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
