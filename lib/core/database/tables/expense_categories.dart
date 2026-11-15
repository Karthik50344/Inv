import 'package:drift/drift.dart';

/// Categories that expenses are filed under. Archived, never deleted.
/// Names are unique among active categories (partial index in
/// `schema_extras.dart`).
@DataClassName('ExpenseCategoryRow')
class ExpenseCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get archivedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
