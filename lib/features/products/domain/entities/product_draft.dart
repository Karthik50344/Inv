import 'package:equatable/equatable.dart';

/// Raw (text) product input from a form; validated by `ProductValidator`.
final class ProductDraft extends Equatable {
  /// Creates a draft.
  const ProductDraft({
    required this.name,
    required this.unitId,
    this.sku = '',
    this.barcode = '',
    this.description = '',
    this.categoryId,
    this.purchasePrice = '',
    this.sellingPrice = '',
    this.priceIncludesTax = false,
    this.taxRateId,
    this.reorderLevel = '',
    this.imagePath,
  });

  /// SKU text (blank allowed on create to auto-generate).
  final String sku;

  /// Barcode text.
  final String barcode;

  /// Product name.
  final String name;

  /// Description text.
  final String description;

  /// Selected category id.
  final String? categoryId;

  /// Selected unit id (empty when none selected).
  final String unitId;

  /// Purchase price text (blank = 0).
  final String purchasePrice;

  /// Selling price text (blank = 0).
  final String sellingPrice;

  /// Whether prices include tax.
  final bool priceIncludesTax;

  /// Selected tax rate id.
  final String? taxRateId;

  /// Reorder level text (blank = 0).
  final String reorderLevel;

  /// Stored image path.
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
