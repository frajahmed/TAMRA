import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/core/api/api_client.dart';
import 'package:tamra_app/core/auth/auth_controller.dart';
import 'package:tamra_app/core/auth/token_storage.dart';
import 'package:tamra_app/core/offline/local_store.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeApiClient api;
  late MemoryTokenStorage storage;

  ProviderContainer container() {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        tokenStorageProvider.overrideWithValue(storage),
        localStoreProvider.overrideWithValue(MemoryLocalStore()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Reads the controller and waits for the start-up restore to finish.
  Future<AuthController> started(ProviderContainer container) async {
    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return container.read(authControllerProvider.notifier);
  }

  setUp(() {
    api = FakeApiClient();
    storage = MemoryTokenStorage();
  });

  test('without stored tokens the user is logged out', () async {
    final c = container();
    await started(c);
    expect(c.read(authControllerProvider), const AuthState.loggedOut());
  });

  test('stored tokens restore the session and check onboarding', () async {
    storage = MemoryTokenStorage(access: 'a', refresh: 'r');
    api.profile = {'is_complete': true};
    api.consents = [
      {'type': 'health_data', 'withdrawn_at': null},
    ];
    final c = container();
    await started(c);
    expect(c.read(authControllerProvider),
        const AuthState(status: AuthStatus.loggedIn));
  });

  test('withdrawn consent means consent is needed again', () async {
    storage = MemoryTokenStorage(access: 'a', refresh: 'r');
    api.consents = [
      {'type': 'health_data', 'withdrawn_at': '2026-10-01T10:00:00Z'},
    ];
    final c = container();
    await started(c);
    final state = c.read(authControllerProvider);
    expect(state.needsConsent, isTrue);
    expect(state.needsProfile, isTrue);
  });

  test('login saves tokens and lowercases the email', () async {
    final c = container();
    final controller = await started(c);
    await controller.login(' User@Example.com ', 'secret-123');

    expect(api.calls, contains('login:user@example.com'));
    expect(storage.access, 'access-1');
    expect(storage.refresh, 'refresh-1');
    expect(c.read(authControllerProvider).isLoggedIn, isTrue);
    expect(c.read(authControllerProvider).needsConsent, isTrue);
  });

  test('failed login throws and stores nothing', () async {
    api.loginError = const ApiError(
      code: 'no_active_account',
      message: 'No active account found',
      statusCode: 401,
    );
    final c = container();
    final controller = await started(c);

    await expectLater(
        controller.login('a@b.de', 'x'), throwsA(isA<ApiError>()));
    expect(storage.access, isNull);
    expect(c.read(authControllerProvider), const AuthState.loggedOut());
  });

  test('expired session on start logs out and clears tokens', () async {
    storage = MemoryTokenStorage(access: 'a', refresh: 'r');
    api.profileError =
        const ApiError(code: 'token_not_valid', message: 'x', statusCode: 401);
    final c = container();
    await started(c);
    expect(c.read(authControllerProvider), const AuthState.loggedOut());
    expect(storage.access, isNull);
  });

  test('offline start keeps the user logged in', () async {
    storage = MemoryTokenStorage(access: 'a', refresh: 'r');
    api.profileError =
        const ApiError(code: 'network_error', message: 'offline');
    final c = container();
    await started(c);
    expect(c.read(authControllerProvider).isLoggedIn, isTrue);
  });

  test('logout blacklists the refresh token and clears storage', () async {
    storage = MemoryTokenStorage(access: 'a', refresh: 'r');
    api.profile = {'is_complete': true};
    final c = container();
    final controller = await started(c);
    await controller.logout();

    expect(api.calls, contains('logout:r'));
    expect(storage.refresh, isNull);
    expect(c.read(authControllerProvider), const AuthState.loggedOut());
  });

  test('consent and profile flags can be cleared', () async {
    final c = container();
    final controller = await started(c);
    await controller.login('a@b.de', 'secret-123');
    controller.markConsentGiven();
    controller.markProfileComplete();
    expect(c.read(authControllerProvider),
        const AuthState(status: AuthStatus.loggedIn));
  });
}
