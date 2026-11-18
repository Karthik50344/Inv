import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/constants/app_constants.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:inventrix/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:inventrix/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:inventrix/features/dashboard/presentation/widgets/dashboard_charts.dart';
import 'package:inventrix/features/reports/domain/entities/report_figures.dart';
import 'package:inventrix/features/reports/domain/entities/report_period.dart';
import 'package:inventrix/features/reports/presentation/widgets/period_chips.dart';
import 'package:inventrix/features/reports/presentation/widgets/report_formatters.dart';
import 'package:inventrix/features/reports/presentation/widgets/trend_bar_chart.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// The dashboard: period figures, stock and balance alerts, charts and the
/// latest documents. Provide a [DashboardBloc] above it.
class DashboardPage extends StatelessWidget {
  /// Creates the page.
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        final bloc = context.read<DashboardBloc>();
        return Scaffold(
          appBar: AppAppBar(
            title: 'Dashboard',
            actions: [
              AppIconButton(
                key: const Key('dashboard_refresh'),
                tooltip: 'Refresh',
                icon: Icons.refresh,
                onPressed: () => bloc.add(const DashboardRefreshed()),
              ),
            ],
          ),
          body: _body(context, state, bloc),
        );
      },
    );
  }

  Widget _body(BuildContext context, DashboardState state, DashboardBloc bloc) {
    final snapshot = state.snapshot;
    switch (state.status) {
      case ViewStatus.initial:
        return const LoadingIndicator();
      case ViewStatus.loading:
        return snapshot == null
            ? const LoadingIndicator()
            : _Content(state: state, snapshot: snapshot, bloc: bloc);
      case ViewStatus.failure:
        if (snapshot != null) {
          return _Content(
            state: state,
            snapshot: snapshot,
            bloc: bloc,
            error: state.message,
          );
        }
        return ErrorState(
          message: state.message ?? 'Could not load the dashboard.',
          onRetry: () => bloc.add(const DashboardRefreshed()),
        );
      case ViewStatus.empty:
        return AppRefreshIndicator(
          onRefresh: () async => bloc.add(const DashboardRefreshed()),
          child: ListView(
            physics: AppRefreshIndicator.physics,
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              Text(
                'Welcome to ${AppConstants.appName}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              AppSpacing.gap16,
              EmptyState(
                icon: Icons.insights_outlined,
                title: 'No data yet',
                message:
                    'Sales, stock and balance summaries will appear here '
                    'once you start recording business activity.',
                action: AppButton(
                  key: const Key('dashboard_first_product'),
                  label: 'Add your first product',
                  icon: Icons.add,
                  onPressed: () =>
                      _push(context, bloc, RouteNames.productNew),
                ),
              ),
            ],
          ),
        );
      case ViewStatus.loaded:
        return _Content(state: state, snapshot: snapshot!, bloc: bloc);
    }
  }
}

/// Opens a route and reloads the dashboard when the user comes back, so new
/// documents show up without a manual refresh.
Future<void> _push(
  BuildContext context,
  DashboardBloc bloc,
  String name, {
  Map<String, String> params = const {},
}) async {
  await context.pushNamed(name, pathParameters: params);
  bloc.add(const DashboardRefreshed());
}

class _Content extends StatelessWidget {
  const _Content({
    required this.state,
    required this.snapshot,
    required this.bloc,
    this.error,
  });

  final DashboardState state;
  final DashboardSnapshot snapshot;
  final DashboardBloc bloc;
  final String? error;

  static const MoneyFormatter _money = MoneyFormatter();

  void _openReport(BuildContext context, String slug) =>
      context.pushNamed(RouteNames.reportView, pathParameters: {'kind': slug});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appColors;
    final s = snapshot;
    final lowStock = s.inventory.lowStockCount;
    final outOfStock = s.inventory.outOfStockCount;
    return AppRefreshIndicator(
      onRefresh: () async => bloc.add(const DashboardRefreshed()),
      child: ListView(
        physics: AppRefreshIndicator.physics,
        padding: const EdgeInsets.only(bottom: AppSpacing.s32),
        children: [
          if (state.status == ViewStatus.loading)
            const LinearProgressIndicator(minHeight: 2),
          if (error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s8,
                AppSpacing.s16,
                0,
              ),
              child: AppCard(
                tone: AppTone.danger,
                padding: const EdgeInsets.all(AppSpacing.s12),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: tokens.danger.onContainer,
                    ),
                    AppSpacing.hGap12,
                    Expanded(
                      child: Text(
                        error!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: tokens.danger.onContainer,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => bloc.add(const DashboardRefreshed()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          PeriodChips(
            selected: state.period,
            current: s.range,
            periods: const [
              ReportPeriod.today,
              ReportPeriod.thisMonth,
              ReportPeriod.lastMonth,
              ReportPeriod.last30Days,
              ReportPeriod.thisYear,
              ReportPeriod.custom,
            ],
            onChanged: (period, picked) =>
                bloc.add(DashboardPeriodChanged(period, range: picked)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            child: Text(
              ReportFormatters.range(s.range.from, s.range.to),
              key: const Key('dashboard_range'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ),
          _QuickActions(bloc: bloc),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s16,
              AppSpacing.s16,
              0,
            ),
            child: _HeroCard(snapshot: s),
          ),
          _Section(
            title: 'This period',
            children: [
              AppStatCard(
                label: 'Net purchases',
                value: _money.format(s.purchases.netAfterReturns),
                subtitle: '${s.purchases.count} invoice(s), excl. tax',
                icon: Icons.shopping_cart_checkout_outlined,
                tone: AppTone.info,
              ),
              AppStatCard(
                label: 'Expenses',
                value: _money.format(s.profit.expenses),
                subtitle: '${s.expenses.count} posted, excl. tax',
                icon: Icons.receipt_long_outlined,
                tone: AppTone.warning,
              ),
              AppStatCard(
                label: 'Gross profit',
                value: _money.format(s.profit.grossProfit),
                subtitle: 'Estimate',
                icon: Icons.trending_up,
                tone: s.profit.grossProfit.isNegative
                    ? AppTone.danger
                    : AppTone.success,
                valueTone: s.profit.grossProfit.isNegative
                    ? AppTone.danger
                    : null,
              ),
              AppStatCard(
                label: 'Operating result',
                value: _money.format(s.profit.operatingResult),
                subtitle: 'Estimate',
                icon: Icons.account_balance_outlined,
                tone: s.profit.operatingResult.isNegative
                    ? AppTone.danger
                    : AppTone.success,
                valueTone: s.profit.operatingResult.isNegative
                    ? AppTone.danger
                    : null,
              ),
              AppStatCard(
                label: 'Net cash',
                value: _money.format(s.cash.net),
                subtitle:
                    'In ${_money.format(s.cash.cashIn)} · '
                    'out ${_money.format(s.cash.cashOut)}',
                icon: Icons.payments_outlined,
                tone: s.cash.net.isNegative ? AppTone.danger : AppTone.brand,
                valueTone: s.cash.net.isNegative ? AppTone.danger : null,
              ),
              AppStatCard(
                label: 'Gross margin',
                value: s.profit.grossMarginBasisPoints == null
                    ? '–'
                    : ReportFormatters.percent(
                        s.profit.grossMarginBasisPoints!,
                      ),
                subtitle: 'Of net sales',
                icon: Icons.percent,
                tone: (s.profit.grossMarginBasisPoints ?? 0) < 0
                    ? AppTone.danger
                    : AppTone.brand,
                valueTone: (s.profit.grossMarginBasisPoints ?? 0) < 0
                    ? AppTone.danger
                    : null,
              ),
              AppStatCard(
                label: 'Average sale',
                value: s.averageSale == null ? '–' : _money.format(s.averageSale!),
                subtitle: 'Per invoice, excl. tax',
                icon: Icons.receipt_outlined,
                tone: AppTone.neutral,
              ),
              AppStatCard(
                label: 'Sales returns',
                value: _money.format(s.sales.returnsNet),
                subtitle: '${s.sales.returnsCount} return(s), excl. tax',
                icon: Icons.assignment_return_outlined,
                tone: AppTone.neutral,
              ),
              AppStatCard(
                label: 'Tax collected',
                value: _money.format(s.taxCollected),
                subtitle: 'On sales, after returns',
                icon: Icons.account_balance_wallet_outlined,
                tone: AppTone.neutral,
              ),
            ],
          ),
          _Section(
            title: 'Right now',
            children: [
              AppStatCard(
                label: 'Inventory value',
                value: _money.format(s.inventory.totalValue),
                icon: Icons.inventory_2_outlined,
                onTap: () => _openReport(context, 'inventory'),
              ),
              AppStatCard(
                label: 'Low stock',
                value: '$lowStock',
                subtitle: 'products',
                icon: Icons.warning_amber_rounded,
                tone: lowStock > 0 ? AppTone.warning : AppTone.success,
                valueTone: lowStock > 0 ? AppTone.warning : null,
                onTap: () => _openReport(context, 'low-stock'),
              ),
              AppStatCard(
                label: 'Out of stock',
                value: '$outOfStock',
                subtitle: 'products',
                icon: Icons.remove_shopping_cart_outlined,
                tone: outOfStock > 0 ? AppTone.danger : AppTone.success,
                valueTone: outOfStock > 0 ? AppTone.danger : null,
                onTap: () => _openReport(context, 'low-stock'),
              ),
              AppStatCard(
                label: 'Customers owe',
                value: _money.format(s.receivable),
                icon: Icons.south_west,
                tone: AppTone.success,
                onTap: () => _openReport(context, 'customer-outstanding'),
              ),
              AppStatCard(
                label: 'You owe suppliers',
                value: _money.format(s.payable),
                icon: Icons.north_east,
                tone: AppTone.warning,
                onTap: () => _openReport(context, 'supplier-outstanding'),
              ),
            ],
          ),
          const AppSectionHeader(title: 'Insights'),
          ChartCard(
            title: s.chart.title,
            child: s.chart.isFlat
                ? const NoChartData()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.s16,
                        runSpacing: AppSpacing.s4,
                        children: TrendBarChart.legend(context, s.chart),
                      ),
                      AppSpacing.gap12,
                      TrendBarChart(chart: s.chart),
                    ],
                  ),
          ),
          ChartCard(
            title: 'Sales trend',
            subtitle: 'Running total of net sales',
            child: s.trendChart.isFlat
                ? const NoChartData()
                : TrendLineChart(chart: s.trendChart),
          ),
          ChartCard(
            title: 'Where the money went',
            subtitle: 'Estimate, excluding tax',
            child: RankedBars(
              bars: [
                RankedBar(
                  'Net sales',
                  s.profit.netSales.minorUnits,
                  _money.format(s.profit.netSales),
                ),
                RankedBar(
                  'Cost of goods sold',
                  s.profit.costOfGoodsSold.minorUnits,
                  _money.format(s.profit.costOfGoodsSold),
                ),
                RankedBar(
                  'Operating expenses',
                  s.profit.expenses.minorUnits,
                  _money.format(s.profit.expenses),
                ),
                RankedBar(
                  'Operating result',
                  s.profit.operatingResult.minorUnits,
                  _money.format(s.profit.operatingResult),
                ),
              ],
            ),
          ),
          ChartCard(
            title: 'Expenses by category',
            subtitle: 'Posted expenses, excluding tax',
            child: DonutChart(
              centerText: _money.format(s.expenses.net),
              centerLabel: 'total',
              slices: [
                for (final c in s.expenses.byCategory)
                  DonutSlice(
                    c.categoryName,
                    c.net.minorUnits,
                    _money.format(c.net),
                  ),
              ],
            ),
          ),
          ChartCard(
            title: 'Top products',
            subtitle: 'By net revenue, excluding tax',
            child: RankedBars(
              bars: [
                for (final p in s.topProducts)
                  RankedBar(
                    p.name,
                    p.netRevenue.minorUnits,
                    _money.format(p.netRevenue),
                  ),
              ],
            ),
          ),
          ChartCard(
            title: 'Stock health',
            subtitle: 'Products as of now',
            child: DonutChart(
              centerText:
                  '${s.healthyStockCount + lowStock + outOfStock}',
              centerLabel: 'products',
              colors: [
                tokens.success.solid,
                tokens.warning.solid,
                tokens.danger.solid,
              ],
              slices: [
                DonutSlice(
                  'Healthy',
                  s.healthyStockCount,
                  '${s.healthyStockCount}',
                ),
                DonutSlice('Low', lowStock, '$lowStock'),
                DonutSlice('Out of stock', outOfStock, '$outOfStock'),
              ],
            ),
          ),
          ChartCard(
            title: 'Cash and balances',
            subtitle: 'Cash moved this period, balances as of now',
            child: RankedBars(
              bars: [
                RankedBar(
                  'Cash received',
                  s.cash.cashIn.minorUnits,
                  _money.format(s.cash.cashIn),
                ),
                RankedBar(
                  'Cash paid out',
                  s.cash.cashOut.minorUnits,
                  _money.format(s.cash.cashOut),
                ),
                RankedBar(
                  'Customers owe',
                  s.receivable.minorUnits,
                  _money.format(s.receivable),
                ),
                RankedBar(
                  'You owe suppliers',
                  s.payable.minorUnits,
                  _money.format(s.payable),
                ),
              ],
            ),
          ),
          _Recent(
            title: 'Recent sales',
            icon: Icons.point_of_sale_outlined,
            rows: s.recentSales,
            onViewAll: () => context.goNamed(RouteNames.sales),
          ),
          _Recent(
            title: 'Recent purchases',
            icon: Icons.shopping_bag_outlined,
            rows: s.recentPurchases,
            onViewAll: () => context.pushNamed(RouteNames.purchases),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s24,
              AppSpacing.s16,
              0,
            ),
            child: AppButton(
              key: const Key('dashboard_reports'),
              label: 'All reports',
              icon: Icons.bar_chart_outlined,
              variant: AppButtonVariant.outlined,
              expand: true,
              onPressed: () => context.pushNamed(RouteNames.reports),
            ),
          ),
        ],
      ),
    );
  }
}

/// The headline figure of the period: net sales.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appColors;
    final s = snapshot;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.brand.container,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.point_of_sale_outlined,
                    size: 18,
                    color: tokens.brand.onContainer,
                  ),
                ),
              ),
              AppSpacing.hGap12,
              Text(
                'Net sales',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          AppSpacing.gap12,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: AppCurrencyText(
              s.sales.netAfterReturns,
              size: AppCurrencySize.large,
            ),
          ),
          AppSpacing.gap4,
          Text(
            '${s.sales.count} invoice(s), excl. tax',
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A horizontally scrolling row of shortcuts to the most common tasks.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.bloc});

  final DashboardBloc bloc;

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        key: const Key('quick_new_sale'),
        label: 'New sale',
        icon: Icons.point_of_sale_outlined,
        tone: AppTone.brand,
        onTap: () => _push(context, bloc, RouteNames.saleNew),
      ),
      _QuickAction(
        key: const Key('quick_new_purchase'),
        label: 'New purchase',
        icon: Icons.shopping_bag_outlined,
        tone: AppTone.info,
        onTap: () => _push(context, bloc, RouteNames.purchaseNew),
      ),
      _QuickAction(
        key: const Key('quick_new_product'),
        label: 'Add product',
        icon: Icons.add_box_outlined,
        tone: AppTone.success,
        onTap: () => _push(context, bloc, RouteNames.productNew),
      ),
      _QuickAction(
        key: const Key('quick_new_expense'),
        label: 'Add expense',
        icon: Icons.receipt_long_outlined,
        tone: AppTone.warning,
        onTap: () => _push(context, bloc, RouteNames.expenseNew),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s16),
      child: SizedBox(
        height: 88,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          itemCount: actions.length,
          separatorBuilder: (_, _) => AppSpacing.hGap12,
          itemBuilder: (_, i) => actions[i],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.tone,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final AppTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = tone.colors(context);
    return SizedBox(
      width: 104,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s12,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.container,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(icon, size: 20, color: colors.onContainer),
              ),
            ),
            AppSpacing.gap8,
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 600 ? 3 : 2;
              const gap = AppSpacing.s12;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final c in children) SizedBox(width: width, child: c),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({
    required this.title,
    required this.icon,
    required this.rows,
    required this.onViewAll,
  });

  final String title;
  final IconData icon;
  final List<DocumentRow> rows;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: rows.isEmpty ? null : 'View all',
          onAction: rows.isEmpty ? null : onViewAll,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    child: Text(
                      'None yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: tokens.divider),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s16,
                            vertical: AppSpacing.s12,
                          ),
                          child: Row(
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: tokens.neutral.container,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.small,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    icon,
                                    size: 18,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                              ),
                              AppSpacing.hGap12,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${rows[i].number} · ${rows[i].partyName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      ReportFormatters.day(rows[i].date),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: tokens.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              AppSpacing.hGap12,
                              AppCurrencyText(rows[i].total),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
