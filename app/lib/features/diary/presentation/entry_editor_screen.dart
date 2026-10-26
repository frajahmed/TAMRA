import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/json.dart';
import '../../../core/nutrition/nutrition.dart';
import '../../../l10n/app_strings.dart';
import '../../food/domain/food.dart';
import '../data/diary_repository.dart';
import '../domain/diary.dart';

/// Smallest amount in grams the API accepts.
const minAmountG = 0.1;

/// Largest amount in grams the API accepts.
const maxAmountG = 5000;

/// What the entry editor works on: a new food for a meal, or an existing entry.
class EntryEditorArgs {
  /// Add [food] to [meal] on [date].
  const EntryEditorArgs.add({
    required Food this.food,
    required this.meal,
    required this.date,
    this.energyUnit = EnergyUnit.kcal,
  }) : entry = null;

  /// Change amount or meal of [entry].
  EntryEditorArgs.edit(DiaryEntry this.entry, {this.energyUnit = EnergyUnit.kcal})
      : food = null,
        meal = entry.meal,
        date = entry.date;

  /// The chosen food (new entry), else null.
  final Food? food;

  /// The entry being edited, else null.
  final DiaryEntry? entry;

  /// The meal preselected in the editor.
  final Meal meal;

  /// The day of the entry.
  final DateTime date;

  /// kcal or kJ for the preview, as in the diary.
  final EnergyUnit energyUnit;

  /// True when an existing entry is changed.
  bool get isEdit => entry != null;

  /// Name shown at the top.
  String get name => food?.name ?? entry!.foodName;

  /// Nutrients per 100 g for the live preview.
  NutritionPer100g get per100g => food?.per100g ?? entry!.per100g;

  /// Serving size of the food, if known (offered as a quick choice).
  double? get servingSizeG => food?.servingSizeG;

  /// Amount shown first: the entry's amount, one serving, or 100 g.
  double get initialAmountG => entry?.amountG ?? food?.servingSizeG ?? 100;
}

/// Choose amount and meal for a food, see the nutrients live, save to the diary.
/// Returns `true` to the caller after saving.
class EntryEditorScreen extends ConsumerStatefulWidget {
  /// Creates the editor for [args].
  const EntryEditorScreen({super.key, required this.args});

  /// What is added or edited.
  final EntryEditorArgs args;

  @override
  ConsumerState<EntryEditorScreen> createState() => _EntryEditorScreenState();
}

class _EntryEditorScreenState extends ConsumerState<EntryEditorScreen> {
  late final _amount = TextEditingController(text: formatAmount(widget.args.initialAmountG));
  late Meal _meal = widget.args.meal;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _validAmount {
    final value = parseAmount(_amount.text);
    if (value == null || value < minAmountG || value > maxAmountG) return null;
    return value;
  }

  Future<void> _save(AppStrings strings) async {
    final amount = _validAmount;
    if (amount == null) {
      setState(() => _error = strings.invalidRange(minAmountG, maxAmountG));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repository = ref.read(diaryRepositoryProvider);
    final args = widget.args;
    try {
      final entry = args.entry;
      if (entry != null) {
        await repository.update(
          entry.id,
          amountG: amount == entry.amountG ? null : amount,
          meal: _meal == entry.meal ? null : _meal,
        );
      } else {
        await repository.add(
          NewDiaryEntry(date: args.date, meal: _meal, foodId: args.food!.id, amountG: amount),
        );
      }
      if (mounted) context.pop(true);
    } on ApiError catch (error) {
      if (!mounted) return;
      final messages = error.fieldMessages;
      setState(() {
        _error = error.isNetworkError || messages.isEmpty
            ? strings.genericError
            : messages.join('\n');
      });
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
    final args = widget.args;
    final serving = args.servingSizeG;
    final preview = args.per100g.forGrams(_validAmount ?? 0);

    return Scaffold(
      appBar: AppBar(title: Text(args.isEdit ? strings.editEntryTitle : strings.addEntryTitle)),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(16),
        children: [
          Text(args.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            key: const Key('entry-amount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(labelText: strings.amountLabel),
            onChanged: (_) => setState(() => _error = null),
          ),
          if (serving != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ActionChip(
                key: const Key('entry-serving'),
                label: Text(strings.oneServing(serving.round())),
                onPressed: () => setState(() => _amount.text = formatAmount(serving)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<Meal>(
            key: const Key('entry-meal'),
            initialValue: _meal,
            decoration: InputDecoration(labelText: strings.mealLabel),
            items: [
              for (final meal in Meal.values)
                DropdownMenuItem(value: meal, child: Text(strings.meal(meal))),
            ],
            onChanged: (meal) => setState(() => _meal = meal ?? _meal),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.energy(preview.kcal, args.energyUnit),
                    key: const Key('entry-preview-kcal'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  _PreviewRow(label: strings.carbs, grams: preview.carbs, color: colors.carbs),
                  _PreviewRow(label: strings.fat, grams: preview.fat, color: colors.fat),
                  _PreviewRow(
                    label: strings.protein,
                    grams: preview.protein,
                    color: colors.protein,
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const Key('entry-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('entry-save'),
            onPressed: _busy ? null : () => _save(strings),
            child: Text(strings.save),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.grams, required this.color});

  final String label;
  final double grams;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(strings.gramsValue(formatAmount(double.parse(grams.toStringAsFixed(1))))),
        ],
      ),
    );
  }
}
