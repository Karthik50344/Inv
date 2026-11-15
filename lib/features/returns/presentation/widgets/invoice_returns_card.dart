import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/payments/presentation/bloc/balance_cubits.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/returns/presentation/bloc/return_detail_cubit.dart';
import 'package:inventrix/features/sales/presentation/widgets/date_text.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';

/// The returns posted against one invoice, and the button that starts a new
/// one. Needs an [InvoiceReturnsCubit] above it (the router provides it on
/// the sale and purchase detail routes); only show it for posted invoices.
class InvoiceReturnsCard extends StatelessWidget {
  /// Creates the card.
  const InvoiceReturnsCard({
    required this.kind,
    required this.invoiceId,
    super.key,
  });

  /// Sales or purchase.
  final InvoiceKind kind;

  /// The invoice id.
  final String invoiceId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InvoiceReturnsCubit, InvoiceReturnsState>(
      builder: (context, state) {
        if (state.status == DetailStatus.loading) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          );
        }
        if (state.status == DetailStatus.failure) {
          return ListTile(
            title: Text(state.message ?? 'Could not load returns.'),
          );
        }
        const formatter = MoneyFormatter();
        final total = state.returnedTotal;
        return Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Returns', style: Theme.of(context).textTheme.titleMedium),
                if (total == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Nothing has been returned.'),
                  )
                else ...[
                  ListTile(
                    key: const Key('invoice_returned_total'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Returned in total'),
                    trailing: Text(formatter.format(total)),
                  ),
                  for (final doc in state.returns)
                    ListTile(
                      key: Key('invoice_return_${doc.id}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${doc.number} · ${formatDocumentDate(doc.returnDate)}',
                      ),
                      subtitle: Text(doc.reason),
                      trailing: Text(formatter.format(doc.total)),
                      onTap: () => context.pushNamed(
                        RouteNames.returnDetail,
                        pathParameters: {'kind': kind.name, 'id': doc.id},
                      ),
                    ),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    key: const Key('return_items'),
                    onPressed: () async {
                      final returns = context.read<InvoiceReturnsCubit>();
                      final settlement = context.read<InvoiceSettlementCubit>();
                      await context.pushNamed(
                        RouteNames.returnNew,
                        queryParameters: {
                          'kind': kind.name,
                          'invoice': invoiceId,
                        },
                      );
                      await returns.load(kind, invoiceId);
                      await settlement.load(kind, invoiceId);
                    },
                    icon: const Icon(Icons.assignment_return_outlined),
                    label: const Text('Return items'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
