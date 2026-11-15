import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/returns/presentation/bloc/returns_bloc.dart';
import 'package:inventrix/features/sales/presentation/widgets/date_text.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';
import 'package:inventrix/shared/presentation/widgets/search_field.dart';

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
          appBar: AppBar(title: const Text('Returns')),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add_return'),
            onPressed: () async {
              final kind = await showModalBottomSheet<InvoiceKind>(
                context: context,
                builder: (sheet) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final kind in InvoiceKind.values)
                        ListTile(
                          key: Key('new_return_${kind.name}'),
                          leading: const Icon(Icons.assignment_return_outlined),
                          title: Text(
                            kind == InvoiceKind.sales
                                ? 'Customer return (sales)'
                                : 'Return to supplier (purchase)',
                          ),
                          onTap: () => Navigator.of(sheet).pop(kind),
                        ),
                    ],
                  ),
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
          body: Column(
            children: [
              SearchField(
                hintText: 'Search number, invoice or name',
                onChanged: (query) => bloc.add(ReturnsSearchChanged(query)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      key: const Key('filter_all'),
                      label: const Text('All'),
                      selected: state.filter.kind == null,
                      onSelected: (_) => bloc.add(const ReturnsKindChanged(null)),
                    ),
                    for (final kind in InvoiceKind.values)
                      ChoiceChip(
                        key: Key('filter_${kind.name}'),
                        label: Text(
                          kind == InvoiceKind.sales ? 'Sales' : 'Purchases',
                        ),
                        selected: state.filter.kind == kind,
                        onSelected: (_) => bloc.add(ReturnsKindChanged(kind)),
                      ),
                  ],
                ),
              ),
              Expanded(child: _body(context, state)),
            ],
          ),
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
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: state.items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = state.items[index];
            return ListTile(
              key: Key('return_${item.id}'),
              onTap: () => _open(
                context,
                RouteNames.returnDetail,
                params: {'kind': item.kind.name, 'id': item.id},
              ),
              title: Text('${item.number} · ${item.partyName}'),
              subtitle: Text(
                '${formatDocumentDate(item.returnDate)} · '
                'against ${item.invoiceNumber} · '
                '${item.lineCount} item${item.lineCount == 1 ? '' : 's'}',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatter.format(item.total),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (item.refundAmount.isPositive)
                    Text(
                      'Refunded ${formatter.format(item.refundAmount)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            );
          },
        );
    }
  }
}
