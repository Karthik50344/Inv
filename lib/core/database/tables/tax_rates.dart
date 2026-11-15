import 'package:drift/drift.dart';

/// Configurable tax rates stored as basis points (1% = 100).
@DataClassName('TaxRateRow')
class TaxRates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get rateBp => integer().customConstraint(
    'NOT NULL CHECK (rate_bp BETWEEN 0 AND 100000)',
  )();
  BoolColumn get isExempt => boolean().withDefault(const Constant(false))();
  IntColumn get archivedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (is_exempt = 0 OR rate_bp = 0)',
  ];
}
