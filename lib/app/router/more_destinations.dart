import 'package:flutter/material.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/router/route_paths.dart';

/// An entry in the "More" section.
class MoreDestination {
  /// Creates a destination.
  const MoreDestination({
    required this.name,
    required this.path,
    required this.title,
    required this.icon,
    required this.phase,
  });

  /// Route name.
  final String name;

  /// Absolute route path.
  final String path;

  /// Title shown in lists and app bars.
  final String title;

  /// Leading icon.
  final IconData icon;

  /// Roadmap phase that implements the feature.
  final int phase;
}

/// Everything reachable from the "More" tab.
const List<MoreDestination> moreDestinations = [
  MoreDestination(
    name: RouteNames.purchases,
    path: RoutePaths.purchases,
    title: 'Purchases',
    icon: Icons.shopping_cart_outlined,
    phase: 4,
  ),
  MoreDestination(
    name: RouteNames.customers,
    path: RoutePaths.customers,
    title: 'Customers',
    icon: Icons.people_outline,
    phase: 2,
  ),
  MoreDestination(
    name: RouteNames.suppliers,
    path: RoutePaths.suppliers,
    title: 'Suppliers',
    icon: Icons.local_shipping_outlined,
    phase: 2,
  ),
  MoreDestination(
    name: RouteNames.payments,
    path: RoutePaths.payments,
    title: 'Payments',
    icon: Icons.payments_outlined,
    phase: 6,
  ),
  MoreDestination(
    name: RouteNames.returns,
    path: RoutePaths.returns,
    title: 'Returns',
    icon: Icons.assignment_return_outlined,
    phase: 7,
  ),
  MoreDestination(
    name: RouteNames.expenses,
    path: RoutePaths.expenses,
    title: 'Expenses',
    icon: Icons.account_balance_wallet_outlined,
    phase: 8,
  ),
  MoreDestination(
    name: RouteNames.reports,
    path: RoutePaths.reports,
    title: 'Reports',
    icon: Icons.bar_chart_outlined,
    phase: 9,
  ),
  MoreDestination(
    name: RouteNames.backup,
    path: RoutePaths.backup,
    title: 'Backup',
    icon: Icons.backup_outlined,
    phase: 10,
  ),
  MoreDestination(
    name: RouteNames.settings,
    path: RoutePaths.settings,
    title: 'Settings',
    icon: Icons.settings_outlined,
    phase: 11,
  ),
];
