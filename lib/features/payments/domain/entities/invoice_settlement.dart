import 'package:equatable/equatable.dart';

/// What the active payments say about one invoice, in minor units.
final class InvoiceSettlement extends Equatable {
  /// Creates a settlement.
  const InvoiceSettlement({
    this.netPaidMinor = 0,
    this.refundedMinor = 0,
    this.activeCount = 0,
  });

  /// No payment activity.
  static const InvoiceSettlement none = InvoiceSettlement();

  /// Payments minus refunds allocated to the invoice.
  final int netPaidMinor;

  /// Total handed back through refunds (a positive number).
  final int refundedMinor;

  /// Number of active allocations (payments and refunds).
  final int activeCount;

  @override
  List<Object?> get props => [netPaidMinor, refundedMinor, activeCount];
}
