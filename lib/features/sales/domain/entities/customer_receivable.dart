import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// What a customer owes the business.
///
/// `outstanding = openingBalance + sales`. Payments and refunds reduce it
/// from Phase 6 on.
final class CustomerReceivable extends Equatable {
  /// Creates a receivable.
  const CustomerReceivable({
    required this.openingBalance,
    required this.sales,
  });

  /// Opening balance recorded on the customer (negative is a credit).
  final Money openingBalance;

  /// Total of the customer's posted sales invoices.
  final Money sales;

  /// Amount currently owed.
  Money get outstanding => openingBalance + sales;

  @override
  List<Object?> get props => [openingBalance, sales];
}
