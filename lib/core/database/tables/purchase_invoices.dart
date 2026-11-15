import 'package:drift/drift.dart';
import 'package:inventrix/core/database/tables/suppliers.dart';

/// Purchase invoice headers. Posted invoices are immutable (see the
/// triggers in `schema_extras.dart`); they can only move to `voided`.
///
/// Supplier name, currency and all totals are snapshots so history stays
/// correct when master data or settings change.
@DataClassName('PurchaseInvoiceRow')
class PurchaseInvoices extends Table {
  TextColumn get id => text()();

  /// Assigned when posted (unique, enforced by a partial index).
  TextColumn get number => text().nullable()();
  TextColumn get supplierId =>
      text().references(Suppliers, #id, onDelete: KeyAction.restrict)();
  TextColumn get supplierName => text()();
  TextColumn get status => text().customConstraint(
    'NOT NULL CHECK (status IN ('
    "'draft','created','pendingApproval','approved','authorized',"
    "'posted','cancelled','voided'))",
  )();
  IntColumn get invoiceDate => integer()();
  IntColumn get dueDate => integer().nullable()();
  TextColumn get supplierReference => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get currencyCode => text()();
  IntColumn get decimalPlaces => integer().customConstraint(
    'NOT NULL CHECK (decimal_places BETWEEN 0 AND 4)',
  )();
  IntColumn get subtotalMinor =>
      integer().customConstraint('NOT NULL CHECK (subtotal_minor >= 0)')();
  IntColumn get discountTotalMinor => integer().customConstraint(
    'NOT NULL CHECK (discount_total_minor >= 0)',
  )();
  IntColumn get netTotalMinor =>
      integer().customConstraint('NOT NULL CHECK (net_total_minor >= 0)')();
  IntColumn get taxTotalMinor =>
      integer().customConstraint('NOT NULL CHECK (tax_total_minor >= 0)')();
  IntColumn get totalMinor =>
      integer().customConstraint('NOT NULL CHECK (total_minor >= 0)')();
  IntColumn get postedAt => integer().nullable()();
  IntColumn get cancelledAt => integer().nullable()();
  IntColumn get voidedAt => integer().nullable()();
  TextColumn get voidReason => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    // A number exists exactly for documents that were posted.
    "CHECK ((number IS NOT NULL) = (status IN ('posted','voided')))",
    "CHECK (status NOT IN ('posted','voided') OR posted_at IS NOT NULL)",
    "CHECK (status <> 'voided' OR "
        '(voided_at IS NOT NULL AND void_reason IS NOT NULL))',
    'CHECK (total_minor = net_total_minor + tax_total_minor)',
  ];
}
