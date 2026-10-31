import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_strings.dart';
import '../data/stats_repository.dart';
import '../domain/streak.dart';

/// Positive diary hint that shows today's current and best logging streak.
class StreakChip extends ConsumerWidget {
  /// Creates the streak chip.
  const StreakChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(streakProvider).when(
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => const SizedBox.shrink(),
          data: (streak) => _StreakChipContent(streak: streak),
        );
  }
}

class _StreakChipContent extends StatelessWidget {
  const _StreakChipContent({required this.streak});

  final Streak streak;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final primary = streak.currentDays == 0
        ? strings.streakStart
        : streak.currentDays == 1
            ? strings.streakOneDay
            : strings.streakDays(streak.currentDays);
    final keepGoing = streak.currentDays > 0 && !streak.loggedToday;
    final showLongest = streak.longestDays > streak.currentDays;
    final visibleLines = [
      primary,
      if (keepGoing) strings.streakKeepGoing,
      if (showLongest) strings.streakLongest(streak.longestDays),
    ];

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 12),
      child: Semantics(
        key: const Key('streak-chip'),
        label: visibleLines.join('\n'),
        container: true,
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (streak.currentDays > 0) ...[
              Icon(Icons.local_fire_department, color: colors.brand),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(primary),
                  if (keepGoing) Text(strings.streakKeepGoing),
                  if (showLongest)
                    Text(
                      strings.streakLongest(streak.longestDays),
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
