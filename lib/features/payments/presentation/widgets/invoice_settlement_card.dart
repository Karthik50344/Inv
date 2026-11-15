import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/presentation/bloc/balance_cubits.dart';
import 'package:inventrix/features/payments/presentation/widgets/payment_status_chip.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// Payment status, amounts paid and outstanding, and the payments settling
/// one posted invoice. Needs an [InvoiceSettlementCubit] above it in the tree
/// (the router provides it on the sale and purchase detail routes).
class InvoiceSettlementCard extends StatelessWidget {
  /// Creates the card.
  const InvoiceSettlementCard({
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
    return BlocBuilder<InvoiceSettlementCubit, InvoiceSettlementState>(
        builder: (context, state) {
          final view = state.view;
          if (state.status == ViewStatus.failure) {
            return ListTile(
              title: Text(state.message ?? 'Could not load payments.'),
            );
          }
          if (view == null) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            );
          }
          const formatter = MoneyFormatter();
          final invoice = view.invoice;
          final isSales = kind == InvoiceKind.sales;
          final walkIn = invoice.partyId.isEmpty;
          final type = isSales ? PartyType.customer : PartyType.supplier;
          return Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Payments',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (view.status != null)
                        PaymentStatusChip(status: view.status!),
                    ],
                  ),
                  if (walkIn)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Walk-in sale: payments are not tracked for sales '
                        'without a customer.',
                      ),
                    )
                  else ...[
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(isSales ? 'Received' : 'Paid'),
                      trailing: Text(formatter.format(invoice.netPaid)),
                    ),
                    if (invoice.returned.isPositive)
                      ListTile(
                        key: const Key('invoice_returned'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Returned'),
                        trailing: Text(formatter.format(invoice.returned)),
                      ),
                    if (invoice.credit.isPositive)
                      ListTile(
                        key: const Key('invoice_credit'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          isSales
                              ? 'Credit held for the customer'
                              : 'Credit held with the supplier',
                        ),
                        trailing: Text(formatter.format(invoice.credit)),
                      ),
                    ListTile(
                      key: const Key('invoice_outstanding'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Outstanding'),
                      trailing: Text(
                        formatter.format(invoice.outstanding),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    for (final payment in view.payments)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        key: Key('invoice_payment_${payment.id}'),
                        title: Text('${payment.number} · ${payment.methodName}'),
                        trailing: Text(
                          formatter.format(
                            payment.allocations
                                .where((a) => a.invoiceId == invoiceId)
                                .fold(
                                  invoice.netPaid - invoice.netPaid,
                                  (sum, a) => sum + a.amount,
                                ),
                          ),
                        ),
                        onTap: () => context.pushNamed(
                          RouteNames.paymentDetail,
                          pathParameters: {'id': payment.id},
                        ),
                      ),
                    if (invoice.outstanding.isPositive)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          key: const Key('record_payment_for_invoice'),
                          onPressed: () async {
                            final cubit = context
                                .read<InvoiceSettlementCubit>();
                            await context.pushNamed(
                              RouteNames.paymentNew,
                              queryParameters: {
                                'type': type.dbName,
                                'party': invoice.partyId,
                                'invoice': invoiceId,
                              },
                            );
                            await cubit.load(kind, invoiceId);
                          },
                          icon: const Icon(Icons.payments_outlined),
                          label: Text(
                            isSales ? 'Receive payment' : 'Record payment',
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
    );
  }
}
