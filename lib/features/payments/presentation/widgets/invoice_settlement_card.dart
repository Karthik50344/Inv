import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/presentation/bloc/balance_cubits.dart';
import 'package:inventrix/features/payments/presentation/widgets/payment_status_chip.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_button.dart';
import 'package:inventrix/shared/presentation/widgets/app_card.dart';
import 'package:inventrix/shared/presentation/widgets/app_tone.dart';

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
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s12),
            child: AppCard(
              tone: AppTone.danger,
              child: Text(state.message ?? 'Could not load payments.'),
            ),
          );
        }
        if (view == null) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.s16),
            child: LinearProgressIndicator(),
          );
        }
        const formatter = MoneyFormatter();
        final invoice = view.invoice;
        final isSales = kind == InvoiceKind.sales;
        final walkIn = invoice.partyId.isEmpty;
        final type = isSales ? PartyType.customer : PartyType.supplier;
        final theme = Theme.of(context);
        final tokens = context.appColors;
        Widget row(String label, String value, {Key? key, bool bold = false}) =>
            Padding(
              key: key,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: bold
                          ? theme.textTheme.titleSmall
                          : theme.textTheme.bodyMedium?.copyWith(
                              color: tokens.textSecondary,
                            ),
                    ),
                  ),
                  Text(
                    value,
                    style: bold
                        ? context.appText.financialMedium
                        : context.appText.financialSmall,
                  ),
                ],
              ),
            );
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s12),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Payments', style: theme.textTheme.titleMedium),
                    ),
                    if (view.status != null)
                      PaymentStatusChip(status: view.status!),
                  ],
                ),
                if (walkIn)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Walk-in sale: payments are not tracked for sales '
                      'without a customer.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  )
                else ...[
                  AppSpacing.gap8,
                  row(isSales ? 'Received' : 'Paid', formatter.format(invoice.netPaid)),
                  if (invoice.returned.isPositive)
                    row(
                      'Returned',
                      formatter.format(invoice.returned),
                      key: const Key('invoice_returned'),
                    ),
                  if (invoice.credit.isPositive)
                    row(
                      isSales
                          ? 'Credit held for the customer'
                          : 'Credit held with the supplier',
                      formatter.format(invoice.credit),
                      key: const Key('invoice_credit'),
                    ),
                  Divider(height: AppSpacing.s16, color: tokens.divider),
                  row(
                    'Outstanding',
                    formatter.format(invoice.outstanding),
                    key: const Key('invoice_outstanding'),
                    bold: true,
                  ),
                  for (final payment in view.payments)
                    InkWell(
                      key: Key('invoice_payment_${payment.id}'),
                      onTap: () => context.pushNamed(
                        RouteNames.paymentDetail,
                        pathParameters: {'id': payment.id},
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 18,
                              color: tokens.textSecondary,
                            ),
                            AppSpacing.hGap8,
                            Expanded(
                              child: Text(
                                '${payment.number} · ${payment.methodName}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            Text(
                              formatter.format(
                                payment.allocations
                                    .where((a) => a.invoiceId == invoiceId)
                                    .fold(
                                      invoice.netPaid - invoice.netPaid,
                                      (sum, a) => sum + a.amount,
                                    ),
                              ),
                              style: context.appText.financialSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (invoice.outstanding.isPositive) ...[
                    AppSpacing.gap8,
                    AppButton(
                      key: const Key('record_payment_for_invoice'),
                      label: isSales ? 'Receive payment' : 'Record payment',
                      icon: Icons.payments_outlined,
                      variant: AppButtonVariant.secondary,
                      expand: true,
                      onPressed: () async {
                        final cubit = context.read<InvoiceSettlementCubit>();
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
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
