import 'package:drift/drift.dart';
import 'package:inventrix/core/database/tables/customers.dart';
import 'package:inventrix/core/database/tables/payment_methods.dart';
import 'package:inventrix/core/database/tables/sales_invoices.dart';

/// Sales return headers. Append-only (see the triggers in
/// `schema_extras.dart`): a return is never edited or deleted. Party name,
/// invoice number, currency, totals and the refund method name are
/// snapshots.
@DataClassName('SalesReturnRow')
class SalesReturns extends Table {
  TextColumn get id => text()();

  /// `SRN-000001`; unique.
  TextColumn get number => text()();
  TextColumn get invoiceId =>
      text().references(SalesInvoices, #id, onDelete: KeyAction.restrict)();
  TextColumn get invoiceNumber => text()();

  /// `null` for a return of a walk-in sale.
  TextColumn get customerId => text().nullable().references(
    Customers,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get customerName => text()();
  IntColumn get returnDate => integer()();
  TextColumn get reason => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get currencyCode => text()();
  IntColumn get decimalPlaces => integer().customConstraint(
    'NOT NULL CHECK (decimal_places BETWEEN 0 AND 4)',
  )();
  IntColumn get netTotalMinor =>
      integer().customConstraint('NOT NULL CHECK (net_total_minor >= 0)')();
  IntColumn get taxTotalMinor =>
      integer().customConstraint('NOT NULL CHECK (tax_total_minor >= 0)')();
  IntColumn get totalMinor =>
      integer().customConstraint('NOT NULL CHECK (total_minor >= 0)')();

  /// Cash handed back to the customer (0 = none, the value stays as credit).
  IntColumn get refundAmountMinor => integer().customConstraint(
    'NOT NULL CHECK (refund_amount_minor >= 0)',
  )();
  TextColumn get refundMethodId => text().nullable().references(
    PaymentMethods,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get refundMethodName => text().nullable()();
  TextColumn get refundReference => text().nullable()();

  /// Makes posting safe to repeat; unique.
  TextColumn get idempotencyKey => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (total_minor = net_total_minor + tax_total_minor)',
    'CHECK (refund_amount_minor <= total_minor)',
    'CHECK ((refund_amount_minor > 0) = (refund_method_id IS NOT NULL))',
  ];
}
