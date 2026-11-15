import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/inventory/domain/entities/inventory_valuation.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_status.dart';
import 'package:inventrix/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:inventrix/features/inventory/presentation/bloc/inventory_event.dart';
import 'package:inventrix/features/inventory/presentation/bloc/inventory_state.dart';
import 'package:inventrix/features/inventory/presentation/widgets/stock_status_chip.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';
import 'package:inventrix/shared/presentation/widgets/search_field.dart';

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
          appBar: AppBar(
            title: Text(title),
            actions: [
              if (!isReport) ...[
                IconButton(
                  key: const Key('open_low_stock'),
                  tooltip: 'Low-stock report',
                  icon: const Icon(Icons.warning_amber_outlined),
                  onPressed: () => _push(context, RouteNames.lowStock),
                ),
                IconButton(
                  key: const Key('open_reconcile'),
                  tooltip: 'Reconcile',
                  icon: const Icon(Icons.fact_check_outlined),
                  onPressed: () => _push(context, RouteNames.reconcile),
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              if (state.valuation != null && !isReport)
                _ValuationCard(valuation: state.valuation!),
              SearchField(
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
        const formatter = MoneyFormatter();
        return ListView.separated(
          itemCount: state.items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = state.items[index];
            final symbol = state.units[item.product.unitId]?.symbol ?? '';
            return ListTile(
              key: Key('stock_${item.product.id}'),
              title: Text(item.product.name),
              subtitle: Text(
                '${item.product.sku} · '
                '${item.balance.quantityOnHand.toDecimalString()} $symbol · '
                '${formatter.format(item.balance.inventoryValue)}',
              ),
              trailing: StockStatusChip(status: item.status),
              onTap: () => _push(
                context,
                RouteNames.stockDetail,
                params: {'id': item.product.id},
              ),
            );
          },
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
    return Card(
      margin: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Inventory value', style: theme.textTheme.labelMedium),
                  Text(
                    formatter.format(valuation.totalValue),
                    key: const Key('inventory_total_value'),
                    style: theme.textTheme.titleLarge,
                  ),
                  Text('${valuation.productsInStock} products in stock'),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${valuation.lowStockCount} low',
                  key: const Key('inventory_low_count'),
                ),
                Text(
                  '${valuation.outOfStockCount} out',
                  key: const Key('inventory_out_count'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusFilters extends StatelessWidget {
  const _StatusFilters({required this.state});

  final InventoryState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<InventoryBloc>();
    Widget chip(String label, StockStatusFilter value) => Padding(
      padding: const EdgeInsets.only(right: AppDimensions.spaceSm),
      child: ChoiceChip(
        key: Key('filter_${value.name}'),
        label: Text(label),
        selected: state.filter.status == value,
        onSelected: (_) => bloc.add(InventoryStatusFilterChanged(value)),
      ),
    );
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd),
        children: [
          chip('All', StockStatusFilter.all),
          chip('Low stock', StockStatusFilter.low),
          chip('Out of stock', StockStatusFilter.out),
        ],
      ),
    );
  }
}
