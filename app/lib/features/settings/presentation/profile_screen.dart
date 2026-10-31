import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/locale_provider.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/json.dart';
import '../../../core/nutrition/nutrition.dart';
import '../../../l10n/app_strings.dart';
import '../../diary/data/diary_repository.dart';
import '../../onboarding/data/profile_repository.dart';
import '../../onboarding/domain/profile.dart';
import '../../stats/data/stats_repository.dart';
import '../data/file_sharer.dart';

/// Profile tab: daily target, units, language, weight history, privacy (export,
/// withdraw consent), logout and deleting the account.
class ProfileScreen extends ConsumerWidget {
  /// Creates the profile screen.
  const ProfileScreen({super.key});

  Future<void> _update(
      BuildContext context, WidgetRef ref, Map<String, dynamic> changes) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = AppStrings.of(context).genericError;
    try {
      await ref.read(profileRepositoryProvider).updateSettings(changes);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
    // Units are shown in the diary and the statistics too.
    ref
      ..invalidate(profileProvider)
      ..invalidate(diaryDayProvider)
      ..invalidate(statsProvider);
  }

  void _setLanguage(BuildContext context, WidgetRef ref, String? code) {
    ref
        .read(localeProvider.notifier)
        .setLocale(code == null ? null : Locale(code));
    if (code != null) _update(context, ref, {'language': code});
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = AppStrings.of(context).genericError;
    try {
      final json = await ref.read(profileRepositoryProvider).exportData();
      final name = 'tamra-export-${dateKey(DateTime.now())}.json';
      await ref.read(fileSharerProvider).shareJson(name, json);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _withdrawConsent(BuildContext context, WidgetRef ref) async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.withdrawConsent),
        content: Text(strings.withdrawConsentText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            key: const Key('withdraw-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.withdrawConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(profileRepositoryProvider).withdrawHealthConsent();
      ref.read(authControllerProvider.notifier).markConsentWithdrawn();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(strings.genericError)));
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => const _DeleteAccountDialog(),
    );
    if (deleted == true)
      await ref.read(authControllerProvider.notifier).accountDeleted();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final colors = AppColors.of(context);
    final profile = ref.watch(profileProvider).valueOrNull ?? const Profile();
    final language = ref.watch(localeProvider)?.languageCode;
    final target = profile.kcalTarget;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(strings.navProfile)),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.settingsTarget,
                      style: TextStyle(color: colors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    target == null
                        ? strings.noTargetYet
                        : strings.energy(target.toDouble(), profile.energyUnit),
                    key: const Key('settings-target'),
                    style: textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          ),
          _Section(strings.settingsUnits),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: Text(strings.weightUnitLabel),
                  trailing: SegmentedButton<WeightUnit>(
                    key: const Key('unit-weight'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                      ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
                    ],
                    selected: {profile.weightUnit},
                    onSelectionChanged: (selection) => _update(
                        context, ref, {'weight_unit': selection.first.name}),
                  ),
                ),
                ListTile(
                  title: Text(strings.energyUnitLabel),
                  trailing: SegmentedButton<EnergyUnit>(
                    key: const Key('unit-energy'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                          value: EnergyUnit.kcal, label: Text('kcal')),
                      ButtonSegment(value: EnergyUnit.kj, label: Text('kJ')),
                    ],
                    selected: {profile.energyUnit},
                    onSelectionChanged: (selection) => _update(
                        context, ref, {'energy_unit': selection.first.name}),
                  ),
                ),
                ListTile(
                  title: Text(strings.languageLabel),
                  subtitle: DropdownButton<String?>(
                    key: const Key('language'),
                    isExpanded: true,
                    value: language,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(child: Text(strings.languageDevice)),
                      for (final entry in AppStrings.languageNames.entries)
                        DropdownMenuItem(
                            value: entry.key, child: Text(entry.value)),
                    ],
                    onChanged: (code) => _setLanguage(context, ref, code),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              key: const Key('count-sport'),
              title: Text(strings.countSport),
              subtitle: Text(strings.countSportHint),
              value: profile.countActivityKcal,
              onChanged: (value) =>
                  _update(context, ref, {'count_activity_kcal': value}),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              key: const Key('profile-weight'),
              leading: const Icon(Icons.monitor_weight_outlined),
              title: Text(strings.openWeight),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.weight),
            ),
          ),
          _Section(strings.privacyTitle),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('export-data'),
                  leading: const Icon(Icons.download_outlined),
                  title: Text(strings.exportData),
                  subtitle: Text(strings.exportDataHint),
                  onTap: () => _export(context, ref),
                ),
                ListTile(
                  key: const Key('withdraw-consent'),
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(strings.withdrawConsent),
                  onTap: () => _withdrawConsent(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('profile-logout'),
                  leading: const Icon(Icons.logout),
                  title: Text(strings.logout),
                  onTap: () =>
                      ref.read(authControllerProvider.notifier).logout(),
                ),
                ListTile(
                  key: const Key('delete-account'),
                  leading: Icon(Icons.delete_forever_outlined,
                      color: colors.textSecondary),
                  title: Text(strings.deleteAccount),
                  onTap: () => _deleteAccount(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 20, 4, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

/// Asks for the password and deletes the account; returns true when it was deleted.
class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete(AppStrings strings) async {
    if (_password.text.isEmpty) {
      setState(() => _error = strings.fieldRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).deleteAccount(_password.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiError catch (error) {
      final messages = error.fieldMessages;
      if (mounted) {
        setState(() =>
            _error = messages.isEmpty ? strings.genericError : messages.first);
      }
    } catch (_) {
      if (mounted) setState(() => _error = strings.genericError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AlertDialog(
      title: Text(strings.deleteAccount),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.deleteAccountText),
          const SizedBox(height: 16),
          TextField(
            key: const Key('delete-password'),
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration:
                InputDecoration(labelText: strings.password, errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(strings.cancel),
        ),
        FilledButton(
          key: const Key('delete-confirm'),
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: _busy ? null : () => _delete(strings),
          child: Text(strings.deleteConfirm),
        ),
      ],
    );
  }
}
