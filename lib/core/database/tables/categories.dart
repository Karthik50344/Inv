import 'package:drift/drift.dart';

/// Product categories. Archived instead of deleted.
@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();

  /// Reserved for nested categories.
  TextColumn get parentId => text().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.restrict,
  )();
  IntColumn get archivedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
