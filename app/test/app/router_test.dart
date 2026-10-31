import 'package:flutter_test/flutter_test.dart';
import 'package:tamra_app/app/router.dart';
import 'package:tamra_app/core/auth/auth_controller.dart';

void main() {
  const unknown = AuthState.unknown();
  const loggedOut = AuthState.loggedOut();
  const needsConsent = AuthState(
      status: AuthStatus.loggedIn, needsConsent: true, needsProfile: true);
  const needsProfile =
      AuthState(status: AuthStatus.loggedIn, needsProfile: true);
  const ready = AuthState(status: AuthStatus.loggedIn);

  test('unknown state waits on the splash screen', () {
    expect(authRedirect(unknown, AppRoutes.home), AppRoutes.splash);
    expect(authRedirect(unknown, AppRoutes.splash), isNull);
  });

  test('logged out users may only see login and register', () {
    expect(authRedirect(loggedOut, AppRoutes.home), AppRoutes.login);
    expect(authRedirect(loggedOut, AppRoutes.onboarding), AppRoutes.login);
    expect(authRedirect(loggedOut, AppRoutes.login), isNull);
    expect(authRedirect(loggedOut, AppRoutes.register), isNull);
  });

  test('consent comes before onboarding, onboarding before home', () {
    expect(authRedirect(needsConsent, AppRoutes.home), AppRoutes.consent);
    expect(authRedirect(needsConsent, AppRoutes.consent), isNull);
    expect(authRedirect(needsProfile, AppRoutes.consent), AppRoutes.onboarding);
    expect(authRedirect(needsProfile, AppRoutes.onboarding), isNull);
  });

  test('ready users leave the entry screens', () {
    expect(authRedirect(ready, AppRoutes.login), AppRoutes.home);
    expect(authRedirect(ready, AppRoutes.splash), AppRoutes.home);
    expect(authRedirect(ready, AppRoutes.onboarding), AppRoutes.home);
    expect(authRedirect(ready, AppRoutes.home), isNull);
  });

  test('the debug screen is always reachable', () {
    expect(authRedirect(loggedOut, AppRoutes.debug), isNull);
  });
}
