import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Summary of inventory across all products.
final class InventoryValuation extends Equatable {
  /// Creates a valuation.
  const InventoryValuation({
    required this.totalValue,
    required this.productsInStock,
    required this.lowStockCount,
    required this.outOfStockCount,
  });

  /// Sum of all balances' values (archived products included).
  final Money totalValue;

  /// Number of products with stock on hand.
  final int productsInStock;

  /// Active products at or below their reorder level (but not out).
  final int lowStockCount;

  /// Active products with no stock.
  final int outOfStockCount;

  @override
  List<Object?> get props => [
    totalValue,
    productsInStock,
    lowStockCount,
    outOfStockCount,
  ];
}
