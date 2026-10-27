import 'package:flutter/material.dart';

import '../domain/activity.dart';

/// Icon of a type of sport.
IconData activityKindIcon(ActivityKind kind) => switch (kind) {
      ActivityKind.walking => Icons.directions_walk,
      ActivityKind.running => Icons.directions_run,
      ActivityKind.cycling => Icons.directions_bike,
      ActivityKind.swimming => Icons.pool,
      ActivityKind.strength => Icons.fitness_center,
      ActivityKind.yoga => Icons.self_improvement,
      ActivityKind.hiit => Icons.timer,
      ActivityKind.teamSport => Icons.sports_soccer,
      ActivityKind.hiking => Icons.terrain,
      ActivityKind.dancing => Icons.music_note,
      ActivityKind.other => Icons.sports,
    };

/// Icon of the source: hand for manual entries, heart for health apps, link for others.
IconData activitySourceIcon(ActivitySource source) => switch (source) {
      ActivitySource.manual => Icons.edit_note,
      ActivitySource.appleHealth || ActivitySource.healthConnect => Icons.favorite,
      ActivitySource.other => Icons.link,
    };
