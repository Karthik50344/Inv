import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// What the ledger says about one product (sum of its movements).
final class LedgerTotals extends Equatable {
  /// Creates totals.
  const LedgerTotals({
    required this.productId,
    required this.quantity,
    required this.value,
  });

  /// Product id.
  final String productId;

  /// Sum of signed quantity deltas.
  final Quantity quantity;

  /// Sum of signed value deltas.
  final Money value;

  @override
  List<Object?> get props => [productId, quantity, value];
}

/// A product whose maintained balance disagrees with its ledger.
final class BalanceMismatch extends Equatable {
  /// Creates a mismatch.
  const BalanceMismatch({
    required this.productId,
    required this.expectedQuantity,
    required this.expectedValue,
    required this.actualQuantity,
    required this.actualValue,
    required this.balanceMissing,
  });

  /// Product id.
  final String productId;

  /// Quantity according to the ledger.
  final Quantity expectedQuantity;

  /// Value according to the ledger.
  final Money expectedValue;

  /// Quantity stored in the balance (zero if the row is missing).
  final Quantity actualQuantity;

  /// Value stored in the balance (zero if the row is missing).
  final Money actualValue;

  /// Whether the balance row does not exist.
  final bool balanceMissing;

  @override
  List<Object?> get props => [
    productId,
    expectedQuantity,
    expectedValue,
    actualQuantity,
    actualValue,
    balanceMissing,
  ];
}

/// Result of comparing every balance against the ledger.
final class ReconciliationReport extends Equatable {
  /// Creates a report.
  const ReconciliationReport({
    required this.productsChecked,
    required this.mismatches,
  });

  /// Number of products compared.
  final int productsChecked;

  /// Products whose balance is wrong.
  final List<BalanceMismatch> mismatches;

  /// Whether every balance matches the ledger.
  bool get isConsistent => mismatches.isEmpty;

  @override
  List<Object?> get props => [productsChecked, mismatches];
}
