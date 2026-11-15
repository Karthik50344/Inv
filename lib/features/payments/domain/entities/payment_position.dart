import 'package:equatable/equatable.dart';
import 'package:inventrix/features/payments/domain/entities/payment.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// How much of a payment is still unspent, derived from the payment, its
/// allocations and its active refunds.
final class PaymentPosition extends Equatable {
  /// Creates a position.
  const PaymentPosition({
    required this.amount,
    required this.refunded,
    required this.allocatedNet,
    required this.allocatedByInvoice,
  });

  /// Derives the position of [payment] given its active [refunds].
  factory PaymentPosition.of(Payment payment, Iterable<Payment> refunds) {
    final active = refunds.where((r) => r.isActive).toList();
    final amount = payment.amount;
    Money sum(Iterable<Money> values) => Money.sum(
      values,
      currencyCode: amount.currencyCode,
      decimalPlaces: amount.decimalPlaces,
    );
    final byInvoice = <String, int>{};
    for (final allocation in [
      ...payment.allocations,
      for (final refund in active) ...refund.allocations,
    ]) {
      byInvoice.update(
        allocation.invoiceId,
        (v) => v + allocation.amount.minorUnits,
        ifAbsent: () => allocation.amount.minorUnits,
      );
    }
    return PaymentPosition(
      amount: amount,
      refunded: sum(active.map((r) => r.amount)),
      allocatedNet: sum([
        ...payment.allocations.map((a) => a.amount),
        for (final refund in active) ...refund.allocations.map((a) => a.amount),
      ]),
      allocatedByInvoice: byInvoice,
    );
  }

  /// The payment amount.
  final Money amount;

  /// Total of active refunds taken from this payment.
  final Money refunded;

  /// Allocated to invoices, net of refund reductions.
  final Money allocatedNet;

  /// Net minor units this payment still settles, per invoice id.
  final Map<String, int> allocatedByInvoice;

  /// Money held that is not applied to any invoice (never negative).
  Money get credit {
    final value = amount - refunded - allocatedNet;
    return value.isNegative ? amount - amount : value;
  }

  /// How much can still be refunded.
  Money get refundable => amount - refunded;

  @override
  List<Object?> get props => [amount, refunded, allocatedNet, allocatedByInvoice];
}
