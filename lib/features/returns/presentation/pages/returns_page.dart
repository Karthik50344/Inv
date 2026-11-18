import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/returns/presentation/bloc/returns_bloc.dart';
import 'package:inventrix/features/sales/presentation/widgets/date_text.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Sales and purchase returns with search and a kind filter.
class ReturnsPage extends StatelessWidget {
  /// Creates the page. Provide a [ReturnsBloc] above it.
  const ReturnsPage({super.key});

  Future<void> _open(
    BuildContext context,
    String name, {
    Map<String, String> params = const {},
    Map<String, String> query = const {},
  }) async {
    final bloc = context.read<ReturnsBloc>();
    await context.pushNamed(
      name,
      pathParameters: params,
      queryParameters: query,
    );
    bloc.add(const ReturnsRefreshed());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReturnsBloc, ReturnsState>(
      listenWhen: (previous, current) =>
          current.message != null && current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final bloc = context.read<ReturnsBloc>();
        return Scaffold(
          appBar: const AppAppBar(title: 'Returns'),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add_return'),
            onPressed: () async {
              final kind = await showAppBottomSheet<InvoiceKind>(
                context: context,
                title: 'New return',
                builder: (sheet) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final kind in InvoiceKind.values)
                      ListTile(
                        key: Key('new_return_${kind.name}'),
                        leading: Icon(
                          kind == InvoiceKind.sales
                              ? Icons.south_west
                              : Icons.north_east,
                        ),
                        title: Text(
                          kind == InvoiceKind.sales
                              ? 'Customer return (sales)'
                              : 'Return to supplier (purchase)',
                        ),
                        onTap: () => Navigator.of(sheet).pop(kind),
                      ),
                  ],
                ),
              );
              if (kind != null && context.mounted) {
                await _open(
                  context,
                  RouteNames.returnNew,
                  query: {'kind': kind.name},
                );
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('New return'),
          ),
          body: AppContentWidth(child: Column(
            children: [
              AppSearchField(
                hintText: 'Search number, invoice or name',
                onChanged: (query) => bloc.add(ReturnsSearchChanged(query)),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s4,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.s8),
                      child: AppChip(
                        key: const Key('filter_all'),
                        label: 'All',
                        selected: state.filter.kind == null,
                        onSelected: (_) =>
                            bloc.add(const ReturnsKindChanged(null)),
                      ),
                    ),
                    for (final kind in InvoiceKind.values)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.s8),
                        child: AppChip(
                          key: Key('filter_${kind.name}'),
                          label: kind == InvoiceKind.sales
                              ? 'Sales'
                              : 'Purchases',
                          selected: state.filter.kind == kind,
                          onSelected: (_) => bloc.add(ReturnsKindChanged(kind)),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: _body(context, state)),
            ],
          )),
        );
      },
    );
  }

  Widget _body(BuildContext context, ReturnsState state) {
    final bloc = context.read<ReturnsBloc>();
    switch (state.status) {
      case ViewStatus.initial:
      case ViewStatus.loading:
        return const LoadingIndicator();
      case ViewStatus.failure:
        return ErrorState(
          message: state.message ?? 'Could not load returns.',
          onRetry: () => bloc.add(const ReturnsRefreshed()),
        );
      case ViewStatus.empty:
        final filtered =
            state.filter.query.isNotEmpty || state.filter.kind != null;
        return EmptyState(
          icon: Icons.assignment_return_outlined,
          title: filtered ? 'No matching returns' : 'No returns yet',
          message: filtered
              ? 'Try a different search or filter.'
              : 'Record goods a customer brings back, or that you send back '
                    'to a supplier. Open a posted invoice and choose '
                    '"Return items", or use the button below.',
        );
      case ViewStatus.loaded:
        const formatter = MoneyFormatter();
        final tokens = context.appColors;
        final theme = Theme.of(context);
        return AppRefreshIndicator(
          onRefresh: () async => bloc.add(const ReturnsRefreshed()),
          child: ListView.separated(
            physics: AppRefreshIndicator.physics,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s4,
              AppSpacing.s16,
              96,
            ),
            itemCount: state.items.length,
            separatorBuilder: (_, _) => AppSpacing.gap8,
            itemBuilder: (context, index) {
              final item = state.items[index];
              final colors = (item.kind == InvoiceKind.sales
                      ? AppTone.warning
                      : AppTone.info)
                  .colors(context);
              return AppCard(
                key: Key('return_${item.id}'),
                padding: const EdgeInsets.all(AppSpacing.s12),
                onTap: () => _open(
                  context,
                  RouteNames.returnDetail,
                  params: {'kind': item.kind.name, 'id': item.id},
                ),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.container,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.assignment_return_outlined,
                          size: 20,
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
                            '${item.number} · ${item.partyName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${formatDocumentDate(item.returnDate)} · '
                            'against ${item.invoiceNumber} · '
                            '${item.lineCount} item'
                            '${item.lineCount == 1 ? '' : 's'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.hGap8,
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatter.format(item.total),
                          style: context.appText.financialSmall,
                        ),
                        if (item.refundAmount.isPositive)
                          Text(
                            'Refunded ${formatter.format(item.refundAmount)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: tokens.textSecondary,
                            ),
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
