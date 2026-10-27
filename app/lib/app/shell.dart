import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/nav_dock.dart';
import '../features/diary/presentation/add_food_flow.dart';
import '../features/food/domain/food.dart';
import '../l10n/app_strings.dart';
import 'router.dart';

/// Frame around the four main tabs with the floating navigation dock.
/// The centre button adds food (scan or search) to the day shown in the diary.
class AppShell extends ConsumerWidget {
  /// Creates the frame for [navigationShell] (provided by go_router).
  const AppShell({super.key, required this.navigationShell});

  /// The tab navigation of go_router; each tab keeps its own state.
  final StatefulNavigationShell navigationShell;

  Future<void> _addFood(BuildContext context, WidgetRef ref) async {
    final strings = AppStrings.of(context);
    final route = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('sheet-scan'),
              leading: const Icon(Icons.qr_code_scanner),
              title: Text(strings.scanTitle),
              onTap: () => Navigator.of(sheetContext).pop(AppRoutes.foodScan),
            ),
            ListTile(
              key: const Key('sheet-search'),
              leading: const Icon(Icons.search),
              title: Text(strings.foodSearchTitle),
              onTap: () => Navigator.of(sheetContext).pop(AppRoutes.foodSearch),
            ),
          ],
        ),
      ),
    );
    if (route == null || !context.mounted) return;
    final food = await context.push<Food>(route);
    if (food == null || !context.mounted) return;
    final saved = await addFoodToDiary(
      context,
      ref,
      food: food,
      meal: mealForTime(DateTime.now()),
    );
    if (saved) navigationShell.goBranch(0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavDock(
        currentIndex: navigationShell.currentIndex,
        centerLabel: strings.addFood,
        onCenter: () => _addFood(context, ref),
        // Tapping the open tab again goes back to its start page.
        onSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: [
          NavDockItem(icon: Icons.menu_book, label: strings.navDiary, keyName: 'nav-diary'),
          NavDockItem(icon: Icons.bar_chart, label: strings.navStats, keyName: 'nav-stats'),
          NavDockItem(
            icon: Icons.directions_run,
            label: strings.navActivity,
            keyName: 'nav-activity',
          ),
          NavDockItem(icon: Icons.person, label: strings.navProfile, keyName: 'nav-profile'),
        ],
      ),
    );
  }
}
