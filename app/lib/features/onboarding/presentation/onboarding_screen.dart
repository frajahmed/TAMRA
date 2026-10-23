import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/nutrition/nutrition.dart';
import '../../../l10n/app_strings.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

/// Six questions, then the calculated daily target.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.currentYear});

  /// Only for tests; defaults to the current year.
  final int? currentYear;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { goal, sex, birthYear, height, weight, activity }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _index = 0;
  WeightGoal? _goal;
  Sex? _sex;
  ActivityLevel? _activity;
  final _birthYear = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  String? _inputError;
  bool _saving = false;
  String? _saveError;
  int? _localTarget;
  Profile? _result;

  int get _year => widget.currentYear ?? DateTime.now().year;
  _Step get _step => _Step.values[_index];

  @override
  void dispose() {
    _birthYear.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  /// Validates a number field; returns the value or sets [_inputError].
  num? _readNumber(TextEditingController controller, num min, num max, AppStrings strings) {
    final value = num.tryParse(controller.text.trim().replaceAll(',', '.'));
    if (value == null || value < min || value > max) {
      setState(() => _inputError = strings.invalidRange(min, max));
      return null;
    }
    return value;
  }

  bool _currentStepValid(AppStrings strings) {
    switch (_step) {
      case _Step.goal:
        return _goal != null;
      case _Step.sex:
        return _sex != null;
      case _Step.activity:
        return _activity != null;
      case _Step.birthYear:
        return _readNumber(
              _birthYear,
              _year - ProfileLimits.maxAge,
              _year - ProfileLimits.minAge,
              strings,
            ) !=
            null;
      case _Step.height:
        return _readNumber(
              _height,
              ProfileLimits.minHeightCm,
              ProfileLimits.maxHeightCm,
              strings,
            ) !=
            null;
      case _Step.weight:
        return _readNumber(
              _weight,
              ProfileLimits.minWeightKg,
              ProfileLimits.maxWeightKg,
              strings,
            ) !=
            null;
    }
  }

  Future<void> _next(AppStrings strings) async {
    setState(() => _inputError = null);
    if (!_currentStepValid(strings)) return;
    if (_index < _Step.values.length - 1) {
      setState(() => _index++);
      return;
    }
    await _save(strings);
  }

  Future<void> _save(AppStrings strings) async {
    final answers = OnboardingAnswers(
      goal: _goal!,
      sex: _sex!,
      birthYear: int.parse(_birthYear.text.trim()),
      heightCm: double.parse(_height.text.trim().replaceAll(',', '.')),
      weightKg: double.parse(_weight.text.trim().replaceAll(',', '.')),
      activityLevel: _activity!,
    );
    setState(() {
      _saving = true;
      _saveError = null;
      _localTarget = answers.localCalorieTarget(_year);
    });
    try {
      final profile = await ref.read(profileRepositoryProvider).saveOnboarding(answers);
      if (mounted) setState(() => _result = profile);
    } catch (_) {
      if (mounted) setState(() => _saveError = strings.genericError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final total = _Step.values.length;

    return Scaffold(
      appBar: AppBar(title: Text(strings.onboardingTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: _result != null || _saving
              ? _ResultView(
                  profile: _result,
                  localTarget: _localTarget,
                  saving: _saving,
                  onStart: () => ref.read(authControllerProvider.notifier).markProfileComplete(),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(strings.stepOf(_index + 1, total), key: const Key('onboarding-step')),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: (_index + 1) / total),
                    const SizedBox(height: 24),
                    Expanded(child: SingleChildScrollView(child: _question(strings))),
                    if (_inputError != null)
                      Text(
                        _inputError!,
                        key: const Key('onboarding-error'),
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    if (_saveError != null)
                      Text(
                        _saveError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (_index > 0)
                          TextButton(
                            onPressed: () => setState(() {
                              _index--;
                              _inputError = null;
                            }),
                            child: Text(strings.back),
                          ),
                        const Spacer(),
                        FilledButton(
                          key: const Key('onboarding-next'),
                          onPressed: () => _next(strings),
                          child: Text(_index == total - 1 ? strings.save : strings.next),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _question(AppStrings strings) {
    final title = Theme.of(context).textTheme.titleLarge;
    switch (_step) {
      case _Step.goal:
        return _Choice<WeightGoal>(
          question: strings.goalQuestion,
          value: _goal,
          options: {
            WeightGoal.lose: strings.goalLose,
            WeightGoal.maintain: strings.goalMaintain,
            WeightGoal.gain: strings.goalGain,
          },
          onChanged: (value) => setState(() => _goal = value),
        );
      case _Step.sex:
        return _Choice<Sex>(
          question: strings.sexQuestion,
          value: _sex,
          options: {Sex.female: strings.sexFemale, Sex.male: strings.sexMale},
          onChanged: (value) => setState(() => _sex = value),
        );
      case _Step.activity:
        return _Choice<ActivityLevel>(
          question: strings.activityQuestion,
          value: _activity,
          options: {
            ActivityLevel.sedentary: strings.activitySedentary,
            ActivityLevel.light: strings.activityLight,
            ActivityLevel.moderate: strings.activityModerate,
            ActivityLevel.active: strings.activityActive,
            ActivityLevel.veryActive: strings.activityVeryActive,
          },
          onChanged: (value) => setState(() => _activity = value),
        );
      case _Step.birthYear:
        return _NumberInput(
          question: strings.birthYearQuestion,
          controller: _birthYear,
          style: title,
          decimals: false,
        );
      case _Step.height:
        return _NumberInput(question: strings.heightQuestion, controller: _height, style: title);
      case _Step.weight:
        return _NumberInput(question: strings.weightQuestion, controller: _weight, style: title);
    }
  }
}

class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.question,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String question;
  final T? value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(question, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        for (final entry in options.entries)
          Card(
            child: ListTile(
              key: Key('choice-${entry.key}'),
              selected: entry.key == value,
              leading: Icon(
                entry.key == value ? Icons.check_circle : Icons.circle_outlined,
              ),
              title: Text(entry.value),
              onTap: () => onChanged(entry.key),
            ),
          ),
      ],
    );
  }
}

class _NumberInput extends StatelessWidget {
  const _NumberInput({
    required this.question,
    required this.controller,
    this.style,
    this.decimals = true,
  });

  final String question;
  final TextEditingController controller;
  final TextStyle? style;
  final bool decimals;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(question, style: style),
        const SizedBox(height: 16),
        TextField(
          key: const Key('onboarding-input'),
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: decimals),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(decimals ? r'[0-9.,]' : r'[0-9]')),
          ],
        ),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.profile,
    required this.localTarget,
    required this.saving,
    required this.onStart,
  });

  final Profile? profile;
  final int? localTarget;
  final bool saving;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final kcal = profile?.kcalTarget ?? localTarget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.resultTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        if (kcal != null)
          Text(
            strings.resultKcal(kcal),
            key: const Key('result-kcal'),
            style: theme.textTheme.headlineMedium,
          ),
        const SizedBox(height: 8),
        Text(strings.resultFormula, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 24),
        if (profile != null) ...[
          _MacroRow(label: strings.protein, grams: profile!.proteinG),
          _MacroRow(label: strings.carbs, grams: profile!.carbsG),
          _MacroRow(label: strings.fat, grams: profile!.fatG),
        ],
        const Spacer(),
        if (saving)
          const Center(child: CircularProgressIndicator())
        else
          FilledButton(
            key: const Key('onboarding-start'),
            onPressed: onStart,
            child: Text(strings.startButton),
          ),
      ],
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.label, required this.grams});

  final String label;
  final int? grams;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsetsDirectional.zero,
      title: Text(label),
      trailing: Text(grams == null ? '–' : '$grams g'),
    );
  }
}
