import 'package:drift/drift.dart';
import 'package:inventrix/core/database/tables/tax_rules.dart';

/// One tax line produced by a rule (CGST, VAT, a cess, ...). The type is
/// free text on purpose so new tax kinds need no schema change.
@DataClassName('TaxComponentRow')
@TableIndex(name: 'idx_tax_components_rule', columns: {#taxRuleId})
class TaxComponents extends Table {
  TextColumn get id => text()();
  TextColumn get taxRuleId =>
      text().references(TaxRules, #id, onDelete: KeyAction.restrict)();
  TextColumn get name => text()();
  TextColumn get componentType => text()();
  IntColumn get rateBasisPoints => integer().withDefault(const Constant(0))();
  IntColumn get fixedAmountMinor => integer().nullable()();
  IntColumn get calculationOrder => integer()();
  BoolColumn get isCompound => boolean().withDefault(const Constant(false))();
  BoolColumn get isRecoverable =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (rate_basis_points BETWEEN 0 AND 100000)',
    'CHECK (fixed_amount_minor IS NULL OR fixed_amount_minor >= 0)',
  ];
}
