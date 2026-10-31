import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

import '../../../core/json.dart';
import '../domain/activity.dart';

/// Reads workouts and steps from the phone's health hub. The rest of the app only knows
/// this interface, so the `health` package is used in this file alone and tests use a fake.
abstract interface class HealthSource {
  /// True on iPhone (Apple Health) and Android (Health Connect).
  bool get isSupported;

  /// Name of the hub shown to the user ("Apple Health" or "Health Connect").
  String get displayName;

  /// API value of the source (`apple_health` or `health_connect`).
  String get sourceApi;

  /// Asks the user for read access; true when granted.
  Future<bool> requestPermission();

  /// Workouts and daily steps between [from] and [to].
  Future<HealthImport> read({required DateTime from, required DateTime to});
}

/// Apple Health / Health Connect through the `health` package (read only).
class DeviceHealthSource implements HealthSource {
  /// Creates the source.
  DeviceHealthSource();

  static const _types = [HealthDataType.WORKOUT, HealthDataType.STEPS];

  final Health _health = Health();
  bool _configured = false;

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  bool get isSupported => Platform.isIOS || Platform.isAndroid;

  @override
  String get displayName => Platform.isIOS ? 'Apple Health' : 'Health Connect';

  @override
  String get sourceApi => Platform.isIOS ? 'apple_health' : 'health_connect';

  @override
  Future<bool> requestPermission() async {
    await _configure();
    return _health.requestAuthorization(
      _types,
      permissions: [for (final _ in _types) HealthDataAccess.READ],
    );
  }

  @override
  Future<HealthImport> read(
      {required DateTime from, required DateTime to}) async {
    await _configure();
    final points = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.WORKOUT],
      startTime: from,
      endTime: to,
    );
    final workouts = <HealthWorkout>[];
    for (final point in points) {
      final value = point.value;
      if (value is! WorkoutHealthValue) continue;
      final minutes = point.dateTo.difference(point.dateFrom).inMinutes;
      if (minutes < 1) continue;
      workouts.add(
        HealthWorkout(
          externalId: point.uuid,
          start: point.dateFrom,
          minutes: minutes,
          kcal: (value.totalEnergyBurned ?? 0).toDouble(),
          distanceM: value.totalDistance?.round(),
          kind: activityKindFromHealth(value.workoutActivityType.name),
          title: point.sourceName,
        ),
      );
    }

    final steps = <DateTime, int>{};
    for (var day = dateOnly(from);
        !day.isAfter(to);
        day = DateTime(day.year, day.month, day.day + 1)) {
      final next = DateTime(day.year, day.month, day.day + 1);
      final count = await _health.getTotalStepsInInterval(
          day, next.isAfter(to) ? to : next);
      if (count != null && count > 0) steps[day] = count;
    }
    return HealthImport(workouts: workouts, stepsByDay: steps);
  }
}

/// The health hub of the phone; widget tests replace it with a fake.
final healthSourceProvider =
    Provider<HealthSource>((ref) => DeviceHealthSource());
