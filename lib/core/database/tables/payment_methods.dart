import 'package:drift/drift.dart';

/// Ways of paying (cash, bank transfer, ...). Archived, never deleted.
@DataClassName('PaymentMethodRow')
class PaymentMethods extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get createdAt => integer()();
  IntColumn get archivedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
