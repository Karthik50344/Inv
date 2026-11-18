import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/shared/presentation/widgets/app_bottom_navigation.dart';

/// Frame around the five main tabs: bottom bar on phones, side rail on wide
/// screens. The tab content is the [navigationShell] and keeps its own state.
class AppShell extends StatelessWidget {
  /// Creates the shell.
  const AppShell({required this.navigationShell, super.key});

  /// The router's tab container.
  final StatefulNavigationShell navigationShell;

  static const List<AppNavItem> _items = [
    AppNavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    AppNavItem(
      label: 'Products',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
    ),
    AppNavItem(
      label: 'Inventory',
      icon: Icons.warehouse_outlined,
      selectedIcon: Icons.warehouse,
    ),
    AppNavItem(
      label: 'Sales',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
    ),
    AppNavItem(
      label: 'More',
      icon: Icons.more_horiz,
      selectedIcon: Icons.more_horiz,
    ),
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
            AppNavigationRail(
              items: _items,
              selectedIndex: navigationShell.currentIndex,
              onSelected: _select,
            ),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomNavigation(
        items: _items,
        selectedIndex: navigationShell.currentIndex,
        onSelected: _select,
      ),
    );
  }
}
