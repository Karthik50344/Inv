import 'package:material_ui/material_ui.dart';
import 'package:inventrix/features/payments/domain/entities/payment_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_badge.dart';
import 'package:inventrix/shared/presentation/widgets/app_tone.dart';

/// A small coloured label for an invoice's derived [PaymentStatus].
class PaymentStatusChip extends StatelessWidget {
  /// Creates the chip.
  const PaymentStatusChip({required this.status, super.key});

  /// The status to show.
  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      PaymentStatus.paid => AppTone.success,
      PaymentStatus.overdue => AppTone.danger,
      PaymentStatus.unpaid => AppTone.neutral,
      PaymentStatus.partiallyPaid ||
      PaymentStatus.partiallyRefunded ||
      PaymentStatus.refunded ||
      PaymentStatus.writtenOff => AppTone.warning,
    };
    return AppBadge(
      key: Key('payment_status_${status.name}'),
      label: status.label,
      tone: tone,
    );
  }
}
