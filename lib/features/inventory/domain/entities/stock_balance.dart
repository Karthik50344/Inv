import 'package:equatable/equatable.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_position.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// The maintained projection of the ledger for one product.
final class StockBalance extends Equatable {
  /// Creates a balance.
  const StockBalance({
    required this.productId,
    required this.quantityOnHand,
    required this.inventoryValue,
    this.updatedAt,
  });

  /// Product id.
  final String productId;

  /// Quantity on hand.
  final Quantity quantityOnHand;

  /// Total value of the stock on hand.
  final Money inventoryValue;

  /// Last change (UTC); `null` if the balance row does not exist yet.
  final DateTime? updatedAt;

  /// The balance as a calculator input.
  StockPosition get position =>
      StockPosition(quantity: quantityOnHand, value: inventoryValue);

  /// Weighted average cost per unit, or `null` with no stock.
  Money? get averageCost => position.averageCost;

  @override
  List<Object?> get props => [
    productId,
    quantityOnHand,
    inventoryValue,
    updatedAt,
  ];
}
