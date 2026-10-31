import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../l10n/app_strings.dart';
import 'auth_form.dart';

/// Login with email and password; links to registration.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.login)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(24),
          child: AuthForm(
            keyPrefix: 'login',
            submitLabel: strings.login,
            switchLabel: strings.noAccount,
            onSubmit: (email, password) => ref
                .read(authControllerProvider.notifier)
                .login(email, password),
            onSwitch: () => context.go(AppRoutes.register),
          ),
        ),
      ),
    );
  }
}
