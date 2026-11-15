import 'package:flutter/material.dart';
import 'package:inventrix/features/payments/presentation/widgets/invoice_settlement_card.dart';
import 'package:inventrix/features/returns/presentation/widgets/invoice_returns_card.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/sales/domain/entities/sales_invoice.dart';
import 'package:inventrix/features/sales/presentation/bloc/sales_detail_cubit.dart';
import 'package:inventrix/features/sales/presentation/widgets/date_text.dart';
import 'package:inventrix/features/sales/presentation/widgets/sales_status_chip.dart';
import 'package:inventrix/features/sales/presentation/widgets/sales_totals_card.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/widgets/confirmation_dialog.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';

/// A sale invoice with its workflow actions: edit, submit, approve,
/// post, cancel and void.
class SalesDetailPage extends StatelessWidget {
  /// Creates the page. Provide a [SalesDetailCubit] above it.
  const SalesDetailPage({required this.saleId, super.key});

  /// Id of the sale to show.
  final String saleId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SalesDetailCubit, SalesDetailState>(
      listenWhen: (previous, current) =>
          current.message != null &&
          current.status == DetailStatus.loaded &&
          current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final cubit = context.read<SalesDetailCubit>();
        final invoice = state.invoice;
        return Scaffold(
          appBar: AppBar(
            title: Text(invoice?.displayNumber ?? 'Sales'),
            actions: [
              if (invoice != null && invoice.isEditable)
                IconButton(
                  key: const Key('edit_sale'),
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: state.busy
                      ? null
                      : () async {
                          await context.pushNamed(
                            RouteNames.saleEdit,
                            pathParameters: {'id': invoice.id},
                          );
                          await cubit.load(invoice.id);
                        },
                ),
            ],
          ),
          body: switch (state.status) {
            DetailStatus.loading => const LoadingIndicator(),
            DetailStatus.notFound => const EmptyState(
              icon: Icons.search_off,
              title: 'Sales not found',
              message: 'It may have been removed or the link is invalid.',
            ),
            DetailStatus.failure => ErrorState(
              message: state.message ?? 'Could not load the sale.',
              onRetry: () => cubit.load(saleId),
            ),
            DetailStatus.loaded => _Details(state: state),
          },
        );
      },
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.state});

  final SalesDetailState state;

  @override
  Widget build(BuildContext context) {
    final invoice = state.invoice!;
    const formatter = MoneyFormatter();
    final theme = Theme.of(context);
    Widget row(String label, String? value, {Key? key}) => ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(value ?? '—', key: key),
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppDimensions.maxContentWidth,
        ),
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SalesStatusChip(status: invoice.status),
            ),
            row('Customer', invoice.customerName),
            row('Invoice date', formatDocumentDate(invoice.invoiceDate)),
            if (invoice.dueDate != null)
              row('Due date', formatDocumentDate(invoice.dueDate!)),
            if (invoice.customerReference != null)
              row('Customer invoice no.', invoice.customerReference),
            if (invoice.status == DocumentStatus.voided) ...[
              row(
                'Voided',
                invoice.voidedAt == null
                    ? null
                    : formatDocumentDate(invoice.voidedAt!),
              ),
              row('Reason', invoice.voidReason, key: const Key('void_reason')),
            ],
            if (invoice.notes != null)
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spaceSm),
                child: Text(invoice.notes!),
              ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.spaceSm,
              ),
              child: Text('Items', style: theme.textTheme.titleMedium),
            ),
            for (final line in invoice.lines)
              Card(
                key: Key('detail_line_${line.lineNo}'),
                child: ListTile(
                  title: Text('${line.productName} (${line.sku})'),
                  subtitle: Text(
                    [
                      '${line.quantity.toDecimalString()} ${line.unitSymbol} '
                          '× ${formatter.format(line.unitPrice)}'
                          '${line.priceIncludesTax ? ' (incl. tax)' : ''}',
                      if (line.discountAmount.isPositive)
                        'discount ${formatter.format(line.discountAmount)}',
                      if (line.taxRateBp > 0)
                        '${line.taxName ?? 'Tax'} ${formatter.format(line.tax)}',
                    ].join(' · '),
                  ),
                  trailing: Text(
                    formatter.format(line.total),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ),
            const SizedBox(height: AppDimensions.spaceSm),
            SalesTotalsCard(totals: invoice.totals),
            if (invoice.status == DocumentStatus.posted)
              InvoiceSettlementCard(
                kind: InvoiceKind.sales,
                invoiceId: invoice.id,
              ),
            if (invoice.status == DocumentStatus.posted)
              InvoiceReturnsCard(
                kind: InvoiceKind.sales,
                invoiceId: invoice.id,
              ),
            const SizedBox(height: AppDimensions.spaceMd),
            ..._actions(context, invoice),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, SalesInvoice invoice) {
    final cubit = context.read<SalesDetailCubit>();
    final busy = state.busy;
    Widget gap(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
      child: child,
    );

    Future<void> confirmPost() async {
      final confirmed = await showConfirmationDialog(
        context,
        title: 'Post sale?',
        message:
            'The items will be taken out of your stock and the sale gets '
            'its number. A posted sale cannot be edited; to undo it you '
            'void it, which puts the stock back.',
        confirmLabel: 'Post',
      );
      if (confirmed) {
        await cubit.post();
      }
    }

    Future<void> confirmCancel() async {
      final confirmed = await showConfirmationDialog(
        context,
        title: 'Cancel sale?',
        message: 'This sale will be marked cancelled and cannot be posted.',
        confirmLabel: 'Cancel sale',
        cancelLabel: 'Keep',
        destructive: true,
      );
      if (confirmed) {
        await cubit.cancel();
      }
    }

    Widget filled(String key, String label, VoidCallback? onPressed) => gap(
      FilledButton(
        key: Key(key),
        onPressed: busy ? null : onPressed,
        child: Text(label),
      ),
    );
    Widget outlined(
      String key,
      String label,
      VoidCallback? onPressed, {
      bool destructive = false,
    }) => gap(
      OutlinedButton(
        key: Key(key),
        style: destructive
            ? OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              )
            : null,
        onPressed: busy ? null : onPressed,
        child: Text(label),
      ),
    );

    switch (invoice.status) {
      case DocumentStatus.draft:
      case DocumentStatus.created:
        return [
          if (state.approvalRequired)
            filled('submit_sale', 'Submit for approval', cubit.submit)
          else
            filled('post_sale', 'Post sale', confirmPost),
          outlined(
            'cancel_sale',
            'Cancel sale',
            confirmCancel,
            destructive: true,
          ),
        ];
      case DocumentStatus.pendingApproval:
        return [
          filled('approve_sale', 'Approve', cubit.approve),
          outlined('reopen_sale', 'Return to draft', cubit.reopen),
          outlined(
            'cancel_sale',
            'Cancel sale',
            confirmCancel,
            destructive: true,
          ),
        ];
      case DocumentStatus.approved:
      case DocumentStatus.authorized:
        return [
          filled('post_sale', 'Post sale', confirmPost),
          outlined(
            'cancel_sale',
            'Cancel sale',
            confirmCancel,
            destructive: true,
          ),
        ];
      case DocumentStatus.posted:
        return [
          filled('share_invoice', 'Share invoice PDF', cubit.sharePdf),
          outlined('void_sale', 'Void sale', () async {
            final reason = await _askReason(context);
            if (reason != null) {
              await cubit.voidSale(reason);
            }
          }, destructive: true),
          Text(
            'Voiding keeps this document and puts the goods back in stock '
            'at the cost they left with.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ];
      case DocumentStatus.voided:
        return [
          outlined('share_invoice', 'Share invoice PDF', cubit.sharePdf),
        ];
      case DocumentStatus.cancelled:
        return const [];
    }
  }

  Future<String?> _askReason(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Void sale?'),
        content: TextField(
          key: const Key('void_reason_input'),
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Reason *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Keep'),
          ),
          FilledButton(
            key: const Key('confirm_void'),
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Void'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}
