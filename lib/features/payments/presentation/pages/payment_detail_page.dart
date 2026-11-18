import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/payments/domain/entities/open_invoice.dart';
import 'package:inventrix/features/payments/presentation/bloc/payment_detail_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/purchases/presentation/widgets/date_text.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// One payment or refund with its allocations, and the actions that are
/// allowed on it: reverse, refund, apply credit.
class PaymentDetailPage extends StatelessWidget {
  /// Creates the page.
  const PaymentDetailPage({required this.paymentId, super.key});

  /// The payment to show.
  final String paymentId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PaymentDetailCubit, PaymentDetailState>(
      listenWhen: (previous, current) =>
          current.message != null && current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final cubit = context.read<PaymentDetailCubit>();
        final payment = state.payment;
        switch (state.status) {
          case DetailStatus.loading:
            return Scaffold(
              appBar: const AppAppBar(title: 'Payment'),
              body: const LoadingIndicator(),
            );
          case DetailStatus.notFound:
            return Scaffold(
              appBar: const AppAppBar(title: 'Payment'),
              body: const EmptyState(
                icon: Icons.search_off,
                title: 'Payment not found',
                message: 'This payment no longer exists.',
              ),
            );
          case DetailStatus.failure:
            return Scaffold(
              appBar: const AppAppBar(title: 'Payment'),
              body: ErrorState(
                message: state.message ?? 'Could not load the payment.',
                onRetry: () => cubit.load(paymentId),
              ),
            );
          case DetailStatus.loaded:
            break;
        }
        const formatter = MoneyFormatter();
        final p = payment!;
        final position = state.position;
        final theme = Theme.of(context);
        final tokens = context.appColors;
        final facts = <(String, String?)>[
          ('Type', p.isRefund ? 'Refund' : 'Payment'),
          (p.partyType.label, p.partyName),
          ('Date', formatDocumentDate(p.paymentDate)),
          ('Method', p.methodName),
          ('Reference', p.reference),
          if (p.notes != null) (p.isRefund ? 'Reason' : 'Notes', p.notes),
        ].where((f) => f.$2 != null).toList();
        Widget row(String label, String value, {Key? key, bool bold = false}) =>
            Padding(
              key: key,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: bold
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.bodyMedium?.copyWith(
                            color: tokens.textSecondary,
                          ),
                  ),
                  AppSpacing.hGap16,
                  Expanded(
                    child: Text(
                      value,
                      textAlign: TextAlign.end,
                      style: bold
                          ? context.appText.financialMedium
                          : theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                    ),
                  ),
                ],
              ),
            );
        Widget heading(String text) => AppSectionHeader(
          title: text,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s20,
            AppSpacing.s4,
            AppSpacing.s8,
          ),
        );
        return Scaffold(
          appBar: AppAppBar(title: p.number),
          body: ListView(
            padding: AppSpacing.page,
            children: [
              if (p.isReversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                  child: AppCard(
                    key: const Key('reversed_banner'),
                    tone: AppTone.danger,
                    child: Text(
                      'Reversed on ${formatDocumentDate(p.reversal!.reversedAt)}: '
                      '${p.reversal!.reason}',
                      style: TextStyle(color: tokens.danger.onContainer),
                    ),
                  ),
                ),
              AppCard(
                child: Column(
                  children: [
                    for (final f in facts) row(f.$1, f.$2!),
                    Divider(height: AppSpacing.s16, color: tokens.divider),
                    row(
                      'Amount',
                      '${p.isMoneyIn ? '+' : '-'} ${formatter.format(p.amount)}',
                      bold: true,
                    ),
                  ],
                ),
              ),
              if (p.refundOfPaymentId != null) ...[
                AppSpacing.gap8,
                AppCard(
                  onTap: () => context.pushNamed(
                    RouteNames.paymentDetail,
                    pathParameters: {'id': p.refundOfPaymentId!},
                  ),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Refund of')),
                      Icon(Icons.chevron_right, color: tokens.textDisabled),
                    ],
                  ),
                ),
              ],
              if (position != null) ...[
                heading('Settlement'),
                AppCard(
                  child: Column(
                    children: [
                      row(
                        'Applied to invoices',
                        formatter.format(position.allocatedNet),
                      ),
                      row(
                        'Unallocated credit',
                        formatter.format(position.credit),
                        key: const Key('payment_credit'),
                        bold: true,
                      ),
                      if (position.refunded.isPositive)
                        row('Refunded', formatter.format(position.refunded)),
                    ],
                  ),
                ),
              ],
              if (p.allocations.isNotEmpty) ...[
                heading('Invoices'),
                AppCard(
                  child: Column(
                    children: [
                      for (final a in p.allocations)
                        row(
                          a.invoiceNumber,
                          formatter.format(a.amount),
                          key: Key('allocation_${a.id}'),
                        ),
                    ],
                  ),
                ),
              ],
              if (state.refunds.isNotEmpty) ...[
                heading('Refunds'),
                for (final r in state.refunds)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                    child: AppCard(
                      key: Key('refund_${r.id}'),
                      onTap: () => context.pushNamed(
                        RouteNames.paymentDetail,
                        pathParameters: {'id': r.id},
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${r.number} · ${formatDocumentDate(r.paymentDate)}',
                            ),
                          ),
                          Text(
                            formatter.format(r.amount),
                            style: context.appText.financialSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              AppSpacing.gap16,
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  if (state.canAllocate)
                    AppButton(
                      key: const Key('allocate_credit'),
                      label: 'Apply credit',
                      variant: AppButtonVariant.outlined,
                      onPressed: state.busy
                          ? null
                          : () => _allocate(context, cubit, state),
                    ),
                  if (state.canRefund)
                    AppButton(
                      key: const Key('refund_payment'),
                      label: 'Refund',
                      variant: AppButtonVariant.outlined,
                      onPressed: state.busy
                          ? null
                          : () => _refund(context, cubit, state),
                    ),
                  if (state.canReverse)
                    AppButton(
                      key: const Key('reverse_payment'),
                      label: 'Reverse',
                      variant: AppButtonVariant.destructive,
                      onPressed: state.busy
                          ? null
                          : () => _reverse(context, cubit),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _reverse(BuildContext context, PaymentDetailCubit cubit) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Reverse this payment?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The record stays in your history but stops counting: the '
              'invoices it settled become unpaid again.',
            ),
            TextField(
              key: const Key('reverse_reason'),
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
          ],
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.text,
            size: AppButtonSize.small,
            onPressed: () => Navigator.of(dialog).pop(),
          ),
          AppButton(
            key: const Key('confirm_reverse'),
            label: 'Reverse',
            variant: AppButtonVariant.destructive,
            size: AppButtonSize.small,
            onPressed: () => Navigator.of(dialog).pop(controller.text),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason != null) {
      await cubit.reverse(reason);
    }
  }

  Future<void> _refund(
    BuildContext context,
    PaymentDetailCubit cubit,
    PaymentDetailState state,
  ) async {
    final amount = TextEditingController();
    final reason = TextEditingController();
    final reductions = <String, TextEditingController>{
      for (final a in state.payment!.allocations)
        if ((state.position!.allocatedByInvoice[a.invoiceId] ?? 0) > 0)
          a.invoiceId: TextEditingController(),
    };
    final names = {
      for (final a in state.payment!.allocations) a.invoiceId: a.invoiceNumber,
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Refund'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Up to ${const MoneyFormatter().format(state.position!.refundable)} '
                'can be refunded.',
              ),
              TextField(
                key: const Key('refund_amount'),
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              TextField(
                key: const Key('refund_reason'),
                controller: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              if (reductions.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Take back off these invoices (the rest comes from '
                    'unallocated credit):',
                  ),
                ),
              for (final e in reductions.entries)
                TextField(
                  controller: e.value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: names[e.key]),
                ),
            ],
          ),
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.text,
            size: AppButtonSize.small,
            onPressed: () => Navigator.of(dialog).pop(false),
          ),
          AppButton(
            key: const Key('confirm_refund'),
            label: 'Refund',
            size: AppButtonSize.small,
            onPressed: () => Navigator.of(dialog).pop(true),
          ),
        ],
      ),
    );
    final values = {for (final e in reductions.entries) e.key: e.value.text};
    final amountText = amount.text;
    final reasonText = reason.text;
    amount.dispose();
    reason.dispose();
    for (final c in reductions.values) {
      c.dispose();
    }
    if (ok ?? false) {
      await cubit.refund(
        amount: amountText,
        reason: reasonText,
        reductions: values,
      );
    }
  }

  Future<void> _allocate(
    BuildContext context,
    PaymentDetailCubit cubit,
    PaymentDetailState state,
  ) async {
    final controllers = <String, TextEditingController>{
      for (final OpenInvoice i in state.openInvoices) i.id: TextEditingController(),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Apply credit'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Available: '
                '${const MoneyFormatter().format(state.position!.credit)}',
              ),
              for (final i in state.openInvoices)
                TextField(
                  key: Key('credit_${i.id}'),
                  controller: controllers[i.id],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        '${i.displayNumber} · outstanding '
                        '${const MoneyFormatter().format(i.outstanding)}',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.text,
            size: AppButtonSize.small,
            onPressed: () => Navigator.of(dialog).pop(false),
          ),
          AppButton(
            key: const Key('confirm_allocate'),
            label: 'Apply',
            size: AppButtonSize.small,
            onPressed: () => Navigator.of(dialog).pop(true),
          ),
        ],
      ),
    );
    final values = {for (final e in controllers.entries) e.key: e.value.text};
    for (final c in controllers.values) {
      c.dispose();
    }
    if (ok ?? false) {
      await cubit.allocateCredit(values);
    }
  }
}
