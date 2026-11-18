import 'package:flutter/material.dart';
import 'package:inventrix/features/payments/presentation/widgets/invoice_settlement_card.dart';
import 'package:inventrix/features/returns/presentation/widgets/invoice_returns_card.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/sales/domain/entities/sales_invoice.dart';
import 'package:inventrix/features/sales/presentation/bloc/sales_detail_cubit.dart';
import 'package:inventrix/features/sales/presentation/widgets/date_text.dart';
import 'package:inventrix/features/sales/presentation/widgets/sales_status_chip.dart';
import 'package:inventrix/features/sales/presentation/widgets/sales_totals_card.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

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
          appBar: AppAppBar(
            title: invoice?.displayNumber ?? 'Sales',
            actions: [
              if (invoice != null && invoice.isEditable)
                AppIconButton(
                  key: const Key('edit_sale'),
                  tooltip: 'Edit',
                  icon: Icons.edit_outlined,
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
    final tokens = context.appColors;
    final facts = <(String, String?, Key?)>[
      ('Customer', invoice.customerName, null),
      ('Invoice date', formatDocumentDate(invoice.invoiceDate), null),
      if (invoice.dueDate != null)
        ('Due date', formatDocumentDate(invoice.dueDate!), null),
      if (invoice.customerReference != null)
        ('Customer invoice no.', invoice.customerReference, null),
      if (invoice.status == DocumentStatus.voided) ...[
        (
          'Voided',
          invoice.voidedAt == null
              ? null
              : formatDocumentDate(invoice.voidedAt!),
          null,
        ),
        ('Reason', invoice.voidReason, const Key('void_reason')),
      ],
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppDimensions.maxContentWidth,
        ),
        child: ListView(
          padding: AppSpacing.page,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SalesStatusChip(status: invoice.status),
            ),
            AppSpacing.gap12,
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s4,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < facts.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s12,
                      ),
                      decoration: BoxDecoration(
                        border: i == facts.length - 1
                            ? null
                            : Border(
                                bottom: BorderSide(color: tokens.divider),
                              ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            facts[i].$1,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: tokens.textSecondary,
                            ),
                          ),
                          AppSpacing.hGap16,
                          Expanded(
                            child: Text(
                              facts[i].$2 ?? '—',
                              key: facts[i].$3,
                              textAlign: TextAlign.end,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (invoice.notes != null) ...[
              AppSpacing.gap12,
              AppCard(
                child: Text(
                  invoice.notes!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
              ),
            ],
            const AppSectionHeader(
              title: 'Items',
              padding: EdgeInsets.fromLTRB(
                AppSpacing.s4,
                AppSpacing.s24,
                AppSpacing.s4,
                AppSpacing.s8,
              ),
            ),
            for (final line in invoice.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                child: AppCard(
                  key: Key('detail_line_${line.lineNo}'),
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${line.productName} (${line.sku})',
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                '${line.quantity.toDecimalString()} ${line.unitSymbol} '
                                    '× ${formatter.format(line.unitPrice)}'
                                    '${line.priceIncludesTax ? ' (incl. tax)' : ''}',
                                if (line.discountAmount.isPositive)
                                  'discount ${formatter.format(line.discountAmount)}',
                                if (line.taxRateBp > 0)
                                  '${line.taxName ?? 'Tax'} ${formatter.format(line.tax)}',
                              ].join(' · '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppSpacing.hGap8,
                      AppCurrencyText(line.total),
                    ],
                  ),
                ),
              ),
            AppSpacing.gap8,
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
            AppSpacing.gap16,
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
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
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
      AppButton(
        key: Key(key),
        label: label,
        expand: true,
        onPressed: busy ? null : onPressed,
      ),
    );
    Widget outlined(
      String key,
      String label,
      VoidCallback? onPressed, {
      bool destructive = false,
    }) => gap(
      AppButton(
        key: Key(key),
        label: label,
        expand: true,
        variant: AppButtonVariant.outlined,
        onPressed: busy ? null : onPressed,
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
          ),
        ),
        actions: [
          AppButton(
            label: 'Keep',
            variant: AppButtonVariant.text,
            size: AppButtonSize.small,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          AppButton(
            key: const Key('confirm_void'),
            label: 'Void',
            variant: AppButtonVariant.destructive,
            size: AppButtonSize.small,
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}
