import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/json.dart';
import '../../../core/nutrition/nutrition.dart';
import '../../../core/widgets/charts.dart';
import '../../../l10n/app_strings.dart';
import '../../onboarding/data/profile_repository.dart';
import '../../stats/data/stats_repository.dart';
import '../data/tracking_repository.dart';
import '../domain/tracking.dart';

/// Lowest weight in kg the API accepts.
const minWeightKg = 30.0;

/// Highest weight in kg the API accepts.
const maxWeightKg = 300.0;

/// Weight history: line chart of the last 90 days, list, add / change / delete.
class WeightScreen extends ConsumerWidget {
  /// Creates the weight screen.
  const WeightScreen({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    WeightUnit unit, {
    WeightLog? existing,
  }) async {
    final result = await showDialog<(DateTime, double)>(
      context: context,
      builder: (context) => _WeightDialog(unit: unit, existing: existing),
    );
    if (result == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(trackingRepositoryProvider).saveWeight(result.$1, result.$2),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = AppStrings.of(context).genericError;
    try {
      await action();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
    // A new newest weight also changes the profile and its calorie target.
    ref
      ..invalidate(weightsProvider)
      ..invalidate(profileProvider)
      ..invalidate(weekStatsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final unit = ref.watch(profileProvider).valueOrNull?.weightUnit ?? WeightUnit.kg;
    final weights = ref.watch(weightsProvider);
    final localizations = MaterialLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.weightTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('weight-add'),
        onPressed: () => _edit(context, ref, unit),
        icon: const Icon(Icons.add),
        label: Text(strings.weightAdd),
      ),
      body: weights.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: OutlinedButton(
            key: const Key('weight-retry'),
            onPressed: () => ref.invalidate(weightsProvider),
            child: Text(strings.retry),
          ),
        ),
        data: (logs) => logs.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(32),
                  child: Text(
                    strings.weightEmpty,
                    key: const Key('weight-empty'),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 96),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(16),
                      child: LineChart(
                        key: const Key('weight-chart'),
                        values: [for (final log in logs) unit.fromKg(log.weightKg)],
                        semanticLabel: strings.weightChartLabel,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final log in logs.reversed)
                    ListTile(
                      key: Key('weight-${log.id}'),
                      title: Text(strings.weight(log.weightKg, unit)),
                      subtitle: Text(localizations.formatMediumDate(log.date)),
                      onTap: () => _edit(context, ref, unit, existing: log),
                      trailing: IconButton(
                        key: Key('weight-delete-${log.id}'),
                        tooltip: strings.delete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _run(
                          context,
                          ref,
                          () => ref.read(trackingRepositoryProvider).deleteWeight(log.id),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Dialog for date and weight; returns (day, weight in kg) or null when cancelled.
class _WeightDialog extends StatefulWidget {
  const _WeightDialog({required this.unit, this.existing});

  final WeightUnit unit;
  final WeightLog? existing;

  @override
  State<_WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends State<_WeightDialog> {
  late DateTime _date = widget.existing?.date ?? dateOnly(DateTime.now());
  late final _input = TextEditingController(
    text: widget.existing == null
        ? ''
        : formatAmount(double.parse(widget.unit.fromKg(widget.existing!.weightKg).toStringAsFixed(1))),
  );
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  void _save(AppStrings strings) {
    final typed = parseAmount(_input.text);
    final kg = typed == null ? null : widget.unit.toKg(typed);
    if (kg == null || kg < minWeightKg || kg > maxWeightKg) {
      final low = formatAmount(widget.unit.fromKg(minWeightKg).roundToDouble());
      final high = formatAmount(widget.unit.fromKg(maxWeightKg).roundToDouble());
      setState(() => _error = strings.invalidRange(num.parse(low), num.parse(high)));
      return;
    }
    Navigator.of(context).pop((_date, double.parse(kg.toStringAsFixed(1))));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AlertDialog(
      title: Text(strings.weightAdd),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('weight-date'),
            contentPadding: EdgeInsetsDirectional.zero,
            leading: const Icon(Icons.event),
            title: Text(strings.dateLabel),
            subtitle: Text(MaterialLocalizations.of(context).formatMediumDate(_date)),
            // The day of an existing entry stays fixed: one weight per day.
            onTap: widget.existing == null ? _pickDate : null,
          ),
          TextField(
            key: const Key('weight-input'),
            controller: _input,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(
              labelText: strings.weightLabel(widget.unit),
              errorText: _error,
            ),
            onSubmitted: (_) => _save(strings),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          key: const Key('weight-save'),
          onPressed: () => _save(strings),
          child: Text(strings.save),
        ),
      ],
    );
  }
}
