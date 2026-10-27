import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/json.dart';
import 'activity_repository.dart';
import 'health_source.dart';

/// How far back the first sync after connecting reads.
const firstSyncDays = 30;

/// The API accepts at most this many workouts per import request.
const importPageSize = 500;

/// Remembers whether the health hub is connected and when it was synced last.
abstract class HealthSettingsStorage {
  /// True after the user connected the health hub.
  Future<bool> isConnected();

  /// Saves the connection state.
  Future<void> setConnected(bool connected);

  /// Time of the last successful sync, or null.
  Future<DateTime?> lastSync();

  /// Saves the time of the last successful sync (null forgets it).
  Future<void> setLastSync(DateTime? time);
}

/// Stored in the phone's secure storage (already used for the tokens).
class SecureHealthSettingsStorage implements HealthSettingsStorage {
  /// Creates the storage; [storage] can be replaced in tests.
  SecureHealthSettingsStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _connectedKey = 'tamra_health_connected';
  static const _lastSyncKey = 'tamra_health_last_sync';
  final FlutterSecureStorage _storage;

  @override
  Future<bool> isConnected() async => await _storage.read(key: _connectedKey) == 'true';

  @override
  Future<void> setConnected(bool connected) =>
      _storage.write(key: _connectedKey, value: connected.toString());

  @override
  Future<DateTime?> lastSync() async =>
      DateTime.tryParse(await _storage.read(key: _lastSyncKey) ?? '');

  @override
  Future<void> setLastSync(DateTime? time) => time == null
      ? _storage.delete(key: _lastSyncKey)
      : _storage.write(key: _lastSyncKey, value: time.toIso8601String());
}

/// Kept in memory (tests).
class MemoryHealthSettingsStorage implements HealthSettingsStorage {
  /// Whether the hub is connected.
  bool connected = false;

  /// Time of the last sync.
  DateTime? last;

  @override
  Future<bool> isConnected() async => connected;

  @override
  Future<void> setConnected(bool connected) async => this.connected = connected;

  @override
  Future<DateTime?> lastSync() async => last;

  @override
  Future<void> setLastSync(DateTime? time) async => last = time;
}

/// State of the health connection shown on the activity screen.
class HealthStatus {
  /// Creates the status.
  const HealthStatus({required this.supported, required this.connected, this.lastSync});

  /// False on devices without a health hub.
  final bool supported;

  /// True after the user connected.
  final bool connected;

  /// Time of the last successful sync.
  final DateTime? lastSync;
}

/// Connects the health hub and copies new workouts and steps into TAMRA.
///
/// The import is idempotent on the server, so reading a few hours twice never creates
/// duplicates; the first sync reads [firstSyncDays] days, later ones start at the last sync.
class HealthSync {
  /// Creates the sync; [clock] can be fixed in tests.
  HealthSync({
    required this.source,
    required this.repository,
    required this.storage,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Where the data comes from.
  final HealthSource source;

  /// Where the data goes.
  final ActivityRepository repository;

  /// Connection state and last sync.
  final HealthSettingsStorage storage;

  final DateTime Function() _clock;

  /// Current state for the screen.
  Future<HealthStatus> status() async => HealthStatus(
        supported: source.isSupported,
        connected: await storage.isConnected(),
        lastSync: await storage.lastSync(),
      );

  /// Asks for access and runs the first sync; false when access was refused.
  Future<bool> connect() async {
    if (!source.isSupported || !await source.requestPermission()) return false;
    await storage.setConnected(true);
    await sync();
    return true;
  }

  /// Reads everything since the last sync and imports it; returns the number of new rows.
  Future<int> sync() async {
    final now = _clock();
    final last = await storage.lastSync();
    final from = last ?? DateTime(now.year, now.month, now.day - firstSyncDays);
    final data = await source.read(from: from, to: now);

    final steps = [
      for (final entry in data.stepsByDay.entries)
        {
          'date': dateKey(entry.key),
          'steps': entry.value.clamp(0, 200000),
          'source': source.sourceApi,
        },
    ];
    final workouts = [for (final workout in data.workouts) workout.toImportJson(source.sourceApi)];

    var created = 0;
    var start = 0;
    do {
      final page = workouts.skip(start).take(importPageSize).toList();
      created += await repository.importData(activities: page, steps: start == 0 ? steps : []);
      start += importPageSize;
    } while (start < workouts.length);

    await storage.setLastSync(now);
    return created;
  }

  /// Stops syncing; already imported workouts stay until the user deletes them.
  Future<void> disconnect() async {
    await storage.setConnected(false);
    await storage.setLastSync(null);
  }
}

/// Where the connection state is stored (memory in tests).
final healthStorageProvider =
    Provider<HealthSettingsStorage>((ref) => SecureHealthSettingsStorage());

/// The health sync of the app.
final healthSyncProvider = Provider<HealthSync>((ref) {
  return HealthSync(
    source: ref.watch(healthSourceProvider),
    repository: ref.watch(activityRepositoryProvider),
    storage: ref.watch(healthStorageProvider),
  );
});

/// Connection state for the activity screen; invalidate after connect / sync / disconnect.
final healthStatusProvider = FutureProvider.autoDispose<HealthStatus>((ref) {
  return ref.watch(healthSyncProvider).status();
});
