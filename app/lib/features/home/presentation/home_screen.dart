import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../l10n/app_strings.dart';

/// Placeholder start screen. Replaced by the diary in T-30.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(strings.appName)),
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
              if (kDebugMode) ...[
                const SizedBox(height: 32),
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
