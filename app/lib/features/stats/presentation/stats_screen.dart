import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/nutrition/nutrition.dart';
import '../../../core/widgets/charts.dart';
import '../../../l10n/app_strings.dart';
import '../../onboarding/data/profile_repository.dart';
import '../data/stats_repository.dart';
import '../domain/stats.dart';

/// Statistics tab: eaten and burned calories against the target for 7 days, 4 weeks or
/// 12 months, average macros and sport, and the weight change. 12 months will be PRO.
class StatsScreen extends ConsumerWidget {
  /// Creates the statistics screen.
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final energyUnit = profile?.energyUnit ?? EnergyUnit.kcal;
    final weightUnit = profile?.weightUnit ?? WeightUnit.kg;
    final stats = ref.watch(statsProvider);
    final range = ref.watch(statsRangeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(strings.navStats)),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.genericError, key: const Key('stats-error')),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('stats-retry'),
                onPressed: () => ref.invalidate(statsProvider),
                child: Text(strings.retry),
              ),
            ],
          ),
        ),
        data: (summary) => RefreshIndicator(
          onRefresh: () => ref.refresh(statsProvider.future),
          child: _StatsContent(
            summary: summary,
            range: range,
            onRangeSelected: (selected) => ref.read(statsRangeProvider.notifier).select(selected),
            energyUnit: energyUnit,
            weightUnit: weightUnit,
          ),
        ),
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  const _StatsContent({
    required this.summary,
    required this.range,
    required this.onRangeSelected,
    required this.energyUnit,
    required this.weightUnit,
  });

  final StatsSummary summary;
  final StatsRange range;
  final ValueChanged<StatsRange> onRangeSelected;
  final EnergyUnit energyUnit;
  final WeightUnit weightUnit;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = AppColors.of(context);
    final localizations = MaterialLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final target = summary.kcalTarget;
    final change = summary.weightChangeKg;
    final averages = summary.averages;
    final locale = Localizations.localeOf(context).languageCode;

    String label(DateTime date) => switch (range) {
          StatsRange.days7 => localizations.narrowWeekdays[date.weekday % 7],
          StatsRange.weeks4 => DateFormat.Md(locale).format(date),
          StatsRange.months12 => DateFormat.MMM(locale).format(date),
        };

    return ListView(
      key: const Key('stats-list'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 8),
          child: SegmentedButton<StatsRange>(
            key: const Key('stats-range'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: StatsRange.days7, label: Text(strings.statsRange7)),
              ButtonSegment(value: StatsRange.weeks4, label: Text(strings.statsRange4w)),
              ButtonSegment(
                value: StatsRange.months12,
                // Marked for the later PRO plan; still free while there is no payment.
                icon: const Icon(Icons.lock_outline, size: 16),
                label: Text(strings.statsRange12m),
              ),
            ],
            selected: {range},
            onSelectionChanged: (selection) => onRangeSelected(selection.first),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.statsEaten, style: textTheme.titleMedium),
                const SizedBox(height: 16),
                BarChart(
                  key: const Key('stats-kcal-chart'),
                  values: [for (final day in summary.days) day.nutrients.kcal],
                  secondaryValues: [for (final day in summary.days) day.burnedKcal],
                  labels: [for (final day in summary.days) label(day.date)],
                  target: target?.toDouble(),
                  semanticLabel: strings.kcalChartLabel,
                ),
                if (target != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${strings.statsTarget}: ${strings.energy(target.toDouble(), energyUnit)}',
                    style: TextStyle(color: colors.brand),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.statsAverage, style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  strings.energy(averages.kcal, energyUnit),
                  key: const Key('stats-average-kcal'),
                  style: textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                _MacroLine(label: strings.carbs, grams: averages.carbs, color: colors.carbs),
                _MacroLine(label: strings.fat, grams: averages.fat, color: colors.fat),
                _MacroLine(
                  label: strings.protein,
                  grams: averages.protein,
                  color: colors.protein,
                ),
                _MacroLine(
                  label: strings.statsSportAverage,
                  grams: null,
                  value: strings.energy(summary.averageBurnedKcal, energyUnit),
                  color: colors.brand,
                ),
                const SizedBox(height: 8),
                Text(
                  strings.statsLoggedDays(summary.loggedDays, _dayCount(summary)),
                  key: const Key('stats-logged-days'),
                  style: TextStyle(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            key: const Key('open-weight'),
            title: Text(strings.statsWeightChange),
            subtitle: Text(
              change == null
                  ? strings.statsNoWeightChange
                  : strings.weight(change, weightUnit, signed: true),
              key: const Key('stats-weight-change'),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.weight),
          ),
        ),
      ],
    );
  }
}

/// Number of calendar days the summary covers (periods for weeks and months).
int _dayCount(StatsSummary summary) {
  if (summary.days.isEmpty) return 0;
  final first = summary.days.first.date;
  final today = DateTime.now();
  return DateTime(today.year, today.month, today.day).difference(first).inDays + 1;
}

class _MacroLine extends StatelessWidget {
  const _MacroLine({required this.label, required this.grams, required this.color, this.value});

  final String label;
  final double? grams;
  final Color color;
  final String? value;

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
          Text(value ?? strings.gramsValue((grams ?? 0).round())),
        ],
      ),
    );
  }
}
