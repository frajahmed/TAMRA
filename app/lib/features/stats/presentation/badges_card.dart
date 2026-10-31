import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_strings.dart';
import '../data/stats_repository.dart';
import '../domain/streak.dart';

/// Statistics card with the fixed streak milestones and their progress.
class BadgesCard extends ConsumerWidget {
  /// Creates the badges card.
  const BadgesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(streakProvider).when(
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => const SizedBox.shrink(),
          data: (streak) => _BadgesContent(streak: streak),
        );
  }
}

class _BadgesContent extends StatelessWidget {
  const _BadgesContent({required this.streak});

  final Streak streak;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.badgesTitle, style: textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final badge in streak.badges)
                  _BadgeItem(
                    badge: badge,
                    currentDays: streak.currentDays,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeItem extends StatelessWidget {
  const _BadgeItem({required this.badge, required this.currentDays});

  final StreakBadge badge;
  final int currentDays;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final earnedOn = badge.earnedOn;
    final daysOpen = badge.days > currentDays ? badge.days - currentDays : 0;
    final status = badge.earned && earnedOn != null
        ? strings.badgeEarnedOn(
            MaterialLocalizations.of(context).formatMediumDate(earnedOn),
          )
        : strings.badgeOpen(daysOpen);

    return Container(
      key: Key('badge-${badge.days}'),
      constraints: const BoxConstraints(minWidth: 128, maxWidth: 200),
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            badge.earned ? Icons.emoji_events : Icons.emoji_events_outlined,
            color: badge.earned ? colors.brand : colors.textSecondary,
          ),
          const SizedBox(height: 6),
          Text(strings.badgeDays(badge.days), style: textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(status, style: TextStyle(color: colors.textSecondary)),
        ],
      ),
    );
  }
}
