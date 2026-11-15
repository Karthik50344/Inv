import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/features/reports/domain/entities/report_kind.dart';

/// The list of reports.
class ReportsPage extends StatelessWidget {
  /// Creates the page.
  const ReportsPage({super.key});

  static IconData _icon(ReportKind kind) => switch (kind) {
    ReportKind.sales => Icons.point_of_sale_outlined,
    ReportKind.purchases => Icons.shopping_cart_outlined,
    ReportKind.inventory => Icons.inventory_2_outlined,
    ReportKind.stockMovements => Icons.swap_vert_outlined,
    ReportKind.lowStock => Icons.warning_amber_outlined,
    ReportKind.productPerformance => Icons.leaderboard_outlined,
    ReportKind.customerOutstanding => Icons.people_outline,
    ReportKind.supplierOutstanding => Icons.local_shipping_outlined,
    ReportKind.payments => Icons.payments_outlined,
    ReportKind.expenses => Icons.account_balance_wallet_outlined,
    ReportKind.profitability => Icons.trending_up_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        children: [
          for (final kind in ReportKind.values)
            ListTile(
              key: Key('report_${kind.name}'),
              leading: Icon(_icon(kind)),
              title: Text(kind.title),
              subtitle: Text(kind.description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed(
                RouteNames.reportView,
                pathParameters: {'kind': kind.slug},
              ),
            ),
        ],
      ),
    );
  }
}
