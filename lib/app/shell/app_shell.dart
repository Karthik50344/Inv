import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';

class _NavItem {
  const _NavItem(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Navigation scaffold: bottom bar on phones, rail on wide screens.
class AppShell extends StatelessWidget {
  /// Creates the shell around the active branch.
  const AppShell({required this.navigationShell, super.key});

  /// The active branch container provided by GoRouter.
  final StatefulNavigationShell navigationShell;

  static const List<_NavItem> _items = [
    _NavItem('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
    _NavItem('Products', Icons.inventory_2_outlined, Icons.inventory_2),
    _NavItem('Inventory', Icons.warehouse_outlined, Icons.warehouse),
    _NavItem('Sales', Icons.receipt_long_outlined, Icons.receipt_long),
    _NavItem('More', Icons.more_horiz, Icons.more_horiz),
  ];

  void _select(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final isWide =
        MediaQuery.sizeOf(context).width >= AppDimensions.wideLayoutBreakpoint;
    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final item in _items)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _select,
        destinations: [
          for (final item in _items)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: item.label,
            ),
        ],
      ),
    );
  }
}
