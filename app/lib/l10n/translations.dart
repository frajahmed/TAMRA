/// Texts per language code. Every language must contain every key
/// (checked by test/l10n/app_strings_test.dart).
///
/// If a translation is not ready yet, copy the English text and add
/// the comment `// TODO-TRANSLATE` at the end of the line.
const Map<String, Map<String, String>> translations = {
  'en': {
    'appName': 'TAMRA',
    'homeTitle': 'Welcome to TAMRA',
    'homeSubtitle': 'Your fair nutrition tracker',
    'debugTitle': 'Developer check',
    'checkServer': 'Check server',
    'serverOk': 'Server reachable',
    'serverError': 'Server not reachable',
    'loading': 'Loading…',
  },
  'de': {
    'appName': 'TAMRA',
    'homeTitle': 'Willkommen bei TAMRA',
    'homeSubtitle': 'Dein fairer Ernährungs-Tracker',
    'debugTitle': 'Entwickler-Check',
    'checkServer': 'Server prüfen',
    'serverOk': 'Server erreichbar',
    'serverError': 'Server nicht erreichbar',
    'loading': 'Wird geladen…',
  },
  'fr': {
    'appName': 'TAMRA',
    'homeTitle': 'Bienvenue sur TAMRA',
    'homeSubtitle': 'Ton suivi nutritionnel équitable',
    'debugTitle': 'Vérification développeur',
    'checkServer': 'Vérifier le serveur',
    'serverOk': 'Serveur accessible',
    'serverError': 'Serveur inaccessible',
    'loading': 'Chargement…',
  },
  'it': {
    'appName': 'TAMRA',
    'homeTitle': 'Benvenuto su TAMRA',
    'homeSubtitle': 'Il tuo tracker nutrizionale equo',
    'debugTitle': 'Controllo sviluppatore',
    'checkServer': 'Controlla server',
    'serverOk': 'Server raggiungibile',
    'serverError': 'Server non raggiungibile',
    'loading': 'Caricamento…',
  },
  'ar': {
    'appName': 'تمرة',
    'homeTitle': 'مرحبًا بك في تمرة',
    'homeSubtitle': 'متتبع التغذية العادل الخاص بك',
    'debugTitle': 'فحص المطور',
    'checkServer': 'فحص الخادم',
    'serverOk': 'الخادم متاح',
    'serverError': 'الخادم غير متاح',
    'loading': 'جارٍ التحميل…',
  },
};
