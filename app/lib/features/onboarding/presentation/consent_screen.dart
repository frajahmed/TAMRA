import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../l10n/app_strings.dart';
import '../data/profile_repository.dart';

/// GDPR Art. 9: explicit consent before any health data is collected.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _accepted = false;
  bool _busy = false;
  String? _error;

  Future<void> _continue(AppStrings strings) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).giveHealthConsent();
      ref.read(authControllerProvider.notifier).markConsentGiven();
    } catch (_) {
      if (mounted) setState(() => _error = strings.genericError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.consentTitle),
        actions: [
          TextButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            child: Text(strings.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.all(24),
          children: [
            Text(strings.consentText, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
            CheckboxListTile(
              key: const Key('consent-checkbox'),
              value: _accepted,
              onChanged: _busy ? null : (value) => setState(() => _accepted = value ?? false),
              title: Text(strings.consentCheckbox),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsetsDirectional.zero,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('consent-continue'),
              onPressed: (_accepted && !_busy) ? () => _continue(strings) : null,
              child: Text(strings.continueButton),
            ),
          ],
        ),
      ),
    );
  }
}
