import 'package:drift/drift.dart';
import 'package:inventrix/core/database/tables/products.dart';
import 'package:inventrix/core/database/tables/purchase_invoice_items.dart';
import 'package:inventrix/core/database/tables/purchase_returns.dart';

/// Returned lines of a purchase return, with snapshots of the original line.
@DataClassName('PurchaseReturnItemRow')
class PurchaseReturnItems extends Table {
  TextColumn get id => text()();
  TextColumn get returnId =>
      text().references(PurchaseReturns, #id, onDelete: KeyAction.restrict)();
  IntColumn get lineNo =>
      integer().customConstraint('NOT NULL CHECK (line_no >= 1)')();

  /// The invoice line being returned.
  TextColumn get invoiceItemId => text().references(
    PurchaseInvoiceItems,
    #id,
    onDelete: KeyAction.restrict,
  )();
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
  IntColumn get netMinor =>
      integer().customConstraint('NOT NULL CHECK (net_minor >= 0)')();
  IntColumn get taxMinor =>
      integer().customConstraint('NOT NULL CHECK (tax_minor >= 0)')();
  IntColumn get totalMinor =>
      integer().customConstraint('NOT NULL CHECK (total_minor >= 0)')();

  /// Value that left stock.
  IntColumn get stockCostMinor => integer().customConstraint(
    'NOT NULL CHECK (stock_cost_minor >= 0)',
  )();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {returnId, lineNo},
    {returnId, invoiceItemId},
  ];

  @override
  List<String> get customConstraints => [
    'CHECK (total_minor = net_minor + tax_minor)',
  ];
}
