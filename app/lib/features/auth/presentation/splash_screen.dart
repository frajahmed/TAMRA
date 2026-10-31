import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';

/// Shown while the stored login is checked on app start.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(strings.appName,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            CircularProgressIndicator(semanticsLabel: strings.loading),
          ],
        ),
      ),
    );
  }
}
