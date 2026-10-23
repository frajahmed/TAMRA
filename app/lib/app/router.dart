import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/debug/presentation/debug_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/presentation/consent_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';

/// Route paths. Add new screens here, never use raw strings in features.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const consent = '/onboarding/consent';
  static const onboarding = '/onboarding';
  static const home = '/';
  static const debug = '/debug';
}

/// Where the user may go, based on the login state. Pure function, unit-tested.
/// Returns the path to redirect to, or null to stay.
String? authRedirect(AuthState auth, String location) {
  if (location == AppRoutes.debug) return null;

  switch (auth.status) {
    case AuthStatus.unknown:
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case AuthStatus.loggedOut:
      const open = [AppRoutes.login, AppRoutes.register];
      return open.contains(location) ? null : AppRoutes.login;
    case AuthStatus.loggedIn:
      if (auth.needsConsent) {
        return location == AppRoutes.consent ? null : AppRoutes.consent;
      }
      if (auth.needsProfile) {
        return location == AppRoutes.onboarding ? null : AppRoutes.onboarding;
      }
      const entry = [
        AppRoutes.splash,
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.consent,
        AppRoutes.onboarding,
      ];
      return entry.contains(location) ? AppRoutes.home : null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<AuthState>(authControllerProvider, (previous, next) => refresh.value++);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) =>
        authRedirect(ref.read(authControllerProvider), state.matchedLocation),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (context, state) => const RegisterScreen()),
      GoRoute(path: AppRoutes.consent, builder: (context, state) => const ConsentScreen()),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen()),
      GoRoute(path: AppRoutes.debug, builder: (context, state) => const DebugScreen()),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
