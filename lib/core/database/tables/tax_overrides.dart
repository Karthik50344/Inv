import 'package:drift/drift.dart';
import 'package:inventrix/core/database/tables/tax_categories.dart';

/// An explicit, named replacement of a product's tax category.
@DataClassName('TaxOverrideRow')
class TaxOverrides extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get taxCategoryId =>
      text().references(TaxCategories, #id, onDelete: KeyAction.restrict)();
  TextColumn get reason => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ["CHECK (length(trim(reason)) > 0)"];
}
