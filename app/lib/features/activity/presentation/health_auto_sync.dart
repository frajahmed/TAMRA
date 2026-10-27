import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../diary/data/diary_repository.dart';
import '../data/activity_repository.dart';
import '../data/health_sync.dart';

/// Syncs the connected health hub once when the app opens, quietly in the background.
/// Errors are ignored here; the activity screen offers "sync now" with a message.
class HealthAutoSync extends ConsumerStatefulWidget {
  /// Wraps [child] (the tab frame of the app).
  const HealthAutoSync({super.key, required this.child});

  /// What is shown; the sync has no UI of its own.
  final Widget child;

  @override
  ConsumerState<HealthAutoSync> createState() => _HealthAutoSyncState();
}

class _HealthAutoSyncState extends ConsumerState<HealthAutoSync> {
  @override
  void initState() {
    super.initState();
    unawaited(_syncIfConnected());
  }

  Future<void> _syncIfConnected() async {
    final sync = ref.read(healthSyncProvider);
    try {
      final status = await sync.status();
      if (!status.supported || !status.connected) return;
      await sync.sync();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    ref
      ..invalidate(healthStatusProvider)
      ..invalidate(activityDayProvider)
      ..invalidate(diaryDayProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
