import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_strings.dart';
import '../data/tracking_repository.dart';
import '../domain/tracking.dart';

/// Water of one day as glasses: "+" adds 250 ml, "−" removes the newest entry.
class WaterCard extends ConsumerWidget {
  /// Creates the card for [day].
  const WaterCard({super.key, required this.day});

  /// The day shown.
  final DateTime day;

  Future<void> _change(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = AppStrings.of(context).genericError;
    try {
      await action();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
    ref.invalidate(waterDayProvider(day));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final colors = AppColors.of(context);
    final repository = ref.watch(trackingRepositoryProvider);
    final water = ref.watch(waterDayProvider(day));
    final data = water.valueOrNull;
    final glasses = data?.glasses ?? 0;

    return Card(
      key: const Key('water-card'),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(strings.water, style: Theme.of(context).textTheme.titleMedium),
                ),
                Text(
                  strings.waterProgress(data?.totalMl ?? 0, waterGoalMl),
                  key: const Key('water-total'),
                  style: TextStyle(color: colors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    children: [
                      for (var index = 0; index < waterGoalMl ~/ glassMl; index++)
                        Icon(
                          index < glasses ? Icons.local_drink : Icons.local_drink_outlined,
                          color: index < glasses ? colors.progress : colors.border,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('water-remove'),
                  tooltip: strings.waterRemove,
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: data == null || data.entries.isEmpty
                      ? null
                      : () => _change(
                            context,
                            ref,
                            () => repository.removeWater(data.entries.first.id),
                          ),
                ),
                IconButton.filled(
                  key: const Key('water-add'),
                  tooltip: strings.waterAdd,
                  style: IconButton.styleFrom(backgroundColor: colors.progress),
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () => _change(context, ref, () => repository.addWater(day)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
