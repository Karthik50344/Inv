import 'package:drift/drift.dart';
import 'package:inventrix/core/database/tables/products.dart';

/// Offline product classification codes (HSN, SAC, HS, custom). A product
/// may have several; at most one is primary. Codes are entered by the user
/// and never looked up online or invented.
@DataClassName('ProductClassificationRow')
@TableIndex(name: 'idx_product_classifications_product', columns: {#productId})
@TableIndex(name: 'idx_product_classifications_code', columns: {#classificationCode})
class ProductClassifications extends Table {
  TextColumn get id => text()();
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.restrict)();
  TextColumn get classificationSystem => text()();
  TextColumn get classificationCode => text()();
  TextColumn get classificationDescription => text().nullable()();
  TextColumn get countryCode => text().nullable()();
  TextColumn get classificationType => text()();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {productId, classificationSystem, classificationCode},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (classification_type IN ('goods', 'services', 'other'))",
    'CHECK (length(trim(classification_code)) > 0)',
    'CHECK (length(trim(classification_system)) > 0)',
  ];
}
