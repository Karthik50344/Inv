import 'package:drift/drift.dart';

/// Business identity used on documents. A single active row is expected.
@DataClassName('BusinessProfileRow')
class BusinessProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get taxId => text().nullable()();
  TextColumn get logoPath => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
