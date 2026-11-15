import 'package:equatable/equatable.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_balance.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_status.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';

/// A product together with its stock balance.
final class StockItem extends Equatable {
  /// Creates an item.
  const StockItem({required this.product, required this.balance});

  /// The product.
  final Product product;

  /// Its balance.
  final StockBalance balance;

  /// Stock health: out when nothing is on hand, low when at or below a
  /// positive reorder level.
  StockStatus get status {
    final onHand = balance.quantityOnHand;
    if (onHand.isZero || onHand.isNegative) {
      return StockStatus.out;
    }
    final reorder = product.reorderLevel;
    if (reorder.isPositive && onHand <= reorder) {
      return StockStatus.low;
    }
    return StockStatus.ok;
  }

  @override
  List<Object?> get props => [product, balance];
}
