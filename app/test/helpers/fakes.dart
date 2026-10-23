import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tamra_app/app/app.dart';
import 'package:tamra_app/app/locale_provider.dart';
import 'package:tamra_app/core/api/api_client.dart';
import 'package:tamra_app/core/auth/auth_controller.dart';
import 'package:tamra_app/features/onboarding/data/profile_repository.dart';
import 'package:tamra_app/features/onboarding/domain/profile.dart';

/// Fixed language for widget tests.
class FixedLocale extends LocaleNotifier {
  FixedLocale(this.locale);

  final Locale locale;

  @override
  Locale? build() => locale;
}

/// Auth controller with a fixed state; records calls instead of talking to the API.
class FakeAuthController extends AuthController {
  FakeAuthController(this.initial, {this.loginError});

  final AuthState initial;
  final ApiError? loginError;
  final List<String> calls = [];

  @override
  AuthState build() => initial;

  @override
  Future<void> login(String email, String password) async {
    calls.add('login:$email');
    if (loginError != null) throw loginError!;
    state = const AuthState(status: AuthStatus.loggedIn);
  }

  @override
  Future<void> register(String email, String password) async {
    calls.add('register:$email');
    if (loginError != null) throw loginError!;
    state = const AuthState(status: AuthStatus.loggedIn, needsConsent: true, needsProfile: true);
  }

  @override
  Future<void> logout() async {
    calls.add('logout');
    state = const AuthState.loggedOut();
  }
}

/// ApiClient whose methods return canned answers. No network.
class FakeApiClient extends ApiClient {
  FakeApiClient() : super(Dio());

  ApiError? loginError;
  ApiError? profileError;
  Map<String, dynamic> profile = {'is_complete': false};
  List<Map<String, dynamic>> consents = [];
  final List<String> calls = [];

  @override
  Future<AuthTokens> login(String email, String password) async {
    calls.add('login:$email');
    if (loginError != null) throw loginError!;
    return const AuthTokens(access: 'access-1', refresh: 'refresh-1');
  }

  @override
  Future<AuthTokens> register(String email, String password) async {
    calls.add('register:$email');
    return const AuthTokens(access: 'access-1', refresh: 'refresh-1');
  }

  @override
  Future<void> logout(String refreshToken) async => calls.add('logout:$refreshToken');

  @override
  Future<Map<String, dynamic>> getProfile() async {
    if (profileError != null) throw profileError!;
    return profile;
  }

  @override
  Future<List<Map<String, dynamic>>> listConsents() async => consents;
}

/// Profile repository returning a fixed result.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({this.result, this.fail = false});

  final Profile? result;
  final bool fail;
  OnboardingAnswers? saved;
  int consentCalls = 0;

  @override
  Future<Profile> getProfile() async => result ?? const Profile();

  @override
  Future<Profile> saveOnboarding(OnboardingAnswers answers) async {
    if (fail) throw const ApiError(code: 'network_error', message: 'offline');
    saved = answers;
    return result ?? const Profile();
  }

  @override
  Future<void> giveHealthConsent() async {
    if (fail) throw const ApiError(code: 'network_error', message: 'offline');
    consentCalls++;
  }
}

const loggedInComplete = AuthState(status: AuthStatus.loggedIn);

/// The whole app with a fixed language and auth state.
Widget testApp({
  Locale locale = const Locale('en'),
  AuthState auth = loggedInComplete,
  FakeAuthController? controller,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      localeProvider.overrideWith(() => FixedLocale(locale)),
      authControllerProvider.overrideWith(() => controller ?? FakeAuthController(auth)),
      ...overrides,
    ],
    child: const TamraApp(),
  );
}
