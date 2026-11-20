import 'package:drift/drift.dart';
import 'package:inventrix/core/database/tables/products.dart';
import 'package:inventrix/core/database/tables/purchase_invoices.dart';

/// Purchase invoice lines with snapshots of product, unit, price, discount
/// and tax at the time of purchase.
@DataClassName('PurchaseInvoiceItemRow')
class PurchaseInvoiceItems extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId =>
      text().references(PurchaseInvoices, #id, onDelete: KeyAction.restrict)();
  IntColumn get lineNo =>
      integer().customConstraint('NOT NULL CHECK (line_no >= 1)')();
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.restrict)();
  TextColumn get productName => text()();
  TextColumn get sku => text()();
  TextColumn get unitSymbol => text()();
  IntColumn get unitDecimalPlaces => integer().customConstraint(
    'NOT NULL CHECK (unit_decimal_places BETWEEN 0 AND 3)',
  )();
  IntColumn get quantityMilli =>
      integer().customConstraint('NOT NULL CHECK (quantity_milli > 0)')();
  IntColumn get unitPriceMinor =>
      integer().customConstraint('NOT NULL CHECK (unit_price_minor >= 0)')();
  BoolColumn get priceIncludesTax => boolean()();
  TextColumn get discountType => text().customConstraint(
    "NOT NULL CHECK (discount_type IN ('none','percent','amount'))",
  )();
  IntColumn get discountValue =>
      integer().customConstraint('NOT NULL CHECK (discount_value >= 0)')();
  IntColumn get taxRateBp => integer().customConstraint(
    'NOT NULL CHECK (tax_rate_bp BETWEEN 0 AND 100000)',
  )();
  TextColumn get taxName => text().nullable()();
  IntColumn get grossMinor =>
      integer().customConstraint('NOT NULL CHECK (gross_minor >= 0)')();
  IntColumn get discountMinor =>
      integer().customConstraint('NOT NULL CHECK (discount_minor >= 0)')();
  IntColumn get netMinor =>
      integer().customConstraint('NOT NULL CHECK (net_minor >= 0)')();
  IntColumn get taxMinor =>
      integer().customConstraint('NOT NULL CHECK (tax_minor >= 0)')();
  IntColumn get totalMinor =>
      integer().customConstraint('NOT NULL CHECK (total_minor >= 0)')();

  // Schema v11: tax and classification snapshots (null on lines created by
  // the single-rate path or before v11).
  TextColumn get taxTreatment => text().nullable()();
  TextColumn get taxCategoryId => text().nullable()();
  TextColumn get taxSnapshotJson => text().nullable()();
  TextColumn get classificationSystem => text().nullable()();
  TextColumn get classificationCode => text().nullable()();
  TextColumn get classificationDescription => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {invoiceId, lineNo},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (total_minor = net_minor + tax_minor)',
    'CHECK (discount_minor <= gross_minor)',
  ];
}
