import 'package:drift/drift.dart';

/// Units of measurement. [decimalPlaces] (0–3) limits quantity precision.
@DataClassName('UnitRow')
class Units extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get symbol => text()();
  IntColumn get decimalPlaces => integer().customConstraint(
    'NOT NULL CHECK (decimal_places BETWEEN 0 AND 3)',
  )();
  IntColumn get archivedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {symbol},
  ];
}
