import 'package:drift/drift.dart';
import 'package:inventrix/core/database/tables/tax_categories.dart';
import 'package:inventrix/core/database/tables/tax_jurisdictions.dart';
import 'package:inventrix/core/database/tables/tax_profiles.dart';

/// Says which components apply in which context. Dates are UTC midnight
/// epoch milliseconds; both ends are inclusive.
@DataClassName('TaxRuleRow')
@TableIndex(
  name: 'idx_tax_rules_lookup',
  columns: {#taxProfileId, #taxCategoryId, #isActive},
)
class TaxRules extends Table {
  TextColumn get id => text()();
  TextColumn get taxProfileId =>
      text().references(TaxProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get taxCategoryId =>
      text().references(TaxCategories, #id, onDelete: KeyAction.restrict)();
  TextColumn get jurisdictionId => text().nullable().references(
    TaxJurisdictions,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get transactionType => text().nullable()();
  TextColumn get customerTaxStatus => text().nullable()();
  TextColumn get supplyType => text().nullable()();
  TextColumn get supplyRelation => text().withDefault(const Constant('any'))();
  TextColumn get calculationMethod => text()();
  BoolColumn get isStackable => boolean().withDefault(const Constant(false))();
  IntColumn get effectiveFrom => integer()();
  IntColumn get effectiveUntil => integer().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (calculation_method IN ('percentage', 'fixed'))",
    "CHECK (supply_relation IN ('any', 'intra', 'inter', 'cross_border'))",
    "CHECK (transaction_type IS NULL OR transaction_type IN ('sale', "
        "'purchase', 'sales_return', 'purchase_return'))",
    'CHECK (effective_until IS NULL OR effective_until >= effective_from)',
  ];
}
