import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_strings.dart';
import '../../diary/data/diary_repository.dart';
import '../data/activity_repository.dart';
import '../data/health_source.dart';
import '../data/health_sync.dart';

/// Card on the activity screen: connect Apple Health / Health Connect, sync, disconnect.
class HealthCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const HealthCard({super.key});

  @override
  ConsumerState<HealthCard> createState() => _HealthCardState();
}

class _HealthCardState extends ConsumerState<HealthCard> {
  bool _busy = false;

  Future<void> _run(Future<String?> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = AppStrings.of(context).genericError;
    setState(() => _busy = true);
    String? message;
    try {
      message = await action();
    } catch (_) {
      message = error;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    // New sport changes the activity list, the diary budget and the connection state.
    ref
      ..invalidate(healthStatusProvider)
      ..invalidate(activityDayProvider)
      ..invalidate(diaryDayProvider);
    if (message != null) messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final sync = ref.watch(healthSyncProvider);
    final app = ref.watch(healthSourceProvider).displayName;
    final status = ref.watch(healthStatusProvider).valueOrNull;
    final localizations = MaterialLocalizations.of(context);

    if (status == null) return const SizedBox.shrink();

    final lastSync = status.lastSync;
    return Card(
      key: const Key('health-card'),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(strings.healthTitle, style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!status.supported)
              Text(strings.healthUnsupported, key: const Key('health-unsupported'))
            else if (!status.connected) ...[
              Text(strings.healthConnectHint(app)),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('health-connect'),
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          final granted = await sync.connect();
                          return granted ? null : strings.healthDenied(app);
                        }),
                child: Text('${strings.healthConnect} – $app'),
              ),
            ] else ...[
              if (lastSync != null)
                Text(
                  strings.healthLastSync(
                    '${localizations.formatMediumDate(lastSync)} '
                    '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(lastSync))}',
                  ),
                  key: const Key('health-last-sync'),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonal(
                    key: const Key('health-sync'),
                    onPressed: _busy
                        ? null
                        : () => _run(() async => strings.healthSynced(await sync.sync())),
                    child: Text(strings.healthSyncNow),
                  ),
                  TextButton(
                    key: const Key('health-disconnect'),
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              await sync.disconnect();
                              return null;
                            }),
                    child: Text(strings.healthDisconnect),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
