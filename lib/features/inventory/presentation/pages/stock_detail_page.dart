import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/date_formatter.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement.dart';
import 'package:inventrix/features/inventory/presentation/bloc/stock_detail_cubit.dart';
import 'package:inventrix/features/inventory/presentation/widgets/stock_status_chip.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

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
          appBar: AppAppBar(title: state.item?.product.name ?? 'Stock'),
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
    final tokens = context.appColors;
    final average = item.balance.averageCost;
    Widget fact(String text, {Key? key}) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s4),
      child: Text(
        text,
        key: key,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: tokens.textSecondary,
        ),
      ),
    );
    return AppRefreshIndicator(
      onRefresh: () => context.read<StockDetailCubit>().load(item.product.id),
      child: ListView(
        physics: AppRefreshIndicator.physics,
        padding: AppSpacing.page,
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.s20),
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
                AppSpacing.gap8,
                fact(
                  'Value: ${formatter.format(item.balance.inventoryValue)}',
                  key: const Key('stock_value'),
                ),
                fact(
                  'Average cost: '
                  '${average == null ? '—' : formatter.format(average)}',
                  key: const Key('stock_average_cost'),
                ),
                fact(
                  'Reorder level: '
                  '${item.product.reorderLevel.toDecimalString()} $symbol',
                ),
              ],
            ),
          ),
          AppSpacing.gap16,
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              if (state.canRecordOpeningStock)
                AppButton(
                  key: const Key('opening_stock'),
                  label: 'Opening stock',
                  icon: Icons.playlist_add,
                  onPressed: () => onOpen(RouteNames.stockOpening),
                ),
              AppButton(
                key: const Key('stock_in'),
                label: 'Stock in',
                icon: Icons.add,
                variant: AppButtonVariant.secondary,
                onPressed: () => onOpen(RouteNames.stockIn),
              ),
              AppButton(
                key: const Key('stock_out'),
                label: 'Stock out',
                icon: Icons.remove,
                variant: AppButtonVariant.outlined,
                onPressed: () => onOpen(RouteNames.stockOut),
              ),
            ],
          ),
          const AppSectionHeader(
            title: 'Movement history',
            padding: EdgeInsets.fromLTRB(
              AppSpacing.s4,
              AppSpacing.s24,
              AppSpacing.s4,
              AppSpacing.s8,
            ),
          ),
          if (state.movements.isEmpty)
            const AppCard(child: Text('No stock movements yet.'))
          else
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < state.movements.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: tokens.divider),
                    _MovementTile(
                      movement: state.movements[i],
                      symbol: symbol,
                    ),
                  ],
                ],
              ),
            ),
          if (state.hasMore)
            Center(
              child: AppButton(
                key: const Key('load_more_movements'),
                label: state.loadingMore ? 'Loading…' : 'Load more',
                variant: AppButtonVariant.text,
                onPressed: state.loadingMore
                    ? null
                    : context.read<StockDetailCubit>().loadMore,
              ),
            ),
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement, required this.symbol});

  final StockMovement movement;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final inbound = movement.isInbound;
    final sign = inbound ? '+' : '';
    final when = DateFormatter.dateTime(movement.occurredAt);
    final tone = inbound ? AppTone.success : AppTone.danger;
    final colors = tone.colors(context);
    final theme = Theme.of(context);
    return Padding(
      key: Key('movement_${movement.id}'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.container,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                inbound ? Icons.south_west : Icons.north_east,
                size: 18,
                color: colors.onContainer,
              ),
            ),
          ),
          AppSpacing.hGap12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${movement.type.label}: $sign${movement.quantityDelta.toDecimalString()} $symbol',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  [if (movement.reason != null) movement.reason!, when]
                      .join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.hGap8,
          AppCurrencyText(movement.totalCost),
        ],
      ),
    );
  }
}
