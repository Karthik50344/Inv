import 'package:drift/drift.dart';

/// A tax system for a country (GST, VAT, sales tax, ...).
@DataClassName('TaxRegimeRow')
class TaxRegimes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get countryCode => text()();
  TextColumn get description => text().nullable()();
  TextColumn get currencyCode => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
