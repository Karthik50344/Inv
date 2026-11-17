import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/core/formatters/date_formatter.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement.dart';
import 'package:inventrix/features/inventory/presentation/bloc/stock_detail_cubit.dart';
import 'package:inventrix/features/inventory/presentation/widgets/stock_status_chip.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';

/// Stock position, valuation and movement history for one product.
class StockDetailPage extends StatelessWidget {
  /// Creates the page for [productId]. Provide a [StockDetailCubit] above.
  const StockDetailPage({required this.productId, super.key});

  /// Id of the product.
  final String productId;

  Future<void> _open(BuildContext context, String route) async {
    final cubit = context.read<StockDetailCubit>();
    await context.pushNamed(route, pathParameters: {'id': productId});
    await cubit.load(productId);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<StockDetailCubit, StockDetailState>(
      listenWhen: (previous, current) =>
          current.message != null &&
          current.status == DetailStatus.loaded &&
          current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final cubit = context.read<StockDetailCubit>();
        return Scaffold(
          appBar: AppBar(title: Text(state.item?.product.name ?? 'Stock')),
          body: switch (state.status) {
            DetailStatus.loading => const LoadingIndicator(),
            DetailStatus.notFound => const EmptyState(
              icon: Icons.search_off,
              title: 'Product not found',
              message: 'It may have been removed or the link is invalid.',
            ),
            DetailStatus.failure => ErrorState(
              message: state.message ?? 'Could not load stock.',
              onRetry: () => cubit.load(productId),
            ),
            DetailStatus.loaded => _Body(
              state: state,
              onOpen: (route) => _open(context, route),
            ),
          },
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.onOpen});

  final StockDetailState state;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final item = state.item!;
    final symbol = state.unit?.symbol ?? '';
    const formatter = MoneyFormatter();
    final theme = Theme.of(context);
    final average = item.balance.averageCost;
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.balance.quantityOnHand.toDecimalString()} $symbol',
                        key: const Key('stock_quantity'),
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    StockStatusChip(status: item.status),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                Text(
                  'Value: ${formatter.format(item.balance.inventoryValue)}',
                  key: const Key('stock_value'),
                ),
                Text(
                  'Average cost: '
                  '${average == null ? '—' : formatter.format(average)}',
                  key: const Key('stock_average_cost'),
                ),
                Text(
                  'Reorder level: '
                  '${item.product.reorderLevel.toDecimalString()} $symbol',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spaceMd),
        Wrap(
          spacing: AppDimensions.spaceSm,
          runSpacing: AppDimensions.spaceSm,
          children: [
            if (state.canRecordOpeningStock)
              FilledButton(
                key: const Key('opening_stock'),
                onPressed: () => onOpen(RouteNames.stockOpening),
                child: const Text('Opening stock'),
              ),
            FilledButton.tonal(
              key: const Key('stock_in'),
              onPressed: () => onOpen(RouteNames.stockIn),
              child: const Text('Stock in'),
            ),
            OutlinedButton(
              key: const Key('stock_out'),
              onPressed: () => onOpen(RouteNames.stockOut),
              child: const Text('Stock out'),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceLg),
        Text('Movement history', style: theme.textTheme.titleMedium),
        if (state.movements.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimensions.spaceMd),
            child: Text('No stock movements yet.'),
          )
        else
          for (final movement in state.movements)
            _MovementTile(movement: movement, symbol: symbol),
        if (state.hasMore)
          Center(
            child: TextButton(
              key: const Key('load_more_movements'),
              onPressed: state.loadingMore
                  ? null
                  : context.read<StockDetailCubit>().loadMore,
              child: Text(state.loadingMore ? 'Loading…' : 'Load more'),
            ),
          ),
      ],
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement, required this.symbol});

  final StockMovement movement;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    const formatter = MoneyFormatter();
    final inbound = movement.isInbound;
    final sign = inbound ? '+' : '';
    final when = DateFormatter.dateTime(movement.occurredAt);
    return ListTile(
      key: Key('movement_${movement.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        inbound ? Icons.south_west : Icons.north_east,
        color: inbound ? Colors.green : Theme.of(context).colorScheme.error,
      ),
      title: Text(
        '${movement.type.label}: $sign${movement.quantityDelta.toDecimalString()} $symbol',
      ),
      subtitle: Text(
        [if (movement.reason != null) movement.reason!, when].join(' · '),
      ),
      trailing: Text(formatter.format(movement.totalCost)),
    );
  }
}
