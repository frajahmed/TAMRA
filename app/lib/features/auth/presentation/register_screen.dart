import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../l10n/app_strings.dart';
import 'auth_form.dart';

class RegisterScreen extends ConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.register)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(24),
          child: AuthForm(
            keyPrefix: 'register',
            submitLabel: strings.register,
            switchLabel: strings.haveAccount,
            checkPasswordLength: true,
            onSubmit: (email, password) =>
                ref.read(authControllerProvider.notifier).register(email, password),
            onSwitch: () => context.go(AppRoutes.login),
          ),
        ),
      ),
    );
  }
}
