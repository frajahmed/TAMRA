import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../l10n/app_strings.dart';

/// Shared email + password form for login and registration.
class AuthForm extends StatefulWidget {
  const AuthForm({
    super.key,
    required this.keyPrefix,
    required this.submitLabel,
    required this.switchLabel,
    required this.onSubmit,
    required this.onSwitch,
    this.checkPasswordLength = false,
  });

  /// `login` or `register`; used for widget keys (e.g. `login-email`).
  final String keyPrefix;
  final String submitLabel;
  final String switchLabel;
  final Future<void> Function(String email, String password) onSubmit;
  final VoidCallback onSwitch;
  final bool checkPasswordLength;

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(AppStrings strings) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_email.text.trim(), _password.text);
    } on ApiError catch (error) {
      final messages = error.fieldMessages;
      setState(() {
        if (error.isNetworkError) {
          _error = strings.genericError;
        } else if (messages.isNotEmpty) {
          _error = messages.join('\n');
        } else {
          _error = error.message;
        }
      });
    } catch (_) {
      setState(() => _error = strings.genericError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final prefix = widget.keyPrefix;

    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: Key('$prefix-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: strings.email),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return strings.fieldRequired;
                final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
                return valid ? null : strings.emailInvalid;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: Key('$prefix-password'),
              controller: _password,
              obscureText: true,
              autofillHints: [
                widget.checkPasswordLength ? AutofillHints.newPassword : AutofillHints.password,
              ],
              decoration: InputDecoration(labelText: strings.password),
              onFieldSubmitted: (_) => _submit(strings),
              validator: (value) {
                final text = value ?? '';
                if (text.isEmpty) return strings.fieldRequired;
                if (widget.checkPasswordLength && text.length < 10) {
                  return strings.passwordTooShort;
                }
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                key: Key('$prefix-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: Key('$prefix-submit'),
              onPressed: _busy ? null : () => _submit(strings),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.submitLabel),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: Key('$prefix-switch'),
              onPressed: _busy ? null : widget.onSwitch,
              child: Text(widget.switchLabel),
            ),
          ],
        ),
      ),
    );
  }
}
