import 'package:drift/drift.dart';
import 'package:inventrix/core/database/tables/categories.dart';
import 'package:inventrix/core/database/tables/tax_categories.dart';
import 'package:inventrix/core/database/tables/tax_overrides.dart';
import 'package:inventrix/core/database/tables/tax_rates.dart';
import 'package:inventrix/core/database/tables/units.dart';

/// Sellable/purchasable items. Prices are integer minor units.
@DataClassName('ProductRow')
@TableIndex(name: 'idx_products_category_id', columns: {#categoryId})
@TableIndex(name: 'idx_products_name', columns: {#name})
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get sku => text()();
  TextColumn get barcode => text().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get categoryId => text().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get unitId =>
      text().references(Units, #id, onDelete: KeyAction.restrict)();
  IntColumn get purchasePriceMinor => integer().customConstraint(
    'NOT NULL CHECK (purchase_price_minor >= 0)',
  )();
  IntColumn get sellingPriceMinor =>
      integer().customConstraint('NOT NULL CHECK (selling_price_minor >= 0)')();
  BoolColumn get priceIncludesTax =>
      boolean().withDefault(const Constant(false))();
  TextColumn get taxRateId => text().nullable().references(
    TaxRates,
    #id,
    onDelete: KeyAction.restrict,
  )();

  /// Configurable tax model (schema v10): the product's tax category and an
  /// optional explicit override. Neither holds a tax amount.
  TextColumn get taxCategoryId => text().nullable().references(
    TaxCategories,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get taxOverrideId => text().nullable().references(
    TaxOverrides,
    #id,
    onDelete: KeyAction.restrict,
  )();
  IntColumn get reorderLevelMilli =>
      integer().customConstraint('NOT NULL CHECK (reorder_level_milli >= 0)')();
  TextColumn get imagePath => text().nullable()();
  IntColumn get archivedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {sku},
  ];
}
