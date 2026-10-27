import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/nutrition/nutrition.dart';
import '../../../core/widgets/date_strip.dart';
import '../../../l10n/app_strings.dart';
import '../../diary/data/diary_repository.dart';
import '../../onboarding/data/profile_repository.dart';
import '../data/activity_repository.dart';
import '../domain/activity.dart';
import 'activity_icons.dart';

/// Activity tab: sport and steps of the day shown in the diary; add or delete workouts.
class ActivityScreen extends ConsumerWidget {
  /// Creates the activity screen.
  const ActivityScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, Activity activity) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = AppStrings.of(context).genericError;
    try {
      await ref.read(activityRepositoryProvider).delete(activity.id);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
    // Sport changes the day's budget in the diary too.
    ref
      ..invalidate(activityDayProvider(activity.date))
      ..invalidate(diaryDayProvider(activity.date));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final colors = AppColors.of(context);
    final day = ref.watch(selectedDayProvider);
    final sport = ref.watch(activityDayProvider(day));
    final energyUnit = ref.watch(profileProvider).valueOrNull?.energyUnit ?? EnergyUnit.kcal;

    return Scaffold(
      appBar: AppBar(title: Text(strings.navActivity)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('activity-add'),
        icon: const Icon(Icons.add),
        label: Text(strings.activityAdd),
        onPressed: () => context.push(AppRoutes.activityAdd),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
            child: DateStrip(
              selected: day,
              onSelected: ref.read(selectedDayProvider.notifier).select,
            ),
          ),
          Expanded(
            child: sport.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: OutlinedButton(
                  key: const Key('activity-retry'),
                  onPressed: () => ref.invalidate(activityDayProvider(day)),
                  child: Text(strings.retry),
                ),
              ),
              data: (data) => ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 96),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strings.activityBurned(strings.energy(data.burnedKcal, energyUnit)),
                                  key: const Key('activity-burned'),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text(
                                  strings.minutesValue(data.minutes),
                                  style: TextStyle(color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.directions_walk, color: colors.textSecondary),
                          const SizedBox(width: 4),
                          Text(strings.stepsValue(data.steps), key: const Key('activity-steps')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (data.activities.isEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.all(24),
                      child: Text(
                        strings.activityEmpty,
                        key: const Key('activity-empty'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final activity in data.activities)
                    Card(
                      child: ListTile(
                        key: Key('activity-${activity.id}'),
                        leading: Icon(activityKindIcon(activity.kind), color: colors.brand),
                        title: Text(
                          activity.title.isEmpty
                              ? strings.activityKind(activity.kind)
                              : activity.title,
                        ),
                        subtitle: Text(
                          activity.isImported
                              ? '${strings.minutesValue(activity.durationMin)} · ${strings.importedHint}'
                              : strings.minutesValue(activity.durationMin),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(activitySourceIcon(activity.source), size: 18),
                            const SizedBox(width: 8),
                            Text(strings.energy(activity.kcal, energyUnit)),
                            IconButton(
                              key: Key('activity-delete-${activity.id}'),
                              tooltip: strings.delete,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(context, ref, activity),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
