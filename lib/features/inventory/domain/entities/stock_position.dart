import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// Quantity on hand and its total value (weighted-average-cost state).
///
/// Invariants: quantity >= 0, value >= 0, and zero quantity implies zero
/// value.
final class StockPosition extends Equatable {
  /// Creates a position; callers are responsible for the invariants (the
  /// calculator preserves them and the database enforces them).
  const StockPosition({required this.quantity, required this.value});

  /// An empty position in the currency of [zero].
  factory StockPosition.empty(Money zero) =>
      StockPosition(quantity: Quantity.zero, value: zero);

  /// Quantity on hand.
  final Quantity quantity;

  /// Total inventory value of [quantity].
  final Money value;

  /// Average cost per unit, or `null` when no stock is on hand.
  Money? get averageCost =>
      quantity.isPositive ? value.perUnit(quantity) : null;

  @override
  List<Object?> get props => [quantity, value];
}
