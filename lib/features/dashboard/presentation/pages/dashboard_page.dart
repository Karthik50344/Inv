import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
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
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';
import 'package:inventrix/shared/presentation/widgets/local_data_warning_banner.dart';

/// The dashboard: period figures, stock and balance alerts, a chart and the
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
          appBar: AppBar(
            title: const Text('Dashboard'),
            actions: [
              IconButton(
                key: const Key('dashboard_refresh'),
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
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
        return ListView(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          children: [
            Text(
              'Welcome to ${AppConstants.appName}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppDimensions.spaceMd),
            const LocalDataWarningBanner(),
            const SizedBox(height: AppDimensions.spaceLg),
            const EmptyState(
              icon: Icons.insights_outlined,
              title: 'No data yet',
              message:
                  'Sales, stock and balance summaries will appear here '
                  'once you start recording business activity.',
            ),
          ],
        );
      case ViewStatus.loaded:
        return _Content(state: state, snapshot: snapshot!, bloc: bloc);
    }
  }
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
    final s = snapshot;
    return RefreshIndicator(
      onRefresh: () async => bloc.add(const DashboardRefreshed()),
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppDimensions.spaceLg),
        children: [
          if (state.status == ViewStatus.loading)
            const LinearProgressIndicator(),
          if (error != null)
            MaterialBanner(
              content: Text(error!),
              actions: [
                TextButton(
                  onPressed: () => bloc.add(const DashboardRefreshed()),
                  child: const Text('Retry'),
                ),
              ],
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceMd,
            ),
            child: Text(
              ReportFormatters.range(s.range.from, s.range.to),
              key: const Key('dashboard_range'),
              style: theme.textTheme.bodySmall,
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(AppDimensions.spaceMd),
            child: LocalDataWarningBanner(),
          ),
          _Section(
            title: 'This period',
            children: [
              _Tile(
                'Net sales',
                _money.format(s.sales.netAfterReturns),
                hint: '${s.sales.count} invoice(s), excl. tax',
              ),
              _Tile(
                'Net purchases',
                _money.format(s.purchases.netAfterReturns),
                hint: '${s.purchases.count} invoice(s), excl. tax',
              ),
              _Tile(
                'Expenses',
                _money.format(s.profit.expenses),
                hint: '${s.expenses.count} posted, excl. tax',
              ),
              _Tile(
                'Gross profit',
                _money.format(s.profit.grossProfit),
                hint: 'Estimate',
                negative: s.profit.grossProfit.isNegative,
              ),
              _Tile(
                'Operating result',
                _money.format(s.profit.operatingResult),
                hint: 'Estimate',
                negative: s.profit.operatingResult.isNegative,
              ),
              _Tile(
                'Net cash',
                _money.format(s.cash.net),
                hint:
                    'In ${_money.format(s.cash.cashIn)} · '
                    'out ${_money.format(s.cash.cashOut)}',
                negative: s.cash.net.isNegative,
              ),
              _Tile(
                'Gross margin',
                s.profit.grossMarginBasisPoints == null
                    ? '–'
                    : ReportFormatters.percent(
                        s.profit.grossMarginBasisPoints!,
                      ),
                hint: 'Of net sales',
                negative: (s.profit.grossMarginBasisPoints ?? 0) < 0,
              ),
              _Tile(
                'Average sale',
                s.averageSale == null ? '–' : _money.format(s.averageSale!),
                hint: 'Per invoice, excl. tax',
              ),
              _Tile(
                'Sales returns',
                _money.format(s.sales.returnsNet),
                hint: '${s.sales.returnsCount} return(s), excl. tax',
              ),
              _Tile(
                'Tax collected',
                _money.format(s.taxCollected),
                hint: 'On sales, after returns',
              ),
            ],
          ),
          _Section(
            title: 'Right now',
            children: [
              _Tile(
                'Inventory value',
                _money.format(s.inventory.totalValue),
                onTap: () => _openReport(context, 'inventory'),
              ),
              _Tile(
                'Low stock',
                '${s.inventory.lowStockCount}',
                hint: 'products',
                onTap: () => _openReport(context, 'low-stock'),
              ),
              _Tile(
                'Out of stock',
                '${s.inventory.outOfStockCount}',
                hint: 'products',
                onTap: () => _openReport(context, 'low-stock'),
              ),
              _Tile(
                'Customers owe',
                _money.format(s.receivable),
                onTap: () => _openReport(context, 'customer-outstanding'),
              ),
              _Tile(
                'You owe suppliers',
                _money.format(s.payable),
                onTap: () => _openReport(context, 'supplier-outstanding'),
              ),
            ],
          ),
          ChartCard(
            title: s.chart.title,
            child: s.chart.isFlat
                ? const NoChartData()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppDimensions.spaceMd,
                        children: TrendBarChart.legend(context, s.chart),
                      ),
                      const SizedBox(height: AppDimensions.spaceSm),
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
                  '${s.healthyStockCount + s.inventory.lowStockCount + s.inventory.outOfStockCount}',
              centerLabel: 'products',
              slices: [
                DonutSlice(
                  'Healthy',
                  s.healthyStockCount,
                  '${s.healthyStockCount}',
                ),
                DonutSlice(
                  'Low',
                  s.inventory.lowStockCount,
                  '${s.inventory.lowStockCount}',
                ),
                DonutSlice(
                  'Out of stock',
                  s.inventory.outOfStockCount,
                  '${s.inventory.outOfStockCount}',
                ),
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
          _Recent(title: 'Recent sales', rows: s.recentSales),
          _Recent(title: 'Recent purchases', rows: s.recentPurchases),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: OutlinedButton.icon(
              key: const Key('dashboard_reports'),
              onPressed: () => context.pushNamed(RouteNames.reports),
              icon: const Icon(Icons.bar_chart_outlined),
              label: const Text('All reports'),
            ),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spaceMd,
        0,
        AppDimensions.spaceMd,
        AppDimensions.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppDimensions.spaceSm),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 600 ? 3 : 2;
              const gap = AppDimensions.spaceSm;
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
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(
    this.label,
    this.value, {
    this.hint,
    this.negative = false,
    this.onTap,
  });

  final String label;
  final String value;
  final String? hint;
  final bool negative;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: negative ? theme.colorScheme.error : null,
                  ),
                ),
              ),
              if (hint != null)
                Text(
                  hint!,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.title, required this.rows});

  final String title;
  final List<DocumentRow> rows;

  @override
  Widget build(BuildContext context) {
    const money = MoneyFormatter();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spaceMd,
        AppDimensions.spaceMd,
        AppDimensions.spaceMd,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'None yet.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            for (final r in rows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${r.number} · ${r.partyName}'),
                subtitle: Text(ReportFormatters.day(r.date)),
                trailing: Text(money.format(r.total)),
              ),
        ],
      ),
    );
  }
}
