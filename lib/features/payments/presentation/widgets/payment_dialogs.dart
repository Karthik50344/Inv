import 'package:flutter/material.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/payments/domain/entities/open_invoice.dart';
import 'package:inventrix/features/payments/presentation/bloc/payment_methods_cubit.dart';

// Every dialog below owns its text controllers in its own State, so they are
// disposed only after the dialog route has finished closing. Disposing a
// controller right when `showDialog` completes would use it during the exit
// animation and crash with a framework assertion.

/// Asks for the reason of a reversal. Returns the text, or `null` on cancel.
Future<String?> askReverseReason(BuildContext context) => showDialog<String>(
  context: context,
  builder: (_) => const _ReverseDialog(),
);

class _ReverseDialog extends StatefulWidget {
  const _ReverseDialog();

  @override
  State<_ReverseDialog> createState() => _ReverseDialogState();
}

class _ReverseDialogState extends State<_ReverseDialog> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
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
          controller: _reason,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('confirm_reverse'),
        onPressed: () => Navigator.of(context).pop(_reason.text),
        child: const Text('Reverse'),
      ),
    ],
  );
}

/// What the refund dialog collected.
final class RefundEntry {
  /// Creates the entry.
  const RefundEntry({
    required this.amount,
    required this.reason,
    required this.reductions,
  });

  /// Amount text.
  final String amount;

  /// Reason text.
  final String reason;

  /// Amount text to take back per invoice id.
  final Map<String, String> reductions;
}

/// Asks for a refund. [invoiceNames] maps the invoice ids a refund can be
/// taken back from to their numbers. Returns `null` on cancel.
Future<RefundEntry?> askRefund(
  BuildContext context, {
  required String refundableText,
  required Map<String, String> invoiceNames,
}) => showDialog<RefundEntry>(
  context: context,
  builder: (_) =>
      _RefundDialog(refundableText: refundableText, invoiceNames: invoiceNames),
);

class _RefundDialog extends StatefulWidget {
  const _RefundDialog({
    required this.refundableText,
    required this.invoiceNames,
  });

  final String refundableText;
  final Map<String, String> invoiceNames;

  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  late final Map<String, TextEditingController> _reductions = {
    for (final id in widget.invoiceNames.keys) id: TextEditingController(),
  };

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    for (final c in _reductions.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Refund'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Up to ${widget.refundableText} can be refunded.'),
          TextField(
            key: const Key('refund_amount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
          TextField(
            key: const Key('refund_reason'),
            controller: _reason,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          if (_reductions.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Take back off these invoices (the rest comes from '
                'unallocated credit):',
              ),
            ),
          for (final e in _reductions.entries)
            TextField(
              controller: e.value,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: widget.invoiceNames[e.key]),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('confirm_refund'),
        onPressed: () => Navigator.of(context).pop(
          RefundEntry(
            amount: _amount.text,
            reason: _reason.text,
            reductions: {
              for (final e in _reductions.entries) e.key: e.value.text,
            },
          ),
        ),
        child: const Text('Refund'),
      ),
    ],
  );
}

/// Asks how much unallocated credit to apply to which open invoice. Returns
/// the amount text per invoice id, or `null` on cancel.
Future<Map<String, String>?> askCreditAllocation(
  BuildContext context, {
  required String availableText,
  required List<OpenInvoice> invoices,
}) => showDialog<Map<String, String>>(
  context: context,
  builder: (_) =>
      _AllocateDialog(availableText: availableText, invoices: invoices),
);

class _AllocateDialog extends StatefulWidget {
  const _AllocateDialog({required this.availableText, required this.invoices});

  final String availableText;
  final List<OpenInvoice> invoices;

  @override
  State<_AllocateDialog> createState() => _AllocateDialogState();
}

class _AllocateDialogState extends State<_AllocateDialog> {
  late final Map<String, TextEditingController> _controllers = {
    for (final i in widget.invoices) i.id: TextEditingController(),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const formatter = MoneyFormatter();
    return AlertDialog(
      title: const Text('Apply credit'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Available: ${widget.availableText}'),
            for (final i in widget.invoices)
              TextField(
                key: Key('credit_${i.id}'),
                controller: _controllers[i.id],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText:
                      '${i.displayNumber} · outstanding '
                      '${formatter.format(i.outstanding)}',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm_allocate'),
          onPressed: () => Navigator.of(context).pop({
            for (final e in _controllers.entries) e.key: e.value.text,
          }),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

/// Asks for the name of a new payment method and creates it through
/// [cubit]. Returns `true` when it was created.
Future<bool> askNewPaymentMethod(
  BuildContext context,
  PaymentMethodsCubit cubit,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _NewMethodDialog(cubit: cubit),
    ) ??
    false;

class _NewMethodDialog extends StatefulWidget {
  const _NewMethodDialog({required this.cubit});

  final PaymentMethodsCubit cubit;

  @override
  State<_NewMethodDialog> createState() => _NewMethodDialogState();
}

class _NewMethodDialogState extends State<_NewMethodDialog> {
  final TextEditingController _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final message = await widget.cubit.create(_name.text);
    if (!mounted) {
      return;
    }
    if (message == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New payment method'),
    content: TextField(
      key: const Key('method_name'),
      controller: _name,
      autofocus: true,
      decoration: InputDecoration(labelText: 'Name', errorText: _error),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('save_method'),
        onPressed: _save,
        child: const Text('Add'),
      ),
    ],
  );
}
