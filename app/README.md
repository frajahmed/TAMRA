# TAMRA App (Flutter)

## Start
```bash
cd app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000   # Android emulator
flutter run --dart-define=API_BASE_URL=http://localhost:8000  # iOS simulator
```

## Checks (must pass before every PR)
```bash
dart format lib test
flutter analyze
flutter test
```

## Structure
```
lib/
  main.dart
  app/            app.dart (MaterialApp), router.dart, theme.dart, locale_provider.dart
  core/           config.dart, api/api_client.dart, nutrition/nutrition.dart
  features/<name>/{data,domain,presentation}/
  l10n/           app_strings.dart (getters), translations.dart (texts for de, en, fr, it, ar)
test/             mirrors lib/
```

The `android/` and `ios/` folders are generated once by the GitHub workflow
"Bootstrap Flutter platforms" (Actions tab → Run workflow).
