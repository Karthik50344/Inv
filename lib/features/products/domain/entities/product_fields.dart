import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// Validated, typed product data without identity or timestamps.
final class ProductFields extends Equatable {
  /// Creates validated fields.
  const ProductFields({
    required this.name,
    required this.unitId,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.priceIncludesTax,
    required this.reorderLevel,
    this.sku,
    this.barcode,
    this.description,
    this.categoryId,
    this.taxRateId,
    this.imagePath,
  });

  /// Normalized (upper-case) SKU; `null` only when it should be generated.
  final String? sku;

  /// Optional barcode.
  final String? barcode;

  /// Product name.
  final String name;

  /// Optional description.
  final String? description;

  /// Optional category id.
  final String? categoryId;

  /// Unit id.
  final String unitId;

  /// Default purchase price per unit.
  final Money purchasePrice;

  /// Default selling price per unit.
  final Money sellingPrice;

  /// Whether prices include tax.
  final bool priceIncludesTax;

  /// Optional tax rate id (null = no tax configured).
  final String? taxRateId;

  /// Stock level at or below which the product is considered low.
  final Quantity reorderLevel;

  /// Path of the stored product image, if any.
  final String? imagePath;

  @override
  List<Object?> get props => [
    sku,
    barcode,
    name,
    description,
    categoryId,
    unitId,
    purchasePrice,
    sellingPrice,
    priceIncludesTax,
    taxRateId,
    reorderLevel,
    imagePath,
  ];
}
