import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../l10n/app_strings.dart';

/// Placeholder start screen. Replaced by the diary in T-31.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appName),
        actions: [
          IconButton(
            key: const Key('logout'),
            tooltip: strings.logout,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                strings.homeTitle,
                key: const Key('home-title'),
                style: textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                strings.homeSubtitle,
                style: textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                key: const Key('open-food-search'),
                onPressed: () => context.push(AppRoutes.foodSearch),
                icon: const Icon(Icons.search),
                label: Text(strings.foodSearchTitle),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  key: const Key('open-debug'),
                  onPressed: () => context.push(AppRoutes.debug),
                  child: Text(strings.debugTitle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
