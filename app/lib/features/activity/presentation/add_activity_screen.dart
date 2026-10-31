import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/json.dart';
import '../../../core/nutrition/nutrition.dart';
import '../../../l10n/app_strings.dart';
import '../../diary/data/diary_repository.dart';
import '../../onboarding/data/profile_repository.dart';
import '../data/activity_repository.dart';
import '../domain/activity.dart';
import 'activity_icons.dart';

/// Enter a workout by hand: type, duration, optional distance; kcal are suggested from the
/// MET value and the profile weight and can be changed.
class AddActivityScreen extends ConsumerStatefulWidget {
  /// Creates the form.
  const AddActivityScreen({super.key});

  @override
  ConsumerState<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends ConsumerState<AddActivityScreen> {
  final _minutes = TextEditingController(text: '30');
  final _distance = TextEditingController();
  final _kcal = TextEditingController();
  ActivityKind _kind = ActivityKind.walking;

  /// True once the user typed own kcal; then the suggestion no longer overwrites them.
  bool _kcalEdited = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _suggest();
  }

  @override
  void dispose() {
    _minutes.dispose();
    _distance.dispose();
    _kcal.dispose();
    super.dispose();
  }

  double get _weightKg =>
      ref.read(profileProvider).valueOrNull?.weightKg ?? defaultWeightKg;

  void _suggest() {
    if (_kcalEdited) return;
    final minutes = int.tryParse(_minutes.text) ?? 0;
    final kcal =
        activityKcal(met: _kind.met, weightKg: _weightKg, minutes: minutes);
    _kcal.text = kcal.round().toString();
  }

  Future<void> _save(AppStrings strings) async {
    final minutes = int.tryParse(_minutes.text);
    final kcal = parseAmount(_kcal.text);
    final distanceKm = parseAmount(_distance.text);
    if (minutes == null || minutes < 1 || minutes > 1440) {
      setState(() => _error = strings.invalidRange(1, 1440));
      return;
    }
    if (kcal == null || kcal < 0 || kcal > 10000) {
      setState(() => _error = strings.invalidRange(0, 10000));
      return;
    }
    final day = ref.read(selectedDayProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(activityRepositoryProvider).add(
            NewActivity(
              date: day,
              kind: _kind,
              durationMin: minutes,
              kcal: kcal,
              distanceM:
                  distanceKm == null ? null : (distanceKm * 1000).round(),
            ),
          );
      if (!mounted) return;
      ref
        ..invalidate(activityDayProvider(day))
        ..invalidate(diaryDayProvider(day));
      context.pop(true);
    } on ApiError catch (error) {
      final messages = error.fieldMessages;
      if (mounted) {
        setState(() => _error =
            messages.isEmpty ? strings.genericError : messages.join('\n'));
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
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.activityAdd)),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in ActivityKind.values)
                ChoiceChip(
                  key: Key('kind-${kind.apiValue}'),
                  avatar: Icon(activityKindIcon(kind), size: 18),
                  label: Text(strings.activityKind(kind)),
                  selected: kind == _kind,
                  onSelected: (_) => setState(() {
                    _kind = kind;
                    _suggest();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('activity-minutes'),
            controller: _minutes,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: strings.durationLabel),
            onChanged: (_) => setState(_suggest),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('activity-distance'),
            controller: _distance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            ],
            decoration: InputDecoration(labelText: strings.distanceLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('activity-kcal'),
            controller: _kcal,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            ],
            decoration: InputDecoration(
              labelText: strings.kcalBurnedLabel,
              helperText: strings.kcalSuggestion,
              helperMaxLines: 2,
            ),
            onChanged: (_) => _kcalEdited = true,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const Key('activity-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('activity-save'),
            onPressed: _busy ? null : () => _save(strings),
            child: Text(strings.save),
          ),
          const SizedBox(height: 8),
          Text(
            strings.countSportHint,
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
