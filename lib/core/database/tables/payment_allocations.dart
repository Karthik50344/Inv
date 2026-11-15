import 'package:drift/drift.dart';
import 'package:inventrix/core/database/tables/payments.dart';
import 'package:inventrix/core/database/tables/purchase_invoices.dart';
import 'package:inventrix/core/database/tables/sales_invoices.dart';

/// The part of a payment applied to one invoice: exactly one of the two
/// invoice columns is set. Positive for payments, negative for refunds.
@DataClassName('PaymentAllocationRow')
class PaymentAllocations extends Table {
  TextColumn get id => text()();
  TextColumn get paymentId => text().references(
    Payments,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get salesInvoiceId => text().nullable().references(
    SalesInvoices,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get purchaseInvoiceId => text().nullable().references(
    PurchaseInvoices,
    #id,
    onDelete: KeyAction.restrict,
  )();

  /// Invoice number at the time of allocation.
  TextColumn get invoiceNumber => text()();
  IntColumn get amountMinor =>
      integer().customConstraint('NOT NULL CHECK (amount_minor <> 0)')();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK ((sales_invoice_id IS NULL) <> (purchase_invoice_id IS NULL))',
  ];
}
