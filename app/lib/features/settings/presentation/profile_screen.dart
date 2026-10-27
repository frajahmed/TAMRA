import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../l10n/app_strings.dart';

/// Profile tab: weight history and logout (settings follow in T-43).
class ProfileScreen extends ConsumerWidget {
  /// Creates the profile screen.
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.navProfile)),
      body: ListView(
        children: [
          ListTile(
            key: const Key('profile-weight'),
            leading: const Icon(Icons.monitor_weight_outlined),
            title: Text(strings.openWeight),
            onTap: () => context.push(AppRoutes.weight),
          ),
          ListTile(
            key: const Key('profile-logout'),
            leading: const Icon(Icons.logout),
            title: Text(strings.logout),
            onTap: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
