import 'package:equatable/equatable.dart';
import 'package:inventrix/features/products/domain/entities/product_fields.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// A sellable/purchasable product.
final class Product extends Equatable {
  /// Creates a product.
  const Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.unitId,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.priceIncludesTax,
    required this.reorderLevel,
    required this.createdAt,
    required this.updatedAt,
    this.barcode,
    this.description,
    this.categoryId,
    this.taxRateId,
    this.imagePath,
    this.archivedAt,
  });

  /// Builds a product from validated [fields].
  factory Product.fromFields({
    required String id,
    required String sku,
    required ProductFields fields,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? archivedAt,
  }) => Product(
    id: id,
    sku: sku,
    barcode: fields.barcode,
    name: fields.name,
    description: fields.description,
    categoryId: fields.categoryId,
    unitId: fields.unitId,
    purchasePrice: fields.purchasePrice,
    sellingPrice: fields.sellingPrice,
    priceIncludesTax: fields.priceIncludesTax,
    taxRateId: fields.taxRateId,
    reorderLevel: fields.reorderLevel,
    imagePath: fields.imagePath,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
  );

  /// Unique id.
  final String id;

  /// Unique SKU (upper-case).
  final String sku;

  /// Optional barcode (unique when present).
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

  /// Optional tax rate id.
  final String? taxRateId;

  /// Reorder level.
  final Quantity reorderLevel;

  /// Stored image path, if any.
  final String? imagePath;

  /// Creation time (UTC).
  final DateTime createdAt;

  /// Last update time (UTC).
  final DateTime updatedAt;

  /// Archive time, if archived.
  final DateTime? archivedAt;

  /// Whether the product is archived.
  bool get isArchived => archivedAt != null;

  /// Archived copy.
  Product archived(DateTime at) => _copy(updatedAt: at, archivedAt: at);

  /// Restored (active) copy.
  Product restored(DateTime at) => _copy(updatedAt: at);

  Product _copy({required DateTime updatedAt, DateTime? archivedAt}) => Product(
    id: id,
    sku: sku,
    barcode: barcode,
    name: name,
    description: description,
    categoryId: categoryId,
    unitId: unitId,
    purchasePrice: purchasePrice,
    sellingPrice: sellingPrice,
    priceIncludesTax: priceIncludesTax,
    taxRateId: taxRateId,
    reorderLevel: reorderLevel,
    imagePath: imagePath,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
  );

  @override
  List<Object?> get props => [
    id,
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
    createdAt,
    updatedAt,
    archivedAt,
  ];
}
