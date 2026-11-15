import 'package:drift/drift.dart';
import 'package:inventrix/core/database/tables/customers.dart';
import 'package:inventrix/core/database/tables/payment_methods.dart';
import 'package:inventrix/core/database/tables/suppliers.dart';

/// Payments received from customers or made to suppliers, and refunds of
/// them. Rows are append-only (see the triggers in `schema_extras.dart`):
/// a payment is cancelled by a row in `payment_reversals`, never edited or
/// deleted. Party name, method name and currency are snapshots.
@DataClassName('PaymentRow')
class Payments extends Table {
  TextColumn get id => text()();

  /// `PAY-000001` or `RFD-000001`; unique.
  TextColumn get number => text()();
  TextColumn get kind => text().customConstraint(
    "NOT NULL CHECK (kind IN ('payment','refund'))",
  )();
  TextColumn get partyType => text().customConstraint(
    "NOT NULL CHECK (party_type IN ('customer','supplier'))",
  )();
  TextColumn get customerId => text().nullable().references(
    Customers,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get supplierId => text().nullable().references(
    Suppliers,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get partyName => text()();
  TextColumn get methodId => text().references(
    PaymentMethods,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get methodName => text()();
  IntColumn get paymentDate => integer()();
  IntColumn get amountMinor =>
      integer().customConstraint('NOT NULL CHECK (amount_minor > 0)')();
  TextColumn get currencyCode => text()();
  IntColumn get decimalPlaces => integer().customConstraint(
    'NOT NULL CHECK (decimal_places BETWEEN 0 AND 4)',
  )();
  TextColumn get reference => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// For a refund: the payment it gives money back from.
  TextColumn get refundOfPaymentId => text().nullable().references(
    Payments,
    #id,
    onDelete: KeyAction.restrict,
  )();

  /// Makes recording safe to repeat; unique.
  TextColumn get idempotencyKey => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK ((party_type = 'customer' AND customer_id IS NOT NULL "
        'AND supplier_id IS NULL) OR '
        "(party_type = 'supplier' AND supplier_id IS NOT NULL "
        'AND customer_id IS NULL))',
    "CHECK ((kind = 'refund') = (refund_of_payment_id IS NOT NULL))",
  ];
}
