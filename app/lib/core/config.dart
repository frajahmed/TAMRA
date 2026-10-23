/// Build-time configuration.
///
/// Set values with `--dart-define`, for example:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000`
abstract final class AppConfig {
  /// Default works for the Android emulator talking to a local API.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
