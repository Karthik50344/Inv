import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/features/reports/domain/entities/report_kind.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

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

  static AppTone _tone(ReportKind kind) => switch (kind) {
    ReportKind.sales || ReportKind.profitability => AppTone.success,
    ReportKind.purchases || ReportKind.payments => AppTone.info,
    ReportKind.lowStock ||
    ReportKind.customerOutstanding ||
    ReportKind.supplierOutstanding ||
    ReportKind.expenses => AppTone.warning,
    _ => AppTone.brand,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appColors;
    return Scaffold(
      appBar: const AppAppBar(title: 'Reports'),
      body: AppContentWidth(child: ListView.separated(
        padding: AppSpacing.page,
        itemCount: ReportKind.values.length,
        separatorBuilder: (_, _) => AppSpacing.gap8,
        itemBuilder: (context, index) {
          final kind = ReportKind.values[index];
          final colors = _tone(kind).colors(context);
          return AppCard(
            key: Key('report_${kind.name}'),
            padding: const EdgeInsets.all(AppSpacing.s12),
            onTap: () => context.pushNamed(
              RouteNames.reportView,
              pathParameters: {'kind': kind.slug},
            ),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.container,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      _icon(kind),
                      size: 22,
                      color: colors.onContainer,
                    ),
                  ),
                ),
                AppSpacing.hGap12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kind.title, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        kind.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: tokens.textSecondary),
              ],
            ),
          );
        },
      )),
    );
  }
}
