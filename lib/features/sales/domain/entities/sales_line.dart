import 'package:equatable/equatable.dart';
import 'package:inventrix/features/product_classification/domain/entities/product_classification.dart';
import 'package:inventrix/features/taxation/domain/entities/line_tax_snapshot.dart';
import 'package:inventrix/shared/domain/value_objects/line_amounts.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// One line of a sale invoice.
///
/// Name, SKU, unit, price, discount and tax are **snapshots** taken when the
/// line was saved, so later edits to the product never change the invoice.
final class SalesLine extends Equatable {
  /// Creates a line.
  const SalesLine({
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
    this.taxSnapshot,
    this.classification,
  });

  /// Unique id (also the idempotency key of its stock movement).
  final String id;

  /// 1-based position on the invoice.
  final int lineNo;

  /// The saled product.
  final String productId;

  /// Product name at the time of sale.
  final String productName;

  /// Product SKU at the time of sale.
  final String sku;

  /// Unit symbol at the time of sale.
  final String unitSymbol;

  /// Decimal places of the unit at the time of sale.
  final int unitDecimalPlaces;

  /// Salesd quantity (always positive).
  final Quantity quantity;

  /// Price per unit as entered.
  final Money unitPrice;

  /// Whether [unitPrice] includes tax.
  final bool priceIncludesTax;

  /// Line discount.
  final Discount discount;

  /// Tax rate in basis points at the time of sale.
  final int taxRateBp;

  /// Name of the tax rate at the time of sale, if any.
  final String? taxName;

  /// Computed amounts.
  final LineAmounts amounts;

  /// How the line was taxed (components, rules, treatment); `null` for
  /// lines taxed with the single-rate path or created before schema v11.
  final LineTaxSnapshot? taxSnapshot;

  /// Primary classification (HSN/SAC/...) frozen with the line, if any.
  final ClassificationSnapshot? classification;

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
    taxSnapshot,
    classification,
  ];
}
