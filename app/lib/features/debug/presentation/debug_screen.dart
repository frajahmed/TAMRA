import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../l10n/app_strings.dart';

/// Result of the last server check. Re-run with `ref.invalidate(healthProvider)`.
final healthProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(apiClientProvider).health();
});

/// Developer screen: checks that the app can reach the API.
class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final health = ref.watch(healthProvider);

    final status = health.when(
      data: (ok) => ok ? strings.serverOk : strings.serverError,
      error: (error, stackTrace) => strings.serverError,
      loading: () => strings.loading,
    );

    return Scaffold(
      appBar: AppBar(title: Text(strings.debugTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(status, key: const Key('health-status')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(healthProvider),
              child: Text(strings.checkServer),
            ),
          ],
        ),
      ),
    );
  }
}
