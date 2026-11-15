import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/payments/domain/entities/open_invoice.dart';
import 'package:inventrix/features/payments/presentation/bloc/payment_detail_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/purchases/presentation/widgets/date_text.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';

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
              appBar: AppBar(title: const Text('Payment')),
              body: const LoadingIndicator(),
            );
          case DetailStatus.notFound:
            return Scaffold(
              appBar: AppBar(title: const Text('Payment')),
              body: const Center(child: Text('This payment no longer exists.')),
            );
          case DetailStatus.failure:
            return Scaffold(
              appBar: AppBar(title: const Text('Payment')),
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
        Widget row(String label, String? value) => value == null
            ? const SizedBox.shrink()
            : ListTile(
                dense: true,
                title: Text(label),
                trailing: Text(value),
              );
        return Scaffold(
          appBar: AppBar(title: Text(p.number)),
          body: ListView(
            children: [
              if (p.isReversed)
                MaterialBanner(
                  key: const Key('reversed_banner'),
                  content: Text(
                    'Reversed on ${formatDocumentDate(p.reversal!.reversedAt)}: '
                    '${p.reversal!.reason}',
                  ),
                  actions: const [SizedBox.shrink()],
                ),
              row('Type', p.isRefund ? 'Refund' : 'Payment'),
              row(p.partyType.label, p.partyName),
              row('Date', formatDocumentDate(p.paymentDate)),
              row('Method', p.methodName),
              row('Reference', p.reference),
              row(
                'Amount',
                '${p.isMoneyIn ? '+' : '-'} ${formatter.format(p.amount)}',
              ),
              if (p.notes != null) row(p.isRefund ? 'Reason' : 'Notes', p.notes),
              if (p.refundOfPaymentId != null)
                ListTile(
                  dense: true,
                  title: const Text('Refund of'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed(
                    RouteNames.paymentDetail,
                    pathParameters: {'id': p.refundOfPaymentId!},
                  ),
                ),
              if (position != null) ...[
                row('Applied to invoices', formatter.format(position.allocatedNet)),
                ListTile(
                  key: const Key('payment_credit'),
                  dense: true,
                  title: const Text('Unallocated credit'),
                  trailing: Text(
                    formatter.format(position.credit),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (position.refunded.isPositive)
                  row('Refunded', formatter.format(position.refunded)),
              ],
              const Divider(),
              if (p.allocations.isNotEmpty)
                const ListTile(
                  dense: true,
                  title: Text('Invoices'),
                ),
              for (final a in p.allocations)
                ListTile(
                  key: Key('allocation_${a.id}'),
                  dense: true,
                  title: Text(a.invoiceNumber),
                  trailing: Text(formatter.format(a.amount)),
                ),
              if (state.refunds.isNotEmpty) const ListTile(title: Text('Refunds')),
              for (final r in state.refunds)
                ListTile(
                  key: Key('refund_${r.id}'),
                  dense: true,
                  title: Text('${r.number} · ${formatDocumentDate(r.paymentDate)}'),
                  trailing: Text(formatter.format(r.amount)),
                  onTap: () => context.pushNamed(
                    RouteNames.paymentDetail,
                    pathParameters: {'id': r.id},
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (state.canAllocate)
                      OutlinedButton(
                        key: const Key('allocate_credit'),
                        onPressed: state.busy
                            ? null
                            : () => _allocate(context, cubit, state),
                        child: const Text('Apply credit'),
                      ),
                    if (state.canRefund)
                      OutlinedButton(
                        key: const Key('refund_payment'),
                        onPressed: state.busy
                            ? null
                            : () => _refund(context, cubit, state),
                        child: const Text('Refund'),
                      ),
                    if (state.canReverse)
                      FilledButton(
                        key: const Key('reverse_payment'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(context).colorScheme.onError,
                        ),
                        onPressed: state.busy
                            ? null
                            : () => _reverse(context, cubit),
                        child: const Text('Reverse'),
                      ),
                  ],
                ),
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
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_reverse'),
            onPressed: () => Navigator.of(dialog).pop(controller.text),
            child: const Text('Reverse'),
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
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_refund'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Refund'),
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
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_allocate'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Apply'),
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
