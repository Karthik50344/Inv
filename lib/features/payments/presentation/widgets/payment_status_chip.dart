import 'package:flutter/material.dart';
import 'package:inventrix/features/payments/domain/entities/payment_status.dart';

/// A small coloured label for an invoice's derived [PaymentStatus].
class PaymentStatusChip extends StatelessWidget {
  /// Creates the chip.
  const PaymentStatusChip({required this.status, super.key});

  /// The status to show.
  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      PaymentStatus.paid => (scheme.primaryContainer, scheme.onPrimaryContainer),
      PaymentStatus.overdue => (scheme.errorContainer, scheme.onErrorContainer),
      PaymentStatus.unpaid => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      PaymentStatus.partiallyPaid ||
      PaymentStatus.partiallyRefunded ||
      PaymentStatus.refunded ||
      PaymentStatus.writtenOff => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
    };
    return Chip(
      key: Key('payment_status_${status.name}'),
      label: Text(status.label),
      backgroundColor: background,
      labelStyle: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: foreground),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      side: BorderSide.none,
    );
  }
}
