import 'package:flutter/material.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/router/route_paths.dart';

/// Section of the More screen an entry belongs to.
enum MoreGroup {
  /// Day-to-day business documents and contacts.
  operations('Operations'),

  /// Analysis.
  insights('Insights'),

  /// Data and configuration.
  system('System');

  const MoreGroup(this.label);

  /// Heading shown above the group.
  final String label;
}

/// An entry in the "More" section.
class MoreDestination {
  /// Creates a destination.
  const MoreDestination({
    required this.name,
    required this.path,
    required this.title,
    required this.icon,
    required this.phase,
    required this.group,
    required this.subtitle,
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

  /// Section of the More screen.
  final MoreGroup group;

  /// One-line description shown under the title.
  final String subtitle;
}

/// Everything reachable from the "More" tab.
const List<MoreDestination> moreDestinations = [
  MoreDestination(
    name: RouteNames.purchases,
    path: RoutePaths.purchases,
    title: 'Purchases',
    icon: Icons.shopping_cart_outlined,
    phase: 4,
    group: MoreGroup.operations,
    subtitle: 'Supplier bills and receiving',
  ),
  MoreDestination(
    name: RouteNames.customers,
    path: RoutePaths.customers,
    title: 'Customers',
    icon: Icons.people_outline,
    phase: 2,
    group: MoreGroup.operations,
    subtitle: 'Contacts and balances',
  ),
  MoreDestination(
    name: RouteNames.suppliers,
    path: RoutePaths.suppliers,
    title: 'Suppliers',
    icon: Icons.local_shipping_outlined,
    phase: 2,
    group: MoreGroup.operations,
    subtitle: 'Contacts and payables',
  ),
  MoreDestination(
    name: RouteNames.payments,
    path: RoutePaths.payments,
    title: 'Payments',
    icon: Icons.payments_outlined,
    phase: 6,
    group: MoreGroup.operations,
    subtitle: 'Receipts and settlements',
  ),
  MoreDestination(
    name: RouteNames.returns,
    path: RoutePaths.returns,
    title: 'Returns',
    icon: Icons.assignment_return_outlined,
    phase: 7,
    group: MoreGroup.operations,
    subtitle: 'Sales and purchase returns',
  ),
  MoreDestination(
    name: RouteNames.expenses,
    path: RoutePaths.expenses,
    title: 'Expenses',
    icon: Icons.account_balance_wallet_outlined,
    phase: 8,
    group: MoreGroup.operations,
    subtitle: 'Day-to-day costs',
  ),
  MoreDestination(
    name: RouteNames.reports,
    path: RoutePaths.reports,
    title: 'Reports',
    icon: Icons.bar_chart_outlined,
    phase: 9,
    group: MoreGroup.insights,
    subtitle: 'Sales, stock and profit',
  ),
  MoreDestination(
    name: RouteNames.backup,
    path: RoutePaths.backup,
    title: 'Backup',
    icon: Icons.backup_outlined,
    phase: 10,
    group: MoreGroup.system,
    subtitle: 'Export and restore your data',
  ),
  MoreDestination(
    name: RouteNames.tax,
    path: RoutePaths.taxSettings,
    title: 'Tax settings',
    icon: Icons.percent,
    phase: 12,
    group: MoreGroup.system,
    subtitle: 'Tax categories, rules and rates',
  ),
  MoreDestination(
    name: RouteNames.audit,
    path: RoutePaths.audit,
    title: 'Audit & export',
    icon: Icons.fact_check_outlined,
    phase: 12,
    group: MoreGroup.system,
    subtitle: 'Activity log and auditor exports',
  ),
  MoreDestination(
    name: RouteNames.settings,
    path: RoutePaths.settings,
    title: 'Settings',
    icon: Icons.settings_outlined,
    phase: 11,
    group: MoreGroup.system,
    subtitle: 'Business, tax and preferences',
  ),
];
