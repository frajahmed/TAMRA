import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/json.dart';
import '../core/nutrition/nutrition.dart';
import '../features/diary/domain/diary.dart';
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

  // --- Diary ----------------------------------------------------------------
  String get today => text('today');
  String get caloriesLeft => text('caloriesLeft');
  String get caloriesOver => text('caloriesOver');
  String get addFood => text('addFood');
  String get entryDeleted => text('entryDeleted');
  String get undo => text('undo');
  String get addEntryTitle => text('addEntryTitle');
  String get editEntryTitle => text('editEntryTitle');
  String get amountLabel => text('amountLabel');
  String get mealLabel => text('mealLabel');
  String get previousWeek => text('previousWeek');
  String get nextWeek => text('nextWeek');
  String gramsValue(Object value) => _fill('gramsValue', {'value': value});
  /// "45 / 130 g" under a macro bar.
  String gramsProgress(num value, num target) =>
      _fill('gramsProgress', {'value': value, 'target': target});
  String oneServing(num grams) => _fill('oneServing', {'grams': grams});
  /// The visible calorie formula under the arc (values already formatted).
  String calorieFormula({required String target, required String eaten, required String remaining}) =>
      _fill('calorieFormula', {'target': target, 'eaten': eaten, 'remaining': remaining});

  // --- Navigation, weight, water, statistics ---------------------------------------
  String get navDiary => text('navDiary');
  String get navStats => text('navStats');
  String get navActivity => text('navActivity');
  String get navProfile => text('navProfile');
  String get comingSoon => text('comingSoon');
  String get water => text('water');
  String get waterAdd => text('waterAdd');
  String get waterRemove => text('waterRemove');
  String get weightTitle => text('weightTitle');
  String get weightAdd => text('weightAdd');
  String get weightEmpty => text('weightEmpty');
  String get dateLabel => text('dateLabel');
  String get delete => text('delete');
  String get cancel => text('cancel');
  String get statsLast7Days => text('statsLast7Days');
  String get statsAverage => text('statsAverage');
  String get statsWeightChange => text('statsWeightChange');
  String get statsNoWeightChange => text('statsNoWeightChange');
  String get statsTarget => text('statsTarget');
  String get openWeight => text('openWeight');
  String get kcalChartLabel => text('kcalChartLabel');
  String get weightChartLabel => text('weightChartLabel');
  String waterProgress(int value, int goal) => _fill('waterProgress', {'value': value, 'goal': goal});
  /// "5 of 7 days logged" in the statistics.
  String statsLoggedDays(int count, int total) =>
      _fill('statsLoggedDays', {'count': count, 'total': total});

  /// Label of the weight input in the user's unit.
  String weightLabel(WeightUnit unit) =>
      unit == WeightUnit.lb ? text('weightLabelLb') : text('weightLabelKg');

  /// [kg] shown in the user's unit with one decimal, e.g. "75.5 kg" or "166.4 lb".
  String weight(double kg, WeightUnit unit, {bool signed = false}) {
    final value = double.parse(unit.fromKg(kg).toStringAsFixed(1));
    final number = formatAmount(value);
    final shown = signed && value > 0 ? '+$number' : number;
    return unit == WeightUnit.lb
        ? _fill('weightValueLb', {'value': shown})
        : _fill('weightValueKg', {'value': shown});
  }

  // --- Settings ---------------------------------------------------------------
  String get settingsTarget => text('settingsTarget');
  String get noTargetYet => text('noTargetYet');
  String get settingsUnits => text('settingsUnits');
  String get weightUnitLabel => text('weightUnitLabel');
  String get energyUnitLabel => text('energyUnitLabel');
  String get languageLabel => text('languageLabel');
  String get languageDevice => text('languageDevice');
  String get privacyTitle => text('privacyTitle');
  String get exportData => text('exportData');
  String get exportDataHint => text('exportDataHint');
  String get withdrawConsent => text('withdrawConsent');
  String get withdrawConsentText => text('withdrawConsentText');
  String get withdrawConfirm => text('withdrawConfirm');
  String get deleteAccount => text('deleteAccount');
  String get deleteAccountText => text('deleteAccountText');
  String get deleteConfirm => text('deleteConfirm');

  /// Names of the app languages, each written in its own language (never translated).
  static const languageNames = {
    'de': 'Deutsch',
    'en': 'English',
    'fr': 'Français',
    'it': 'Italiano',
    'ar': 'العربية',
  };

  /// Name of a meal.
  String meal(Meal meal) => switch (meal) {
        Meal.breakfast => text('mealBreakfast'),
        Meal.lunch => text('mealLunch'),
        Meal.dinner => text('mealDinner'),
        Meal.snack => text('mealSnack'),
      };

  /// [kcal] as "520 kcal" or, when the user chose kJ, "2176 kJ" (rounded to whole numbers).
  String energy(double kcal, EnergyUnit unit) => switch (unit) {
        EnergyUnit.kcal => _fill('kcalValue', {'value': kcal.round()}),
        EnergyUnit.kj => _fill('kjValue', {'value': Units.kcalToKj(kcal).round()}),
      };
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
