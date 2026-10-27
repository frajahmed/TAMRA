import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';

/// Activity tab. Sport entries and Apple Health / Health Connect follow in sprint 5.
class ActivityScreen extends StatelessWidget {
  /// Creates the activity screen.
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.navActivity)),
      body: Center(child: Text(strings.comingSoon, key: const Key('activity-coming'))),
    );
  }
}
