import 'package:inventrix/features/payments/domain/entities/payment_status.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Derives an invoice's [PaymentStatus]. Pure and deterministic: the clock is
/// passed in.
abstract final class PaymentStatusCalculator {
  /// Returns `null` when the invoice is not posted (drafts, cancelled and
  /// voided documents have no payment status).
  ///
  /// Rules, in order:
  /// 1. `netPaid >= total` (including a zero total): [PaymentStatus.paid].
  /// 2. Otherwise something is outstanding. If the due date is before today:
  ///    [PaymentStatus.overdue].
  /// 3. `netPaid == 0`: [PaymentStatus.refunded] if money was handed back,
  ///    else [PaymentStatus.unpaid].
  /// 4. Otherwise: [PaymentStatus.partiallyRefunded] if money was handed back,
  ///    else [PaymentStatus.partiallyPaid].
  static PaymentStatus? derive({
    required DocumentStatus documentStatus,
    required Money total,
    required Money netPaid,
    required Money refunded,
    required DateTime? dueDate,
    required DateTime now,
  }) {
    if (documentStatus != DocumentStatus.posted) {
      return null;
    }
    if (netPaid >= total) {
      return PaymentStatus.paid;
    }
    if (dueDate != null && _day(dueDate).isBefore(_day(now))) {
      return PaymentStatus.overdue;
    }
    final anyRefund = refunded.isPositive;
    if (!netPaid.isPositive) {
      return anyRefund ? PaymentStatus.refunded : PaymentStatus.unpaid;
    }
    return anyRefund
        ? PaymentStatus.partiallyRefunded
        : PaymentStatus.partiallyPaid;
  }

  static DateTime _day(DateTime value) {
    final utc = value.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day);
  }
}
