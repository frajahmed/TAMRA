import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../offline/local_store.dart';
import 'token_storage.dart';

/// Whether the user is logged in; `unknown` while stored tokens are checked at start.
enum AuthStatus { unknown, loggedOut, loggedIn }

/// Login state plus what is still missing before the user can use the app.
class AuthState {
  const AuthState({
    required this.status,
    this.needsConsent = false,
    this.needsProfile = false,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);
  const AuthState.loggedOut() : this(status: AuthStatus.loggedOut);

  final AuthStatus status;
  final bool needsConsent;
  final bool needsProfile;

  /// True when tokens are present and valid.
  bool get isLoggedIn => status == AuthStatus.loggedIn;

  /// Same login status with changed consent/profile flags.
  AuthState copyWith({bool? needsConsent, bool? needsProfile}) => AuthState(
        status: status,
        needsConsent: needsConsent ?? this.needsConsent,
        needsProfile: needsProfile ?? this.needsProfile,
      );

  @override
  bool operator ==(Object other) =>
      other is AuthState &&
      other.status == status &&
      other.needsConsent == needsConsent &&
      other.needsProfile == needsProfile;

  @override
  int get hashCode => Object.hash(status, needsConsent, needsProfile);

  @override
  String toString() =>
      'AuthState($status, needsConsent: $needsConsent, needsProfile: $needsProfile)';
}

/// Current version of the health-data consent text (see translations: consentText).
const healthConsentVersion = '2026-10';

/// Logs the user in and out and decides which entry screen is needed
/// (consent, onboarding or the app). Tokens are kept in [TokenStorage].
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    unawaited(Future<void>.microtask(restore));
    return const AuthState.unknown();
  }

  ApiClient get _api => ref.read(apiClientProvider);
  TokenStorage get _storage => ref.read(tokenStorageProvider);

  /// Called on app start: logged in if tokens are stored.
  Future<void> restore() async {
    final access = await _storage.readAccess();
    if (access == null) {
      state = const AuthState.loggedOut();
      return;
    }
    await _loadSession();
  }

  /// Throws [ApiError] on failure (shown by the login screen).
  Future<void> login(String email, String password) async {
    final tokens = await _api.login(email.trim().toLowerCase(), password);
    await _storage.save(access: tokens.access, refresh: tokens.refresh);
    await _loadSession();
  }

  /// Throws [ApiError] on failure (shown by the register screen).
  Future<void> register(String email, String password) async {
    final tokens = await _api.register(email.trim().toLowerCase(), password);
    await _storage.save(access: tokens.access, refresh: tokens.refresh);
    await _loadSession();
  }

  /// Logs out on the server (refresh token blacklisted) and deletes the stored tokens.
  Future<void> logout() async {
    final refresh = await _storage.readRefresh();
    if (refresh != null) {
      try {
        await _api.logout(refresh);
      } on ApiError {
        // Logging out locally is enough when the server cannot be reached.
      }
    }
    await _storage.clear();
    await _clearOfflineData();
    state = const AuthState.loggedOut();
  }

  /// Deletes cached diary days and waiting offline changes from the phone.
  /// A failure here must never block logging out.
  Future<void> _clearOfflineData() async {
    try {
      await ref.read(localStoreProvider).clear();
    } catch (_) {
      // The cache lives in the app sandbox and is replaced on the next login.
    }
  }

  /// Called by the AuthInterceptor when the refresh token is no longer valid.
  void sessionExpired() => state = const AuthState.loggedOut();

  /// Called after the health-data consent was saved.
  void markConsentGiven() => state = state.copyWith(needsConsent: false);

  /// Called after the health-data consent was withdrawn: the consent screen comes back.
  void markConsentWithdrawn() => state = state.copyWith(needsConsent: true);

  /// Called after the account was deleted on the server: forget the tokens locally
  /// (the server already blacklisted them).
  Future<void> accountDeleted() async {
    await _storage.clear();
    await _clearOfflineData();
    state = const AuthState.loggedOut();
  }

  /// Called after onboarding saved a complete profile.
  void markProfileComplete() => state = state.copyWith(needsProfile: false);

  Future<void> _loadSession() async {
    try {
      final profile = await _api.getProfile();
      final consents = await _api.listConsents();
      final hasHealthConsent = consents.any(
        (consent) => consent['type'] == 'health_data' && consent['withdrawn_at'] == null,
      );
      state = AuthState(
        status: AuthStatus.loggedIn,
        needsConsent: !hasHealthConsent,
        needsProfile: profile['is_complete'] != true,
      );
    } on ApiError catch (error) {
      if (error.statusCode == 401) {
        await _storage.clear();
        state = const AuthState.loggedOut();
      } else {
        // Offline start: let the user in; onboarding is checked again next time.
        state = const AuthState(status: AuthStatus.loggedIn);
      }
    }
  }
}

/// The login state of the app.
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
