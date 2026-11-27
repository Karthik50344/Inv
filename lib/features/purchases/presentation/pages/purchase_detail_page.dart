import 'package:material_ui/material_ui.dart';
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
import 'package:inventrix/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:inventrix/features/purchases/presentation/bloc/purchase_detail_cubit.dart';
import 'package:inventrix/features/purchases/presentation/widgets/date_text.dart';
import 'package:inventrix/features/purchases/presentation/widgets/purchase_status_chip.dart';
import 'package:inventrix/features/purchases/presentation/widgets/purchase_totals_card.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// A purchase invoice with its workflow actions: edit, submit, approve,
/// post, cancel and void.
class PurchaseDetailPage extends StatelessWidget {
  /// Creates the page. Provide a [PurchaseDetailCubit] above it.
  const PurchaseDetailPage({required this.purchaseId, super.key});

  /// Id of the purchase to show.
  final String purchaseId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PurchaseDetailCubit, PurchaseDetailState>(
      listenWhen: (previous, current) =>
          current.message != null &&
          current.status == DetailStatus.loaded &&
          current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final cubit = context.read<PurchaseDetailCubit>();
        final invoice = state.invoice;
        return Scaffold(
          appBar: AppAppBar(
            title: invoice?.displayNumber ?? 'Purchase',
            actions: [
              if (invoice != null && invoice.isEditable)
                AppIconButton(
                  key: const Key('edit_purchase'),
                  tooltip: 'Edit',
                  icon: Icons.edit_outlined,
                  onPressed: state.busy
                      ? null
                      : () async {
                          await context.pushNamed(
                            RouteNames.purchaseEdit,
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
              title: 'Purchase not found',
              message: 'It may have been removed or the link is invalid.',
            ),
            DetailStatus.failure => ErrorState(
              message: state.message ?? 'Could not load the purchase.',
              onRetry: () => cubit.load(purchaseId),
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

  final PurchaseDetailState state;

  @override
  Widget build(BuildContext context) {
    final invoice = state.invoice!;
    const formatter = MoneyFormatter();
    final theme = Theme.of(context);
    final tokens = context.appColors;
    final facts = <(String, String?, Key?)>[
      ('Supplier', invoice.supplierName, null),
      ('Invoice date', formatDocumentDate(invoice.invoiceDate), null),
      if (invoice.dueDate != null)
        ('Due date', formatDocumentDate(invoice.dueDate!), null),
      if (invoice.supplierReference != null)
        ('Supplier invoice no.', invoice.supplierReference, null),
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
              child: PurchaseStatusChip(status: invoice.status),
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
            PurchaseTotalsCard(totals: invoice.totals),
            if (invoice.status == DocumentStatus.posted)
              InvoiceSettlementCard(
                kind: InvoiceKind.purchase,
                invoiceId: invoice.id,
              ),
            if (invoice.status == DocumentStatus.posted)
              InvoiceReturnsCard(
                kind: InvoiceKind.purchase,
                invoiceId: invoice.id,
              ),
            AppSpacing.gap16,
            ..._actions(context, invoice),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, PurchaseInvoice invoice) {
    final cubit = context.read<PurchaseDetailCubit>();
    final busy = state.busy;
    Widget gap(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: child,
    );

    Future<void> confirmPost() async {
      final confirmed = await showConfirmationDialog(
        context,
        title: 'Post purchase?',
        message:
            'The items will be added to your stock and the purchase gets '
            'its number. A posted purchase cannot be edited; to undo it you '
            'void it, which reverses the stock.',
        confirmLabel: 'Post',
      );
      if (confirmed) {
        await cubit.post();
      }
    }

    Future<void> confirmCancel() async {
      final confirmed = await showConfirmationDialog(
        context,
        title: 'Cancel purchase?',
        message: 'This purchase will be marked cancelled and cannot be posted.',
        confirmLabel: 'Cancel purchase',
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
            filled('submit_purchase', 'Submit for approval', cubit.submit)
          else
            filled('post_purchase', 'Post purchase', confirmPost),
          outlined(
            'cancel_purchase',
            'Cancel purchase',
            confirmCancel,
            destructive: true,
          ),
        ];
      case DocumentStatus.pendingApproval:
        return [
          filled('approve_purchase', 'Approve', cubit.approve),
          outlined('reopen_purchase', 'Return to draft', cubit.reopen),
          outlined(
            'cancel_purchase',
            'Cancel purchase',
            confirmCancel,
            destructive: true,
          ),
        ];
      case DocumentStatus.approved:
      case DocumentStatus.authorized:
        return [
          filled('post_purchase', 'Post purchase', confirmPost),
          outlined(
            'cancel_purchase',
            'Cancel purchase',
            confirmCancel,
            destructive: true,
          ),
        ];
      case DocumentStatus.posted:
        return [
          outlined('void_purchase', 'Void purchase', () async {
            final reason = await _askReason(context);
            if (reason != null) {
              await cubit.voidPurchase(reason);
            }
          }, destructive: true),
          Text(
            'Voiding keeps this document and reverses its stock. It is '
            'rejected if some of the received stock has already been used.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ];
      case DocumentStatus.voided:
      case DocumentStatus.cancelled:
        return const [];
    }
  }

  Future<String?> _askReason(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Void purchase?'),
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
