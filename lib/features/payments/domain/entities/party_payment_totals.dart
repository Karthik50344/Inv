import 'package:equatable/equatable.dart';

/// Sums of a party's active payments and refunds, in minor units.
final class PartyPaymentTotals extends Equatable {
  /// Creates totals.
  const PartyPaymentTotals({
    this.paymentsMinor = 0,
    this.refundsMinor = 0,
  });

  /// Sum of active payments.
  final int paymentsMinor;

  /// Sum of active refunds.
  final int refundsMinor;

  @override
  List<Object?> get props => [paymentsMinor, refundsMinor];
}
