import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/payments/presentation/bloc/balance_cubits.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/returns/presentation/bloc/return_detail_cubit.dart';
import 'package:inventrix/features/sales/presentation/widgets/date_text.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

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
            padding: EdgeInsets.symmetric(vertical: AppSpacing.s12),
            child: LinearProgressIndicator(),
          );
        }
        final theme = Theme.of(context);
        final tokens = context.appColors;
        if (state.status == DetailStatus.failure) {
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s12),
            child: AppCard(
              tone: AppTone.danger,
              child: Text(state.message ?? 'Could not load returns.'),
            ),
          );
        }
        const formatter = MoneyFormatter();
        final total = state.returnedTotal;
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s12),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Returns', style: theme.textTheme.titleMedium),
                if (total == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s8,
                    ),
                    child: Text(
                      'Nothing has been returned.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  )
                else ...[
                  AppSpacing.gap8,
                  Row(
                    key: const Key('invoice_returned_total'),
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Returned in total',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                      Text(
                        formatter.format(total),
                        style: context.appText.financialSmall,
                      ),
                    ],
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
                      trailing: Text(
                        formatter.format(doc.total),
                        style: context.appText.financialSmall,
                      ),
                      onTap: () => context.pushNamed(
                        RouteNames.returnDetail,
                        pathParameters: {'kind': kind.name, 'id': doc.id},
                      ),
                    ),
                ],
                AppSpacing.gap12,
                AppButton(
                  key: const Key('return_items'),
                  label: 'Return items',
                  icon: Icons.assignment_return_outlined,
                  variant: AppButtonVariant.secondary,
                  expand: true,
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
