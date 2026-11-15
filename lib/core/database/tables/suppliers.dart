import 'package:drift/drift.dart';

/// Suppliers with contact details and an opening balance (signed minor units).
@DataClassName('SupplierRow')
class Suppliers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get state => text().nullable()();
  TextColumn get postalCode => text().nullable()();
  TextColumn get taxId => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get openingBalanceMinor => integer()();
  IntColumn get archivedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
