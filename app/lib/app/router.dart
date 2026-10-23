import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/debug/presentation/debug_screen.dart';
import '../features/home/presentation/home_screen.dart';

/// Route paths. Add new screens here, never use raw strings in features.
abstract final class AppRoutes {
  static const home = '/';
  static const debug = '/debug';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.debug,
        builder: (context, state) => const DebugScreen(),
      ),
    ],
  );
});
