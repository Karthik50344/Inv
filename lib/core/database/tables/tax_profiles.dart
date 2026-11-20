import 'package:drift/drift.dart';
import 'package:inventrix/core/database/tables/tax_categories.dart';
import 'package:inventrix/core/database/tables/tax_regimes.dart';

/// A named set of rules for one regime.
@DataClassName('TaxProfileRow')
class TaxProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get regimeId =>
      text().references(TaxRegimes, #id, onDelete: KeyAction.restrict)();
  TextColumn get description => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  TextColumn get defaultTaxCategoryId => text().nullable().references(
    TaxCategories,
    #id,
    onDelete: KeyAction.restrict,
  )();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
