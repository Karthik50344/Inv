import 'package:drift/drift.dart';
import 'package:inventrix/core/database/tables/payments.dart';

/// Cancels the financial effect of a payment without deleting it. At most
/// one reversal per payment (unique index in `schema_extras.dart`).
@DataClassName('PaymentReversalRow')
class PaymentReversals extends Table {
  TextColumn get id => text()();
  TextColumn get paymentId => text().references(
    Payments,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get reason => text()();
  IntColumn get reversedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
