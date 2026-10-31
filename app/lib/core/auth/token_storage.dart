import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the JWT tokens. Never log or print the values.
abstract class TokenStorage {
  /// The short-lived access token, or null when logged out.
  Future<String?> readAccess();

  /// The refresh token (30 days), or null when logged out.
  Future<String?> readRefresh();

  /// Stores both tokens after login, registration or refresh.
  Future<void> save({required String access, required String refresh});

  /// Deletes both tokens (logout, session expired).
  Future<void> clear();
}

/// Production storage: iOS Keychain / Android Keystore.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'tamra_access_token';
  static const _refreshKey = 'tamra_refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccess() => _storage.read(key: _accessKey);

  @override
  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  @override
  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

/// In-memory storage for tests.
class MemoryTokenStorage implements TokenStorage {
  MemoryTokenStorage({this.access, this.refresh});

  String? access;
  String? refresh;

  @override
  Future<String?> readAccess() async => access;

  @override
  Future<String?> readRefresh() async => refresh;

  @override
  Future<void> save({required String access, required String refresh}) async {
    this.access = access;
    this.refresh = refresh;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}

/// Where tokens are stored: the phone's secure storage (Keychain / Keystore).
final tokenStorageProvider =
    Provider<TokenStorage>((ref) => SecureTokenStorage());
