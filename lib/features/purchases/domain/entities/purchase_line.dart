import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/value_objects/line_amounts.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// One line of a purchase invoice.
///
/// Name, SKU, unit, price, discount and tax are **snapshots** taken when the
/// line was saved, so later edits to the product never change the invoice.
final class PurchaseLine extends Equatable {
  /// Creates a line.
  const PurchaseLine({
    required this.id,
    required this.lineNo,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unitSymbol,
    required this.unitDecimalPlaces,
    required this.quantity,
    required this.unitPrice,
    required this.priceIncludesTax,
    required this.discount,
    required this.taxRateBp,
    required this.amounts,
    this.taxName,
  });

  /// Unique id (also the idempotency key of its stock movement).
  final String id;

  /// 1-based position on the invoice.
  final int lineNo;

  /// The purchased product.
  final String productId;

  /// Product name at the time of purchase.
  final String productName;

  /// Product SKU at the time of purchase.
  final String sku;

  /// Unit symbol at the time of purchase.
  final String unitSymbol;

  /// Decimal places of the unit at the time of purchase.
  final int unitDecimalPlaces;

  /// Purchased quantity (always positive).
  final Quantity quantity;

  /// Price per unit as entered.
  final Money unitPrice;

  /// Whether [unitPrice] includes tax.
  final bool priceIncludesTax;

  /// Line discount.
  final Discount discount;

  /// Tax rate in basis points at the time of purchase.
  final int taxRateBp;

  /// Name of the tax rate at the time of purchase, if any.
  final String? taxName;

  /// Computed amounts.
  final LineAmounts amounts;

  /// Line value before discount.
  Money get gross => amounts.gross;

  /// Discount amount.
  Money get discountAmount => amounts.discount;

  /// Taxable amount (inventory cost of this line).
  Money get net => amounts.net;

  /// Tax amount.
  Money get tax => amounts.tax;

  /// Total including tax.
  Money get total => amounts.total;

  @override
  List<Object?> get props => [
    id,
    lineNo,
    productId,
    productName,
    sku,
    unitSymbol,
    unitDecimalPlaces,
    quantity,
    unitPrice,
    priceIncludesTax,
    discount,
    taxRateBp,
    taxName,
    amounts,
  ];
}
