import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// One tab of the [NavDock].
class NavDockItem {
  /// Creates a tab with icon, label and a widget key for tests.
  const NavDockItem({required this.icon, required this.label, required this.keyName});

  /// Icon of the tab.
  final IconData icon;

  /// Text under the icon (also read by screen readers).
  final String label;

  /// Value of the tab's `Key` (e.g. `nav-diary`).
  final String keyName;
}

/// Floating bottom navigation: two tabs, a round centre button, two tabs.
class NavDock extends StatelessWidget {
  /// Creates the dock with exactly four [items].
  const NavDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    required this.onCenter,
    required this.centerLabel,
  });

  /// The four tabs, left to right (mirrored in right-to-left languages).
  final List<NavDockItem> items;

  /// Index of the selected tab.
  final int currentIndex;

  /// Called with the index of the tapped tab.
  final ValueChanged<int> onSelected;

  /// Called by the centre button (add food).
  final VoidCallback onCenter;

  /// Tooltip and screen-reader text of the centre button.
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    Widget tab(int index) {
      final item = items[index];
      final selected = index == currentIndex;
      final color = selected ? colors.brand : colors.textSecondary;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: InkWell(
            key: Key(item.keyName),
            borderRadius: BorderRadius.circular(20),
            onTap: () => onSelected(index),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, color: color),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              tab(0),
              tab(1),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
                child: IconButton.filled(
                  key: const Key('nav-scan'),
                  tooltip: centerLabel,
                  iconSize: 30,
                  style: IconButton.styleFrom(
                    backgroundColor: colors.brand,
                    foregroundColor: Colors.white,
                    fixedSize: const Size(56, 56),
                  ),
                  icon: const Icon(Icons.add),
                  onPressed: onCenter,
                ),
              ),
              tab(2),
              tab(3),
            ],
          ),
        ),
      ),
    );
  }
}
