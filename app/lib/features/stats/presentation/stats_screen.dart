import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/nutrition/nutrition.dart';
import '../../../core/widgets/charts.dart';
import '../../../l10n/app_strings.dart';
import '../../onboarding/data/profile_repository.dart';
import '../data/stats_repository.dart';
import '../domain/stats.dart';

/// Statistics tab: calories of the last 7 days against the target, average macros and
/// the weight change. Free users see 7 days (longer ranges come with PRO).
class StatsScreen extends ConsumerWidget {
  /// Creates the statistics screen.
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final energyUnit = profile?.energyUnit ?? EnergyUnit.kcal;
    final weightUnit = profile?.weightUnit ?? WeightUnit.kg;
    final stats = ref.watch(weekStatsProvider);

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
                onPressed: () => ref.invalidate(weekStatsProvider),
                child: Text(strings.retry),
              ),
            ],
          ),
        ),
        data: (summary) => RefreshIndicator(
          onRefresh: () => ref.refresh(weekStatsProvider.future),
          child: _StatsContent(
            summary: summary,
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
    required this.energyUnit,
    required this.weightUnit,
  });

  final StatsSummary summary;
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

    return ListView(
      key: const Key('stats-list'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.statsLast7Days, style: textTheme.titleMedium),
                const SizedBox(height: 16),
                BarChart(
                  key: const Key('stats-kcal-chart'),
                  values: [for (final day in summary.days) day.nutrients.kcal],
                  labels: [
                    for (final day in summary.days)
                      localizations.narrowWeekdays[day.date.weekday % 7],
                  ],
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
                _MacroLine(label: strings.protein, grams: averages.protein, color: colors.protein),
                const SizedBox(height: 8),
                Text(
                  strings.statsLoggedDays(summary.loggedDays, summary.days.length),
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

class _MacroLine extends StatelessWidget {
  const _MacroLine({required this.label, required this.grams, required this.color});

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
          Text(strings.gramsValue(grams.round())),
        ],
      ),
    );
  }
}
