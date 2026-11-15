import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/errors/failure.dart';

/// Inserts a unit row using raw SQL (exercises the real schema constraints).
Future<void> insertUnit(
  AppDatabase db,
  String id, {
  String symbol = 'pcs',
  int decimalPlaces = 0,
}) => db.customStatement(
  'INSERT INTO units (id, name, symbol, decimal_places, archived_at, '
  'created_at, updated_at) VALUES (?, ?, ?, ?, NULL, 1, 1)',
  [id, 'Unit $id', symbol, decimalPlaces],
);

/// Inserts a category row.
Future<void> insertCategory(
  AppDatabase db,
  String id, {
  String name = 'Category',
  int? archivedAt,
}) => db.customStatement(
  'INSERT INTO categories (id, name, description, parent_id, archived_at, '
  'created_at, updated_at) VALUES (?, ?, NULL, NULL, ?, 1, 1)',
  [id, name, archivedAt],
);

/// Inserts a product row.
Future<void> insertProduct(
  AppDatabase db,
  String id, {
  String sku = 'SKU-1',
  String? barcode,
  String unitId = 'u1',
  String? categoryId,
}) => db.customStatement(
  'INSERT INTO products (id, sku, barcode, name, description, '
  'category_id, unit_id, purchase_price_minor, selling_price_minor, '
  'price_includes_tax, tax_rate_id, reorder_level_milli, image_path, '
  'archived_at, created_at, updated_at) '
  'VALUES (?, ?, ?, ?, NULL, ?, ?, 0, 0, 0, NULL, 0, NULL, NULL, 1, 1)',
  [id, sku, barcode, 'Product $id', categoryId, unitId],
);

/// Inserts a stock movement row.
Future<void> insertMovement(
  AppDatabase db,
  String id, {
  String productId = 'p1',
  String type = 'purchase',
  int deltaMilli = 1000,
  int totalCostMinor = 500,
  String? reason,
  String? sourceType,
  String? sourceId,
  String? sourceLineId,
}) => db.customStatement(
  'INSERT INTO stock_movements (id, product_id, movement_type, '
  'quantity_delta_milli, total_cost_minor, unit_cost_minor_snapshot, '
  'source_type, source_id, source_line_id, reason, occurred_at, '
  'created_at) VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?, ?, 1, 1)',
  [
    id,
    productId,
    type,
    deltaMilli,
    totalCostMinor,
    sourceType,
    sourceId,
    sourceLineId,
    reason,
  ],
);

/// Runs [action], expecting it to fail, and returns the mapped [Failure].
Future<Failure> failureOf(Future<void> Function() action) async {
  try {
    await action();
  } on Object catch (error, stackTrace) {
    return mapDatabaseError(error, stackTrace);
  }
  fail('Expected the operation to fail, but it succeeded.');
}

/// Inserts a supplier row.
Future<void> insertSupplier(AppDatabase db, String id) => db.customStatement(
  'INSERT INTO suppliers (id, name, opening_balance_minor, created_at, '
  'updated_at) VALUES (?, ?, 0, 1, 1)',
  [id, 'Supplier $id'],
);

/// Inserts a customer row.
Future<void> insertCustomer(AppDatabase db, String id) => db.customStatement(
  'INSERT INTO customers (id, name, opening_balance_minor, created_at, '
  'updated_at) VALUES (?, ?, 0, 1, 1)',
  [id, 'Customer $id'],
);

/// Inserts a purchase invoice header. Posted/voided invoices need a number
/// and a posted time; use [status] `draft` for a plain draft.
Future<void> insertPurchaseInvoice(
  AppDatabase db,
  String id, {
  String supplierId = 's1',
  String status = 'draft',
  String? number,
  int totalMinor = 1180,
  int netMinor = 1000,
  int taxMinor = 180,
  int? postedAt,
  int? voidedAt,
  String? voidReason,
}) => db.customStatement(
  'INSERT INTO purchase_invoices (id, number, supplier_id, supplier_name, '
  'status, invoice_date, currency_code, decimal_places, subtotal_minor, '
  'discount_total_minor, net_total_minor, tax_total_minor, total_minor, '
  'posted_at, voided_at, void_reason, created_at, updated_at) '
  "VALUES (?, ?, ?, 'Supplier', ?, 1, 'INR', 2, ?, 0, ?, ?, ?, ?, ?, ?, 1, 1)",
  [
    id,
    number,
    supplierId,
    status,
    netMinor,
    netMinor,
    taxMinor,
    totalMinor,
    postedAt,
    voidedAt,
    voidReason,
  ],
);

/// Inserts a purchase invoice line.
Future<void> insertPurchaseItem(
  AppDatabase db,
  String id, {
  String invoiceId = 'i1',
  int lineNo = 1,
  String productId = 'p1',
  int quantityMilli = 1000,
}) => db.customStatement(
  'INSERT INTO purchase_invoice_items (id, invoice_id, line_no, product_id, '
  'product_name, sku, unit_symbol, unit_decimal_places, quantity_milli, '
  'unit_price_minor, price_includes_tax, discount_type, discount_value, '
  'tax_rate_bp, tax_name, gross_minor, discount_minor, net_minor, tax_minor, '
  "total_minor) VALUES (?, ?, ?, ?, 'Product', 'SKU', 'pcs', 0, ?, 1000, 0, "
  "'none', 0, 1800, 'GST', 1000, 0, 1000, 180, 1180)",
  [id, invoiceId, lineNo, productId, quantityMilli],
);

/// Inserts a sales invoice header. Posted/voided invoices need a number
/// and a posted time; use [status] `draft` for a plain draft.
Future<void> insertSalesInvoice(
  AppDatabase db,
  String id, {
  String? customerId = 's1',
  String status = 'draft',
  String? number,
  int totalMinor = 1180,
  int netMinor = 1000,
  int taxMinor = 180,
  int? postedAt,
  int? voidedAt,
  String? voidReason,
}) => db.customStatement(
  'INSERT INTO sales_invoices (id, number, customer_id, customer_name, '
  'status, invoice_date, currency_code, decimal_places, subtotal_minor, '
  'discount_total_minor, net_total_minor, tax_total_minor, total_minor, '
  'posted_at, voided_at, void_reason, created_at, updated_at) '
  "VALUES (?, ?, ?, 'Customer', ?, 1, 'INR', 2, ?, 0, ?, ?, ?, ?, ?, ?, 1, 1)",
  [
    id,
    number,
    customerId,
    status,
    netMinor,
    netMinor,
    taxMinor,
    totalMinor,
    postedAt,
    voidedAt,
    voidReason,
  ],
);

/// Inserts a sales invoice line.
Future<void> insertSalesItem(
  AppDatabase db,
  String id, {
  String invoiceId = 'i1',
  int lineNo = 1,
  String productId = 'p1',
  int quantityMilli = 1000,
}) => db.customStatement(
  'INSERT INTO sales_invoice_items (id, invoice_id, line_no, product_id, '
  'product_name, sku, unit_symbol, unit_decimal_places, quantity_milli, '
  'unit_price_minor, price_includes_tax, discount_type, discount_value, '
  'tax_rate_bp, tax_name, gross_minor, discount_minor, net_minor, tax_minor, '
  "total_minor) VALUES (?, ?, ?, ?, 'Product', 'SKU', 'pcs', 0, ?, 1000, 0, "
  "'none', 0, 1800, 'GST', 1000, 0, 1000, 180, 1180)",
  [id, invoiceId, lineNo, productId, quantityMilli],
);
