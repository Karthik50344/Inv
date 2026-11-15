import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// What the business owes a supplier.
///
/// `outstanding = openingBalance + purchases`. Payments and refunds reduce
/// it from Phase 6 on.
final class SupplierPayable extends Equatable {
  /// Creates a payable.
  const SupplierPayable({
    required this.openingBalance,
    required this.purchases,
  });

  /// Opening balance recorded on the supplier (negative is a credit).
  final Money openingBalance;

  /// Total of the supplier's posted purchase invoices.
  final Money purchases;

  /// Amount currently owed.
  Money get outstanding => openingBalance + purchases;

  @override
  List<Object?> get props => [openingBalance, purchases];
}
