import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// One returned line. Product, SKU and unit are snapshots of the original
/// invoice line; amounts are the matching share of that line's net and tax.
final class ReturnLine extends Equatable {
  /// Creates a line.
  const ReturnLine({
    required this.id,
    required this.lineNo,
    required this.invoiceLineId,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unitSymbol,
    required this.unitDecimalPlaces,
    required this.quantity,
    required this.net,
    required this.tax,
    required this.restocked,
    required this.stockCost,
    this.note,
  });

  /// Unique id (also the source line id of its stock movement).
  final String id;

  /// 1-based position on the return.
  final int lineNo;

  /// The line of the original invoice that is being returned.
  final String invoiceLineId;

  /// The returned product.
  final String productId;

  /// Product name on the original invoice.
  final String productName;

  /// Product SKU on the original invoice.
  final String sku;

  /// Unit symbol on the original invoice.
  final String unitSymbol;

  /// Decimal places of the unit on the original invoice.
  final int unitDecimalPlaces;

  /// Returned quantity (always positive).
  final Quantity quantity;

  /// Value of the goods without tax.
  final Money net;

  /// Tax on the returned goods.
  final Money tax;

  /// Sales return: whether the goods went back into stock. A purchase
  /// return always takes the goods out of stock, so it is always `true`.
  final bool restocked;

  /// Value that entered stock (sales return) or left it (purchase
  /// return); zero when the goods were not restocked.
  final Money stockCost;

  /// Optional note about this line.
  final String? note;

  /// Net plus tax.
  Money get total => net + tax;

  @override
  List<Object?> get props => [
    id,
    lineNo,
    invoiceLineId,
    productId,
    productName,
    sku,
    unitSymbol,
    unitDecimalPlaces,
    quantity,
    net,
    tax,
    restocked,
    stockCost,
    note,
  ];
}
