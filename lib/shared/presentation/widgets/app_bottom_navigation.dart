import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';

/// One destination of the bottom bar or rail.
class AppNavItem {
  /// Creates a destination.
  const AppNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  /// Text under the icon.
  final String label;

  /// Icon when not selected.
  final IconData icon;

  /// Icon when selected.
  final IconData selectedIcon;
}

/// Bottom navigation for phones: a Material [NavigationBar] with a hairline
/// top border, always showing labels.
class AppBottomNavigation extends StatelessWidget {
  /// Creates the bar.
  const AppBottomNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  /// Destinations.
  final List<AppNavItem> items;

  /// Index of the active destination.
  final int selectedIndex;

  /// Called with the tapped index.
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.appColors.border)),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        destinations: [
          for (final item in items)
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

/// Side navigation for wide screens: a Material [NavigationRail] topped by
/// the Inventrix mark, with a hairline right border.
class AppNavigationRail extends StatelessWidget {
  /// Creates the rail.
  const AppNavigationRail({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  /// Destinations.
  final List<AppNavItem> items;

  /// Index of the active destination.
  final int selectedIndex;

  /// Called with the tapped index.
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: context.appColors.border)),
      ),
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        labelType: NavigationRailLabelType.all,
        leading: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s8),
          child: Image.asset(
            dark
                ? 'assets/branding/inventrix_symbol_dark.png'
                : 'assets/branding/inventrix_symbol.png',
            width: 32,
            height: 32,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const SizedBox(width: 32, height: 32),
          ),
        ),
        destinations: [
          for (final item in items)
            NavigationRailDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: Text(item.label),
            ),
        ],
      ),
    );
  }
}
