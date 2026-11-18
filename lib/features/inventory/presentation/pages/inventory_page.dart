import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/inventory/domain/entities/inventory_valuation.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_status.dart';
import 'package:inventrix/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:inventrix/features/inventory/presentation/bloc/inventory_event.dart';
import 'package:inventrix/features/inventory/presentation/bloc/inventory_state.dart';
import 'package:inventrix/features/inventory/presentation/widgets/stock_status_chip.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Current stock for every product, with valuation and low/out filters.
///
/// Also used as the low-stock report ([isReport]).
class InventoryPage extends StatelessWidget {
  /// Creates the page. Provide an [InventoryBloc] above it.
  const InventoryPage({
    this.title = 'Inventory',
    this.isReport = false,
    super.key,
  });

  /// App bar title.
  final String title;

  /// Whether this is the low-stock report (hides report shortcuts).
  final bool isReport;

  Future<void> _push(
    BuildContext context,
    String name, {
    Map<String, String> params = const {},
  }) async {
    final bloc = context.read<InventoryBloc>();
    await context.pushNamed(name, pathParameters: params);
    bloc.add(const InventoryRefreshed());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InventoryBloc, InventoryState>(
      listenWhen: (previous, current) =>
          current.message != null && current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final bloc = context.read<InventoryBloc>();
        return Scaffold(
          appBar: AppAppBar(
            title: title,
            actions: [
              if (!isReport) ...[
                AppIconButton(
                  key: const Key('open_low_stock'),
                  tooltip: 'Low-stock report',
                  icon: Icons.warning_amber_outlined,
                  onPressed: () => _push(context, RouteNames.lowStock),
                ),
                AppIconButton(
                  key: const Key('open_reconcile'),
                  tooltip: 'Reconcile',
                  icon: Icons.fact_check_outlined,
                  onPressed: () => _push(context, RouteNames.reconcile),
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              if (state.valuation != null && !isReport)
                _ValuationCard(valuation: state.valuation!),
              AppSearchField(
                hintText: 'Search name, SKU or barcode',
                onChanged: (query) => bloc.add(InventorySearchChanged(query)),
              ),
              if (!isReport) _StatusFilters(state: state),
              Expanded(child: _body(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, InventoryState state) {
    final bloc = context.read<InventoryBloc>();
    switch (state.status) {
      case ViewStatus.initial:
      case ViewStatus.loading:
        return const LoadingIndicator();
      case ViewStatus.failure:
        return ErrorState(
          message: state.message ?? 'Could not load stock.',
          onRetry: () => bloc.add(const InventoryRefreshed()),
        );
      case ViewStatus.empty:
        return EmptyState(
          icon: isReport
              ? Icons.check_circle_outline
              : Icons.warehouse_outlined,
          title: isReport
              ? 'Nothing needs restocking'
              : (state.filter.query.isNotEmpty ||
                        state.filter.status != StockStatusFilter.all
                    ? 'No matching products'
                    : 'No products yet'),
          message: isReport
              ? 'No product is low or out of stock.'
              : 'Add products first, then record their stock here.',
        );
      case ViewStatus.loaded:
        final tokens = context.appColors;
        final theme = Theme.of(context);
        return AppRefreshIndicator(
          onRefresh: () async => bloc.add(const InventoryRefreshed()),
          child: ListView.separated(
            physics: AppRefreshIndicator.physics,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s4,
              AppSpacing.s16,
              AppSpacing.s24,
            ),
            itemCount: state.items.length,
            separatorBuilder: (_, _) => AppSpacing.gap8,
            itemBuilder: (context, index) {
              final item = state.items[index];
              final symbol = state.units[item.product.unitId]?.symbol ?? '';
              return AppCard(
                key: Key('stock_${item.product.id}'),
                padding: const EdgeInsets.all(AppSpacing.s12),
                onTap: () => _push(
                  context,
                  RouteNames.stockDetail,
                  params: {'id': item.product.id},
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.product.sku,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: tokens.textSecondary,
                            ),
                          ),
                          AppSpacing.gap4,
                          StockStatusChip(status: item.status),
                        ],
                      ),
                    ),
                    AppSpacing.hGap8,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${item.balance.quantityOnHand.toDecimalString()} $symbol'
                              .trim(),
                          style: context.appText.financialSmall,
                        ),
                        AppSpacing.gap4,
                        AppCurrencyText(
                          item.balance.inventoryValue,
                          tone: AppTone.neutral,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
    }
  }
}

class _ValuationCard extends StatelessWidget {
  const _ValuationCard({required this.valuation});

  final InventoryValuation valuation;

  @override
  Widget build(BuildContext context) {
    const formatter = MoneyFormatter();
    final theme = Theme.of(context);
    final tokens = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s16,
        0,
      ),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inventory value',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                  AppSpacing.gap4,
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      formatter.format(valuation.totalValue),
                      key: const Key('inventory_total_value'),
                      style: context.appText.financialMedium,
                    ),
                  ),
                  Text(
                    '${valuation.productsInStock} products in stock',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.hGap12,
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _CountPill(
                  '${valuation.lowStockCount} low',
                  AppTone.warning,
                  const Key('inventory_low_count'),
                ),
                AppSpacing.gap8,
                _CountPill(
                  '${valuation.outOfStockCount} out',
                  AppTone.danger,
                  const Key('inventory_out_count'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill(this.text, this.tone, this.pillKey);

  final String text;
  final AppTone tone;
  final Key pillKey;

  @override
  Widget build(BuildContext context) =>
      AppBadge(key: pillKey, label: text, tone: tone);
}

class _StatusFilters extends StatelessWidget {
  const _StatusFilters({required this.state});

  final InventoryState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<InventoryBloc>();
    Widget chip(String label, StockStatusFilter value) => Padding(
      padding: const EdgeInsets.only(right: AppSpacing.s8),
      child: AppChip(
        key: Key('filter_${value.name}'),
        label: label,
        selected: state.filter.status == value,
        onSelected: (_) => bloc.add(InventoryStatusFilterChanged(value)),
      ),
    );
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s4,
        ),
        children: [
          chip('All', StockStatusFilter.all),
          chip('Low stock', StockStatusFilter.low),
          chip('Out of stock', StockStatusFilter.out),
        ],
      ),
    );
  }
}
